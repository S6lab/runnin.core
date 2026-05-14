# runnin.ai

**AI Running Coach** — Your personal running coach powered by artificial intelligence.

runnin.ai combines guided onboarding, AI-generated training plans, real-time coaching during runs, and detailed post-run reports to help runners train with more consistency and intelligence.

---

## Architecture

```
┌──────────────────────────────────────────────────────────────────┐
│                        MOBILE (Flutter)                          │
│  Clean Architecture · Riverpod (state) · go_router (navigation)  │
│  geolocator (GPS) · flutter_map + OSM (maps) · Hive (local)     │
│  Firebase SDK (Auth, Firestore, Analytics, Crashlytics)          │
└──────────────────────┬───────────────────────────────────────────┘
                       │ HTTP (REST)
┌──────────────────────▼───────────────────────────────────────────┐
│                    BACKEND (Cloud Run)                            │
│  Node.js + TypeScript · Express · Clean Architecture modules      │
│  Firestore (DB) · Firebase Admin · Winston (logging)             │
├──────────────────────┬───────────────────────────────────────────┤
│       LLM PROVIDERS (pluggable adapters)     │  TTS / Other      │
│  Gemini (default) · Groq (real-time)         │  Google Neural2   │
│  Together AI (async/deep analysis)           │  (streaming)      │
└──────────────────────────────────────────────────────────────────┘
```

### Clean Architecture — Backend (`server/`)

```
server/src/
├── main.ts                           ← App bootstrap
├── server.ts                         ← Express factory
├── shared/infra/                     ← Cross-cutting infrastructure
│   ├── http/middlewares/              ← Auth, error, request-id
│   ├── firebase/                     ← Admin SDK + Firestore clients
│   ├── llm/                          ← LLM abstraction + adapters (Gemini, Groq, Together)
│   └── tts/                          ← TTS abstraction + Google Neural2 adapter
├── shared/errors/                    ← AppError, HTTP errors
├── shared/logger/                    ← Winston structured JSON logger
└── modules/                          ← Domain modules (clean architecture)
    ├── users/                        ← User profile, onboarding
    ├── runs/                         ← Run tracking, GPS points, completion
    ├── plans/                        ← Training plan generation & retrieval
    ├── coach/                        ← Real-time coaching & post-run reports
    └── gamification/                 ← (planned) XP, badges, streaks
```

### Clean Architecture — Mobile (`app/`)

```
app/lib/
├── main.dart
├── core/                             ← Theme, router, network client, errors
├── shared/widgets/                   ← Shared UI components
└── features/                         ← Feature modules
    ├── auth/                         ← Login (Google, anonymous)
    ├── onboarding/                   ← Multi-step wizard
    ├── home/                         ← Dashboard with session of the day
    ├── training/                     ← Weekly plan view
    ├── run/                          ← Active run tracking (GPS, coach)
    ├── history/                      ← Past runs & analytics
    ├── coach/                        ← Coach chat & reports
    └── profile/                      ← Account & settings
```

---

## Stack

| Layer | Component | Technology |
|-------|-----------|-----------|
| **Mobile** | Framework | Flutter (Dart 3.x) |
| **Mobile** | State management | Riverpod 2.x + BLoC |
| **Mobile** | Navigation | go_router |
| **Mobile** | GPS tracking | geolocator + flutter_background_service |
| **Mobile** | Maps | flutter_map + OpenStreetMap |
| **Mobile** | Local storage | Hive (local-first during runs) |
| **Mobile** | Wearables | health plugin (Health Connect + HealthKit) |
| **Backend** | Runtime | Node.js 20 + TypeScript 6.x |
| **Backend** | Framework | Express 5.x |
| **Backend** | Database | Firestore (Firebase) |
| **Backend** | Auth | Firebase Auth (Phone, Google, Anonymous) |
| **Backend** | Push | Firebase Cloud Messaging |
| **Backend** | Logging | Winston (structured JSON) |
| **Backend** | Validation | Zod |
| **AI** | LLM (real-time) | Qwen3-32B via Groq (sub-second) |
| **AI** | LLM (async) | DeepSeek V3.2 via Together AI |
| **AI** | LLM (fallback) | Gemini 2.5 Flash-Lite |
| **AI** | TTS | Google Cloud Text-to-Speech Neural2 |
| **Infra** | Compute | Google Cloud Run (southamerica-east1) |
| **Infra** | Monitoring | Firebase Crashlytics + Cloud Logging |

