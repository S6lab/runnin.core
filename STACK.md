# RunCoach AI — Stack Técnica & Decisões de Arquitetura

> Documento de referência técnica consolidado.
> Baseado em: protótipo Figma Make + Think Tank técnico (março 2026).

---

## 1. Sugestões de Nome

O domínio `runrun.ai` é descritivo demais e tem repetição. Sugestões com maior potencial de marca:

| Nome | Conceito | Tagline natural | Por quê funciona |
|------|---------|----------------|-----------------|
| **Rumo** | "Rumo/direção" em PT-BR | "Rumo aos 10K" | Curto, memorável, único, duplo sentido (rota física + objetivo de vida) |
| **Ritmo** | "Rhythm" — core do coaching de corrida | "No seu ritmo, no seu nível" | Palavra-chave de qualquer corredor, coaching implícito |
| **Impulso** | Impulso/push — energia de arranque | "O impulso que você precisava" | Remete a motivação + física da corrida |
| **Pulso** | Pulso cardíaco + wearables | "Escuta o seu pulso" | Conecta coach, BPM e wearables numa só palavra |
| **Volta** | Volta (lap) + "volta a correr" | "Sua próxima volta começa aqui" | Retenção embutida no nome |

**Recomendação: `Rumo`** — curto (5 letras), sem ambiguidade em inglês ou português, domínio `.app` provavelmente disponível, tagline natural "Rumo aos 10K" alinha diretamente com o produto.

---

## 2. Visão Geral da Stack

```
┌─────────────────────────────────────────────────────┐
│                   MOBILE (Flutter)                   │
│  GPS nativo · Health Connect/Kit · BLoC/Riverpod     │
│  Hive (local-first) · flutter_map (OpenStreetMap)    │
└─────────────────┬───────────────────────────────────┘
                  │ Firebase SDK (FlutterFire)
┌─────────────────▼───────────────────────────────────┐
│              BACKEND (Firebase BaaS)                 │
│  Firestore · Cloud Functions (Node 20) · FCM         │
│  Phone Auth · Remote Config · Crashlytics            │
└────────┬──────────────────────────┬─────────────────┘
         │ HTTP direto (baixa latência)  │ async
┌────────▼──────────┐    ┌────────────▼──────────────┐
│   IA REAL-TIME    │    │   IA ASSÍNCRONA           │
│  Qwen3-32B/Groq   │    │  DeepSeek V3.2/Together   │
│  Google Neural2   │    │  Google Neural2 (relatório)│
│  TTS streaming    │    │  Geração de plano/report  │
└───────────────────┘    └───────────────────────────┘
```

---

## 3. Análise CAP — Escolha do Banco

### O Teorema CAP no contexto do app

O app tem duas realidades opostas:

| Momento | Rede disponível? | Prioridade CAP |
|---------|-----------------|----------------|
| **Durante a corrida** (GPS tracking, dados locais) | Frequentemente não | **AP** — Disponibilidade + Tolerância a Partições |
| **Fora da corrida** (plano, relatório, perfil, gamificação) | Sim (WiFi/4G normal) | **CP** — Consistência + Tolerância a Partições |

**Conclusão:** O app exige estratégia híbrida — **local-first durante a corrida, consistência eventual no sync**.

### Firestore vs Supabase — decisão definitiva

| Critério | Firestore (Firebase) | Supabase (PostgreSQL) |
|---------|---------------------|----------------------|
| **CAP** | CP com eventual consistency (Firestore listeners) | CP (PostgreSQL ACID) |
| **Local-first** | Offline persistence nativa (SDK faz cache automático) | Requer configuração manual |
| **Real-time** | Listeners nativos, otimizados pra mobile | Logical replication via WebSocket |
| **Flutter SDK** | FlutterFire — oficial, melhor suporte | community-maintained, bom mas menos battle-tested |
| **Ecossistema** | Maps, FCM, Analytics, Crashlytics — 1 billing | Cada serviço é fornecedor separado |
| **Queries complexas** | Limitado (sem joins) | SQL completo — muito mais flexível |
| **Vendor lock-in** | Alto — API proprietária | Baixo — PostgreSQL é padrão |
| **Pricing** | Pay-as-you-go (imprevisível) | $25/mês fixo |
| **Free tier** | 50K reads/dia, 20K writes/dia | 500MB DB, 1GB storage |
| **Multi-tenant (operadoras)** | Identity Platform — nativo | Row Level Security — nativo |

### Decisão: **Firestore** (com proteções arquiteturais)

