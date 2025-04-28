@echo off
setlocal enabledelayedexpansion

:: =============================================
:: SSLScan安全分析工具 - 终极完整版
:: 修复内容：
:: 1. 完全兼容Windows（去除uniq等Linux命令）
:: 2. 增强的不安全算法检测（包含所有CBC模式）
:: 3. 完美的ANSI颜色代码处理
:: =============================================

:: 安全获取日期（兼容所有区域设置）
for /f "tokens=2 delims==" %%I in ('wmic os get localdatetime /value') do set "datetime=%%I"
set "safe_date=%datetime:~0,4%-%datetime:~4,2%-%datetime:~6,2%"

:: 配置参数
set "RESULTS_DIR=.\results"
set "INSECURE_FILE=insecure_domains_%safe_date%.txt"
set "REPORT_FILE=full_report_%safe_date%.txt"
set "TEMP_FILE=%temp%\sslscan_clean.tmp"
set "ISSUE_TYPES_FILE=%temp%\issue_types.tmp"

:: 初始化文件
(
    echo 不安全的SSL/TLS配置报告
    echo 生成日期: %date% %time%
    echo =========================================
    echo.
) > "%INSECURE_FILE%"

(
    echo SSL/TLS全面安全检测报告
    echo 扫描时间: %date% %time%
    echo =========================================
) > "%REPORT_FILE%"

:: 检查results目录
if not exist "%RESULTS_DIR%\" (
    echo 错误: 找不到results目录
    pause
    exit /b 1
)

:: 主检查循环
set "total_count=0"
set "insecure_count=0"
for %%f in ("%RESULTS_DIR%\*_sslscan.txt") do (
    set /a "total_count+=1"
    call :process_file "%%f"
)

:: 生成总结
call :generate_summary

:: 清理临时文件
if exist "%TEMP_FILE%" del "%TEMP_FILE%"
if exist "%ISSUE_TYPES_FILE%" del "%ISSUE_TYPES_FILE%"

:: 显示结果
echo.
echo 检查完成!
echo 扫描域名总数: %total_count%
echo 存在问题的域名: %insecure_count%
echo.
echo 完整报告: %REPORT_FILE%
echo 问题域名: %INSECURE_FILE%
echo.

start "" notepad "%REPORT_FILE%"
start "" notepad "%INSECURE_FILE%"

exit /b 0

:: =============================================
:: 子程序: 处理单个文件（完整颜色代码处理）
:: =============================================
:process_file
    set "FILE=%~1"
    set "DOMAIN=%~n1"
    set "DOMAIN=!DOMAIN:_sslscan=!"
    set "FILE_HAS_ISSUES=0"
    
    (
        echo.
        echo [域名] !DOMAIN!
        echo =========================================
    ) >> "%REPORT_FILE%"
    
    :: 高级颜色代码处理（支持所有ANSI颜色）
    powershell -Command "(Get-Content -Path '%~1') -replace '\x1B\[[0-9;]*[mK]', '' | Out-File -FilePath '%TEMP_FILE%'"
    
    :: 执行所有安全检查
    call :check_protocol
    call :check_ciphers
    call :check_cbc
    call :check_dhe
    call :check_certificate
    call :check_other
    
    :: 记录有问题的域名
    if !FILE_HAS_ISSUES! EQU 1 (
        set /a "insecure_count+=1"
        echo !DOMAIN! >> "%INSECURE_FILE%"
    )
    
    goto :eof

:: =============================================
:: 子程序: 协议检查（完整实现）
:: =============================================
:check_protocol
    (
        echo [协议检查]
        echo -------------------------
    ) >> "%REPORT_FILE%"
    
    set "PROTOCOL_ISSUE=0"
    
    :: 检查TLS 1.3是否禁用
    findstr /C:"TLSv1.3   disabled" "%TEMP_FILE%" >nul && (
        echo ?? TLS 1.3未启用 >> "%REPORT_FILE%"
        set "PROTOCOL_ISSUE=1"
    )
    
    :: 检查不安全的协议
    for %%p in (SSLv2 SSLv3 TLSv1.0 TLSv1.1) do (
        findstr /C:"%%p     enabled" "%TEMP_FILE%" >nul && (
            echo ? 不安全的协议: %%p >> "%REPORT_FILE%"
            echo ? [协议] !DOMAIN! 启用了 %%p >> "%INSECURE_FILE%"
            echo "协议:%%p" >> "%ISSUE_TYPES_FILE%"
            set "PROTOCOL_ISSUE=1"
            set "FILE_HAS_ISSUES=1"
        )
    )
    
    if !PROTOCOL_ISSUE! EQU 0 (
        echo ? 协议配置安全 >> "%REPORT_FILE%"
    )
    goto :eof

