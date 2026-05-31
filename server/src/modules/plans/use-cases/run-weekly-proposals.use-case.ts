import { UserRepository } from '@modules/users/domain/user.repository';
import { isPremium } from '@modules/users/domain/user.entity';
import { ProposalTaskDispatcher } from '@shared/infra/tasks/proposal-task.dispatcher';
import { ProcessUserProposalUseCase } from './process-user-proposal.use-case';
import { logger } from '@shared/logger/logger';

const BATCH_SIZE = 100;

export interface WeeklyProposalsResult {
  /** Modo de execução: enfileirou tasks ou processou inline (fallback). */
  mode: 'queued' | 'inline';
  premium: number;
  enqueued: number;
  appliedInline: number;
  errors: number;
}

/**
 * Cron de DOMINGO (enqueue). Percorre os usuários PREMIUM em lote (cursor) e
 * enfileira 1 Cloud Task por usuário — retorno rápido, sem estourar timeout.
 * O critério de ativo (correu ≤14d) + plano `ready` é avaliado no worker
 * (ProcessUserProposalUseCase), por usuário.
 *
 * Fallback: se o dispatcher não estiver configurado (dev local), processa
 * inline — pode ser lento, mas funcional.
 */
export class RunWeeklyProposalsUseCase {
  constructor(
    private readonly userRepo: UserRepository,
    private readonly dispatcher: ProposalTaskDispatcher,
    private readonly processUser: ProcessUserProposalUseCase,
  ) {}

  async execute(): Promise<WeeklyProposalsResult> {
    const queued = this.dispatcher.enabled;
    const result: WeeklyProposalsResult = {
      mode: queued ? 'queued' : 'inline',
      premium: 0,
      enqueued: 0,
      appliedInline: 0,
      errors: 0,
    };
    let cursor: string | undefined;

    while (true) {
      const batch = await this.userRepo.list(BATCH_SIZE, cursor);
      if (batch.length === 0) break;

      for (const profile of batch) {
        // Premium filtrado aqui (profile já em mãos, sem leitura extra).
        if (!isPremium(profile)) continue;
        result.premium++;
        try {
          if (queued) {
            await this.dispatcher.enqueue({ userId: profile.id });
            result.enqueued++;
          } else {
            const out = await this.processUser.execute(profile.id);
            if (out.applied) result.appliedInline++;
          }
        } catch (err) {
          result.errors++;
          logger.warn('weekly_proposals.enqueue_failed', {
            userId: profile.id,
            err: String(err),
          });
        }
      }

      if (batch.length < BATCH_SIZE) break;
      cursor = batch[batch.length - 1]!.id;
    }

    logger.info('weekly_proposals.done', result);
    return result;
  }
}
