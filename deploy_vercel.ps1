# Script de déploiement Vercel Production pour M@LINTIC-APP
# Approche : Pré-compilation Locale Flutter + Envoi Vercel CLI

$ErrorActionPreference = "Stop"
Set-Location -Path $PSScriptRoot

Write-Host "======================================================================" -ForegroundColor Cyan
Write-Host "  DEPLOIEMENT VERCEL PRODUCTION - M@LINTIC-APP" -ForegroundColor Cyan
Write-Host "  Approche : Pre-compilation Locale Flutter + Envoi Vercel CLI" -ForegroundColor Cyan
Write-Host "======================================================================" -ForegroundColor Cyan
Write-Host ""

# 1. Vérification de Flutter
Write-Host "[1/3] Verification de l'environnement Flutter..." -ForegroundColor Yellow
if (-not (Get-Command flutter -ErrorAction SilentlyContinue)) {
    Write-Host "[ERREUR] Flutter n'est pas installe ou n'est pas dans le PATH." -ForegroundColor Red
    exit 1
}
Write-Host "[OK] Flutter detecte." -ForegroundColor Green

# 2. Compilation Flutter Web Release
Write-Host ""
Write-Host "[2/3] Compilation du paquet Flutter Web Release..." -ForegroundColor Yellow
flutter build web --release
if ($LASTEXITCODE -ne 0) {
    Write-Host "[ERREUR] La compilation Flutter Web a echoue." -ForegroundColor Red
    exit 1
}
Write-Host "[OK] Compilation terminee avec succes dans build/web." -ForegroundColor Green

# 3. Déploiement direct sur Vercel
Write-Host ""
Write-Host "[3/3] Envoi et activation sur les serveurs Edge de Vercel..." -ForegroundColor Yellow
npx -y vercel --prod --yes
if ($LASTEXITCODE -ne 0) {
    Write-Host "[ERREUR] Le deploiement Vercel a echoue." -ForegroundColor Red
    exit 1
}

Write-Host ""
Write-Host "======================================================================" -ForegroundColor Green
Write-Host "  DEPLOIEMENT VERCEL REUSSI ET EN LIGNE !" -ForegroundColor Green
Write-Host "======================================================================" -ForegroundColor Green
Write-Host "  Application Principale : https://malintic-app.vercel.app" -ForegroundColor Cyan
Write-Host "  Page Inscription SFP5  : https://malintic-app.vercel.app/formation?id=form_sfp_2026" -ForegroundColor Cyan
Write-Host "======================================================================" -ForegroundColor Green
Write-Host ""
