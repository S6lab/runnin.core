import { v4 as uuid } from 'uuid';
import { parseWeightKg } from '@modules/users/domain/user-metrics';
import { PlanRepository } from '../domain/plan.repository';
import { PlanRevision } from '../domain/plan-revision.entity';
import { PlanRevisionRepository } from '../domain/plan-revision.repository';
import { CheckpointInput } from '../domain/plan-checkpoint.entity';
import { PlanCheckpointRepository } from '../domain/plan-checkpoint.repository';
import { RunRepository } from '@modules/runs/domain/run.repository';
import { CheckpointAnalysisStrategy } from './checkpoint-analysis.strategy';
import { CreateNotificationUseCase } from '@modules/notifications/domain/use-cases/create-notification.use-case';
import { SendUserPushUseCase } from '@modules/notifications/domain/use-cases/send-user-push.use-case';
import { PlanRevision as PlanRevisionLog, effectivePlanWeeks } from '../domain/plan.entity';
import {
  buildChangesSnapshot,
  buildCheckpointProposal,
  buildLogSummary,
  deriveRequestType,
  mergeInputs,
  mergeProposedWeeks,
  PlanNotReadyError,
} from './checkpoint-shared';
import { enforceRevisionInvariants } from './enforce-race-week-structure';
import { clampRevisionMagnitude } from './clamp-revision-magnitude';
import { hydrateRevisedSessions } from './hydrate-revised-sessions';
import { FirestoreUserRepository } from '@modules/users/infra/firestore-user.repository';
import { NotFoundError } from '@shared/errors/app-error';
import { logger } from '@shared/logger/logger';

/**
 * Aplica direto a revisão semanal do plano (cron de domingo):
 *  - roda a análise (LLM) sobre a semana + feedback agregado das runs
 *  - merge das semanas novas no plano (substitui as futuras, preserva passado)
 *  - grava PlanRevision com status='applied' (histórico/auditoria)
 *  - completa o checkpoint da semana (se existir)
 *  - notifica o user que o plano foi atualizado (sem CTA pra aceitar)
 *
 * Substitui o fluxo antigo de propose → user aceita → resolve. Não há mais
 * passo de aprovação manual: o plano se atualiza sozinho.
 *
 * Idempotência: se já existe revisão `applied` pra essa weekIndex, pula.
 */
export class ApplyWeeklyRevisionUseCase {
  constructor(
    private readonly planRepo: PlanRepository,
    private readonly checkpointRepo: PlanCheckpointRepository,
    private readonly revisionRepo: PlanRevisionRepository,
    private readonly runRepo: RunRepository,
    private readonly strategy: CheckpointAnalysisStrategy,
    private readonly createNotification: CreateNotificationUseCase,
    private readonly sendPush: SendUserPushUseCase,
  ) {}

