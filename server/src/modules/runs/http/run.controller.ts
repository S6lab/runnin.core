import { Request, Response, NextFunction } from 'express';
import { FirestoreRunRepository } from '../infra/firestore-run.repository';
import { CreateRunUseCase, CreateRunSchema } from '../domain/use-cases/create-run.use-case';
import { AddGpsBatchUseCase, AddGpsBatchSchema } from '../domain/use-cases/add-gps-batch.use-case';
import { CompleteRunUseCase, CompleteRunSchema } from '../domain/use-cases/complete-run.use-case';
import { BenchmarkRepository } from '@modules/benchmark/domain/benchmark.repository';
import { NotFoundError } from '@shared/errors/app-error';
import { triggerReportGeneration } from '@modules/coach/http/coach.controller';

const repo = new FirestoreRunRepository();
const benchmarkRepo = new BenchmarkRepository();
const createRun = new CreateRunUseCase(repo);
const addGpsBatch = new AddGpsBatchUseCase(repo);
const completeRun = new CompleteRunUseCase(repo, benchmarkRepo);

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
    res.json(run);
  } catch (err) { next(err); }
}

export async function getRun(req: Request, res: Response, next: NextFunction): Promise<void> {
  try {
    const run = await repo.findById(req.params['id'] as string, req.uid);
    if (!run) throw new NotFoundError('Run');
    res.json(run);
  } catch (err) { next(err); }
}

export async function listRuns(req: Request, res: Response, next: NextFunction): Promise<void> {
  try {
    const limit = Math.min(Number(req.query.limit ?? 20), 50);
    const cursor = req.query.cursor as string | undefined;
    const result = await repo.findByUser(req.uid, limit, cursor);
    res.json(result);
  } catch (err) { next(err); }
}
