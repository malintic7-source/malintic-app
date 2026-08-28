@echo off
setlocal enabledelayedexpansion
pushd "%~dp0"
title Accedez a l'Application Gestion Formations MNTIC

:: Detection automatique et intelligente de l'IP Locale Physique (Wi-Fi / Ethernet)
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

cls
echo ======================================================================
echo     GESTION DES FORMATIONS M@LI-NTIC - ACCES A L'APPLICATION
echo ======================================================================
echo.
echo  Choisissez le mode d'acces souhaite :
echo.
echo  [1] ACCES RESEAU LOCAL (LAN / Wi-Fi Bureau) [Recommande au bureau]
if defined LOCAL_IP (
echo      Lien : http://!LOCAL_IP!
) else (
echo      Lien : http://localhost
)
echo.
echo  [2] ACCES PUBLIC (Internet / Extranet hors bureau)
echo      Lien : https://malintic-app.vercel.app
echo.
echo  [3] Afficher les informations de connexion pour d'autres appareils
echo.
echo  [4] Quitter
echo.
echo ======================================================================
set /p CHOIX="Entrez votre choix (1, 2, 3 ou 4) : "

if "%CHOIX%"=="1" (
    if defined LOCAL_IP (
        start http://!LOCAL_IP!
    ) else (
        start http://localhost
    )
    goto end
)
if "%CHOIX%"=="2" (
    start https://malintic-app.vercel.app
    goto end
)
if "%CHOIX%"=="3" (
    cls
    echo ======================================================================
    echo   CONNEXION DEPUIS D'AUTRES ORDINATEURS / PHONES DU BUREAU (Wi-Fi)
    echo ======================================================================
    echo.
    echo   1. Connectez l'autre appareil (PC, Tablette, Telephone) au meme Wi-Fi.
    echo   2. Ouvrez le navigateur (Chrome, Edge, Safari).
    echo   3. Entrez directement l'une des adresses suivantes :
    echo.
    if defined LOCAL_IP (
        echo      👉 http://!LOCAL_IP!
        echo      👉 http://!LOCAL_IP!:8000
    ) else (
        echo      👉 http://%COMPUTERNAME%
    )
    echo.
    echo   (Note : Ne pas utiliser le port 8080 qui est reserve a XAMPP)
    echo.
    echo ======================================================================
    pause
    goto end
)

:end
popd
