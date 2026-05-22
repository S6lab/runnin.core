import { Request, Response, NextFunction } from 'express';
import { z } from 'zod';
import { FirestorePlanCheckpointRepository } from '../infra/firestore-plan-checkpoint.repository';
import { FirestorePlanRevisionRepository } from '../infra/firestore-plan-revision.repository';
import { CheckpointAlreadyAppliedError } from '../use-cases/checkpoint-shared';
import { container } from '@shared/container';
import {
  CheckpointInput,
  CheckpointInputType,
} from '../domain/plan-checkpoint.entity';
import { NotFoundError } from '@shared/errors/app-error';

const checkpointRepo = new FirestorePlanCheckpointRepository();
const revisionRepo = new FirestorePlanRevisionRepository();
const resolveProposal = container.useCases.resolveProposal;

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
    if (!cp) throw new NotFoundError('Checkpoint');
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
    if (!cp) throw new NotFoundError('Checkpoint');
    if (cp.status === 'completed') {
      throw new CheckpointAlreadyAppliedError(weekNumber, cp.completedAt);
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

/**
 * Detalhe de UMA revisão (proposta pendente ou aplicada). Usado pela tela de
 * proposta no app pra renderizar atual × proposto + explicação do coach.
 */
export async function getRevisionHandler(
  req: Request,
  res: Response,
  next: NextFunction,
): Promise<void> {
  try {
    const planId = req.params['id'] as string;
    const revisionId = req.params['revisionId'] as string;
    const rev = await revisionRepo.findById(revisionId, req.uid);
    if (!rev || rev.planId !== planId) throw new NotFoundError('Revision');
    res.json(rev);
  } catch (err) {
    next(err);
  }
}

/** Aceita a proposta pendente: aplica as próximas 2 semanas no plano. */
export async function acceptProposalHandler(
  req: Request,
  res: Response,
  next: NextFunction,
): Promise<void> {
  try {
    const planId = req.params['id'] as string;
    const revisionId = req.params['revisionId'] as string;
    const result = await resolveProposal.accept(req.uid, planId, revisionId);
    res.json({ revision: result.revision, plan: result.plan });
  } catch (err) {
    next(err);
  }
}

/** Recusa a proposta pendente: descarta o ajuste, mantém o plano atual. */
export async function rejectProposalHandler(
  req: Request,
  res: Response,
  next: NextFunction,
): Promise<void> {
  try {
    const planId = req.params['id'] as string;
    const revisionId = req.params['revisionId'] as string;
    const result = await resolveProposal.reject(req.uid, planId, revisionId);
    res.json({ revision: result.revision, plan: result.plan });
  } catch (err) {
    next(err);
  }
}

/**
 * "Depois": o usuário adia o checkpoint sem aplicar ajuste. Marca como
 * `skipped` (sem revisão). As semanas que seriam detalhadas seguem em
 * esqueleto e são enriquecidas no próximo checkpoint. Não consome cota.
 */
export async function skipCheckpointHandler(
  req: Request,
  res: Response,
  next: NextFunction,
): Promise<void> {
  try {
    const planId = req.params['id'] as string;
    const weekNumber = parseWeekNumber(req, res);
    if (weekNumber == null) return;
    const cp = await checkpointRepo.findByWeek(planId, weekNumber, req.uid);
    if (!cp) throw new NotFoundError('Checkpoint');
    if (cp.status === 'completed') {
      throw new CheckpointAlreadyAppliedError(weekNumber, cp.completedAt);
    }
    await checkpointRepo.update(planId, weekNumber, req.uid, {
      status: 'skipped',
    });
    res.json({ ...cp, status: 'skipped' });
  } catch (err) {
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
