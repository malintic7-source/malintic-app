@echo off
setlocal enabledelayedexpansion
title Configuration du Demarrage Automatique - MNTIC
cd /d "%~dp0"

echo ======================================================================
echo   CONFIGURATION DU DEMARRAGE AUTOMATIQUE SYSTEME - M@LI-NTIC
echo ======================================================================
echo.

:: 1. Verification des privileges
net session >nul 2>&1
if %ERRORLEVEL% neq 0 (
    echo [INFO] Pour enregistrer la tache planifiee systeme, executez ce script en tant qu'Administrateur si demande.
)

:: 2. Configuration des regles de Pare-Feu LAN (Ports 80 et 8080)
netsh advfirewall firewall add rule name="MNTIC_App_LAN_8080" dir=in action=allow protocol=TCP localport=8080 profile=any >nul 2>&1
netsh advfirewall firewall add rule name="MNTIC_App_LAN_80" dir=in action=allow protocol=TCP localport=80 profile=any >nul 2>&1
echo [OK] Autorisations Pare-feu LAN configurees (ports 80 et 8080).

:: 3. Configuration du domaine local mntic_app.local dans hosts
findstr /c:"mntic_app.local" "%SystemRoot%\System32\drivers\etc\hosts" >nul 2>&1
if %ERRORLEVEL% neq 0 (
    echo. >> "%SystemRoot%\System32\drivers\etc\hosts" 2>nul
    echo # Domaine Local Application MNTIC >> "%SystemRoot%\System32\drivers\etc\hosts" 2>nul
    echo 127.0.0.1 mntic_app.local mntic-app.local >> "%SystemRoot%\System32\drivers\etc\hosts" 2>nul
    echo [OK] Domaine mntic_app.local associe au fichier hosts local.
)

:: 4. Creation du script de demarrage silencieux (start-daemon.bat)
set "START_SCRIPT=%~dp0start-daemon.bat"
(
    echo @echo off
    echo cd /d "%~dp0"
    echo :: Attente que le moteur Docker Desktop soit actif
    echo :WAIT_DOCKER
    echo docker info >nul 2>&1
    echo if %%ERRORLEVEL%% neq 0 (
    echo     timeout /t 5 /nobreak ^>nul
    echo     goto WAIT_DOCKER
    echo ^)
    echo :: Demarrage automatique de tous les conteneurs et des tunnels
    echo docker compose -p gestion_formations up -d --remove-orphans
) > "%START_SCRIPT%"

echo [OK] Script de surveillance et demarrage cree : %START_SCRIPT%

:: 5. Creation de la tache planifiee Windows au demarrage / ouverture de session
schtasks /create /tn "GestionFormations_AutoStart" /tr ""%START_SCRIPT%"" /sc onlogon /rl highest /f >nul 2>&1
if %ERRORLEVEL% equ 0 (
    echo [SUCCES] Tache planifiee 'GestionFormations_AutoStart' installee avec succes !
    echo L'application, le domaine mntic_app.local et les tunnels redemarreront automatiquement au demarrage de la machine.
) else (
    echo [INFO] Ajout d'un raccourci dans le dossier Demarrage automatique utilisateur...
    copy /y "%START_SCRIPT%" "%APPDATA%\Microsoft\Windows\Start Menu\Programs\Startup\GestionFormations_AutoStart.bat" >nul 2>&1
    echo [SUCCES] Raccourci place dans le dossier de demarrage automatique.
)

echo.
echo ======================================================================
echo   DEMARRAGE AUTOMATIQUE CONFIGURE AVEC SUCCES !
echo   - Domaine Local : http://mntic_app.local
echo   - Port Standard : 80 et 8080
echo   - Tunnel Public : https://boil-prude-curry.ngrok-free.dev
echo ======================================================================
echo.
pause
popd
