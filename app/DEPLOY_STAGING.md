# Deploy Flutter frontend to Firebase Hosting staging

## Prerequisites
- Firebase CLI installed and authenticated
- `FIREBASE_TOKEN` environment variable set with CI token
- Firebase project: `runnin-staging-494520`

## Manual Deployment

### Get Firebase CI Token
```bash
firebase login:ci
```
Copy the token output.

### Setup and Deploy
```bash
cd app
export FIREBASE_TOKEN='your-token-from-above'
flutter build web --release --dart-define=FLUTTER_NODE_ENV=staging
firebase use staging
firebase deploy --only hosting:staging --non-interactive
```

## Automated Deployment (GitHub Actions)

Push to the `staging` branch or manually trigger the workflow.

### Required GitHub Secret
Add the following secret to your repository:
- `FIREBASE_STAGING_TOKEN` - Firebase CI token for staging project

Get the token by running `firebase login:ci`

## Staging URL
https://runnin-staging-494520.web.app

## Notes
- Build output goes to `build/web`
- Uses configuration from `firebase.staging.json` and `.firebaserc`

## See Also
For comprehensive documentation including setup steps and configuration details, see: `FIREBASE_STAGING_DEPLOYMENT.md`
