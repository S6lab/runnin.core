import { v4 as uuid } from 'uuid';
import { PlanRepository } from '../domain/plan.repository';
import { PlanRevision } from '../domain/plan-revision.entity';
import { PlanRevisionRepository } from '../domain/plan-revision.repository';
import { CheckpointInput } from '../domain/plan-checkpoint.entity';
import { PlanCheckpointRepository } from '../domain/plan-checkpoint.repository';
import { RunRepository } from '@modules/runs/domain/run.repository';
import { CheckpointAnalysisStrategy } from './checkpoint-analysis.strategy';
import { CreateNotificationUseCase } from '@modules/notifications/domain/use-cases/create-notification.use-case';
import { SendUserPushUseCase } from '@modules/notifications/domain/use-cases/send-user-push.use-case';
import { PlanRevision as PlanRevisionLog } from '../domain/plan.entity';
import {
  buildChangesSnapshot,
  buildCheckpointProposal,
  buildLogSummary,
  deriveRequestType,
  mergeInputs,
  mergeProposedWeeks,
  PlanNotReadyError,
} from './checkpoint-shared';
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

    if (proposal.newWeeks.length === 0) {
      if (cp) {
        await this.checkpointRepo.update(planId, weekNumber, userId, {
          autoAnalysis: proposal.autoAnalysis,
        });
      }
      logger.info('weekly_revision.no_changes', { planId, weekNumber, userId });
      return { reason: 'no_changes' };
    }

    const now = new Date().toISOString();
    const newPlanWeeks = mergeProposedWeeks(plan, weekNumber, proposal.newWeeks);

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
      summary: buildLogSummary(mergedInputs, proposal.oldFollowingWeeks, proposal.newWeeks),
      details: proposal.coachExplanation,
      changes: buildChangesSnapshot(proposal.oldFollowingWeeks, proposal.newWeeks),
    };

    await this.planRepo.update(planId, userId, {
      weeks: newPlanWeeks,
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

    try {
      await this.createNotification.execute({
        userId,
        type: 'plan_updated',
        dedupeKey: revision.id,
        title: 'Plano atualizado',
        body: 'O coach ajustou as próximas 2 semanas com base na sua jornada. Toque pra ver o que mudou.',
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
        title: 'Plano atualizado',
        body: 'Coach ajustou as próximas 2 semanas. Toque pra ver o que mudou.',
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
      planId, userId, weekNumber, revisionId: revision.id,
    });
    return { revision };
  }
}
