# Momentos em que o Coach.AI é acionado

> Mapeamento feito a partir do código-fonte (branch `main`, 2026-05-19).
> Arquivo de referência para engenharia e produto.

---

## Visão geral

O Coach.AI atua em **três camadas** distintas:

| Camada | Tecnologia | Exemplos de trigger |
|---|---|---|
| **Tempo real** (durante a corrida) | SSE streaming via `POST /coach/message` | km_reached, pace_alert, motivação |
| **Síncrono pontual** | Gemini Live (WebSocket + áudio) | Saudação inicial, síntese de voz de cues |
| **Assíncrono / sob demanda** | `GET /coach/report`, `POST /plans/generate`, `POST /plan-revision` | Relatório pós-corrida, geração de plano, revisão |

---

## 1. Onboarding — Geração do Plano

**Onde:** `PlanLoadingPage` (`/plan-loading`)  
**Arquivo:** `app/lib/features/run/presentation/pages/plan_loading_page.dart`  
**Endpoint:** `POST /plans/generate`

- Disparado logo após o usuário concluir o onboarding.
- O Coach AI (LLM grande no servidor) analisa perfil, objetivo, nível e frequência semanal para gerar o plano de treino completo (meses, semanas, sessões, segments, paces alvo).
- A geração é assíncrona (~60-90 s); o app redireciona para `/home` após 15 s e a tela `/training` faz polling até `status='ready'`.

---

## 2. Coach Intro (Briefing Inicial)

**Onde:** `CoachIntroPage` (`/coach-intro`)  
**Arquivo:** `app/lib/features/coach_intro/presentation/pages/coach_intro_page.dart`

- Exibido apenas uma vez, após a geração do plano e antes da primeira corrida.
- **Não** aciona o LLM em tempo real — é conteúdo estático que explica ao usuário o que o coach faz.
- Marca `coachIntroSeen = true` via `PATCH /users/me` ao concluir ou pular.

---

## 3. Durante a Corrida — Saudação Inicial

**Onde:** `RunBloc._speakStartGreeting()` — disparado em `StartRun`  
**Arquivo:** `app/lib/features/run/presentation/bloc/run_bloc.dart`  
**Tecnologia:** Gemini Live (client → Google direto via ephemeral token)

- Acionado imediatamente quando o usuário pressiona **INICIAR**.
- O app busca em paralelo o perfil do usuário e o plano vigente.
- Monta um texto personalizado: nome do corredor + tipo de corrida + sessão planejada para hoje (pace alvo, distância) — ou reconhece que o usuário optou por Free Run mesmo tendo sessão planejada.
- Sintetiza em áudio WAV via `LiveCoachVoiceService` usando a voz configurada pelo usuário.
- Exemplo de saudação: *"Bora, Eduardo! Hoje é tempo run de 8km, pace alvo 5:30/km. Vou te acompanhar do início ao fim."*

---

## 4. Durante a Corrida — Cues Automáticos (SSE Streaming)

**Onde:** `RunBloc._requestCoachCue()` → `RunCoachRemoteDatasource.streamCoachCue()`  
**Arquivo:** `app/lib/features/run/presentation/bloc/run_bloc.dart`  
**Endpoint:** `POST /coach/message` (SSE, `text/event-stream`)

Cada cue abaixo só dispara se **não há outro cue em andamento** (`_coachRequestInFlight`). O servidor pode retornar 204 (sem conteúdo) para silenciar o cue com base em preferências de frequência (DND, frequency=silent, etc.).

Após receber o texto do servidor, o app sintetiza áudio via Gemini Live e toca ao usuário.

### 4.1 `km_reached` — Ao cruzar cada quilômetro

- Dispara **uma vez por km** cruzado (sem cooldown além do dedup por km).
- Informa ao usuário o km concluído, tempo do km, pace estimado.
- Condicional: `alertPrefs['kmAlert'] == true` (padrão: **ligado**).
- Passa `kmDurationS` (duração do km em segundos) e `kmAvgBpm` (quando disponível via wearable).

### 4.2 `km_analysis` — ~10 s após cada km

- Disparado 10 segundos depois de cada `km_reached` (Timer de um disparo, cancelável).
- Análise técnica dos últimos 5 splits: compara pace real vs alvo do plano e sugere ação ("acelera", "mantém", "recupera").
- O servidor recebe o array `recentSplits` com os dados de km fechados.
- Condicional: `alertPrefs['kmAlert'] == true` (padrão: **ligado**).

### 4.3 `km_split` — Delta de pace entre kms (do 2º km em diante)

- Dispara ao cruzar km quando `kmSplits == true` e há pace do km anterior.
- Comenta a variação de pace entre o km atual e o anterior.
- Condicional: `alertPrefs['kmSplits'] == true` (padrão: **desligado** para reduzir ruído).