---

## Status

**Current phase:** MVP stabilization (post-bootstrap, pre-production)

### Implemented
- [x] Backend published on Cloud Run (`runnin-api`)
- [x] Firebase Auth (anonymous + Google Sign-In)
- [x] Onboarding with local persistence
- [x] User profile CRUD
- [x] Run tracking (GPS, completion, history)
- [x] Training plan generation & retrieval
- [x] Coach real-time messaging (SSE streaming)
- [x] Post-run reports
- [x] Home, Training, History, Profile, Account screens

### In stabilization
- [ ] End-to-end flow validation (login → onboarding → plan → run)
- [ ] LLM provider configuration for production
- [ ] GPS tracking validation on physical devices
- [ ] Error states and empty state UX

### Not yet implemented
- [ ] Gamification (XP, badges, streaks)
- [ ] Notifications (FCM)
- [ ] Health Connect / HealthKit integration
- [ ] Medical exams & advanced health
- [ ] Billing / premium
- [ ] Wearables (BLE direct)
- [ ] Multi-tenant / white-label

---

## Local Development

### Prerequisites

- Node.js 20+
- Flutter 3.x
- Firebase CLI (`npm install -g firebase-tools`)
- Google Cloud SDK (`gcloud`)
- A Firebase project (contact team for access)

### Backend

```bash
# Install dependencies
cd server
npm install

# Configure environment
cp .env.example .env
# Edit .env with your Firebase project credentials & API keys

# Start dev server with hot-reload
npm run dev
```

### Mobile

```bash
cd app

# Get Flutter dependencies
flutter pub get

# Run on Chrome (points to local server)
flutter run -d chrome --dart-define=API_BASE_URL=http://localhost:3000

# Run on physical device (for GPS testing)
flutter run --flavor dev
```

---

## Deployment

### Backend (Cloud Run)

```bash
./deploy-server.sh
```

The script reads environment variables from `server/.env.production`, builds the Docker container, and deploys to Cloud Run in `southamerica-east1`.

### Frontend (Firebase Hosting)

```bash
./deploy-web.sh
```

---

## API Overview

Base URL (production): `https://runnin-api-rogiz7losq-rj.a.run.app/v1`

All authenticated endpoints require:
```
Authorization: Bearer <Firebase ID Token>
```

### Health
```
GET /health → { status, version, timestamp }
```

### Users
| Method | Path | Description |
|--------|------|-------------|
| GET | /v1/users/me | Get current user profile |
| PATCH | /v1/users/me | Update profile |
| POST | /v1/users/onboarding | Complete onboarding + generate plan |

### Plans
| Method | Path | Description |
|--------|------|-------------|
| GET | /v1/plans/current | Get current training plan |
| POST | /v1/plans/generate | Generate new plan (async) |
| GET | /v1/plans/:id | Get plan by ID |

### Runs
| Method | Path | Description |
|--------|------|-------------|
| POST | /v1/runs | Start a new run |
| PATCH | /v1/runs/:id/gps | Upload GPS points batch |
| PATCH | /v1/runs/:id/complete | Complete a run |
| GET | /v1/runs/:id | Get run details |
| GET | /v1/runs | List runs (paginated) |

### Coach
| Method | Path | Description |
|--------|------|-------------|
| POST | /v1/coach/message | Real-time coaching (SSE stream) |
| GET | /v1/coach/report/:runId | Get post-run coach report |
| POST | /v1/coach/chat | Async coaching chat |

Full API contracts and types are documented in [ROADMAP.md](./ROADMAP.md).

---

## Project Resources

- [Stack & Architecture Decisions](./STACK.md)
- [Product Roadmap & Status](./ROADMAP.md)
- [Product Blueprint](./docs/PRODUCT_BLUEPRINT.md)
- [Project Summary](./docs/PROJECT_SUMMARY.md)
- [Design System](./docs/DESIGN_SYSTEM.md)

---

*runnin.ai — AI Running Coach. Built with Flutter, Node.js, Firebase, and LLMs.*
