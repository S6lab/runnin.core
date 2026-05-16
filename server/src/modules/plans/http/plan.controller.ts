import { Request, Response, NextFunction } from 'express';
import { FirestorePlanRepository } from '../infra/firestore-plan.repository';
import { GeneratePlanUseCase, GeneratePlanSchema } from '../use-cases/generate-plan.use-case';
import { NotFoundError } from '@shared/errors/app-error';
import { getRunningKnowledgeCorpusWithStorage } from '@shared/knowledge/running/running-knowledge';

const repo = new FirestorePlanRepository();
const generatePlan = new GeneratePlanUseCase(repo);

export async function getCurrentPlan(req: Request, res: Response, next: NextFunction): Promise<void> {
  try {
    const plan = await repo.findCurrent(req.uid);
    if (!plan) { res.status(404).json({ error: 'No active plan' }); return; }
    res.json(plan);
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
    next(err);
  }
}

export async function getPlanById(req: Request, res: Response, next: NextFunction): Promise<void> {
  try {
    const plan = await repo.findById(req.params['id'] as string, req.uid);
    if (!plan) throw new NotFoundError('Plan');
    res.json(plan);
  } catch (err) { next(err); }
}
