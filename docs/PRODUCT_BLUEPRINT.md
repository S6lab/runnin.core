# Blueprint do Produto

> Consolidação dos prints em `references/`, `think-tank-runcoach-ai.md`, `ROADMAP.md` e `TODO.md`.

## 1. Conclusão do confronto

O protótipo é substancialmente maior do que o roadmap atual. O roadmap cobre o núcleo do MVP técnico, mas não contempla boa parte da superfície funcional já validada pelos prints:

- design system com múltiplas skins;
- onboarding profundo de saúde e rotina;
- periodização semanal e mensal;
- revisões semanais do plano;
- notificações inteligentes fora da corrida;
- gamificação completa;
- analytics históricos mais ricos;
- ajustes avançados do Coach;
- saúde, wearable e exames.

Em outras palavras: o `ROADMAP.md` está correto no que afirma, mas está incompleto frente ao protótipo e ao `think-tank`.

## 2. Mapa funcional consolidado

### Onboarding e identidade

- Splash/brand.
- Slides de valor do produto.
- Login com telefone/OTP.
- Google Sign-In.
- Coleta de nome e data de nascimento.
- Nível atual do corredor.
- Peso e altura.
- Condições de saúde e medicações.
- Frequência semanal.
- Meta principal.
- Pace alvo opcional.
- Rotina de sono e horário preferido.
- Conectar wearable agora ou depois.
- Geração do plano pela IA.

### Home e sessão do dia

- Saudação contextual.
- Sessão do dia com tipo, distância, pace e duração estimada.
- Briefing textual do Coach.
- Inbox de notificações acionáveis:
  - melhor horário;
  - preparo nutricional;
  - hidratação;
  - checklist pré-run;
  - sono/recovery.
- Visão semanal resumida.
- Performance cards.
- Status corporal.
- Última corrida com CTA de detalhes/compartilhar.
- Coach semanal/resumo.

### Treino

- Plano semanal.
- Periodização mensal por mesociclo.
- Relatórios semanais.
- Histórico de ajustes/revisões.
- Regra de uma revisão por semana.
- Briefing do treino com zonas alvo.
- Nutrição e mobilidade pré-corrida.

### Corrida

- Escolha entre sessão do plano e free run.
- Configuração de alertas.
- Integração com música.
- Corrida ativa com timer, pace, dist, bpm, kcal e splits.
- Mapa/rota.
- Pausar/finalizar.
- Coach em tempo real por voz e eventos.

### Pós-corrida

- Resumo imediato.
- Relatório detalhado.
- Splits.
- Zonas cardíacas.
- Benchmark.
- Conquistas/xp.
- Compartilhamento.

### Histórico e analytics

- Filtros por aba: dados, corridas, benchmark.
- Filtros de período: semana, mês, 3 meses.
- Totais consolidados.
- Zonas cardíacas agregadas.
- Volume semanal.
- Tendência de pace.
- Tendência de BPM.
- Resumo evolutivo com análise do coach.

### Perfil, saúde e ajustes

- Resumo do usuário.
- Streak, XP, badges, corrida total.
- Condições de saúde.
- Skin/theme switcher.
- Editar perfil.
- Menu para gamificação, saúde e ajustes.
- Ajustes de voz/persona do Coach.
- Frequência de fala, idioma, autoajuste de plano.
- Alertas de corrida default.
- Notificações fora da corrida.
- Unidades, vibração, integração musical, exportação, privacidade.
- Preview das notificações.
- Entrada de exames médicos.

### Gamificação

- Galeria de badges.
- Regras de XP.
- Calendário de streak.
- Progresso de badges bloqueados e desbloqueados.

## 3. Confronto com o roadmap atual

### Já aparecem no roadmap

- Auth.
- Onboarding básico.
- Home.
- Runs.
- Coach.
- Training.
- History.
- Profile.
- Gamification em nível inicial.
- LLM dual e TTS no backend.

### Estão no protótipo, mas não estão materializados no roadmap

- Sistema de skins/temas.
- Login por OTP.
- Saúde detalhada e medicações.
- Janela metabólica e rotina de sono.
- Notificações inteligentes fora da corrida.
- Ajustes avançados do coach.
- Revisões semanais do plano.
- Exportação de dados.
- Privacidade e permissões.
- Upload de exames.
- Música com ducking explícito.
- Benchmark mais profundo.
- Biblioteca de badges e calendário de streak.

## 4. Confronto com o TODO atual

O `TODO.md` também está subdimensionado. Ele reflete mais a execução técnica do bootstrap do MVP do que o escopo real do produto. Estavam faltando:

- macrofases por módulo do protótipo;
- dependências humanas/externas;
- gaps de compliance/loja/permissões;
- trilha de implementação para wearable, exames, música e notificações.

Isso foi corrigido no `TODO.md`.

## 5. Planejamento por módulo

### 5.1 Design system e app shell

- Front: tokens, componentes-base, skin switcher, tipografia, charts, cards, segmented tabs.
- Back: não depende.
- Infra: não depende.
- Stack: Flutter, ThemeExtension, Hive para persistir skin, componentes compartilhados.

