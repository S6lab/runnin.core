#!/usr/bin/env bash
set -euo pipefail

PROJECT_ID="runnin-494520"
CHANNEL="staging"

echo "→ Build Flutter web..."
cd app
flutter build web --release --dart-define=API_URL=https://runnin-api-staging-rogiz7losq-rj.a.run.app
cd ..

echo "→ Deploy Firebase Hosting preview channel: $CHANNEL..."
node tool/firebase_hosting_deploy_gcloud.js "$PROJECT_ID" "$PROJECT_ID" "$CHANNEL" app/build/web

echo "✓ Deploy web staging concluído!"
echo ""
echo "🔗 URL do frontend staging:"
echo "https://runnin-494520--${CHANNEL}-5sd5wkho.web.app"
echo ""
echo "🔗 URL principal (live):"
echo "https://runnin-494520.web.app"
