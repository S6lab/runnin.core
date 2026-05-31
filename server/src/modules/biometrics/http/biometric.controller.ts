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
