# Firebase Google Sign-In and LLM API Configuration

## Status: Requires Credentials and Console Access

This document outlines the steps needed to complete the production configuration for Firebase Google Sign-In and Gemini LLM API.

## Prerequisites Required

### 1. Gemini API Key
- **What**: Valid Gemini API key from Google AI Studio
- **Where to get**: https://makersuite.google.com/app/apikey
- **Project**: runnin-494520
- **Usage**: Backend LLM operations (coach, plan generation, reports)

### 2. Google Cloud Authentication
- **What**: Authenticated gcloud CLI
- **Project**: runnin-494520
- **Region**: southamerica-east1
- **Service**: runnin-api

### 3. Firebase Console Access
- **What**: Firebase Console access for enabling auth providers
- **URL**: https://console.firebase.google.com/project/runnin-494520
- **Required permission**: Editor or Owner role

## Configuration Steps

### Step 1: Enable Google Sign-In in Firebase Console

**Manual Action Required** (Firebase CLI doesn't support auth provider configuration):

1. Open Firebase Console: https://console.firebase.google.com/project/runnin-494520
2. Navigate to: **Authentication** → **Sign-in method**
3. Find "Google" in the providers list
4. Click "Enable"
5. Configure:
   - **Public-facing name**: "Runnin"
   - **Support email**: (select project support email)
6. Click "Save"

**Verification**:
```bash
# Check if Google provider is enabled (requires firebase auth)
firebase auth:export /tmp/auth-check.json --project runnin-494520
```

### Step 2: Configure Gemini API Key in Cloud Run

**Automated Script** (requires authenticated gcloud):

```bash
#!/usr/bin/env bash
# File: scripts/configure-gemini.sh

PROJECT_ID="runnin-494520"
SERVICE_NAME="runnin-api"
REGION="southamerica-east1"

# Read GEMINI_API_KEY from environment or prompt
if [[ -z "$GEMINI_API_KEY" ]]; then
  echo -n "Enter Gemini API Key: "
  read -s GEMINI_API_KEY
  echo
fi

# Update Cloud Run service environment variables
gcloud run services update "$SERVICE_NAME" \
  --project="$PROJECT_ID" \
  --region="$REGION" \
  --set-env-vars="LLM_REALTIME_PROVIDER=gemini,LLM_ASYNC_PROVIDER=gemini,GEMINI_API_KEY=$GEMINI_API_KEY" \
  --quiet

echo "✓ Cloud Run environment variables updated"

# Verify configuration
echo "→ Current environment variables:"
gcloud run services describe "$SERVICE_NAME" \
  --project="$PROJECT_ID" \
  --region="$REGION" \
  --format="value(spec.template.spec.containers[0].env)" | grep -E "(LLM|GEMINI)"
```

### Step 3: Authenticate gcloud CLI

**One-time setup**:

```bash
# Login to Google Cloud
gcloud auth login

# Set default project
gcloud config set project runnin-494520

# Verify authentication
gcloud auth list
```

### Step 4: Test Configuration

**Verification script** (requires authentication):

```bash
#!/usr/bin/env bash
# File: scripts/verify-production-config.sh

set -euo pipefail

PROJECT_ID="runnin-494520"
SERVICE_NAME="runnin-api"
REGION="southamerica-east1"
API_URL="https://runnin-api-rogiz7losq-rj.a.run.app"

echo "→ Checking Cloud Run service status..."
gcloud run services describe "$SERVICE_NAME" \
  --project="$PROJECT_ID" \
  --region="$REGION" \
  --format="value(status.url)" > /dev/null && echo "✓ Service is running"

echo "→ Checking environment variables..."
ENV_CHECK=$(gcloud run services describe "$SERVICE_NAME" \
  --project="$PROJECT_ID" \
  --region="$REGION" \
  --format="value(spec.template.spec.containers[0].env)")

echo "$ENV_CHECK" | grep -q "LLM_REALTIME_PROVIDER" && echo "✓ LLM_REALTIME_PROVIDER is set"
echo "$ENV_CHECK" | grep -q "GEMINI_API_KEY" && echo "✓ GEMINI_API_KEY is set"

echo "→ Testing backend health..."
curl -s "$API_URL/health" | jq '.' && echo "✓ Backend is healthy"

echo "→ Testing LLM endpoint (requires Firebase auth token)..."
echo "  Manual test: Use Firebase Auth to get a token, then:"
echo "  curl -H 'Authorization: Bearer <TOKEN>' $API_URL/v1/coach/chat"

echo ""
echo "✓ Configuration verification complete"
```

## Execution Plan

1. **Board provides Gemini API key** (security-sensitive)
2. **Manual step**: Enable Google Sign-In in Firebase Console (requires browser)
3. **Automated**: Run `scripts/configure-gemini.sh` (requires gcloud auth)
4. **Automated**: Run `scripts/verify-production-config.sh`
5. **Manual test**: Verify Google Sign-In works in mobile app
6. **Manual test**: Verify LLM endpoints respond correctly

## Security Considerations

- **Gemini API Key**: Never commit to repository, use environment variables only
- **Firebase Admin credentials**: Already configured via `.env.production` (keep private key secure)
- **Cloud Run IAM**: Service account `runnin-api@runnin-494520.iam.gserviceaccount.com` has required permissions
- **Google Sign-In**: OAuth credentials managed by Firebase (auto-configured on enable)

## Cost Implications

- **Gemini API**: Pay-per-use (estimated $20-50/month for MVP usage)
- **Cloud Run**: Already deployed, env var updates are free
- **Firebase Auth**: Free tier covers MVP usage

## Rollback Plan

If issues arise:

```bash
# Revert to previous env vars
gcloud run services update runnin-api \
  --project=runnin-494520 \
  --region=southamerica-east1 \
  --clear-env-vars LLM_REALTIME_PROVIDER,LLM_ASYNC_PROVIDER,GEMINI_API_KEY

# Disable Google Sign-In
# Manual: Firebase Console → Authentication → Sign-in method → Google → Disable
```

## Support

- **Firebase Console**: https://console.firebase.google.com/project/runnin-494520
- **Cloud Run Console**: https://console.cloud.google.com/run?project=runnin-494520
- **Gemini API Console**: https://console.cloud.google.com/apis/api/generativelanguage.googleapis.com?project=runnin-494520
