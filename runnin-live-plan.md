# 09 — Coach Cue System: limpeza, prioridade e clean architecture

## Problema atual

- **Sobreposição**: múltiplos eventos chegam em sequência rápida (ex: `km_reached` + `segment_start` no mesmo km), geram dois cues simultâneos, Gemini Live fala os dois ao mesmo tempo
- **Eventos demais**: 16 tipos de evento — muitos redundantes (`segment_start`, `segment_end`, `motivation`, `check_in`, `pre_run`, `preview`, `km_split`, `segment_pace_off`) causam ruído
- **Estado disperso**: `lastSegmentStartAtByRunId` em memória direto no use case, sem abstração
- **Watch duplication**: sem dedup por origem (watch vs iPhone disparam mesmo evento)
- **Sem fila**: o servidor processa todas as requests em paralelo sem serialização

---

## Eventos limpos: antes → depois

| Antes | Depois | Prioridade | Template/LLM |
|---|---|---|---|
| `start` | `start` | P2 | LLM |
| `check_in` (500m) | `half_km` | P3 | LLM |
| `km_reached` | `km_reached` | P2 | LLM |
| `high_bpm` | `bpm_alert` | P0 | Template |
| `pace_alert` | `pace_alert` | P1 | Template |
| `goal_reached` | `goal_reached` | P1 | LLM |
| `finish` | `finish` | P1 | LLM |
| `no_movement` | `no_movement` | P3 | Template |
| ~~`pre_run`~~ | removido | | |
| ~~`motivation`~~ | removido | | |
| ~~`question`~~ | removido | | |
| ~~`preview`~~ | removido | | |
| ~~`segment_start`~~ | removido | | |
| ~~`segment_end`~~ | removido | | |
| ~~`segment_pace_off`~~ | removido | | |
| ~~`km_split`~~ | removido | | |

**P0** = segurança, interrompe qualquer cue em andamento  
**P1** = importante, aguarda P0 terminar  
**P2** = normal, aguarda P0+P1  
**P3** = background, descartado se fila ocupada com ≥P2

---

## Payloads por evento

```typescript
// start — sistema: systemInstruction completo
type StartPayload = {
  profile: ProfileSnippet;       // nome, nível, goal, frequência
  session: SessionSnippet;       // tipo, distância, targetPace, notas
  segments: ExecutionSegment[];  // roteiro completo
  weather?: WeatherSnapshot;     // temp, humidity, wind
}

// half_km — 500m mark, pace últimos 500m vs projetado
type HalfKmPayload = {
  name: string;
  kmDone: number;           // ex: 2.5
  kmRemaining: number;      // ex: 7.5
  pace500m: string;         // pace dos últimos 500m formado "5:30"
  targetPace?: string;      // null após goal_reached (modo livre)
}

// km_reached — fechamento do split
type KmReachedPayload = {
  kmTotal: number;          // km completado
  currentPace: string;      // pace do km fechado
  targetPace: string;       // pace planejado
  bpm: number;
  activeSegment: ActiveSegmentSnippet;  // fase + instrução atual
}

// bpm_alert — P0, template, sem LLM
type BpmAlertPayload = {
  name: string;
  bpm: number;
  maxBpm: number;           // calculado Karvonen
  source: 'realtime';       // obrigatório: não aceita fallback
}

// pace_alert — P1, template, guard rail 30%
type PaceAlertPayload = {
  name: string;
  currentPace: string;
  targetPace: string;
  deviationPct: number;     // ex: 32 (%)
}

// goal_reached — pergunta se vai continuar
type GoalReachedPayload = {
  name: string;
  totalDistanceKm: number;
  elapsedMin: number;
  avgPace: string;
}

// finish — resumo final
type FinishPayload = {
  totalDistanceKm: number;  // 2 casas decimais
  elapsedMin: number;
  avgPace: string;
  avgBpm: number;
  calories: number;
}

// no_movement — template, Δs < 50m por 1min
type NoMovementPayload = {
  runId: string;
  name: string;             // vocativo
}
```

