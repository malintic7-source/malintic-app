<#
Mise à jour applicative contrôlée.

Ne lance jamais `docker compose down`, ne supprime aucun volume, image ou
tunnel, et ne force pas la recréation si l'image n'a pas changé. Les données
opérationnelles restent dans le stockage partagé (Firestore) et les navigateurs
des utilisateurs ; le conteneur ne contient que les fichiers web compilés.
#>

[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $MyInvocation.MyCommand.Path
Set-Location $root
$service = 'gestion_formations'
$apiService = 'api'
$container = 'gestion_formations_app'

Write-Host "[1/4] Compilation de la version web..."
flutter build web --release
if ($LASTEXITCODE -ne 0) {
    throw "La compilation Flutter a échoué. La version actuellement en ligne est conservée."
}

Write-Host "[2/4] Construction de la nouvelle image..."
docker compose -p gestion_formations build $service $apiService
if ($LASTEXITCODE -ne 0) {
    throw "La construction Docker a échoué. La version actuellement en ligne est conservée."
}

Write-Host "[3/4] Mise à jour contrôlée du seul service applicatif..."
# Sans `down` ni suppression de volume : Docker conserve les données locales
# de l'API et le tunnel. Les deux services sont mis à jour de façon contrôlée.
docker compose -p gestion_formations up -d --no-deps $apiService
if ($LASTEXITCODE -ne 0) {
    throw "La mise à jour de l'API locale a échoué."
}
docker compose -p gestion_formations up -d --no-deps $service
if ($LASTEXITCODE -ne 0) {
    throw "La mise à jour Docker a échoué."
}

Write-Host "[4/4] Vérification de santé..."
$deadline = (Get-Date).AddMinutes(2)
do {
    $health = docker inspect --format '{{if .State.Health}}{{.State.Health.Status}}{{else}}{{.State.Status}}{{end}}' $container 2>$null
    if ($health -eq 'healthy') { break }
    if ((Get-Date) -ge $deadline) {
        docker logs --tail 40 $container
        throw "La nouvelle version ne répond pas sainement. Aucune donnée n'a été supprimée."
    }
    Start-Sleep -Seconds 3
} while ($true)

$response = Invoke-WebRequest -UseBasicParsing -Uri 'http://localhost:8080/' -TimeoutSec 20
if ($response.StatusCode -ne 200) {
    throw "Le contrôle HTTP local a échoué (code $($response.StatusCode))."
}

Write-Host "Mise à jour réussie : application saine (HTTP $($response.StatusCode))."
Write-Host "Le tunnel ngrok existant n'a pas été modifié."
