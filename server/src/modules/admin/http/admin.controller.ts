import { Request, Response, NextFunction } from 'express';
import { z } from 'zod';
import { getAsyncLLM } from '@shared/infra/llm/llm.factory';
import {
  buildPlanInitPrompt,
  buildPlanRevisionPrompt,
  buildLiveCoachPrompt,
  buildPostRunReportPrompt,
  buildPeriodAnalysisPrompt,
  buildCoachChatPrompt,
  buildExamAnalysisPrompt,
  getDefaultsSnapshot,
  invalidatePromptsCache,
  type BuiltPrompt,
} from '@shared/infra/llm/prompts';

const PreviewSchema = z.object({
  builder: z.enum([
    'plan-init',
    'plan-revision',
    'live-coach',
    'post-run-report',
    'period-analysis',
    'coach-chat',
    'exam-analysis',
  ]),
  /** When true, runs the LLM with the compiled prompt and returns its output too. */
  runLlm: z.boolean().optional().default(false),
  /** Optional fixture override; otherwise uses canonical fixture. */
  fixture: z.record(z.string(), z.any()).optional(),
});

const FIXTURE_PROFILE = {
  name: 'João Atleta',
  level: 'intermediario' as const,
  goal: 'Sub 50min nos 10K',
  frequency: 4,
  hasWearable: true,
  gender: 'male' as const,
  birthDate: '1990-05-12',
  weight: '72kg',
  height: '178cm',
  runPeriod: 'manha' as const,
  restingBpm: 55,
  maxBpm: 188,
  medicalConditions: [],
  coachPersonality: 'motivador' as const,
  coachMessageFrequency: 'per_km' as const,
  coachFeedbackEnabled: { pace: true, bpm: true, motivation: true },
};

async function buildByName(builder: string, _fixture: Record<string, unknown> | undefined): Promise<BuiltPrompt> {
  const ragContext = '[KB1] Treino aeróbico em zona 2 prioriza adaptação cardiovascular.\n[KB2] Recuperação ativa acelera resposta neuromuscular.';
  switch (builder) {
    case 'plan-init':
      return buildPlanInitPrompt({
        profile: FIXTURE_PROFILE,
        input: { goal: 'Sub 50min nos 10K', level: 'intermediario', frequency: 4, weeksCount: 8 },
        ragContext,
      });
    case 'plan-revision':
      return buildPlanRevisionPrompt({
        profile: FIXTURE_PROFILE,
        plan: { goal: 'Sub 50min nos 10K', level: 'intermediario', weeksCount: 8, weeks: [] },
        revision: { type: 'more_load', subOption: '+5km/semana', freeText: '' },
        ragContext,
      });
    case 'live-coach':
      return buildLiveCoachPrompt({
        profile: FIXTURE_PROFILE,
        runtimeContextJson: '{"plan":"semana 3 / Easy Run"}',
        ctx: { event: 'km_reached', runType: 'Easy Run', currentPaceMinKm: 5.4, targetPaceMinKm: 5.5, distanceM: 3000, elapsedS: 970, bpm: 152, kmReached: 3 },
        ragContext,
      });
    case 'post-run-report':
      return buildPostRunReportPrompt({
        profile: FIXTURE_PROFILE,
        run: { summary: '- Tipo: Easy Run\n- Distância: 8.00km\n- Duração: 45 minutos\n- Pace médio: 5:38/km' },
        planContext: 'Plano: Sub 50min nos 10K (intermediario, semana atual 3)',
        recentRunsContext: 'Easy Run 6km em 34min; Long Run 12km em 1h12min',
        ragContext,
      });
    case 'period-analysis':
      return buildPeriodAnalysisPrompt({
        profile: FIXTURE_PROFILE,
        period: {
          range: '10 corridas (62 km totais)',
          metrics: '- Quantidade: 10\n- Distância: 62km\n- BPM médio: 148',
          runs: '- 2026-05-01: 8km em 45min\n- 2026-05-04: 5km em 28min',
        },
        ragContext,
      });
    case 'coach-chat':
      return buildCoachChatPrompt({
        profile: FIXTURE_PROFILE,
        question: 'Posso correr hoje mesmo com a perna um pouco dolorida?',
        planContext: 'Plano: Sub 50min nos 10K, semana 3',
        recentRunsContext: 'Easy 6km ontem',
        ragContext,
      });
    case 'exam-analysis':
      return buildExamAnalysisPrompt({
        profile: FIXTURE_PROFILE,
        schema: '{ "summary": string, ... }',
      });
    default:
      throw new Error(`Unknown builder: ${builder}`);
  }
}

export async function postPromptPreview(req: Request, res: Response, next: NextFunction): Promise<void> {
  try {
    const input = PreviewSchema.parse(req.body);
    // Always invalidate before preview so admin sees latest Firestore overrides immediately
    invalidatePromptsCache();

    const built = await buildByName(input.builder, input.fixture);

    let llmOutput: string | undefined;
    if (input.runLlm) {
      const llm = getAsyncLLM();
      llmOutput = await llm.generate(built.userPrompt, {
        systemPrompt: built.systemPrompt,
        maxTokens: Math.min(built.maxTokens, 800),
        temperature: built.temperature,
      });
    }

    res.json({
      systemPrompt: built.systemPrompt,
      userPrompt: built.userPrompt,
      maxTokens: built.maxTokens,
      temperature: built.temperature,
      version: built.version,
      source: built.source,
      llmOutput,
    });
  } catch (err) {
    next(err);
  }
}

export async function getPromptDefaults(_req: Request, res: Response, next: NextFunction): Promise<void> {
  try {
    res.json(getDefaultsSnapshot());
  } catch (err) {
    next(err);
  }
}

export function postInvalidateCache(_req: Request, res: Response): void {
  invalidatePromptsCache();
  res.json({ ok: true });
}