---

## Arquitetura nova

```
modules/coach/
  domain/
    cue-event.types.ts         ← tipos limpos + payloads acima
    cue-priority.ts            ← enum P0–P3 + config de cooldown por evento
    cue-queue.entity.ts        ← fila com prioridade, cooldown, busy flag
    cue-session.entity.ts      ← estado de uma sessão (mode: planned|free, etc.)
  use-cases/
    process-cue-event.use-case.ts    ← orquestrador principal (substitui coach-message)
    generate-cue-text.use-case.ts    ← puro: evento → texto (LLM ou template)
    deliver-cue.use-case.ts          ← envia para Live WS ou HTTP fallback
    coach-runtime-context.service.ts ← inalterado
    build-run-coach-instruction.ts   ← inalterado
    live-session-registry.ts         ← inalterado
    log-live-turn.use-case.ts        ← inalterado
  infra/
    cue-session-store.ts       ← Map<runId, CueSession> — estado único de runtime
    template-cues.ts           ← simplificado: apenas bpm_alert, pace_alert, no_movement
  http/
    coach.controller.ts        ← simplificado: valida + chama process-cue-event
    coach.routes.ts            ← inalterado
    coach-live.ws.ts           ← emite sinal turnComplete para o CueSessionStore
```

---

## CueQueue: comportamento

```
Evento chega no servidor
       │
       ▼
Verificar dedup por origem
(watch + iPhone, mesmo evento, janela 3s) ──► drop se duplicata
       │
       ▼
Verificar cooldown do evento ──────────────► drop se dentro do cooldown
       │
       ▼
Verificar prioridade vs fila atual:
  P0 chegou → interrompe cue ativo, injeta imediatamente
  P1 chegou → aguarda P0 terminar, preempta P2/P3 na fila
  P2 chegou → aguarda P0+P1, descarta P3 pendente na fila
  P3 chegou → descartado se fila não vazia
       │
       ▼
Enfileirar (ou executar direto se fila vazia)
       │
       ▼
[Gemini Live turnComplete] ──► marca busy=false ──► processa próximo da fila
```

**Cooldowns por evento:**

| Evento | Cooldown |
|---|---|
| `bpm_alert` | 60s |
| `pace_alert` | 30s |
| `no_movement` | 60s |
| `half_km` | — (1x por 500m) |
| `km_reached` | — (1x por km) |
| `start` / `finish` / `goal_reached` | — (1x por run) |

---

## Fluxo de entrega

```
process-cue-event
      │
      ├── dedup watch/phone ──► drop
      ├── cooldown check ─────► drop  
      ├── priority check ─────► drop/preempt/queue
      │
      ▼
generate-cue-text
      │
      ├── Template (P0 bpm_alert, P1 pace_alert, P3 no_movement)
      │     └── retorna texto imediato, sem LLM
      │
      └── LLM (start, half_km, km_reached, goal_reached, finish)
            └── buildPrompt(event, payload) → LLM.generate()
      │
      ▼
deliver-cue
      │
      ├── Live WS ativo? ──── inject text → Gemini Live
      │                         aguarda turnComplete → queue.setBusy(false)
      │
      └── Sem Live WS ──────── HTTP SSE (text + audioBase64)
                                on stream end → queue.setBusy(false)
```

---

## Modo livre (após goal_reached aceitar continuar)

`CueSession.mode` muda de `'planned'` → `'free'` quando o usuário confirma que vai continuar.

No modo `'free'`:
- `half_km`: payload sem `targetPace` (só `kmDone` + `pace500m`)
- `km_reached`: payload sem `targetPace` + sem `activeSegment`
- `goal_reached` e seus follow-ups: não geram novos cues de progressão do roteiro

---

## CueSessionStore (infra)

