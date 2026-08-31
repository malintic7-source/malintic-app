@echo off
setlocal enabledelayedexpansion

echo ================================================================
echo   NETTOYAGE COMPLET ET REDEPLOIEMENT M@LINTIC (DOCKER / VERCEL)
echo ================================================================
echo.

echo [1/4] Nettoyage des conteneurs et anciennes images Docker...
docker-compose down 2>nul
docker rmi -f malintic_app-app malintic_app-api malintic_app-supervisor gestion_formations-app gestion_formations-api 2>nul
docker builder prune -f
docker image prune -f
echo   - Images Docker obsoletes purgees avec succes.
echo.

echo [2/4] Nettoyage des caches locaux et Vercel...
if exist build\web rd /s /q build\web
if exist .vercel\cache rd /s /q .vercel\cache
echo   - Caches build et Vercel nettoyes.
echo.

echo [3/4] Recompilation propre du bundle Web Flutter...
call flutter build web --release --pwa-strategy=none --no-tree-shake-icons
if errorlevel 1 (
    echo [ERREUR] Echec de la compilation Flutter Web.
    exit /b 1
)
echo.

echo [4/4] Reconstruction Docker sans cache...
docker-compose build --no-cache
if errorlevel 1 (
    echo [ERREUR] Echec du build Docker.
    exit /b 1
)

echo.
echo ================================================================
echo   REDEPLOIEMENT TERMINE AVEC SUCCES !
echo   - Lancer l'environnement local : docker-compose up -d
echo   - Port Application Web         : http://localhost (ou :8000)
echo   - Port API Backend Node        : http://localhost:5001
echo   - Port Superviseur PRA / PCA   : http://localhost:5002
echo   - Deploiement Vercel Cloud     : npx vercel --prod --force
echo ================================================================
pause
