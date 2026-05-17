import { z } from 'zod';
import { RunRepository } from '@modules/runs/domain/run.repository';
import { Run } from '@modules/runs/domain/run.entity';
import { NotFoundError } from '@shared/errors/app-error';
import { BenchmarkRepository } from '@modules/benchmark/domain/benchmark.repository';
import { FirestoreUserRepository } from '@modules/users/infra/firestore-user.repository';
import { GetProfileUseCase } from '@modules/users/domain/use-cases/get-profile.use-case';

export const CompleteRunSchema = z.object({
  distanceM: z.number().nonnegative(),
  durationS: z.number().nonnegative(),
  avgBpm: z.number().optional(),
  maxBpm: z.number().optional(),
});

export type CompleteRunInput = z.infer<typeof CompleteRunSchema>;

function formatPace(distanceM: number, durationS: number): string {
  if (distanceM <= 0) return '--:--';
  const paceSecPerKm = (durationS / distanceM) * 1000;
  const min = Math.floor(paceSecPerKm / 60);
  const sec = Math.round(paceSecPerKm % 60);
  return `${min}:${sec.toString().padStart(2, '0')}`;
}

function calcXp(distanceM: number, durationS: number): number {
  if (distanceM <= 0) return 0;
  const km = distanceM / 1000;
  const minutes = durationS / 60;
  return Math.round(km * 10 + minutes * 0.5);
}

/**
 * Calorias estimadas (kcal) baseadas em MET × peso(kg) × tempo(h).
 * MET escalonado por pace (Compendium of Physical Activities, Ainsworth):
 *  - >7:30/km → 6.0 (caminhada rápida / trote leve)
 *  - 6-7:30   → 9.0 (corrida easy)
 *  - 5-6      → 11.0 (corrida moderada)
 *  - 4:30-5   → 12.5 (tempo run)
 *  - <4:30    → 14.0+ (intervalado / fast)
 * Sem peso (perfil incompleto) usa 70kg como média genérica.
 */
function calcCalories(distanceM: number, durationS: number, weightKg: number): number {
  if (distanceM <= 0 || durationS <= 0) return 0;
  const km = distanceM / 1000;
  const minutes = durationS / 60;
  const paceMinPerKm = minutes / km;
  let met: number;
  if (paceMinPerKm > 7.5) met = 6.0;
  else if (paceMinPerKm > 6.0) met = 9.0;
  else if (paceMinPerKm > 5.0) met = 11.0;
  else if (paceMinPerKm > 4.5) met = 12.5;
  else met = 14.0;
  const hours = durationS / 3600;
  return Math.round(met * weightKg * hours);
}

function parseWeightKg(raw: string | undefined): number {
  if (!raw) return 70; // fallback genérico
  const n = Number(raw.replace(/[^0-9.]/g, ''));
  if (!Number.isFinite(n) || n <= 0) return 70;
  return n;
}

export class CompleteRunUseCase {
  constructor(
    private readonly runRepo: RunRepository,
    private readonly benchmarkRepo?: BenchmarkRepository,
  ) {}

  async execute(runId: string, userId: string, input: CompleteRunInput): Promise<Run> {
    const run = await this.runRepo.findById(runId, userId);
    if (!run) throw new NotFoundError('Run');

    // Busca peso do perfil pra calcular calorias com precisão real.
    // Sem peso, usa fallback 70kg.
    let weightKg = 70;
    try {
      const userRepo = new FirestoreUserRepository();
      const getProfileUC = new GetProfileUseCase(userRepo);
      const profile = await getProfileUC.execute(userId);
      weightKg = parseWeightKg(profile?.weight);
    } catch (_) {/* mantém fallback 70kg */}

    const updates: Partial<Run> = {
      status: 'completed',
      distanceM: input.distanceM,
      durationS: input.durationS,
      avgPace: formatPace(input.distanceM, input.durationS),
      avgBpm: input.avgBpm,
      maxBpm: input.maxBpm,
      calories: calcCalories(input.distanceM, input.durationS, weightKg),
      xpEarned: calcXp(input.distanceM, input.durationS),
      completedAt: new Date().toISOString(),
    };

    await this.runRepo.update(runId, userId, updates);

    if (this.benchmarkRepo) {
      try {
        await this.triggerBenchmarkUpdate(runId, userId, updates);
      } catch (err) {
        console.warn('Failed to trigger benchmark update:', err instanceof Error ? err.message : String(err));
      }
    }

    return { ...run, ...updates };
  }

  private async triggerBenchmarkUpdate(runId: string, userId: string, updates: Partial<Run>): Promise<void> {
    const userRepo = new FirestoreUserRepository();
    const getProfileUseCase = new GetProfileUseCase(userRepo);
    
    try {
      const profile = await getProfileUseCase.execute(userId);
      if (!profile) {
        console.warn(`User profile not found: ${userId}`);
        return;
      }

      const distanceM = updates.distanceM!;
      if (!distanceM) return;

      const level = profile.level || 'intermediario';
      const distanceKm = Math.round(distanceM / 1000);
      const runType = updates.type || 'easy_run';

      await this.benchmarkRepo!.createOrIncrementAggregate(level, runType, `${distanceKm}km`);
      await this.benchmarkRepo!.addMetricToAggregate(level, runType, `${distanceKm}km`, 'paceAvgs', this.parsePace(updates.avgPace) ?? 300);
      await this.benchmarkRepo!.addMetricToAggregate(level, runType, `${distanceKm}km`, 'bpmAvgs', updates.avgBpm ?? 0);
      await this.benchmarkRepo!.addMetricToAggregate(level, runType, `${distanceKm}km`, 'distAvgs', distanceM);
    } catch (err) {
      console.warn('Failed to trigger benchmark update:', err instanceof Error ? err.message : String(err));
    }
  }

  private parsePace(paceStr?: string): number | undefined {
    if (!paceStr) return undefined;
    try {
      const [min, sec] = paceStr.split(':').map(Number);
      if (min === undefined || sec === undefined) return undefined;
      return min + sec / 60;
    } catch (_) {
      return undefined;
    }
  }
}
