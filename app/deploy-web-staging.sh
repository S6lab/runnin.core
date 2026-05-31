#!/bin/bash
set -e

echo "Deploying Flutter web to Firebase Hosting staging..."

cd "$(dirname "$0")"

if ! command -v flutter &> /dev/null; then
    echo "Error: Flutter not found"
    exit 1
fi

if ! command -v firebase &> /dev/null; then
    echo "Error: Firebase CLI not found"
    exit 1
fi

echo "Installing dependencies..."
flutter pub get

echo "Building Flutter web for staging..."
flutter build web --release --dart-define=FLUTTER_NODE_ENV=staging

echo "Checking for Firebase authentication..."

if [ -z "$FIREBASE_TOKEN" ]; then
    echo "Error: FIREBASE_TOKEN not set. Please set it to your Firebase CI token."
    echo ""
    echo "To get your Firebase CI token:"
    echo "1. Run: firebase login:ci"
    echo "2. Copy the token returned"
    echo "3. Set it as an environment variable: export FIREBASE_TOKEN='your-token'"
    exit 1
fi

echo "Deploying to Firebase Hosting staging..."
firebase use staging
firebase deploy --only hosting:staging --non-interactive

echo "✓ Deployment complete!"
echo ""
echo "Staging URL: https://runnin-staging-494520.web.app"
