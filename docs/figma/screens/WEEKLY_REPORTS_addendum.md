# WEEKLY_REPORTS — Spec backend + frontend

## Endpoints (server)

### `GET /weekly-reports?limit=10`
Lista paginada (mais recente primeiro). Cada item:
```json
{
  "id": "userId_weekStart",
  "weekStart": "2026-03-03",
  "weekEnd": "2026-03-09",
  "weekNumber": 2,
  "adherence": 40,
  "kmTotal": 13.2,
  "paceAvg": "5:38",
  "sessionsDone": 2,
  "sessionsPlanned": 5,
  "freeRunsCount": 1,
  "freeRunsKm": 3.2,
  "coachQuote": "Semana em andamento..." // 1ª frase de analysis.coachAnalysis
}
```

### `GET /weekly-reports/:weekStart`
Detalhe completo:
```json
{
  ...lista_fields,
  "analysis": {
    "coachAnalysis": "2-3 frases analisando a semana, citando dados específicos.",
    "highlights": [
      { "type": "positive", "text": "Intervalado sub-5 consistente" },
      { "type": "alert",    "text": "BPM máx no intervalado foi 185 — próximo do teto" }
    ],
    "recommendation": "1-2 frases recomendando ajuste pra próxima semana."
  },
  "status": "ready",
  "generatedAt": "..."
}
```

### `POST /weekly-reports/:weekStart/regenerate` (opcional)
Força regeneração (uso pelo user OR pelo Cloud Scheduler na 2ª-feira).

## LLM (Gemini 2.5 Flash) prompt template

System prompt (use `coach-config.service` defaults):
```
Você é o Coach.AI do runnin. Analise a SEMANA do corredor abaixo com tom firme, motivador e técnico.
Use dados específicos (km, pace, BPM). Identifique padrões positivos e alertas.
Retorne APENAS JSON estrito conforme schema. Não adicione comentários, markdown ou texto fora do JSON.
```

User prompt:
```
Plano da semana: {weekNumber}/{totalWeeks}, foco: {focus}
Sessões planejadas:
{plannedSessions.map((s, i) => `  ${i+1}. ${dayName(s.dayOfWeek)}: ${s.type} ${s.distanceKm}km @ ${s.targetPace ?? 'livre'}`).join('\n')}

Sessões concluídas (executadas conforme plano):
{completedFromPlan.map((r, i) => `  ${i+1}. ${dayName(date(r.createdAt))}: ${r.type} ${(r.distanceM/1000).toFixed(1)}km @ ${r.avgPace} BPM ${r.avgBpm ?? 'N/A'}/${r.maxBpm ?? 'N/A'}`).join('\n')}

Corridas livres (fora do plano):
{freeRuns.map(...).join('\n')}

Profile: nível={level}, objetivo={goal}, gênero={gender ?? 'N/A'}, runPeriod={runPeriod ?? 'N/A'}
{exam summaries from RAG, if any}

Aderência: {adherencePercent}% ({sessionsDone}/{plannedTotal})
KM total da semana: {kmTotal}
Pace médio: {paceAvg}
BPM médio: {bpmAvg}

Base de conhecimento de corrida:
{ragContext}

Retorne JSON estrito:
{
  "coachAnalysis": string,    // 2-3 frases. Cite KM, pace, BPM específicos. Cite o foco da semana.
  "highlights": [             // 3-5 items
    { "type": "positive" | "alert", "text": string }
  ],
  "recommendation": string    // 1-2 frases. Concreto: "ajuste pace do tempo run para X" ou "mantenha"
}
```

## Schema Zod (server)

```ts
const WeeklyReportAnalysisSchema = z.object({
  coachAnalysis: z.string().min(20).max(400),
  highlights: z.array(z.object({
    type: z.enum(['positive', 'alert']),
    text: z.string().min(5).max(120),
  })).min(2).max(6),
  recommendation: z.string().min(10).max(200),
});
```

Se parse falhar, retry 1× com prompt corretivo `"O JSON anterior tinha {error}. Refaça respeitando o schema."`. Se falhar de novo, fallback template:
```json
{
  "coachAnalysis": "Semana com {sessionsDone} de {sessionsPlanned} sessões concluídas. {kmTotal}km totais.",
  "highlights": [{ "type": "positive", "text": "Semana iniciada" }],
  "recommendation": "Continue executando o plano."
}
```

## Idempotência

Document id: `${userId}_${weekStart}` (formato `YYYY-MM-DD` da segunda-feira da semana).
Re-chamadas de `GET /weekly-reports/:weekStart` retornam cached se já gerado.

## Cloud Scheduler (futuro — SUP-601)

Job semanal toda segunda 06:00 BRT itera users e força regeneração para a semana anterior (para que o relatório esteja pronto quando o user abrir o app).

## Frontend consumer (C5 SUP-606)

### Lista (TREINO > RELATÓRIOS — tela 22 mockup)
`ReportCard` por semana com:
- Header: "Semana N" + range de datas + badge `MAIS RECENTE` (no item [0])
- Stats: ADERÊNCIA % (cor: verde ≥ 70, orange < 70) + KM + SESSÕES + FREE
- 1-3 linhas do `coachQuote` (snippet)
- Badge "SEM REVISÃO" (placeholder até PlanRevision wirado)

### Detail page `weekly_report_detail_page.dart`
Componentes ordenados:
1. TopNav breadcrumb "RUNNIN.AI / RELATÓRIO" + back
2. `// RELATÓRIO SEMANAL` label + "Semana N" + date range
3. Card ADERÊNCIA com `FigmaAdherenceProgress` (criar em A6) + badge "ATENÇÃO" se < 70
4. Grid 3 stat tiles (KM TOTAL / PACE MÉD / SESSÕES X de Y)
5. Card laranja "TREINOS LIVRES INTEGRADOS" + badge ADAPTADO (mostrar se freeRunsCount > 0)
6. ANÁLISE DO COACH (cyan-border card, texto = `analysis.coachAnalysis`)
7. DESTAQUES (lista de `FigmaHighlightBullet` — `+` para positive, `!` para alert; criar em A6)
8. ADAPTAÇÃO SUGERIDA (orange-border card, texto = `analysis.recommendation`)
9. META: copy estática "Completar {profile.goal}" + "trajetória mantida"
10. 2 CTAs: "CONVERSAR COM COACH ↗" (push `/coach` ou abrir revision wizard) + "MANTER PLANO ATUAL"
11. Footer: "{remaining} revisão disponível por semana" (lê `user.planRevisions`)
