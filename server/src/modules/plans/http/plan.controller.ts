import { Request, Response, NextFunction } from 'express';
import { FirestorePlanRepository } from '../infra/firestore-plan.repository';
import { FirestoreUserRepository } from '@modules/users/infra/firestore-user.repository';
import { GeneratePlanUseCase, GeneratePlanSchema } from '../use-cases/generate-plan.use-case';
import { NotFoundError } from '@shared/errors/app-error';
import { getRunningKnowledgeCorpusWithStorage } from '@shared/knowledge/running/running-knowledge';
import { Plan, PlanSession } from '../domain/plan.entity';
import { buildExecutionSegments } from '../use-cases/build-execution-segments';
import { getRoteiroTemplates } from '@shared/knowledge/running/roteiro-templates.store';
import {
  ADMISSIBILITY_CONFIG_VERSION,
  AGE_RESTRICTION_THRESHOLDS,
  BLOCKED_BY_LEVEL,
  FLOW_WEEKLY_KM_CAP,
  IMPROVE_PACE_BYPASS_BY_LEVEL,
  MAX_KM_PER_SESSION,
  MAX_LONG_RUN_RATIO_BY_LEVEL,
  MEDICAL_CONDITION_OPTIONS,
  MIN_FREQ_BY_PROFILE_DISTANCE,
  PACE_IMPROVEMENT_CEILING_PCT,
  PEAK_WEEKLY_KM,
  PEAK_WEEKLY_KM_CAP,
  RACE_WINDOWS,
  RAMP_BASE_FLOOR_KM,
  REDIRECT_TARGET,
  WEEKLY_RAMP_RATE,
  WINDOW_RESTRICTION_BY_PROFILE,
} from '../use-cases/plan-windows.constants';

const repo = new FirestorePlanRepository();
const userRepo = new FirestoreUserRepository();
const generatePlan = new GeneratePlanUseCase(repo, userRepo);

/**
 * Calcula a data final do mesociclo (ISO YYYY-MM-DD) baseada em startDate +
 * weeksCount × 7 - 1 dias. Usado pra detecção lazy de plano concluído.
 * Retorna null se faltar startDate.
 */
function mesocycleEndDate(plan: Plan): string | null {
  if (!plan.startDate) return null;
  const d = new Date(`${plan.startDate}T00:00:00Z`);
  d.setUTCDate(d.getUTCDate() + plan.weeksCount * 7 - 1);
  return d.toISOString().slice(0, 10);
}

/**
 * Detecção LAZY de plano concluído. Quando o plano está 'ready' e o
 * mesocycleEndDate já passou, marca como 'completed' (com completedAt =
 * endDate) e persiste. Evita criar cron dedicado: a próxima leitura faz a
 * transição. Retorna o plano (possivelmente atualizado).
 */
async function detectCompletion(plan: Plan): Promise<Plan> {
  if (plan.status !== 'ready') return plan;
  const endDate = mesocycleEndDate(plan);
  if (!endDate) return plan;
  const today = new Date().toISOString().slice(0, 10);
  if (endDate >= today) return plan; // ainda em curso
  const now = new Date().toISOString();
  const completed: Plan = { ...plan, status: 'completed', completedAt: endDate, updatedAt: now };
  await repo.update(plan.id, plan.userId, {
    status: 'completed',
    completedAt: endDate,
    updatedAt: now,
  });
  return completed;
}

/**
 * Garante que cada sessão tem recheio completo: executionSegments,
 * hydrationLiters, nutritionPre/Post. Rede de segurança no read pra
 * sessões revisadas em que o LLM omitiu algum campo (apesar de Fix 4c
 * hidratar no apply). Planos antigos (pré-builder) também passam aqui.
 *
 * Não escreve no Firestore — só patcha in-memory pra resposta. Lazy.
 */
async function ensureSessionSegments(plan: Plan): Promise<Plan> {
  let patched = false;
  const tpl = await getRoteiroTemplates();
  const patchWeeks = (weeks: Plan['weeks']): Plan['weeks'] =>
    weeks.map((w) => ({
      ...w,
      sessions: w.sessions.map((s: PlanSession) => {
        const needsSegments = (s.executionSegments?.length ?? 0) < 2;
        const needsHydration = !s.hydrationLiters || s.hydrationLiters <= 0;
        const needsPre = !s.nutritionPre || s.nutritionPre.trim().length === 0;
        const needsPost = !s.nutritionPost || s.nutritionPost.trim().length === 0;
        if (!needsSegments && !needsHydration && !needsPre && !needsPost) return s;
        patched = true;
        const next = { ...s };
        if (needsSegments) next.executionSegments = buildExecutionSegments(s, tpl);
        if (needsHydration) next.hydrationLiters = defaultHydrationFromDist(s.distanceKm);
        if (needsPre) next.nutritionPre = defaultPreFor(s.type);
        if (needsPost) next.nutritionPost = defaultPostFor(s.type);
        return next;
      }),
    }));
  const weeks = patchWeeks(plan.weeks);
  const adjustedWeeks = plan.adjustedWeeks ? patchWeeks(plan.adjustedWeeks) : undefined;
  return patched ? { ...plan, weeks, ...(adjustedWeeks ? { adjustedWeeks } : {}) } : plan;
}

