import { Request, Response, NextFunction } from 'express';
import { ZodError } from 'zod';
import { AppError } from '@shared/errors/app-error';
import { logger } from '@shared/logger/logger';

export function errorMiddleware(err: unknown, req: Request, res: Response, _next: NextFunction): void {
  if (err instanceof ZodError) {
    res.status(422).json({
      error: { code: 'VALIDATION_ERROR', message: 'Invalid request data', details: err.issues },
    });
    return;
  }

  if (err instanceof AppError) {
    if (err.statusCode >= 500) {
      logger.error(err.message, { requestId: req.id, stack: err.stack });
    }
    res.status(err.statusCode).json({ error: { code: err.code, message: err.message } });
    return;
  }

  const asError = err instanceof Error ? err : undefined;
  const msg = asError?.message ?? String(err);

  // Gemini API rate limit (429): tratar como 503 amigável ao caller
  if (msg.includes('429') || msg.toLowerCase().includes('quota') || msg.toLowerCase().includes('rate limit')) {
    logger.warn('llm.rate_limited', { requestId: req.id, errorMessage: msg.slice(0, 200) });
    res.status(503).json({
      error: {
        code: 'LLM_RATE_LIMITED',
        message: 'Serviço de IA sobrecarregado. Tente novamente em alguns segundos.',
        retryAfterSeconds: 60,
      },
    });
    return;
  }

  logger.error('Unhandled error', {
    requestId: req.id,
    errorMessage: msg,
    errorName: asError?.name,
    stack: asError?.stack,
  });
  res.status(500).json({ error: { code: 'INTERNAL_ERROR', message: 'Internal server error' } });
}
