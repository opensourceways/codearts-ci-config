@echo off
setlocal enabledelayedexpansion

:: =============================================
:: SSLScan��ȫ�������� - �ռ�������
:: �޸����ݣ�
:: 1. ��ȫ����Windows��ȥ��uniq��Linux���
:: 2. ��ǿ�Ĳ���ȫ�㷨��⣨��������CBCģʽ��
:: 3. ������ANSI��ɫ���봦��
:: =============================================

:: ��ȫ��ȡ���ڣ����������������ã�
for /f "tokens=2 delims==" %%I in ('wmic os get localdatetime /value') do set "datetime=%%I"
set "safe_date=%datetime:~0,4%-%datetime:~4,2%-%datetime:~6,2%"

:: ���ò���
set "RESULTS_DIR=.\results"
set "INSECURE_FILE=insecure_domains_%safe_date%.txt"
set "REPORT_FILE=full_report_%safe_date%.txt"
set "TEMP_FILE=%temp%\sslscan_clean.tmp"
set "ISSUE_TYPES_FILE=%temp%\issue_types.tmp"

:: ��ʼ���ļ�
(
    echo ����ȫ��SSL/TLS���ñ���
    echo ��������: %date% %time%
    echo =========================================
    echo.
) > "%INSECURE_FILE%"

(
    echo SSL/TLSȫ�氲ȫ��ⱨ��
    echo ɨ��ʱ��: %date% %time%
    echo =========================================
) > "%REPORT_FILE%"

:: ���resultsĿ¼
if not exist "%RESULTS_DIR%\" (
    echo ����: �Ҳ���resultsĿ¼
    pause
    exit /b 1
)

:: �����ѭ��
set "total_count=0"
set "insecure_count=0"
for %%f in ("%RESULTS_DIR%\*_sslscan.txt") do (
    set /a "total_count+=1"
    call :process_file "%%f"
)

:: �����ܽ�
call :generate_summary

:: ������ʱ�ļ�
if exist "%TEMP_FILE%" del "%TEMP_FILE%"
if exist "%ISSUE_TYPES_FILE%" del "%ISSUE_TYPES_FILE%"

:: ��ʾ���
echo.
echo ������!
echo ɨ����������: %total_count%
echo �������������: %insecure_count%
echo.
echo ��������: %REPORT_FILE%
echo ��������: %INSECURE_FILE%
echo.

start "" notepad "%REPORT_FILE%"
start "" notepad "%INSECURE_FILE%"

exit /b 0

:: =============================================
:: �ӳ���: �������ļ���������ɫ���봦��
:: =============================================
:process_file
    set "FILE=%~1"
    set "DOMAIN=%~n1"
    set "DOMAIN=!DOMAIN:_sslscan=!"
    set "FILE_HAS_ISSUES=0"
    
    (
        echo.
        echo [����] !DOMAIN!
        echo =========================================
    ) >> "%REPORT_FILE%"
    
    :: �߼���ɫ���봦��֧������ANSI��ɫ��
    powershell -Command "(Get-Content -Path '%~1') -replace '\x1B\[[0-9;]*[mK]', '' | Out-File -FilePath '%TEMP_FILE%'"
    
    :: ִ�����а�ȫ���
    call :check_protocol
    call :check_ciphers
    call :check_cbc
    call :check_dhe
    call :check_certificate
    call :check_other
    
    :: ��¼�����������
    if !FILE_HAS_ISSUES! EQU 1 (
        set /a "insecure_count+=1"
        echo !DOMAIN! >> "%INSECURE_FILE%"
    )
    
    goto :eof

:: =============================================
:: �ӳ���: Э���飨����ʵ�֣�
:: =============================================
:check_protocol
    (
        echo [Э����]
        echo -------------------------
    ) >> "%REPORT_FILE%"
    
    set "PROTOCOL_ISSUE=0"
    
    :: ���TLS 1.3�Ƿ����
    findstr /C:"TLSv1.3   disabled" "%TEMP_FILE%" >nul && (
        echo ?? TLS 1.3δ���� >> "%REPORT_FILE%"
        set "PROTOCOL_ISSUE=1"
    )
    
    :: ��鲻��ȫ��Э��
    for %%p in (SSLv2 SSLv3 TLSv1.0 TLSv1.1) do (
        findstr /C:"%%p     enabled" "%TEMP_FILE%" >nul && (
            echo ? ����ȫ��Э��: %%p >> "%REPORT_FILE%"
            echo ? [Э��] !DOMAIN! ������ %%p >> "%INSECURE_FILE%"
            echo "Э��:%%p" >> "%ISSUE_TYPES_FILE%"
            set "PROTOCOL_ISSUE=1"
            set "FILE_HAS_ISSUES=1"
        )
    )
    
    if !PROTOCOL_ISSUE! EQU 0 (
        echo ? Э�����ð�ȫ >> "%REPORT_FILE%"
    )
    goto :eof