function defaultHydrationFromDist(km: number): number {
  if (km <= 4) return 1.5;
  if (km <= 8) return 2.0;
  return 2.5;
}

function defaultPreFor(type: string): string {
  const t = type.toLowerCase();
  if (t.includes('long') || t.includes('tempo')) return 'Banana com pasta de amendoim + café 45min antes.';
  if (t.includes('tiro') || t.includes('interval') || t.includes('fartlek')) return 'Pão integral com mel + café 30-45min antes.';
  if (t.includes('recovery') || t.includes('caminhada')) return 'Fruta + chá 20min antes.';
  return 'Lanche leve 30-45min antes — banana ou pão integral com mel.';
}

function defaultPostFor(type: string): string {
  const t = type.toLowerCase();
  if (t.includes('long')) return 'Refeição completa em 30min: proteína + carbo + fruta.';
  if (t.includes('tiro') || t.includes('interval')) return 'Shake proteico ou iogurte com frutas em 30min.';
  if (t.includes('recovery') || t.includes('caminhada')) return 'Hidratação + fruta — recuperação ativa.';
  return 'Refeição balanceada em até 1h: proteína + carbo + hidratação.';
}

export async function getCurrentPlan(req: Request, res: Response, next: NextFunction): Promise<void> {
  try {
    const raw = await repo.findCurrent(req.uid);
    if (!raw) { res.status(404).json({ error: 'No active plan' }); return; }
    const plan = await detectCompletion(raw);
    res.json(await ensureSessionSegments(plan));
  } catch (err) { next(err); }
}

export async function getPlanKnowledge(_req: Request, res: Response, next: NextFunction): Promise<void> {
  try {
    const chunks = await getRunningKnowledgeCorpusWithStorage();
    res.json({
      chunks: chunks.map(({ embedding: _embedding, ...chunk }) => chunk),
    });
  } catch (err) { next(err); }
}

/**
 * Config de admissibilidade pro wizard do app. Fonte única das regras que
 * antes viviam duplicadas/hardcoded em plan_admissibility.dart (sync
 * manual = drift). App busca no open do wizard, com cache + fallback
 * local quando offline ou em version mismatch.
 */
export function getAdmissibilityConfig(_req: Request, res: Response): void {
  res.json({
    version: ADMISSIBILITY_CONFIG_VERSION,
    raceWindows: RACE_WINDOWS,
    redirectTarget: REDIRECT_TARGET,
    peakWeeklyKm: PEAK_WEEKLY_KM,
    // Matriz v2 (aditivos — app antigo ignora sem quebrar):
    peakWeeklyKmCap: PEAK_WEEKLY_KM_CAP,
    flowWeeklyKmCap: FLOW_WEEKLY_KM_CAP,
    maxLongRunRatioByLevel: MAX_LONG_RUN_RATIO_BY_LEVEL,
    weeklyRampRate: WEEKLY_RAMP_RATE,
    rampBaseFloorKm: RAMP_BASE_FLOOR_KM,
    minFreqByProfileDistance: MIN_FREQ_BY_PROFILE_DISTANCE,
    blockedSentinel: BLOCKED_BY_LEVEL,
    windowRestrictionByProfile: WINDOW_RESTRICTION_BY_PROFILE,
    improvePaceBypassByLevel: IMPROVE_PACE_BYPASS_BY_LEVEL,
    maxKmPerSession: MAX_KM_PER_SESSION,
    medicalConditionOptions: MEDICAL_CONDITION_OPTIONS,
    ageRestrictionThresholds: AGE_RESTRICTION_THRESHOLDS,
    paceImprovementCeilingPct: PACE_IMPROVEMENT_CEILING_PCT,
  });
}

export async function postGeneratePlan(req: Request, res: Response, next: NextFunction): Promise<void> {
  try {
    const input = GeneratePlanSchema.parse(req.body);
    const confirmOverwrite = req.query['confirmOverwrite'] === '1' || (req.body as { confirmOverwrite?: boolean }).confirmOverwrite === true;
    const plan = await generatePlan.execute(req.uid, input, { confirmOverwrite });
    res.status(202).json({ planId: plan.id, status: plan.status });
  } catch (err) {
    if (err instanceof Error && (err as Error & { code?: string }).code === 'PLAN_ALREADY_EXISTS') {
      res.status(409).json({ error: 'PLAN_ALREADY_EXISTS', message: err.message });
      return;
    }
    if (err instanceof Error) {
      const code = (err as Error & { code?: string }).code;
      if (code === 'ONBOARDING_REQUIRED' || code === 'ONBOARDING_INCOMPLETE') {
        res.status(422).json({ error: code, message: err.message });
        return;
      }
    }
    next(err);
  }
}

export async function getPlanById(req: Request, res: Response, next: NextFunction): Promise<void> {
  try {
    const raw = await repo.findById(req.params['id'] as string, req.uid);
    if (!raw) throw new NotFoundError('Plan');
    const plan = await detectCompletion(raw);
    res.json(await ensureSessionSegments(plan));
  } catch (err) { next(err); }
}
