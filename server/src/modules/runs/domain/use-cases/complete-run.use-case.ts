import { z } from 'zod';
import { RunRepository } from '@modules/runs/domain/run.repository';
import { Run, KmSplit } from '@modules/runs/domain/run.entity';
import { NotFoundError } from '@shared/errors/app-error';
import { FirestoreUserRepository } from '@modules/users/infra/firestore-user.repository';
import { GetProfileUseCase } from '@modules/users/domain/use-cases/get-profile.use-case';
import { parseWeightKg } from '@modules/users/domain/user-metrics';
import { FirestorePlanRepository } from '@modules/plans/infra/firestore-plan.repository';
import { effectivePlanWeeks } from '@modules/plans/domain/plan.entity';
import { logger } from '@shared/logger/logger';
import { EvaluateBadgesUseCase } from '@modules/badges/use-cases/evaluate-badges.use-case';
import { FirestoreBadgeRepository } from '@modules/badges/infra/firestore-badge.repository';
import { SendUserPushUseCase } from '@modules/notifications/domain/use-cases/send-user-push.use-case';

const KmSplitInputSchema = z.object({
  kmIndex: z.number().int().nonnegative(),
  durationS: z.number().nonnegative(),
  avgPaceMinKm: z.string(),
  avgBpm: z.number().optional(),
  /** TF 75 Fase 10: BPM máximo do split (pico). Cliente reporta. */
  maxBpm: z.number().optional(),
  elevationGain: z.number().optional(),
  /** Perda de elevação (m) do km — histerese 3m, espelho do ganho. */
  elevationLoss: z.number().optional(),
  /** Distância real do split (m). Opcional — splits de 1km completo omitem.
   *  Splits parciais (tail < 1km) enviam o leftover real pra calorias
   *  serem calculadas proporcionalmente. */
  distanceM: z.number().positive().optional(),
  /** Marca o split como parcial (tail da corrida). Renderizado com '~' na UI. */
  isPartial: z.boolean().optional(),
});

const TelemetryPointSchema = z.object({
  tMs: z.number().int().nonnegative(),
  distM: z.number().nonnegative(),
  bpm: z.number().int().optional(),
  paceSec: z.number().int().optional(),
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
  /** Telemetria sincronizada {bpm, pace, dist} a cada 30s. Opcional — runs
   *  antigas ou cliente legacy pode não enviar. */
  telemetryTimeline: z.array(TelemetryPointSchema).max(1500).optional(),
});

export type CompleteRunInput = z.infer<typeof CompleteRunSchema>;

export type AssessmentEffortLabel = 'confortavel' | 'moderado' | 'forte' | 'maximo';

export interface AssessmentEffort {
  /** % da reserva de FC (Karvonen) do esforço médio. Null sem FC/perfil. */
  pctHrr: number | null;
  /** Drift cardíaco Pa:Hr (1ª vs 2ª metade dos splits): FC subindo com o
   *  mesmo pace = esforço insustentável. Null com <2 splits ou sem FC. */
  cardiacDriftPct: number | null;
  effortLabel: AssessmentEffortLabel | null;
  /** Pace base (easy) estimado a partir do medido + esforço. Igual ao
   *  medido quando o esforço foi confortável. */
  easyPaceMinKm: string | null;
}

/**
 * Anti-gaming da avaliação: iniciante que "entrega a vida" em 2km pra
 * cravar um pace bom é detectado pela FC — %HRR alto + drift cardíaco
 * denunciam esforço de prova, não capacidade confortável. O pace BASE do
 * plano é derivado do esforço, não do número cru.
 */