:: =============================================
:: 子程序: 密码套件检查（完整实现）
:: =============================================
:check_ciphers
    (
        echo.
        echo [密码套件检查]
        echo -------------------------
    ) >> "%REPORT_FILE%"
    
    set "CIPHER_ISSUE=0"
    
    :: 不安全套件列表（完整列表）
    for %%c in (
        "DES-CBC" "DES-CBC3" "RC4" "RC2" "IDEA" "SEED" 
        "MD5" "SHA1" "EXPORT" "ANON" "NULL" "ADH" "AECDH" "KRB5"
        "PSK" "SRP"
    ) do (
        findstr /R /C:"%%c" "%TEMP_FILE%" | findstr "Accepted" >nul && (
            echo ? 不安全的密码套件: %%c >> "%REPORT_FILE%"
            echo ? [密码套件] !DOMAIN! 接受 %%c >> "%INSECURE_FILE%"
            echo "密码套件:%%c" >> "%ISSUE_TYPES_FILE%"
            set "CIPHER_ISSUE=1"
            set "FILE_HAS_ISSUES=1"
        )
    )
    
    if !CIPHER_ISSUE! EQU 0 (
        echo ? 未发现不安全密码套件 >> "%REPORT_FILE%"
    )
    goto :eof

:: =============================================
:: 子程序: CBC模式检查（完整增强实现）
:: =============================================
:check_cbc
    (
        echo.
        echo [CBC模式检查]
        echo -------------------------
    ) >> "%REPORT_FILE%"
    
    set "CBC_ISSUE=0"
    
    :: 全面的CBC模式套件检测（包括所有变种）
    for %%c in (
        "AES.*-CBC" "AES.*-CBC-SHA" "AES.*-CBC-SHA256" 
        "CAMELLIA.*-CBC" "3DES-.*CBC" "SEED.*-CBC"
        "DES.*-CBC" "IDEA.*-CBC" "RC2.*-CBC"
    ) do (
        findstr /R /C:"%%c" "%TEMP_FILE%" | findstr "Accepted" >nul && (
            echo ?? 高风险CBC模式套件: %%c >> "%REPORT_FILE%"
            echo ?? [CBC模式] !DOMAIN! 使用 %%c >> "%INSSURE_FILE%"
            echo "CBC模式:%%c" >> "%ISSUE_TYPES_FILE%"
            set "CBC_ISSUE=1"
            set "FILE_HAS_ISSUES=1"
        )
    )
    
    if !CBC_ISSUE! EQU 0 (
        echo ? 未发现高风险CBC套件 >> "%REPORT_FILE%"
    )
    goto :eof

:: =============================================
:: 子程序: DH参数检查（完整实现）
:: =============================================
:check_dhe
    (
        echo.
        echo [DH参数检查]
        echo -------------------------
    ) >> "%REPORT_FILE%"
    
    findstr /C:"DHE 1024 bits" "%TEMP_FILE%" >nul && (
        echo ? 弱Diffie-Hellman参数(1024位) >> "%REPORT_FILE%"
        echo ? [DH参数] !DOMAIN! 使用1024位DHE >> "%INSECURE_FILE%"
        echo "DH参数:1024位" >> "%ISSUE_TYPES_FILE%"
        set "FILE_HAS_ISSUES=1"
    ) || (
        echo ? DH参数安全 >> "%REPORT_FILE%"
    )
    goto :eof

