/**
 * Métricas TECH consolidadas pra aba do admin: saúde dos serviços
 * (healthz ao vivo), erros 24h/7d (de `system/errors/daily`, alimentado
 * pelo wrapper do logger) e custo LLM (reusa GetLlmUsageUseCase).
 */
import { getFirestore } from '@shared/infra/firebase/firebase.client';
import { GetLlmUsageUseCase } from './get-llm-usage.use-case';

export interface ServiceHealth {
  name: string;
  url: string;
  ok: boolean;
  latencyMs: number | null;
  error?: string;
}

export interface ErrorsDay {
  date: string;
  total: number;
  byService: Record<string, number>;
  byMessageKey: Record<string, number>;
}

export interface TechMetrics {
  computedAt: string;
  services: ServiceHealth[];
  errors: { today: ErrorsDay | null; last7d: ErrorsDay[]; total7d: number };
  llmCost: { todayUsd: number; last7dUsd: number };
}

const HEALTH_TARGETS: { name: string; url: string }[] = [
  { name: 'runnin-api', url: process.env['SELF_BASE_URL'] ?? 'https://runnin-api-rogiz7losq-rj.a.run.app' },
  { name: 's6-ai', url: process.env['S6_AI_BASE_URL'] ?? 'https://runnin-s6-ai-rogiz7losq-rj.a.run.app' },
];

export class GetTechMetricsUseCase {
  private llmUsage = new GetLlmUsageUseCase();

  async execute(): Promise<TechMetrics> {
    const [services, errors, llmCost] = await Promise.all([
      this._checkHealth(),
      this._fetchErrors(),
      this._fetchLlmCost(),
    ]);
    return { computedAt: new Date().toISOString(), services, errors, llmCost };
  }

  private async _checkHealth(): Promise<ServiceHealth[]> {
    return Promise.all(
      HEALTH_TARGETS.map(async ({ name, url }) => {
        const start = Date.now();
        try {
          const ctrl = new AbortController();
          const timer = setTimeout(() => ctrl.abort(), 5000);
          const res = await fetch(`${url}/healthz`, { signal: ctrl.signal });
          clearTimeout(timer);
          return { name, url, ok: res.ok, latencyMs: Date.now() - start };
        } catch (err) {
          return { name, url, ok: false, latencyMs: null, error: String(err) };
        }
      }),
    );
  }

  private async _fetchErrors(): Promise<TechMetrics['errors']> {
    const today = new Date().toISOString().slice(0, 10);
    const from = new Date(Date.now() - 6 * 86_400_000).toISOString().slice(0, 10);
    const snap = await getFirestore()
      .collection('system').doc('errors').collection('daily')
      .where('date', '>=', from)
      .orderBy('date', 'desc')
      .limit(7)
      .get();
    const days: ErrorsDay[] = snap.docs.map((d) => {
      const data = d.data() as Partial<ErrorsDay>;
      return {
        date: data.date ?? d.id,
        total: data.total ?? 0,
        byService: data.byService ?? {},
        byMessageKey: data.byMessageKey ?? {},
      };
    });
    return {
      today: days.find((d) => d.date === today) ?? null,
      last7d: days,
      total7d: days.reduce((a, d) => a + d.total, 0),
    };
  }

  private async _fetchLlmCost(): Promise<TechMetrics['llmCost']> {
    const today = new Date().toISOString().slice(0, 10);
    const from = new Date(Date.now() - 6 * 86_400_000).toISOString().slice(0, 10);
    try {
      const breakdown = await this.llmUsage.execute({ range: { from, to: today } });
      const todayUsd = breakdown.byDay.find((d) => d.date === today)?.totalCostUsd ?? 0;
      return {
        todayUsd: Math.round(todayUsd * 10000) / 10000,
        last7dUsd: Math.round(breakdown.totals.costUsd * 10000) / 10000,
      };
    } catch {
      return { todayUsd: 0, last7dUsd: 0 };
    }
  }
}
