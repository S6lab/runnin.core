# runnin.core

Monorepo do **runnin.ai** — AI Running Coach.

App Flutter (iOS + Apple Watch + Android + Web) + backend Node em Cloud Run, com geração de plano via Gemini Pro, coach voz ao vivo via Gemini Live, RAGs global + per-user (exames OCR), e revisão semanal automática.

## Estrutura

```
app/              Flutter (iOS first, Android, Web)
  ios/RunninWatch Apple Watch companion (Swift)
server/           Node + Express + TypeScript em Cloud Run
docs/
  architecture/   📘 Arquitetura E2E — comece aqui
  DEPLOY.md       Deploy + CI/CD (branches, Codemagic, Cloud Build)
  coach-ai-v3/    Especificação de design dos momentos IA
```

## 📘 Arquitetura completa

Documentação técnica vive em [`/docs/architecture/`](docs/architecture/). Começa pelo [README](docs/architecture/README.md) que tem o big-picture do fluxo IA E2E e índice dos sub-docs:

- [00-overview](docs/architecture/00-overview.md) — Visão geral, stack, princípios
- [01-coach-ai](docs/architecture/01-coach-ai.md) — Gemini Live, cues, rotação, ducking
- [02-plan-generation](docs/architecture/02-plan-generation.md) — Pipeline 5-fase + weekly revision
- [03-rags](docs/architecture/03-rags.md) — RAG global + per-user (exames)
- [04-prompts](docs/architecture/04-prompts.md) — config-store, defaults, personas, knobs
- [05-app-protocols](docs/architecture/05-app-protocols.md) — REST + WS + WCSession
- [06-telemetry](docs/architecture/06-telemetry.md) — Telemetry timeline, biometric sync
- [07-observability](docs/architecture/07-observability.md) — Logging, token tracking, admin

## Como rodar localmente

Server:

```bash
cd server
npm install
npm run dev      # localhost:3000
```

App (Chrome local apontando pro server):

```bash
cd app
flutter pub get
flutter run -d chrome --dart-define=API_BASE_URL=http://localhost:3000
```

Detalhes em [`app/README.md`](app/README.md) e [`server/README.md`](server/README.md) (em construção).

## Deploy e CI/CD

Convenção "1 branch = 1 ambiente". Push em branch dispara pipeline automático.

| Branch | Server (Cloud Run) | Mobile | Web (Firebase) |
|---|---|---|---|
| `main` | — | — | prod |
| `release` | prod `runnin-api` | — | — |
| `release-ios` | — | TestFlight | — |
| `release-android` | — | Play Internal | — |
| `homologation` | staging `runnin-api-staging` | — | staging |

Detalhes completos em [`docs/DEPLOY.md`](docs/DEPLOY.md).

## Stack

- **App**: Flutter 3.x, Bloc, Dio, Hive, GoRouter
- **Watch**: Swift native, HKWorkoutSession + HKLiveWorkoutBuilder, WCSession
- **Backend**: Node 20 + Express + TypeScript em Cloud Run (`southamerica-east1`)
- **DB**: Firestore Native + Storage
- **Auth**: Firebase Auth (anônimo, email, Apple, Google, telefone)
- **LLM**: Gemini 3.5 Flash (texto), 3.1 Pro Preview (plan), 2.5 Flash Live (voz), embedding-001 (RAG)
- **CI**: GitHub Actions (server + web) + Codemagic (mobile)

## Memórias importantes

Persistem entre sessões em `~/.claude/projects/.../memory/`:

- `project_plan_revision_architecture` — `weeks=BASE imutável + adjustedWeeks=vigente`
- `project_health_plugin_per_type_query` — NUNCA passar lista batch pro `health.getHealthDataFromTypes` (loop tipo-por-tipo)
- `project_plan_personalization_priority` — `durationMin/hidratação/nutrição` por dia
- `project_run_type_freemium_gate` — freemium só roda Free Run; premium escolhe planned vs Free Run
- `iOS extension version sync` — bump iOS toca pubspec + 3 build configs do pbxproj
