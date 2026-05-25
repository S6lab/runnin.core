import { Router } from 'express';
import { authMiddleware } from '@shared/infra/http/middlewares/auth.middleware';
import { getCurrentWeatherHandler } from './weather.controller';

export const weatherRouter = Router();

weatherRouter.use(authMiddleware);
weatherRouter.get('/current', getCurrentWeatherHandler);
