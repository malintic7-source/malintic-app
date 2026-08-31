@echo off
setlocal enabledelayedexpansion
pushd "%~dp0"
title Deploiement Vercel Production - M@LINTIC-APP

echo ======================================================================
echo   DEPLOIEMENT VERCEL PRODUCTION - M@LINTIC-APP
echo   Approche : Pre-compilation Locale Flutter + Envoi Vercel CLI
echo ======================================================================
echo.

:: 1. Verification de Flutter
echo [1/3] Verification de l'environnement Flutter...
where flutter >nul 2>&1
if %ERRORLEVEL% neq 0 (
    echo [ERREUR] Flutter n'est pas installe ou n'est pas dans le PATH.
    pause
    popd
    exit /b 1
)
echo [OK] Flutter detecte.

:: 2. Compilation Flutter Web Release
echo.
echo [2/3] Compilation du paquet Flutter Web Release avec Supabase Cloud...
call flutter build web --release --dart-define=SUPABASE_URL=https://mzixlwnrsqoxolzafmjb.supabase.co --dart-define=SUPABASE_ANON_KEY=sb_publishable_X9Srmcc9dIppUO8Hl0EDAw_C-giTCqt --dart-define=SUPABASE_ENABLED=true
if %ERRORLEVEL% neq 0 (
    echo [ERREUR] La compilation Flutter Web a echoue.
    pause
    popd
    exit /b 1
)
echo [OK] Compilation terminee avec succes dans build/web.

:: 3. Deploiement direct sur Vercel
echo.
echo [3/3] Envoi et activation sur les serveurs Edge de Vercel...
call npx -y vercel --prod --yes
if %ERRORLEVEL% neq 0 (
    echo [ERREUR] Le deploiement Vercel a echoue.
    pause
    popd
    exit /b 1
)

echo.
echo ======================================================================
echo   DEPLOIEMENT VERCEL REUSSI ET EN LIGNE !
echo ======================================================================
echo   Application Principale : https://malintic-app.vercel.app
echo   Page Inscription SFP5  : https://malintic-app.vercel.app/formation?id=form_sfp_2026
echo ======================================================================
echo.
pause
popd
