# 00 — Visão geral

## O que é runnin

Coach AI de corrida personalizado: gera planos de treino, narra cada corrida ao vivo (voz nativa do Gemini), analisa pós-corrida, revisa o plano semanalmente baseado em telemetria + biometria + execução.

## Princípios arquiteturais

1. **Server-first**: lógica de plano, prompts, RAG vivem no Node. App é UI + telemetria.
2. **LLM provider-agnostic**: adapter pattern (`LLMProvider` interface) permite trocar Gemini ↔ Groq ↔ Together sem mexer em use cases.
3. **Prompt store editável**: prompts em Firestore (`app_config/prompts`) — admin tweaka sem deploy.
4. **Plano base é imutável**: `plan.weeks` nunca muda após criação. `adjustedWeeks` carrega revisões cumulativas.
5. **Best-effort instrumentação**: tracker de tokens, telemetria de sync, beacons — TODOS falham silencioso. Coach não pode quebrar por feature de observabilidade.
6. **Watch é dumb client**: Watch só renderiza estado do iPhone (via WCSession). iPhone é fonte de verdade.

## Fluxo de dados macro

```
┌─────────────┐         ┌──────────────────┐         ┌─────────────────┐
│             │  REST   │                  │  LLM    │                 │
│  Flutter    │ ──────► │  Node Cloud Run  │ ──────► │  Gemini APIs    │
│  iOS App    │         │                  │         │  (Pro/Flash/    │
│             │ ◄────── │                  │ ◄────── │   Live/Embed)   │
└─────┬───────┘   WS    └────────┬─────────┘         └─────────────────┘
      │                          │
      │ WCSession                │ Firestore
      ▼                          ▼
┌─────────────┐         ┌──────────────────┐
│             │         │                  │
│  watchOS    │         │  Firestore       │
│  Companion  │         │  + Storage       │
│             │         │                  │
└─────────────┘         └──────────────────┘
```

## Subsistemas

| Subsistema | Responsabilidade |
|---|---|
| **Plans** | Geração + revisão semanal + estrutura two-tier |
| **Coach** | Live voice, message HTTP, reports, period analysis |
| **Runs** | Captura GPS + BPM + splits + telemetryTimeline, completeRun |
| **Biometrics** | Sync HK → server, summary 7d/30d, zonas cardíacas |
| **Exams** | Upload + OCR multimodal + extração estruturada |
| **Notifications** | In-app + push FCM, dedup por dedupeKey |
| **Subscriptions** | Premium gate (coach voice, weekly reports, plan generation) |
| **Admin** | Prompts, users, RAG reindex, usage/tokens, runtime config |

## Escalabilidade atual

- Cloud Run: auto-scale 0→N instâncias. CPU/RAM baixos por instância — bottleneck é Firestore reads, não compute.
- Firestore: aggregate reads pra summary endpoints. Doc cap em `llm_usage/{date}` agregado (1 doc/dia/user).
- Gemini: rate limits de API key. Cost-conscious via tracker (Fase 3 deste plano).

## Próximos gargalos previstos

- **Cron weekly** (domingo 23h): N requests Cloud Tasks em fan-out → 1 instance Cloud Run lida. Se >500 users premium, splitar em workers.
- **WS Live**: cada sessão = 1 WS aberto no Cloud Run. Cap 80 concurrent por instance. Se >80 corredores simultâneos, scale-up.
- **Storage exames**: PDF/JPG dos users em Storage bucket. Sem lifecycle policy ainda — adicionar TTL ou cold-storage move depois.

## Convenções de código

- TypeScript strict no server, Dart sound null safety no app.
- `use-case` files = orchestração; `domain` files = entities + interfaces; `infra` = adapters (Firestore, HTTP, LLM).
- Comentários WHY (não WHAT) em PT-BR. Path-line references usadas pra rastreabilidade.
- `logger.info(<event-name>, {...})` com event names estruturados (ver `06-telemetry.md`).
