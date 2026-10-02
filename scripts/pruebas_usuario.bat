@echo off
REM Pruebas desde el usuario (Windows) - Diego 2023-0316
set SRV=%1
if "%SRV%"=="" set SRV=10.23.16.130
echo ===== %date% %time% =====
ipconfig
ping -n 4 %SRV%
tracert -d %SRV%
curl -k -s -o NUL -w "Codigo HTTP: %%{http_code}\n" https://%SRV%
pause
