# 03 — RAGs (Retrieval-Augmented Generation)

Dois RAGs convivem: **global** (curated, 140+ chunks de ciência de corrida) e **per-user** (exames OCR extraídos).

## RAG global

### Corpus

`server/src/shared/knowledge/running/running-knowledge-corpus.json` — chunks estáticos versionados.

Estrutura de cada chunk:

```json
{
  "id": "A.1.2",
  "secao": "A",         // letra da seção (A..R)
  "tema": "fisiologia.zona-aerobica",
  "categoria": ["aerobic", "zone2", "easy-pace"],
  "nivel": ["iniciante", "intermediario", "avancado"],
  "encaminhamento": ["plan-init", "weekly-revision"],
  "vinculante": false,  // true = sempre inclui em prompts sensíveis
  "text": "Texto técnico do chunk (1-3 parágrafos)..."
}
```

### Seções (A-R)

| Seção | Tema |
|---|---|
| A | Fisiologia básica (zonas, VO2, limiar) |
| B | Princípios de periodização |
| C | Tipos de sessão (Easy, Long, Tempo, Tiros, Fartlek, Progressivo, Recovery) |
| D | Pace alvo por nível/distância |
| E | Hidratação + nutrição |
| F | Recuperação + sono |
| G | Lesões comuns (prevenção, não tratamento) |
| H | Calor, frio, altitude |
| I | Tapering pré-prova |
| ... | ... |
| **R** | **Bounds clinical/legal — SEMPRE incluso em planos sensíveis** |

Seção R é `vinculante: true` — chunks com `hasNegativeSymptom`, `medicalConditions`, ou exames OCR-detectados (ferritina baixa, hipertensão, etc) NUNCA são droppados do prompt.

### Indexação (embedding)

```
build-time / admin trigger:
  ┌──────────────────────┐
  │ corpus.json (estatico)│
  └──────────┬───────────┘
             │
             ▼
  ┌──────────────────────┐
  │ embed each chunk     │
  │ (gemini-embedding-001)│
  └──────────┬───────────┘
             │
             ▼
  ┌──────────────────────┐
  │ rag_chunks Firestore │  ← collection raiz, doc id = chunk.id
  │ { ...chunk, embedding}│
  └──────────────────────┘
```

Admin endpoint `POST /v1/admin/rag/reindex` força re-embed. Chamado quando o corpus muda.

### Retrieval

`server/src/shared/knowledge/running/running-knowledge.ts`:

```ts
formatRunningKnowledgeContext(query: string, topK: number = 5)
```

1. Tokeniza `query` (lower + split).
2. Score per chunk:
   - +1.0 por categoria-tag match
   - +0.5 por tema substring match
   - +0.3 por nivel match
   - +∞ se `vinculante: true` (always-include)
3. Embedding similarity (cosine) com query embedding — top-K final.
4. Cache 5min por query string.

Retorna `string` com chunks separados por `---`.

## RAG por usuário (exames OCR)

### Pipeline

```
app: POST /v1/exams (upload PDF/JPG)
                │
                ▼
       Storage bucket: exams/{uid}/{examId}.{pdf|jpg}
                │
                ▼
       POST /v1/exams/:id/analyze (interno, async)
                │
                ▼
  GeminiMultimodalService.generateTextWithImage(
    prompt: "Extraia: VO2max, FC max/limiar, ferritina,
             hemoglobina, vit D, recomendações, alerts",
    imageData, mimeType,
    trackOpts: { userId, useCase: 'analyze-exam' }
  )
                │
                ▼
  Parse JSON estruturado:
  {
    summary: "Atleta saudável, vit D baixa.",
    keyFindings: ["VO2max 48", "ferritina 65"],
    recommendations: ["Suplementar vit D"],
    vo2max: 48, fcMax: 184, vitaminaD: 22, ...
  }
                │
                ▼
  Persist em: exams/{examId} doc
              + users/{uid}/medicalConditions (mutate)
              + rag_chunks: 1 chunk por finding (embed)
                              { userId, examId, finding, embedding }
```

### Injeção em prompts

Quando geração de plano roda pra `userId=X`:

```ts
formatRunningKnowledgeContext(query, topK=5)
  // Internamente:
  // - Fetch global chunks (rag_chunks where userId is null)
  // - Fetch user chunks (rag_chunks where userId == X)
  // - Merge + score + dedup + topK
```

User chunks têm prioridade quando match com tema do prompt (ex: prompt menciona "anemia" → ferritina chunk do user vai pro topo).

## Cache + invalidação

- Cache em memória: 5min por `(query, userId, topK)` tuple.
- Invalidação: `POST /v1/admin/rag/purge` limpa cache.
- Re-embed total: `POST /v1/admin/rag/reindex`.

## Paths-chave

| Path | Função |
|---|---|
| `server/src/shared/knowledge/running/running-knowledge-corpus.json` | Corpus estático global |
| `server/src/shared/knowledge/running/running-knowledge.ts` | Load, score, retrieve |
| `server/src/shared/infra/llm/embedding.adapter.ts` | gemini-embedding-001 |
| `server/src/modules/exams/use-cases/analyze-exam.use-case.ts` | OCR + chunk creation user |
| `server/src/modules/admin/use-cases/reindex-rag.use-case.ts` | Re-embed total |
| `server/src/modules/admin/use-cases/purge-rag-cache.use-case.ts` | Cache flush |
