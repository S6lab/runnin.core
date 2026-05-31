# Cloud Scheduler para Notificações Diárias e Reset de Cota

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

### 2. Criar o Cloud Scheduler Job para Notificações

```bash
gcloud scheduler jobs create http daily-notifs \
  --schedule="0 6 * * *" \
  --uri=https://<YOUR_REGION>-<YOUR_PROJECT_ID>.cloudfunctions.net/notifications-function \
  --http-method=POST \
  --headers=Content-Type=application/json,X-CRON-TOKEN=seu-token-secreto-unico \
  --time-zone="America/Sao_Paulo"
```

### 3. Criar o Cloud Scheduler Job para Reset de Cota ( SUP-601 )

Adicione este job para zera `user.planRevisions.usedThisWeek` toda segunda às 03:00 BRT:

```bash
gcloud scheduler jobs create http reset-plan-revision-quota \
  --schedule='0 3 * * 1' \
  --time-zone='America/Sao_Paulo' \
  --uri="https://<YOUR_REGION>-<YOUR_PROJECT_ID>.run.app/v1/users/internal/reset-plan-revision-quota" \
  --http-method=POST \
  --headers="X-CRON-TOKEN=seu-token-secreto-unico"
```

**⚠️ Importante:** Use o URI da API (não a função) para endpoints `/internal/*`.

### 4. Verificar os jobs criados

```bash
gcloud scheduler jobs describe daily-notifs
```

### 4. Listar todos os jobs

```bash
gcloud scheduler jobs list
```

## Parâmetros do Schedule (Notifications)

- **Schedule:** `0 6 * * *` (rodar todos os dias às 06:00 horário de São Paulo)
- **URI:** URL da função cloud (ajustar conforme deploy)
- **Time Zone:** `America/Sao_Paulo` (horário local)

## Parâmetros do Schedule (Reset de Cota)

- **Schedule:** `0 3 * * 1` (rodar toda segunda-feira às 03:00 horário de São Paulo)
- **URI:** URL da API Cloud Run (ajustar conforme deploy)
- **Time Zone:** `America/Sao_Paulo` (horário local)

## Processamento em Batch

O endpoint processa todos os usuários com `planRevisions` definido:

- Itera todos os usuários em lotes de 100
- Reseta `usedThisWeek = 0` e atualiza `resetAt = now()`
- Retorna contador total de usuários resetados

## Monitoramento

Logs mostrarão contador final após cada execução:

Exemplo de log:
```json
{
  "resetCount": 150
}
```

## Troubleshooting

### Erro: Invalid or missing X-CRON-TOKEN header
- Verifique se a variável `X_CRON_TOKEN` está configurada no deploy
- Certifique-se que o header `X-CRON-TOKEN` está presente na requisição

### Erro: X-CRON-TOKEN env var not configured
- Defina a variável de ambiente no deploy da função

### Job não roda (Notifications)
- Verifique o schedule: `gcloud scheduler jobs describe daily-notifs`
- Confirme que a função existe e está ativa
- Verifique permissões do Cloud Scheduler para invocar a função

### Job não roda (Reset de Cota)
- Verifique o schedule: `gcloud scheduler jobs describe reset-plan-revision-quota`
- Confirme que o endpoint está acessível via Cloud Run
- Verifique permissões do Cloud Scheduler para invocar a API

### Erro: Invalid or missing X-CRON-TOKEN header
- Verifique se a variável `X_CRON_TOKEN` está configurada no deploy
- Certifique-se que o header `X-CRON-TOKEN` está presente na requisição

### Erro: X-CRON-TOKEN env var not configured
- Defina a variável de ambiente no deploy do Cloud Run ou função