**Justificativa principal:** Para um founder solo com produto em escala inicial (0–50K users), o ecossistema Firebase unificado reduz drasticamente a complexidade operacional. Maps, FCM, Analytics, Crashlytics, Auth, Remote Config — tudo num console, um SDK, um billing.

**Proteções obrigatórias:**
- **Repository Pattern** desde o dia 1 — código nunca fala com Firestore diretamente, sempre via interface abstrata. Migrar pra Supabase eventualmente = trocar implementação do repository, não reescrever o app.
- **Firebase Budget Alerts** configurados antes de produção.
- Preferir `get()` a listeners quando real-time não é necessário.

**Quando reavaliar:** >50K users E custo Firestore >10% da receita → migração pra Supabase viabilizada pelo Repository Pattern.

### Modelo de dados Firestore

```
firestore/
├── users/{userId}
│   ├── profile:        { name, phone, level, goal, operator_id, premium }
│   ├── preferences:    { alerts, coach_voice, run_time }
│   ├── gamification:   { xp, level, streak, badges[], last_run_date }
│   └── health_connect: { last_sync, permissions[] }
│
├── users/{userId}/runs/{runId}
│   ├── metadata:     { date, distance_m, duration_s, avg_pace, status }
│   ├── plan:         { type, target_pace, intervals[] }
│   ├── coach_report: { summary, insights[], next_suggestion }
│   └── gps_points/  (subcollection — evita limite 1MB/doc)
│       └── {pointId}: { lat, lng, ts, accuracy, pace, bpm }
│
├── users/{userId}/plans/{planId}
│   ├── goal, duration_weeks, current_week
│   └── weeks/{weekId}/sessions/{sessionId}
│
├── operators/{operatorId}          ← white-label / DCB
│   ├── config:  { name, logo_url, colors, theme }
│   └── billing: { model, price, revenue_share }
│
├── benchmarks/{routeHash}          ← agregado, nunca individual
│   └── stats: { avg_pace_by_level, runner_count, last_updated }
│
└── gamification_rules/{ruleId}     ← Remote Config alternativo
    └── { type, threshold, badge_name, xp_reward }
```

---

## 4. Hosting — Cloud Run vs Alternativas

### O que precisa de hosting (fora do Firebase)

O Firebase Cloud Functions cobre a maioria do backend. O que pode exigir um servidor dedicado:
- Proxy de LLM (se quiser adicionar cache, rate limiting, logging centralizado)
- Serviços de longa duração (websocket pra coach real-time no futuro)
- APIs internas (white-label, integrações DCB customizadas)

### Opções avaliadas

| Plataforma | Modelo | Custo estimado (servidor leve) | Cold start | Ideal para |
|-----------|--------|-------------------------------|-----------|-----------|
| **Cloud Run (GCP)** | Pay-per-request, escala a zero | ~$0–15/mês no MVP, ~R$ 0–90 | ~1–3s (sem min instances) | Dentro do ecossistema Google, integra com Firebase fácil |
| **Fly.io** | VM persistente, billing por hora | ~$3–10/mês (256MB RAM) | Zero (sempre ligado) | Servidor barato, sem cold start, bom pra websockets |
| **Railway** | Container, $5 crédito grátis/mês | ~$5–10/mês | Zero | Simplicidade máxima, deploy em 1 clique |
| **Render** | Container, free tier com sleep | ~$0 (free) / $7 (sem sleep) | ~30s no free tier | Protótipo grátis |
| **Cloud Functions Gen2** | Já no Firebase, mesmo ecossistema | Incluso no Firebase billing | ~1–3s | A solução padrão — evita mais um fornecedor |

### Decisão: **Cloud Functions + Cloud Run como fallback**

**Para o MVP:** Cloud Functions Gen2 (Node.js 20) cobre tudo — triggers Firestore, HTTP endpoints, scheduled jobs. Já está dentro do ecossistema Firebase, sem fornecedor extra.

**Se precisar de servidor dedicado** (websockets, proxy LLM com estado): **Fly.io** ou **Cloud Run com `minInstances: 1`**.

- **Fly.io** é mais barato para servidores always-on (R$ 18–60/mês) vs Cloud Run com minInstances (~R$ 30–80/mês).
- **Cloud Run** faz mais sentido quando o serviço é event-driven e pode escalar a zero (paga só o que usa).

**Regra:** Começar com Cloud Functions. Só adicionar Cloud Run/Fly.io se uma necessidade concreta surgir.

---

## 5. Geolocalização — GPS Nativo, Zero Custo de API

### Estratégia: local-first, GPS do próprio dispositivo

