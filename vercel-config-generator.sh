#!/usr/bin/env bash
# Script pour générer vercel.json dynamiquement avec les bonnes URLs d'API
# Usage: ./vercel-config-generator.sh --api-url "https://malintic-api.onrender.com"

set -e

# Couleurs pour output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Parse arguments
API_URL="${VERCEL_API_URL}"
while [[ $# -gt 0 ]]; do
  case $1 in
    --api-url)
      API_URL="$2"
      shift 2
      ;;
    *)
      echo -e "${RED}❌ Unknown option: $1${NC}"
      exit 1
      ;;
  esac
done

if [ -z "$API_URL" ]; then
  echo -e "${RED}❌ ERROR: API URL not provided${NC}"
  echo -e "${YELLOW}Usage: $0 --api-url 'https://malintic-api.onrender.com'${NC}"
  echo ""
  echo -e "${CYAN}Environment variables accepted:${NC}"
  echo "  VERCEL_API_URL  = Backend URL (Ex: https://malintic-api.onrender.com)"
  exit 1
fi

# Generate vercel.json
cat > vercel.json << EOF
{
  "outputDirectory": "build/web",
  "cleanUrls": true,
  "framework": null,
  "buildCommand": null,
  "installCommand": null,
  "headers": [
    {
      "source": "/(index.html|flutter_bootstrap.js|flutter_service_worker.js|version.json|manifest.json)",
      "headers": [
        {
          "key": "Cache-Control",
          "value": "no-cache, no-store, must-revalidate, max-age=0"
        },
        {
          "key": "Pragma",
          "value": "no-cache"
        },
        {
          "key": "Expires",
          "value": "0"
        }
      ]
    },
    {
      "source": "/(assets/.*|images/.*|canvaskit/.*|main\\\\.dart\\\\.js|flutter\\\\.js|.*\\\\.wasm|.*\\\\.png|.*\\\\.jpg|.*\\\\.jpeg|.*\\\\.svg|.*\\\\.ico|.*\\\\.ttf|.*\\\\.otf|.*\\\\.frag)",
      "headers": [
        {
          "key": "Cache-Control",
          "value": "no-cache, must-revalidate"
        }
      ]
    }
  ],
  "rewrites": [
    {
      "source": "/api/:path*",
      "destination": "$API_URL/api/:path*"
    },
    {
      "source": "/formation.html",
      "destination": "/formation.html"
    },
    {
      "source": "/((?!api/|.*\\\\.[\\\\w]+\$).*)",
      "destination": "/index.html"
    }
  ]
}
EOF

echo -e "${GREEN}✅ Configuration generated for:${NC}"
echo -e "${CYAN}   API Backend: $API_URL${NC}"
echo ""
echo -e "${GREEN}✅ vercel.json generated successfully${NC}"
echo -e "${CYAN}   Commit before push: git add vercel.json && git commit -m 'chore: update API URL in vercel config'${NC}"