:: =============================================
:: �ӳ���: �����׼���飨����ʵ�֣�
:: =============================================
:check_ciphers
    (
        echo.
        echo [�����׼����]
        echo -------------------------
    ) >> "%REPORT_FILE%"
    
    set "CIPHER_ISSUE=0"
    
    :: ����ȫ�׼��б������б�
    for %%c in (
        "DES-CBC" "DES-CBC3" "RC4" "RC2" "IDEA" "SEED" 
        "MD5" "SHA1" "EXPORT" "ANON" "NULL" "ADH" "AECDH" "KRB5"
        "PSK" "SRP"
    ) do (
        findstr /R /C:"%%c" "%TEMP_FILE%" | findstr "Accepted" >nul && (
            echo ? ����ȫ�������׼�: %%c >> "%REPORT_FILE%"
            echo ? [�����׼�] !DOMAIN! ���� %%c >> "%INSECURE_FILE%"
            echo "�����׼�:%%c" >> "%ISSUE_TYPES_FILE%"
            set "CIPHER_ISSUE=1"
            set "FILE_HAS_ISSUES=1"
        )
    )
    
    if !CIPHER_ISSUE! EQU 0 (
        echo ? δ���ֲ���ȫ�����׼� >> "%REPORT_FILE%"
    )
    goto :eof

:: =============================================
:: �ӳ���: CBCģʽ��飨������ǿʵ�֣�
:: =============================================
:check_cbc
    (
        echo.
        echo [CBCģʽ���]
        echo -------------------------
    ) >> "%REPORT_FILE%"
    
    set "CBC_ISSUE=0"
    
    :: ȫ���CBCģʽ�׼���⣨�������б��֣�
    for %%c in (
        "AES.*-CBC" "AES.*-CBC-SHA" "AES.*-CBC-SHA256" 
        "CAMELLIA.*-CBC" "3DES-.*CBC" "SEED.*-CBC"
        "DES.*-CBC" "IDEA.*-CBC" "RC2.*-CBC"
    ) do (
        findstr /R /C:"%%c" "%TEMP_FILE%" | findstr "Accepted" >nul && (
            echo ?? �߷���CBCģʽ�׼�: %%c >> "%REPORT_FILE%"
            echo ?? [CBCģʽ] !DOMAIN! ʹ�� %%c >> "%INSSURE_FILE%"
            echo "CBCģʽ:%%c" >> "%ISSUE_TYPES_FILE%"
            set "CBC_ISSUE=1"
            set "FILE_HAS_ISSUES=1"
        )
    )
    
    if !CBC_ISSUE! EQU 0 (
        echo ? δ���ָ߷���CBC�׼� >> "%REPORT_FILE%"
    )
    goto :eof

:: =============================================
:: �ӳ���: DH������飨����ʵ�֣�
:: =============================================
:check_dhe
    (
        echo.
        echo [DH�������]
        echo -------------------------
    ) >> "%REPORT_FILE%"
    
    findstr /C:"DHE 1024 bits" "%TEMP_FILE%" >nul && (
        echo ? ��Diffie-Hellman����(1024λ) >> "%REPORT_FILE%"
        echo ? [DH����] !DOMAIN! ʹ��1024λDHE >> "%INSECURE_FILE%"
        echo "DH����:1024λ" >> "%ISSUE_TYPES_FILE%"
        set "FILE_HAS_ISSUES=1"
    ) || (
        echo ? DH������ȫ >> "%REPORT_FILE%"
    )
    goto :eof

