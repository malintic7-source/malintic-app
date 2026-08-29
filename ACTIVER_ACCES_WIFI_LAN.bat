@echo off
setlocal enabledelayedexpansion
pushd "%~dp0"
title Configuration Reseau Wi-Fi/LAN - M@LINTIC-APP

:: Auto-elevation en Administrateur
net session >nul 2>&1
if %ERRORLEVEL% neq 0 (
    echo [ELEVATION] Demande des droits Administrateur pour ouvrir le Pare-feu...
    powershell -NoProfile -Command "Start-Process cmd -ArgumentList '/c \"\"%~f0\"\"' -Verb RunAs"
    popd
    exit /b
)

echo ======================================================================
echo   AUTORISATION ACCES WI-FI / RESEAU LOCAL (LAN) - M@LINTIC-APP
echo ======================================================================
echo.

:: 1. Configuration du Pare-Feu Windows (Ports 80 et 8000)
echo [1/3] Ouverture des ports dans le Pare-Feu Windows (80 et 8000)...
netsh advfirewall firewall delete rule name="MNTIC_App_LAN_80" >nul 2>&1
netsh advfirewall firewall delete rule name="MNTIC_App_LAN_8000" >nul 2>&1
netsh advfirewall firewall add rule name="MNTIC_App_LAN_80" dir=in action=allow protocol=TCP localport=80 profile=any >nul 2>&1
netsh advfirewall firewall add rule name="MNTIC_App_LAN_8000" dir=in action=allow protocol=TCP localport=8000 profile=any >nul 2>&1
echo [OK] Pare-feu Windows configure (Trafic entrant autorise).

:: 2. Configuration du Routage Réseau PortProxy (Wi-Fi <-> Docker WSL)
echo.
echo [2/3] Configuration du pont reseau physique vers Docker (Ports 80 et 8000)...
netsh interface portproxy delete v4tov4 listenaddress=0.0.0.0 listenport=80 >nul 2>&1
netsh interface portproxy delete v4tov4 listenaddress=0.0.0.0 listenport=8000 >nul 2>&1
netsh interface portproxy add v4tov4 listenaddress=0.0.0.0 listenport=80 connectaddress=127.0.0.1 connectport=80 >nul 2>&1
netsh interface portproxy add v4tov4 listenaddress=0.0.0.0 listenport=8000 connectaddress=127.0.0.1 connectport=8000 >nul 2>&1
echo [OK] Routage reseau active.

:: 3. Detection de l'IP Locale Physique
set LOCAL_IP=
for /f "tokens=2 delims=:" %%a in ('ipconfig ^| findstr /c:"IPv4" /c:"Adresse IPv4"') do (
    set "TMP_IP=%%a"
    set "TMP_IP=!TMP_IP: =!"
    if not "!TMP_IP!"=="" (
        if "!TMP_IP:~0,8!"=="192.168." set "LOCAL_IP=!TMP_IP!"
        if "!TMP_IP:~0,3!"=="10." if not defined LOCAL_IP set "LOCAL_IP=!TMP_IP!"
    )
)
if not defined LOCAL_IP (
    for /f "tokens=2 delims=:" %%a in ('ipconfig ^| findstr /c:"IPv4" /c:"Adresse IPv4"') do (
        set "TMP_IP=%%a"
        set "TMP_IP=!TMP_IP: =!"
        if not "!TMP_IP!"=="" (
            if not "!TMP_IP:~0,3!"=="127" if not "!TMP_IP:~0,8!"=="169.254" if not "!TMP_IP:~0,4!"=="172." (
                set "LOCAL_IP=!TMP_IP!"
            )
        )
    )
)

echo.
echo ======================================================================
echo   ACCES RESEAU LOCAL REUSSI ET OPERATIONNEL !
echo ======================================================================
echo.
echo   Depuis TOUS les autres appareils connectes au Wi-Fi (Smartphones, PC) :
echo.
if defined LOCAL_IP (
echo      👉 http://!LOCAL_IP!
echo      👉 http://!LOCAL_IP!:8000
) else (
echo      👉 http://%COMPUTERNAME%
)
echo.
echo ======================================================================
echo.
pause
popd
