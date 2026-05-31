import { Plan } from '../domain/plan.entity';
import { PlanCheckpoint } from '../domain/plan-checkpoint.entity';
import { PlanCheckpointRepository } from '../domain/plan-checkpoint.repository';

/**
 * Cria 1 checkpoint por semana do mesociclo, sempre ancorado ao DOMINGO
 * (último dia da semana civil). Antes era D+6 relativo à startDate, o
 * que fazia cair em dias inconsistentes (terça, quinta, etc) quando o
 * plano começava no meio da semana. Idempotente: se já existem
 * checkpoints pro plano, não recria. Chamado quando plan vira `ready`
 * em generate-plan.
 */
export class ScheduleCheckpointsUseCase {
  constructor(private readonly repo: PlanCheckpointRepository) {}

  async execute(plan: Plan): Promise<PlanCheckpoint[]> {
    const existing = await this.repo.findByPlan(plan.id, plan.userId);
    if (existing.length > 0) return existing;

    const start = parseISO(plan.startDate ?? plan.createdAt.slice(0, 10));
    if (!start) return [];

    const now = new Date().toISOString();
    const checkpoints: PlanCheckpoint[] = plan.weeks.map((w) => {
      // Cada semana N: pega um dia no meio dela (start + (N-1)*7 + 3)
      // e avança até o próximo domingo. Se já cair no domingo, fica.
      const midweek = new Date(start.getTime() + ((w.weekNumber - 1) * 7 + 3) * 86_400_000);
      const daysUntilSunday = (7 - midweek.getDay()) % 7; // 0 = Sun
      const dueDate = new Date(midweek.getTime() + daysUntilSunday * 86_400_000);
      return {
        id: `${plan.id}_${w.weekNumber}`,
        planId: plan.id,
        userId: plan.userId,
        weekNumber: w.weekNumber,
        scheduledDate: dueDate.toISOString().slice(0, 10),
        status: 'scheduled',
        createdAt: now,
      };
    });

    await this.repo.saveBatch(checkpoints);
    return checkpoints;
  }
}

function parseISO(s: string): Date | null {
  const d = new Date(`${s}T00:00:00`);
  return isNaN(d.getTime()) ? null : d;
}
