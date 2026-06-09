# 04 — Prompts

## Filosofia

Prompts são **dados**, não código. Admin pode editar sem deploy de Dart/TS.

- **Defaults** em arquivos TS versionados (`server/src/shared/infra/llm/prompts/defaults/*.default.ts`).
- **Overrides** em Firestore (`app_config/prompts.prompts.{promptId}`).
- **Cache** in-memory 60s.
- **Templates** com placeholders `{{var}}` resolvidos via `renderTemplate()`.

## Prompts editáveis (registry)

`GET /v1/admin/prompts/registry` retorna a lista:

| ID | Use case | Modelo padrão |
|---|---|---|
| `plan-init` | Geração inicial do plano (Fase 2) | gemini-3.1-pro-preview |
| `plan-rationale` | Rationale longo do coach pós-geração | gemini-3.5-flash |
| `plan-narratives` | Narrativas curtas semana-a-semana | gemini-3.5-flash |
| `plan-revision` | Revisão manual via app | gemini-3.5-flash |
| `live-voice` | systemInstruction do Gemini Live | gemini-2.5-flash-native-audio |
| `coach-message` | Cues via HTTP (km_reached, pace_alert) | gemini-3.5-flash |
| `coach-chat` | Chat texto fora da corrida | gemini-3.5-flash |
| `weekly-report` | Resumo semanal | gemini-3.5-flash |
| `run-report` | Pós-corrida | gemini-3.5-flash |
| `run-report-enriched` | Pós-corrida com seções coachExplanation densas | gemini-3.5-flash |
| `period-analysis` | Análise de período (tela histórico) | gemini-3.5-flash |
| `weekly-revision-analysis` | Cron domingo (análise 4-block) | gemini-3.5-flash |
| `exam-extract` | OCR de exame médico | gemini-3.5-flash (multimodal) |

## Schema do PromptConfig

```ts
interface PromptConfig {
  systemPrompt: string;      // template com {{persona.tone}}, {{profile.context}}, etc
  userTemplate: string;      // template
  maxTokens: number;
  temperature: number;
  ragChunks?: number;        // topK pra RAG
  // metadata
  version?: string;
  source?: 'default' | 'firestore';
}
```

## getPromptConfig

`server/src/shared/infra/llm/prompts/config-store.ts`:

```ts
const { config, source } = await getPromptConfig('plan-init');
// 1. Tenta Firestore: app_config/prompts.prompts['plan-init']
// 2. Se ausente, fallback pro default TS
// 3. Cache 60s

// renderTemplate aplica placeholders
const finalPrompt = renderTemplate(config.userTemplate, {
  persona: { tone: 'motivador' },
  profile: { name: 'Edu', level: 'iniciante' },
  plan: { goal: 'Completar 10K', weeksCount: 14 },
  rag: knowledgeContext,
});
```

## Personas (resolver)

`server/src/shared/infra/llm/prompts/persona/resolver.ts` mapeia `profile.coachPersonality` → tom:

| Persona | Tom |
|---|---|
| `motivador` | Animado, frases curtas, exclamações pontuais. |
| `tecnico` | Termos científicos, métricas explícitas, sem floreio. |
| `parceiro` | Conversacional, primeira pessoa do plural ("vamos juntos"). |
| `disciplinador` | Direto, sem rodeios, foco em consistência. |

Override também via Firestore (`app_config/prompts.personas.{persona}`).

## Knobs (feature toggles dentro do prompt)

`app_config/prompts.knobs.{knobName}` permite ligar/desligar comportamentos:

| Knob | Default | Efeito |
|---|---|---|
| `respectFeedbackToggles` | true | Quando ON, coach respeita `profile.coachFeedbackEnabled` (mute por tema). |
| `injectWeatherContext` | true | Adiciona temperatura/umidade/vento no live instruction. |
| `injectExecutionSegments` | true | Anexa roteiro km-a-km na live instruction. |
| `enrichedRunReport` | true | Run report tem 4 seções (runAnalysis, planEvolution, etc) vs flat text. |

## Endpoints admin

| Endpoint | Método | Função |
|---|---|---|
| `/v1/admin/prompts/registry` | GET | Lista prompts editáveis + defaults summary |
| `/v1/admin/prompts/defaults` | GET | Retorna prompts default TS (source-of-truth) |
| `/v1/admin/prompts/preview` | POST | Roda LLM com prompt + input de teste, retorna resposta |
| `/v1/admin/prompts/invalidate-cache` | POST | Limpa cache 60s pra refletir Firestore update agora |
| `/v1/admin/wiring-status` | GET | Quais prompts/personas/knobs estão com override Firestore vs default |

## Paths-chave

| Path | Função |
|---|---|
| `server/src/shared/infra/llm/prompts/config-store.ts` | getPromptConfig + cache |
| `server/src/shared/infra/llm/prompts/render.ts` | renderTemplate placeholders |
| `server/src/shared/infra/llm/prompts/persona/resolver.ts` | resolvePersonaTone |
| `server/src/shared/infra/llm/prompts/defaults/*.default.ts` | Defaults versionados |
| `server/src/modules/admin/use-cases/wiring-status.ts` | Detecta overrides |
