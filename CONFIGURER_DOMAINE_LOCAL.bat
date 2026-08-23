@echo off
setlocal enabledelayedexpansion
pushd "%~dp0"
title Configuration du Domaine Local mntic_app.local

echo ======================================================================
echo   CONFIGURATION DU NOM DE DOMAINE LOCAL : mntic_app.local
echo ======================================================================
echo.

:: Verification des droits administrateur
net session >nul 2>&1
if %ERRORLEVEL% neq 0 (
    echo [ATTENTION] Ce script necessite les droits Administrateur pour modifier le fichier hosts.
    echo Clic-droit sur ce fichier puis "Executer en tant qu'administrateur".
    echo.
    pause
    popd
    exit /b 1
)

:: Detection de l'IP Locale
for /f "tokens=2 delims=:" %%a in ('ipconfig ^| findstr /c:"IPv4" /c:"Adresse IPv4"') do (
    set IP=%%a
    set IP=!IP: =!
    if not "!IP!"=="" (
        if not "!IP:~0,3!"=="127" (
            set LOCAL_IP=!IP!
        )
    )
)

set HOSTS_FILE=%SystemRoot%\System32\drivers\etc\hosts

:: Verifier si le domaine est deja dans hosts
findstr /c:"mntic_app.local" "%HOSTS_FILE%" >nul 2>&1
if %ERRORLEVEL% equ 0 (
    echo [INFO] Le domaine mntic_app.local est deja configure dans le fichier hosts.
) else (
    echo. >> "%HOSTS_FILE%"
    echo # Domaine Local Application MNTIC >> "%HOSTS_FILE%"
    echo 127.0.0.1 mntic_app.local mntic-app.local >> "%HOSTS_FILE%"
    if defined LOCAL_IP (
        echo !LOCAL_IP! mntic_app.local mntic-app.local >> "%HOSTS_FILE%"
    )
    echo [OK] Noms de domaine mntic_app.local et mntic-app.local ajoutes au fichier hosts avec succes.
)

:: Vider le cache DNS Windows
ipconfig /flushdns >nul 2>&1
echo [OK] Cache DNS Windows actualise.

echo.
echo ======================================================================
echo   CONFIGURATION REUSSIE !
echo   Vous pouvez desormais acceder a l'application via :
echo.
echo   👉 http://mntic_app.local
echo   👉 http://mntic-app.local
echo   👉 http://mntic_app.local:8080
echo ======================================================================
echo.
pause
popd
