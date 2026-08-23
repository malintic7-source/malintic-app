@echo off
setlocal enabledelayedexpansion
pushd "%~dp0"
title Diagnostic et Reparation Reseau LAN - M@LI-NTIC

:: Auto-elevation Administrateur
net session >nul 2>&1
if %ERRORLEVEL% neq 0 (
    echo [INFO] Demande des droits Administrateur pour configurer le reseau Windows...
    powershell -Command "Start-Process '%~f0' -Verb RunAs"
    popd
    exit /b
)

cls
echo ======================================================================
echo   DIAGNOSTIC ET REPARATION RESEAU LAN M@LI-NTIC (192.168.10.69)
echo ======================================================================
echo.

:: 1. Verification de l'IP 192.168.10.69
echo [1/5] Verification de l'adresse IP locale...
ipconfig | findstr /c:"192.168.10.69" >nul 2>&1
if %ERRORLEVEL% equ 0 (
    echo [OK] Adresse IP 192.168.10.69 detectee sur la carte reseau.
) else (
    echo [ATTENTION] L'adresse 192.168.10.69 n'est pas l'adresse IP actuelle de ce PC.
    echo Adresses IP trouvees sur cette machine :
    ipconfig | findstr /c:"IPv4" /c:"Adresse IPv4"
)

:: 2. Configuration du Pare-Feu Windows
echo.
echo [2/5] Ouverture des ports 80 et 8080 dans le Pare-Feu Windows...
netsh advfirewall firewall delete rule name="MNTIC_App_LAN_8080" >nul 2>&1
netsh advfirewall firewall delete rule name="MNTIC_App_LAN_80" >nul 2>&1
netsh advfirewall firewall add rule name="MNTIC_App_LAN_8080" dir=in action=allow protocol=TCP localport=8080 profile=any >nul 2>&1
netsh advfirewall firewall add rule name="MNTIC_App_LAN_80" dir=in action=allow protocol=TCP localport=80 profile=any >nul 2>&1
echo [OK] Ports 80 et 8080 ouverts dans le Pare-feu Windows.

:: 3. Configuration du Pont Reseau Physique <-> Docker WSL
echo.
echo [3/5] Configuration du pont reseau Windows (PortProxy)...
netsh interface portproxy delete v4tov4 listenaddress=0.0.0.0 listenport=8080 >nul 2>&1
netsh interface portproxy delete v4tov4 listenaddress=0.0.0.0 listenport=80 >nul 2>&1
netsh interface portproxy add v4tov4 listenaddress=0.0.0.0 listenport=8080 connectaddress=127.0.0.1 connectport=8080 >nul 2>&1
netsh interface portproxy add v4tov4 listenaddress=0.0.0.0 listenport=80 connectaddress=127.0.0.1 connectport=80 >nul 2>&1
echo [OK] Pont reseau vers Docker actif.

:: 4. Configuration du nom de domaine mntic-app.local dans hosts
echo.
echo [4/5] Enregistrement du domaine mntic-app.local dans hosts...
set HOSTS_FILE=%SystemRoot%\System32\drivers\etc\hosts
findstr /c:"mntic-app.local" "%HOSTS_FILE%" >nul 2>&1
if %ERRORLEVEL% neq 0 (
    echo. >> "%HOSTS_FILE%"
    echo # Domaine Local Application MNTIC >> "%HOSTS_FILE%"
    echo 127.0.0.1 mntic-app.local mnticapp.local >> "%HOSTS_FILE%"
    echo 192.168.10.69 mntic-app.local mnticapp.local >> "%HOSTS_FILE%"
    ipconfig /flushdns >nul 2>&1
    echo [OK] Domaine mntic-app.local enregistre.
) else (
    echo [OK] Domaine mntic-app.local deja present dans hosts.
)

:: 5. Verification de Docker
echo.
echo [5/5] Verification de l'etat de Docker...
docker info >nul 2>&1
if %ERRORLEVEL% neq 0 (
    echo [ATTENTION] Docker Desktop n'est pas lance ou est en cours de demarrage.
    echo Veuillez demarrer Docker Desktop, puis lancer deploy.bat.
) else (
    echo [OK] Docker Desktop est actif.
    echo Verification des conteneurs en cours...
    docker ps --filter "name=gestion_formations" --format "table {{.Names}}	{{.Status}}	{{.Ports}}"
)

echo.
echo ======================================================================
echo   DIAGNOSTIC ET REPARATION TERMINES AVEC SUCCES !
echo ======================================================================
echo.
echo   Liens d'acces reseau local :
echo   👉 http://192.168.10.69:8080
echo   👉 http://mntic-app.local:8080
echo.
pause
popd