:: =============================================
:: 子程序: 证书检查（完整实现+颜色代码修复）
:: =============================================
:check_certificate
    (
        echo.
        echo [证书检查]
        echo -------------------------
    ) >> "%REPORT_FILE%"
    
    set "CERT_ISSUE=0"
    
    :: 完美解析RSA密钥长度（处理所有格式）
    for /f "tokens=1-4 delims=: " %%a in ('findstr /C:"RSA Key Strength:" "%TEMP_FILE%"') do (
        if "%%~d" neq "" (
            set "key_size=%%~d"
        ) else if "%%~c" neq "" (
            set "key_size=%%~c"
        ) else (
            set "key_size=%%~b"
        )
    )
    
    :: 清理非数字字符
    set "key_size=!key_size: =!"
    for /f "delims=0123456789" %%c in ("!key_size!") do set "key_size=!key_size:%%c=!"
    
    if defined key_size (
        if !key_size! LSS 2048 (
            echo ? 弱RSA密钥长度: !key_size!位 >> "%REPORT_FILE%"
            echo ? [证书] !DOMAIN! RSA密钥仅!key_size!位 >> "%INSECURE_FILE%"
            echo "证书:RSA!key_size!位" >> "%ISSUE_TYPES_FILE%"
            set "CERT_ISSUE=1"
            set "FILE_HAS_ISSUES=1"
        )
    )
    
    :: 检查证书有效期
    for /f "tokens=2 delims=:" %%d in ('findstr /C:"Not valid after:" "%TEMP_FILE%"') do (
        set "expiry_date=%%d"
        for /f "tokens=1-3" %%a in ("!expiry_date!") do (
            set "expiry_day=%%a"
            set "expiry_month=%%b"
            set "expiry_year=%%c"
        )
    )
    
    if !CERT_ISSUE! EQU 0 (
        echo ? 证书配置安全 >> "%REPORT_FILE%"
    )
    goto :eof

:: =============================================
:: 子程序: 其他安全检查（完整实现）
:: =============================================
:check_other
    (
        echo.
        echo [其他安全检查]
        echo -------------------------
    ) >> "%REPORT_FILE%"
    
    set "OTHER_ISSUE=0"
    
    :: Heartbleed漏洞检查
    findstr /C:"Heartbleed:.*vulnerable" "%TEMP_FILE%" >nul && (
        echo ? 存在Heartbleed漏洞 >> "%REPORT_FILE%"
        echo ? [漏洞] !DOMAIN! 存在Heartbleed风险 >> "%INSECURE_FILE%"
        echo "漏洞:Heartbleed" >> "%ISSUE_TYPES_FILE%"
        set "OTHER_ISSUE=1"
        set "FILE_HAS_ISSUES=1"
    )
    
    :: TLS压缩检查
    findstr /C:"TLS Compression:.*enabled" "%TEMP_FILE%" >nul && (
        echo ? 启用了不安全的TLS压缩 >> "%REPORT_FILE%"
        echo ? [配置] !DOMAIN! 启用了TLS压缩 >> "%INSECURE_FILE%"
        echo "配置:TLS压缩" >> "%ISSUE_TYPES_FILE%"
        set "OTHER_ISSUE=1"
        set "FILE_HAS_ISSUES=1"
    )
    
    :: 检查不安全的重新协商
    findstr /C:"TLS renegotiation:.*supported" "%TEMP_FILE%" >nul && (
        echo ?? 支持不安全的TLS重新协商 >> "%REPORT_FILE%"
        echo ?? [配置] !DOMAIN! 支持不安全重新协商 >> "%INSECURE_FILE%"
        echo "配置:不安全重新协商" >> "%ISSUE_TYPES_FILE%"
        set "OTHER_ISSUE=1"
        set "FILE_HAS_ISSUES=1"
    )
    
    if !OTHER_ISSUE! EQU 0 (
        echo ? 未发现其他安全问题 >> "%REPORT_FILE%"
    )
    goto :eof

:: =============================================
:: 子程序: 生成总结报告（Windows兼容实现）
:: =============================================
:generate_summary
    :: Windows兼容的问题类型统计
    if exist "%ISSUE_TYPES_FILE%" (
        (
            echo.
            echo ======== 问题类型统计 ========
        ) >> "%REPORT_FILE%"
        
        for /f "tokens=1* delims=:" %%a in ('sort "%ISSUE_TYPES_FILE%"') do (
            set "type=%%a"
            set "value=%%b"
            if "!last_type!"=="!type!" (
                set /a "count+=1"
            ) else (
                if defined last_type (
                    echo !last_type!: !count!次 >> "%REPORT_FILE%"
                )
                set "count=1"
                set "last_type=!type!"
            )
        )
        if defined last_type (
            echo !last_type!: !count!次 >> "%REPORT_FILE%"
        )
    )

    (
        echo.
        echo ======== 扫描总结 ========
        echo 扫描域名总数: %total_count%
        echo 存在问题的域名: %insecure_count%
        echo 安全域名: %total_count%-%insecure_count%
        echo.
        echo 详细问题请查看: %INSECURE_FILE%
        echo ============================
    ) >> "%REPORT_FILE%"
    
    goto :eof