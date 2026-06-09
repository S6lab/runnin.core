import { Plan, effectivePlanWeeks } from '../domain/plan.entity';
import { PlanRepository } from '../domain/plan.repository';
import { PlanRevisionRepository } from '../domain/plan-revision.repository';
import { UserRepository } from '@modules/users/domain/user.repository';
import { RunRepository } from '@modules/runs/domain/run.repository';
import { RequestRevisionUseCase } from './request-revision.use-case';
import { currentWeekNumber } from './checkpoint-shared';
import { logger } from '@shared/logger/logger';

export type AdaptSource = 'missed_day';

/**
 * Adaptações automáticas do plano feitas pela IA sem input do usuário.
 *
 *  - `missed_day`: roda 1x/dia pelo cron. Se o user tinha sessão planejada
 *    ontem e não rodou nada, pede AI pra realocar a carga perdida.
 *  - Revisão semanal (domingo 23h BR) NÃO passa por aqui — é feita via
 *    `ApplyWeeklyRevisionUseCase` no fan-out do cron `weekly-proposals`.
 *
 * Por design, não consome cota de revisões manuais do usuário
 * (bypassQuota=true). Não falha hard — registra warn e segue.
 */
export class AdaptPlanUseCase {
  constructor(
    private readonly plans: PlanRepository,
    private readonly runs: RunRepository,
    private readonly revision: RequestRevisionUseCase,
    private readonly _users: UserRepository,
    private readonly _revisions: PlanRevisionRepository,
  ) {}

  /**
   * Revisão semanal automática: olha as últimas 7 sessões executadas (vs
   * planejadas) e pede pra IA ajustar as próximas semanas. Anexa um
   * snapshot ao histórico plan.revisions[] pra o atleta ver a jornada.
   *
   * Disparada via cron semanal OU manualmente pelo admin.
   */
  async executeWeeklyRevision(userId: string): Promise<{ applied: boolean; reason?: string }> {
    try {
      const plan = await this.plans.findCurrent(userId);
      if (!plan || plan.status !== 'ready') {
        return { applied: false, reason: 'no_active_plan' };
      }

      const since = new Date(Date.now() - 7 * 86_400_000);
      const recent = await this.runs.findByDateRange(userId, since, new Date());
      const completed = recent.filter(r => r.status === 'completed');

      const totalKm = completed.reduce(
        (s, r) => s + (r.distanceM ?? 0) / 1000,
        0,
      );
      const currentWeekIndex = this._getCurrentWeekIndex(plan);
      const currentWeek = effectivePlanWeeks(plan)[currentWeekIndex];
      const plannedSessions = currentWeek?.sessions.length ?? 0;
      const completedCount = completed.length;
      const aderence = plannedSessions > 0
        ? Math.round((completedCount / plannedSessions) * 100)
        : 0;

      const summary = completedCount === 0
        ? `Semana ${currentWeekIndex + 1} sem corridas registradas — sugerindo reduzir volume das próximas semanas e voltar a fundação.`
        : `Semana ${currentWeekIndex + 1}: ${completedCount}/${plannedSessions} sessões (${aderence}% aderência) totalizando ${totalKm.toFixed(1)}km. Ajustando próximas semanas conforme execução real.`;

      const freeText = [
        `[REVISÃO SEMANAL] Reveja as próximas semanas do plano com base na execução da semana ${currentWeekIndex + 1}:`,
        `- Sessões planejadas: ${plannedSessions}`,
        `- Sessões executadas: ${completedCount}`,
        `- Aderência: ${aderence}%`,
        `- Volume real: ${totalKm.toFixed(1)}km`,
        '',
        completedCount === 0
          ? 'Reduza o volume das próximas 2 semanas em ~20% e mantenha intensidade baixa pra reengajar.'
          : aderence < 60
          ? 'Aderência baixa — reduza volume em 10-15% nas próximas semanas e simplifique tipos de sessão.'
          : aderence > 100
          ? 'Aderência altíssima — pode subir progressão 5-10% nas próximas semanas se BPM/recuperação OK.'
          : 'Aderência saudável — mantenha progressão planejada com ajustes finos por sensação.',
      ].join('\n');

      await this.revision.execute(
        userId,
        plan.id,
        { type: 'other', freeText },
        { bypassQuota: true },
      );

      const revisionEntry = {
        weekNumber: currentWeekIndex + 1,
        revisedAt: new Date().toISOString(),
        trigger: 'weekly_cron' as const,
        summary,
        details: freeText,
        changes: {
          sessionsAdjusted: plannedSessions,
          intensityShift: (aderence > 100
            ? 'increased'
            : aderence < 60
            ? 'decreased'
            : 'unchanged') as 'increased' | 'decreased' | 'unchanged',
        },
      };

      const existingRevisions = plan.revisions ?? [];
      await this.plans.update(plan.id, userId, {
        revisions: [...existingRevisions, revisionEntry],
        updatedAt: new Date().toISOString(),
      });

      logger.info('plan.adapt.weekly_revision_applied', {
        userId,
        planId: plan.id,
        weekIndex: currentWeekIndex,
        aderence,
      });
      return { applied: true };
    } catch (err) {
      logger.warn('plan.adapt.weekly_revision_failed', {
        userId,
        err: String(err),
      });
      return { applied: false, reason: String(err) };
    }
  }

  async executeMissedDay(userId: string): Promise<void> {
    try {
      const plan = await this.plans.findCurrent(userId);
      if (!plan || plan.status !== 'ready') return;
      const yesterdayDow = ((new Date(Date.now() - 86_400_000).getDay()) || 7);
      const currentWeekIndex = this._getCurrentWeekIndex(plan);
      const currentWeek = effectivePlanWeeks(plan)[currentWeekIndex];
      if (!currentWeek) return;
      const sessionYesterday = currentWeek.sessions.find(
        s => s.dayOfWeek === yesterdayDow,
      );
      if (!sessionYesterday) return; // descanso planejado → ok

      // Verifica se rodou ontem
      const since = new Date(Date.now() - 86_400_000);
      since.setHours(0, 0, 0, 0);
      const until = new Date(since.getTime() + 86_400_000);
      const recent = await this.runs.findByDateRange(userId, since, until);
      const ranYesterday = recent.some(r => r.status === 'completed');
      if (ranYesterday) return;

      const summary = `Sessão planejada para ontem (${sessionYesterday.type} ${sessionYesterday.distanceKm}km) não foi executada. Realoque a carga perdida nas próximas sessões da semana sem sobrecarregar.`;

      await this.revision.execute(
        userId,
        plan.id,
        { type: 'other', freeText: summary },
        { bypassQuota: true },
      );
      logger.info('plan.adapt.missed_day_applied', { userId, planId: plan.id });
    } catch (err) {
      logger.warn('plan.adapt.missed_day_failed', { userId, err: String(err) });
    }
  }

  private _getCurrentWeekIndex(plan: Plan): number {
    return currentWeekNumber(plan) - 1;
  }
}
