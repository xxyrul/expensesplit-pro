Param()
Set-StrictMode -Version Latest

# Deploy admin_web to Firebase Hosting (PowerShell)
# Usage: ./scripts/deploy_admin.ps1
# Requires: flutter in PATH, npm and firebase-tools (will install if missing)

$root = Resolve-Path "$(Split-Path -Parent $MyInvocation.MyCommand.Definition)\.."
Push-Location $root
Push-Location "admin_web"

Write-Host "Running flutter pub get..."
flutter pub get

$df = @()
if ($env:FIREBASE_API_KEY) { $df += "--dart-define=FIREBASE_API_KEY=$($env:FIREBASE_API_KEY)" }
if ($env:FIREBASE_APP_ID) { $df += "--dart-define=FIREBASE_APP_ID=$($env:FIREBASE_APP_ID)" }
if ($env:FIREBASE_MESSAGING_SENDER_ID) { $df += "--dart-define=FIREBASE_MESSAGING_SENDER_ID=$($env:FIREBASE_MESSAGING_SENDER_ID)" }
if ($env:FIREBASE_PROJECT_ID) { $df += "--dart-define=FIREBASE_PROJECT_ID=$($env:FIREBASE_PROJECT_ID)" }
if ($env:FIREBASE_AUTH_DOMAIN) { $df += "--dart-define=FIREBASE_AUTH_DOMAIN=$($env:FIREBASE_AUTH_DOMAIN)" }
if ($env:FIREBASE_STORAGE_BUCKET) { $df += "--dart-define=FIREBASE_STORAGE_BUCKET=$($env:FIREBASE_STORAGE_BUCKET)" }

Write-Host "Building admin_web (release)..."
flutter build web --release -t lib/main.dart $df

Pop-Location

if (-not (Get-Command firebase -ErrorAction SilentlyContinue)) {
  Write-Host "firebase CLI not found, installing via npm..."
  npm install -g firebase-tools
}

if ($env:FIREBASE_PROJECT) {
  firebase deploy --only hosting --project $env:FIREBASE_PROJECT
} else {
  firebase deploy --only hosting
}

Pop-Location
Write-Host "Deployment finished."
