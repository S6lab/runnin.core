import { Router } from 'express';
import { authMiddleware } from '@shared/infra/http/middlewares/auth.middleware';
import { postUploadUrl, postFinalizeExam, getExams, deleteExamHandler } from './exam.controller';

export const examRouter = Router();

examRouter.use(authMiddleware);
examRouter.post('/upload-url', postUploadUrl);
examRouter.post('/:examId/finalize', postFinalizeExam);
examRouter.get('/', getExams);
examRouter.delete('/:examId', deleteExamHandler);
