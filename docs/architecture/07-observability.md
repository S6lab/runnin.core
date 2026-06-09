# 07 — Observabilidade & Admin

## Camadas

```
1. Logging       Winston JSON stdout → Cloud Run captura como jsonPayload
2. Request ID    UUID v4 injetado em req.id, propagado via X-Request-Id header
3. Token tracking  Firestore agregado por user-dia (collection llm_usage)
4. Push events   PushNotification tool / Crashlytics (app-side)
5. Métricas admin /admin/usage/* endpoints (REST) + Flutter pages (TF 66+)
6. Health checks /health endpoint simples (sanity para Cloud Run probe)
```

## Token tracking (custo + volume)

### Schema Firestore

```
users/{uid}/llm_usage/{YYYY-MM-DD}
{
  date: "2026-06-09",
  totalInputTokens, totalOutputTokens, totalCalls, totalCostUsd,
  byModel: {
    "gemini-3.5-flash": { input, output, calls, costUsd },
    "gemini-3.1-pro-preview": { ... },
    ...
  },
  byUseCase: {
    "generate-plan": { calls, costUsd },
    "live-coach": { ... },
    ...
  },
  updatedAt: ISO
}

system/llm_usage/daily/{YYYY-MM-DD}    ← cron jobs (sem userId)
```

Doc id = data ISO → 1 doc/dia/user. `FieldValue.increment()` garante atomic em race condition.

### Use cases tagged

Cada call LLM passa `userId + useCase` via `LLMOptions`:

```ts
await llm.generate(prompt, {
  systemPrompt, maxTokens, temperature,
  userId: 'ZDG4...',
  useCase: 'generate-plan',  // ou 'plan-rationale', 'weekly-revision-analysis',
                              //    'coach-message', 'coach-chat', 'run-report',
                              //    'weekly-report', 'period-analysis', etc
});
```

Calls sem tagging caem como `useCase: 'unknown'` — admin UI mostra pra rastrear gaps.

### Pricing table

`server/src/shared/infra/llm/llm-pricing.ts`:

```ts
LLM_PRICING_USD_PER_1M = {
  'gemini-3.5-flash':              { inputPer1M: 0.075, outputPer1M: 0.30 },
  'gemini-3.1-pro-preview':        { inputPer1M: 1.25,  outputPer1M: 5.00 },
  'gemini-2.5-flash-native-audio': { inputPer1M: 0.15,  outputPer1M: 1.00 },
  'gemini-embedding-001':          { inputPer1M: 0.025, outputPer1M: 0 },
  ...
}
```

Hardcoded — atualizar manualmente quando Google muda. `GET /v1/admin/usage/pricing` expõe tabela atual.

### Endpoints admin

```
GET /v1/admin/usage/tokens?from=YYYY-MM-DD&to=YYYY-MM-DD&userId=optional
   → { totals, byDay[], byModel{}, byUseCase{} }

GET /v1/admin/usage/top-users?from=YYYY-MM-DD&to=YYYY-MM-DD&limit=20
   → { users: [{ userId, costUsd, calls, inputTokens, outputTokens }] }

GET /v1/admin/usage/system?from=YYYY-MM-DD&to=YYYY-MM-DD
   → idem mas pra crons/system

GET /v1/admin/usage/pricing
   → { pricing: { 'gemini-3.5-flash': {...}, ... } }
```

UI Flutter consome esses 4 em `/admin/tokens` (`AdminTokensPage`) com filtros
HOJE/7D/30D + toggle pra incluir/excluir custo dos crons system.

## Request ID propagation

`server/src/shared/infra/http/middlewares/request-id.middleware.ts`:

- Lê `X-Request-Id` header se cliente enviou; senão gera UUID v4.
- Anexa em `req.id`.
- Devolve no header da resposta.

Logger captura via `req.id` (precisa anexar manualmente nos use cases — TODO automatizar com AsyncLocalStorage).

Query Cloud Logging por trace:

```
gcloud logging read \
  'jsonPayload.requestId="abc-123"' \
  --project=runnin-494520 --limit=50
```

## Convenção de eventos

Ver `06-telemetry.md` pra lista completa.

## Dashboard de saúde (futuro)

Endpoint planejado `GET /v1/admin/health/snapshot`:

```json
{
  "llm": { "calls_last_1h", "error_rate_pct", "avg_latency_ms", "p95_latency_ms" },
  "plans": { "generating_now", "failed_last_24h" },
  "coach_live": { "open_sessions_now", "reconnect_exhausted_last_24h" },
  "biometric_sync": { "successful_today", "errors_today" }
}
```

Tela admin Flutter renderiza com status colorido.

## Paths-chave

| Path | Função |
|---|---|
| `server/src/shared/logger/logger.ts` | Winston JSON config |
| `server/src/shared/infra/http/middlewares/request-id.middleware.ts` | X-Request-Id |
| `server/src/shared/infra/llm/usage-tracker.ts` | Persiste agregado |
| `server/src/shared/infra/llm/llm-pricing.ts` | Tabela USD |
| `server/src/modules/admin/use-cases/get-llm-usage.use-case.ts` | Agregação por range |
| `server/src/modules/admin/http/admin.controller.ts` | Endpoints usage/* |
| `server/src/modules/admin/http/admin.routes.ts` | Routes |