### 4.4 `segment_start` — Início de novo segmento do plano

- Só dispara em corridas vinculadas a uma `PlanSession` com `executionSegments` definidos.
- Quando o GPS cruza o `kmStart` de um novo segment (warmup → main → cooldown, etc.), o coach anuncia a nova fase e o pace alvo.
- Não tem cooldown (dispara uma vez por transição).

### 4.5 `segment_end` — Fim do último segmento

- Dispara quando o GPS ultrapassa o `kmEnd` do último segment da sessão planejada.
- Indica ao usuário que todos os segmentos foram completados.
- Dispara no máximo uma vez por corrida.

### 4.6 `segment_pace_off` — Pace fora do alvo no segment ativo

- Dispara quando o pace suavizado desvia ≥ 10% do `targetPace` do segment ativo.
- Cooldown: **60 s** entre cues do mesmo tipo.
- Condicional: `alertPrefs['paceOutOfRange'] == true` (padrão: **ligado**).
- Substitui o `pace_alert` legado quando há segment com targetPace definido.

### 4.7 `pace_alert` — Pace fora do alvo (Free Run / sem segment com alvo)

- Dispara quando o pace suavizado desvia ≥ 10% do pace alvo escolhido pelo usuário no prep.
- Só ativo quando **não** há segment com targetPace definido (Free Run ou segments de warmup/cooldown sem alvo).
- Cooldown: **60 s**.
- Condicional: `alertPrefs['paceOutOfRange'] == true` (padrão: **ligado**).

### 4.8 `motivation` — Motivação periódica

- Timer tick a cada **60 s**; verifica se nenhum outro cue rolou nos últimos:
  - **5 min** — modo nativo / web em movimento.
  - **3 min** — modo web estacionário (desktop sem GPS real).
- Se passou o tempo sem nenhum cue, dispara uma mensagem motivacional.
- Condicional: `alertPrefs['motivation'] == true` (padrão: **ligado**).

### 4.9 `no_movement` — Sem movimento 30 s após início

- Timer one-shot, disparado 30 s após `StartRun`.
- Condição: `distanceM < 5 m` **e** há pelo menos um fix GPS.
- Coach envia um disclaimer gentil ("tudo bem? começa quando puder").
- Dispara no máximo uma vez por corrida (não repete no resume).

### 4.10 `finish` — Ao concluir a corrida

- Disparado quando o usuário pressiona **ENCERRAR** (`CompleteRun`).
- Condicional: `distanceM >= 10 m` (evita cue em corridas fantasmas).
- Coach faz um comentário final sobre a corrida antes de ir para o relatório.

---

## 5. Relatório Pós-Corrida

**Onde:** `ReportPage` (`/report`)  
**Arquivo:** `app/lib/features/run/presentation/pages/report_page.dart`  
**Endpoint:** `GET /coach/report/:runId` (polling a cada 3 s)

- O servidor gera o relatório assincronamente após `PATCH /runs/:id/complete`.
- **Two-phase delivery:**
  - **Fase A** (`status='summary_ready'`, ~30 s): resumo curto da corrida.
  - **Fase B** (`status='enriched'`, ~60–150 s): análise completa com seções (headings `## `), comparação com plano, sugestões de adaptação.
- O app faz polling por até **150 s** (50 tentativas × 3 s).
- A UI exibe o texto de Fase A com hint "Análise completa em segundos..." enquanto aguarda Fase B.

---

## 6. Detalhe de Corrida — Histórico

**Onde:** `RunDetailPage` (`/history/run/:runId`)  
**Arquivo:** `app/lib/features/history/presentation/pages/run_detail_page.dart`  
**Endpoint:** `GET /coach/report/:runId`

- Ao abrir o detalhe de uma corrida passada, o relatório do coach é carregado (se status='ready').
- Exibe o summary armazenado no Firestore (geração já ocorreu no momento da corrida).
- O usuário também pode acessar **"VER CONVERSA COM COACH"** → `CoachConversationReplayPage` com o histórico de todos os cues da sessão.

---

## 7. Análise de Período

**Onde:** `CoachPeriodBloc` (carregado em telas de histórico/dashboard)  
**Arquivo:** `app/lib/features/coach/application/bloc/coach_period_bloc.dart`  
**Endpoint:** `GET /coach/period-analysis?start_date=&end_date=`

- Acionado quando o usuário seleciona um intervalo de datas no histórico/dashboard.
- O coach analisa as corridas do período e retorna um `summary` consolidado.

---

## 8. Checkpoint Semanal

**Onde:** `CheckpointPage` (`/training/checkpoint/:planId/:weekNumber`)  
**Arquivo:** `app/lib/features/training/presentation/pages/checkpoint_page.dart`

