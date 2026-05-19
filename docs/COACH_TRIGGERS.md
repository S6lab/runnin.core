# Momentos em que o Coach é Acionado

> Mapeamento completo dos pontos do produto onde o Coach AI intervém — baseado na leitura do código `server/src/modules/coach/` e módulos dependentes.

---

## 1. Durante a Corrida (tempo real)

Endpoint: `POST /v1/coach/message`  
Use-case: `CoachMessageUseCase.generate()`  
Transporte: SSE (Server-Sent Events)  
Feature flag: `coachVoiceDuringRun`

O cliente Flutter envia um evento com contexto da corrida ativa (pace, distância, BPM, km percorrido) e recebe texto + áudio TTS em streaming. Os eventos reconhecidos e quando cada um dispara:

| Evento | Quando é enviado |
|--------|------------------|
| `start` | Corrida iniciada — saudação leve (sem LLM, só template com nome + tipo de corrida). |
| `km_reached` | Usuário cruzou mais um quilômetro inteiro. Coach comenta pace do km, calorias e BPM. |
| `km_split` | Variante de `km_reached` quando o app quer granularidade extra por split. |
| `pace_alert` | Pace desviou do alvo geral da sessão (sem segments definidos). |
| `motivation` | App decide enviar motivação em momento narrativo (ex.: metade da corrida). |
| `question` | Atleta fez pergunta por texto durante a corrida. |
| `segment_start` | Atleta cruzou a fronteira para o próximo segmento do `executionSegments` da `PlanSession`. |
| `segment_pace_off` | Pace deviou do alvo **deste** segmento (substitui `pace_alert` quando há plano com segmentos). |
| `segment_end` | Último ponto GPS dentro do segmento final. |
| `finish` | Corrida finalizada — sempre entregue, mesmo com `coachMessageFrequency: silent`. |
| `preview` | Pré-visualização de voz nas configurações do Coach (sem LLM, só TTS de texto fixo). |

### Regras de supressão (Decision Layer)

Antes de chamar o LLM, o servidor aplica um filtro baseado nas preferências do usuário:

- **`silent`** — bloqueia tudo, exceto `finish` e alertas críticos (`pace_alert`, `segment_pace_off`) se `allowCriticalAlertsInSilent = true` (default).
- **`alerts_only`** — bloqueia eventos narrativos (`km_reached`, `km_split`, `motivation`, `segment_start`, `segment_end`).
- **`per_2km`** — ignora `km_reached`/`km_split` em kms ímpares.
- **Janela DND (`dndWindow`)** — bloqueia qualquer evento que não seja crítico ou `finish`.

---

## 2. Corrida ao Vivo via WebSocket (Gemini Live)

Endpoint: `ws://api/v1/coach/live?token=<firebase-id-token>&runId=<opcional>`  
Arquivo: `coach-live.ws.ts`  
Feature flag: `coachVoiceDuringRun` (token efêmero via `POST /v1/coach/live-token`)

Proxy bidirecional entre o app Flutter e a API Gemini Live. O usuário fala por áudio (ou texto) e o Coach responde em áudio em tempo real, sem eventos pré-definidos. É acionado quando o atleta abre a sessão de voz ao vivo durante a corrida. A conversa é persistida por runId para replay no histórico.

---

## 3. Relatório Pós-Corrida (Two-Phase)

Gatilho: conclusão da corrida via `PATCH /v1/runs/:id/complete`  
Use-case: `GenerateReportUseCase.execute()`  
Feature flag: `weeklyReports`

Assim que o backend conclui a corrida, `triggerReportGeneration()` é chamado em background:

**Fase A (`summary_ready`, ~30 s):** LLM assíncrono gera um parágrafo de análise com pace, BPM, duração, plano e histórico recente. UI exibe imediatamente quando disponível.

**Fase B (`enriched`, +15 s após Fase A):** Segundo LLM call gera 4 seções estruturadas em JSON:
- `runAnalysis` — desempenho da corrida em detalhes.
- `planEvolution` — como a corrida se encaixa na progressão do plano.
- `nextSessions` — orientação para as próximas sessões.
- `recommendations` — dicas de recuperação, nutrição, ajustes.

A Fase B é fire-and-forget — falha não trava a Fase A.

---

## 4. Adaptação Automática do Plano Pós-Corrida

Gatilho: `patchComplete` (conclusão de corrida)  
Use-case: `AdaptPlanUseCase.executeAfterRun()`

Em paralelo ao relatório, o backend pede ao LLM que ajuste as próximas sessões da semana corrente com base nos dados reais da corrida (pace vs target, BPM, duração). Não consome cota manual de revisão do usuário (`bypassQuota: true`). A revisão é gravada em `plan.revisions[]` para auditoria.

---

## 5. Chat Assíncrono (Fora da Corrida)

Endpoint: `POST /v1/coach/chat`  
Use-case: `CoachChatUseCase.execute()`  
Feature flag: `coachChat`

O atleta envia uma mensagem de texto para o Coach fora da corrida (ex.: dúvidas sobre plano, saúde, nutrição). O Coach responde com contexto do perfil, plano atual e corridas recentes. Sem streaming — resposta única síncrona.

---

## 6. Relatório de Período / Histórico

