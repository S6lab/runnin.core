import { Request, Response, NextFunction } from 'express';
import { FirestorePlanRepository } from '../infra/firestore-plan.repository';
import { GeneratePlanUseCase, GeneratePlanSchema } from '../use-cases/generate-plan.use-case';
import { NotFoundError } from '@shared/errors/app-error';
import { getRunningKnowledgeCorpusWithStorage } from '@shared/knowledge/running/running-knowledge';
import { Plan, PlanSession } from '../domain/plan.entity';
import { buildExecutionSegments } from '../use-cases/build-execution-segments';
import { getRoteiroTemplates } from '@shared/knowledge/running/roteiro-templates.store';

const repo = new FirestorePlanRepository();
const generatePlan = new GeneratePlanUseCase(repo);

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
 * Garante que cada sessão tem executionSegments populados. Planos antigos
 * (gerados antes do builder determinístico) podem ter [] ou 1 segment
 * solto vindo do LLM. Regenera in-memory na leitura sem mutar Firestore
 * — migration silenciosa só pra resposta.
 */
async function ensureSessionSegments(plan: Plan): Promise<Plan> {
  let patched = false;
  const tpl = await getRoteiroTemplates();
  const weeks = plan.weeks.map((w) => ({
    ...w,
    sessions: w.sessions.map((s: PlanSession) => {
      if ((s.executionSegments?.length ?? 0) >= 2) return s;
      patched = true;
      return { ...s, executionSegments: buildExecutionSegments(s, tpl) };
    }),
  }));
  return patched ? { ...plan, weeks } : plan;
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
