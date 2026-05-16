# Firebase Deployment Guide

## ✅ Production + Staging Environment Setup Complete

### Current Status
- ✓ **Production Project**: `runnin-494520`
- ✓ **Staging Project**: `runnin-staging-494520`
- ✓ **Staging Hosting Site**: https://runnin-staging-494520.web.app

### 1. GitHub Actions Deployment Workflow

The staging deployment workflow is configured at `.github/workflows/deploy-staging.yml`:

**Triggers:**
- Push to `staging` branch (auto-deploy)
- Manual trigger via GitHub Actions UI

**Deployment Target:** `runnin-staging-494520`




### 2. Deploy to Staging

**GitHub Actions (Auto-deploy)**:
```bash
# Push to staging branch
git push origin staging

#-or- Trigger manually via GitHub Actions UI
```

**Local Deployment**:
```bash
flutter build web --dart-define=FLAVOR=staging -t lib/main_staging.dart
firebase deploy --project runnin-staging-494520
```

### 3. Required GitHub Secret

Add `FIREBASE_STAGING_TOKEN` to your repository:
1. Go to GitHub: Settings → Secrets and variables → Actions
2. Create new secret: `FIREBASE_STAGING_TOKEN`
3. Get token from Firebase Console → Project Settings → Service Accounts → Generate New Private Key

## Deployment Summary

| Environment | Firebase Project | Hosting URL | Branch |
|------------|-----------------|-------------|--------|
| Production | `runnin-494520` | https://runnin.web.app | main |
| Staging | `runnin-staging-494520` | https://runnin-staging-494520.web.app | staging |
