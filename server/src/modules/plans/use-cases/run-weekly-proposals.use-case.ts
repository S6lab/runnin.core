import { UserRepository } from '@modules/users/domain/user.repository';
import { isPremium } from '@modules/users/domain/user.entity';
import { RunRepository } from '@modules/runs/domain/run.repository';
import { PlanRepository } from '../domain/plan.repository';
import { ProposeCheckpointUseCase } from './propose-checkpoint.use-case';
import { currentWeekNumber } from './checkpoint-shared';
import { logger } from '@shared/logger/logger';

const ACTIVE_WINDOW_DAYS = 14;
const BATCH_SIZE = 100;

export interface WeeklyProposalsResult {
  processed: number;
  proposed: number;
  skipped: number;
  errors: number;
}

/**
 * Cron de DOMINGO: percorre os usuários ATIVOS premium e gera uma PROPOSTA
 * de revisão das próximas 2 semanas (pendente de aceite). Critério de ativo:
 * tem plano `ready` E correu nos últimos 14 dias. Soft-fail por usuário.
 */
export class RunWeeklyProposalsUseCase {
  constructor(
    private readonly userRepo: UserRepository,
    private readonly planRepo: PlanRepository,
    private readonly runRepo: RunRepository,
    private readonly propose: ProposeCheckpointUseCase,
  ) {}

  async execute(): Promise<WeeklyProposalsResult> {
    const result: WeeklyProposalsResult = { processed: 0, proposed: 0, skipped: 0, errors: 0 };
    let cursor: string | undefined;

    while (true) {
      const batch = await this.userRepo.list(BATCH_SIZE, cursor);
      if (batch.length === 0) break;

      for (const profile of batch) {
        result.processed++;
        try {
          if (!isPremium(profile)) {
            result.skipped++;
            continue;
          }
          const plan = await this.planRepo.findCurrent(profile.id);
          if (!plan || plan.status !== 'ready') {
            result.skipped++;
            continue;
          }
          if (plan.pendingRevisionId) {
            // Já há proposta pendente aguardando o usuário — não duplica.
            result.skipped++;
            continue;
          }
          if (!(await this._isActive(profile.id))) {
            result.skipped++;
            continue;
          }

          const weekNumber = currentWeekNumber(plan);
          const out = await this.propose.execute(profile.id, plan.id, weekNumber);
          if (out.revision) {
            result.proposed++;
          } else {
            result.skipped++;
          }
        } catch (err) {
          result.errors++;
          logger.warn('weekly_proposals.user_failed', {
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

  /** Ativo = correu (run completed) nos últimos ACTIVE_WINDOW_DAYS dias. */
  private async _isActive(userId: string): Promise<boolean> {
    const cutoff = Date.now() - ACTIVE_WINDOW_DAYS * 86_400_000;
    const recent = await this.runRepo.findByUser(userId, 20);
    return recent.runs.some(
      (r) => r.status === 'completed' && new Date(r.createdAt).getTime() >= cutoff,
    );
  }
}
