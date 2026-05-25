import { Request, Response, NextFunction } from 'express';
import { FirestoreRunRepository } from '../infra/firestore-run.repository';
import { CreateRunUseCase, CreateRunSchema } from '../domain/use-cases/create-run.use-case';
import { AddGpsBatchUseCase, AddGpsBatchSchema } from '../domain/use-cases/add-gps-batch.use-case';
import { CompleteRunUseCase, CompleteRunSchema } from '../domain/use-cases/complete-run.use-case';
import {
  SubmitRunFeedbackUseCase,
  SubmitRunFeedbackSchema,
} from '../domain/use-cases/submit-run-feedback.use-case';
import { NotFoundError } from '@shared/errors/app-error';
import { triggerReportGeneration } from '@modules/coach/http/coach.controller';
import { FirestoreCoachReportRepository } from '@modules/coach/infra/firestore-coach-report.repository';
import { container } from '@shared/container';

const repo = new FirestoreRunRepository();
const createRun = new CreateRunUseCase(repo);
const addGpsBatch = new AddGpsBatchUseCase(repo);
const completeRun = new CompleteRunUseCase(repo);
const submitRunFeedback = new SubmitRunFeedbackUseCase(repo);
const reportRepo = new FirestoreCoachReportRepository();

export async function postRun(req: Request, res: Response, next: NextFunction): Promise<void> {
  try {
    const input = CreateRunSchema.parse(req.body);
    const run = await createRun.execute(req.uid, input);
    res.status(201).json(run);
  } catch (err) { next(err); }
}

export async function patchGps(req: Request, res: Response, next: NextFunction): Promise<void> {
  try {
    const input = AddGpsBatchSchema.parse(req.body);
    const result = await addGpsBatch.execute(req.params['id'] as string, req.uid, input);
    res.json(result);
  } catch (err) { next(err); }
}

export async function patchComplete(req: Request, res: Response, next: NextFunction): Promise<void> {
  try {
    const input = CompleteRunSchema.parse(req.body);
    const run = await completeRun.execute(req.params['id'] as string, req.uid, input);
    triggerReportGeneration(run.id, req.uid);
    // Adapta plano em background com base na corrida concluída (sem consumir
    // cota manual do usuário). Não bloqueia a resposta.
    void container.useCases.adaptPlan.executeAfterRun(req.uid, run.id);
    res.json(run);
  } catch (err) { next(err); }
}

export async function patchFeedback(req: Request, res: Response, next: NextFunction): Promise<void> {
  try {
    const input = SubmitRunFeedbackSchema.parse(req.body);
    const run = await submitRunFeedback.execute(req.params['id'] as string, req.uid, input);
    res.json(run);
  } catch (err) { next(err); }
}

export async function getRun(req: Request, res: Response, next: NextFunction): Promise<void> {
  try {
    const run = await repo.findById(req.params['id'] as string, req.uid);
    if (!run) throw new NotFoundError('Run');
    res.json({ ...run, splits: run.splits ?? [] });
  } catch (err) { next(err); }
}

export async function getRunGps(req: Request, res: Response, next: NextFunction): Promise<void> {
  try {
    const points = await repo.listGpsPoints(req.params['id'] as string, req.uid);
    res.json({ points });
  } catch (err) { next(err); }
}

function extractCoachQuote(summary: string): string | null {
  if (!summary.trim()) return null;
  const sentences = summary.split('. ');
  const firstSentence = sentences[0];
  if (!firstSentence) return null;
  const trimmed = firstSentence.trim();
  if (trimmed.length > 140) {
    return trimmed.slice(0, 140) + '...';
  }
  return trimmed;
}

export async function listRuns(req: Request, res: Response, next: NextFunction): Promise<void> {
  try {
    const limit = Math.min(Number(req.query.limit ?? 20), 50);
    const cursor = req.query.cursor as string | undefined;
    const result = await repo.findByUser(req.uid, limit, cursor);
    
    const runsWithQuotes = await Promise.all(
      result.runs.map(async (run) => {
        if (!run.coachReportId) {
          return { ...run, coachQuote: null };
        }
        const report = await reportRepo.findByRunId(req.uid, run.id);
        if (!report || report.status === 'pending' || !report.summary.trim()) {
          return { ...run, coachQuote: null };
        }
        const coachQuote = extractCoachQuote(report.summary);
        return { ...run, coachQuote };
      })
    );
    
    res.json({ runs: runsWithQuotes, nextCursor: result.nextCursor });
  } catch (err) { next(err); }
}
