#!/usr/bin/env pwsh
# Script pour générer vercel.json dynamiquement avec les bonnes URLs d'API
# Usage: .\vercel-config-generator.ps1

param(
    [string]$ApiUrl = $env:VERCEL_API_URL,
    [string]$Environment = $env:NODE_ENV
)

if (-not $ApiUrl) {
    Write-Host "❌ ERREUR: VERCEL_API_URL non définie" -ForegroundColor Red
    Write-Host "Usage: .\vercel-config-generator.ps1 -ApiUrl 'https://malintic-api.onrender.com'" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "Variables d'env acceptées:" -ForegroundColor Cyan
    Write-Host "  VERCEL_API_URL  = URL du backend (Ex: https://malintic-api.onrender.com)"
    Write-Host "  NODE_ENV        = Environnement (development|production)"
    exit 1
}

$configTemplate = @{
    outputDirectory = "build/web"
    cleanUrls       = $true
    framework       = $null
    buildCommand    = $null
    installCommand  = $null
    headers         = @(
        @{
            source  = "/(index.html|flutter_bootstrap.js|flutter_service_worker.js|version.json|manifest.json)"
            headers = @(
                @{ key = "Cache-Control"; value = "no-cache, no-store, must-revalidate, max-age=0" },
                @{ key = "Pragma"; value = "no-cache" },
                @{ key = "Expires"; value = "0" }
            )
        },
        @{
            source  = "/(assets/.*|images/.*|canvaskit/.*|main\.dart\.js|flutter\.js|.*\.wasm|.*\.png|.*\.jpg|.*\.jpeg|.*\.svg|.*\.ico|.*\.ttf|.*\.otf|.*\.frag)"
            headers = @(
                @{ key = "Cache-Control"; value = "no-cache, must-revalidate" }
            )
        }
    )
    rewrites        = @(
        @{
            source      = "/api/:path*"
            destination = "$ApiUrl/api/:path*"
        },
        @{
            source      = "/formation.html"
            destination = "/formation.html"
        },
        @{
            source      = "/((?!api/|.*\.[\\w]+`$).*)"
            destination = "/index.html"
        }
    )
}

$configJson = ConvertTo-Json $configTemplate -Depth 10

Write-Host "✅ Configuration générée pour:" -ForegroundColor Green
Write-Host "   API Backend: $ApiUrl" -ForegroundColor Cyan
Write-Host ""

$configJson | Out-File -FilePath "vercel.json" -Encoding utf8 -Force
Write-Host "✅ vercel.json généré avec succès" -ForegroundColor Green
Write-Host "   À commiter avant : git add vercel.json && git commit -m 'chore: update API URL in vercel config'"
