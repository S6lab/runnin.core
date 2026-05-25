import { z } from 'zod';
import { RunRepository } from '@modules/runs/domain/run.repository';
import { Run, KmSplit } from '@modules/runs/domain/run.entity';
import { NotFoundError } from '@shared/errors/app-error';
import { FirestoreUserRepository } from '@modules/users/infra/firestore-user.repository';
import { GetProfileUseCase } from '@modules/users/domain/use-cases/get-profile.use-case';
import { FirestorePlanRepository } from '@modules/plans/infra/firestore-plan.repository';
import { logger } from '@shared/logger/logger';

const KmSplitInputSchema = z.object({
  kmIndex: z.number().int().nonnegative(),
  durationS: z.number().nonnegative(),
  avgPaceMinKm: z.string(),
  avgBpm: z.number().optional(),
  elevationGain: z.number().optional(),
});

export const CompleteRunSchema = z.object({
  distanceM: z.number().nonnegative(),
  durationS: z.number().nonnegative(),
  avgBpm: z.number().optional(),
  maxBpm: z.number().optional(),
  /** Splits por km computados no app a partir dos GPS points. Server enriquece
   *  cada split com `calories` (MET escalonado por pace × peso × tempo do km)
   *  antes de persistir. */
  splits: z.array(KmSplitInputSchema).optional(),
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

    // Enriquece cada split com calorias usando o MET escalonado por pace do
    // próprio km (não da run inteira). Persistir splits permite que a hist
    // renderize métricas km-a-km sem precisar reabrir o GPS bruto.
    const enrichedSplits: KmSplit[] | undefined = input.splits?.map(s => {
      const base: KmSplit = {
        kmIndex: s.kmIndex,
        durationS: s.durationS,
        avgPaceMinKm: s.avgPaceMinKm,
        calories: calcCalories(1000, s.durationS, weightKg),
      };
      if (typeof s.avgBpm === 'number') base.avgBpm = s.avgBpm;
      if (typeof s.elevationGain === 'number') base.elevationGain = s.elevationGain;
      return base;
    });

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
      ...(enrichedSplits && enrichedSplits.length > 0 ? { splits: enrichedSplits } : {}),
    };

    await this.runRepo.update(runId, userId, updates);

    // Marca a sessão do plano como executada quando a run carrega um
    // planSessionId. Permite o app destacar a sessão "feita" na agenda
    // e avisar o user antes de re-executar (sobrescreveria).
    if (run.planSessionId) {
      try {
        await this.flagPlanSessionExecuted(userId, run.planSessionId, runId);
      } catch (err) {
        logger.warn('plan.session.flag_executed_failed', {
          runId, planSessionId: run.planSessionId, err: String(err),
        });
      }
    }

    return { ...run, ...updates };
  }

  /**
   * Encontra a sessão `planSessionId` no plano atual do user e seta
   * `executedRunId` + `executedAt`. Idempotente: re-executar uma sessão
   * sobrescreve o ID anterior (cliente deve avisar antes de chamar).
   */
  private async flagPlanSessionExecuted(
    userId: string,
    planSessionId: string,
    runId: string,
  ): Promise<void> {
    const planRepo = new FirestorePlanRepository();
    const plan = await planRepo.findCurrent(userId);
    if (!plan) return;
    let touched = false;
    const updatedWeeks = plan.weeks.map(w => ({
      ...w,
      sessions: w.sessions.map(s => {
        if (s.id !== planSessionId) return s;
        touched = true;
        return { ...s, executedRunId: runId, executedAt: new Date().toISOString() };
      }),
    }));
    if (!touched) return;
    await planRepo.update(plan.id, userId, { weeks: updatedWeeks });
    logger.info('plan.session.flagged_executed', { planSessionId, runId, planId: plan.id });
  }

}
