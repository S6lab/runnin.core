#!/usr/bin/env bash
set -euo pipefail

echo "→ Build Flutter web..."
cd app
flutter build web --release
cd ..

echo "→ Deploy Firebase Hosting (runnin-494520)..."
node tool/firebase_hosting_deploy_gcloud.js runnin-494520 runnin-494520 app/build/web

echo "✓ Deploy web concluído!"
