import { Request, Response, NextFunction } from 'express';
import { z } from 'zod';
import { FirestoreNotificationRepository } from '../infra/firestore-notification.repository';
import { FirestoreUserRepository } from '@modules/users/infra/firestore-user.repository';
import { FirestorePlanRepository } from '@modules/plans/infra/firestore-plan.repository';
import { FirestoreRunRepository } from '@modules/runs/infra/firestore-run.repository';
import { FirestoreDeviceRepository } from '../infra/firestore-device.repository';
import { ListNotificationsUseCase } from '../domain/use-cases/list-notifications.use-case';
import { DismissNotificationUseCase } from '../domain/use-cases/dismiss-notification.use-case';
import { ClearNotificationsUseCase } from '../domain/use-cases/clear-notifications.use-case';
import { MarkReadUseCase } from '../domain/use-cases/mark-read.use-case';
import { CreateNotificationUseCase } from '../domain/use-cases/create-notification.use-case';
import { EnsureDailyInsightsUseCase } from '../domain/use-cases/ensure-daily-insights.use-case';
import { SendDailyPushUseCase } from '../domain/use-cases/send-daily-push.use-case';
import { container } from '@shared/container';
import { logger } from '@shared/logger/logger';

const repo = new FirestoreNotificationRepository();
const userRepo = new FirestoreUserRepository();
const planRepo = new FirestorePlanRepository();
const runRepo = new FirestoreRunRepository();
const deviceRepo = new FirestoreDeviceRepository();
const create = new CreateNotificationUseCase(repo);

const listUseCase = new ListNotificationsUseCase(repo);
const dismissUseCase = new DismissNotificationUseCase(repo);
const clearUseCase = new ClearNotificationsUseCase(repo);
const markReadUseCase = new MarkReadUseCase(repo);
const ensureDaily = new EnsureDailyInsightsUseCase(
  create,
  userRepo,
  planRepo,
  runRepo,
  repo,
  container.useCases.getUserFeatures,
);
const dailyPush = new SendDailyPushUseCase(userRepo, planRepo, container.useCases.getUserFeatures);

// Cache em memória do último ensureDaily por uid pra evitar rodar 100x num
// burst de abertura/refresh do painel. TTL 6h (cron diário roda 1x/dia +
// painel pode chamar várias vezes a cada navegação).
const _lastEnsuredAt = new Map<string, number>();
const _ENSURE_CACHE_TTL_MS = 6 * 60 * 60 * 1000;

export async function listNotifications(req: Request, res: Response, next: NextFunction): Promise<void> {
  try {
    const cursor = typeof req.query['cursor'] === 'string' ? req.query['cursor'] : undefined;
    const limitRaw = typeof req.query['limit'] === 'string' ? Number(req.query['limit']) : undefined;
    const limit = Number.isFinite(limitRaw) && limitRaw! > 0 ? limitRaw : undefined;

    // ensureDaily só na primeira página — em loadMore não faz sentido
    // recriar os insights diários (e atrasaria a paginação).
    if (!cursor) {
      const lastAt = _lastEnsuredAt.get(req.uid) ?? 0;
      const ageMs = Date.now() - lastAt;
      if (ageMs > _ENSURE_CACHE_TTL_MS) {
        try {
          await ensureDaily.execute(req.uid);
          _lastEnsuredAt.set(req.uid, Date.now());
        } catch (err) {
          logger.warn('notifications.ensure_daily_failed', { uid: req.uid, err: String(err) });
        }
      }
    }
    const result = await listUseCase.execute(req.uid, { before: cursor, limit });
    res.json({ items: result.items, nextCursor: result.nextCursor });
  } catch (err) {
    next(err);
  }
}

export async function dismissNotification(req: Request, res: Response, next: NextFunction): Promise<void> {
  try {
    await dismissUseCase.execute(req.uid, req.params['id'] as string);
    res.status(204).send();
  } catch (err) {
    next(err);
  }
}

export async function clearNotifications(req: Request, res: Response, next: NextFunction): Promise<void> {
  try {
    const result = await clearUseCase.execute(req.uid);
    res.json(result);
  } catch (err) {
    next(err);
  }
}

export async function markRead(req: Request, res: Response, next: NextFunction): Promise<void> {
  try {
    await markReadUseCase.execute(req.uid, req.params['id'] as string);
    res.status(204).send();
  } catch (err) {
    next(err);
  }
}

const RegisterDeviceSchema = z.object({
  token: z.string().min(20),
  platform: z.enum(['ios', 'android', 'web', 'unknown']).optional().default('unknown'),
});

export async function registerDevice(req: Request, res: Response, next: NextFunction): Promise<void> {
  try {
    const { token, platform } = RegisterDeviceSchema.parse(req.body);
    await deviceRepo.upsert(req.uid, token, platform);
    res.json({ ok: true });
  } catch (err) {
    next(err);
  }
}

export async function ensureDailyNotifications(req: Request, res: Response, next: NextFunction): Promise<void> {
  try {
    const batchSize = 100;
    let cursor: string | undefined;
    let processedCount = 0;
    
    while (true) {
      const users = cursor ? await userRepo.list(batchSize) : await userRepo.list(batchSize);
      
      if (users.length === 0) {
        break;
      }
      
      const promises = users.map(async user => {
        await ensureDaily.execute(user.id).catch(err => {
          logger.warn('notifications.ensure_daily_user_failed', { uid: user.id, err: String(err) });
        });
        await dailyPush.executeForUser(user.id).catch(err => {
          logger.warn('notifications.daily_push_failed', { uid: user.id, err: String(err) });
        });
        // Se o user tinha sessão planejada ontem e não rodou, IA realoca a
        // carga perdida nas próximas sessões. No-op pra quem está em dia.
        await container.useCases.adaptPlan.executeMissedDay(user.id).catch(err => {
          logger.warn('notifications.adapt_missed_day_failed', { uid: user.id, err: String(err) });
        });
      });

      await Promise.all(promises);
      processedCount += users.length;
      
      if (users.length < batchSize) {
        break;
      }
      
      cursor = users[users.length - 1].id;
    }
    
    logger.info('notifications.ensure_daily_complete', { count: processedCount });
    res.json({ processed: processedCount });
  } catch (err) {
    next(err);
  }
}
