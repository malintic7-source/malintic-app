@echo off
setlocal enabledelayedexpansion
pushd "%~dp0"
title Accedez a l'Application Gestion Formations MNTIC

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

cls
echo ======================================================================
echo     GESTION DES FORMATIONS M@LI-NTIC - ACCES A L'APPLICATION
echo ======================================================================
echo.
echo  Choisissez le mode d'acces souhaite :
echo.
echo  [1] ACCES RESEAU LOCAL (LAN / Wi-Fi Bureau) [Recommande au bureau]
if defined LOCAL_IP (
echo      Lien : http://!LOCAL_IP!:8080
) else (
echo      Lien : http://localhost:8080
)
echo.
echo  [2] ACCES DISTANT (Internet / Extranet hors bureau)
echo      Lien : https://boil-prude-curry.ngrok-free.dev
echo.
echo  [3] Afficher les informations de connexion pour d'autres appareils
echo.
echo  [4] Quitter
echo.
echo ======================================================================
set /p CHOIX="Entrez votre choix (1, 2, 3 ou 4) : "

if "%CHOIX%"=="1" (
    if defined LOCAL_IP (
        start http://!LOCAL_IP!:8080
    ) else (
        start http://localhost:8080
    )
    goto end
)
if "%CHOIX%"=="2" (
    start https://boil-prude-curry.ngrok-free.dev
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
    echo   3. Entrez l'adresse suivante :
    echo.
    if defined LOCAL_IP (
        echo      👉 http://!LOCAL_IP!:8080
    ) else (
        echo      👉 http://%COMPUTERNAME%:8080
    )
    echo.
    echo ======================================================================
    pause
    goto end
)

:end
popd
