import { Run } from '@modules/runs/domain/run.entity';
import { RunRepository } from '@modules/runs/domain/run.repository';
import { BADGE_DEFINITIONS } from '../domain/badge-definitions';
import { BadgeRepository } from '../domain/badge.repository';

export interface NextBadgeProgress {
  badgeId: string;
  category: string;
  title: string;
  subtitle: string;
  /** Valor atual numérico (km acumulados, dias de streak, melhor distância única). */
  current: number;
  /** Alvo numérico do badge. */
  target: number;
  /** [0, 1] — progresso atual. */
  progress: number;
  /** Texto pronto pra UI ("faltam 12 km", "faltam 3 dias"). */
  remaining: string;
  /** Unidade do display ('km', 'dias'). */
  unit: string;
}

/**
 * Calcula o próximo badge MAIS PRÓXIMO de desbloquear pro user. Filtra
 * categorias com progresso mensurável (cumulative distance, streak,
 * single-run distance) — first/pace/report ficam de fora porque são
 * binárias ou dependem de PR em uma run específica.
 *
 * Ordena por progresso DESC (quanto mais perto, mais relevante mostrar).
 * Retorna `null` se user já desbloqueou tudo OU ainda está longe demais
 * (progresso < 5% em todos).
 */
export class GetNextBadgeUseCase {
  constructor(
    private readonly runs: RunRepository,
    private readonly badges: BadgeRepository,
  ) {}

  async execute(uid: string): Promise<NextBadgeProgress | null> {
    const oneYearAgo = new Date(Date.now() - 365 * 24 * 60 * 60 * 1000);
    const now = new Date(Date.now() + 24 * 60 * 60 * 1000);
    const allRuns = (await this.runs.findByDateRange(uid, oneYearAgo, now))
      .filter((r) => r.status === 'completed')
      .filter((r) => (r.durationS ?? 0) >= 30 && (r.distanceM ?? 0) >= 100);

    const existing = await this.badges.listByUser(uid);
    const unlocked = new Set(existing.map((b) => b.badgeId));

    const totalKm = allRuns.reduce((s, r) => s + (r.distanceM ?? 0) / 1000, 0);
    const bestSingleKm = allRuns.reduce(
      (m, r) => Math.max(m, (r.distanceM ?? 0) / 1000),
      0,
    );
    const streak = currentStreakDays(allRuns);

    const candidates: NextBadgeProgress[] = [];

    for (const def of BADGE_DEFINITIONS) {
      if (unlocked.has(def.badgeId)) continue;
      const m = def.badgeId.match(/^cumulative_(\d+)k$/);
      if (m) {
        const target = parseInt(m[1]!, 10);
        candidates.push({
          badgeId: def.badgeId,
          category: def.category,
          title: def.title,
          subtitle: def.subtitle,
          current: round1(totalKm),
          target,
          progress: clamp01(totalKm / target),
          remaining: `faltam ${Math.max(0, round1(target - totalKm))} km`,
          unit: 'km',
        });
        continue;
      }
      const s = def.badgeId.match(/^single_run_(\d+)k$/);
      if (s) {
        const target = parseInt(s[1]!, 10);
        candidates.push({
          badgeId: def.badgeId,
          category: def.category,
          title: def.title,
          subtitle: def.subtitle,
          current: round1(bestSingleKm),
          target,
          progress: clamp01(bestSingleKm / target),
          remaining: `faltam ${Math.max(0, round1(target - bestSingleKm))} km em uma corrida`,
          unit: 'km',
        });
        continue;
      }
      const st = def.badgeId.match(/^streak_(\d+)_days$/);
      if (st) {
        const target = parseInt(st[1]!, 10);
        candidates.push({
          badgeId: def.badgeId,
          category: def.category,
          title: def.title,
          subtitle: def.subtitle,
          current: streak,
          target,
          progress: clamp01(streak / target),
          remaining: `faltam ${Math.max(0, target - streak)} dias seguidos`,
          unit: 'dias',
        });
        continue;
      }
      // first/pace/report: pulados (sem progresso mensurável aqui).
    }

    if (candidates.length === 0) return null;
    candidates.sort((a, b) => b.progress - a.progress);
    const top = candidates[0]!;
    // Se mais próximo está em < 5%, melhor não mostrar "PRÓXIMO: 1000K
    // acumulados" pra iniciante. Devolve null e UI esconde o card.
    if (top.progress < 0.05) return null;
    return top;
  }
}

function currentStreakDays(allRuns: Run[]): number {
  if (allRuns.length === 0) return 0;
  const days = new Set<string>();
  for (const r of allRuns) {
    const d = new Date(r.createdAt as string);
    if (Number.isNaN(d.getTime())) continue;
    days.add(d.toISOString().slice(0, 10));
  }
  let streak = 0;
  const today = new Date();
  for (let i = 0; i < 365; i++) {
    const check = new Date(today);
    check.setUTCDate(today.getUTCDate() - i);
    const key = check.toISOString().slice(0, 10);
    if (days.has(key)) streak++;
    else if (i === 0) continue;
    else break;
  }
  return streak;
}

function clamp01(v: number): number {
  if (!Number.isFinite(v)) return 0;
  return Math.max(0, Math.min(1, v));
}

function round1(v: number): number {
  return Math.round(v * 10) / 10;
}
