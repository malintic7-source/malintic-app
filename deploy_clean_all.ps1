# ================================================================
#  Script PowerShell : Nettoyage et Redéploiement Propre M@LINTIC
# ================================================================

Write-Host "================================================================" -ForegroundColor Cyan
Write-Host "  NETTOYAGE COMPLET ET REDEPLOIEMENT M@LINTIC (DOCKER / VERCEL)" -ForegroundColor Cyan
Write-Host "================================================================" -ForegroundColor Cyan

# 1. Nettoyage Docker
Write-Host "`n[1/4] Nettoyage des conteneurs et anciennes images Docker..." -ForegroundColor Yellow
docker-compose down 2>$null
docker rmi -f malintic_app-app malintic_app-api malintic_app-supervisor gestion_formations-app gestion_formations-api 2>$null
docker builder prune -f
docker image prune -f
Write-Host "  - Images Docker obsoletes purgees avec succes." -ForegroundColor Green

# 2. Nettoyage Vercel & Build cache
Write-Host "`n[2/4] Nettoyage des caches locaux et Vercel..." -ForegroundColor Yellow
if (Test-Path build\web) { Remove-Item -Recurse -Force build\web }
if (Test-Path .vercel\cache) { Remove-Item -Recurse -Force .vercel\cache }
Write-Host "  - Caches build et Vercel nettoyes." -ForegroundColor Green

# 3. Compilation Flutter Web
Write-Host "`n[3/4] Recompilation propre du bundle Web Flutter..." -ForegroundColor Yellow
flutter build web --release --pwa-strategy=none --no-tree-shake-icons
if ($LASTEXITCODE -ne 0) {
    Write-Host "[ERREUR] Echec de la compilation Flutter Web." -ForegroundColor Red
    exit 1
}

# 4. Reconstruction Docker sans cache
Write-Host "`n[4/4] Reconstruction Docker sans cache..." -ForegroundColor Yellow
docker-compose build --no-cache
if ($LASTEXITCODE -ne 0) {
    Write-Host "[ERREUR] Echec du build Docker." -ForegroundColor Red
    exit 1
}

Write-Host "`n================================================================" -ForegroundColor Cyan
Write-Host "  REDEPLOIEMENT TERMINE AVEC SUCCES !" -ForegroundColor Green
Write-Host "  - Lancer l'environnement local : docker-compose up -d"
Write-Host "  - Port Application Web         : http://localhost (ou :8000)"
Write-Host "  - Port API Backend Node        : http://localhost:5001"
Write-Host "  - Port Superviseur PRA / PCA   : http://localhost:5002"
Write-Host "  - Deploiement Vercel Cloud     : npx vercel --prod --force"
Write-Host "================================================================" -ForegroundColor Cyan
