import { PlanRepository } from '../domain/plan.repository';
import { RunRepository } from '@modules/runs/domain/run.repository';
import { Run } from '@modules/runs/domain/run.entity';
import { Plan } from '../domain/plan.entity';
import { CheckpointInput } from '../domain/plan-checkpoint.entity';
import { ApplyWeeklyRevisionUseCase } from './apply-weekly-revision.use-case';
import { civilWeekRange, currentWeekNumber } from './checkpoint-shared';
import { logger } from '@shared/logger/logger';

const ACTIVE_WINDOW_DAYS = 14;

/**
 * Worker do fan-out: processa UM usuário (1 chamada de LLM). Chamado por cada
 * Cloud Task enfileirada pelo cron de domingo. Critério de ativo: tem plano
 * `ready` E correu nos últimos 14 dias. Idempotência (já aplicou revisão
 * pra essa semana?) fica dentro da use-case. (Premium já foi filtrado no
 * enqueue.)
 */
export class ProcessUserProposalUseCase {
  constructor(
    private readonly planRepo: PlanRepository,
    private readonly runRepo: RunRepository,
    private readonly applyRevision: ApplyWeeklyRevisionUseCase,
  ) {}

  async execute(userId: string): Promise<{ applied: boolean; reason?: string }> {
    const plan = await this.planRepo.findCurrent(userId);
    if (!plan || plan.status !== 'ready') return { applied: false, reason: 'no_active_plan' };
    if (!(await this._isActive(userId))) return { applied: false, reason: 'inactive' };

    const weekNumber = currentWeekNumber(plan);
    const extraInputs = await this._collectWeekFeedback(userId, plan, weekNumber);
    const out = await this.applyRevision.execute(userId, plan.id, weekNumber, extraInputs);
    if (out.revision) {
      logger.info('weekly_revision.worker.applied', {
        userId, planId: plan.id, weekNumber, feedbackInputs: extraInputs.length,
      });
      return { applied: true };
    }
    return { applied: false, reason: out.reason };
  }

  /** Ativo = correu (run completed) nos últimos ACTIVE_WINDOW_DAYS dias. */
  private async _isActive(userId: string): Promise<boolean> {
    const cutoff = Date.now() - ACTIVE_WINDOW_DAYS * 86_400_000;
    const recent = await this.runRepo.findByUser(userId, 20);
    return recent.runs.some(
      (r) => r.status === 'completed' && new Date(r.createdAt).getTime() >= cutoff,
    );
  }

  /**
   * Agrega o feedback subjetivo (chips + note) submetido pelo user em cada
   * corrida concluída da semana. Substitui o input vindo da página de
   * checkpoint solto: agora o coach lê o que o user sentiu por corrida.
   * Dedupa por (type|note) pra não dar peso indevido a feedback repetido.
   */
  private async _collectWeekFeedback(
    userId: string,
    plan: Plan,
    weekNumber: number,
  ): Promise<CheckpointInput[]> {
    const range = civilWeekRange(plan, weekNumber);
    if (!range) return [];
    const recent = await this.runRepo.findByUser(userId, 50);
    const inWeek = recent.runs.filter((r: Run) => {
      if (r.status !== 'completed') return false;
      const t = new Date(r.createdAt).getTime();
      return t >= range.start.getTime() && t < range.end.getTime();
    });
    const all = inWeek.flatMap((r) => r.userFeedback ?? []);
    const seen = new Set<string>();
    return all.filter((i) => {
      const k = `${i.type}|${i.note ?? ''}`;
      if (seen.has(k)) return false;
      seen.add(k);
      return true;
    });
  }
}
