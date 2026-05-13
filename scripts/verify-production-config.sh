#!/usr/bin/env bash
set -euo pipefail

PROJECT_ID="runnin-494520"
SERVICE_NAME="runnin-api"
REGION="southamerica-east1"
API_URL="https://runnin-api-rogiz7losq-rj.a.run.app"

echo "==================================="
echo "Production Configuration Verification"
echo "==================================="
echo ""

# Check if gcloud is authenticated
if ! gcloud auth list --filter=status:ACTIVE --format="value(account)" | grep -q .; then
  echo "❌ Error: gcloud is not authenticated"
  echo "Please run: gcloud auth login"
  exit 1
fi

echo "→ Checking Cloud Run service status..."
SERVICE_URL=$(gcloud run services describe "$SERVICE_NAME" \
  --project="$PROJECT_ID" \
  --region="$REGION" \
  --format="value(status.url)" 2>/dev/null || echo "")

if [[ -n "$SERVICE_URL" ]]; then
  echo "✓ Service is running"
  echo "  URL: $SERVICE_URL"
else
  echo "❌ Service not found or not running"
  exit 1
fi

echo ""
echo "→ Checking environment variables..."
ENV_VARS=$(gcloud run services describe "$SERVICE_NAME" \
  --project="$PROJECT_ID" \
  --region="$REGION" \
  --format="value(spec.template.spec.containers[0].env)")

# Check LLM configuration
if echo "$ENV_VARS" | grep -q "LLM_REALTIME_PROVIDER"; then
  REALTIME_PROVIDER=$(echo "$ENV_VARS" | grep "LLM_REALTIME_PROVIDER" | cut -d'=' -f2)
  echo "✓ LLM_REALTIME_PROVIDER = $REALTIME_PROVIDER"
else
  echo "⚠ LLM_REALTIME_PROVIDER not set"
fi

if echo "$ENV_VARS" | grep -q "LLM_ASYNC_PROVIDER"; then
  ASYNC_PROVIDER=$(echo "$ENV_VARS" | grep "LLM_ASYNC_PROVIDER" | cut -d'=' -f2)
  echo "✓ LLM_ASYNC_PROVIDER = $ASYNC_PROVIDER"
else
  echo "⚠ LLM_ASYNC_PROVIDER not set"
fi

if echo "$ENV_VARS" | grep -q "GEMINI_API_KEY"; then
  echo "✓ GEMINI_API_KEY = [REDACTED]"
else
  echo "❌ GEMINI_API_KEY not set"
fi

echo ""
echo "→ Testing backend health endpoint..."
if command -v jq &> /dev/null; then
  if HEALTH_RESPONSE=$(curl -s -f "$API_URL/health" 2>/dev/null); then
    echo "$HEALTH_RESPONSE" | jq '.'
    echo "✓ Backend is healthy"
  else
    echo "❌ Health endpoint failed"
  fi
else
  if curl -s -f "$API_URL/health" &>/dev/null; then
    echo "✓ Backend is responding (install jq for detailed output)"
  else
    echo "❌ Health endpoint failed"
  fi
fi

echo ""
echo "→ Checking Firebase configuration..."
if echo "$ENV_VARS" | grep -q "FIREBASE_PROJECT_ID=runnin-494520"; then
  echo "✓ FIREBASE_PROJECT_ID is correctly set"
else
  echo "⚠ FIREBASE_PROJECT_ID might not be set"
fi

echo ""
echo "==================================="
echo "Manual Verification Steps"
echo "==================================="
echo ""
echo "1. Firebase Google Sign-In:"
echo "   • Open: https://console.firebase.google.com/project/runnin-494520/authentication/providers"
echo "   • Verify Google provider shows 'Enabled'"
echo ""
echo "2. Test Google Sign-In in mobile app:"
echo "   • Open the Runnin app"
echo "   • Tap 'Sign in with Google'"
echo "   • Complete OAuth flow"
echo "   • Verify successful login"
echo ""
echo "3. Test LLM endpoints (requires Firebase auth token):"
echo "   • Get a Firebase ID token from the app"
echo "   • Test coach endpoint:"
echo "     curl -H 'Authorization: Bearer <TOKEN>' \\"
echo "          -X POST $API_URL/v1/coach/chat \\"
echo "          -H 'Content-Type: application/json' \\"
echo "          -d '{\"message\": \"Hello, coach!\"}'"
echo ""
echo "4. Monitor Cloud Run logs:"
echo "   • https://console.cloud.google.com/run/detail/$REGION/$SERVICE_NAME/logs?project=$PROJECT_ID"
echo ""

echo "✓ Automated verification complete"
