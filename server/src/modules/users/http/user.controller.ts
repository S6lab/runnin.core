import { Request, Response, NextFunction } from 'express';
import { FirestoreUserRepository } from '../infra/firestore-user.repository';
import { GetProfileUseCase } from '../domain/use-cases/get-profile.use-case';
import { UpsertProfileUseCase, UpsertProfileSchema } from '../domain/use-cases/upsert-profile.use-case';
import { CompleteOnboardingUseCase, CompleteOnboardingSchema } from '../domain/use-cases/complete-onboarding.use-case';
import { ProvisionUserSchema, ProvisionUserUseCase } from '../domain/use-cases/provision-user.use-case';
import { ActivateTrialUseCase } from '../domain/use-cases/activate-trial.use-case';
import { ResetPlanRevisionsQuotaUseCase } from '../domain/use-cases/reset-plan-revisions-quota.use-case';

const repo = new FirestoreUserRepository();
const getProfile = new GetProfileUseCase(repo);
const upsertProfile = new UpsertProfileUseCase(repo);
const completeOnboarding = new CompleteOnboardingUseCase(repo);
const provisionUser = new ProvisionUserUseCase(repo);
const activateTrial = new ActivateTrialUseCase(repo);
const resetPlanRevisionsQuota = new ResetPlanRevisionsQuotaUseCase(repo);

export async function getMe(req: Request, res: Response, next: NextFunction): Promise<void> {
  try {
    const user = await getProfile.execute(req.uid);
    res.json(user);
  } catch (err) {
    next(err);
  }
}

export async function patchMe(req: Request, res: Response, next: NextFunction): Promise<void> {
  try {
    const input = UpsertProfileSchema.parse(req.body);
    const user = await upsertProfile.execute(req.uid, input);
    res.json(user);
  } catch (err) {
    next(err);
  }
}

/**
 * DELETE /users/me — exclui a conta do user requisitante.
 *  - Apaga subcollections (plans, runs, biometrics, devices, etc).
 *  - Apaga o doc do user em users/{uid}.
 *  - Apaga o user Firebase Auth (deleteUser).
 * Tudo é irreversível. Sem dialog de segundo fator aqui (frontend já
 * exige confirmação dupla via dialog).
 */
export async function deleteMe(req: Request, res: Response, next: NextFunction): Promise<void> {
  try {
    const uid = req.uid;
    const { getAuth, getFirestore } = await import('@shared/infra/firebase/firebase.client');
    const auth = getAuth();
    const db = getFirestore();

    const userScopedCols = [
      'plans',
      'runs',
      'biometric_samples',
      'period-analysis',
      'rag_chunks',
      'devices',
      'onboarding_history',
      'exams',
    ];
    let batch = db.batch();
    let opsInBatch = 0;
    const commitIfNeeded = async () => {
      if (opsInBatch >= 400) {
        await batch.commit();
        batch = db.batch();
        opsInBatch = 0;
      }
    };
    for (const col of userScopedCols) {
      const snap = await db.collection(`users/${uid}/${col}`).get();
      for (const d of snap.docs) {
        if (col === 'runs') {
          const subCols = ['gps_points', 'coach_messages', 'reports'];
          for (const sc of subCols) {
            const subSnap = await d.ref.collection(sc).get();
            for (const sd of subSnap.docs) {
              batch.delete(sd.ref);
              opsInBatch++;
              await commitIfNeeded();
            }
          }
        }
        batch.delete(d.ref);
        opsInBatch++;
        await commitIfNeeded();
      }
    }
    // doc raiz do user
    batch.delete(db.collection('users').doc(uid));
    opsInBatch++;
    if (opsInBatch > 0) await batch.commit();

    // Auth user — IRREVERSÍVEL
    try {
      await auth.deleteUser(uid);
    } catch (_) {
      // Se já estiver deletado, ignora — Firestore foi limpo.
    }

    res.status(204).send();
  } catch (err) {
    next(err);
  }
}

export async function postOnboarding(req: Request, res: Response, next: NextFunction): Promise<void> {
  try {
    const input = CompleteOnboardingSchema.parse(req.body);
    const result = await completeOnboarding.execute(req.uid, input);
    res.status(201).json(result);
  } catch (err) {
    next(err);
  }
}

export async function postProvision(req: Request, res: Response, next: NextFunction): Promise<void> {
  try {
    const input = ProvisionUserSchema.parse(req.body ?? {});
    const user = await provisionUser.execute(req.uid, input);
    res.status(201).json(user);
  } catch (err) {
    next(err);
  }
}

export async function postActivateTrial(req: Request, res: Response, next: NextFunction): Promise<void> {
  try {
    const user = await activateTrial.execute(req.uid);
    res.json(user);
  } catch (err) {
    next(err);
  }
}

export async function postResetPlanRevisionsQuota(_req: Request, res: Response): Promise<void> {
  const result = await resetPlanRevisionsQuota.execute();
  res.json(result);
}
