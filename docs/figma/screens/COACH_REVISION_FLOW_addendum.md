# COACH REVISION FLOW — Spec backend + frontend

## Backend (SUP-600 B2)

### `POST /plans/:id/request-revision`

**Headers**: `Authorization: Bearer <firebase-token>`

**Body**:
```ts
{
  type: 'more_load' | 'less_load' | 'more_days' | 'less_days' |
        'more_tempo' | 'more_resistance' | 'more_intervals' |
        'change_days' | 'pain_or_discomfort' | 'other';
  subOption?: string;   // e.g. "+5km/semana", "+10km/semana", "Mais intensidade"
  freeText?: string;    // when type === 'other'
}
```

**Response 200**:
```ts
{
  revision: PlanRevision;     // ver entity já criada em foundation
  updatedPlan: Plan;          // weeks alterados
}
```

**Response 429** (quota esgotada):
```ts
{ error: 'quota_exhausted', usedThisWeek: 1, max: 1, resetAt: '2026-03-10' }
```

### Quota check

```ts
const profile = await userRepo.findById(userId);
const quota = profile.planRevisions ?? { usedThisWeek: 0, max: 1, resetAt: now };
if (quota.usedThisWeek >= quota.max) {
  throw new QuotaExhaustedError(...);
}
```

### LLM modifier prompt

System:
```
Você é o Coach.AI do runnin. Modifique o plano de treino existente conforme a solicitação.

Regras:
1. Mantenha o objetivo do user ({goal})
2. NÃO altere semanas já completas/passadas
3. Modifique apenas semanas futuras a partir da atual ({currentWeekIndex})
4. Se houver dados clínicos (exam summaries), respeite limites (FCmáx, limiar)
5. Preserve a periodização (não quebre estrutura linear 3:1)
6. Retorne APENAS JSON estrito conforme schema.
```

User:
```
Plano atual (semanas futuras a partir de {currentWeekIndex}):
{plan.weeks.slice(currentWeekIndex).map(...)}

Solicitação do user:
- Tipo: {type}
- Sub-opção: {subOption ?? 'N/A'}
- Texto livre: {freeText ?? 'N/A'}

Profile: nível={level}, objetivo={goal}, frequência={frequency}x/semana
{exam summaries from RAG}

Retorne JSON estrito:
{
  "coachExplanation": string,  // 2-3 frases explicando o que mudou e por quê. Cite exames se relevante.
  "newWeeks": [                // weeks modificadas (mesmo schema de PlanWeek)
    {
      "weekNumber": 2,
      "focus": "Intervalado",
      "narrative": "Semana focada em...",
      "sessions": [
        { "dayOfWeek": 1, "type": "Easy Run", "distanceKm": 5, "targetPace": "6:30", "notes": "..." }
      ]
    }
  ]
}
```

### Schema Zod

```ts
const PlanWeekSchema = z.object({
  weekNumber: z.number().int().positive(),
  focus: z.string().optional(),
  narrative: z.string().optional(),
  sessions: z.array(z.object({
    dayOfWeek: z.number().int().min(1).max(7),
    type: z.string().min(1),
    distanceKm: z.number().positive(),
    targetPace: z.string().optional(),
    notes: z.string(),
  })),
});

const RevisionResponseSchema = z.object({
  coachExplanation: z.string().min(20).max(400),
  newWeeks: z.array(PlanWeekSchema).min(1),
});
```

### Flow no use-case

1. Snapshot `oldWeeksSnapshot = [...plan.weeks]`
2. LLM gera `newWeeks` + `coachExplanation`
3. Merge: `plan.weeks = [...plan.weeks.slice(0, currentWeekIndex), ...newWeeks]`
4. `planRepo.update(planId, { weeks: plan.weeks })`
5. `planRevisionRepo.save({ id, planId, weekIndex: currentWeekIndex, ..., status: 'applied' })`
6. `userRepo.update(userId, { planRevisions: { ...quota, usedThisWeek: quota.usedThisWeek + 1 } })`

### `GET /plans/:id/revisions`
Lista revisões aplicadas pra AJUSTES histórico.

## Frontend (SUP-611 C6)

### `revision_flow_page.dart`

Route: `/training/revise` (ou modal full-screen dentro de TREINO).

State machine (4 telas):

**1. Choice screen** (tela 24 do mockup)
- Header `// SOLICITAR ALTERAÇÃO` + heading + subtitle ancorando ao relatório semanal
- Grid 2-col com 10 `FigmaWizardChoiceCard` (ver A6) — single-select
- Bottom: card "1 ALTERAÇÃO SELECIONADA" + CTA "CONVERSAR COM COACH ↗"

**2. Drill-down screen** (tela 26)
- Header "SESSÃO DE AJUSTE · {TIPO}" + sub "✓ N exames integrados" (lê `GET /exams?count=true`)
- User bubble (cyan border) com texto da escolha
- Coach bubble (orange border) com pergunta + 4 `FigmaQuickReplyButton` (sub-options definidas por tipo):

```dart
const subOptions = {
  'more_load': ['+5km/semana', '+10km/semana', 'Mais intensidade', 'Volume + intensidade'],
  'less_load': ['-5km/semana', 'Reduzir intensidade', 'Mais descanso'],
  'more_days': ['+1 dia', '+2 dias'],
  'less_days': ['-1 dia', '-2 dias'],
  'more_tempo': ['1 tempo run', '2 tempos por semana'],
  'more_resistance': ['+1 long run', 'Aumentar long run'],
  'more_intervals': ['400m', '800m', '1km repeats'],
  'change_days': ['Editar manualmente'],
  'pain_or_discomfort': ['Reduzir volume 50%', 'Pausar 1 semana'],
  'other': [], // free text input
};
```

**3. Confirm screen** (tela 27)
- User bubble com sub-option escolhida
- Coach bubble com texto LLM (`coachExplanation`) explicando o que vai mudar
- 2 CTAs: "Confirmar alteração" (cyan border) + "Cancelar" (outline)

**4. Post-apply** (tela 28)
- Mensagem "Plano recalculado! As mudanças entram em vigor a partir da próxima sessão."
- 2 CTAs: "VER PLANO ATUALIZADO ↗" (push `/training`) + "HOME" (push `/home`)

### `adjustments_history_page.dart` (TREINO > AJUSTES)

- Card "REVISÃO USADA ESTA SEMANA" — orange border + "Próxima disponível em Semana N" + chip count
- Card laranja COACH.AI > COMO FUNCIONAM AS REVISÕES (texto educacional)
- Lista "SOLICITAÇÕES ANTERIORES" — cards (consume `GET /plans/:id/revisions`)
- "CALENDÁRIO DE REVISÕES" — `FigmaCalendarVisualization` (ver A6) mostrando 4 semanas com status
