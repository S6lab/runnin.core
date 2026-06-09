import { Request, Response, NextFunction } from 'express';
import { getAuth } from '@shared/infra/firebase/firebase.client';
import { container } from '@shared/container';
import { IngestSamplesSchema } from '../use-cases/ingest-samples.use-case';
import { BiometricSampleType } from '../domain/biometric-sample.entity';

export async function postIngestSamples(
  req: Request,
  res: Response,
  next: NextFunction,
): Promise<void> {
  try {
    const input = IngestSamplesSchema.parse(req.body);
    const result = await container.useCases.ingestBiometricSamples.execute(
      req.uid,
      input,
    );
    res.status(201).json(result);
  } catch (err) {
    next(err);
  }
}

/**
 * POST /v1/biometrics/sync-ping — heartbeat de abertura do app.
 * Chamado UNCONDICIONALMENTE pelo Home bootstrap, antes de qualquer
 * gate. Permite distinguir nos logs:
 *  - Ping sim, telemetry não → syncSince morre em algum lugar
 *  - Ping não → user não abriu Home OU app sem conectividade
 *  - Ping + telemetry → flow rodou, dá pra ver byType counts
 */
export async function postSyncPing(
  req: Request,
  _res: Response,
  next: NextFunction,
): Promise<void> {
  try {
    const { logger } = await import('@shared/logger/logger');
    logger.info('wearable.sync.ping', {
      uid: req.uid,
      tfHint: (req.body as { tf?: string })?.tf,
      platform: (req.body as { platform?: string })?.platform,
    });
    _res.status(204).end();
  } catch (err) {
    next(err);
  }
}

/**
 * POST /v1/biometrics/sync-telemetry — diagnóstico de sync.
 * Recebe metadata sobre uma chamada syncSince (window, counts) e loga.
 * Permite ver em produção se o plugin está retornando 0 samples
 * mesmo com HK populado.
 */
export async function postSyncTelemetry(
  req: Request,
  res: Response,
  next: NextFunction,
): Promise<void> {
  try {
    const body = req.body as {
      fromIso?: string;
      toIso?: string;
      hkFetchedTotal?: number;
      mappedTotal?: number;
      byType?: Record<string, number>;
      mappedByType?: Record<string, number>;
      lastSyncIso?: string | null;
      errorMsg?: string;
    };
    // eslint-disable-next-line @typescript-eslint/no-var-requires
    const { logger } = await import('@shared/logger/logger');
    logger.info('wearable.sync.telemetry', {
      uid: req.uid,
      fromIso: body.fromIso,
      toIso: body.toIso,
      lastSyncIso: body.lastSyncIso ?? null,
      hkFetchedTotal: body.hkFetchedTotal ?? 0,
      mappedTotal: body.mappedTotal ?? 0,
      byType: body.byType ?? {},
      mappedByType: body.mappedByType ?? {},
      errorMsg: body.errorMsg ?? null,
    });
    res.status(204).end();
  } catch (err) {
    next(err);
  }
}

export async function getLatestByType(
  req: Request,
  res: Response,
  next: NextFunction,
): Promise<void> {
  try {
    const type = req.params['type'] as BiometricSampleType;
    const sample = await container.repos.biometricSamples.findLatestByType(
      req.uid,
      type,
    );
    if (!sample) {
      res.status(404).json({ error: 'not_found', code: 'NO_SAMPLES' });
      return;
    }
    res.json(sample);
  } catch (err) {
    next(err);
  }
}

export async function getSummary(
  req: Request,
  res: Response,
  next: NextFunction,
): Promise<void> {
  try {
    const windowDays = Math.min(
      Math.max(Number(req.query['windowDays'] ?? 7), 1),
      90,
    );
    const summary = await container.useCases.getBiometricSummary.execute(
      req.uid,
      windowDays,
    );
    res.json(summary);
  } catch (err) {
    next(err);
  }
}

/**
 * POST /v1/biometrics/seed-test-user — admin only.
 *
 * Body: { email: 'nalin@s6lab.com' }  (ou usa default)
 * Resolve o uid do Firebase Auth pelo email, seeda 7d de dados realistas.
 */
export async function postSeedTestUser(
  req: Request,
  res: Response,
  next: NextFunction,
): Promise<void> {
  try {
    const email = (req.body?.email as string | undefined) ?? 'nalin@s6lab.com';
    const user = await getAuth().getUserByEmail(email);
    const result = await container.useCases.seedBiometricTestUser.execute(user.uid);
    res.json({ ok: true, email, uid: user.uid, ...result });
  } catch (err) {
    next(err);
  }
}
