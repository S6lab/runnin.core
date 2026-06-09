# 05 — Protocolos de comunicação

## Autenticação

Todas as rotas REST exigem `Authorization: Bearer <firebase-id-token>` (exceto health, admin via X-Cron-Token).

Token vem de Firebase Auth (anônimo, email, Apple, Google, telefone). Server valida via `firebase-admin` em `authMiddleware`.

WS Live usa o **ephemeral token** Google AI (não o ID token) — server gera via `POST /v1/coach/live-token`.

## Endpoints REST

### Plans

| Método | Rota | Premium? | Função |
|---|---|---|---|
| POST | `/v1/plans/generate` | ✓ | Cria plano (5 fases) |
| GET | `/v1/plans/current` | | Plano atual (com adjustedWeeks) |
| GET | `/v1/plans/:id` | | Plano específico |
| GET | `/v1/plans/:id/checkpoints` | | Lista checkpoints |
| GET | `/v1/plans/knowledge/corpus` | | RAG global pra UI debug |
| POST | `/v1/plans/revisions` | ✓ | Revisão manual |
| GET | `/v1/plans/:planId/revisions` | | Histórico revisões |
| GET | `/v1/plans/:planId/reports/:weekNumber` | ✓ | Relatório semanal |

### Coach

| Método | Rota | Premium? | Função |
|---|---|---|---|
| POST | `/v1/coach/live-token` | ✓ | Ephemeral token Google |
| WS | `/v1/coach/live` | ✓ | Sessão Live proxy |
| POST | `/v1/coach/live-diag` | | Beacon diagnóstico |
| POST | `/v1/coach/live-turn` | ✓ | Persiste turn (replay) |
| POST | `/v1/coach/message` | ✓ | Cue HTTP (km_reached, etc) |
| POST | `/v1/coach/chat` | ✓ | Chat texto |
| GET | `/v1/coach/report/:runId` | ✓ | Report pós-corrida |
| POST | `/v1/coach/report/:runId/generate` | ✓ | Forçar regeneração |
| GET | `/v1/coach/messages/:runId` | ✓ | Histórico de cues |
| GET | `/v1/coach/period-analysis` | ✓ | Análise período histórico |
| GET | `/v1/coach/runtime-config` | | Config dinâmica do coach |

### Runs

| Método | Rota | Função |
|---|---|---|
| POST | `/v1/runs` | createRun (status='active') |
| PATCH | `/v1/runs/:runId/complete` | completeRun com splits + telemetryTimeline |
| PATCH | `/v1/runs/:runId/feedback` | submitFeedback (chips) |
| POST | `/v1/runs/:runId/gps` | addGpsBatch |
| GET | `/v1/runs` | List paginated |
| GET | `/v1/runs/:runId` | Detalhe |

### Biometrics

| Método | Rota | Função |
|---|---|---|
| POST | `/v1/biometrics/samples` | Ingest HK samples |
| POST | `/v1/biometrics/sync-telemetry` | Telemetry de sync (debug) |
| POST | `/v1/biometrics/sync-ping` | Heartbeat de abertura |
| GET | `/v1/biometrics/summary?windowDays=7` | Agregado (sono, BPM, HRV) |
| GET | `/v1/biometrics/latest/:type` | Último sample por tipo |

### Stats / History

| Método | Rota | Função |
|---|---|---|
| GET | `/v1/stats/aggregate?period=week` | Aggregate + deltas |
| GET | `/v1/stats/breakdown?period=week` | Volume + pace buckets |

### Exams

| Método | Rota | Função |
|---|---|---|
| POST | `/v1/exams` | Upload PDF/JPG |
| POST | `/v1/exams/:id/analyze` | Trigger OCR (interno/async) |
| GET | `/v1/exams/:id/data` | Estrutura extraída |
| GET | `/v1/exams` | Lista |

### Notifications

| Método | Rota | Função |
|---|---|---|
| GET | `/v1/notifications?cursor=...` | Lista paginada |
| POST | `/v1/notifications/:id/dismiss` | Marcar dispensada |
| POST | `/v1/notifications/clear` | Limpar todas |
| POST | `/v1/notifications/devices` | Registrar FCM token |
| POST | `/v1/notifications/ensure-daily` | Cron diário 08h |

### Subscriptions

| Método | Rota | Função |
|---|---|---|
| GET | `/v1/subscriptions/features` | Quais features tem premium |
| POST | `/v1/subscriptions/benefits/lookup` | Parceiro (cupom) |
| POST | `/v1/subscriptions/benefits/activate` | Ativar parceria |

### Admin

Ver `04-prompts.md` + `07-observability.md` pra detalhes. Lista completa em `server/src/modules/admin/http/admin.routes.ts`.

## WebSocket: `/v1/coach/live`

Upgrade flow descrito em `01-coach-ai.md`. Mensagens client → server:

```json
{ "type": "telemetry", "text": "Coach, fechei o km 2: pace 5:30, BPM 145" }
{ "type": "command", "name": "pause" | "resume" | "stop" }
```

Server → client:

```json
{ "kind": "ready" }                        // setup ok
{ "kind": "audio", "chunk": "<base64-pcm>" }
{ "kind": "transcript", "text": "Boa, mantém esse ritmo." }
{ "kind": "error", "code": "...", "reason": "..." }
{ "kind": "close", "code": 1000 }
```

## WCSession (Watch ↔ iPhone)

### iPhone → Watch (`updateApplicationContext`)

Single-value dedup; iOS entrega na próxima reachable. Watch lê via `didReceiveApplicationContext`.

```swift
{
  "type": "run_state",       // ou "today_session"
  "status": "active",
  "elapsedS": 482,
  "distanceM": 2160,
  "paceMinKm": 5.5,
  "bpm": 142,
  "splits": [...],
  "accentColor": "#00E5FF",
  "_attachedTodaySession": { "type": "Easy Run", ... } | NSNull
}
```

### Watch → iPhone

Comandos: `sendMessage` quando reachable, fallback `transferUserInfo` (queue persistente).

```swift
{ "action": "pauseRun" | "resumeRun" | "abandonRun" | "completeRun" | "startRun",
  "request_id": "<uuid>" }   // TF 59+ dedup
```

BPM stream do HKWorkoutSession: `WCSession.default.sendMessage(["type": "bpm_update", "bpm": 142])` 1Hz quando ativo.

## Paths-chave

| Path | Função |
|---|---|
| `server/src/server.ts` | Express setup, middlewares, route mounting |
| `server/src/shared/infra/http/middlewares/auth.middleware.ts` | Firebase ID token |
| `server/src/shared/infra/http/middlewares/request-id.middleware.ts` | Trace UUID |
| `server/src/shared/infra/http/middlewares/require-feature.middleware.ts` | Premium gates |
| `app/lib/core/network/api_client.dart` | Dio config + auth interceptor |
| `app/lib/features/run/data/workout_realtime_service.dart` | WCSession bridge |
| `app/ios/Runner/WorkoutRealtimePlugin.swift` | iPhone-side WCSession delegate |
| `app/ios/RunninWatch Watch App/SessionDelegate.swift` | Watch-side WCSession |