function classifyAssessmentEffort(opts: {
  avgBpm?: number;
  restingBpm?: number;
  maxBpm?: number;
  paceMinKm: string;
  splits?: CompleteRunInput['splits'];
}): AssessmentEffort {
  const { avgBpm, restingBpm, maxBpm } = opts;
  let pctHrr: number | null = null;
  if (
    typeof avgBpm === 'number' && avgBpm > 0 &&
    typeof restingBpm === 'number' && restingBpm > 0 &&
    typeof maxBpm === 'number' && maxBpm > restingBpm
  ) {
    pctHrr = Math.round(((avgBpm - restingBpm) / (maxBpm - restingBpm)) * 100);
    pctHrr = Math.max(0, Math.min(120, pctHrr));
  }

  // Pa:Hr decoupling: ratio velocidade/FC da 1ª metade vs 2ª metade dos
  // splits. >5% = aeróbico não sustenta o pace (Maffetone usa esse corte).
  let cardiacDriftPct: number | null = null;
  const splits = (opts.splits ?? []).filter(
    (s) => typeof s.avgBpm === 'number' && s.avgBpm > 0 && s.durationS > 0,
  );
  if (splits.length >= 2) {
    const mid = Math.floor(splits.length / 2);
    const ratioOf = (part: typeof splits) => {
      const speed = part.reduce((a, s) => {
        const dist = typeof s.distanceM === 'number' ? s.distanceM : 1000;
        return a + dist / s.durationS;
      }, 0) / part.length;
      const hr = part.reduce((a, s) => a + (s.avgBpm ?? 0), 0) / part.length;
      return hr > 0 ? speed / hr : null;
    };
    const r1 = ratioOf(splits.slice(0, mid));
    const r2 = ratioOf(splits.slice(mid));
    if (r1 != null && r2 != null && r2 > 0) {
      cardiacDriftPct = Math.round(((r1 / r2) - 1) * 1000) / 10;
    }
  }

  let effortLabel: AssessmentEffortLabel | null = null;
  if (pctHrr != null) {
    effortLabel = pctHrr >= 85 ? 'maximo'
      : pctHrr >= 75 ? 'forte'
      : pctHrr >= 65 ? 'moderado'
      : 'confortavel';
    // Drift alto promove o label: pace caiu OU FC subiu pra sustentar —
    // mesmo com %HRR médio "ok", o esforço não era confortável.
    if (cardiacDriftPct != null && cardiacDriftPct > 8 && effortLabel === 'confortavel') {
      effortLabel = 'moderado';
    }
  }

  // Easy pace estimado: offset conservador sobre o medido por banda de
  // esforço (~75s pra all-out ≈ diferença pace de prova 5K vs easy).
  let easyPaceMinKm: string | null = null;
  const paceMatch = /^(\d{1,2}):(\d{2})$/.exec(opts.paceMinKm);
  if (paceMatch && effortLabel != null) {
    const baseSec = parseInt(paceMatch[1]!, 10) * 60 + parseInt(paceMatch[2]!, 10);
    const offset = effortLabel === 'maximo' ? 75
      : effortLabel === 'forte' ? 45
      : effortLabel === 'moderado' ? 20
      : 0;
    const easySec = baseSec + offset;
    easyPaceMinKm = `${Math.floor(easySec / 60)}:${(easySec % 60).toString().padStart(2, '0')}`;
  }

  return { pctHrr, cardiacDriftPct, effortLabel, easyPaceMinKm };
}

