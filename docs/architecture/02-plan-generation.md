# 02 — Geração de Plano

## Pipeline em 5 fases

```
                  ┌──────────────────────────────────┐
                  │  POST /v1/plans/generate         │
                  │  { goal, level, weeks, freq, ... }│
                  └─────────────────┬────────────────┘
                                    │
                                    ▼
   ┌────────────────────────────────────────────────────────────┐
   │  FASE 1: VALIDAÇÕES (síncronas, defensivas)               │
   │                                                            │
   │   • validateGoalWindow(distance, weeks, level)            │
   │   • validatePaceTarget(targetPace, level)                  │
   │   • validateVolumeForGoal(currentKm, distance)            │
   │   • validateMedicalForGoal(exams, conditions)             │
   │   • validateAgeForGoal(age, distance)                      │
   │                                                            │
   │   FAIL → 422 ONBOARDING_INCOMPLETE / PLAN_REJECTED        │
   └─────────────────┬──────────────────────────────────────────┘
                     │ pass
                     ▼
   ┌────────────────────────────────────────────────────────────┐
   │  FASE 2: PLAN INIT (gemini-3.1-pro-preview)              │
   │                                                            │
   │   • buildPlanInitPrompt(profile, goal, level, ...)        │
   │   • RAG: formatRunningKnowledgeContext(query, topK=5)     │
   │     ┌─ chunks vinculantes (Seção R)                      │
   │     └─ chunks tema-match (top similarity)                 │
   │   • llm.generate(prompt, { useCase: 'generate-plan' })   │
   │                                                            │
   │   → JSON { weeks[], checkpoints[], targetSession }       │
   │   → status='generating', adjustedWeeks = weeks (TF 59+)  │
   └─────────────────┬──────────────────────────────────────────┘
                     │
                     ▼
   ┌────────────────────────────────────────────────────────────┐
   │  FASE 3: ENRIQUECIMENTO (gemini-3.5-flash)                │
   │   • coachRationale (markdown 1000-1400 palavras)         │
   │   • mesocycleNarrative (3-4 frases)                       │
   │   • goalAssessment (2-4 frases honestas)                  │
   │   • per-week narratives + blockName + objective + targets │
   │   → useCase: 'plan-rationale', 'plan-narratives'         │
   └─────────────────┬──────────────────────────────────────────┘
                     │
                     ▼
   ┌────────────────────────────────────────────────────────────┐
   │  FASE 4: TWO-TIER ENRICHMENT (`enrichTwoTier`)            │
   │   • 2 próximas semanas = 'full' (recheio completo)       │
   │   • restantes = 'skeleton' (só volume + pace bruto)       │
   │   • Cada checkpoint libera a próxima janela.               │
   └─────────────────┬──────────────────────────────────────────┘
                     │
                     ▼
   ┌────────────────────────────────────────────────────────────┐
   │  FASE 5: BUILD EXECUTION SEGMENTS                          │
   │   • Cada sessão dividida em phases:                       │
   │     warmup (1km) → main → cooldown (1km)                  │
   │   • Roteiro km-a-km lido de roteiro-templates.json        │
   │   • UI mostra phases + instruction no DayDetailPage       │
   └─────────────────┬──────────────────────────────────────────┘
                     │
                     ▼
              status='ready' + push notif "PLANO PRONTO"
```

## Resilience

- **Retry MAX_TOKENS**: até 3 retries com `maxTokens` reduzido + system prompt extra ("seja conciso").
- **Fallback determinístico**: se LLM falha 3x ou usageMetadata vazio, gera plano via heurística (mesma estrutura mas sem narrativa rica).
- **Two-step parsing**: `_parsePlan` tenta JSON.parse; se falhar, manda LLM "repare esse JSON"; se ainda falhar, "expanda o JSON quebrado".
- **Cooldown geração**: user que tentar gerar 2 planos em <5min → 409 PLAN_GENERATION_COOLDOWN.

## Weekly revision (revisão semanal automática)

Cron Cloud Scheduler dispara domingo 23h:

```
runWeeklyProposals (cron)
    │
    ├──► fan-out: 1 Cloud Task por user premium ativo
    │         │
    │         ▼
    │    ProcessUserProposalUseCase.execute(userId)
    │         │
    │         ├──► currentWeekNumber(plan) = N (semana que terminou)
    │         │
    │         ├──► ApplyWeeklyRevisionUseCase
    │         │      │
    │         │      ├──► buildCheckpointProposal
    │         │      │      • biometricSummary 7d (sono, HRV, resting BPM, max BPM)
    │         │      │      • weekRuns (planSessionId vs free run split)
    │         │      │      • weekMetrics (volume, pace, BPM)
    │         │      │
    │         │      ├──► llm-checkpoint-analysis.strategy.ts
    │         │      │      4-block prompt:
    │         │      │       1. Volume overload (3 caminhos A/B/C)
    │         │      │       2. Volume underload
    │         │      │       3. Pace overshoot
    │         │      │       4. Pace undershoot
    │         │      │      Trigger AND (2+ sinais convergentes) vs OR
    │         │      │
    │         │      ├──► mergeProposedWeeks (current+1, current+2 só)
    │         │      ├──► enforceRevisionInvariants (race week + taper intacto)
    │         │      ├──► clampRevisionMagnitude (70-110% piso/teto Pfitzinger)
    │         │      ├──► hydrateRevisedSessions (recheio: segments, nutrição, narrativa)
    │         │      │
    │         │      └──► persist adjustedWeeks + planRevisions doc
    │         │           + push notif "plano atualizado"
    │         │
    │         └──► (idempotente: skip se já aplicado pra week N)
    │
    └──► done
```

Detalhes ver `checkpoint-shared.ts`, `llm-checkpoint-analysis.strategy.ts`, `apply-weekly-revision.use-case.ts`.

## Plano base imutável + adjustedWeeks

- `plan.weeks` = BASE imutável (gerada uma vez).
- `plan.adjustedWeeks` = snapshot vigente (com revisões cumulativas + flag de execução).
- `effectivePlanWeeks(plan)` = `adjustedWeeks ?? weeks` — usado por TODAS as telas de treino corrente.
- "VER PLANO BASE" no app lê `plan.weeks` (imutável).
- Treino/semana/mês + RUN 1/5 + Histórico lêem `effectiveWeeks`.

Ver `project_plan_revision_architecture` na memória pra detalhes da regra.

## Paths-chave

| Path | Função |
|---|---|
| `server/src/modules/plans/use-cases/generate-plan.use-case.ts` | Pipeline 5-fase |
| `server/src/modules/plans/use-cases/apply-weekly-revision.use-case.ts` | Cron domingo |
| `server/src/modules/plans/use-cases/llm-checkpoint-analysis.strategy.ts` | Prompt 4-block |
| `server/src/modules/plans/use-cases/clamp-revision-magnitude.ts` | 70%/110% clamp |
| `server/src/modules/plans/use-cases/hydrate-revised-sessions.ts` | Recheio pós-LLM |
| `server/src/modules/plans/use-cases/enforce-race-week-structure.ts` | Race + taper preservados |
| `server/src/modules/plans/use-cases/checkpoint-shared.ts` | computeWeekData, mergeProposedWeeks |
| `server/src/modules/plans/domain/plan.entity.ts` | `effectivePlanWeeks()` helper |
