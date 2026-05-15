#!/usr/bin/env bash
set -euo pipefail

PROJECT_ID="runnin-494520"
SERVICE_NAME="runnin-api-staging"
REGION="southamerica-east1"
SA="runnin-api@${PROJECT_ID}.iam.gserviceaccount.com"
ENV_FILE="server/.env.staging"

if [[ ! -f "$ENV_FILE" ]]; then
  echo "⚠️  $ENV_FILE não encontrado. Usando .env.production como base..."
  ENV_FILE="server/.env.production"
fi

echo "→ Lendo variáveis de $ENV_FILE..."
# PORT é reservado no Cloud Run; variáveis vazias são ignoradas.
# Stripa comentários inline (`# ...`) e trailing whitespace
ENV_VARS=$(grep -v '^#' "$ENV_FILE" \
  | sed -E 's/[[:space:]]*#.*$//' \
  | sed -E 's/[[:space:]]+$//' \
  | grep -v '^$' \
  | grep -v '^PORT=' \
  | grep -v '=$' \
  | tr '\n' ',' \
  | sed 's/,$//')

# Override NODE_ENV for staging
if [[ "$ENV_VARS" == *"NODE_ENV="* ]]; then
  ENV_VARS=$(echo "$ENV_VARS" | sed 's/NODE_ENV=[^,]*/NODE_ENV=staging/')
else
  ENV_VARS="${ENV_VARS},NODE_ENV=staging"
fi

echo "→ Deploy no Cloud Run STAGING ($REGION)..."
gcloud run deploy "$SERVICE_NAME" \
  --source=server \
  --region="$REGION" \
  --project="$PROJECT_ID" \
  --service-account="$SA" \
  --set-env-vars="$ENV_VARS" \
  --allow-unauthenticated \
  --port=8080 \
  --memory=512Mi \
  --cpu=1 \
  --min-instances=0 \
  --max-instances=5 \
  --timeout=60 \
  --quiet

echo "✓ Deploy STAGING concluído!"
echo ""
echo "🔗 URL do backend staging:"
gcloud run services describe "$SERVICE_NAME" \
  --region="$REGION" \
  --project="$PROJECT_ID" \
  --format="value(status.url)"
