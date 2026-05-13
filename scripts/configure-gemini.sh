#!/usr/bin/env bash
set -euo pipefail

PROJECT_ID="runnin-494520"
SERVICE_NAME="runnin-api"
REGION="southamerica-east1"

echo "==================================="
echo "Gemini API Configuration for Cloud Run"
echo "==================================="
echo ""

# Check if gcloud is authenticated
if ! gcloud auth list --filter=status:ACTIVE --format="value(account)" | grep -q .; then
  echo "❌ Error: gcloud is not authenticated"
  echo "Please run: gcloud auth login"
  exit 1
fi

# Check if project is accessible
if ! gcloud projects describe "$PROJECT_ID" &>/dev/null; then
  echo "❌ Error: Cannot access project $PROJECT_ID"
  echo "Please verify your permissions"
  exit 1
fi

# Read GEMINI_API_KEY from environment or prompt
if [[ -z "${GEMINI_API_KEY:-}" ]]; then
  echo "Enter Gemini API Key (input hidden):"
  echo "Get key from: https://makersuite.google.com/app/apikey"
  echo -n "> "
  read -s GEMINI_API_KEY
  echo ""
  echo ""
fi

if [[ -z "$GEMINI_API_KEY" ]]; then
  echo "❌ Error: GEMINI_API_KEY cannot be empty"
  exit 1
fi

echo "→ Updating Cloud Run service: $SERVICE_NAME"
echo "  Project: $PROJECT_ID"
echo "  Region: $REGION"
echo ""

# Update Cloud Run service environment variables
if gcloud run services update "$SERVICE_NAME" \
  --project="$PROJECT_ID" \
  --region="$REGION" \
  --set-env-vars="LLM_REALTIME_PROVIDER=gemini,LLM_ASYNC_PROVIDER=gemini,GEMINI_API_KEY=$GEMINI_API_KEY" \
  --quiet; then

  echo ""
  echo "✓ Cloud Run environment variables updated successfully"
  echo ""

  # Verify configuration (without showing the actual key)
  echo "→ Verifying environment variables..."
  ENV_VARS=$(gcloud run services describe "$SERVICE_NAME" \
    --project="$PROJECT_ID" \
    --region="$REGION" \
    --format="value(spec.template.spec.containers[0].env)")

  if echo "$ENV_VARS" | grep -q "LLM_REALTIME_PROVIDER=gemini"; then
    echo "✓ LLM_REALTIME_PROVIDER = gemini"
  fi

  if echo "$ENV_VARS" | grep -q "LLM_ASYNC_PROVIDER=gemini"; then
    echo "✓ LLM_ASYNC_PROVIDER = gemini"
  fi

  if echo "$ENV_VARS" | grep -q "GEMINI_API_KEY"; then
    echo "✓ GEMINI_API_KEY = [REDACTED]"
  fi

  echo ""
  echo "✓ Configuration complete!"
  echo ""
  echo "Next steps:"
  echo "1. Run verification script: ./scripts/verify-production-config.sh"
  echo "2. Test LLM endpoints in the mobile app"

else
  echo ""
  echo "❌ Error: Failed to update Cloud Run service"
  echo "Please check your permissions and try again"
  exit 1
fi
