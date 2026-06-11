#!/usr/bin/env bash
set -euo pipefail

# Deploy do s6-ai (microsserviço de IA) — STAGING.
# Mesmo project do prod (padrão do runnin-api-staging), service separado.

PROJECT_ID="runnin-494520"
SERVICE_NAME="runnin-s6-ai-staging"
REGION="southamerica-east1"
SA="runnin-s6-ai@${PROJECT_ID}.iam.gserviceaccount.com"
ENV_FILE="s6-ai/.env.staging"

if [[ ! -f "$ENV_FILE" ]]; then
  echo "⚠️  $ENV_FILE não encontrado. Usando .env.production como base..."
  ENV_FILE="s6-ai/.env.production"
fi

echo "→ Lendo variáveis de $ENV_FILE..."
ENV_VARS=$(grep -v '^#' "$ENV_FILE" \
  | sed -E 's/[[:space:]]*#.*$//' \
  | sed -E 's/[[:space:]]+$//' \
  | grep -v '^$' \
  | grep -v '^PORT=' \
  | grep -v '^S6_INTERNAL_TOKEN=' \
  | grep -v '=$' \
  | tr '\n' ',' \
  | sed 's/,$//')

# Override NODE_ENV pra staging
if [[ "$ENV_VARS" == *"NODE_ENV="* ]]; then
  ENV_VARS=$(echo "$ENV_VARS" | sed 's/NODE_ENV=[^,]*/NODE_ENV=staging/')
else
  ENV_VARS="${ENV_VARS},NODE_ENV=staging"
fi

echo "→ Deploy no Cloud Run STAGING ($REGION)..."
gcloud run deploy "$SERVICE_NAME" \
  --source=s6-ai \
  --region="$REGION" \
  --project="$PROJECT_ID" \
  --service-account="$SA" \
  --set-env-vars="$ENV_VARS" \
  --set-secrets="S6_INTERNAL_TOKEN=s6-internal-token:latest" \
  --allow-unauthenticated \
  --port=8080 \
  --memory=512Mi \
  --cpu=1 \
  --min-instances=0 \
  --max-instances=1 \
  --session-affinity \
  --timeout=3600 \
  --quiet

echo "✓ Deploy STAGING concluído!"
gcloud run services describe "$SERVICE_NAME" \
  --region="$REGION" \
  --project="$PROJECT_ID" \
  --format="value(status.url)"
