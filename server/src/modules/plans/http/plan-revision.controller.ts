import { Request, Response, NextFunction } from 'express';
import { FirestorePlanRepository } from '../infra/firestore-plan.repository';
import { FirestorePlanRevisionRepository } from '../infra/firestore-plan-revision.repository';
import { RequestRevisionUseCase, RequestRevisionSchema, QuotaExhaustedError } from '../use-cases/request-revision.use-case';
import { ListPlanRevisionsUseCase } from '../use-cases/list-plan-revisions.use-case';
import { NotFoundError } from '@shared/errors/app-error';

const planRepo = new FirestorePlanRepository();
const revisionRepo = new FirestorePlanRevisionRepository();
const requestRevision = new RequestRevisionUseCase(planRepo, revisionRepo, undefined as any);
const listRevisions = new ListPlanRevisionsUseCase(revisionRepo);

export async function requestRevisionHandler(req: Request, res: Response, next: NextFunction): Promise<void> {
  try {
    const planId = req.params['id'] as string;
    const input = RequestRevisionSchema.parse(req.body);
    const result = await requestRevision.execute(req.uid, planId, input);
    res.status(200).json(result);
  } catch (err) {
    if (err instanceof QuotaExhaustedError) {
      res.status(429).json({
        error: 'quota_exhausted',
        usedThisWeek: (err as any).usedThisWeek ?? 0,
        max: (err as any).max ?? 1,
        resetAt: (err as any).resetAt ?? new Date().toISOString(),
      });
      return;
    }
    next(err);
  }
}

export async function listRevisionsHandler(req: Request, res: Response, next: NextFunction): Promise<void> {
  try {
    const planId = req.params['id'] as string;
    const revisions = await listRevisions.execute(planId, req.uid);
    res.json({ revisions });
  } catch (err) {
    next(err);
  }
}
