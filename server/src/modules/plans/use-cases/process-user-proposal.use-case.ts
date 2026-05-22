import { PlanRepository } from '../domain/plan.repository';
import { RunRepository } from '@modules/runs/domain/run.repository';
import { ProposeCheckpointUseCase } from './propose-checkpoint.use-case';
import { currentWeekNumber } from './checkpoint-shared';
import { logger } from '@shared/logger/logger';

const ACTIVE_WINDOW_DAYS = 14;

/**
 * Worker do fan-out: processa UM usuário (1 chamada de LLM). Chamado por cada
 * Cloud Task enfileirada pelo cron de domingo. Critério de ativo: tem plano
 * `ready` E correu nos últimos 14 dias. Idempotente: pula se já há proposta
 * pendente. (Premium já foi filtrado no enqueue.)
 */
export class ProcessUserProposalUseCase {
  constructor(
    private readonly planRepo: PlanRepository,
    private readonly runRepo: RunRepository,
    private readonly propose: ProposeCheckpointUseCase,
  ) {}

  async execute(userId: string): Promise<{ proposed: boolean; reason?: string }> {
    const plan = await this.planRepo.findCurrent(userId);
    if (!plan || plan.status !== 'ready') return { proposed: false, reason: 'no_active_plan' };
    if (plan.pendingRevisionId) return { proposed: false, reason: 'already_pending' };
    if (!(await this._isActive(userId))) return { proposed: false, reason: 'inactive' };

    const weekNumber = currentWeekNumber(plan);
    const out = await this.propose.execute(userId, plan.id, weekNumber);
    if (out.revision) {
      logger.info('weekly_proposal.worker.proposed', { userId, planId: plan.id, weekNumber });
      return { proposed: true };
    }
    return { proposed: false, reason: out.reason };
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
