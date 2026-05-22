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
import {
  buildCheckpointProposal,
  deriveRequestType,
  mergeInputs,
  PlanNotReadyError,
} from './checkpoint-shared';
import { NotFoundError } from '@shared/errors/app-error';
import { logger } from '@shared/logger/logger';

/**
 * Gera a PROPOSTA de revisão das próximas semanas (com base nos inputs da
 * semana + números das runs), salva como PlanRevision `pending` e seta
 * `plan.pendingRevisionId` — SEM aplicar no plano. Notifica o usuário.
 *
 * Idempotente: se já existe uma proposta pendente para o plano, não cria
 * outra (retorna a existente). O plano só muda quando o usuário ACEITA
 * (ver ResolveProposalUseCase).
 */
export class ProposeCheckpointUseCase {
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

    // Idempotência: uma proposta pendente por vez.
    if (plan.pendingRevisionId) {
      return { reason: 'already_pending' };
    }

    const cp = await this.checkpointRepo.findByWeek(planId, weekNumber, userId);
    if (!cp) return { reason: 'no_checkpoint' };
    if (cp.status === 'completed') return { reason: 'checkpoint_completed' };

    const mergedInputs = mergeInputs(cp.userInputs ?? [], extraInputs);

    const proposal = await buildCheckpointProposal(
      { runRepo: this.runRepo, strategy: this.strategy },
      plan,
      weekNumber,
      mergedInputs,
      userId,
    );

    if (proposal.newWeeks.length === 0) {
      // Sem mudança: registra a análise no checkpoint, mas não cria proposta.
      await this.checkpointRepo.update(planId, weekNumber, userId, {
        autoAnalysis: proposal.autoAnalysis,
      });
      logger.info('checkpoint.propose.no_changes', { planId, weekNumber, userId });
      return { reason: 'no_changes' };
    }

    const now = new Date().toISOString();
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
      status: 'pending',
      createdAt: now,
    };
    await this.revisionRepo.save(revision);

    await this.planRepo.update(planId, userId, {
      pendingRevisionId: revision.id,
      updatedAt: now,
    });

    await this.checkpointRepo.update(planId, weekNumber, userId, {
      userInputs: mergedInputs,
      autoAnalysis: proposal.autoAnalysis,
      resultRevisionId: revision.id,
    });

    // Notifica o usuário que há uma proposta pra revisar.
    try {
      await this.createNotification.execute({
        userId,
        type: 'plan_proposal',
        dedupeKey: revision.id,
        title: 'Plano da semana revisado',
        body: 'Sua proposta de ajuste das próximas 2 semanas está pronta. Toque para revisar e aceitar.',
        icon: 'auto_awesome',
        ctaLabel: 'REVISAR',
        ctaRoute: '/training/plan-proposal',
        data: { planId, revisionId: revision.id },
      });
    } catch (err) {
      logger.warn('checkpoint.propose.notify_failed', { planId, userId, err: String(err) });
    }

    // Push (FCM) além da notificação in-app — alerta o usuário no device.
    try {
      await this.sendPush.execute(userId, {
        title: 'Plano da semana revisado',
        body: 'Sua proposta de ajuste das próximas 2 semanas está pronta. Toque pra revisar e aceitar.',
        data: {
          kind: 'plan_proposal',
          route: '/training/plan-proposal',
          planId,
          revisionId: revision.id,
        },
      });
    } catch (err) {
      logger.warn('checkpoint.propose.push_failed', { planId, userId, err: String(err) });
    }

    logger.info('checkpoint.propose.created', {
      planId,
      userId,
      weekNumber,
      revisionId: revision.id,
    });
    return { revision };
  }
}
