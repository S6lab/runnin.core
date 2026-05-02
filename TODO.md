# TODO

## Concluído ✅

- [x] Criar estrutura do projeto Flutter + Node.js
- [x] Backend Node.js + TypeScript no Cloud Run (`runrun-api`) — **online e respondendo**
- [x] Clean Architecture no server: modules/runs, modules/coach, shared/infra
- [x] Firebase Admin inicializado no server (ADC)
- [x] Providers de LLM desacoplados por interface
- [x] Gemini definido como provider padrão configurável por env var
- [x] Groq e Together mantidos como opções futuras
- [x] Firestore run repository com GPS subcollection + batch write
- [x] Coach use-case com system prompt PT-BR
- [x] Dockerfile multi-stage com tsc-alias
- [x] `flutterfire configure` → `firebase_options.dart` gerado para Android + iOS + **Web** ✅
- [x] Descomentar import firebase_options.dart no main.dart
- [x] Build APK debug sem erros (`app-debug.apk`)
- [x] Fix bug timer: `_TimerTick` separado de `_GpsUpdate` (elapsed não dobrava mais)
- [x] Fix PrepPage: tipo de corrida selecionado agora é passado corretamente ao `StartRun`
- [x] Login anônimo no Firebase habilitado
- [x] Backend redeployado no Cloud Run e saudável em `/health`
- [x] Tela `Conta` com logout
- [x] Edição de perfil movida para tela dedicada
- [x] Onboarding persistido localmente; não reaparece sozinho após concluído

---

## Pendente — PRIORITÁRIO

- [ ] **Ativar Google Sign-In no Firebase Console**
  - console.firebase.google.com → runnin-494520 → Authentication → Sign-in method → Google → Ativar

- [ ] **Preencher API keys/config dos providers no Cloud Run:**
  ```
  gcloud run services update runrun-api --region southamerica-east1 \
    --set-env-vars "LLM_REALTIME_PROVIDER=gemini,LLM_ASYNC_PROVIDER=gemini,GEMINI_API_KEY=xxx"
  ```
  - `GEMINI_API_KEY` — ai.google.dev
  - `GROQ_API_KEY` — opcional, se quiser usar Groq depois
  - `TOGETHER_API_KEY` — opcional, se quiser usar Together depois

- [ ] **Validar em produção o fluxo real**
  - login → onboarding → `POST /v1/users/onboarding` → plano gerado → `GET /v1/plans/current`

---

## Pendente — Device / Teste

- [ ] Rodar no Chrome para checar design:
  ```
  flutter run -d chrome --web-port 8080
  ```

- [ ] Conectar device físico Android (USB debugging) ou criar emulador:
  ```
  flutter emulators --create --name pixel9
  flutter run
  ```

- [ ] Instalar APK no device físico:
  ```
  adb install build/app/outputs/flutter-apk/app-debug.apk
  ```

---

## Pendente — Próximas features (pós-MVP)

- [ ] Tela History: listar corridas passadas (buscar da API `/runs`)
- [ ] Tela Training: plano semanal real (integrar com coach backend)
- [ ] Coach voice (TTS): Google Cloud TTS Neural2 — avaliar custo antes de ativar
- [ ] Wearables: integrar plugin `health` (Health Connect / HealthKit)
- [ ] RevenueCat: paywall + IAP R$ 14,90/mês
- [ ] ASO: título, descrição, screenshots para Play Store

---

## Pendente — Paridade com o protótipo

- [ ] Migrar o app para usar design tokens compartilhados em todas as telas
- [ ] Extrair componentes-base do design system (`MetricCard`, `CoachNarrativeCard`, `SegmentedTabs`, `PaletteCard`, `WeekGrid`)
- [ ] Implementar seleção e persistência completa de skin em todas as telas críticas
- [ ] Onboarding completo: slides, OTP, saúde, rotina, wearable, geração de plano
- [ ] Home completa: notificações acionáveis, status corporal, última corrida, coach semanal
- [ ] Training completo: plano semanal, mensal, relatórios e revisões
- [ ] Run completo: sessão do plano vs free run, alertas, música, mapa, pausa/finalização
- [ ] Relatório pós-corrida completo: splits, zonas, benchmark, conquistas e share card
- [ ] History completo: filtros por período, trends, zonas cardíacas e benchmark agregado
- [ ] Gamificação completa: badges, XP, streak, progresso e regras de desbloqueio
- [ ] Perfil/ajustes completos: saúde, ajustes do coach, notificações, exportação e privacidade

---

## Pendente — Backend / Clean Architecture / IaC

- [ ] Criar módulos backend ausentes: `plan_reviews`, `history`, `notifications`, `health`, `exams`, `gamification`
- [ ] Estruturar contratos e repositórios por módulo com adapters explícitos
- [ ] Introduzir fila/eventos para geração assíncrona de plano, relatório e notificações
- [ ] Definir coleções Firestore para `plans`, `weekly_reports`, `badge_progress`, `user_preferences`, `health_profile`, `exam_files`
- [ ] Criar base de Terraform para GCP (`Cloud Run`, `Firestore`, `Storage`, `Secret Manager`, `Scheduler`, `Pub/Sub`, `Monitoring`)
- [ ] Configurar ambientes `dev`, `staging` e `prod`
- [ ] Instrumentar observabilidade por módulo e provider IA

---

## Pendente — Humano / Externo

- [ ] Validar escopo oficial de wearables suportados no lançamento
- [ ] Testar Health Connect / HealthKit com devices reais
- [ ] Definir política legal para upload e retenção de exames médicos
- [ ] Escolher fornecedor final de TTS/STT e aprovar custos
- [ ] Validar ducking de áudio e integrações reais com apps de música
- [ ] Definir metodologia real de benchmark/percentil com massa de dados suficiente
- [ ] Definir branding multi-tenant / white-label se o app for operado por parceiros
- [ ] Avaliar se login com telefone realmente entra no escopo do MVP
