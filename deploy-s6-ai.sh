#!/usr/bin/env bash
set -euo pipefail

# Deploy do s6-ai (microsserviço de IA) — produção.
# Pré-requisitos (uma vez):
#   gcloud iam service-accounts create runnin-s6-ai --project=runnin-494520
#   gcloud projects add-iam-policy-binding runnin-494520 \
#     --member="serviceAccount:runnin-s6-ai@runnin-494520.iam.gserviceaccount.com" \
#     --role="roles/datastore.user"
#   gcloud secrets create s6-internal-token-prod --project=runnin-494520 (+ versão)
#
# Flags WS: --session-affinity + --timeout=3600 porque a sessão Live é um
# WebSocket longo; --max-instances=1 porque o CueSessionStore é in-memory
# (scale-out = Redis, documentado no plano).

PROJECT_ID="runnin-494520"
SERVICE_NAME="runnin-s6-ai"
REGION="southamerica-east1"
SA="runnin-s6-ai@${PROJECT_ID}.iam.gserviceaccount.com"
ENV_FILE="s6-ai/.env.production"

if [[ ! -f "$ENV_FILE" ]]; then
  echo "Erro: $ENV_FILE não encontrado. Crie a partir de s6-ai/.env.example"
  exit 1
fi

echo "→ Lendo variáveis de $ENV_FILE..."
# PORT é reservado no Cloud Run; S6_INTERNAL_TOKEN vem do Secret Manager.
ENV_VARS=$(grep -v '^#' "$ENV_FILE" \
  | sed -E 's/[[:space:]]*#.*$//' \
  | sed -E 's/[[:space:]]+$//' \
  | grep -v '^$' \
  | grep -v '^PORT=' \
  | grep -v '^S6_INTERNAL_TOKEN=' \
  | grep -v '=$' \
  | tr '\n' ',' \
  | sed 's/,$//')

echo "→ Deploy no Cloud Run ($REGION)..."
gcloud run deploy "$SERVICE_NAME" \
  --source=s6-ai \
  --region="$REGION" \
  --project="$PROJECT_ID" \
  --service-account="$SA" \
  --set-env-vars="$ENV_VARS" \
  --set-secrets="S6_INTERNAL_TOKEN=s6-internal-token-prod:latest" \
  --allow-unauthenticated \
  --port=8080 \
  --memory=512Mi \
  --cpu=1 \
  --min-instances=1 \
  --max-instances=1 \
  --session-affinity \
  --timeout=3600 \
  --quiet

echo "✓ Deploy concluído!"
gcloud run services describe "$SERVICE_NAME" \
  --region="$REGION" \
  --project="$PROJECT_ID" \
  --format="value(status.url)"
