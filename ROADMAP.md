# runrun.ai — Roadmap e Status Atual

> Status em 2026-05-15: app Flutter e backend Node.js publicados, com auth Firebase, onboarding, home, treino, corrida, histórico, coach, dashboard e conta já implementados em diferentes níveis de maturidade.
> Stack: Flutter (mobile/web) + Node.js TypeScript (Cloud Run) + Firebase. **Não há frontend web separado** (React/Vite/HTML) — Flutter web cobre o canal web.
> Foco atual: alinhar app com design system Figma (migração HOME/TREINO/HIST/GAMIFICAÇÃO/PERFIL em andamento), fechar ambiente de staging e estabilizar fluxos reais.

---

## Snapshot Atual

- Backend publicado no Cloud Run:
  - Serviço: `runrun-api`
  - Região: `southamerica-east1`
  - URL: `https://runnin-api-rogiz7losq-rj.a.run.app`
  - Revisão atual: `runrun-api-00003-gvc`
- App com:
  - login Google
  - login anônimo
  - onboarding persistido localmente
  - menu `Conta`
  - edição de perfil em tela dedicada
  - logout
- Módulos implementados no app:
  - `auth`, `onboarding`, `home`, `training`, `run`, `history`, `profile`, `coach`, `dashboard`
- Módulos implementados no backend:
  - `users`, `runs`, `plans`, `coach`
- Módulos ainda não fechados:
  - `gamification`, `notifications`, `health`, `exams`, `wearables`, `billing/premium`
- Ambiente de **staging** configurado:
  - Backend: [deploy-server-staging.sh](deploy-server-staging.sh), Cloud Run service separado
  - Flutter web: [app/main_staging.dart](app/main_staging.dart) (usa `StagingFirebaseOptions` de [app/lib/firebase_options.dart](app/lib/firebase_options.dart)) + [app/web/staging_index.html](app/web/staging_index.html)
  - Deploy web: [deploy-web-staging.sh](deploy-web-staging.sh) + [firebase.staging.json](firebase.staging.json)
  - Documentação: [app/DEPLOY_STAGING.md](app/DEPLOY_STAGING.md)
- **Design system Flutter** alinhado parcialmente ao Figma (cores, tipografia, tokens) — [app/lib/core/theme/](app/lib/core/theme/), [app/lib/core/widgets/](app/lib/core/widgets/), [app/lib/shared/widgets/figma/](app/lib/shared/widgets/figma/). Migração de telas em andamento (ver seção "Design System Migration" abaixo)

---

## Cloud Run Free Tier

| Recurso | Free tier mensal | Suficiente para MVP? |
|---------|-----------------|---------------------|
| Requests | 2 milhões/mês | ✅ (MVP tem <10K) |
| CPU | 180.000 vCPU-segundos/mês | ✅ |
| Memória | 360.000 GB-segundos/mês | ✅ |
| Egress (saída) | 1 GB/mês | ✅ |
| **min-instances = 0** | Cold start: ~1–2s Node.js | ✅ aceitável (operações assíncronas) |

**Custo real do MVP: R$ 0/mês** até escala real.

---

## Staging Environment

Ambiente paralelo para validar mudanças antes de promoção a produção.

**Backend (Cloud Run):**
- Deploy via [deploy-server-staging.sh](deploy-server-staging.sh)
- Service distinto em `southamerica-east1`, mesma região de prod
- Variáveis de ambiente em `server/.env.staging` (não versionado)

**Flutter Web:**
- Entry-point: [app/main_staging.dart](app/main_staging.dart) (variante de `main.dart`)
- Firebase options: classe `StagingFirebaseOptions` em [app/lib/firebase_options.dart](app/lib/firebase_options.dart) (gerada pela FlutterFire CLI, ao lado de `DefaultFirebaseOptions`)
- HTML shell: [app/web/staging_index.html](app/web/staging_index.html)
- Deploy: [deploy-web-staging.sh](deploy-web-staging.sh)
- Firebase Hosting config: [firebase.staging.json](firebase.staging.json)

**CI/CD:**
- [app/.github/workflows/deploy-staging.yml](app/.github/workflows/deploy-staging.yml)
- [app/.github/workflows/deploy-production.yml](app/.github/workflows/deploy-production.yml)

**Documentação operacional:** [app/DEPLOY_STAGING.md](app/DEPLOY_STAGING.md)

