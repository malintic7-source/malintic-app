@echo off
setlocal
pushd "%~dp0"
title M@LINTIC - DEPLOIEMENT LOCAL DOCKER

echo ============================================================
echo   M@LINTIC - DEPLOIEMENT LOCAL DOCKER
echo   PostgreSQL local ^| API ^| Frontend ^| Ngrok
echo ============================================================
echo.

where docker >nul 2>&1
if errorlevel 1 (
    echo [ERREUR] Docker Desktop est introuvable dans le PATH.
    popd
    exit /b 1
)

docker info >nul 2>&1
if errorlevel 1 (
    echo [ERREUR] Docker Desktop n'est pas demarre.
    echo Demarrez Docker Desktop puis relancez ce script.
    popd
    exit /b 1
)

if not exist ".env" (
    echo [ERREUR] Le fichier .env est absent.
    echo Copiez .env.example vers .env et renseignez les secrets locaux.
    popd
    exit /b 1
)

echo [1/5] Validation de la configuration Compose...
docker compose config --quiet
if errorlevel 1 (
    echo [ERREUR] docker-compose.yml est invalide.
    popd
    exit /b 1
)

echo [2/5] Compilation Flutter Web...
where flutter >nul 2>&1
if errorlevel 1 (
    echo [ERREUR] Flutter est introuvable dans le PATH.
    popd
    exit /b 1
)
call flutter build web --release --pwa-strategy=none --no-tree-shake-icons
if errorlevel 1 (
    echo [ERREUR] La compilation Flutter a echoue.
    popd
    exit /b 1
)

echo [3/5] Sauvegarde PostgreSQL...
if not exist "backup" mkdir "backup"
docker compose exec -T postgres pg_dump -U malintic -d malintic > "backup\malintic_pre_deploy.sql"
if errorlevel 1 (
    echo [INFO] Sauvegarde PostgreSQL non disponible, premier deploiement probable.
)

echo [4/5] Construction et demarrage des services...
docker compose up -d --build --remove-orphans
if errorlevel 1 (
    echo [ERREUR] Le demarrage Docker a echoue.
    popd
    exit /b 1
)

echo [5/5] Verification de sante...
docker compose ps
docker compose exec -T postgres pg_isready -U malintic -d malintic
if errorlevel 1 (
    echo [ERREUR] PostgreSQL n'est pas pret.
    popd
    exit /b 1
)

echo.
echo [OK] Deploiement local termine.
echo Application : http://localhost
echo API         : http://localhost:8000/api/health
echo PostgreSQL  : reseau Docker uniquement
echo.
echo Administration optionnelle :
echo   docker compose --profile admin up -d pgadmin
echo   docker compose --profile monitoring up -d prometheus grafana
echo.
popd
exit /b 0