Substitui todo o estado disperso atual (`lastSegmentStartAtByRunId`, cache de contexto, etc.):

```typescript
interface CueSession {
  runId: string;
  queue: CueQueue;
  mode: 'planned' | 'free';
  lastCueTexts: string[];        // últimos 3, injetados no systemInstruction na rotação
  activeSegmentIndex: number;    // atualizado pelo app via currentSegmentIndex
  sessionGeneration: number;     // contador de reconnects do Gemini Live
  createdAt: number;
}

class CueSessionStore {
  get(runId: string): CueSession | null
  getOrCreate(runId: string): CueSession
  destroy(runId: string): void   // chamado em finish ou expiração
  // TTL: 8h (cobertura para ultramaratona)
}
```

---

## Arquivos a criar

| Arquivo | O que é |
|---|---|
| `domain/cue-event.types.ts` | Tipos limpos, union type dos 8 eventos + payloads |
| `domain/cue-priority.ts` | Enum P0–P3, cooldown config, regras de preemption |
| `domain/cue-queue.entity.ts` | Classe pura (sem I/O): enqueue, next, dedup, busy |
| `domain/cue-session.entity.ts` | Estado de uma sessão (mode, lastCueTexts, etc.) |
| `infra/cue-session-store.ts` | Map<runId, CueSession> com TTL |
| `use-cases/process-cue-event.use-case.ts` | Orquestrador principal |
| `use-cases/generate-cue-text.use-case.ts` | Texto puro por evento (LLM ou template) |
| `use-cases/deliver-cue.use-case.ts` | Entrega via Live WS ou HTTP SSE |

## Arquivos a modificar

| Arquivo | O que muda |
|---|---|
| `use-cases/coach-message.use-case.ts` | Substituído pelo `process-cue-event` — o arquivo vira um thin adapter enquanto o app não migra o nome do endpoint |
| `infra/template-cues.ts` | Reduzido para 3 templates: `bpm_alert`, `pace_alert`, `no_movement` |
| `http/coach.controller.ts` | Simplificado: valida payload → chama `process-cue-event` |
| `http/coach-live.ws.ts` | Emite `turnComplete` para o `CueSessionStore` |

## Arquivos inalterados

- `coach-runtime-context.service.ts`
- `build-run-coach-instruction.ts`
- `live-session-registry.ts`
- `log-live-turn.use-case.ts`
- `generate-report.use-case.ts`
- `generate-period-analysis.use-case.ts`
- `coach-chat.use-case.ts`
- Todo o LLM infra (`shared/infra/llm/`)
- Todos os repos Firestore

---

## Preparação para microserviço (s6-ai)

Cada camada da clean architecture mapeia diretamente para o s6-ai:

| Módulo local | s6-ai |
|---|---|
| `domain/cue-event.types.ts` | `src/features/coach/coach.types.ts` |
| `use-cases/generate-cue-text.use-case.ts` | `src/features/coach/cue.use-case.ts` |
| `use-cases/deliver-cue.use-case.ts` | `src/features/coach/live/live.ws.ts` |
| `infra/template-cues.ts` | `src/features/coach/templates/` |
| `infra/cue-session-store.ts` | `src/features/coach/live-context.manager.ts` |

Quando migrar: `process-cue-event` vira um POST `/v1/coach/cue` no s6-ai. O runnin.core passa a ser só um proxy de eventos (valida Firebase auth + serializa payload → s6-ai).

---

## Testes

```
__tests__/
  cue-queue.entity.test.ts         ← priority, cooldown, preemption sem I/O
  cue-session-store.test.ts        ← TTL, getOrCreate, destroy
  process-cue-event.test.ts        ← por evento: payload → cue gerado ou drop
  generate-cue-text.test.ts        ← mock LLMProvider, verifica prompt por evento
  template-cues.test.ts            ← os 3 templates com variações determinísticas
```