> Débito conhecido: bug pré-existente em `StagingFirebaseOptions.ios.storageBucket` ([firebase_options.dart:133](app/lib/firebase_options.dart#L133)) — string `'run nin-staging-494520.firebasestorage.app'` com espaço. Os `appId` de staging também estão como placeholders (`STAGING_APP_ID`); regenerar via FlutterFire CLI contra o projeto Firebase de staging real antes do primeiro deploy.

---

## Estrutura de Repositórios

```
renius-lab/runrun.server   → API Cloud Run (Node.js + TypeScript)
renius-lab/runrun.app      → App Flutter
```

Local de trabalho:
```
/Users/eduardovasqueskaizer/Projects/runnin.core/
├── app/          → Flutter (mobile + web)
├── docs/         → STACK.md, ROADMAP.md, PRODUCT_BLUEPRINT.md, FIGMA_IMPLEMENTATION_PLAN.md, GCP_SETUP.md
├── docs/figma/   → telas extraídas via MCP, DESIGN_SYSTEM.md, JOURNEYS.md
└── (server em repo separado)
```

---

## Arquitetura da API (Clean Architecture)

```
server/
├── src/
│   ├── main.ts                        ← bootstrap do servidor
│   ├── server.ts                      ← Express app factory
│   │
│   ├── shared/
│   │   ├── infra/
│   │   │   ├── http/
│   │   │   │   ├── middlewares/
│   │   │   │   │   ├── auth.middleware.ts      ← verifica Firebase JWT
│   │   │   │   │   ├── error.middleware.ts     ← handler global de erros
│   │   │   │   │   └── request-id.middleware.ts
│   │   │   │   └── router.ts
│   │   │   ├── firebase/
│   │   │   │   ├── firebase.client.ts          ← admin SDK singleton
│   │   │   │   └── firestore.client.ts
│   │   │   ├── llm/
│   │   │   │   ├── llm.interface.ts            ← abstração
│   │   │   │   ├── llm.factory.ts              ← seleção por env var
│   │   │   │   ├── gemini.adapter.ts           ← provider padrão atual
│   │   │   │   ├── groq.adapter.ts             ← opcional
│   │   │   │   └── together.adapter.ts         ← opcional
│   │   │   └── tts/
│   │   │       ├── tts.interface.ts
│   │   │       └── google-neural2.adapter.ts
│   │   ├── errors/
│   │   │   ├── app-error.ts
│   │   │   └── http-errors.ts
│   │   └── logger/
│   │       └── logger.ts                       ← Winston, JSON, Cloud Logging
│   │
│   └── modules/
│       ├── users/
│       │   ├── domain/
│       │   │   ├── user.entity.ts
│       │   │   └── user.repository.ts          ← interface
│       │   ├── infra/
│       │   │   └── firestore-user.repository.ts
│       │   ├── use-cases/
│       │   │   ├── upsert-profile.use-case.ts
│       │   │   └── get-profile.use-case.ts
│       │   └── http/
│       │       ├── user.controller.ts
│       │       └── user.routes.ts
│       │
│       ├── runs/
│       │   ├── domain/
│       │   │   ├── run.entity.ts
│       │   │   └── run.repository.ts
│       │   ├── infra/
│       │   │   └── firestore-run.repository.ts
│       │   ├── use-cases/
│       │   │   ├── create-run.use-case.ts
│       │   │   ├── add-gps-batch.use-case.ts   ← batch de pontos GPS
│       │   │   └── complete-run.use-case.ts
│       │   └── http/
│       │       ├── run.controller.ts
│       │       └── run.routes.ts
│       │
│       ├── plans/
│       │   ├── domain/
│       │   │   ├── plan.entity.ts
│       │   │   └── plan.repository.ts
│       │   ├── infra/
│       │   │   └── firestore-plan.repository.ts
│       │   ├── use-cases/
│       │   │   └── generate-plan.use-case.ts   ← LLM grande
│       │   └── http/
│       │       ├── plan.controller.ts
│       │       └── plan.routes.ts
│       │
│       ├── coach/
│       │   ├── domain/
│       │   │   ├── coach-report.entity.ts
│       │   │   └── coach-report.repository.ts    ← interface
│       │   ├── infra/
│       │   │   └── firestore-coach-report.repository.ts
│       │   ├── use-cases/
│       │   │   ├── coach-message.use-case.ts     ← LLM rápido (stream)
│       │   │   ├── coach-chat.use-case.ts
│       │   │   ├── get-coach-report.use-case.ts
│       │   │   └── generate-report.use-case.ts   ← LLM grande (async)
│       │   └── http/
│       │       ├── coach.controller.ts
│       │       └── coach.routes.ts
│       │
│       ├── notifications/                        ← Firestore-backed, idempotente por dia
│       │
│       └── gamification/                         ← previsto no desenho, ainda não implementado no código atual
│
├── Dockerfile
├── .env.example
├── tsconfig.json
└── package.json
```

---

## Arquitetura Flutter (Clean Architecture Hexagonal)

```
app/
└── lib/
    ├── main.dart
    ├── core/
    │   ├── theme/                      ← dark theme, paleta, tipografia, tokens Figma
    │   ├── router/
    │   │   └── app_router.dart         ← go_router, rotas, guards auth
    │   ├── network/
    │   │   └── api_client.dart         ← Dio + interceptors (auth JWT, retry)
    │   ├── widgets/                    ← biblioteca de componentes base (progress_bar, toggle, card, tab_bar)
    │   └── errors/
    │       ├── app_exception.dart
    │       └── failure.dart
    │
    ├── shared/
    │   ├── widgets/                    ← componentes consolidados de UI (cards, panels, layouts, navs)
    │   │   └── figma/                  ← componentes derivados das specs Figma (top_nav, bottom_nav, tab_bar, run_fab, zone_distribution)
    │   └── extensions/
    │       └── date_extensions.dart
    │
    └── features/
        ├── auth/
        │   ├── data/
        │   │   └── user_remote_datasource.dart
        │   └── presentation/
        │       └── pages/login_page.dart
        │
        ├── steps/                      ← entidades, BLoC e UI de progresso/etapas (Run Journey, onboarding)
        │
        ├── onboarding/
        │   └── presentation/
        │       └── pages/onboarding_page.dart
        │
        ├── home/
        │   ├── domain/
        │   │   └── use_cases/get_home_data_use_case.dart
        │   └── presentation/
        │       ├── cubit/home_cubit.dart
        │       └── pages/home_page.dart
        │
        ├── run/
        │   ├── domain/
        │   │   ├── entities/
        │   │   │   ├── run.dart
        │   │   │   └── gps_point.dart
        │   │   ├── repositories/run_repository.dart
        │   │   └── use_cases/
        │   │       ├── start_run_use_case.dart
        │   │       ├── track_gps_use_case.dart       ← stream de posição
        │   │       └── complete_run_use_case.dart
        │   ├── data/
        │   │   ├── repositories/run_repository_impl.dart
        │   │   └── datasources/
        │   │       ├── run_remote_datasource.dart    ← API
        │   │       └── run_local_datasource.dart     ← Hive
        │   └── presentation/
        │       ├── bloc/run_bloc.dart
        │       └── pages/
        │           ├── prep_page.dart
        │           ├── active_run_page.dart
        │           └── report_page.dart
        │
        ├── training/
        │   └── presentation/
        │       └── pages/training_page.dart
        │
        ├── history/
        │   └── presentation/
        │       └── pages/history_page.dart
        │
        └── profile/
            └── presentation/
                └── pages/
                    ├── account_page.dart
                    └── profile_page.dart
```

Observações do estado real:
- O app atual inicializa e autentica diretamente a partir de `main.dart` e `login_page.dart`.
- O onboarding é persistido localmente na box Hive `runrun_settings` com a chave `onboarding_completed`.
- A rota `/profile` hoje representa o menu `Conta`, e a edição do perfil fica em `/profile/edit`.

---

## Design System Migration (Figma → Flutter)

Migração incremental para alinhar a UI Flutter ao design system canônico do Figma. **Não há frontend web em outra stack** — toda a UI é Flutter.

**Documentos de referência:**
- [docs/FIGMA_IMPLEMENTATION_PLAN.md](docs/FIGMA_IMPLEMENTATION_PLAN.md) — plano em 5 fases (30-44 dias)
- [docs/figma/DESIGN_SYSTEM.md](docs/figma/DESIGN_SYSTEM.md) — 69 tokens de cor, 32 estilos tipográficos, 60+ componentes
- [docs/figma/JOURNEYS.md](docs/figma/JOURNEYS.md) — 7 jornadas (onboarding, home, training, run, history, profile, coach)

**Estado por tela:**

| Tela           | Status         | Task Paperclip |
|----------------|----------------|----------------|
| HOME           | em fila (todo) | SUP-303        |
| TREINO         | em fila (todo) | SUP-306        |
| HISTÓRICO      | em fila (todo) | SUP-305        |
| GAMIFICAÇÃO    | em fila (todo) | SUP-304        |
| PERFIL         | em fila (todo) | SUP-222        |
| Step UI        | em fila (todo) | SUP-193        |
| Badge system   | em fila (todo) | SUP-152        |
| RUN / COACH / ONBOARDING | a planejar | —    |

**Débito conhecido (DRY):** possível duplicação entre `app/lib/shared/widgets/*.dart` e `app/lib/shared/widgets/figma/*.dart` (exemplo: `app_top_nav.dart` vs `figma/figma_top_nav.dart`). Consolidar quando a migração das telas listadas acima estabilizar — qual conjunto vira fonte de verdade é decisão a tomar ao fim do ciclo.

---

## Contratos da API

### Base URL
```
https://runnin-api-rogiz7losq-rj.a.run.app/v1   (produção atual)
http://localhost:3000/v1                                         (local)
```

### Auth
Todos os endpoints autenticados exigem:
```
Authorization: Bearer <Firebase ID Token>
```

### Endpoints

#### Health
```
GET  /health
→ { status: "ok", version: "1.0.0", timestamp: "..." }
```

#### Users
```
GET    /v1/users/me
→ UserProfile

PATCH  /v1/users/me
body: { name?, level?, goal?, frequency?, hasWearable?, preferredRunTime? }
→ UserProfile

POST   /v1/users/onboarding
body: { name, level, goal, frequency, birthDate, weight, height, hasWearable }
→ { user: UserProfile, planId: string }   ← gera plano automaticamente
```

#### Plans
```
GET    /v1/plans/current
→ Plan | null

POST   /v1/plans/generate
body: { goal, level, weeksCount?, currentFitness? }
→ { planId: string }   ← geração assíncrona, ouvir Firestore

GET    /v1/plans/:id
→ Plan
```

#### Runs
```
POST   /v1/runs
body: { planSessionId?, type, targetPace?, targetDistance? }
→ { runId: string }

PATCH  /v1/runs/:id/gps
body: { points: GpsPoint[] }   ← batch de até 100 pontos
→ { accepted: number }

PATCH  /v1/runs/:id/complete
body: { distanceM, durationS, avgBpm?, maxBpm? }
→ { run: Run, reportId: string }   ← relatório gerado async

GET    /v1/runs/:id
→ Run

GET    /v1/runs
query: { limit?, cursor? }
→ { runs: Run[], nextCursor? }
```

#### Coach
```
POST   /v1/coach/message          ← durante corrida (streaming SSE)
body: { runId, event: "km_reached"|"pace_alert"|"question", context: CoachContext }
→ SSE stream de texto (chunks do LLM)

GET    /v1/coach/report/:runId    ← relatório pós-corrida
→ CoachReport | { status: "pending" }

POST   /v1/coach/chat             ← chat assíncrono (fora da corrida)
body: { message, context? }
→ { reply: string }
```

#### Gamification
```
Ainda não implementado como endpoint dedicado no backend atual.
```

### Tipos principais
```typescript
interface UserProfile {
  id: string;
  name: string;
  level: 'iniciante' | 'intermediario' | 'avancado';
  goal: string;
  frequency: number;
  premium: boolean;
  operatorId?: string;
  createdAt: string;
}

interface GpsPoint {
  lat: number;
  lng: number;
  ts: number;        // Unix ms
  accuracy: number;  // metros — filtrar se > 15
  pace?: number;     // min/km calculado
  bpm?: number;
}

interface Run {
  id: string;
  userId: string;
  status: 'active' | 'completed' | 'abandoned';
  type: string;
  distanceM: number;
  durationS: number;
  avgPace: string;
  avgBpm?: number;
  xpEarned?: number;
  coachReportId?: string;
  createdAt: string;
}

interface CoachContext {
  currentPaceMinKm: number;
  targetPaceMinKm: number;
  distanceM: number;
  elapsedS: number;
  bpm?: number;
  kmReached?: number;
  question?: string;
}
```

---

## Observabilidade

### Backend (Cloud Run)
```typescript
// Winston com JSON — Cloud Logging processa automaticamente
logger.info('run.completed', {
  runId,
  userId,
  distanceM,
  durationS,
  requestId: req.headers['x-request-id'],
});

logger.error('llm.request.failed', {
  provider: 'groq',
  model: 'qwen3-32b',
  latencyMs,
  error: err.message,
});
```

- **Structured logging:** Winston + JSON format. Cloud Logging indexa automaticamente.
- **Request ID:** gerado no middleware, propagado em todos os logs da request.
- **Latência de LLM/TTS:** logar `provider`, `model`, `latencyMs`, `tokensUsed` em toda chamada.
- **Health endpoint:** `GET /health` — retorna 200 com versão + timestamp. Cloud Run usa pra readiness probe.
- **Error tracking:** Firebase Crashlytics no Flutter. Cloud Error Reporting no backend (captura automaticamente logs de erro do Cloud Logging).
- **Alertas:** Firebase Budget Alert no console GCP + Cloud Monitoring alert se `/health` falhar.

### Flutter
- Firebase Crashlytics — captura exceções não tratadas
- Firebase Performance — tempo de rede (Dio interceptor)
- Firebase Analytics — eventos de negócio (`run_started`, `run_completed`, `coach_message_sent`)

---

## Configuração do Projeto

### .env.example (server)
```env
PORT=3000
NODE_ENV=development

# Firebase Admin
FIREBASE_PROJECT_ID=runnin-494520
FIREBASE_CLIENT_EMAIL=...
FIREBASE_PRIVATE_KEY=...

# LLM
LLM_REALTIME_PROVIDER=gemini
LLM_ASYNC_PROVIDER=gemini
GEMINI_API_KEY=...
GROQ_API_KEY=...             # opcional
TOGETHER_API_KEY=...         # opcional

# TTS
GOOGLE_TTS_API_KEY=...

# Observabilidade
LOG_LEVEL=info
```

### Dockerfile (server)
```dockerfile
FROM node:20-alpine AS builder
WORKDIR /app
COPY package*.json ./
RUN npm ci
COPY . .
RUN npm run build

FROM node:20-alpine
WORKDIR /app
COPY --from=builder /app/dist ./dist
COPY --from=builder /app/node_modules ./node_modules
COPY package*.json ./
ENV NODE_ENV=production
EXPOSE 3000
CMD ["node", "dist/main.js"]
```

---

## TODO — Prioridades Reais

### PRÉ-REQUISITOS (fazer antes de começar)
- [x] Criar projeto no Firebase Console (`runnin-494520`)
- [x] Ativar Firestore
- [x] Ativar Firebase Auth
- [x] Ativar Anonymous Auth
- [ ] Ativar Google Sign-In em produção, se ainda não estiver habilitado
- [ ] Criar conta Google Cloud (projeto já criado pelo Firebase)
- [x] Ativar Cloud Run API no GCP
- [x] Ativar Cloud Logging API
- [ ] Criar Service Account para Cloud Run (roles: Firestore User, Cloud Logging Writer)
- [x] Repositório monorepo local com `server/` e `app/`
- [ ] Instalar: Node.js 20, Flutter 3.x, Firebase CLI, Google Cloud CLI

---

### Backend — Estado Atual

#### Infra e deploy
- [x] Estrutura `server/` em Node.js + TypeScript
- [x] Healthcheck publicado em `GET /health`
- [x] Build local validado
- [x] Deploy no Cloud Run concluído
- [x] Backend online e saudável na revisão `runrun-api-00003-gvc`
- [ ] Configurar segredos e variáveis de produção no Cloud Run (`GEMINI_API_KEY` e providers opcionais, se usados)
- [ ] Validar fluxo real completo após onboarding com geração de plano e dados persistidos

#### Módulos implementados
- [x] `users`
- [x] `runs`
- [x] `plans`
- [x] `coach`

#### Pendências reais no backend
- [ ] Garantir provider LLM ativo para geração de plano e relatório pós-corrida
- [ ] Validar seleção por env var (`LLM_REALTIME_PROVIDER` e `LLM_ASYNC_PROVIDER`)
- [ ] Validar contratos de erro e estados vazios em produção
- [ ] Criar módulos ausentes: `history` dedicado, `notifications`, `health`, `exams`, `gamification`
- [ ] Introduzir fila/eventos para tarefas assíncronas de IA e notificações
- [x] Estruturar ambientes `dev`, `staging` e `prod` — staging configurado (Cloud Run + Firebase Hosting + workflows), pendente primeiro deploy real

---

### Flutter — Estado Atual

#### Estrutura e navegação
- [x] App Flutter configurado com Firebase Web/Android/iOS
- [x] Router com login, onboarding, home, treino, corrida, histórico, dashboard e conta
- [x] Guardas de autenticação e persistência local do onboarding
- [x] Menu `Conta` em `/profile`
- [x] Tela dedicada de edição em `/profile/edit`
- [x] Logout implementado

#### Fluxos implementados
- [x] Login com Google
- [x] Login anônimo
- [x] Onboarding com persistência local
- [x] Home conectada ao backend
- [x] Training, History, Profile e Account disponíveis
- [x] Run flow com telas de preparo, corrida ativa e relatório

#### Pendências reais no app
- [ ] Validar em produção o fluxo `login -> onboarding -> plano -> treino`
- [ ] Fechar estados vazios e mensagens de erro mais amigáveis em todas as telas
- [ ] Validar tracking real de GPS em device físico
- [ ] Testar build release Android
- [/] Revisar paridade visual com o protótipo em telas-chave — em andamento via Design System Migration (ver seção dedicada acima)

#### Design System Migration (Flutter ← Figma)
- [ ] HOME — migrar para tokens/componentes Figma (SUP-303)
- [ ] TREINO — migrar para tokens/componentes Figma (SUP-306)
- [ ] HISTÓRICO — migrar para tokens/componentes Figma (SUP-305)
- [ ] GAMIFICAÇÃO — migrar para tokens/componentes Figma (SUP-304)
- [ ] PERFIL — ajustes Figma (SUP-222) + GamificationStatsRow (SUP-317) + Body Metrics Grid (SUP-136) + Action Buttons (SUP-140)
- [ ] Step UI — componentes de progresso de etapas (SUP-193)
- [ ] BADGES — 21-badge system (SUP-152) + Badge card (SUP-144)
- [ ] Bottom Nav compartilhada (SUP-141) + revisão (SUP-282)
- [ ] Consolidar `shared/widgets/*` vs `shared/widgets/figma/*` (DRY) ao fim do ciclo

---

### Backlog de Produto

#### Curto prazo
- [ ] Confirmar geração real de plano após onboarding
- [ ] Confirmar carregamento real de `users/me`, `runs` e `plans/current`
- [ ] Revisar UX de login, conta e onboarding com dados reais
- [ ] Garantir observabilidade mínima para erros de produção

#### Médio prazo
- [ ] Coach pós-corrida e chat assíncrono com provider IA validado
- [ ] Share card de corrida
- [ ] Notificações push
- [ ] Gamificação básica (XP, streak, badges)
- [ ] Integrações Health Connect / HealthKit

#### Longo prazo
- [ ] Billing / premium
- [ ] Wearables completos
- [ ] Exames / saúde avançada
- [ ] Multi-tenant / white-label

---

## Checklist de Qualidade Atual

### Backend
- [x] Dockerfile e build local funcionando
- [x] `/health` respondendo em produção
- [x] Middleware de auth presente nas rotas protegidas
- [x] Logging estruturado configurado
- [ ] Revisar padronização final de erros HTTP em todos os endpoints
- [ ] Garantir ausência de segredos hardcoded

### Flutter
- [x] Onboarding não reaparece sozinho após concluído
- [x] Login anônimo e logout funcionando no app
- [x] Telas principais navegam sem crash mesmo quando backend retorna `401` ou vazio
- [ ] Validar permissões e tracking de GPS em device real
- [ ] Validar release build Android
- [ ] Confirmar experiência completa com dados reais

---

## Comandos de referência rápida

```bash
# Rodar API local
cd server && npm run dev

# Deploy API no Cloud Run
gcloud run deploy runrun-api \
  --source . \
  --region southamerica-east1 \
  --allow-unauthenticated \
  --min-instances 0 \
  --max-instances 10 \
  --memory 512Mi \
  --set-env-vars "NODE_ENV=production,FIREBASE_PROJECT_ID=runnin-494520"

# Ver logs Cloud Run em tempo real
gcloud run logs tail runrun-api --region southamerica-east1

# Rodar Flutter em modo debug (device físico para GPS)
cd app && flutter run --flavor dev

# Build release APK
cd app && flutter build apk --release --flavor prod
```

---

*Atualizado em 2026-05-15 após cleanup de artefatos fora-de-stack e re-baseline do Paperclip (cancelamento das tasks "step front-end"/Vite+React e desbloqueio das tasks de Design System Migration). Server: refactor do módulo `coach` para Clean Architecture (CoachReportRepository), remoção do diretório vazio `wearable/`, server/.gitignore criado.*