:: =============================================
:: �ӳ���: ֤���飨����ʵ��+��ɫ�����޸���
:: =============================================
:check_certificate
    (
        echo.
        echo [֤����]
        echo -------------------------
    ) >> "%REPORT_FILE%"
    
    set "CERT_ISSUE=0"
    
    :: ��������RSA��Կ���ȣ��������и�ʽ��
    for /f "tokens=1-4 delims=: " %%a in ('findstr /C:"RSA Key Strength:" "%TEMP_FILE%"') do (
        if "%%~d" neq "" (
            set "key_size=%%~d"
        ) else if "%%~c" neq "" (
            set "key_size=%%~c"
        ) else (
            set "key_size=%%~b"
        )
    )
    
    :: ����������ַ�
    set "key_size=!key_size: =!"
    for /f "delims=0123456789" %%c in ("!key_size!") do set "key_size=!key_size:%%c=!"
    
    if defined key_size (
        if !key_size! LSS 2048 (
            echo ? ��RSA��Կ����: !key_size!λ >> "%REPORT_FILE%"
            echo ? [֤��] !DOMAIN! RSA��Կ��!key_size!λ >> "%INSECURE_FILE%"
            echo "֤��:RSA!key_size!λ" >> "%ISSUE_TYPES_FILE%"
            set "CERT_ISSUE=1"
            set "FILE_HAS_ISSUES=1"
        )
    )
    
    :: ���֤����Ч��
    for /f "tokens=2 delims=:" %%d in ('findstr /C:"Not valid after:" "%TEMP_FILE%"') do (
        set "expiry_date=%%d"
        for /f "tokens=1-3" %%a in ("!expiry_date!") do (
            set "expiry_day=%%a"
            set "expiry_month=%%b"
            set "expiry_year=%%c"
        )
    )
    
    if !CERT_ISSUE! EQU 0 (
        echo ? ֤�����ð�ȫ >> "%REPORT_FILE%"
    )
    goto :eof

:: =============================================
:: �ӳ���: ������ȫ��飨����ʵ�֣�
:: =============================================
:check_other
    (
        echo.
        echo [������ȫ���]
        echo -------------------------
    ) >> "%REPORT_FILE%"
    
    set "OTHER_ISSUE=0"
    
    :: Heartbleed©�����
    findstr /C:"Heartbleed:.*vulnerable" "%TEMP_FILE%" >nul && (
        echo ? ����Heartbleed©�� >> "%REPORT_FILE%"
        echo ? [©��] !DOMAIN! ����Heartbleed���� >> "%INSECURE_FILE%"
        echo "©��:Heartbleed" >> "%ISSUE_TYPES_FILE%"
        set "OTHER_ISSUE=1"
        set "FILE_HAS_ISSUES=1"
    )
    
    :: TLSѹ�����
    findstr /C:"TLS Compression:.*enabled" "%TEMP_FILE%" >nul && (
        echo ? �����˲���ȫ��TLSѹ�� >> "%REPORT_FILE%"
        echo ? [����] !DOMAIN! ������TLSѹ�� >> "%INSECURE_FILE%"
        echo "����:TLSѹ��" >> "%ISSUE_TYPES_FILE%"
        set "OTHER_ISSUE=1"
        set "FILE_HAS_ISSUES=1"
    )
    
    :: ��鲻��ȫ������Э��
    findstr /C:"TLS renegotiation:.*supported" "%TEMP_FILE%" >nul && (
        echo ?? ֧�ֲ���ȫ��TLS����Э�� >> "%REPORT_FILE%"
        echo ?? [����] !DOMAIN! ֧�ֲ���ȫ����Э�� >> "%INSECURE_FILE%"
        echo "����:����ȫ����Э��" >> "%ISSUE_TYPES_FILE%"
        set "OTHER_ISSUE=1"
        set "FILE_HAS_ISSUES=1"
    )
    
    if !OTHER_ISSUE! EQU 0 (
        echo ? δ����������ȫ���� >> "%REPORT_FILE%"
    )
    goto :eof

:: =============================================
:: �ӳ���: �����ܽᱨ�棨Windows����ʵ�֣�
:: =============================================
:generate_summary
    :: Windows���ݵ���������ͳ��
    if exist "%ISSUE_TYPES_FILE%" (
        (
            echo.
            echo ======== ��������ͳ�� ========
        ) >> "%REPORT_FILE%"
        
        for /f "tokens=1* delims=:" %%a in ('sort "%ISSUE_TYPES_FILE%"') do (
            set "type=%%a"
            set "value=%%b"
            if "!last_type!"=="!type!" (
                set /a "count+=1"
            ) else (
                if defined last_type (
                    echo !last_type!: !count!�� >> "%REPORT_FILE%"
                )
                set "count=1"
                set "last_type=!type!"
            )
        )
        if defined last_type (
            echo !last_type!: !count!�� >> "%REPORT_FILE%"
        )
    )

    (
        echo.
        echo ======== ɨ���ܽ� ========
        echo ɨ����������: %total_count%
        echo �������������: %insecure_count%
        echo ��ȫ����: %total_count%-%insecure_count%
        echo.
        echo ��ϸ������鿴: %INSECURE_FILE%
        echo ============================
    ) >> "%REPORT_FILE%"
    
    goto :eof