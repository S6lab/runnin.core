import { FieldPath } from 'firebase-admin/firestore';
import { getFirestore } from '@shared/infra/firebase/firebase.client';
import { logger } from '@shared/logger/logger';

/** Teto de docs por query de usage: 1 doc = 1 user×dia, então 5000 cobre
 *  ~166 users ativos num range de 30d. Evita query unbounded se a base
 *  crescer; pra mais que isso, mover pra BigQuery sink. */
const MAX_USAGE_DOCS = 5000;

/** Range de datas (YYYY-MM-DD, inclusive ambos extremos). */
export interface UsageRange {
  from: string;
  to: string;
}

export interface DailyUsage {
  date: string;
  totalInputTokens: number;
  totalOutputTokens: number;
  totalCalls: number;
  totalCostUsd: number;
  byModel: Record<string, ModelUsage>;
  byUseCase: Record<string, UseCaseUsage>;
}

export interface ModelUsage {
  input: number;
  output: number;
  calls: number;
  costUsd: number;
}

export interface UseCaseUsage {
  calls: number;
  costUsd: number;
}

export interface UsageBreakdown {
  totals: {
    inputTokens: number;
    outputTokens: number;
    calls: number;
    costUsd: number;
  };
  byDay: DailyUsage[];
  byModel: Record<string, ModelUsage>;
  byUseCase: Record<string, UseCaseUsage>;
}

export interface TopUser {
  userId: string;
  costUsd: number;
  calls: number;
  inputTokens: number;
  outputTokens: number;
}

/**
 * Lê `users/{uid}/llm_usage/{date}` no range [from, to] e agrega totais
 * + breakdowns. Quando `userId` é null, agrega TODOS os users (top users
 * + grand totals). Quando `userId` informado, retorna só esse user.
 *
 * Performance: Firestore collection group query atravessa todos os
 * subcollections `llm_usage` paginados; aceita até 30 dias × N users
 * sem problemas. Pra ranges maiores, mover pra BigQuery sink.
 */
export class GetLlmUsageUseCase {
  async execute(args: {
    range: UsageRange;
    userId?: string | null;
  }): Promise<UsageBreakdown> {
    const db = getFirestore();
    const docs = await this._fetchDocs(db, args);

    const byDay: DailyUsage[] = [];
    const byModel: Record<string, ModelUsage> = {};
    const byUseCase: Record<string, UseCaseUsage> = {};
    let totalsInput = 0;
    let totalsOutput = 0;
    let totalsCalls = 0;
    let totalsCost = 0;

    for (const d of docs) {
      const data = d.data() as DailyUsage;
      const date = data.date ?? d.id;
      if (date < args.range.from || date > args.range.to) continue;
      totalsInput += data.totalInputTokens ?? 0;
      totalsOutput += data.totalOutputTokens ?? 0;
      totalsCalls += data.totalCalls ?? 0;
      totalsCost += data.totalCostUsd ?? 0;
      byDay.push(data);
      for (const [m, u] of Object.entries(data.byModel ?? {})) {
        if (!byModel[m]) byModel[m] = { input: 0, output: 0, calls: 0, costUsd: 0 };
        byModel[m].input += u.input ?? 0;
        byModel[m].output += u.output ?? 0;
        byModel[m].calls += u.calls ?? 0;
        byModel[m].costUsd += u.costUsd ?? 0;
      }
      for (const [k, u] of Object.entries(data.byUseCase ?? {})) {
        if (!byUseCase[k]) byUseCase[k] = { calls: 0, costUsd: 0 };
        byUseCase[k].calls += u.calls ?? 0;
        byUseCase[k].costUsd += u.costUsd ?? 0;
      }
    }
    byDay.sort((a, b) => a.date.localeCompare(b.date));
    return {
      totals: {
        inputTokens: totalsInput,
        outputTokens: totalsOutput,
        calls: totalsCalls,
        costUsd: totalsCost,
      },
      byDay,
      byModel,
      byUseCase,
    };
  }