### 5.2 Auth e onboarding

- Front: splash, onboarding slides, login OTP/Google, wizard multi-step.
- Back: `users`, `onboarding`, geração inicial do plano.
- Infra: Firebase Auth, Firestore, Remote Config.
- Stack: Flutter + Firebase Auth + Firestore + Cloud Functions/Cloud Run.

### 5.3 Perfil, saúde e exames

- Front: perfil, editar dados, tags de saúde, wearable status, upload de exames.
- Back: `users`, `health_profile`, `exam_files`, validações de segurança.
- Infra: Firestore, Cloud Storage, signed URLs, regras de acesso.
- Stack: Flutter, Firestore, Storage, adapter para OCR/extração futura.
- Dependência humana: definição médica/jurídica do que pode ser coletado e exibido.

### 5.4 Training engine

- Front: plano semanal, mensal, relatórios, revisões.
- Back: `plans`, `plan_reviews`, `weekly_reports`, `sessions`, `plan_adjustments`.
- Infra: jobs assíncronos, filas/eventos, observabilidade.
- Stack: Node/TypeScript, Clean Architecture, strategy + adapter para motor de geração, Firestore.

### 5.5 Run execution

- Front: prep, alertas, música, run active, splits, mapa, report.
- Back: `runs`, `gps_points`, `run_reports`, eventos do coach.
- Infra: background processing, batching, retry/sync.
- Stack: Flutter + geolocator + background service + Hive + flutter_map; backend com Cloud Run.

### 5.6 Coach AI

- Front: coach cards, chat, voz, notificações inteligentes.
- Back: dual-LLM pipeline, TTS, report generation, notification composer.
- Infra: provider adapters, métricas de latência, secrets, budgets.
- Stack: Groq/Together via adapters, Cloud Run, FCM, optional TTS provider.

### 5.7 History e analytics

- Front: dashboards, trends, benchmarks.
- Back: agregações por período, percentis, séries temporais.
- Infra: jobs de agregação, cache leve.
- Stack: Firestore + collection de snapshots agregados + adapters para analytics engine.

### 5.8 Gamificação

- Front: badges, xp, streak, unlock cards.
- Back: rule engine, badge progress, streak service.
- Infra: triggers pós-corrida e pós-relatório.
- Stack: domain services + strategy/rule objects.

### 5.9 Ajustes e notificações

- Front: alertas de corrida, notificações, voz/persona, unidades, privacidade.
- Back: `user_preferences`, schedules, notification policies.
- Infra: FCM, cron/scheduler, permissões nativas.
- Stack: Firebase Messaging + Scheduler + Remote Config.

## 6. Arquitetura recomendada

### Flutter

- `core`: theme, router, di, analytics, permission, local storage, design system.
- `shared`: widgets, cards, chart widgets, layouts, entities utilitárias.
- `features`: `auth`, `onboarding`, `home`, `training`, `run`, `history`, `coach`, `profile`, `health`, `settings`, `gamification`.
- Padrões:
  - Clean Architecture;
  - repository;
  - adapter para APIs, wearable, tts, llm, export;
  - mapper entre DTO e entidade;
  - local-first para corrida.

### Backend

- `modules/users`
- `modules/onboarding`
- `modules/plans`
- `modules/plan-reviews`
- `modules/runs`
- `modules/coach`
- `modules/history`
- `modules/gamification`
- `modules/notifications`
- `modules/health`
- `modules/exams`
- `shared/infra`
- `shared/domain`

### Infra e IaC

- Terraform como padrão.
- GCP:
  - Cloud Run;
  - Firestore;
  - Cloud Storage;
  - Secret Manager;
  - Artifact Registry;
  - Cloud Scheduler;
  - Pub/Sub;
  - Cloud Logging / Monitoring;
  - Firebase Auth / FCM / Crashlytics / Analytics / Remote Config.
- Ambientes:
  - `dev`
  - `staging`
  - `prod`
- Segredos e configs versionados por ambiente.

## 7. Dependências externas com placeholder humano

- Wearables:
  - validar quais devices terão suporte oficial inicial;
  - testes reais com Health Connect/HealthKit;
  - eventual BLE direto em relógios/cintas.
- Música:
  - validar ducking por SO e apps suportados;
  - política de integração com Spotify/Apple Music/YT Music.
- Exames médicos:
  - definir retenção, criptografia, consentimento e linguagem legal;
  - decidir se haverá leitura automática ou upload puro.
- TTS/STT:
  - escolher fornecedor final e voz PT-BR;
  - validar custo/latência em produção.
- Benchmark:
  - definir fonte real dos percentis;
  - evitar comparação enganosa com pouca massa crítica.
- Comercial/white-label:
  - operadores, branding por tenant e revenue share.

## 8. Ordem de implementação

1. Design system + app shell + skin switcher.
2. Onboarding completo + perfil/saúde.
3. Engine de plano semanal/mensal.
4. Corrida ativa + report pós-run com dados reais.
5. Coach em tempo real e notificações.
6. Histórico analítico.
7. Gamificação completa.
8. Exames, wearable avançado e integrações externas.
