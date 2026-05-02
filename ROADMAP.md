# runrun.ai — Roadmap e Status Atual

> Status em 2026-04-12: app Flutter e backend Node.js publicados, com auth Firebase, onboarding, home, treino, corrida, histórico, coach, dashboard e conta já implementados em diferentes níveis de maturidade.
> Stack: Flutter (mobile/web) + Node.js TypeScript (Cloud Run) + Firebase.
> Foco atual: estabilizar fluxos reais, alinhar deploys e fechar gaps para dados de produção.

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

## Estrutura de Repositórios

```
renius-lab/runrun.server   → API Cloud Run (Node.js + TypeScript)
renius-lab/runrun.app      → App Flutter
```

Local de trabalho:
```
/home/nalin/Projects/runrun.app/
├── server/   → API
├── app/      → Flutter
└── docs/     → STACK.md, ROADMAP.md, etc.
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
│       │   ├── use-cases/
│       │   │   ├── coach-message.use-case.ts   ← LLM rápido (stream)
│       │   │   └── generate-report.use-case.ts ← LLM grande (async)
│       │   └── http/
│       │       ├── coach.controller.ts
│       │       └── coach.routes.ts
│       │
│       └── gamification/             ← previsto no desenho, ainda não implementado no código atual
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
    │   ├── theme/
    │   │   ├── app_theme.dart          ← dark theme, cores, fontes
    │   │   └── app_colors.dart
    │   ├── router/
    │   │   └── app_router.dart         ← go_router, rotas, guards auth
    │   ├── network/
    │   │   └── api_client.dart         ← Dio + interceptors (auth JWT, retry)
    │   └── errors/
    │       ├── app_exception.dart
    │       └── failure.dart
    │
    ├── shared/
    │   ├── widgets/
    │   │   ├── accent_button.dart
    │   │   ├── section_head.dart
    │   │   └── loading_overlay.dart
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
- [ ] Estruturar ambientes `dev`, `staging` e `prod`

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
- [ ] Revisar paridade visual com o protótipo em telas-chave

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

*Atualizado em 2026-04-12 após deploy da revisão `runrun-api-00003-gvc`.*
