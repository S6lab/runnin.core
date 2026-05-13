import { Request, Response, NextFunction } from 'express';
import { FirestorePlanRepository } from '../infra/firestore-plan.repository';
import { GeneratePlanUseCase, GeneratePlanSchema } from '../use-cases/generate-plan.use-case';
import { UpdateSessionStatusUseCase, UpdateSessionStatusSchema } from '../use-cases/update-session-status.use-case';
import { NotFoundError } from '@shared/errors/app-error';
import { getRunningKnowledgeCorpusWithStorage } from '@shared/knowledge/running/running-knowledge';
import { FirestoreUserRepository } from '@modules/users/infra/firestore-user.repository';

const planRepo = new FirestorePlanRepository();
const userRepo = new FirestoreUserRepository();
const generatePlan = new GeneratePlanUseCase(planRepo, userRepo);
const updateSessionStatus = new UpdateSessionStatusUseCase(planRepo);

export async function getCurrentPlan(req: Request, res: Response, next: NextFunction): Promise<void> {
  try {
    const plan = await planRepo.findCurrent(req.uid);
    if (!plan) throw new NotFoundError('Plan');
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
    const plan = await generatePlan.execute(req.uid, input);
    res.status(202).json({ planId: plan.id, status: plan.status });
  } catch (err) { next(err); }
}

export async function getPlanById(req: Request, res: Response, next: NextFunction): Promise<void> {
  try {
    const plan = await planRepo.findById(req.params['id'] as string, req.uid);
    if (!plan) throw new NotFoundError('Plan');
    res.json(plan);
  } catch (err) { next(err); }
}

export async function patchSessionStatus(req: Request, res: Response, next: NextFunction): Promise<void> {
  try {
    const planId = req.params['planId'] as string;
    const sessionId = req.params['sessionId'] as string;
    const input = UpdateSessionStatusSchema.parse(req.body);

    await updateSessionStatus.execute(req.uid, planId, sessionId, input);

    res.status(204).send();
  } catch (err) { next(err); }
}
