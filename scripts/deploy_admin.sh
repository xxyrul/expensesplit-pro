#!/usr/bin/env bash
set -euo pipefail

# Deploy admin_web to Firebase Hosting
# Usage:
#   ./scripts/deploy_admin.sh
# Environment variables (optional):
#   FIREBASE_PROJECT - Firebase project id to deploy to (overrides firebase.json)
#   FIREBASE_API_KEY, FIREBASE_APP_ID, FIREBASE_MESSAGING_SENDER_ID, FIREBASE_PROJECT_ID,
#   FIREBASE_AUTH_DOMAIN, FIREBASE_STORAGE_BUCKET - if set, passed to flutter build as --dart-define

ROOT_DIR=$(cd "$(dirname "$0")/.." && pwd)
ADMIN_DIR="$ROOT_DIR/admin_web"

echo "Building admin_web..."
cd "$ADMIN_DIR"

# Build dart-define flags if provided
DF_FLAGS=()
maybe_add_def() {
  local name="$1"
  local val="${!name:-}"
  if [ -n "$val" ]; then
    DF_FLAGS+=("--dart-define=${name}=${val}")
  fi
}

maybe_add_def FIREBASE_API_KEY
maybe_add_def FIREBASE_APP_ID
maybe_add_def FIREBASE_MESSAGING_SENDER_ID
maybe_add_def FIREBASE_PROJECT_ID
maybe_add_def FIREBASE_AUTH_DOMAIN
maybe_add_def FIREBASE_STORAGE_BUCKET

echo "Running flutter pub get..."
flutter pub get

echo "Running flutter build web..."
flutter build web --release -t lib/main.dart "${DF_FLAGS[@]:-}"

echo "Deploying to Firebase Hosting..."
cd "$ROOT_DIR"

if ! command -v firebase >/dev/null 2>&1; then
  echo "firebase cli not found — installing via npm..."
  npm install -g firebase-tools
fi

if [ -n "${FIREBASE_PROJECT:-}" ]; then
  firebase deploy --only hosting --project "$FIREBASE_PROJECT"
else
  firebase deploy --only hosting
fi

echo "Deployment finished."
