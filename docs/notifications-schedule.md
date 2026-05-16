# Cloud Scheduler para Notificações Diárias

## Visão Geral

Este documento descreve como configurar o Cloud Scheduler para rodar diariamente o processo de geração de notificações de insights.

## Endpoint

O app expõe um endpoint protegido para garantir notificações diárias:

```
POST /v1/notifications/ensure-daily
```

**Proteção:** O endpoint requer o header `X-CRON-TOKEN` com o valor da variável de ambiente `X_CRON_TOKEN`.

## Configuração Local (Teste)

Para testar localmente:

```bash
export X_CRON_TOKEN="seu-token-secreto"
curl -X POST http://localhost:3000/v1/notifications/ensure-daily \
  -H "X-CRON-TOKEN: ${X_CRON_TOKEN}"
```

## Configuração no Google Cloud

### 1. Definir a variável de ambiente

No Firebase/Cloud Functions, defina a variável `X_CRON_TOKEN`:

```bash
gcloud functions deploy notifications-function \
  --set-env-vars=X_CRON_TOKEN=seu-token-secreto-unico
```

### 2. Criar o Cloud Scheduler Job

```bash
gcloud scheduler jobs create http daily-notifs \
  --schedule="0 6 * * *" \
  --uri=https://<YOUR_REGION>-<YOUR_PROJECT_ID>.cloudfunctions.net/notifications-function \
  --http-method=POST \
  --headers=Content-Type=application/json,X-CRON-TOKEN=seu-token-secreto-unico \
  --time-zone="America/Sao_Paulo"
```

### 3. Verificar o job criado

```bash
gcloud scheduler jobs describe daily-notifs
```

### 4. Listar todos os jobs

```bash
gcloud scheduler jobs list
```

## Parâmetros do Schedule

- **Schedule:** `0 6 * * *` (rodar todos os dias às 06:00 horário de São Paulo)
- **URI:** URL da função cloud (ajustar conforme deploy)
- **Time Zone:** `America/Sao_Paulo` (horário local)

## Processamento em Batch

O endpoint processa usuários em lotes de 100 para evitar timeouts e garantir escalabilidade:

- Itera todos os usuários com `onboarded: true`
- Executa `EnsureDailyInsightsUseCase` para cada usuário
- Logs de sucesso/falha por usuário
- Resumo final com total processado

## Monitoramento

Logs do Cloud Functions mostrarão:
- `notifications.ensure_daily_user_failed` para usuários que falharam
- `notifications.ensure_daily_complete` com contador final

Exemplo de log:
```json
{
  "message": "notifications.ensure_daily_complete",
  "count": 150
}
```

## Troubleshooting

### Erro: Invalid or missing X-CRON-TOKEN header
- Verifique se a variável `X_CRON_TOKEN` está configurada no deploy
- Certifique-se que o header `X-CRON-TOKEN` está presente na requisição

### Erro: X-CRON-TOKEN env var not configured
- Defina a variável de ambiente no deploy da função

### Job não roda
- Verifique o schedule: `gcloud scheduler jobs describe daily-notifs`
- Confirme que a função existe e está ativa
- Verifique permissões do Cloud Scheduler para invocar a função
