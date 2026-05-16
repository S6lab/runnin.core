# Arquitetura runnin.core

> Snapshot: 2026-05-16 — pós-introdução do módulo Subscriptions + container DI.
> Doc viva — atualizar quando módulo novo ou collection nova entrar.

## Índice

1. [Stack](#stack)
2. [Topologia](#topologia)
3. [Backend layout (Clean Arch)](#backend-layout)
4. [Modelo de dados Firestore](#modelo-de-dados-firestore)
5. [Módulo Subscriptions (planos)](#módulo-subscriptions)
6. [Fluxo de login + onboarding](#fluxo-de-login)
7. [Plan generation + rate limits](#plan-generation--rate-limits)
8. [Integração biométrica (Apple Health / Google Fit / wearables)](#integração-biométrica)
9. [Injeção de dependência](#injeção-de-dependência)
10. [Async jobs (Cloud Tasks — planejado)](#async-jobs--cloud-tasks)
11. [Backlog arquitetural](#backlog-arquitetural)

---

## Stack

| Camada | Tecnologia |
|---|---|
| App | Flutter 3.41 (Web/iOS/Android), `flutter_bloc`, `go_router`, `dio`, `cloud_firestore`, `firebase_auth` |
| Server | Node 20 + TypeScript, Express, Cloud Run (southamerica-east1), `firebase-admin` |
| DB | Firestore (Native mode) no projeto `runnin-494520` |
| Auth | Firebase Auth (Google, Phone SMS, Anonymous, future Apple) |
| LLM | Gemini 2.5 Flash (REST) + Gemini 2.0 Flash Exp (Live WebSocket) — adapter pattern (Groq/Together opcionais) |
| Files | Cloud Storage (`runnin-exams` bucket) |
| Hosting web | Firebase Hosting (channel `staging` em `runnin-494520--staging-5sd5wkho.web.app`) |

---

## Topologia

```
┌──────────────────────────────────────────────────────────────────┐
│                        Flutter App (Web/iOS/Android)              │
│   • cloud_firestore (read direto: app_config, run-time UI state) │
│   • dio → API Cloud Run (mutations + features premium)            │
│   • firebase_auth (JWT)                                           │
└────────────┬─────────────────────────────────────────────┬────────┘
             │                                              │
             ▼                                              ▼
   ┌──────────────────┐                          ┌────────────────────┐
   │  Cloud Run        │ ◄──── auth JWT ─────────│  Firebase Auth     │
   │  runnin-api-staging│                         └────────────────────┘
   └─────┬─────────────┘
         │
         ├──► Firestore (Native)
         │      collections (ver §4)
         │
         ├──► Cloud Storage (uploads de exames)
         │
         ├──► Gemini API (REST + WebSocket)
         │
         └──► [futuro] Cloud Tasks (jobs assíncronos)
```

---

## Backend layout

Estrutura por feature module, com Clean Architecture:

```
server/src/
├── server.ts                  # express setup, monta routers
├── modules/
│   ├── users/                 # perfil, onboarding, preferences
│   │   ├── domain/            # entity, repository (interface), use-cases
│   │   ├── http/              # controllers + routes (driver adapter)
│   │   └── infra/             # firestore-user.repository (driven adapter)
│   ├── subscriptions/         # ✨ NOVO — planos + features (freemium/pro)
│   │   ├── domain/
│   │   │   ├── plan-features.ts        # contract de 14 features booleanas
│   │   │   ├── defaults.ts             # FREEMIUM_PLAN + PRO_PLAN catalog
│   │   │   ├── subscription-plan.entity.ts
│   │   │   └── subscription-plan.repository.ts
│   │   ├── infra/firestore-subscription-plan.repository.ts (cache 60s)
│   │   ├── use-cases/get-user-features.use-case.ts
│   │   └── http/subscription.{controller,routes}.ts
│   ├── plans/                 # planos de TREINO (training plans, NÃO assinatura)
│   ├── runs/                  # corridas + GPS points
│   ├── coach/                 # chat, reports, period analysis, live
│   ├── exams/                 # upload + OCR (Gemini multimodal)
│   ├── health/                # zonas cardíacas
│   ├── notifications/         # notif center
│   ├── admin/                 # prompts admin console
│   └── benchmark/             # cohort percentile
└── shared/
    ├── container.ts           # ✨ DI singleton manual
    ├── feature-flags/         # ✨ kill switches globais (Firestore-backed, cache 60s)
    ├── errors/app-error.ts    # NotFoundError, ForbiddenError, CooldownError, etc.
    ├── infra/
    │   ├── firebase/firebase.client.ts
    │   ├── http/middlewares/  # auth, requireFeature, requireAdmin, error, requestId
    │   └── llm/               # gemini.adapter, gemini-live, groq, together + factory
    ├── knowledge/running/     # RAG corpus shared
    └── logger/                # pino structured logs
```

### Convenção Clean Arch
- **domain/** depende só de tipos puros (sem express, sem firebase-admin). Define entity + repository **interface** + use-cases.
- **infra/** implementa as interfaces de domain. Aqui mora `firebase-admin`, `dio`, http externo. **Substituível**: trocar Firestore por Mongo = só trocar `infra/firestore-xxx.repository.ts` por `infra/mongo-xxx.repository.ts` e re-wirar no `container.ts`. Domain e use-cases não mudam.
- **http/** = driver adapter (entrada HTTP). Controllers fazem parse + delegate pra use-case + serialize response.

### Onde está bom ✅
- 9 módulos consistentes, 32 use cases.
- LLM com adapter (`gemini` | `groq` | `together`) — trocar provider é flag de env.
- Repos isolam Firestore atrás de interfaces (ex: `UserRepository`, `PlanRepository`).

### Onde melhorar (ver §11)
- 5 use cases em `users/` ainda estão em `domain/use-cases/` (resto do projeto usa `use-cases/` à parte). Padronizar.
- Alguns controllers instanciam `new FirestoreXxxRepository()` direto em vez de pegar do container.

---

## Modelo de dados Firestore

### Collections top-level

```
app_config/
├── prompts                    # overrides do admin pros 7 builders LLM
├── feature_flags              # ✨ kill switches globais (coachLiveEnabled, etc.)
└── pricing                    # priceLabel + periodLabel pro paywall

subscription_plans/            # ✨ NOVO — catálogo de planos
├── freemium                   # features: { runTracking: true, generatePlan: false, ... }
└── pro                        # features: { runTracking: true, generatePlan: true, ... }

cohort_aggregates/             # benchmark counters (B4 backend)
└── {level}_{runType}_{distance}

users/
└── {uid}                      # UserProfile (perfil + subscriptionPlanId + quotas)
    │
    ├── runs/                  # corridas do user
    │   └── {runId}
    │       ├── gps_points/    # batch de pontos GPS
    │       ├── reports/       # coach reports pós-run (legado)
    │       └── coach_messages/ # log de cues durante a corrida
    │
    ├── plans/                 # TRAINING plans (renomear pra training_plans no futuro)
    │   └── {planId}
    │       └── weekly_reports/{weekNumber}  # report semanal por plano
    │
    ├── planRevisions/         # log de revisões pedidas
    │
    ├── exams/                 # uploads de exame + OCR result
    ├── notifications/         # notif center items
    ├── onboarding_history/    # audit dos redos de onboarding
    ├── period-analysis/       # cache de análises de período
    └── rag_chunks/            # RAG embeddings por user (CANDIDATO a virar shared)
```

### Decisões de modelagem

- **Per-user subcollections** (`users/{uid}/runs`, `users/{uid}/exams`) são default — Firestore security rules ficam triviais (`request.auth.uid == userId`).
- **Top-level com query cross-user** só quando faz sentido agregar: `cohort_aggregates`, `subscription_plans`, `app_config`.
- **NÃO criar uma collection `subscriptions/{uid}` separada** — o plano fica como campo no `UserProfile` (campos `subscriptionPlanId`, `subscriptionStatus`, etc). Razão: 99% dos reads de profile já carregam o user; ter o plan ID embutido evita 2 reads.

### Onde guardar dados biométricos (proposta nova) — ver §8

```
users/{uid}/biometric_samples/  # ✨ proposta
└── {sampleId}
    {
      type: 'bpm' | 'sleep' | 'steps' | 'hrv' | 'spo2' | 'weight',
      value: number,
      unit: string,            # 'bpm' | 'hours' | 'count' | 'ms' | '%' | 'kg'
      source: 'apple_health' | 'google_fit' | 'garmin' | 'manual' | 'wearable_oauth',
      recordedAt: ISO date,    # timestamp do sample (não do upload)
      receivedAt: ISO date,    # quando o app sincronizou
      raw?: object             # payload original do provider (debugging)
    }

users/{uid}/biometric_summaries/  # ✨ daily/weekly rollups (compute-on-write)
└── {dateKey}                     # ex: '2026-05-16' ou '2026-W20'
    {
      window: 'day' | 'week',
      avgRestingBpm?, maxBpm?, sleepHours?, totalSteps?, ...
    }
```

---

## Módulo Subscriptions

### Diagrama lógico

```
┌─────────────────────────────────┐         ┌──────────────────────────────────┐
│  SubscriptionPlan (catalog)     │         │  UserProfile                     │
│  Collection: subscription_plans │         │  Collection: users               │
├─────────────────────────────────┤         ├──────────────────────────────────┤
│ id: 'freemium' | 'pro'          │         │ id: string (uid Firebase)        │
│ name, priceLabel, periodLabel   │         │ name, level, goal, frequency...  │
│ features: PlanFeatures (14)     │◄────────│ subscriptionPlanId               │
│ limits: PlanLimits (4)          │         │ subscriptionStatus               │
│ active: boolean                 │         │ subscriptionStartedAt            │
└─────────────────────────────────┘         │ trialEndsAt?                     │
                                            │ planRevisions: {                 │
                                            │   usedThisWeek, max, resetAt     │
                                            │ }  (quota de gerar plano novo)   │
                                            └──────────────────────────────────┘
```

### Como rodar (deploy + seed)

```bash
# 1. Deploy server
bash deploy-server-staging.sh

# 2. Seed dos 2 planos default no Firestore (idempotente)
curl -X POST https://runnin-api-staging-rogiz7losq-rj.a.run.app/v1/subscriptions/seed
```

### Endpoints

| Método | Path | Auth | Descrição |
|---|---|---|---|
| GET | `/v1/subscriptions/plans` | público | Catálogo (paywall lê) |
| GET | `/v1/subscriptions/me` | bearer | Plano atual do user + features |
| POST | `/v1/subscriptions/seed` | (público hoje) | Idempotente — popula DEFAULTS |

### Middleware

```typescript
// Substitui o antigo requirePremium (boolean)
import { requireFeature } from '@shared/infra/http/middlewares/require-feature.middleware';

planRouter.post('/generate', requireFeature('generatePlan'), handler);
coachRouter.post('/chat', requireFeature('coachChat'), handler);
zoneRouter.use(requireFeature('healthZones'));
examRouter.post('/upload-url', requireFeature('examsOCR'), handler);
```

Backend retorna **403 FORBIDDEN** com mensagem `Feature "xxx" não está disponível no seu plano.` — app pode mostrar paywall específico.

---

## Fluxo de login

### Visão geral

```
┌─────────┐    auto-advance    ┌─────────┐
│ /splash │ ─────(1.8s)─────► │ /intro  │ (3 slides, marca intro_seen no Hive)
└─────────┘                   └────┬────┘
                                   │ user toca "começar"
                                   ▼
                            ┌──────────────┐
                            │   /login     │ ◄────────────────────────┐
                            └──────┬───────┘                          │
                            Google/Anon/Phone                         │
                                   │                                  │
                            FirebaseAuth.signIn... + provisionMe()    │
                                   │                                  │
                            _navigateAfterAuth():                     │
                            ├── if profile.onboarded → /home          │
                            └── else → /onboarding ────┐              │
                                                       ▼              │
                                            ┌──────────────────┐      │
                                            │   /onboarding    │      │
                                            │   (3 intro + 11  │      │
                                            │   assessment)    │      │
                                            └──────────┬───────┘      │
                                                       │              │
                                            POST /users/onboarding    │
                                                       │              │
                                            ├── if !premium → /paywall│
                                            └── else → /plan-loading  │
                                                       │              │
                                                       ▼              │
                                            ┌──────────────────┐      │
                                            │  /paywall        │      │
                                            │  ASSINAR → PATCH │      │
                                            │  /users/me       │      │
                                            │  {subscriptionPlanId='pro'}
                                            │  CONTINUAR GRÁTIS│      │
                                            └──────────┬───────┘      │
                                                       │              │
                                                       ▼              │
                                                   /home              │
                                                                      │
                          [logout no perfil] ─────────────────────────┘
```

### Bugs corrigidos
- **`/login` standalone travava** porque não navegava após `provisionMe()`. **Fix**: `_navigateAfterAuth()` lê `profile.onboarded` e empurra pra `/home` ou `/onboarding`. Aplicado nos 4 paths (Google, Anon, Phone-auto, Phone-confirm).
- **Login 2x** no fluxo via OnboardingPage: router redirecionava pra `/home` enquanto OnboardingPage navegava por si. **Fix**: guard `onboardingStatus == true` no router (`app_router.dart:104`).

### Persistência da jornada

| Estado | Onde | TTL |
|---|---|---|
| `intro_seen` | Hive (`runnin_settings`) | Persistente |
| `onboarding_completed` cache | Hive + memória do `app_router.dart` | Persistente |
| `pending_training_plan_id` | Hive | Persistente até plano completar |
| `hydration_ml_today` + `hydration_date` | Hive | Reset diário |
| Firebase Auth session | Firebase SDK (web/native) | Persistente |
| UserProfile completo | Firestore `users/{uid}` | Permanente |
| `subscriptionPlanId` | Firestore `users/{uid}` (campo) | Permanente |
| Planos gerados | Firestore `users/{uid}/plans/{planId}` | Permanente |
| Quota `planRevisions` | Firestore campo no `users/{uid}` | Reset semanal |

---

## Plan generation + rate limits

### Regras de negócio

| User | Pode gerar plano? | Quota |
|---|---|---|
| Freemium | ❌ Não | (gate `requireFeature('generatePlan')` retorna 403 antes de qualquer check) |
| Pro (primeiro plano) | ✅ Sim | Não consome quota |
| Pro (substituir plano existente) | ✅ Sim | Consome 1/quota semanal — `max: 1`, `resetAt: +7d` |

### Como funciona o gate

1. `POST /v1/plans/generate` passa por `requireFeature('generatePlan')` (middleware) — freemium recebe 403 aqui.
2. `GeneratePlanUseCase.execute` checa se já existe plano ativo:
   - Sem `confirmOverwrite: true` → retorna 409 `PLAN_ALREADY_EXISTS` (app abre dialog "Substituir?")
   - Com `confirmOverwrite: true` → checa `planRevisions.usedThisWeek < max`. Se exceder, joga `CooldownError` 403 com `availableAt: resetAt`.
3. Sucesso → cria plano em status `generating`, dispara `_generateAsync` no background, retorna 202.

### Por que não usei Cloud Tasks ainda

Plan generation hoje é **fire-and-forget** dentro do mesmo processo Cloud Run:
- ✅ Retorna 202 pro app rápido (~50ms)
- ❌ Se Cloud Run reiniciar (cold start, OOM), o background termina abandonado e plano fica `generating` para sempre
- ❌ Sem retry em falhas LLM (Gemini 429)

**Plano** (não-implementado) — ver §10:
```
POST /plans/generate
  └─► 1. cria plano status=generating
  └─► 2. enqueue Cloud Task → POST /v1/internal/jobs/generate-plan
  └─► 3. retorna 202
```

Cloud Task chama de volta `/v1/internal/jobs/generate-plan` (autenticado via OIDC) com retry exponencial (1min, 5min, 30min). Se 3 retries falharem, marca `status: failed` + notifica user.

---

## Integração biométrica

### Objetivo
Capturar **BPM (heart rate), sono, passos, HRV, SpO2, peso** de fontes externas (Apple Health, Google Fit, ou wearables OAuth) e armazenar no Firestore pra alimentar coach, recovery score e benchmarks.

### Opções de stack

| Estratégia | Pros | Cons | Complexidade |
|---|---|---|---|
| **A. Apple HealthKit + Google Health Connect** (via plugin Flutter) | Não precisa OAuth por brand; user só autoriza o Health Connect/HealthKit uma vez; pega dados de QUALQUER device que escreve lá (Apple Watch, Garmin Connect, Strava, Polar, Whoop) | iOS-only ou Android-only — web fica de fora. Plugins maduros: `health` package | Médio |
| **B. OAuth direto por wearable** (Garmin Connect IQ, Polar Accesslink, Strava, Whoop, Fitbit, etc.) | Funciona em qualquer plataforma (incluindo web) | 1 OAuth por brand → 5-8 integrações pra cobrir mercado | Alto |
| **C. Aggregator (Terra, Vital, Spike)** | 1 API pra tudo, OAuth gerenciado | Custo extra (~$0.10-0.50 por user/mês), dependência de 3rd party | Baixo (codigo) / Médio (custo) |
| **D. Manual input + CSV import** | Zero integração externa | UX ruim, dados esporádicos | Trivial |

### Recomendação

**Fase 1 (MVP)**: A — `health` package (Apple HealthKit + Health Connect) cobre mobile (iOS+Android). Web fica sem biométrico inicialmente.

**Fase 2 (escala)**: C — Aggregator (Terra recomendado, com tier free até 100 conexões/mês) pra Garmin/Strava/Whoop/etc. — apps que escrevem em Health Connect já vêm via Fase 1; aggregator cobre o resto.

**Nunca**: B sozinho — manutenção de 8 OAuths separados é insustentável.

### Stack mínima

#### Flutter app
```yaml
dependencies:
  health: ^11.0.0   # HealthKit + Health Connect unificado
```

#### Server (novo módulo)
```
modules/biometrics/
├── domain/
│   ├── biometric-sample.entity.ts
│   └── biometric-sample.repository.ts
├── infra/
│   └── firestore-biometric-sample.repository.ts
├── use-cases/
│   ├── ingest-samples.use-case.ts          # POST /biometrics/samples (batch)
│   ├── get-latest-by-type.use-case.ts
│   └── compute-daily-summary.use-case.ts   # cron diário → biometric_summaries
└── http/
    ├── biometric.routes.ts                 # POST /v1/biometrics/samples
    └── biometric.controller.ts
```

### Modelo de dados (proposto)

```
users/{uid}/biometric_samples/{sampleId}
{
  type: 'bpm' | 'sleep' | 'steps' | 'hrv' | 'spo2' | 'weight' | 'calories_burned',
  value: number,
  unit: string,
  source: 'apple_health' | 'health_connect' | 'garmin' | 'manual' | 'terra',
  recordedAt: '2026-05-16T08:30:00Z',  # quando aconteceu
  receivedAt: '2026-05-16T09:15:00Z',  # quando sincronizou pro Firestore
  context?: {                            # opcional, depende do type
    sleepStages?: { deep, light, rem, awake },
    activityType?: 'run' | 'walk' | 'cycle' | ...,
  },
}

users/{uid}/biometric_summaries/{dateKey}
{
  window: 'day' | 'week',
  date: '2026-05-16',
  avgRestingBpm?: 58,
  maxBpm?: 178,
  sleepHours?: 7.4,
  sleepQuality?: 'good',                 # AI-computed
  totalSteps?: 8420,
  hrvAvg?: 45,
  computedAt: '2026-05-17T00:05:00Z',
}
```

### Sync flow

```
[Apple Watch/Garmin/etc.]
      ↓ writes to Apple Health / Health Connect
[Flutter app, foreground/background]
      ↓ health.getHealthDataFromTypes(since: lastSync)
      ↓ batch POST /v1/biometrics/samples
[Server]
      ↓ firestore batch.set users/{uid}/biometric_samples/*
      ↓ enqueue compute-daily-summary if sample is from today
      ↓ returns { received: N, deduplicated: M }
```

### Permissões iOS / Android
- iOS: `Info.plist` com `NSHealthShareUsageDescription` + `NSHealthUpdateUsageDescription`.
- Android: `AndroidManifest.xml` com `android.permission.health.READ_HEART_RATE`, `READ_SLEEP`, `READ_STEPS`, etc. Plus Health Connect app instalado no device.

---

## Injeção de dependência

### Estratégia atual (B do plan anterior)

Container singleton manual em `shared/container.ts`:

```typescript
import { FirestoreUserRepository } from '@modules/users/infra/firestore-user.repository';
import { FirestoreSubscriptionPlanRepository } from '@modules/subscriptions/infra/firestore-subscription-plan.repository';
import { GetUserFeaturesUseCase } from '@modules/subscriptions/use-cases/get-user-features.use-case';

const userRepo = new FirestoreUserRepository();
const subscriptionPlanRepo = new FirestoreSubscriptionPlanRepository();

export const container = {
  repos: {
    users: userRepo,
    subscriptionPlans: subscriptionPlanRepo,
  },
  useCases: {
    getUserFeatures: new GetUserFeaturesUseCase(userRepo, subscriptionPlanRepo),
  },
};
```

### Por que não framework DI (Inversify, NestJS, tsyringe)?

| Critério | Container manual | Inversify / DI framework |
|---|---|---|
| LOC adicional | 0 | ~50-100 (decorators, container setup) |
| Build time | mesmo | +5-15s (reflection metadata) |
| Curva de aprendizado | trivial | média |
| Testabilidade | `jest.mock('@shared/container')` resolve | mais sutilezas (rebinds, scopes) |
| Type safety | total (TS infer) | total |
| Reload de singleton em runtime | só re-importar / restart | mesmo |

**Veredito**: pra projeto <50k LOC e equipe pequena, container manual ganha. Migrar pra Inversify quando:
- Time crescer pra 5+ devs (precisa convenção forte)
- Aparecerem scopes complexos (request-scoped, transient)
- Multi-tenancy entrar

### Como adicionar nova dep no container

```typescript
// 1. Importa repo + use-case
import { FirestoreBiometricSampleRepository } from '@modules/biometrics/infra/...';
import { IngestSamplesUseCase } from '@modules/biometrics/use-cases/...';

// 2. Instancia e expõe
const biometricRepo = new FirestoreBiometricSampleRepository();

export const container = {
  repos: {
    ...,
    biometrics: biometricRepo,
  },
  useCases: {
    ...,
    ingestBiometricSamples: new IngestSamplesUseCase(biometricRepo, userRepo),
  },
};

// 3. Usa no controller
import { container } from '@shared/container';
export async function postIngest(req, res) {
  const result = await container.useCases.ingestBiometricSamples.execute(req.uid, req.body);
  res.json(result);
}
```

### Anti-pattern a evitar (presente em alguns controllers legados)

```typescript
// ❌ NÃO: cria nova instância a cada request
export async function getMe(req, res) {
  const repo = new FirestoreUserRepository();
  ...
}

// ✅ SIM: usa container
import { container } from '@shared/container';
export async function getMe(req, res) {
  const profile = await container.repos.users.findById(req.uid);
  ...
}
```

Tarefa de refactor: migrar os controllers legados pra container (~2h, não-urgente).

---

## Async jobs — Cloud Tasks

### Status: **PLANEJADO, não implementado**

### Por que precisamos
- **Plan generation** pode demorar 10-30s, Cloud Run pode reiniciar no meio
- **Cohort aggregate** roda síncrono dentro de `complete-run` — adiciona latência ao path crítico
- **Gemini 429** atualmente joga 503 amigável, mas sem retry
- **Coach report generation** pós-corrida — fire-and-forget hoje, sem garantia

### Arquitetura proposta

```
                              ┌──────────────────┐
                              │  Cloud Tasks      │
                              │  Queue: jobs-llm  │
                              │  Queue: jobs-agg  │
                              │  Queue: jobs-low  │
                              └─────────┬────────┘
                                        │ HTTP POST com OIDC token
                                        ▼
                              ┌──────────────────────┐
                              │  Cloud Run            │
                              │  /v1/internal/jobs/   │
                              │  ├── /generate-plan   │
                              │  ├── /aggregate-cohort│
                              │  └── /generate-report │
                              └──────────────────────┘
                                        │
                                        ▼
                                  Firestore + Gemini
```

### Quando implementar

Quando qualquer um destes acontecer:
1. Plan generation falhar silenciosamente em produção > 1x/dia
2. Latência p99 do complete-run passar de 1s
3. Coach reports começarem a ficar "ausentes" porque background morreu

**Custo Cloud Tasks**: free até 1M invocações/mês. Pra runnin.core (até 10k DAU), zero custo.

### Esforço estimado: ~12h
- Setup das 3 queues + IAM roles (Service Account `cloud-tasks-runner@`)
- Novo módulo `modules/internal-jobs/` com 1 endpoint por job type
- Refactor de `generate-plan`, `complete-run` hooks, `generate-report` pra usar `enqueueJob()` helper
- Retry policy + dead-letter logging
- Testes E2E (smoke)

---

## Backlog arquitetural

Em ordem de retorno por esforço:

| # | Item | Esforço | Impacto |
|---|---|---|---|
| 1 | App consumir `/subscriptions/me` no boot + `subscriptionController.refresh()` no paywall confirm | 1h | Médio — UI já consegue mostrar gates corretos |
| 2 | Renomear `modules/plans/` → `modules/training_plans/` (cosmético) | 2h | Baixo — só clareza semântica |
| 3 | Migrar controllers legados pra container DI | 2h | Médio — limpeza + prepara testes |
| 4 | Shared RAG (mover `users/{uid}/rag_chunks` → `rag_corpus/{topic}/chunks`) | 6h | Alto custo só com scale |
| 5 | Health/Readiness endpoints (`/healthz`, `/readyz`) | 1h | Baixo agora, importante pré-launch |
| 6 | Biometrics module (Fase 1: HealthKit + Health Connect) | 16h | Alto — habilita Recovery score real, melhora coach |
| 7 | Cloud Tasks pra jobs assíncronos | 12h | Alto — confiabilidade |
| 8 | Stripe/StoreKit real (substituir o mock no paywall) | 24h | Crítico pré-monetização |
| 9 | Observability (alerts Cloud Monitoring) | 4h | Alto pós-launch |
| 10 | Remover `requirePremium` legado (já não tem mais callsite) | 0.5h | Baixo — só limpeza |

**Próximas 2 sprints recomendadas**:
- Sprint atual: 1, 3, 5, 10 (~5h, tudo small wins)
- Sprint próxima: 6 (Biometrics) ou 7 (Cloud Tasks) — escolher pela necessidade

---

## Biometrics — implementação atual

### Status: ✅ Backend deployado (sem UI mobile ainda)

Módulo completo em `server/src/modules/biometrics/`:

```
modules/biometrics/
├── domain/
│   ├── biometric-sample.entity.ts      # 12 tipos (bpm, hrv, sleep, etc.) + 9 sources
│   └── biometric-sample.repository.ts
├── infra/firestore-biometric-sample.repository.ts
├── use-cases/
│   ├── ingest-samples.use-case.ts      # batch ingest (até 500 samples/req)
│   ├── get-summary.use-case.ts         # rollup N dias on-demand
│   └── seed-test-user.use-case.ts      # ~50 samples realistas em 7d
└── http/biometric.{controller,routes}.ts
```

### Endpoints

| Método | Path | Auth | Descrição |
|---|---|---|---|
| POST | `/v1/biometrics/samples` | bearer | Batch ingest (até 500 samples) — chamado pelo plugin `health` no app |
| GET | `/v1/biometrics/latest/:type` | bearer | Último sample de um tipo |
| GET | `/v1/biometrics/summary?windowDays=7` | bearer | Rollup (avgRestingBpm, maxBpm, avgSleepHours, totalSteps, avgHrv, latestWeight) |
| POST | `/v1/biometrics/seed-test-user` | admin | Idempotente — popula 7d realistas pra `nalin@s6lab.com` (ou outro email no body) |

### Como testar (3 caminhos)

#### 1) Seed pro user de teste (mais rápido pra ver dados)
```bash
# Logue como admin (eduardokaizer@gmail.com — claim já setada)
TOKEN=$(firebase auth:export ... | jq -r '...')  # ou pegue do browser DevTools (window.firebase.auth.currentUser.getIdToken())

curl -X POST https://runnin-api-staging-rogiz7losq-rj.a.run.app/v1/biometrics/seed-test-user \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"email": "nalin@s6lab.com"}'
# → { ok: true, email: "nalin@s6lab.com", uid: "...", seeded: 50 }
```

Depois, logando como `nalin@s6lab.com`:
```bash
curl https://runnin-api-staging-rogiz7losq-rj.a.run.app/v1/biometrics/summary?windowDays=7 \
  -H "Authorization: Bearer $NALIN_TOKEN"
```

Deve retornar algo como:
```json
{
  "windowDays": 7,
  "avgRestingBpm": 56,
  "maxBpm": 174,
  "avgSleepHours": 7.4,
  "totalSteps": 70250,
  "avgHrv": 48,
  "latestWeight": 71.5,
  "sampleCount": 50
}
```

#### 2) Ingest manual (curl simula app enviando)
```bash
curl -X POST https://runnin-api-staging-rogiz7losq-rj.a.run.app/v1/biometrics/samples \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "samples": [
      {"type":"resting_bpm","value":55,"unit":"bpm","source":"manual","recordedAt":"2026-05-16T07:30:00Z"},
      {"type":"sleep_hours","value":7.8,"unit":"hours","source":"manual","recordedAt":"2026-05-15T23:00:00Z"}
    ]
  }'
```

#### 3) Integração real (próximo passo, NÃO implementado)
Adicionar `health: ^11.0.0` no `pubspec.yaml`. Plugin abstrai Apple HealthKit (iOS) + Google Health Connect (Android). Snippet:

```dart
import 'package:health/health.dart';

final types = [HealthDataType.HEART_RATE, HealthDataType.SLEEP_ASLEEP, HealthDataType.STEPS];
final granted = await Health().requestAuthorization(types);
if (!granted) return;

final samples = await Health().getHealthDataFromTypes(
  startTime: lastSyncAt,
  endTime: DateTime.now(),
  types: types,
);

// Mapeia pro schema do server e POST /v1/biometrics/samples
final payload = samples.map((s) => {
  'type': _mapType(s.type),
  'value': s.value.toDouble(),
  'unit': s.unit,
  'source': Platform.isIOS ? 'apple_health' : 'health_connect',
  'recordedAt': s.dateFrom.toUtc().toIso8601String(),
}).toList();
await dio.post('/biometrics/samples', data: {'samples': payload});
```

**iOS**: `Info.plist` com `NSHealthShareUsageDescription`.
**Android**: `AndroidManifest` com `android.permission.health.READ_*` + Health Connect app instalado.

---

## Coach — migração para Gemini Live multimodal + Neural 2

### Estado atual
- **Coach text chat** (`/v1/coach/chat`): Gemini 2.5 Flash REST. Funciona, mas é request/response sem streaming.
- **Coach voice durante corrida** (`/v1/coach/message`): mesmo Gemini REST, texto retornado é tocado via `audioplayers` no app — sem TTS nativo do Gemini, app usa Web Speech API (browser) ou plataforma.
- **Coach Live** (`/v1/coach/live` WebSocket): Gemini Live API (`gemini-2.0-flash-exp`), apenas texto MVP. Audio multimodal configurado no service mas não wired.

### Opções de migração

| Stack | Latência | Custo (10k DAU) | Qualidade voz | Complexidade |
|---|---|---|---|---|
| **A. Manter atual** (Gemini text + Web Speech TTS) | 200-500ms texto + 100ms TTS local | $0 TTS | TTS robótico do browser | Baixa (já funciona) |
| **B. Gemini text + Google Cloud TTS Neural2** | +200-400ms TTS round-trip | ~$16/1M chars (~$5/mês a 10k DAU) | Excelente (vozes naturais pt-BR `pt-BR-Neural2-A/B/C`) | Média (1 endpoint TTS) |
| **C. Gemini Live multimodal** (input audio → output audio bidirecional) | <300ms full duplex | Token de Live é mais caro (~3x texto) | Excelente (voice Charon, Aoede, Puck nativas) | Alta (WebSocket complexo, ainda preview API) |
| **D. ElevenLabs / OpenAI TTS** | +400-800ms | $5-22/1M chars | Excelente, voices customizadas | Média + custo |

### Recomendação por uso

**Coach durante corrida (cues curtos)**: **B — Google Cloud TTS Neural2**
- Latência aceitável (cue chega 1-2s depois do trigger, OK)
- Custo controlado (cue tem <100 chars → ~5k chars/usuário/mês → ~$0.08/user/mês)
- Vozes pt-BR Neural2 são excelentes (já testadas em apps fitness)
- Reutiliza o pipeline atual (Gemini gera texto → TTS converte → app toca .mp3 base64)

**Coach Chat (conversa texto)**: **manter A** — não vale a pena TTS em chat
- User lê na tela; voz é desnecessária
- Custo extra sem ganho de UX

**Coach Live (conversa por voz, sem corrida)**: **C — Gemini Live multimodal**
- Já tem infra: [`gemini-live.service.ts`](server/src/shared/infra/llm/gemini-live.service.ts) + WebSocket proxy
- Full duplex < 300ms é game-changer pra UX de "conversa"
- API ainda é preview → assumir risco de breaking changes em ~2026

### Plano de implementação (B — TTS Neural2 pra coach voice durante corrida)

**Esforço: ~6h**

1. **Backend**: novo adapter `shared/infra/tts/google-tts.adapter.ts`
   ```typescript
   class GoogleTtsAdapter {
     async synthesize(text: string, voiceName = 'pt-BR-Neural2-B'): Promise<string> {
       // Returns base64 audio/mp3
     }
   }
   ```

2. **Modificar** `coach.controller.postCoachMessage`: depois de gerar texto via Gemini, chama TTS e retorna `{ text, audioBase64, audioMimeType: 'audio/mpeg' }`.

3. **App**: já existe `playCoachAudio` no `coach_audio_player.dart`. Recebe os campos `coachAudioBase64` + `coachAudioMimeType` no `RunState`. **Zero mudança de UI.**

4. **Config**: setar `GCP_TTS_API_KEY` no Cloud Run (ou usar service account já existente).

5. **Custo**: enable Cloud Text-to-Speech API no projeto `runnin-494520`. Billing já ativo.

### Plano (C — Gemini Live multimodal pra coach live)

**Esforço: ~16h** — fica pra depois que B estiver validado em produção.

1. Modificar [`coach-live.ws.ts`](server/src/modules/coach/http/coach-live.ws.ts) pra abrir sessão Live com `responseModalities: ['AUDIO']`.
2. App: usar `MediaRecorder` (Web) ou `record` package (mobile) pra capturar mic em chunks PCM 16khz, enviar via WebSocket.
3. Tocar audio chunks de volta usando Web Audio API ou `audioplayers`.

### Decisão recomendada
- **AGORA**: implementar B (TTS Neural2) — ganho de UX claro, custo controlado, baixo risco.
- **DEPOIS de billing Gemini estável**: planejar C pra coach live como feature premium destacada.

---

## Histórico

| Data | Mudança |
|---|---|
| 2026-05-16 | Doc inicial. Módulo Subscriptions + Container DI + Feature Flags + login fix + plan quota |
| 2026-05-16 (later) | Biometrics module backend (entity + repo + ingest/summary/seed use cases + 4 endpoints). Health/readyz. Coach TTS Neural2 + Gemini Live multimodal analysis. App refresh subscription no boot. |
