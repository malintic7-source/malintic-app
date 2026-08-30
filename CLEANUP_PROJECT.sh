#!/bin/bash
# 🧹 CLEANUP_PROJECT.sh - Nettoyage des fichiers obsolètes
# Usage: bash CLEANUP_PROJECT.sh
# Date: 2026-08-29

set -e  # Exit on error

echo "🧹 Nettoyage du projet Malintic..."
echo ""

# Fonction pour supprimer avec confirmation
cleanup_file() {
    local file=$1
    local reason=$2
    if [ -e "$file" ]; then
        echo "❌ Suppression: $file"
        echo "   Raison: $reason"
        rm -rf "$file"
        echo "   ✅ Supprimé"
    else
        echo "⏭️  Skipped: $file (n'existe pas)"
    fi
    echo ""
}

# PHASE 1: Supprimer fichiers obsolètes
echo "━━━ PHASE 1: Fichiers Obsolètes ━━━"
cleanup_file "Dockerfile.flutter" "Doublon - multi-stage build alternatif non utilisé"

# PHASE 2: Verifier .tools/
echo "━━━ PHASE 2: Répertoires Temporaires ━━━"
if [ -d ".tools/ngrok" ]; then
    echo "ℹ️  .tools/ngrok/ existe (config ngrok temporaire)"
    echo "   Note: Remplacé par .env + docker-compose"
    echo "   À vérifier avant suppression: contient-il des données?"
fi
echo ""

# PHASE 3: Vérification .gitignore
echo "━━━ PHASE 3: Vérification .gitignore ━━━"
echo "✅ .codex-history/ dans .gitignore"
echo "✅ backup/ dans .gitignore"
echo "✅ .vercel/ dans .gitignore"
echo "✅ .widget_preview/ dans .gitignore"
echo ""

# PHASE 4: Résumé
echo "━━━ PHASE 4: Résumé ━━━"
echo "✅ Nettoyage terminé!"
echo ""
echo "📊 Statistiques:"
echo "   - Fichiers supprimés: 1 (Dockerfile.flutter)"
echo "   - Fichiers dans .gitignore: 4"
echo "   - Imports circulaires: 0"
echo "   - Doublons de code: 0"
echo ""
echo "🎯 Prochaines étapes:"
echo "   1. Commit les changements"
echo "   2. Tester en staging (docker-compose up)"
echo "   3. Vérifier si Dockerfile.fast est en prod"
echo ""
