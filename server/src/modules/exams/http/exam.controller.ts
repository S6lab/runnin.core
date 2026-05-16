import { Request, Response, NextFunction } from 'express';
import { GenerateUploadUrlUseCase, GenerateUploadUrlInput } from '../use-cases/generate-exam-upload-url.use-case';
import { InMemoryExamRepository } from '../infra/in-memory-exam.repository';
import { NotFoundError } from '@shared/errors/app-error';

const repo = new InMemoryExamRepository();
const generateUploadUrlUseCase = new GenerateUploadUrlUseCase(repo);

export async function postGenerateUploadUrl(req: Request, res: Response, next: NextFunction): Promise<void> {
  try {
    const input: GenerateUploadUrlInput = {
      examName: req.body.examName,
      fileName: req.body.fileName,
      fileSize: req.body.fileSize,
    };
    
    const result = await generateUploadUrlUseCase.execute(req.uid, input);
    res.status(201).json(result);
  } catch (err) {
    next(err);
  }
}

export async function postFinalizeExam(req: Request, res: Response, next: NextFunction): Promise<void> {
  try {
    const examId = req.params['examId'] as string;
    const { coachAnalysis } = req.body;

    await repo.update(examId, req.uid, { 
      coachAnalysis: coachAnalysis ?? null,
    });

    const exam = await repo.findById(examId, req.uid);
    if (!exam) throw new NotFoundError('Exam');
    
    res.json(exam);
  } catch (err) {
    next(err);
  }
}

export async function getExams(req: Request, res: Response, next: NextFunction): Promise<void> {
  try {
    const limit = Math.min(Number(req.query.limit ?? 20), 50);
    const cursor = req.query.cursor as string | undefined;
    const result = await repo.findByUser(req.uid, limit, cursor);
    res.json(result);
  } catch (err) {
    next(err);
  }
}

export async function deleteExam(req: Request, res: Response, next: NextFunction): Promise<void> {
  try {
    const examId = req.params['examId'] as string;
    await repo.softDelete(examId, req.uid);
    res.status(204).send();
  } catch (err) {
    next(err);
  }
}
