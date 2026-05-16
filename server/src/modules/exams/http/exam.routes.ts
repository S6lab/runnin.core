import { Router } from 'express';
import { authMiddleware } from '@shared/infra/http/middlewares/auth.middleware';
import { postGenerateUploadUrl, postFinalizeExam, getExams, deleteExam } from './exam.controller';

export const examRouter = Router();

examRouter.use(authMiddleware);
examRouter.post('/upload-url', postGenerateUploadUrl);
examRouter.post('/:examId/finalize', postFinalizeExam);
examRouter.get('/', getExams);
examRouter.delete('/:examId', deleteExam);
