import { Request, Response, NextFunction } from 'express';
import { FirestoreExamRepository } from '../infra/firestore-exam.repository';
import { GetUploadUrlUseCase, GetUploadUrlSchema } from '../use-cases/get-upload-url.use-case';
import { FinalizeExamUseCase } from '../use-cases/finalize-exam.use-case';
import { ListExamsUseCase } from '../use-cases/list-exams.use-case';
import { DeleteExamUseCase } from '../use-cases/delete-exam.use-case';

const repo = new FirestoreExamRepository();
const getUploadUrl = new GetUploadUrlUseCase(repo);
const finalizeExam = new FinalizeExamUseCase(repo);
const listExams = new ListExamsUseCase(repo);
const deleteExam = new DeleteExamUseCase(repo);

export async function postUploadUrl(req: Request, res: Response, next: NextFunction): Promise<void> {
  try {
    const input = GetUploadUrlSchema.parse(req.body);
    const result = await getUploadUrl.execute(req.uid, input);
    res.status(201).json(result);
  } catch (err) { next(err); }
}

export async function postFinalizeExam(req: Request, res: Response, next: NextFunction): Promise<void> {
  try {
    const exam = await finalizeExam.execute(req.params['examId'] as string, req.uid);
    res.json(exam);
  } catch (err) { next(err); }
}

export async function getExams(req: Request, res: Response, next: NextFunction): Promise<void> {
  try {
    const cursor = req.query['cursor'] as string | undefined;
    const result = await listExams.execute(req.uid, cursor);
    res.json(result);
  } catch (err) { next(err); }
}

export async function deleteExamHandler(req: Request, res: Response, next: NextFunction): Promise<void> {
  try {
    await deleteExam.execute(req.params['examId'] as string, req.uid);
    res.status(204).send();
  } catch (err) { next(err); }
}
