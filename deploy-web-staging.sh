#!/bin/bash
set -e

echo "Deploying Flutter web to Firebase Hosting staging..."

if ! command -v firebase &> /dev/null; then
    echo "Error: Firebase CLI not found"
    exit 1
fi

echo "Building Flutter web..."
# CRÍTICO: aponta o app pro server staging (sem isso usa o default prod URL e
# bate em produção desatualizada — gera 404 em endpoints novos como /admin/*).
# FIREBASE_VAPID_KEY ativa Web Push (FCM) no browser; sem ela o token web
# nunca é obtido e o /notifications/devices não recebe nada vindo do web.
flutter build web --release \
  --dart-define=API_BASE_URL=https://runnin-api-staging-rogiz7losq-rj.a.run.app \
  --dart-define=FIREBASE_VAPID_KEY=BE1oX84SuJLSCWO-JqYSyIFEtCEPj8d4ol3xWlwPHmBp_ncd372Fsau6Fr5mYxIjzpWKfg5KZcM8ueoMQu78P5Q

if [ -z "$GCLOUD_SERVICE_ACCOUNT_KEY" ]; then
    echo "Error: GCLOUD_SERVICE_ACCOUNT_KEY not set"
    exit 1
fi

echo "Authenticating with Firebase..."
echo "$GCLOUD_SERVICE_ACCOUNT_KEY" | base64 -d > /tmp/service-account-key.json
gcloud auth activate-service-account --key-file=/tmp/service-account-key.json
firebase use staging
firebase deploy --only hosting:staging

echo "✓ Deployment complete!"
