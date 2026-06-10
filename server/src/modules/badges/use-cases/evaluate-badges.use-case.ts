import { Run } from '@modules/runs/domain/run.entity';
import { RunRepository } from '@modules/runs/domain/run.repository';
import { Badge } from '../domain/badge.entity';
import { BADGE_DEFINITIONS, BadgeEvalContext } from '../domain/badge-definitions';
import { BadgeRepository } from '../domain/badge.repository';

export interface EvaluateBadgesInput {
  uid: string;
  /** Trigger pra evento de relatório (cron domingo / fim de mês). */
  reportTrigger?: BadgeEvalContext['reportTrigger'];
}

export interface EvaluateBadgesResult {
  unlocked: Badge[];
  skipped: number;
}

/** Roda TODAS as definições contra o estado atual do user. Idempotente:
 *  badges já desbloqueados são pulados sem re-disparar.
 *
 *  Trigger pontos:
 *  - PATCH /runs/:id/complete → roda com `reportTrigger` undefined
 *  - Cron domingo 23:00 → roda com `reportTrigger: { kind: 'weekly' }`
 *  - Cron fim de mês 23:00 → roda com `reportTrigger: { kind: 'monthly' }`
 *  - Endpoint GET /badges/me (primeira chamada do user) → eval retroativo
 */
export class EvaluateBadgesUseCase {
  constructor(
    private readonly runs: RunRepository,
    private readonly badges: BadgeRepository,
  ) {}

  async execute(input: EvaluateBadgesInput): Promise<EvaluateBadgesResult> {
    const { uid, reportTrigger } = input;
    const allRuns = await this.fetchRunsAsc(uid);
    const existing = await this.badges.listByUser(uid);
    const alreadyUnlocked = new Set(existing.map((b) => b.badgeId));
    const ctx: BadgeEvalContext = {
      uid,
      allRuns,
      alreadyUnlocked,
      reportTrigger,
    };

    const newlyUnlocked: Badge[] = [];
    let skipped = 0;
    for (const def of BADGE_DEFINITIONS) {
      if (alreadyUnlocked.has(def.badgeId)) {
        skipped++;
        continue;
      }
      const res = def.evaluate(ctx);
      if (!res) continue;
      const badge: Badge = {
        badgeId: def.badgeId,
        category: def.category,
        title: def.title,
        subtitle: def.subtitle,
        description: def.description,
        primaryDisplay: res.primaryDisplay,
        primaryUnit: res.primaryUnit,
        badgeChip: res.badgeChip,
        unlockedAt: Date.now(),
        context: res.context,
        stats: res.stats,
        seen: false,
        shareCount: 0,
      };
      await this.badges.save(uid, badge);
      newlyUnlocked.push(badge);
      alreadyUnlocked.add(def.badgeId);
    }

    return { unlocked: newlyUnlocked, skipped };
  }

  private async fetchRunsAsc(uid: string): Promise<Run[]> {
    // Pegamos um período largo (1 ano) — pra eval retroativo, pega lifetime.
    const oneYearAgo = new Date(Date.now() - 365 * 24 * 60 * 60 * 1000);
    const now = new Date(Date.now() + 24 * 60 * 60 * 1000);
    const runs = await this.runs.findByDateRange(uid, oneYearAgo, now);
    // Só considera corridas VÁLIDAS — mesmo critério do stats: ≥30s e ≥100m.
    // Sem isso, corrida-fantasma (user abriu e fechou) virava "primeira
    // corrida" em badge.
    return runs
      .filter((r) => r.status === 'completed')
      .filter((r) => (r.durationS ?? 0) >= 30 && (r.distanceM ?? 0) >= 100)
      .sort((a, b) => new Date(a.createdAt as string).getTime() - new Date(b.createdAt as string).getTime());
  }
}