  /** Top N users por custo total no range. */
  async topUsers(range: UsageRange, limit = 20): Promise<TopUser[]> {
    const db = getFirestore();
    // Collection group query atravessa TODOS os subcollections `llm_usage`
    // de TODOS os users. Filtra por date no range.
    const snap = await db.collectionGroup('llm_usage')
      .where('date', '>=', range.from)
      .where('date', '<=', range.to)
      .limit(MAX_USAGE_DOCS)
      .get();

    const byUser = new Map<string, TopUser>();
    for (const d of snap.docs) {
      const data = d.data() as DailyUsage;
      // Path: users/{uid}/llm_usage/{date}
      const userId = d.ref.parent.parent?.id;
      if (!userId) continue;
      const acc = byUser.get(userId) ?? {
        userId, costUsd: 0, calls: 0, inputTokens: 0, outputTokens: 0,
      };
      acc.costUsd += data.totalCostUsd ?? 0;
      acc.calls += data.totalCalls ?? 0;
      acc.inputTokens += data.totalInputTokens ?? 0;
      acc.outputTokens += data.totalOutputTokens ?? 0;
      byUser.set(userId, acc);
    }
    return [...byUser.values()]
      .sort((a, b) => b.costUsd - a.costUsd)
      .slice(0, limit);
  }

  /** Custo de chamadas SYSTEM (crons, sem userId) no range. */
  async systemUsage(range: UsageRange): Promise<UsageBreakdown> {
    const db = getFirestore();
    // Doc id = YYYY-MM-DD: range por documentId em vez de fetch-all.
    const snap = await db.collection('system').doc('llm_usage')
      .collection('daily')
      .where(FieldPath.documentId(), '>=', range.from)
      .where(FieldPath.documentId(), '<=', range.to)
      .get();
    const docs = snap.docs;
    return this._aggregate(docs, range);
  }

  private async _fetchDocs(
    db: FirebaseFirestore.Firestore,
    args: { range: UsageRange; userId?: string | null },
  ): Promise<FirebaseFirestore.QueryDocumentSnapshot[]> {
    if (args.userId) {
      // Doc id = YYYY-MM-DD: range por documentId evita ler o histórico
      // inteiro do user (query era unbounded).
      const snap = await db.collection('users').doc(args.userId)
        .collection('llm_usage')
        .where(FieldPath.documentId(), '>=', args.range.from)
        .where(FieldPath.documentId(), '<=', args.range.to)
        .get();
      return snap.docs;
    }
    // All users via collection group
    try {
      const snap = await db.collectionGroup('llm_usage')
        .where('date', '>=', args.range.from)
        .where('date', '<=', args.range.to)
        .limit(MAX_USAGE_DOCS)
        .get();
      return snap.docs.filter((d) => d.ref.parent.parent?.parent?.id === 'users');
    } catch (err) {
      logger.warn('admin.usage.collection_group_failed', {
        err: err instanceof Error ? err.message : String(err),
      });
      return [];
    }
  }

  private _aggregate(
    docs: FirebaseFirestore.QueryDocumentSnapshot[],
    range: UsageRange,
  ): UsageBreakdown {
    const byDay: DailyUsage[] = [];
    const byModel: Record<string, ModelUsage> = {};
    const byUseCase: Record<string, UseCaseUsage> = {};
    let totalsInput = 0;
    let totalsOutput = 0;
    let totalsCalls = 0;
    let totalsCost = 0;
    for (const d of docs) {
      const data = d.data() as DailyUsage;
      const date = data.date ?? d.id;
      if (date < range.from || date > range.to) continue;
      totalsInput += data.totalInputTokens ?? 0;
      totalsOutput += data.totalOutputTokens ?? 0;
      totalsCalls += data.totalCalls ?? 0;
      totalsCost += data.totalCostUsd ?? 0;
      byDay.push(data);
      for (const [m, u] of Object.entries(data.byModel ?? {})) {
        if (!byModel[m]) byModel[m] = { input: 0, output: 0, calls: 0, costUsd: 0 };
        byModel[m].input += u.input ?? 0;
        byModel[m].output += u.output ?? 0;
        byModel[m].calls += u.calls ?? 0;
        byModel[m].costUsd += u.costUsd ?? 0;
      }
      for (const [k, u] of Object.entries(data.byUseCase ?? {})) {
        if (!byUseCase[k]) byUseCase[k] = { calls: 0, costUsd: 0 };
        byUseCase[k].calls += u.calls ?? 0;
        byUseCase[k].costUsd += u.costUsd ?? 0;
      }
    }
    byDay.sort((a, b) => a.date.localeCompare(b.date));
    return {
      totals: { inputTokens: totalsInput, outputTokens: totalsOutput, calls: totalsCalls, costUsd: totalsCost },
      byDay, byModel, byUseCase,
    };
  }
}
