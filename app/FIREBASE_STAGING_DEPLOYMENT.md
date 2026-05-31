# Firebase Staging Deployment Setup - Complete

## Status: Ready for Deployment ✓

### Setup Completed
1. ✓ Firebase project created: `runnin-staging-494520`
2. ✓ Web app added to staging project
3. ✓ `.firebaserc` configured with project aliases
4. ✓ `firebase.staging.json` created
5. ✓ `lib/firebase_staging_options.dart` created
6. ✓ GitHub Actions workflow created: `.github/workflows/deploy-staging.yml`

### Deployment Configuration Files
- **.firebaserc**: Project aliases (production & staging)
- **firebase.json**: Production hosting config
- **firebase.staging.json**: Staging hosting config
- **lib/firebase_staging_options.dart**: Staging Firebase options

### Deployment Methods

#### Manual Deployment
```bash
cd app
export FIREBASE_TOKEN='your-ci-token'
flutter build web --release --dart-define=FLUTTER_NODE_ENV=staging
firebase deploy --project runnin-staging-494520
```

#### Automated (GitHub Actions)
```bash
# Push to staging branch
git push origin staging

# OR manually trigger workflow in GitHub
```

### Required Secrets for CI/CD
- `FIREBASE_STAGING_TOKEN` - Get from Firebase Console → Project Settings → Service Accounts → Generate New Private Key

### Deployment URLs
- **Staging**: https://runnin-staging-494520.web.app
- **Production**: https://runnin-494520.web.app

### Files Structure
```
app/
├── .firebaserc                    # Project aliases
├── firebase.json                  # Production config
├── firebase.staging.json          # Staging config
├── lib/
│   ├── firebase_options.dart      # Production options
│   └── firebase_staging_options.dart  # Staging options
├── .github/workflows/
│   └── deploy-staging.yml         # CI/CD workflow
└── DEPLOY_STAGING.md              # This file
```

## Next Steps

1. **Get Firebase CI Token**
   ```bash
   firebase login:ci
   ```

2. **Add Secret to GitHub**
   - Go to Repository Settings → Secrets and variables → Actions
   - Add `FIREBASE_STAGING_TOKEN` with the token value

3. **Deploy**
   - Push to `staging` branch OR manually trigger workflow
   - Monitor deployment in GitHub Actions

## Verification Checklist
- [x] Firebase project created for staging
- [x] Web app added to staging project  
- [x] Service account created with correct permissions
- [x] GitHub secrets configuration documented
- [x] GitHub Actions workflow created
- [ ] Staging build tested (requires Firebase token)
- [ ] Production build tested
