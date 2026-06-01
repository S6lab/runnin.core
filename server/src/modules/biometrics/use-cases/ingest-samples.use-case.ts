import { v4 as uuid } from 'uuid';
import { z } from 'zod';
import {
  BiometricSample,
  BiometricSampleType,
  BiometricSource,
} from '../domain/biometric-sample.entity';
import { BiometricSampleRepository } from '../domain/biometric-sample.repository';
import { UserRepository } from '@modules/users/domain/user.repository';
import { logger } from '@shared/logger/logger';

const SampleInputSchema = z.object({
  type: z.enum([
    'bpm',
    'resting_bpm',
    'max_bpm',
    'hrv',
    'sleep_hours',
    'sleep_deep',
    'steps',
    'spo2',
    'weight',
    'calories_burned',
    'vo2max',
    'respiratory_rate',
  ]),
  value: z.number().finite(),
  unit: z.string().min(1),
  source: z.enum([
    'apple_health',
    'health_connect',
    'garmin',
    'polar',
    'fitbit',
    'whoop',
    'manual',
    'terra',
    'seed',
  ]),
  recordedAt: z.string(),
  context: z.record(z.string(), z.unknown()).optional(),
});

export const IngestSamplesSchema = z.object({
  samples: z.array(SampleInputSchema).min(1).max(500),
});

export type IngestSamplesInput = z.infer<typeof IngestSamplesSchema>;

export class IngestSamplesUseCase {
  constructor(
    private readonly repo: BiometricSampleRepository,
    private readonly userRepo: UserRepository,
  ) {}

  async execute(
    userId: string,
    input: IngestSamplesInput,
  ): Promise<{ received: number; saved: number }> {
    const now = new Date().toISOString();
    const samples: BiometricSample[] = input.samples.map((s) => ({
      id: uuid(),
      userId,
      type: s.type as BiometricSampleType,
      value: s.value,
      unit: s.unit,
      source: s.source as BiometricSource,
      recordedAt: s.recordedAt,
      receivedAt: now,
      context: s.context,
    }));
    const result = await this.repo.saveBatch(samples);
    await this.promoteToProfile(userId, samples);
    return { received: samples.length, saved: result.saved };
  }

  /**
   * Promove os samples relevantes pra campos do perfil que outras telas leem
   * (profile_page mostra restingBpm/maxBpm, zonas Karvonen dependem dos dois).
   * Sem isso, o user sincroniza Apple Health, o ícone fica verde, mas o
   * perfil/ajustes/BPM continuam exibindo o valor manual antigo.
   *
   * Estratégia: pega o sample MAIS RECENTE do batch por tipo. Se for mais
   * novo que o "lastBpmUpdateAt" já registrado, atualiza. Roda em try/catch
   * separado pra que falha na promotion nunca quebre o ingest.
   */
  private async promoteToProfile(userId: string, samples: BiometricSample[]): Promise<void> {
    const latestByType = (type: BiometricSampleType): BiometricSample | undefined =>
      samples
        .filter((s) => s.type === type)
        .reduce<BiometricSample | undefined>(
          (latest, s) =>
            !latest || s.recordedAt > latest.recordedAt ? s : latest,
          undefined,
        );

    const restingSample = latestByType('resting_bpm');
    const maxSample = latestByType('max_bpm');
    if (!restingSample && !maxSample) return;

    const patch: { restingBpm?: number; maxBpm?: number } = {};
    if (restingSample) patch.restingBpm = Math.round(restingSample.value);
    if (maxSample) patch.maxBpm = Math.round(maxSample.value);

    try {
      await this.userRepo.updatePartial(userId, patch);
      logger.info('biometrics.profile_promoted', { userId, patch });
    } catch (err) {
      logger.warn('biometrics.profile_promotion_failed', {
        userId,
        err: err instanceof Error ? err.message : String(err),
      });
    }
  }
}
