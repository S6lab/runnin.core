# 01 — Coach AI

## Cenários de uso

| Cenário | Trigger | Modelo | Endpoint |
|---|---|---|---|
| **Coach durante corrida (voz)** | StartRun com `isPremium=true` | gemini-2.5-flash-native-audio | `WS /v1/coach/live` |
| **Coach mensagem HTTP** | km_reached / pace_alert / motivation | gemini-3.5-flash | `POST /v1/coach/message` |
| **Coach chat texto** | User pergunta fora da corrida | gemini-3.5-flash | `POST /v1/coach/chat` |
| **Run report** | Pós-corrida | gemini-3.5-flash | `POST /v1/coach/report/:runId/generate` |
| **Period analysis** | Tela histórico | gemini-3.5-flash | `GET /v1/coach/period-analysis` |

## Fluxo do Live (voz ao vivo)

```
app                                    server                              Google AI
 │                                      │                                    │
 │  POST /v1/coach/live-token           │                                    │
 ├─────────────────────────────────────►│                                    │
 │                                      │  generateEphemeralToken            │
 │                                      ├───────────────────────────────────►│
 │                                      │           token (30min, 1-use)     │
 │                                      │◄───────────────────────────────────┤
 │  { token, ttl }                      │                                    │
 │◄─────────────────────────────────────┤                                    │
 │                                      │                                    │
 │  WS /v1/coach/live?token=...         │                                    │
 ├─────────────────────────────────────►│                                    │
 │                                      │  verifyIdToken                     │
 │                                      │  CoachRuntimeContextService        │
 │                                      │  buildRunCoachInstruction          │
 │                                      │  GeminiLiveSession.open(           │
 │                                      │    systemInstruction = persona     │
 │                                      │      + profile + plan + weather    │
 │                                      │      + executionSegments           │
 │                                      │  )                                 │
 │                                      ├───────────────────────────────────►│
 │  { kind: "ready" }                   │                                    │
 │◄─────────────────────────────────────┤                                    │
 │                                      │                                    │
 │  sendTelemetry("km_reached")         │                                    │
 ├─────────────────────────────────────►│                                    │
 │                                      ├───────────────────────────────────►│
 │                                      │           audio chunks (PCM)       │
 │                                      │◄───────────────────────────────────┤
 │  audio chunks                        │                                    │
 │◄─────────────────────────────────────┤                                    │
 │                                      │                                    │
 │  ... (loop até CompleteRun)          │                                    │
```

## Triggers de cue no run_bloc.dart (Flutter)

| Trigger | Quando dispara | Cooldown | Skip if |
|---|---|---|---|
| `start` | StartRun + saudação | once | — |
| `check_in` (distância) | `newDistance - _lastCoachSpeechDistanceM >= 500m` | n/a (reset trackers) | saudação ativa, sessão fechada |
| `check_in` (tempo) | `now - _lastCoachSpeechAtMs > 240s` | n/a | saudação ativa |
| `km_reached` | cruzou km boundary | once por km | — |
| `segment_start` | entrou em novo segment | once | — |
| `segment_pace_off` | pace fora do segment target | 60s | — |
| `segment_end` | terminou último segment | one-shot | — |
| `pace_alert` | pace fora do target da sessão | 60s | em segment_pace_off cooldown |
| `high_bpm` | BPM > 92% de maxBpm | 90s | — |
| `motivation` | safety timer 4min idle | 4min | — |
| `finish` | CompleteRun | once | — |

Constants (override Firestore via `app_config/coach_runtime` — editar via `/admin/coach-runtime`):
- `checkInDistanceM = 500`
- `checkInIdleSeconds = 240`
- `rotationAgeMinutes = 4` (Gemini Live cap ~8min — rotação preventiva pra evitar queda)
- `maxReconnectAttempts = 10`
- `cooldownsBy.{pace_alert, segment_pace_off, high_bpm, segment_end}`
- `pendingSendsThrottleMs = 2000`, `pendingSendsMaxQueue = 3`
- `suppressCuesGreetingMs = 12000`

Server lê via `getCoachRuntimeConfig()` (cache 60s). App fetcha em
`GET /v1/coach/runtime-config` (cache 1h Hive). PATCH admin em
`/v1/admin/coach/runtime-config` invalida cache server e a próxima sessão
pega o novo valor.

## Rotação preventiva da sessão Live

Gemini Live cai em ~8-10min de forma natural (Google cap). Rotação proativa em **4min absolutos** abre uma sessão nova com mesmo systemInstruction, drena `_pendingSends` pra ela, e fecha a velha. Ducking é mantido (música abafada) durante reconnect curto — só libera após `_maxReconnectAttempts` esgotar.

```
SessionA (3.9min)               SessionB (nova)
    │                              │
    │   sessionAge >= 4min         │
    ├─────────────────────────────►│ pré-aquece (open)
    │                              │
    │                              ├──► sendText(preamble + drain pendingSends)
    │                              │
    │ ws.close(1000 intentional)   │
    │◄─────────────────────────────┤
    │                              │
    └── continue cues sem hiccup ──┘
```

## Ducking (música)

App configura AVAudioSession com `duckOthers` quando coach abre. Música cai pra 30%. Liberação em duas condições:
1. CompleteRun (intencional)
2. `_maxReconnectAttempts` esgotou (coach morreu de verdade)

NÃO libera em onClose non-1000 simples — música abafada por 1-2s é melhor que clicks de volume durante reconnect curto.

## Dedup pendingSends

Reconnect drena `_pendingSends` no socket novo. Antes mandava tudo em sequência → "2 áudios sobrepostos". Hoje:
- **Dedup por trigger**: se 2 `check_in` foram enfileirados durante queda, último vence
- **Cap 3 cues**: queue nunca excede 3
- **Throttle 2s** entre sends no drain

## Paths-chave

| Camada | Path | Função |
|---|---|---|
| App bloc | `app/lib/features/run/presentation/bloc/run_bloc.dart` | `_requestCoachCue`, `_telemetryText`, triggers |
| App live session | `app/lib/features/run/data/live_run_coach_session.dart` | rotateSession, _maybeScheduleReconnect, _pendingSends |
| App ducking | `app/lib/features/coach_live/data/live_audio_service.dart` | `releaseDucking()` |
| Server WS | `server/src/modules/coach/http/coach-live.ws.ts` | upgrade, verify token, session lifecycle |
| Server instruction | `server/src/modules/coach/use-cases/build-run-coach-instruction.ts` | montagem systemInstruction |
| Server runtime context | `server/src/modules/coach/use-cases/coach-runtime-context.service.ts` | gather profile + plan + currentSession |
| Server config (TF 60+) | `server/src/modules/coach/use-cases/coach-runtime-config.service.ts` | runtime config dinâmica (Firestore override) |
| Server pricing/usage | `server/src/shared/infra/llm/llm-pricing.ts`, `usage-tracker.ts` | tracking USD + tokens |
