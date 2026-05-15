# Deploy Flutter frontend to Firebase Hosting staging

## Commands
```bash
cd app
flutter build web --release --dart-define=FLUTTER_NODE_ENV=staging
firebase deploy --only hosting:staging --non-interactive
```

## Notes
- Requires Firebase CLI configured with staging project access
- Build output goes to `build/web`
- Staging URL: https://runnin-staging.web.app