function formatPace(distanceM: number, durationS: number): string {
  if (distanceM <= 0) return '--:--';
  const paceSecPerKm = (durationS / distanceM) * 1000;
  // Total arredondado ANTES de separar (round(%60)→60 gerava "5:60").
  const total = Math.round(paceSecPerKm);
  const min = Math.floor(total / 60);
  const sec = total % 60;
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

export class CompleteRunUseCase {
  constructor(
    private readonly runRepo: RunRepository,
  ) {}

  async execute(
    runId: string,
    userId: string,
    input: CompleteRunInput,
  ): Promise<{ run: Run; unlockedBadges: import('@modules/badges/domain/badge.entity').Badge[] }> {
    const run = await this.runRepo.findById(runId, userId);
    if (!run) throw new NotFoundError('Run');

    // Busca peso do perfil pra calcular calorias com precisão real.
    // Sem peso, usa fallback 70kg. resting/max BPM alimentam a
    // classificação de esforço da avaliação (Karvonen).
    let weightKg = 70;
    let profileRestingBpm: number | undefined;
    let profileMaxBpm: number | undefined;
    try {
      const userRepo = new FirestoreUserRepository();
      const getProfileUC = new GetProfileUseCase(userRepo);
      const profile = await getProfileUC.execute(userId);
      weightKg = parseWeightKg(profile?.weight) ?? 70;
      profileRestingBpm = profile?.restingBpm;
      profileMaxBpm = profile?.maxBpm;
    } catch (_) {/* mantém fallback 70kg */}

    // Enriquece cada split com calorias usando o MET escalonado por pace do
    // próprio km (não da run inteira). Persistir splits permite que a hist
    // renderize métricas km-a-km sem precisar reabrir o GPS bruto.
    const enrichedSplits: KmSplit[] | undefined = input.splits?.map(s => {
      // Splits completos: 1000m. Parciais: usa distanceM real do tail.
      const splitDistM = typeof s.distanceM === 'number' ? s.distanceM : 1000;
      const base: KmSplit = {
        kmIndex: s.kmIndex,
        durationS: s.durationS,
        avgPaceMinKm: s.avgPaceMinKm,
        calories: calcCalories(splitDistM, s.durationS, weightKg),
      };
      if (typeof s.avgBpm === 'number') base.avgBpm = s.avgBpm;
      if (typeof s.maxBpm === 'number') base.maxBpm = s.maxBpm;
      if (typeof s.elevationGain === 'number') base.elevationGain = s.elevationGain;
      if (typeof s.elevationLoss === 'number') base.elevationLoss = s.elevationLoss;
      if (typeof s.distanceM === 'number') base.distanceM = s.distanceM;
      if (s.isPartial === true) base.isPartial = true;
      return base;
    });

    // Esforço da avaliação computado ANTES do update — vai junto na run
    // (report renderiza sem fetch extra) e no lastAssessment do profile.
    const isAssessment = typeof run.assessmentTargetKm === 'number' && run.assessmentTargetKm > 0;
    const assessmentEffort = isAssessment
      ? classifyAssessmentEffort({
          avgBpm: input.avgBpm,
          restingBpm: profileRestingBpm,
          maxBpm: profileMaxBpm,
          paceMinKm: formatPace(input.distanceM, input.durationS),
          splits: input.splits,
        })
      : null;

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
      ...(assessmentEffort ? { assessmentResult: assessmentEffort } : {}),
      ...(enrichedSplits && enrichedSplits.length > 0 ? { splits: enrichedSplits } : {}),
      ...(input.telemetryTimeline && input.telemetryTimeline.length > 0
        ? { telemetryTimeline: input.telemetryTimeline }
        : {}),
    };

    await this.runRepo.update(runId, userId, updates);

    // Fix TF 60: auto-bump do profile.maxBpm quando a corrida bate mais
    // alto. User reportou "zonas ignoram FC máxima de 150 porque profile
    // está em 145". Now zonas e prompts reusam o valor real (não trava
    // no chute inicial de onboarding). Best-effort: falha silenciosa.
    if (typeof input.maxBpm === 'number' && input.maxBpm > 0) {
      try {
        const userRepo = new FirestoreUserRepository();
        const profile = await userRepo.findById(userId);
        const currentMax = typeof profile?.maxBpm === 'number' ? profile.maxBpm : 0;
        if (input.maxBpm > currentMax) {
          await userRepo.updatePartial(userId, { maxBpm: input.maxBpm });
          logger.info('user.maxBpm.bumped', {
            userId, runId, before: currentMax, after: input.maxBpm,
          });
        }
      } catch (err) {
        logger.warn('user.maxBpm.bump_failed', { userId, runId, err: String(err) });
      }
    }

    // Assessment run: o resultado medido vira capacidade no profile —
    // pace real + distância completada substituem o auto-reportado do
    // wizard (provenance "medido"). Parcial (<50% do alvo) registra só o
    // lastAssessment (com completedKm real, pra UI ofertar repetir) sem
    // sobrescrever capacity/pace. Best-effort: falha silenciosa.
    if (isAssessment && run.assessmentTargetKm) {
      try {
        const completedKm = input.distanceM / 1000;
        const paceMinKm = formatPace(input.distanceM, input.durationS);
        const effort = assessmentEffort!;
        const userRepo = new FirestoreUserRepository();
        const patch: Partial<import('@modules/users/domain/user.entity').UserProfile> = {
          lastAssessment: {
            runId,
            at: new Date().toISOString(),
            targetKm: run.assessmentTargetKm,
            completedKm: Number(completedKm.toFixed(2)),
            paceMinKm,
            ...(typeof input.avgBpm === 'number' ? { avgBpm: input.avgBpm } : {}),
            ...(effort.pctHrr != null ? { pctHrr: effort.pctHrr } : {}),
            ...(effort.cardiacDriftPct != null ? { cardiacDriftPct: effort.cardiacDriftPct } : {}),
            ...(effort.effortLabel != null ? { effortLabel: effort.effortLabel } : {}),
            ...(effort.easyPaceMinKm != null ? { easyPaceMinKm: effort.easyPaceMinKm } : {}),
          },
        };
        const completedEnough = completedKm >= run.assessmentTargetKm * 0.5;
        if (completedEnough && paceMinKm) {
          patch.capacityDistanceKm = Math.max(1, Math.floor(completedKm));
          // Anti-gaming: `currentPaceMinKm` significa pace CONFORTÁVEL.
          // Esforço forte/máximo (detectado pela FC) grava o easy estimado,
          // não o pace cru de quem "entregou a vida" pra cravar número.
          const sustainable =
            effort.effortLabel === 'forte' || effort.effortLabel === 'maximo'
              ? effort.easyPaceMinKm ?? paceMinKm
              : paceMinKm;
          patch.currentPaceMinKm = sustainable;
        }
        await userRepo.updatePartial(userId, patch);
        logger.info('run.assessment.persisted', {
          userId,
          runId,
          targetKm: run.assessmentTargetKm,
          completedKm: Number(completedKm.toFixed(2)),
          paceMinKm,
          pctHrr: effort.pctHrr,
          cardiacDriftPct: effort.cardiacDriftPct,
          effortLabel: effort.effortLabel,
          easyPaceMinKm: effort.easyPaceMinKm,
          overwroteCapacity: completedEnough,
        });
      } catch (err) {
        logger.warn('run.assessment.persist_failed', { userId, runId, err: String(err) });
      }
    }

    // TF 77: dispara evaluator de badges pós-completar. Se a run desbloqueou
    // algum marco (1ª corrida, 5K, 10K, streak, etc), persiste o badge
    // unlocked pra mostrar no próximo open do app. Best-effort — falha
    // silenciosa pra não quebrar o complete-run em caso de Firestore down.
    // TF 79: também retorna a lista pro client mostrar modal pós-run.
    let unlockedBadges: import('@modules/badges/domain/badge.entity').Badge[] = [];
    try {
      const badgesRepo = new FirestoreBadgeRepository();
      const evaluator = new EvaluateBadgesUseCase(this.runRepo, badgesRepo);
      const { unlocked } = await evaluator.execute({ uid: userId });
      unlockedBadges = unlocked;
      if (unlocked.length > 0) {
        logger.info('badges.unlocked_after_run', {
          userId, runId, count: unlocked.length,
          ids: unlocked.map((b) => b.badgeId),
        });
        // TF 79: dispara push pra cada badge desbloqueado. Best-effort —
        // SendUserPushUseCase já respeita notificationsEnabled.push do user
        // e falha silenciosa quando token inválido. Vai pra central de
        // notificações iOS via APNS (bridge automática do FCM).
        try {
          const userRepo = new FirestoreUserRepository();
          const sendPush = new SendUserPushUseCase(userRepo);
          for (const badge of unlocked) {
            await sendPush.execute(userId, {
              title: '🏅 Novo marco desbloqueado!',
              body: `${badge.title} · ${badge.subtitle}`,
              data: {
                kind: 'badge_unlocked',
                route: '/profile/badges',
                badgeId: badge.badgeId,
              },
            });
          }
        } catch (err) {
          logger.warn('badges.push_failed', { userId, runId, err: String(err) });
        }
      }
    } catch (err) {
      logger.warn('badges.eval_failed', { userId, runId, err: String(err) });
    }

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

    return { run: { ...run, ...updates }, unlockedBadges };
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
    // ARQUITETURA: plan.weeks (BASE) é IMUTÁVEL. Flag de execução
    // (executedRunId/executedAt) vai SEMPRE em adjustedWeeks. Se ainda
    // não houver, promove um clone de weeks pra adjustedWeeks com a flag.
    const base = effectivePlanWeeks(plan);
    let touched = false;
    const updatedWeeks = base.map(w => ({
      ...w,
      sessions: w.sessions.map(s => {
        if (s.id !== planSessionId) return s;
        touched = true;
        return { ...s, executedRunId: runId, executedAt: new Date().toISOString() };
      }),
    }));
    if (!touched) return;
    await planRepo.update(plan.id, userId, { adjustedWeeks: updatedWeeks });
    logger.info('plan.session.flagged_executed', { planSessionId, runId, planId: plan.id });
  }

}
