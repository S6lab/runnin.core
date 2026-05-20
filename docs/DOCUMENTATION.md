# runnin.core — Documentação da Estrutura Atual (snapshot 2026-05-19)

> Documentação **fiel ao código implementado** (snapshot 2026-05-19), gerada por auditoria direta
> (`server.ts`, rotas, datasources, wiring). Serve de **base para desenhar melhorias**.
> Substitui o template genérico anterior, que não refletia a stack real.

---

## Sumário

1. [Visão Geral](#1-visão-geral)
2. [Stack Tecnológica (real)](#2-stack-tecnológica-real)
3. [Arquitetura & Estrutura de Pastas](#3-arquitetura--estrutura-de-pastas)
4. [Backend — Módulos & Endpoints](#4-backend--módulos--endpoints)
5. [Modelo de Dados (Firestore)](#5-modelo-de-dados-firestore)
6. [Frontend — Features Flutter](#6-frontend--features-flutter)
7. [Integrações](#7-integrações)
8. [Jornadas do Usuário (reais)](#8-jornadas-do-usuário-reais)
9. [Configuração, Deploy & CI](#9-configuração-deploy--ci)
10. [Testes](#10-testes)
11. [Itens implementados-mas-frágeis](#11-itens-implementados-mas-frágeis)
12. [Oportunidades de melhoria](#12-oportunidades-de-melhoria)

---

## 1. Visão Geral

**Runnin** é um app de corrida com **coach de IA**. Não é uma rede social de corredores — é um
**coach pessoal**: gera planos de treino personalizados, acompanha a corrida em tempo real com voz,
analisa o desempenho e adapta o plano semana a semana. Foco no mercado brasileiro (pt-BR).

Pilares implementados:
- **Planejamento inteligente** — plano mesocíclico gerado por LLM em **dois níveis (two-tier)**: as 2
  primeiras semanas vêm detalhadas (pace, duração, hidratação, nutrição, notas ricas + roteiro km-a-km) e
  as semanas seguintes em **esqueleto** (só tipo/distância/pace + metadados de bloco: nome, objetivo, carga
  projetada, targets). A cada **checkpoint** semanal o coach **detalha as próximas 2 semanas** (esqueleto→full)
  e ajusta a carga pela evolução real; revisões automáticas + manuais; histórico em `plan.revisions[]`.
- **Coach em tempo real** — cues por evento (km, pace, segmento) via SSE e voz via Gemini Live; relatório
  pós-corrida em duas fases (resumo rápido → análise enriquecida).
- **Histórico & métricas** — runs com splits km-a-km (pace, FC, calorias, elevação), stats agregadas,
  benchmark percentil vs coorte, replay da conversa do coach.
- **Saúde & biometria** — sincronização com HealthKit/Health Connect, zonas de FC, OCR de exames.
- **Gamificação** — badges, XP, streak.
- **Monetização** — modelo freemium/pro com gating real de features (pagamento ainda não integrado).

---

## 2. Stack Tecnológica (real)

| Camada | Tecnologia |
|---|---|
| App | **Flutter** (Dart), Web + Android (iOS preparado, deploy desativado) |
| State (app) | flutter_bloc + Cubit + ChangeNotifier (Riverpod presente, pouco usado) |
| Navegação | go_router |
| HTTP (app) | Dio + interceptor de Firebase ID token |
| Mapa / GPS | flutter_map + latlong2 + geolocator |
| Local (app) | Hive |
| Backend | **Node.js + Express 5 + TypeScript** |
| Banco | **Firestore** (Firebase Admin SDK) — NoSQL |
| Auth | **Firebase Auth** (Google + Phone SMS). Sem JWT/registro próprios |
| LLM | **Gemini** (async) + **Gemini Live** (áudio); adapters Groq/Together via factory |
| Validação | Zod |
| WebSocket | `ws` (proxy Gemini Live) |
| Push | Firebase Cloud Messaging |
| Storage | Firebase Storage / GCS (exames, RAG) |
| Hosting web | Firebase Hosting |
| Backend host | Google Cloud Run (`runnin-494520`, southamerica-east1) |
| CI/CD | Codemagic |

> ❌ **NÃO há** PostgreSQL, Prisma, Redis, BullMQ, NestJS — apesar do `DOCUMENTATION.md` antigo afirmar.

---

## 3. Arquitetura & Estrutura de Pastas

Monorepo. Branch de trabalho `development`; deploy a partir de `main`.

```
runnin.core/
├── app/                     # Flutter (frontend)
│   ├── lib/
│   │   ├── core/            # router, network (apiClient), theme/tokens, audio, units, gamification
│   │   ├── features/        # 22 features (ver §6) — data/domain/presentation
│   │   └── shared/widgets/  # widgets reutilizáveis + figma/ (~48 componentes do design system)
│   └── test/                # ~8 widget/bloc tests
├── server/                  # Node + Express + TS (backend)
│   └── src/
│       ├── modules/<m>/     # domain (entities) / use-cases / infra (firestore repos) / http (routes+controller)
│       ├── shared/
│       │   ├── infra/llm/   # factory + adapters + prompts (builders, contexts, personas, defaults)
│       │   ├── infra/firebase/  # client admin
│       │   ├── infra/http/middlewares/  # auth, error, requireFeature, requireAdmin, cron-token, request-id
│       │   ├── container.ts # DI manual (singletons)
│       │   ├── logger/ errors/ feature-flags/ knowledge/
│       ├── server.ts        # monta routers /v1 + health checks
│       └── main.ts          # bootstrap + attach WebSocket coach-live
├── docs/                    # documentação + specs figma
├── codemagic.yaml           # CI/CD
└── deploy-*.sh              # scripts Cloud Run + Firebase Hosting
```

Backend segue **arquitetura modular por domínio**: cada módulo tem `domain` (entidades/interfaces),
`use-cases`, `infra` (repositórios Firestore) e `http` (rotas + controller). DI via container manual.

---

## 4. Backend — Módulos & Endpoints

Todas as rotas sob prefixo **`/v1`**. Auth = Firebase ID token (`Authorization: Bearer <token>`) salvo
quando indicado `[público]` ou `[cron]`. `[premium]` = exige feature do plano (middleware `requireFeature`).

**Health (sem auth):** `GET /health`, `GET /healthz` (liveness), `GET /readyz` (checa Firestore).

### users — `/v1/users`
`GET /me` · `PATCH /me` · `DELETE /me` · `POST /provision` · `POST /onboarding` · `POST /me/trial` ·
`POST /internal/reset-plan-revision-quota` [cron]

`PATCH /me` aceita campos opcionais `uiSkin` (string) e `textScale` (string) para persistir tema/skin/escala de texto no perfil do usuário.

### runs — `/v1/runs`
`POST /` (cria/inicia) · `GET /` (lista, com coachQuote) · `GET /:id` · `GET /:id/gps` ·
`PATCH /:id/gps` (batch) · `PATCH /:id/complete` (calcula splits/calorias, dispara report, marca sessão executada)

### plans — `/v1/plans`
`GET /knowledge/corpus` · `GET /current` · `GET /:id` · `GET /:id/revisions` · `GET /:id/weekly-reports` ·
`GET /:id/weekly-reports/:weekNumber` · `GET /:id/checkpoints` · `GET /:id/checkpoints/:weekNumber` ·
`POST /generate` [premium] · `POST /:id/request-revision` [premium] ·
`POST /:id/weekly-reports/:weekNumber/generate` [premium] · `POST /:id/checkpoints/:weekNumber/inputs` ·
`POST /:id/checkpoints/:weekNumber/apply` [premium] · `POST /:id/checkpoints/:weekNumber/skip` ("Depois", sem cota)

Cota de geração (`profile.planGenerations`): 1º plano livre; novo usuário pode gerar **2× nos primeiros 7
dias**; depois **1 regeneração/semana** (overwrite via `?confirmOverwrite=true` descarta o anterior). Distinta
de `planRevisions` (revisão manual) e do checkpoint (não consomem cota de geração). Two-tier: `PlanWeek` tem
`detailLevel: 'full'|'skeleton'`, `blockName`, `objective`, `projectedLoadKm`, `targets[]`; `Plan.goalAssessment`.

### weekly-reports — `/v1/weekly-reports`
`GET /` · `GET /:weekStart`

### coach — `/v1/coach`
`POST /live-token` [premium] · `POST /message` (SSE) [premium] · `POST /chat` [premium] ·
`GET /report/:runId` [premium] · `POST /report/:runId/generate` [premium] · `GET /messages/:runId` [premium] ·
`GET /period-analysis` [premium] · **WebSocket `/v1/coach/live` (+ `/coach-live` legado)** — token Firebase via query, proxy pro Gemini Live

### notifications — `/v1/notifications`
`GET /` · `POST /clear` · `POST /:id/dismiss` · `POST /:id/read` · `POST /devices` (FCM) · `POST /ensure-daily` [cron]

### health — `/v1/health`
`GET /zones` [premium] (zonas de FC Karvonen)

**HealthZonesPage (app):** Exibe zonas somente quando `restingBpm` e `maxBpm` estão preenchidos no perfil. Se faltar qualquer um, exibe aviso `_MissingBpmBanner` com CTA para o usuário preencher o perfil — zonas não são calculadas com valores padrão.

### exams — `/v1/exams`
`GET /` · `POST /upload-url` [premium] · `POST /:examId/finalize` [premium] · `DELETE /:examId`
(OCR multimodal Gemini. Persiste via Firestore + quota mensal `examsPerMonth` validada no server.
A lista de "exames recomendados" no app é **estática/intencional** — não há endpoint de recomendação
personalizada ainda; é um guia genérico, não dado por usuário.)

**Exames recomendados — lista estática intencional (YAGNI):** O app exibe `_kRecommendedExams` (5 itens: Hemograma, Vitamina D, Ferritina, Testosterona, VO₂ Máx) definida em `health_exams_page.dart`. Não existe endpoint de personalização no servidor — decisão deliberada de YAGNI; sem CMS de exames por ora.

### biometrics — `/v1/biometrics`
`POST /samples` (ingest batch) · `GET /latest/:type` · `GET /summary` · `POST /seed-test-user`

**GET /summary?windowDays=7** — retorna rollup dos últimos N dias:
```json
{
  "windowDays": 7,
  "from": "<ISO>",
  "to": "<ISO>",
  "avgRestingBpm": 58.4,
  "maxBpm": 182,
  "avgSleepHours": 7.2,
  "avgHrv": 52.1,
  "totalSteps": 49200,
  "latestWeight": 72.5,
  "sampleCount": 134
}
```
`avgSleepHours` e `avgHrv` são `null` quando não há amostras do tipo na janela.

### stats — `/v1/stats`
`GET /aggregate?period=week|month|threeMonths` · `GET /totals` ·
`GET /breakdown?period=week|month|threeMonths` (aba DADOS do Histórico: 11 stats consolidados do período —
corridas, dist. total/média, tempo, pace, calorias, nível, BPM méd/máx, streak, XP — + buckets de volume
planejado-vs-realizado e pace projetado-vs-médio por dia/semana/mês; cobre histórico de planos. nível/streak
são lifetime)

### subscriptions — `/v1/subscriptions`
`GET /plans` [público] · `GET /me` · `POST /seed` [público]

### benchmark — `/v1/benchmark`
`GET /?level=&runType=&distance=` · `GET /:runId`

### admin — `/v1/admin`
`POST /tester/seed` [cron] · `GET /diagnose/user` [cron] · `POST /diagnose/regenerate-plan` [cron] ·
`POST /diagnose/reset-journey` [cron] · `POST /diagnose/weekly-revise` [cron] · `POST /prompts/preview` ·
`GET /prompts/defaults` · `POST /prompts/invalidate-cache` · `GET /users` · `PATCH /users/:userId/plan` ·
`POST /users/:userId/reset?mode=plan|full` · `GET /rag/status` · `POST /rag/reindex` · `POST /rag/purge`

> `GET /rag/status` agora retorna também `chunks[]` com metadados v3 (secao, vinculante, categoria,
> encaminhamento) e `vinculanteChunks` no summary. `POST /rag/purge` zera `rag_chunks`/`rag_documents`
> + uploads em Storage e reindexa o corpus canônico (operação destrutiva, troca total da base).

### Arquitetura Coach.AI v3 — 4 modelos / 5 momentos
Organização por **momento da jornada** (não por modelo). Princípios: "pro decide, flash escreve" e
"a voz só fala na corrida (sem RAG)".

| # | Momento | Modelo | Prompt(s) | RAG |
|---|---|---|---|---|
| 1 | Indexação (RAG) | `text-embedding-004` | — | indexa |
| 2 | Plano + Ajuste | `gemini-3.1-pro-preview` | `plan-init`, `plan-revision` | lê |
| 3 | Operação de texto | `gemini-3.5-flash` | `post-run-report`(+`-enriched`), `weekly-report`, `period-analysis`, `coach-chat`, `live-coach` | lê |
| 4 | Multimodal / exame | `gemini-3.5-flash` | `exam-analysis` | lê/escreve |
| 5 | Voz ao vivo | `gemini-2.5-flash-native-audio` | `live-voice` | **não** |

Console de admin por momento em `/admin/coach-ai` (badge do modelo + prompts + painel RAG com purga).

### Infra LLM (`shared/infra/llm`)
- **Factory** realtime + async + plano (env `LLM_REALTIME_PROVIDER` / `LLM_ASYNC_PROVIDER` / `GEMINI_PLAN_MODEL`, default gemini).
- **Adapters**: Gemini (primário), Groq, Together. Embeddings `text-embedding-004`.
- **Gemini Live**: áudio nativo, vozes (Charon default), token efêmero criado server-side. System prompt
  da voz vem do config-store (`live-voice`, Doc 5) — editável no admin, sem RAG em runtime.
- **Prompts** (`prompts/`): 10 ids no config-store — `plan-init`, `plan-revision`, `live-coach`,
  `live-voice`, `post-run-report`, `post-run-report-enriched`, `period-analysis`, `weekly-report`,
  `coach-chat`, `exam-analysis`. + contexts (perfil, run, RAG) + personas (motivador/técnico/sereno) +
  voz/invariantes §R compartilhadas (`defaults/_coach-voice.ts`) + override via Firestore + **decision
  layer** (silencia cue por frequência/DND → server responde 204).
- **RAG**: base = Doc 1 (Coach.AI v3) chunkada por subseção em `running-knowledge-corpus.json`, embeddada
  por vetor em Firestore (`rag_chunks`). Recuperação garante chunk **vinculante** (seção R — limites
  clínicos/legais) em query de tema sensível. Uploads do admin (`rag/uploads/`) complementam a base.

---

## 5. Modelo de Dados (Firestore)

```
users/{uid}                              # perfil (level, goal, frequency, gênero, biometria,
  │                                      #   medicalConditions, coachPersonality/messageFrequency,
  │                                      #   units, subscriptionPlanId, planRevisions{usedThisWeek,max,resetAt},
  │                                      #   planGenerations{total,firstPlanAt,usedThisWeek,resetAt})
  ├─ onboarding_history/{ts}
  ├─ plans/{planId}                      # goal, level, weeksCount, status, startDate, goalAssessment,
  │   │                                  #   weeks[]{detailLevel,blockName,objective,projectedLoadKm,targets[],sessions[]}
  │   ├─ revisions/{revisionId}          # auto/manual/checkpoint/weekly_cron
  │   ├─ checkpoints/{weekNumber}        # questionário subjetivo semanal (scheduled|in_progress|completed|skipped)
  │   └─ weekly_reports/{weekNumber}     # métricas + análise LLM
  ├─ runs/{runId}                        # distanceM, durationS, avgPace, avg/maxBpm, elevationGain,
  │   │                                  #   calories(MET), xpEarned, splits[], coachReportId
  │   ├─ gps_points/{id}                 # lat/lng/ts/accuracy/altitude?/pace?/bpm?
  │   ├─ coach_messages/{id}             # log de cues/voz (replay)
  │   └─ reports/{id}                    # report pós-corrida (two-phase)
  ├─ biometric_samples/{id}              # bpm/hrv/sleep/steps/spo2/weight/... (source: apple_health/health_connect/...)
  ├─ devices/{id}                        # wearables pareados
  ├─ exams/{id}                          # OCR Gemini; persiste via FirestoreExamRepository + quota/mês
  ├─ period-analysis/{id}                # análise multi-semana cacheada
  └─ notifications/{id}

app_config/{feature_flags|subscription_plans|notification_devices|prompts|coach}
rag_chunks/{id}                          # base RAG embeddada (corpus Doc 1 + uploads), vetor + metadados v3
rag_documents/{id}                       # metadados dos uploads de RAG (status indexed/pending)
```

**Estruturas-chave:**
- **PlanSession**: dayOfWeek, type, distanceKm, targetPace, durationMin, hidratação, nutrição,
  `executionSegments[]` (kmStart/kmEnd, phase warmup|main|interval|recovery|cooldown, targetPace, instrução),
  executedRunId.
- **KmSplit** (em Run): kmIndex, durationS, avgPaceMinKm, avgBpm, calories, elevationGain.

Índices compostos (`firestore.indexes.json`): `exams(deletedAt,uploadedAt)`,
`planRevisions(planId,createdAt)`, `biometric_samples(type,recordedAt)`.

---

## 6. Frontend — Features Flutter

22 features em `app/lib/features/`. Router go_router (~26 rotas) com guards de auth/onboarding/paywall.

| Feature | O que faz |
|---|---|
| **splash / intro / coach_intro** | Slides pré-login + briefing do Coach.AI (4 slides) |
| **auth** | Login Google OAuth + Phone SMS; provision/onboarding/patch de perfil |
| **onboarding** | ~15 passos (identidade, nível, objetivo, frequência, pace, gênero, wearable, condições médicas, rotina, data início). Freemium→paywall, premium→plan-loading |
| **run** | `RunBloc` compartilhado prep→run→report→share; GPS (web=polling), splits km-a-km, cues SSE + Gemini Live (voz), stall detection 30s, mapa, pause/resume |
| **training** | Plano mensal/semanal, geração + polling, PlanDetail, DayDetail (segments km-a-km), RevisionFlow, Checkpoint, WeeklyReport. Tabs PLAN \| ADJUSTMENTS |
| **coach / coach_live** | `CoachPeriodBloc` (análise de período); CoachLivePage via WebSocket (texto MVP + chunks de áudio) |
| **home** | `HomeCubit`: hero com stats, sessão do dia, week grid, última corrida, notificações, upsell premium |
| **history** | Submenus: conteúdo (DADOS \| CORRIDAS \| BENCH) em cima, período (SEMANA \| MÊS \| 3 MESES) embaixo. DADOS = 11 stats + "VOLUME ACUMULADO NO PERÍODO" (planejado vs realizado) + "PACE DO PERÍODO" (projetado vs médio), via `/stats/breakdown`. Analytics consolidado aqui (sem mais atalho na Home/Perfil). RunDetail (splits, mapa, zonas FC, coach quote) |
| **profile** | Conta, edição, settings (coach/notifications/units), saúde (index/devices/trends/zones), exames (upload+OCR). `UnitsSettingsPage` carrega preferências do backend via `getMe()` no `initState` (fallback Hive para resposta rápida, backend sobrescreve como source of truth) |
| **dashboard** | Analytics agregado (PRs, tendências) |
| **gamification** | Tabs BADGES \| XP \| STREAK (18+ badges, unlock a partir das runs) |
| **notifications** | `NotificationsCubit` + FCM (render embutido na Home) |
| **biometrics** | `HealthSyncService` (HealthKit/Health Connect), ingest batch |
| **subscriptions / paywall** | `SubscriptionController` (gating de features); PaywallPage (premium fake — PATCH premium:true) |
| **steps / assessment** | Componentes reutilizáveis de fluxo multi-step |
| **admin** | Config de coach/prompts, upload RAG |
| **shared/widgets/figma** | ~48 widgets do design system (JetBrains Mono, FigmaColors, tokens) |
| **shared/widgets/settings_toggle** | `SettingsToggle` — toggle genérico wrapping `FigmaSelectionButton`; substitui `_ChannelToggle` e `_DailyNotificationToggle` (SLA-22) |
| **shared/widgets/feedback_toggle** | `FeedbackToggle` — toggle estilo checkbox custom (GestureDetector+Container+check); extraído de `coach_settings_page.dart` (SLA-22) |
| **shared/widgets/time_picker_button** | `TimePickerButton` — label + TextButton que abre `showTimePicker`; substitui código inline de DND em `notifications_settings_page.dart` (SLA-22) |
| **shared/widgets/time_option_button** | `TimeOptionButton` — botão de opção de horário fixo (preset); extraído de `onboarding_step_routine.dart` (SLA-22) |

`main.dart`: Firebase init, Hive, themeController, FCM register, health sync em background, limpeza de
sessão anônima. `apiClient`: base `API_BASE_URL` (dart-define) + token Firebase + refresh em 401.

---

## 7. Integrações

- **Firebase Auth** — Google + Phone SMS. Anônimo descontinuado (limpo no boot). Server verifica ID token.
- **Gemini** — async (planos, reports, análise, OCR de exames) + **Gemini Live** (voz em tempo real).
  App conecta **direto** no Gemini Live usando token efêmero emitido pelo server (API key fica no server).
- **HealthKit (iOS) / Health Connect (Android)** via pacote `health`: FC, FC repouso, HRV, sono, passos,
  SpO2, peso, energia, respiração. Sincroniza em batch (≤500) pro `/biometrics/samples`.
  ⚠️ Garmin/Polar/Strava só entram **se o dado passar por HealthKit/Health Connect** — sem API direta.
- **FCM** — push notifications (registro de device token).
- **Firebase Storage / GCS** — upload de exames e arquivos de RAG.

---

## 8. Jornadas do Usuário (reais)

**J1 — Onboarding:** Splash → Intro (slides) → Login (Google/Phone) → provision → Onboarding (~15 passos) →
freemium cai em Paywall / premium vai pra Plan Loading (gera plano via LLM, polling) → Coach Intro → Home.
> **Tratamento de erro no submit:** se `POST /onboarding` falhar, a navegação é bloqueada e uma mensagem de erro é exibida na tela ("Erro ao salvar perfil. Tente novamente."). O botão volta a ficar ativo para retry — perfil incompleto não avança pro paywall/plan-loading.

**J2 — Registrar corrida:** Home/Training → Prep (tipo, alvo, alertas) → Active Run (GPS, métricas, splits
km-a-km, coach por voz a cada km/evento, stall detection 30s) → Finalizar → Report (splits, mapa, stats,
narrativa do coach) → Share (card + mapa) → corrida some no histórico.

**J3 — Acompanhar progresso:** History → escolhe conteúdo (DADOS/CORRIDAS/BENCH) e período
(SEMANA/MÊS/3 MESES). DADOS = 11 stats consolidados + volume planejado-vs-realizado + pace projetado-vs-médio
(via `/stats/breakdown`) + análise do coach / CORRIDAS (lista → RunDetail com splits, mapa, zonas FC, coach
quote, replay) / BENCH (percentil vs coorte). Analytics consolidado no Histórico (sem atalho na Home/Perfil).

**J4 — Plano de treino:** Training → periodização mensal (cards em bullets: bloco/objetivo/carga/targets;
semanas 3+ marcadas "esqueleto") → semana (sessões com marcador "concluído" por corrida real) → DayDetail
(segmentos km-a-km, hidratação, nutrição — sem checklist nem "planejado vs realizado") → executar como corrida
(vincula sessão via executedRunId) → Checkpoint semanal (chips + nota; APLICAR detalha as próximas 2 semanas e
ajusta carga, ou DEPOIS adia) → revisão registrada em revisions[] → WeeklyReport (análise LLM).

**J5 — Saúde:** Profile → Health → conectar wearable (HealthKit/Health Connect) → sincroniza biometria →
Trends (FC repouso, HRV, sono, passos) / Zones (zonas FC) / Exams (upload + OCR + análise do coach).

**J6 — Gamificação:** Gamification → BADGES / XP / STREAK, derivados das corridas.

> ❌ Jornadas do `DOCUMENTATION.md` antigo que **não existem**: feed social, seguir corredores, grupos,
> desafios coletivos/leaderboards, integração direta com Strava/Garmin/Polar.

---

## 9. Configuração, Deploy & CI

- **App build**: dart-defines `API_BASE_URL`, `FIREBASE_VAPID_KEY`. Staging aponta pro Cloud Run staging.
- **Server env** (`.env.staging`/`.env.production`): `FIREBASE_PROJECT_ID`, `GEMINI_API_KEY`,
  `LLM_*_PROVIDER`, `TTS_*`, `X_CRON_TOKEN`, etc.
- **Cloud Run**: projeto `runnin-494520`, região `southamerica-east1`, scale-to-zero, via `deploy-server*.sh`.
- **Firebase Hosting**: build web → `firebase deploy` via `deploy-web*.sh` (no-cache nos entrypoints).
- **Codemagic** (`codemagic.yaml`): `android-debug` (push main), `android-release` (tag v*, Play interno),
  `web-staging` (push main), `web-production` (tag v*), `ios-release` (desativado). Instâncias mac: `mac_mini_m1`.
- **Credencial GCP do server**: `server/runnin-google-service-account.json` (gitignored).

---

## 10. Testes

- **App**: ~8 widget/bloc tests (`app/test/`) — steps, home, gamification, body metrics. Sem integração/E2E.
- **Server**: **0 testes**. Sem runner configurado.

---

## 11. Itens implementados-mas-frágeis

1. ✅ **Exames persistem (resolvido 2026-05-19)** — `exam.controller.ts` usa `FirestoreExamRepository` e a
   geração de upload-url valida a quota mensal (`examsPerMonth`) via `GetUserFeaturesUseCase`.
2. ⚠️ **Pagamento é fake** — Paywall só faz `PATCH /users/me {premium:true}`; sem Stripe/StoreKit/cobrança.
3. ⚠️ **Coach Live no app é MVP** — texto + chunks de áudio; voz bidirecional parcial.
4. ⚠️ **Cobertura de testes mínima** — server sem testes; app só widget tests.
5. ⚠️ **Riverpod** está como dependência mas é pouco usado (state real é bloc/cubit/ChangeNotifier).

---

## 13. Decisões de arquitetura registradas

### 13.1 Copy de marketing centralizada em `MarketingCopy` (2026-05-20)

Todas as strings visíveis ao usuário nos flows de intro/onboarding (slides do IntroPage, slides do CoachIntroPage, notas do coach na etapa de frequência e dicas de horário na etapa de rotina) foram movidas para `app/lib/core/constants/marketing_copy.dart`.

**Motivação:** strings espalhadas em 4 widgets dificultam revisão de copy por produto sem tocar lógica de UI; uma única fonte de verdade evita inconsistências entre telas.

**Arquivos afetados:**
- `lib/core/constants/marketing_copy.dart` — criado (fonte de verdade)
- `lib/features/intro/presentation/pages/intro_page.dart`
- `lib/features/coach_intro/presentation/pages/coach_intro_page.dart`
- `lib/features/onboarding/presentation/steps/onboarding_step_frequency.dart`
- `lib/features/onboarding/presentation/steps/onboarding_step_routine.dart`

---

## 12. Oportunidades de melhoria (base para roadmap)

- **Persistência de exames** — apontar o controller pro `FirestoreExamRepository` (corrige perda de dados).
- **Pagamento real** — integrar StoreKit/Play Billing (mobile) e/ou Stripe (web); substituir o premium fake.
- **Coach Live completo** — fechar voz bidirecional no app (mic → Gemini Live → áudio) com UX estável.
- **Testes** — cobrir use-cases do server (Zod + lógica de plano/splits/calorias) e fluxos críticos do app.
- **Observabilidade** — métricas/erros estruturados além do Winston (ex: Sentry/Crashlytics no app já existe).
- **Hardening de auth/admin** — revisar custom claims e rotas cron-token.

---

*Snapshot gerado por auditoria de código em 2026-05-19 — fonte fiel da estrutura atual,
substituindo o template genérico anterior.*