- Disponível **uma vez por semana** (servidor retorna 409 se já foi aplicado).
- O usuário marca chips de percepção subjetiva (dor, cansaço, bem, etc.) e clica **APLICAR AJUSTE**.
- O coach lê todos os dados da semana (corridas, pace, BPM, aderência) + os inputs do usuário e **recalcula as semanas seguintes** do plano.
- Retorna `coachExplanation` com o racional do ajuste aplicado.
- Exige plano **premium** (servidor retorna 403 com `PREMIUM_REQUIRED` caso contrário).

---

## 9. Revisão de Plano (sob demanda)

**Onde:** `RevisionFlowPage` (`/training/revise?planId=`)  
**Arquivo:** `app/lib/features/training/presentation/pages/revision_flow_page.dart`

- O usuário escolhe o tipo de mudança desejada (mais carga, menos dias, mais intervalados, etc.) e uma sub-opção.
- O coach aplica a revisão e retorna `coachExplanation`.
- Quota: **1 revisão por semana** (servidor retorna 429 ao exceder).

---

## 10. Coach Live — Conversa em Tempo Real

**Onde:** `CoachLivePage` (`/coach-live?runId=`)  
**Arquivo:** `app/lib/features/coach_live/presentation/pages/coach_live_page.dart`  
**Tecnologia:** WebSocket (`/v1/coach/live?token=&runId=`)

- Sessão bidirecional via WebSocket + Gemini Live.
- Suporta texto e áudio (PCM 16 kHz mic → coach; PCM 24 kHz speaker → usuário).
- Pode ser aberta **durante ou fora de uma corrida** (parâmetro `runId` opcional).
- Fluxo:
  1. App abre WS, aguarda `{ kind: 'ready' }`.
  2. Usuário envia `{ type: 'text', text }` ou chunks de áudio `{ type: 'audio', mimeType, data }`.
  3. Coach responde em stream (`{ kind: 'content', serverContent: { modelTurn: { parts } } }`).
  4. `turnComplete=true` → coach encerrou o turno.

---

## Diagrama de fluxo resumido

```
ONBOARDING
  └─► POST /plans/generate  →  Coach gera plano completo (LLM grande, assíncrono)

PRIMEIRA CORRIDA
  └─► /coach-intro          →  Briefing estático (sem LLM)

INICIAR corrida
  └─► _speakStartGreeting() →  Gemini Live: saudação personalizada (áudio)

DURANTE corrida (GPS loop)
  ├─► km_reached            →  A cada km cruzado (alertPrefs.kmAlert)
  ├─► km_analysis           →  10 s após km_reached (alertPrefs.kmAlert)
  ├─► km_split              →  Do 2º km em diante (alertPrefs.kmSplits)
  ├─► segment_start         →  Ao entrar em novo segment do plano
  ├─► segment_end           →  Ao passar o último segment
  ├─► segment_pace_off      →  Desvio ≥10% no segment ativo (cooldown 60s)
  ├─► pace_alert            →  Desvio ≥10% em Free Run (cooldown 60s)
  ├─► motivation            →  A cada 5 min sem cue (alertPrefs.motivation)
  └─► no_movement           →  30s sem mover (one-shot)

ENCERRAR corrida
  ├─► finish                →  Cue de encerramento
  └─► GET /coach/report     →  Relatório two-phase (polling 3s, até 150s)

HISTÓRICO
  ├─► GET /coach/report     →  Exibe relatório salvo
  └─► GET /coach/messages   →  Replay da conversa da corrida

TREINO
  ├─► GET /coach/period-analysis  →  Análise de intervalo de datas
  ├─► CheckpointPage (APLICAR)     →  Reprocessa plano com dados da semana (1x/sem)
  └─► RevisionFlowPage (CONFIRMAR) →  Revisão sob demanda (1x/sem)

COACH LIVE
  └─► WS /coach/live        →  Conversa bidirecional texto + áudio (qualquer momento)
```

---

## Preferências do usuário que controlam os cues

Armazenadas no perfil (`preRunAlerts`) e carregadas no início de cada corrida:

| Preferência | Padrão | Controla |
|---|---|---|
| `kmAlert` | **ligado** | `km_reached` + `km_analysis` |
| `paceOutOfRange` | **ligado** | `pace_alert` + `segment_pace_off` |
| `highBpm` | **ligado** | `high_bpm` (pendente de stream de wearable) |
| `kmSplits` | **desligado** | `km_split` |
| `motivation` | **ligado** | `motivation` periódico |

A voz do coach (Gemini Live) é configurada em `coachVoiceId` no perfil do usuário (default: `Charon`).