  async execute(
    userId: string,
    planId: string,
    weekNumber: number,
    extraInputs: CheckpointInput[] = [],
  ): Promise<{ revision?: PlanRevision; reason?: string }> {
    const plan = await this.planRepo.findById(planId, userId);
    if (!plan) throw new NotFoundError('Plan');
    if (plan.status !== 'ready') throw new PlanNotReadyError();

    // Idempotência: cron pode disparar duas vezes (retry, fan-out) — se já
    // aplicou revisão pra essa semana, não roda análise de novo.
    const existing = await this.revisionRepo.listByPlan(planId, userId);
    if (existing.some((r) => r.weekIndex === weekNumber && r.status === 'applied')) {
      return { reason: 'already_applied' };
    }

    // Checkpoint é opcional aqui: o feedback subjetivo agora vem das runs
    // (extraInputs). Mantém leitura pra registrar autoAnalysis se houver.
    const cp = await this.checkpointRepo.findByWeek(planId, weekNumber, userId);
    const mergedInputs = mergeInputs(cp?.userInputs ?? [], extraInputs);

    const proposal = await buildCheckpointProposal(
      { runRepo: this.runRepo, strategy: this.strategy },
      plan,
      weekNumber,
      mergedInputs,
      userId,
    );

    // Caminho único — independente de o LLM ajustar ou não, o checkpoint
    // SEMPRE vira registro no histórico. "Sem ajustes" é sinalizado por
    // newWeeksSnapshot=[] pra a UI distinguir do caso ajustado.
    const noChanges = proposal.newWeeks.length === 0;
    const now = new Date().toISOString();
    // Parte do estado VIGENTE (adjustedWeeks ?? weeks) — nunca da base.
    // Cada revisão é cumulativa sobre o snapshot anterior.
    const previousEffective = effectivePlanWeeks(plan);
    const mergedWeeks = noChanges
      ? previousEffective
      : mergeProposedWeeks(
          { ...plan, weeks: previousEffective },
          weekNumber,
          proposal.newWeeks,
        );

    // Pós-merge passo 1: invariantes da âncora da prova (race+taper, weeksCount,
    // passado). Compara contra a BASE (plan.weeks) pra detectar drift estrutural.
    const enforced = noChanges
      ? { weeks: mergedWeeks, changes: [] as string[] }
      : enforceRevisionInvariants(mergedWeeks, {
          plan,
          originalWeeks: plan.weeks,
          currentWeekNumber: weekNumber,
        });

    // Pós-merge passo 2: cap absoluto de magnitude (70%-110% vs semana anterior).
    // Cobre LLM que ignora a regra "deload 15-30%" e manda 83% de corte.
    const clampedResult = noChanges
      ? { weeks: enforced.weeks, clamped: [] }
      : clampRevisionMagnitude(enforced.weeks, previousEffective, weekNumber, {
          planId,
          userId,
        });

    // Pós-merge passo 3: hidrata recheio das sessões revisadas (executionSegments,
    // hidratação, nutrição, targetPace) + força detailLevel + fallback narrative.
    // Sessões em weeks > current+2 ficam como skeleton (locked é OK ali).
    const profile = await this._loadProfile(userId);
    const newAdjustedWeeks = noChanges
      ? clampedResult.weeks
      : await hydrateRevisedSessions(clampedResult.weeks, {
          currentWeekNumber: weekNumber,
          profile,
          plan,
        });

    const revision: PlanRevision = {
      id: uuid(),
      planId,
      userId,
      weekIndex: weekNumber,
      requestType: deriveRequestType(mergedInputs),
      freeText: mergedInputs.find((i) => i.note)?.note,
      oldWeeksSnapshot: proposal.oldFollowingWeeks,
      newWeeksSnapshot: proposal.newWeeks,
      coachExplanation: proposal.coachExplanation,
      status: 'applied',
      createdAt: now,
      appliedAt: now,
    };
    await this.revisionRepo.save(revision);

    const logEntry: PlanRevisionLog = {
      weekNumber,
      revisedAt: now,
      trigger: 'weekly_cron',
      summary: noChanges
        ? 'Plano completo da semana — sem ajustes'
        : buildLogSummary(mergedInputs, proposal.oldFollowingWeeks, proposal.newWeeks),
      details: proposal.coachExplanation,
      changes: noChanges
        ? { sessionsAdjusted: 0, intensityShift: 'unchanged' }
        : buildChangesSnapshot(proposal.oldFollowingWeeks, proposal.newWeeks),
    };

    // ATENÇÃO: NÃO mexer em `plan.weeks` — é a BASE IMUTÁVEL exibida em
    // "VER PLANO BASE". Salva o snapshot novo em `adjustedWeeks`, que é
    // o que as telas de treino vigente leem via `effectivePlanWeeks`.
    await this.planRepo.update(planId, userId, {
      adjustedWeeks: newAdjustedWeeks,
      revisions: [...(plan.revisions ?? []), logEntry],
      updatedAt: now,
    });

    if (cp) {
      await this.checkpointRepo.update(planId, weekNumber, userId, {
        userInputs: mergedInputs,
        autoAnalysis: proposal.autoAnalysis,
        resultRevisionId: revision.id,
        status: 'completed',
        completedAt: now,
      });
    }

    const notifTitle = noChanges ? 'Coach revisou sua semana' : 'Plano atualizado';
    const notifBody = noChanges
      ? 'Plano segue como estava — você está no ritmo certo. Toque pra ver a avaliação.'
      : 'O coach ajustou as próximas 2 semanas com base na sua jornada. Toque pra ver o que mudou.';

    try {
      // dedupeKey estável por (semana, plano) — antes era revision.id (UUID),
      // que gerava notif nova cada vez que o cron re-rodava com retry/race.
      // Agora 2 calls com mesmo (week, plan) viram 1 doc.
      await this.createNotification.execute({
        userId,
        type: 'plan_updated',
        dedupeKey: `weekly_w${weekNumber}_${planId}`,
        title: notifTitle,
        body: notifBody,
        icon: 'auto_awesome',
        ctaLabel: 'VER',
        ctaRoute: '/training/plan-detail',
        data: { planId, revisionId: revision.id },
      });
    } catch (err) {
      logger.warn('weekly_revision.notify_failed', { planId, userId, err: String(err) });
    }

    try {
      await this.sendPush.execute(userId, {
        title: notifTitle,
        body: notifBody,
        data: {
          kind: 'plan_updated',
          route: '/training/plan-detail',
          planId,
          revisionId: revision.id,
        },
      });
    } catch (err) {
      logger.warn('weekly_revision.push_failed', { planId, userId, err: String(err) });
    }

    logger.info('weekly_revision.applied', {
      planId, userId, weekNumber, revisionId: revision.id, noChanges,
    });
    return { revision };
  }

  /** Carrega o perfil pra usar peso (hidratação) + level (pace defaults).
   *  Best-effort: se falhar, hidrata com defaults conservadores. */
  private async _loadProfile(userId: string): Promise<{ weight?: number; level?: string } | null> {
    try {
      const repo = new FirestoreUserRepository();
      const profile = await repo.findById(userId);
      if (!profile) return null;
      return {
        weight: parseWeightKg(profile.weight) ?? undefined,
        level: typeof profile.level === 'string' ? profile.level : undefined,
      };
    } catch {
      return null;
    }
  }
}
