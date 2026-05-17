import { Request, Response, NextFunction } from 'express';
import { z } from 'zod';
import { FirestorePlanRepository } from '../infra/firestore-plan.repository';
import { FirestorePlanCheckpointRepository } from '../infra/firestore-plan-checkpoint.repository';
import { FirestorePlanRevisionRepository } from '../infra/firestore-plan-revision.repository';
import { FirestoreRunRepository } from '@modules/runs/infra/firestore-run.repository';
import { LlmCheckpointAnalysisStrategy } from '../use-cases/llm-checkpoint-analysis.strategy';
import {
  ApplyCheckpointUseCase,
  CheckpointError,
} from '../use-cases/apply-checkpoint.use-case';
import {
  CheckpointInput,
  CheckpointInputType,
} from '../domain/plan-checkpoint.entity';

const planRepo = new FirestorePlanRepository();
const checkpointRepo = new FirestorePlanCheckpointRepository();
const revisionRepo = new FirestorePlanRevisionRepository();
const runRepo = new FirestoreRunRepository();
const analysisStrategy = new LlmCheckpointAnalysisStrategy();
const applyCheckpoint = new ApplyCheckpointUseCase(
  planRepo,
  checkpointRepo,
  revisionRepo,
  runRepo,
  analysisStrategy,
);

const INPUT_TYPES: CheckpointInputType[] = [
  'load_up',
  'load_down',
  'pain',
  'schedule_conflict',
  'low_energy',
  'sleep_bad',
  'great_week',
  'other',
];

const CheckpointInputSchema = z.object({
  type: z.enum(INPUT_TYPES as [CheckpointInputType, ...CheckpointInputType[]]),
  note: z.string().max(280).optional(),
});

const SubmitInputsBody = z.object({
  inputs: z.array(CheckpointInputSchema).max(8),
});

const ApplyBody = z.object({
  inputs: z.array(CheckpointInputSchema).max(8).optional(),
});

function parseWeekNumber(req: Request, res: Response): number | null {
  const wn = Number(req.params['weekNumber']);
  if (!Number.isInteger(wn) || wn < 1) {
    res.status(400).json({ error: 'invalid_week_number' });
    return null;
  }
  return wn;
}

export async function listCheckpoints(
  req: Request,
  res: Response,
  next: NextFunction,
): Promise<void> {
  try {
    const planId = req.params['id'] as string;
    const items = await checkpointRepo.findByPlan(planId, req.uid);
    res.json({ planId, items });
  } catch (err) {
    next(err);
  }
}

export async function getCheckpoint(
  req: Request,
  res: Response,
  next: NextFunction,
): Promise<void> {
  try {
    const planId = req.params['id'] as string;
    const weekNumber = parseWeekNumber(req, res);
    if (weekNumber == null) return;
    const cp = await checkpointRepo.findByWeek(planId, weekNumber, req.uid);
    if (!cp) {
      res.status(404).json({ error: 'not_found', code: 'CHECKPOINT_NOT_FOUND' });
      return;
    }
    if (!cp.openedAt) {
      await checkpointRepo.update(planId, weekNumber, req.uid, {
        openedAt: new Date().toISOString(),
        status: cp.status === 'scheduled' ? 'in_progress' : cp.status,
      });
    }
    res.json(cp);
  } catch (err) {
    next(err);
  }
}

export async function submitCheckpointInputs(
  req: Request,
  res: Response,
  next: NextFunction,
): Promise<void> {
  try {
    const planId = req.params['id'] as string;
    const weekNumber = parseWeekNumber(req, res);
    if (weekNumber == null) return;
    const body = SubmitInputsBody.parse(req.body);
    const cp = await checkpointRepo.findByWeek(planId, weekNumber, req.uid);
    if (!cp) {
      res.status(404).json({ error: 'not_found', code: 'CHECKPOINT_NOT_FOUND' });
      return;
    }
    if (cp.status === 'completed') {
      res.status(409).json({
        error: 'already_applied',
        code: 'CHECKPOINT_ALREADY_APPLIED',
        message: 'Esse checkpoint já foi aplicado.',
      });
      return;
    }
    const merged = mergeInputs(cp.userInputs ?? [], body.inputs);
    await checkpointRepo.update(planId, weekNumber, req.uid, {
      userInputs: merged,
      status: 'in_progress',
    });
    res.json({ ...cp, userInputs: merged, status: 'in_progress' });
  } catch (err) {
    next(err);
  }
}

export async function applyCheckpointHandler(
  req: Request,
  res: Response,
  next: NextFunction,
): Promise<void> {
  try {
    const planId = req.params['id'] as string;
    const weekNumber = parseWeekNumber(req, res);
    if (weekNumber == null) return;
    const body = ApplyBody.parse(req.body ?? {});
    const result = await applyCheckpoint.execute(
      req.uid,
      planId,
      weekNumber,
      body.inputs ?? [],
    );
    res.json({
      checkpoint: result.checkpoint,
      revision: result.revision,
      plan: result.plan,
    });
  } catch (err) {
    if (err instanceof CheckpointError) {
      const statusCode =
        err.code === 'PLAN_NOT_FOUND' || err.code === 'CHECKPOINT_NOT_FOUND'
          ? 404
          : err.code === 'CHECKPOINT_ALREADY_APPLIED'
          ? 409
          : err.code === 'PLAN_NOT_READY'
          ? 422
          : 400;
      res.status(statusCode).json({
        error: 'checkpoint_error',
        code: err.code,
        message: err.message,
        meta: err.meta,
      });
      return;
    }
    next(err);
  }
}

function mergeInputs(
  existing: CheckpointInput[],
  extra: CheckpointInput[],
): CheckpointInput[] {
  const all = [...existing, ...extra];
  const seen = new Set<string>();
  return all.filter((i) => {
    const k = `${i.type}|${i.note ?? ''}`;
    if (seen.has(k)) return false;
    seen.add(k);
    return true;
  });
}
