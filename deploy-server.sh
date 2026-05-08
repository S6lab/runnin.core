#!/usr/bin/env bash
set -euo pipefail

PROJECT_ID="runnin-494520"
SERVICE_NAME="runnin-api"
REGION="southamerica-east1"
SA="runnin-api@${PROJECT_ID}.iam.gserviceaccount.com"
ENV_FILE="server/.env.production"

if [[ ! -f "$ENV_FILE" ]]; then
  echo "Erro: $ENV_FILE não encontrado. Crie a partir de server/.env.example"
  exit 1
fi

echo "→ Lendo variáveis de $ENV_FILE..."
# PORT é reservado no Cloud Run; variáveis vazias são ignoradas.
# Stripa comentários inline (`# ...`) e trailing whitespace, pra valores
# limparem mesmo quando a linha tem comentário (ex: `FOO=bar  # default: bar`).
ENV_VARS=$(grep -v '^#' "$ENV_FILE" \
  | sed -E 's/[[:space:]]*#.*$//' \
  | sed -E 's/[[:space:]]+$//' \
  | grep -v '^$' \
  | grep -v '^PORT=' \
  | grep -v '=$' \
  | tr '\n' ',' \
  | sed 's/,$//')

echo "→ Deploy no Cloud Run ($REGION)..."
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
  --max-instances=10 \
  --timeout=60 \
  --quiet

echo "✓ Deploy concluído!"
gcloud run services describe "$SERVICE_NAME" \
  --region="$REGION" \
  --project="$PROJECT_ID" \
  --format="value(status.url)"
