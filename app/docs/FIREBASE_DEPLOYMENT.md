# Firebase Deployment Guide

## Setup Steps

### 1. Create Firebase Project for Staging

```bash
# Create staging project
firebase projects:create runnin-staging-494520 \
  --display-name="Runnin Staging"
```

### 2. Add Web App to Staging Project

```bash
# Install Firebase CLI
npm install -g firebase-tools

# Login to Firebase
firebase login

# Initialize Firebase project
firebase projects:add web-app runnin-staging-494520

# Copy webhook URL from Firebase Console
```

### 3. Build and Test Staging Web App

```bash
# Install pub dependencies
flutter pub get

# Build for staging environment
flutter run --release -d chrome --dart-define=FLAVOR=staging

# Test build
flutter build web --dart-define=FLAVOR=staging -t lib/main_staging.dart
```

### 4. Configure Firebase for Web

Edit `web/staging_index.html` and add Firebase config.

### 5. Deploy from Local Machine

```bash
# Login to Firebase
firebase login

# Set staging project as default
firebase use add
# Select 'runnin-staging-494520'

# Deploy to staging
flutter build web --dart-define=FLAVOR=staging -t lib/main_staging.dart
firebase deploy --project runnin-staging-494520

# For production
flutter build web
firebase deploy --project runnin-494520
```

### 6. Set up GitHub Secrets

In your repository settings, add:
1. `FIREBASE_STAGING_TOKEN`
2. `FIREBASE_PROD_TOKEN`

Get tokens from Google Cloud Console > IAM & Admin > Service Accounts.

### 7. GitHub Actions Deployments

**Staging**: Push to `staging` branch or manual trigger
**Production**: Push to `main` branch or manual trigger

## Verification Checklist

- [ ] Firebase project created for staging
- [ ] Web app added to staging project
- [ ] Service account created with correct permissions
- [ ] GitHub secrets configured
- [ ] GitHub Actions workflows deployed
- [ ] Staging build succeeds
- [ ] Production build succeeds
