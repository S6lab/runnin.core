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
    'sleep_rem',
    'sleep_light',
    'sleep_in_bed',
    'sleep_awake',
    'steps',
    'spo2',
    'weight',
    'calories_burned',
    'calories_basal',
    'vo2max',
    'respiratory_rate',
    'bp_systolic',
    'bp_diastolic',
    'body_temperature',
    'ecg',
    'distance_walking_running',
    'distance_cycling',
    'flights_climbed',
    'exercise_time',
    'apple_move_time',
    'apple_stand_time',
    'walking_speed',
    'walking_bpm',
    'height',
    'body_fat_pct',
    'bmi',
    'lean_body_mass',
    'waist_circumference',
    'hrv_rmssd',
    'high_hr_event',
    'low_hr_event',
    'irregular_hr_event',
    'afib_burden',
    'skin_temperature',
    'water',
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
    // HealthKit/Health Connect NÃO têm "max heart rate" como tipo nativo
    // (max é derivado, não medido). O app só consegue mandar samples de
    // type='bpm' (HEART_RATE — instantâneo durante o dia + workouts).
    // Derivamos profile.maxBpm como o MAIOR sample 'bpm' do batch — isso
    // captura o pico do dia/semana conforme batches chegam. Suficiente
    // pra alimentar zonas Karvonen sem o user precisar editar manualmente.
    const bpmSamples = samples.filter((s) => s.type === 'bpm');
    const peakBpmSample = bpmSamples.reduce<BiometricSample | undefined>(
      (peak, s) => (!peak || s.value > peak.value ? s : peak),
      undefined,
    );
    if (!restingSample && !peakBpmSample) return;

    // Lê profile atual pra comparar com o pico — só sobe nunca desce.
    // Sem essa comparação, batch novo com leitura instantânea baixa (recovery
    // logo após uma sessão dura) sobrescrevia o pico anterior do treino.
    const currentProfile = await this.userRepo.findById(userId);
    const currentMax = currentProfile?.maxBpm ?? 0;

    const patch: { restingBpm?: number; maxBpm?: number } = {};
    if (restingSample) patch.restingBpm = Math.round(restingSample.value);
    // Sanity-clamp do max: 140-220 cobre faixa realista pra adulto. Sample
    // abaixo de 140 é exercício leve/recovery (não pico real); acima de 220
    // é noise/error do device. E só atualiza se for MAIOR que o atual.
    if (
      peakBpmSample &&
      peakBpmSample.value >= 140 &&
      peakBpmSample.value <= 220 &&
      peakBpmSample.value > currentMax
    ) {
      patch.maxBpm = Math.round(peakBpmSample.value);
    }
    if (Object.keys(patch).length === 0) return;

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