A estratégia mais econômica e eficiente é usar exclusivamente o GPS do dispositivo do usuário. **Não há necessidade de API de geolocalização externa** — as coordenadas vêm do hardware do celular.

```
GPS do celular (LocationManager / CLLocationManager)
       │
       ▼
Plugin geolocator (Flutter)
       │
       ├── Filtragem de ruído (GPS Jump Detection: accuracy > 15m → descarta)
       ├── Suavização de pace (média móvel 3 pontos)
       ├── Adaptive polling (1–3s baseado em velocidade + bateria)
       │
       ▼
Hive (armazenamento local durante a corrida)
       │
       ▼ (após corrida finalizada)
Firestore (sync dos gps_points)
```

### Pacotes Flutter para geolocalização

| Pacote | Finalidade | Custo | Notas |
|--------|-----------|-------|-------|
| [`geolocator`](https://pub.dev/packages/geolocator) | GPS em tempo real + permissões | Grátis | Plugin oficial, cobre Android + iOS |
| [`flutter_background_service`](https://pub.dev/packages/flutter_background_service) | Manter GPS ativo em background | Grátis | Necessário para tracking durante corrida com tela bloqueada |
| [`hive_flutter`](https://pub.dev/packages/hive_flutter) | Persistência local dos pontos GPS | Grátis | Rápido, leve, sem configuração |

**Alternativa paga** (se geolocator não for suficiente): `flutter_background_geolocation` (~$300 licença única) — mais robusto em iOS, melhor handling de sleep do SO. Usar só se tiver problemas com a versão grátis em produção.

### Armadilhas e mitigações

| Problema | Causa | Solução |
|---------|-------|---------|
| GPS "pula" em área urbana | Reflexo de sinal entre prédios | GPS Jump Detection: `accuracy > 15m → ignora ponto` |
| Pace oscila muito | GPS registra micro-variações | Speed Smoothing: média móvel dos últimos 3 pontos |
| App morto em background (iOS) | iOS mata processos agressivamente | `UIBackgroundModes: location` no Info.plist + permissão "Always" |
| Bateria drena rápido | GPS polling a cada 100ms | Adaptive polling: 1s em movimento lento, 3s em pace estável |
| Dados perdidos se internet cair | Sync falhou durante a corrida | Local-first com Hive — sync só acontece pós-corrida |

### Mapas — custo zero no MVP

Para exibir a rota pós-corrida, **não usar Google Maps** no início:

- **`flutter_map` + OpenStreetMap** — tiles gratuitos, sem chave de API, sem billing. Ideal para mostrar a rota da corrida.
- **Google Maps SDK** — necessário apenas se quiser mapas premium ou Places API. Free tier: 28K loads/mês (~R$ 0 para MVP). Usar se já estiver no ecossistema Google.

**Decisão MVP:** `flutter_map` + OSM para display de rota. Adicionar Google Maps só quando as features de Places (sugestões pós-corrida) forem implementadas.

---

## 6. Integração com Wearables

### Estratégia em camadas

```
Camada 1 (MVP obrigatório): Health Connect (Android) + HealthKit (iOS)
       └── plugin `health` (pub.dev) — cobre ambos com 1 API
       └── Dados: BPM, passos, sono, calorias, SpO2

Camada 2 (pós-MVP): BLE direto para wearables populares
       └── `flutter_blue_plus` — conexão Bluetooth Low Energy direta
       └── Polar SDK — Polar H10/OH1 (melhor monitor cardíaco para corrida)

Camada 3 (futuro): Integrações de plataforma
       └── Garmin Connect IQ (via Health Connect no Android)
       └── Apple Watch (HealthKit nativo)
       └── Samsung Galaxy Watch (via Health Connect)
```

### Pacotes Flutter por camada

| Pacote | Plataforma | Dados | Notas |
|--------|-----------|-------|-------|
| [`health`](https://pub.dev/packages/health) | Android (Health Connect) + iOS (HealthKit) | BPM, sono, passos, SpO2, peso | Pacote principal — cobre 95% dos casos. ⚠️ Google Fit descontinuado em 2026, Health Connect é obrigatório |
| [`flutter_blue_plus`](https://pub.dev/packages/flutter_blue_plus) | Android + iOS (BLE) | Qualquer dado via Bluetooth | Para wearables sem Health Connect |
| [`polar_ble_sdk`](https://pub.dev/packages/polar) | Android + iOS | BPM, ECG, aceleração | Polar H10 é o padrão ouro para BPM em corrida |
| [`wear_plus`](https://pub.dev/packages/wear_plus) | Wear OS | Companion app no relógio | Para eventual app no smartwatch |

### Configurações obrigatórias

**Android:**
```xml
<!-- AndroidManifest.xml — FlutterFragmentActivity obrigatória -->
<!-- (FlutterActivity quebra Health Connect) -->
<activity android:name=".MainActivity"
  android:launchMode="singleTop"
  android:theme="@style/LaunchTheme"
  android:configChanges="...">
```

```gradle
// build.gradle — Health Connect requer minSdk 26+
minSdkVersion 26
```

**iOS (Info.plist):**
```xml
<key>NSHealthShareUsageDescription</key>
<string>O Coach precisa dos seus dados de saúde para personalizar o treino.</string>
<key>NSHealthUpdateUsageDescription</key>
<string>Para registrar suas corridas no Health.</string>
```

### Limitações conhecidas

| Wearable | Integração | Limitação |
|---------|-----------|---------|
| **Apple Watch** | HealthKit via `health` | BPM com delay de ~5s via Bluetooth sync |
| **Garmin** | Health Connect (Android) | Sem SDK Flutter direto — dados via Health Connect após sync com app Garmin |
| **Polar H10** | BLE direto via `polar_ble_sdk` | Melhor opção para BPM real-time em corrida |
| **Samsung Galaxy Watch** | Health Connect | Delay similar ao Apple Watch |
| **Fitbit** | Sem Health Connect nativo ainda | API REST do Fitbit (OAuth2) — implementação manual |

### Priorização de desenvolvimento

```
P0 (MVP):
  plugin health → Health Connect (Android) + HealthKit (iOS)
  → BPM, sono, passos disponíveis no Coach sem esforço extra

P1 (pós-MVP):
  Polar BLE direto → BPM real-time durante corrida sem delay
  → Diferencial para usuários com monitor cardíaco externo

P2 (futuro):
  Wear OS companion app → Coach fala direto no pulso
  Apple Watch app → via WatchKit (separado do Flutter app)
```

---

## 7. Stack Consolidada — Tabela Final

| Camada | Componente | Solução | Alternativa | Custo MVP |
|--------|-----------|---------|-------------|-----------|
| **Mobile** | Framework | Flutter (Dart) | — | $0 |
| **Mobile** | State | Riverpod 2.x | BLoC | $0 |
| **Mobile** | GPS | `geolocator` + `flutter_background_service` | `flutter_background_geolocation` (~$300) | $0 |
| **Mobile** | Mapas | `flutter_map` + OpenStreetMap | Google Maps SDK | $0 |
| **Mobile** | Local storage | `hive_flutter` | SQLite (drift) | $0 |
| **Mobile** | Wearables | plugin `health` (Health Connect + HealthKit) | `polar_ble_sdk` (BLE direto) | $0 |
| **Mobile** | Audio duck | `audio_session` | — | $0 |
| **Mobile** | Compartilhar | `share_plus` | `appinio_social_share` | $0 |
| **Mobile** | Animações | `flutter_animate` | — | $0 |
| **Mobile** | Gamificação | custom (Cloud Functions) | `teqani_rewards` | $0 |
| | | | | |
| **Backend** | BaaS | Firebase (Firestore + Auth + Functions + FCM) | Supabase (>50K users) | Free tier |
| **Backend** | Auth | Firebase Phone Auth + Google Sign-In | — | ~R$ 0–360/mês |
| **Backend** | Functions | Cloud Functions Gen2 (Node.js 20) | Cloud Run / Fly.io | ~R$ 0–90/mês |
| **Backend** | Push | Firebase Cloud Messaging | — | $0 |
| **Backend** | Monitoring | Firebase Crashlytics + Performance | — | $0 |
| **Backend** | Config | Firebase Remote Config | — | $0 |
| | | | | |
| **IA — LLM rápido** | Coaching real-time | Qwen3-32B via Groq | Qwen3-8B (mais barato) | ~R$ 50–300/mês |
| **IA — LLM grande** | Plano + relatório | DeepSeek V3.2 via Together AI | Gemini 2.5 Flash-Lite | ~R$ 90–180/mês |
| **IA — LLM fallback** | Protótipo / backup | Gemini 2.5 Flash-Lite | — | Free tier |
| **IA — TTS** | Voz do Coach | Google Cloud TTS Neural2 | Azure Neural TTS | ~R$ 2.880/mês (1K users) |
| **IA — STT** | Voz do corredor | STT nativo (iOS/Android) | — | $0 |

---

## 8. Princípios Arquiteturais Inegociáveis

| Princípio | O que significa |
|-----------|----------------|
| **Repository Pattern** | Código nunca chama Firestore/LLM/TTS diretamente — sempre via interface. Troca de provider = troca de implementação, não reescrita |
| **Local-first** | GPS trail salvo em Hive durante a corrida. Sync pós-corrida. Internet caindo = zero perda de dados |
| **Streaming TTS** | LLM gera tokens em stream → TTS sintetiza em paralelo. Não espera resposta completa para começar a falar |
| **Dual LLM** | Modelo rápido (Groq, sub-segundo) durante corrida + modelo grande (Together AI) para análise assíncrona |
| **Providers americanos** | Qwen e DeepSeek sempre via Groq/Together/Fireworks — dados de saúde nunca passam por servidores chineses |
| **Cache TTS** | Frases comuns pré-geradas ("primeiro quilômetro", "pace acima do plano") — gera 1x, reutiliza. Reduz custo em ~25% |
| **Budget Alerts** | Firebase Budget Alerts configurados no dia 1. TTS é o vilão da conta — monitorar semanalmente |
| **Abstração de IA** | LLM e TTS acessados via interface com config (model, provider). Trocar modelo = mudar config, não código |

---

## 9. Custo Operacional por Fase

### Fase 1 — Protótipo (0–100 users)

| Item | Custo |
|------|-------|
| Firebase (free tier) | R$ 0 |
| Gemini 2.5 Flash-Lite (LLM) | R$ 0 (free tier) |
| Google Neural2 TTS (1M chars/mês grátis) | R$ 0 |
| GPS / Maps / Wearables | R$ 0 |
| **TOTAL** | **R$ 0/mês** |

### Fase 2 — MVP (1.000 users Premium a R$ 14,90)

| Item | Custo/mês | % da receita |
|------|-----------|-------------|
| LLM (Qwen + DeepSeek) | ~R$ 170 | 1,1% |
| TTS (Google Neural2) | ~R$ 2.880 | 19,3% |
| Firebase (Auth SMS + Firestore + Functions) | ~R$ 500 | 3,4% |
| **TOTAL tech** | **~R$ 3.550** | **23,8%** |
| **Margem bruta** | **~R$ 11.350** | **76,2%** |

**Maior alavanca de redução de custo:** TTS representa 81% do custo tech. Cache de frases comuns (-25%) + frases mais curtas (100→60 chars, -40%) podem reduzir o TTS para ~R$ 1.300/mês.

### Escala — a margem se mantém

| Usuários | Receita | Custo tech | Margem |
|---------|---------|-----------|--------|
| 1K | R$ 14.900 | R$ 3.550 | 76% |
| 10K | R$ 149.000 | R$ 35.000 | 77% |
| 50K | R$ 745.000 | R$ 175.000 | 77% |

Todos os custos escalam linearmente com usuários — margem estável. Ponto de atenção em 50K: avaliar TTS self-hosted (Fish Speech / F5-TTS) e migração Firestore → Supabase.

---

## 10. Roadmap Técnico

```
FASE 1 — PROTÓTIPO (0–100 users)
├── Flutter + Firebase free tiers
├── Gemini Flash-Lite (LLM) + Google Neural2 (TTS) — free
├── GPS tracking básico (geolocator + flutter_map + OSM)
├── Health Connect / HealthKit (plugin health)
└── Objetivo: demo funcional para pitch a operadora

FASE 2 — MVP (100–1K users)
├── LLM dual: Qwen3-32B via Groq (real-time) + DeepSeek via Together (análise)
├── Firebase Blaze (pay-as-you-go) com Budget Alerts
├── Cache TTS + frases curtas implementados
├── Polar BLE para BPM real-time (P1)
├── Multi-tenant (1ª operadora DCB)
└── Objetivo: app completo, primeira operadora ao vivo

FASE 3 — ESCALA (1K–50K users)
├── Otimizar queries Firestore (índices compostos, batch reads)
├── flutter_map → Google Maps se Places API for necessária
├── Wear OS companion app (se demanda)
├── Avaliar Fly.io para proxy LLM com cache
└── Objetivo: múltiplas operadoras, margem > 70%

FASE 4 — MATURIDADE (50K+ users)
├── Avaliar Fish Speech / F5-TTS self-hosted (TTS = R$ 144K/mês)
├── Avaliar Supabase para queries analíticas complexas
├── CDN de áudio para cache global de TTS
└── Objetivo: otimizar margem, expansão internacional
```

---

*Última atualização: abril 2026 — baseado em think tank técnico completo + protótipo Figma Make*