Endpoint: `GET /v1/coach/period-analysis`  
Use-case: `GeneratePeriodAnalysisUseCase.execute()`  
Feature flag: `weeklyReports`

Acionado quando o atleta acessa a aba de histórico e solicita análise de um período de corridas. O LLM recebe métricas agregadas (total de km, BPM médio, pace médio, lista de corridas) e gera um resumo evolutivo com orientações.

---

## 7. Relatório Semanal do Plano

Endpoint: via `WeeklyReportController`  
Use-case: `GenerateWeeklyReportUseCase.execute()`

Acionado quando o atleta abre a tela de Treino e clica em ver o relatório de uma semana específica. O LLM recebe: sessões planejadas vs corridas realizadas, aderência, BPM médio, pace médio e contexto RAG. Gera análise de 150–200 palavras + 2–3 highlights. Idempotente — reutiliza o relatório existente se já estiver `ready`.

---

## 8. Revisão Manual do Plano pelo Atleta

Endpoint: `POST /v1/plans/:id/revisions`  
Use-case: `RequestRevisionUseCase.execute()`

O atleta solicita ajuste do plano pela tela de Treino (ex.: mais carga, menos dias, dor/desconforto). O LLM recebe o plano completo, perfil e o motivo da revisão, e devolve novas semanas + `coachExplanation`. Cota: 1 revisão manual por semana (reset toda segunda via Cloud Scheduler).

---

## 9. Revisão Automática Semanal (Cron)

Gatilho: Cloud Scheduler semanal  
Use-case: `AdaptPlanUseCase.executeWeeklyRevision()`

Toda semana o backend avalia aderência da semana encerrada (sessões planejadas vs executadas, km total) e pede ao LLM que ajuste as próximas semanas automaticamente. Regras:
- Aderência 0%: reduz volume ~20%, baixa intensidade.
- Aderência < 60%: reduz volume 10–15%, simplifica sessões.
- Aderência > 100%: aumenta progressão 5–10%.
- Caso normal: mantém progressão com ajustes finos.

Não consome cota manual. Snapshot gravado em `plan.revisions[]`.

---

## 10. Adaptação por Dia Perdido (Cron Diário)

Gatilho: Cloud Scheduler diário  
Use-case: `AdaptPlanUseCase.executeMissedDay()`

Se o atleta tinha sessão planejada ontem e não registrou nenhuma corrida, o LLM realoca a carga perdida nas próximas sessões da semana sem sobrecarregar. Bypass de cota.

---

## 11. Notificações Diárias de Insights

Gatilho: `POST /v1/notifications/ensure-daily` (Cloud Scheduler 06:00 BRT)  
Use-case: `EnsureDailyInsightsUseCase.execute()`

O Coach não chama o LLM neste momento — as 7 notificações são geradas com **lógica determinística** baseada no plano e perfil do usuário, sem inferência de IA. Cada notificação é idempotente por dia (`dedupeKey = YYYY-MM-DD`):

| Tipo | Conteúdo |
|------|----------|
| `melhor_horario` | Janela sugerida para a próxima sessão com base em `runPeriod` do perfil. |
| `preparo_nutricional` | Orientação pré-treino baseada no tipo de sessão do dia (long, tempo, interval, easy). |
| `hidratacao` | Meta de hidratação do dia calculada por peso (35ml/kg, cap 3.5L; ou valor do plano, cap 4L). |
| `checklist_pre_easy_run` | Checklist de aquecimento e mobilidade antes da corrida. |
| `sono_performance` | Status de dados de sono (necessita wearable). |
| `bpm_real` | Informa se há dados de BPM real registrados nas corridas. |
| `fechamento_mensal` | Destaca sinais de exames e histórico para calibrar zonas. |

---

## 12. Geração Inicial do Plano (Onboarding)

Endpoint: `POST /v1/users/onboarding` → `POST /v1/plans/generate`  
Use-case: `GeneratePlanUseCase.execute()`

Ao finalizar o onboarding, o LLM grande (async) gera o plano semanal/mensal completo com sessões, pace alvo, nutrição, hidratação e segmentos de execução. Este é o primeiro e mais longo call ao LLM — pode levar 30–60 s. O resultado é ouvido via Firestore em tempo real pelo app.

---

## Resumo por Contexto

| Contexto | Tipo de Coach | LLM? | Áudio? |
|----------|---------------|-------|--------|
| Corrida ativa (eventos) | Tempo real / SSE | Sim (realtime) | Sim (TTS cascata) |
| Corrida ao vivo (voice) | WebSocket bidirecional | Gemini Live | Sim (nativo) |
| Preview de voz (settings) | Sem LLM | Não | Sim (TTS) |
| Relatório pós-corrida | Background assíncrono | Sim (async) | Não |
| Adaptação pós-corrida | Background assíncrono | Sim (async) | Não |
| Chat fora da corrida | Síncrono | Sim (async) | Não |
| Análise de período | On-demand | Sim (async) | Não |
| Relatório semanal | On-demand | Sim (async) | Não |
| Revisão manual do plano | On-demand | Sim (async) | Não |
| Revisão automática semanal | Cron semanal | Sim (async) | Não |
| Dia perdido | Cron diário | Sim (async) | Não |
| Notificações diárias | Cron diário | **Não** | Não |
| Geração do plano inicial | Onboarding | Sim (async) | Não |
