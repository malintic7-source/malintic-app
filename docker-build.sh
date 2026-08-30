#!/bin/bash

# Docker Build & Deploy Script
# Usage: ./docker-build.sh [--no-cache] [--clean]

set -e

echo "🐳 Gestion Formations - Docker Build Script"
echo "==========================================="

# Parse arguments
NO_CACHE=""
CLEAN=false

while [[ $# -gt 0 ]]; do
  case $1 in
    --no-cache)
      NO_CACHE="--no-cache"
      echo "🔄 Build sans cache"
      shift
      ;;
    --clean)
      CLEAN=true
      echo "🧹 Mode nettoyage complet"
      shift
      ;;
    *)
      echo "Unknown option: $1"
      exit 1
      ;;
  esac
done

# Clean if requested
if [ "$CLEAN" = true ]; then
  echo "🧹 Nettoyage des anciennes images et volumes..."
  docker-compose down -v
  docker system prune -af
  echo "✅ Nettoyage terminé"
fi

# Stop running containers
echo "🛑 Arrêt des containers en cours..."
docker-compose down

# Build images
echo "🏗️  Construction des images Docker..."
docker-compose build $NO_CACHE

# Start services
echo "🚀 Démarrage des services..."
docker-compose up -d

# Wait for services to be healthy
echo "⏳ Attente du démarrage des services..."
sleep 5

# Check health
echo "🏥 Vérification de la santé des services..."

# Frontend health
if docker-compose exec -T app wget -q -O /dev/null http://127.0.0.1/ 2>/dev/null; then
  echo "✅ Frontend (malintic_app) - OK"
else
  echo "⚠️  Frontend (malintic_app) - En cours de démarrage..."
fi

# Backend health
if docker-compose exec -T api node -e "fetch('http://127.0.0.1:5001/api/health').then(r => process.exit(r.ok ? 0 : 1)).catch(() => process.exit(1))" 2>/dev/null; then
  echo "✅ Backend (malintic_api) - OK"
else
  echo "⚠️  Backend (malintic_api) - En cours de démarrage..."
fi

echo ""
echo "🎉 Déploiement terminé!"
echo "==========================================="
echo "📍 URLs d'accès:"
echo "   Frontend: http://localhost (ou http://localhost:8000)"
echo "   API:      http://localhost:5001"
echo ""
echo "📝 Commandes utiles:"
echo "   Logs:     docker-compose logs -f"
echo "   Stop:     docker-compose down"
echo "   Restart:  docker-compose restart"
echo ""
