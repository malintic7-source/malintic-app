# Docker Build & Deploy Script for Windows
# Usage: .\docker-build.ps1 [-NoCache] [-Clean]

param(
    [switch]$NoCache,
    [switch]$Clean
)

Write-Host "🐳 Gestion Formations - Docker Build Script" -ForegroundColor Cyan
Write-Host "===========================================" -ForegroundColor Cyan

# Clean if requested
if ($Clean) {
    Write-Host "🧹 Nettoyage des anciennes images et volumes..." -ForegroundColor Yellow
    docker-compose down -v
    docker system prune -af
    Write-Host "✅ Nettoyage terminé" -ForegroundColor Green
}

# Stop running containers
Write-Host "🛑 Arrêt des containers en cours..." -ForegroundColor Yellow
docker-compose down

# Build images
Write-Host "🏗️  Construction des images Docker..." -ForegroundColor Yellow
if ($NoCache) {
    docker-compose build --no-cache
} else {
    docker-compose build
}

# Start services
Write-Host "🚀 Démarrage des services..." -ForegroundColor Yellow
docker-compose up -d

# Wait for services to be healthy
Write-Host "⏳ Attente du démarrage des services..." -ForegroundColor Yellow
Start-Sleep -Seconds 5

# Check health
Write-Host "🏥 Vérification de la santé des services..." -ForegroundColor Yellow

# Frontend health
try {
    docker-compose exec -T app wget -q -O /dev/null http://127.0.0.1/ 2>$null
    Write-Host "✅ Frontend (malintic_app) - OK" -ForegroundColor Green
} catch {
    Write-Host "⚠️  Frontend (malintic_app) - En cours de démarrage..." -ForegroundColor Yellow
}

# Backend health
try {
    docker-compose exec -T api node -e "fetch('http://127.0.0.1:5001/api/health').then(r => process.exit(r.ok ? 0 : 1)).catch(() => process.exit(1))" 2>$null
    Write-Host "✅ Backend (malintic_api) - OK" -ForegroundColor Green
} catch {
    Write-Host "⚠️  Backend (malintic_api) - En cours de démarrage..." -ForegroundColor Yellow
}

Write-Host ""
Write-Host "🎉 Déploiement terminé!" -ForegroundColor Green
Write-Host "===========================================" -ForegroundColor Cyan
Write-Host "📍 URLs d'accès:" -ForegroundColor Cyan
Write-Host "   Frontend: http://localhost (ou http://localhost:8000)" -ForegroundColor White
Write-Host "   API:      http://localhost:5001" -ForegroundColor White
Write-Host ""
Write-Host "📝 Commandes utiles:" -ForegroundColor Cyan
Write-Host "   Logs:     docker-compose logs -f" -ForegroundColor White
Write-Host "   Stop:     docker-compose down" -ForegroundColor White
Write-Host "   Restart:  docker-compose restart" -ForegroundColor White
Write-Host ""
