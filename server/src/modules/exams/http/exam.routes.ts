import { Router } from 'express';
import { authMiddleware } from '@shared/infra/http/middlewares/auth.middleware';
import { requireFeature } from '@shared/infra/http/middlewares/require-feature.middleware';
import { postGenerateUploadUrl, postFinalizeExam, getExams, deleteExam } from './exam.controller';

export const examRouter = Router();

examRouter.use(authMiddleware);
// GET livre (freemium pode ver lista vazia)
examRouter.get('/', getExams);
// Mutations gated por examsOCR
examRouter.post('/upload-url', requireFeature('examsOCR'), postGenerateUploadUrl);
examRouter.post('/:examId/finalize', requireFeature('examsOCR'), postFinalizeExam);
examRouter.delete('/:examId', requireFeature('examsOCR'), deleteExam);
