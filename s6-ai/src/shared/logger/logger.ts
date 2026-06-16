import winston from 'winston';
import { recordErrorMetric } from './error-counter';

const { combine, timestamp, json, errors } = winston.format;

export const logger = winston.createLogger({
  level: process.env.LOG_LEVEL ?? 'info',
  format: combine(
    errors({ stack: true }),
    timestamp(),
    json(),
  ),
  // Era 'runnin-api' (copiado) — poluía filtros de log por serviço.
  defaultMeta: { service: 's6-ai' },
  transports: [new winston.transports.Console()],
});

// Todo logger.error alimenta o contador diário consultável
// (system/errors/daily — aba TECH do admin). Best-effort, não bloqueia.
const _origError = logger.error.bind(logger);
logger.error = ((message: unknown, ...meta: unknown[]) => {
  recordErrorMetric(typeof message === 'string' ? message : String(message));
  return _origError(message as string, ...(meta as object[]));
}) as typeof logger.error;
