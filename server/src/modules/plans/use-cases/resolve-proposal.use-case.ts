import { Plan, PlanRevision as PlanRevisionLog } from '../domain/plan.entity';
import { PlanRepository } from '../domain/plan.repository';
import { PlanRevision } from '../domain/plan-revision.entity';
import { PlanRevisionRepository } from '../domain/plan-revision.repository';
import { PlanCheckpointRepository } from '../domain/plan-checkpoint.repository';
import {
  buildChangesSnapshot,
  buildLogSummary,
  mergeProposedWeeks,
  ProposalAlreadyResolvedError,
} from './checkpoint-shared';
import { NotFoundError } from '@shared/errors/app-error';
import { logger } from '@shared/logger/logger';

/**
 * Resolve uma proposta pendente (criada pelo cron de domingo):
 *  - accept → aplica `newWeeksSnapshot` nas semanas futuras do plano, marca a
 *    revisão como `applied`, completa o checkpoint e limpa pendingRevisionId.
 *  - reject → marca a revisão como `cancelled`, marca o checkpoint como
 *    `skipped` e limpa pendingRevisionId (plano intacto).
 */
export class ResolveProposalUseCase {
  constructor(
    private readonly planRepo: PlanRepository,
    private readonly checkpointRepo: PlanCheckpointRepository,
    private readonly revisionRepo: PlanRevisionRepository,
  ) {}

  private async _loadPending(
    userId: string,
    planId: string,
    revisionId: string,
  ): Promise<{ plan: Plan; revision: PlanRevision }> {
    const plan = await this.planRepo.findById(planId, userId);
    if (!plan) throw new NotFoundError('Plan');
    const revision = await this.revisionRepo.findById(revisionId, userId);
    if (!revision || revision.planId !== planId) throw new NotFoundError('Revision');
    if (revision.status !== 'pending') throw new ProposalAlreadyResolvedError();
    return { plan, revision };
  }

  async accept(
    userId: string,
    planId: string,
    revisionId: string,
  ): Promise<{ plan: Plan; revision: PlanRevision }> {
    const { plan, revision } = await this._loadPending(userId, planId, revisionId);
    const weekNumber = revision.weekIndex;
    const newWeeks = revision.newWeeksSnapshot ?? [];
    const now = new Date().toISOString();

    const newPlanWeeks = mergeProposedWeeks(plan, weekNumber, newWeeks);

    const logEntry: PlanRevisionLog = {
      weekNumber,
      revisedAt: now,
      trigger: 'weekly_cron',
      summary: buildLogSummary([], revision.oldWeeksSnapshot, newWeeks),
      details: revision.coachExplanation,
      changes: buildChangesSnapshot(revision.oldWeeksSnapshot, newWeeks),
    };

    await this.revisionRepo.save({ ...revision, status: 'applied', appliedAt: now });

    await this.planRepo.update(planId, userId, {
      weeks: newPlanWeeks,
      revisions: [...(plan.revisions ?? []), logEntry],
      pendingRevisionId: null,
      updatedAt: now,
    });

    await this.checkpointRepo.update(planId, weekNumber, userId, {
      status: 'completed',
      resultRevisionId: revision.id,
      completedAt: now,
    });

    logger.info('proposal.accepted', { planId, userId, revisionId, weekNumber });
    return {
      plan: { ...plan, weeks: newPlanWeeks, pendingRevisionId: null, updatedAt: now },
      revision: { ...revision, status: 'applied', appliedAt: now },
    };
  }

  async reject(
    userId: string,
    planId: string,
    revisionId: string,
  ): Promise<{ plan: Plan; revision: PlanRevision }> {
    const { plan, revision } = await this._loadPending(userId, planId, revisionId);
    const now = new Date().toISOString();

    await this.revisionRepo.save({ ...revision, status: 'cancelled' });
    await this.planRepo.update(planId, userId, {
      pendingRevisionId: null,
      updatedAt: now,
    });
    await this.checkpointRepo.update(planId, revision.weekIndex, userId, {
      status: 'skipped',
    });

    logger.info('proposal.rejected', { planId, userId, revisionId });
    return {
      plan: { ...plan, pendingRevisionId: null, updatedAt: now },
      revision: { ...revision, status: 'cancelled' },
    };
  }
}
