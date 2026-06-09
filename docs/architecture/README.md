# Arquitetura — runnin.core

Documentação técnica detalhada do runnin.ai. Visão big-picture do fluxo
IA E2E + drill-down por subsistema.

## Estrutura

| Documento | Cobre |
|---|---|
| [00-overview.md](00-overview.md) | Arquitetura geral, fluxo de dados, stack, escalabilidade |
| [01-coach-ai.md](01-coach-ai.md) | Gemini Live: WS proxy, ephemeral token, systemInstruction, rotação, reconnect, ducking, cooldowns, dedup |
| [02-plan-generation.md](02-plan-generation.md) | Pipeline 5-fase, retry MAX_TOKENS, two-tier, executionSegments, weekly revision |
| [03-rags.md](03-rags.md) | RAG global (running-knowledge-corpus) + RAG user (exames), embedding, retrieval |
| [04-prompts.md](04-prompts.md) | config-store, defaults vs overrides Firestore, personas, render template, cache |
| [05-app-protocols.md](05-app-protocols.md) | REST endpoints, WS, WCSession (Watch ↔ iPhone), workflows app→server |
| [06-telemetry.md](06-telemetry.md) | telemetryTimeline 30s tick, max BPM pico, GPS, ingest biometric, sync-telemetry |
| [07-observability.md](07-observability.md) | Logging conventions, request ID, token tracking, dashboards admin |

## Big-picture do fluxo IA E2E

```
┌──────────────────────────────────────────────────────────────────────┐
│  MOMENTOS DE IA (DOC 0)                                              │
└──────────────────────────────────────────────────────────────────────┘

  MOMENTO 1: ONBOARDING → PLANO
    app (form) ──► /v1/plans/generate ──► GeneratePlanUseCase
                                         │
                          ┌──────────────┼──────────────────┐
                          ▼              ▼                  ▼
                   validate()    formatRunningKnowledge   buildPlanInitPrompt
                                 Context (RAG global)
                                         │
                                         ▼
                          gemini-3.1-pro-preview → JSON weeks
                                         │
                                         ▼
                          gemini-3.5-flash (narrativas)
                                         │
                                         ▼
                          persist users/{uid}/plans/{planId}

  MOMENTO 5: CORRIDA → COACH VOZ AO VIVO
    app (StartRun) ──► /v1/coach/live-token ──► ephemeral token (Google AI)
                                                │
                                                ▼
                       WebSocket /v1/coach/live (server proxy)
                                                │
                          ┌─────────────────────┼──────────────┐
                          ▼                     ▼              ▼
                   CoachRuntimeContext   build-run-coach    GeminiLiveSession
                       (profile + plan)   instruction       (Charon voice)
                                                │
                                                ▼
                          turn-by-turn: cues (km_reached, check_in 500m,
                                              segment_*, pace_alert, high_bpm)
                                              cooldowns 60s/90s + dedup

  MOMENTO 2-3-4: TELAS + EXAMES + REVISÃO SEMANAL
    Telas:        gemini-3.5-flash (prosa de reports/insights)
    Exame:        gemini-multimodal (OCR de PDF/JPG) → chunks RAG user
    Revisão sem:  cron domingo 23h ──► ApplyWeeklyRevisionUseCase
                                         │
                                         ▼
                          LLM 4-block prompt (overload/underload/pace)
                          + clamp 70-110% + hydrate recheio
```

## Stack

| Camada | Tecnologia |
|---|---|
| App mobile | Flutter 3.x (iOS native first, Android secondary) |
| Watch | watchOS 10+ native Swift (HKWorkoutSession + HKLiveWorkoutBuilder) |
| Comunicação Watch↔iPhone | WCSession (updateApplicationContext / sendMessage / transferUserInfo) |
| Backend | Node 20 + Express + TypeScript em Cloud Run (`southamerica-east1`) |
| Banco | Firestore (Native mode) + Storage (audio buffers, exames) |
| Auth | Firebase Auth (anônimo + email + Apple + Google + telefone) |
| LLM primário | Gemini 3.5 Flash (texto) + 3.1 Pro Preview (plan reasoning) |
| LLM voz | Gemini 2.5 Flash Native Audio (Live API, persona Charon) |
| LLM multimodal | Gemini 3.5 Flash (OCR de exames) |
| Embedding | gemini-embedding-001 (RAG chunks) |
| Push | Firebase Cloud Messaging |
| Cron | Cloud Scheduler (X-Cron-Token) |

## Glossário rápido

- **Cue**: 1 fala do coach durante a corrida (ex: "km_reached", "check_in", "pace_alert").
- **Two-tier**: plano com `full` (sessões completas) + `skeleton` (resumo só com volume/pace) — `effectiveWeeks` se ajusta dinamicamente.
- **Adjusted weeks**: snapshot vigente do plano (com revisões aplicadas). `plan.weeks` é a BASE imutável.
- **Roteiro / executionSegments**: segmentos km-a-km dentro de uma sessão (aquecimento, main, cooldown) com instruction texts pro coach narrar.
- **Telemetry timeline**: snapshot 30s {bpm, pace, distância} sincronizados — alimenta o coach in-run e análise pós-corrida.
- **RAG vinculante**: chunks da Seção R (clinical/legal bounds) que sempre entram em prompts sensíveis.
