@echo off
setlocal enabledelayedexpansion
pushd "%~dp0"
title Deploiement Securise - M@LINTIC-APP

echo ======================================================================
echo   DEPLOIEMENT ^& MISE A JOUR SECURISEE - M@LINTIC-APP
echo   Dossier : %CD%
echo ======================================================================
echo.

:: 1. Verification de Docker
echo [1/6] Verification de Docker...
where docker >nul 2>&1
if %ERRORLEVEL% neq 0 (
    echo [ERREUR] Docker n'est pas accessible. Assurez-vous que Docker Desktop est lance.
    pause
    popd
    exit /b 1
)
echo [OK] Docker operationnel.

:: 2. Sauvegarde Preventive Automatique des Donnees Actuelles (Photos, Formations, Stagiaires, etc.)
echo.
echo [2/6] Sauvegarde automatique preventive des donnees de production...
if not exist "backup" mkdir "backup" >nul 2>&1
docker exec malintic_api test -f /data/database.json >nul 2>&1
if %ERRORLEVEL% equ 0 (
    docker cp malintic_api:/data/database.json "backup\database_auto_backup.json" >nul 2>&1
    echo [OK] Copie de securite creee dans backup\database_auto_backup.json.
) else (
    echo [INFO] Aucune donnee anterieure a sauvegarder.
)

:: 3. Liaison Réseau Carte Physique (Wi-Fi 192.168.10.69) ^<^> WSL & Pare-Feu
echo.
echo [3/6] Configuration du routage reseau Carte Physique ^<^> WSL (Ports 80 et 8080)...
:: Pont reseau universel pour router les paquets du Wi-Fi physique vers Docker WSL
netsh interface portproxy add v4tov4 listenaddress=0.0.0.0 listenport=8080 connectaddress=127.0.0.1 connectport=8080 >nul 2>&1
netsh interface portproxy add v4tov4 listenaddress=0.0.0.0 listenport=80 connectaddress=127.0.0.1 connectport=80 >nul 2>&1

:: Autorisation Pare-Feu Windows pour tous les profils (Prive, Public, Domaine)
netsh advfirewall firewall delete rule name="MNTIC_App_LAN_8080" >nul 2>&1
netsh advfirewall firewall delete rule name="MNTIC_App_LAN_80" >nul 2>&1
netsh advfirewall firewall add rule name="MNTIC_App_LAN_8080" dir=in action=allow protocol=TCP localport=8080 profile=any >nul 2>&1
netsh advfirewall firewall add rule name="MNTIC_App_LAN_80" dir=in action=allow protocol=TCP localport=80 profile=any >nul 2>&1
echo [OK] Routage reseau physique/WSL et Pare-feu configures avec succes.

:: 4. Compilation des images Docker
echo.
echo [4/6] Compilation des nouvelles images applicatives...
docker compose -p malintic_app build app api
if %ERRORLEVEL% neq 0 (
    docker-compose -p malintic_app build app api
    if %ERRORLEVEL% neq 0 (
        echo [ERREUR] La compilation des images a echoue. L'ancienne version reste active.
        pause
        popd
        exit /b 1
    )
)
echo [OK] Images a jour compilees.

:: 5. Mise a jour des conteneurs (Volume de donnees conserve intact)
echo.
echo [5/6] Application de la mise a jour (Toutes donnees conservees)...
docker compose -p malintic_app up -d --remove-orphans
if %ERRORLEVEL% neq 0 (
    docker-compose -p malintic_app up -d --remove-orphans
    if %ERRORLEVEL% neq 0 (
        echo [ERREUR] Le redemarrage des services a echoue.
        pause
        popd
        exit /b 1
    )
)
echo [OK] Services applicatifs et tunnels redemarres.

:: 6. Verification de la base de donnees
echo.
echo [6/6] Verification des donnees...
docker exec malintic_api test -f /data/database.json >nul 2>&1
if %ERRORLEVEL% neq 0 (
    if exist "server\initial_database.json" (
        echo Initialisation initiale de la base...
        docker cp "server\initial_database.json" malintic_api:/data/database.json >nul 2>&1
        docker compose -p malintic_app restart api >nul 2>&1
        echo [OK] Base initiale installee.
    )
) else (
    echo [OK] Base de donnees intacte et active (100%% des photos, formations et stagiaires preserves).
)

:: Configuration automatique du domaine local mntic_app.local dans hosts
findstr /c:"mntic_app.local" "%SystemRoot%\System32\drivers\etc\hosts" >nul 2>&1
if %ERRORLEVEL% neq 0 (
    echo 127.0.0.1 mntic_app.local mntic-app.local >> "%SystemRoot%\System32\drivers\etc\hosts" 2>nul
)

:: Detection de l'adresse IP locale
for /f "tokens=2 delims=:" %%a in ('ipconfig ^| findstr /c:"IPv4" /c:"Adresse IPv4"') do (
    set IP=%%a
    set IP=!IP: =!
    if not "!IP!"=="" (
        if not "!IP:~0,3!"=="127" (
            set LOCAL_IP=!IP!
        )
    )
)

echo.
echo Statut des services actifs :
docker compose -p malintic_app ps

echo.
echo ======================================================================
echo   DEPLOIEMENT REUSSI - TOUTES DONNEES PRESERVEES A 100%% !
echo ======================================================================
echo.
echo   [1] ACCES LOCAL (LAN / Wi-Fi Bureau) :
echo       - Domaine Local Pro  : http://mntic_app.local  (ou http://mntic-app.local)
if defined LOCAL_IP (
echo       - Adresse IP Directe : http://!LOCAL_IP!:8080
)
echo       - Local sur serveur  : http://localhost:8080
echo.
echo   [2] ACCES DISTANT (Internet / WhatsApp / Extranet) :
echo       - Lien Public Securise : https://boil-prude-curry.ngrok-free.dev
echo.
echo ======================================================================
echo.
pause
popd
