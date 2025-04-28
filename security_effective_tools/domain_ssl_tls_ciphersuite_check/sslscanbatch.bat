@echo off
setlocal enabledelayedexpansion

mkdir results 2>nul

for /f "tokens=*" %%d in (domains.txt) do (
    echo Scanning %%d...
    sslscan.exe %%d > results\%%d_sslscan.txt
    echo Results saved to results\%%d_sslscan.txt
)

echo All scans completed!
pause