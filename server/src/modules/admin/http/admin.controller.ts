import { Request, Response, NextFunction } from 'express';
import { z } from 'zod';
import { getAsyncLLM } from '@shared/infra/llm/llm.factory';
import {
  buildPlanInitPrompt,
  buildPlanRevisionPrompt,
  buildLiveCoachPrompt,
  buildPostRunReportPrompt,
  buildPeriodAnalysisPrompt,
  buildCoachChatPrompt,
  buildExamAnalysisPrompt,
  getDefaultsSnapshot,
  invalidatePromptsCache,
  type BuiltPrompt,
} from '@shared/infra/llm/prompts';

const PreviewSchema = z.object({
  builder: z.enum([
    'plan-init',
    'plan-revision',
    'live-coach',
    'post-run-report',
    'period-analysis',
    'coach-chat',
    'exam-analysis',
  ]),
  /** When true, runs the LLM with the compiled prompt and returns its output too. */
  runLlm: z.boolean().optional().default(false),
  /** Optional fixture override; otherwise uses canonical fixture. */
  fixture: z.record(z.string(), z.any()).optional(),
});

const FIXTURE_PROFILE = {
  name: 'João Atleta',
  level: 'intermediario' as const,
  goal: 'Sub 50min nos 10K',
  frequency: 4,
  hasWearable: true,
  gender: 'male' as const,
  birthDate: '1990-05-12',
  weight: '72kg',
  height: '178cm',
  runPeriod: 'manha' as const,
  restingBpm: 55,
  maxBpm: 188,
  medicalConditions: [],
  coachPersonality: 'motivador' as const,
  coachMessageFrequency: 'per_km' as const,
  coachFeedbackEnabled: { pace: true, bpm: true, motivation: true },
};

async function buildByName(builder: string, _fixture: Record<string, unknown> | undefined): Promise<BuiltPrompt> {
  const ragContext = '[KB1] Treino aeróbico em zona 2 prioriza adaptação cardiovascular.\n[KB2] Recuperação ativa acelera resposta neuromuscular.';
  switch (builder) {
    case 'plan-init':
      return buildPlanInitPrompt({
        profile: FIXTURE_PROFILE,
        input: { goal: 'Sub 50min nos 10K', level: 'intermediario', frequency: 4, weeksCount: 8 },
        ragContext,
      });
    case 'plan-revision':
      return buildPlanRevisionPrompt({
        profile: FIXTURE_PROFILE,
        plan: { goal: 'Sub 50min nos 10K', level: 'intermediario', weeksCount: 8, weeks: [] },
        revision: { type: 'more_load', subOption: '+5km/semana', freeText: '' },
        ragContext,
      });
    case 'live-coach':
      return buildLiveCoachPrompt({
        profile: FIXTURE_PROFILE,
        runtimeContextJson: '{"plan":"semana 3 / Easy Run"}',
        ctx: { event: 'km_reached', runType: 'Easy Run', currentPaceMinKm: 5.4, targetPaceMinKm: 5.5, distanceM: 3000, elapsedS: 970, bpm: 152, kmReached: 3 },
        ragContext,
      });
    case 'post-run-report':
      return buildPostRunReportPrompt({
        profile: FIXTURE_PROFILE,
        run: { summary: '- Tipo: Easy Run\n- Distância: 8.00km\n- Duração: 45 minutos\n- Pace médio: 5:38/km' },
        planContext: 'Plano: Sub 50min nos 10K (intermediario, semana atual 3)',
        recentRunsContext: 'Easy Run 6km em 34min; Long Run 12km em 1h12min',
        ragContext,
      });
    case 'period-analysis':
      return buildPeriodAnalysisPrompt({
        profile: FIXTURE_PROFILE,
        period: {
          range: '10 corridas (62 km totais)',
          metrics: '- Quantidade: 10\n- Distância: 62km\n- BPM médio: 148',
          runs: '- 2026-05-01: 8km em 45min\n- 2026-05-04: 5km em 28min',
        },
        ragContext,
      });
    case 'coach-chat':
      return buildCoachChatPrompt({
        profile: FIXTURE_PROFILE,
        question: 'Posso correr hoje mesmo com a perna um pouco dolorida?',
        planContext: 'Plano: Sub 50min nos 10K, semana 3',
        recentRunsContext: 'Easy 6km ontem',
        ragContext,
      });
    case 'exam-analysis':
      return buildExamAnalysisPrompt({
        profile: FIXTURE_PROFILE,
        schema: '{ "summary": string, ... }',
      });
    default:
      throw new Error(`Unknown builder: ${builder}`);
  }
}

export async function postPromptPreview(req: Request, res: Response, next: NextFunction): Promise<void> {
  try {
    const input = PreviewSchema.parse(req.body);
    // Always invalidate before preview so admin sees latest Firestore overrides immediately
    invalidatePromptsCache();

    const built = await buildByName(input.builder, input.fixture);

    let llmOutput: string | undefined;
    if (input.runLlm) {
      const llm = getAsyncLLM();
      llmOutput = await llm.generate(built.userPrompt, {
        systemPrompt: built.systemPrompt,
        maxTokens: Math.min(built.maxTokens, 800),
        temperature: built.temperature,
      });
    }

    res.json({
      systemPrompt: built.systemPrompt,
      userPrompt: built.userPrompt,
      maxTokens: built.maxTokens,
      temperature: built.temperature,
      version: built.version,
      source: built.source,
      llmOutput,
    });
  } catch (err) {
    next(err);
  }
}

export async function getPromptDefaults(_req: Request, res: Response, next: NextFunction): Promise<void> {
  try {
    res.json(getDefaultsSnapshot());
  } catch (err) {
    next(err);
  }
}

export function postInvalidateCache(_req: Request, res: Response): void {
  invalidatePromptsCache();
  res.json({ ok: true });
}

// === Admin: gerenciamento de plano de usuário ===
import { FirestoreUserRepository } from '@modules/users/infra/firestore-user.repository';
import { getAuth, getFirestore } from '@shared/infra/firebase/firebase.client';
import { SeedTesterUseCase } from '../use-cases/seed-tester.use-case';
import {
  invalidateRunningKnowledgeStorageCache,
  getRunningKnowledgeCorpusWithStorage,
} from '@shared/knowledge/running/running-knowledge';

const userRepo = new FirestoreUserRepository();
const seedTester = new SeedTesterUseCase();

const SeedTesterSchema = z.object({
  phone: z.string().optional(),
  email: z.string().email().optional(),
  uid: z.string().optional(),
}).refine(v => v.phone || v.email || v.uid, {
  message: 'phone, email ou uid obrigatório',
});

/**
 * POST /admin/diagnose/reset-journey?email=X — apaga planos, reseta
 * onboarded=false (mantém dados do perfil) e revoga refresh tokens pra
 * forçar re-login. User vai passar por: login → onboarding (campos pré
 * preenchidos) → paywall → plan-loading → plano gerado com prompt atual.
 */
export async function postDiagnoseResetJourney(req: Request, res: Response, next: NextFunction): Promise<void> {
  try {
    const email = (req.query.email as string | undefined)?.trim();
    if (!email) {
      res.status(400).json({ error: 'email query param required' });
      return;
    }
    const auth = getAuth();
    const db = getFirestore();
    const user = await auth.getUserByEmail(email);

    // 1. Apaga planos
    const plansCol = db.collection(`users/${user.uid}/plans`);
    const plansSnap = await plansCol.get();
    const batch = db.batch();
    plansSnap.docs.forEach(d => batch.delete(d.ref));
    await batch.commit();

    // 2. Reset onboarded + planRevisions quota
    await db.collection('users').doc(user.uid).set({
      onboarded: false,
      planRevisions: { usedThisWeek: 0, max: 1, resetAt: new Date().toISOString() },
      updatedAt: new Date().toISOString(),
    }, { merge: true });

    // 3. Revoga refresh tokens (força re-auth no próximo request)
    await auth.revokeRefreshTokens(user.uid);

    res.json({
      ok: true,
      uid: user.uid,
      plansDeleted: plansSnap.size,
      onboardedReset: true,
      tokensRevoked: true,
      note: 'User precisa fechar app + abrir de novo (ou hard refresh no web) pra cair em /login.',
    });
  } catch (err) {
    next(err);
  }
}

/**
 * POST /admin/diagnose/regenerate-plan?email=X — força regerar o plano do
 * user com o prompt atual. Bypassa cooldown. Útil pra testar mudanças no
 * prompt em produção. Protegido por X-Cron-Token.
 */
export async function postDiagnoseRegeneratePlan(req: Request, res: Response, next: NextFunction): Promise<void> {
  try {
    const email = (req.query.email as string | undefined)?.trim();
    if (!email) {
      res.status(400).json({ error: 'email query param required' });
      return;
    }
    const auth = getAuth();
    const db = getFirestore();
    const user = await auth.getUserByEmail(email);
    const profileSnap = await db.collection('users').doc(user.uid).get();
    const profile = profileSnap.data();
    if (!profile?.goal || !profile?.level) {
      res.status(400).json({ error: 'user has incomplete profile (no goal/level)' });
      return;
    }
    // Apaga plano atual pra evitar checagem de cooldown
    const plansCol = db.collection(`users/${user.uid}/plans`);
    const existing = await plansCol.get();
    const batch = db.batch();
    existing.docs.forEach(d => batch.delete(d.ref));
    await batch.commit();

    // Importa lazy pra evitar circular
    const { GeneratePlanUseCase } = await import(
      '@modules/plans/use-cases/generate-plan.use-case'
    );
    const { FirestorePlanRepository } = await import(
      '@modules/plans/infra/firestore-plan.repository'
    );
    const repo = new FirestorePlanRepository();
    const uc = new GeneratePlanUseCase(repo);
    const plan = await uc.execute(user.uid, {
      goal: profile.goal,
      level: profile.level,
      frequency: profile.frequency,
      weeksCount: 8,
    });
    res.json({
      ok: true,
      planId: plan.id,
      status: plan.status,
      note: 'Generation kicked off async. Polling /admin/diagnose/user em ~15-30s pra ver resultado.',
    });
  } catch (err) {
    next(err);
  }
}

/**
 * GET /admin/diagnose/user?email=X — devolve profile + último plano + stats
 * pra debug rápido sem precisar de ADC local. Protegido por X-Cron-Token.
 */
export async function getDiagnoseUser(req: Request, res: Response, next: NextFunction): Promise<void> {
  try {
    const email = (req.query.email as string | undefined)?.trim();
    if (!email) {
      res.status(400).json({ error: 'email query param required' });
      return;
    }
    const auth = getAuth();
    const db = getFirestore();
    const user = await auth.getUserByEmail(email);
    const profileSnap = await db.collection('users').doc(user.uid).get();
    const profile = profileSnap.exists ? profileSnap.data() : null;

    const plansSnap = await db
      .collection(`users/${user.uid}/plans`)
      .orderBy('createdAt', 'desc')
      .limit(1)
      .get();
    let planDigest: Record<string, unknown> | null = null;
    if (!plansSnap.empty) {
      const planData = plansSnap.docs[0].data() ?? {};
      const weeks = (planData.weeks ?? []) as Array<{
        weekNumber: number;
        narrative?: string;
        sessions?: Array<{ dayOfWeek: number; type: string; distanceKm: number; targetPace?: string; notes?: string }>;
      }>;
      const counts: Record<string, number> = {};
      for (const w of weeks) {
        for (const s of w.sessions ?? []) {
          counts[s.type] = (counts[s.type] ?? 0) + 1;
        }
      }
      planDigest = {
        id: plansSnap.docs[0].id,
        goal: planData.goal,
        level: planData.level,
        weeksCount: planData.weeksCount,
        status: planData.status,
        createdAt: planData.createdAt,
        sessionTypeCounts: counts,
        hasMesocycleNarrative: !!planData.mesocycleNarrative,
        hasCoachRationale: !!planData.coachRationale,
        mesocycleNarrative: planData.mesocycleNarrative ?? null,
        coachRationaleSnippet: planData.coachRationale
          ? String(planData.coachRationale).slice(0, 600)
          : null,
        firstWeek: weeks[0] ? {
          narrative: weeks[0].narrative,
          sessions: weeks[0].sessions,
        } : null,
      };
    }

    res.json({
      uid: user.uid,
      email: user.email,
      phone: user.phoneNumber,
      profile,
      lastPlan: planDigest,
    });
  } catch (err) {
    next(err);
  }
}

export async function postSeedTester(req: Request, res: Response, next: NextFunction): Promise<void> {
  try {
    const input = SeedTesterSchema.parse(req.body);
    const result = await seedTester.execute(input);
    res.json({ ok: true, ...result });
  } catch (err) {
    next(err);
  }
}

const ListUsersQuery = z.object({
  search: z.string().trim().optional(),
  limit: z.coerce.number().int().min(1).max(200).optional().default(50),
});

// Catálogo aberto: aceita qualquer id de plano (validado contra Firestore
// depois). Limita string pra evitar abuse.
const SetUserPlanSchema = z.object({
  plan: z.string().min(2).max(40),
});

export async function getUsersList(req: Request, res: Response, next: NextFunction): Promise<void> {
  try {
    const { search, limit } = ListUsersQuery.parse(req.query);
    const all = await userRepo.list(limit);
    // Enriquece com email do Firebase Auth (perfil só guarda dados de treino).
    const ids = all.map(u => u.id).filter(Boolean);
    const emailById = new Map<string, string | undefined>();
    if (ids.length > 0) {
      try {
        const auth = getAuth();
        const chunks: string[][] = [];
        for (let i = 0; i < ids.length; i += 100) chunks.push(ids.slice(i, i + 100));
        for (const chunk of chunks) {
          const result = await auth.getUsers(chunk.map(uid => ({ uid })));
          for (const u of result.users) emailById.set(u.uid, u.email ?? undefined);
        }
      } catch (_) {/* enrichment best-effort */}
    }
    const term = (search ?? '').toLowerCase();
    const filtered = term
      ? all.filter(u =>
          (u.id ?? '').toLowerCase().includes(term) ||
          (emailById.get(u.id) ?? '').toLowerCase().includes(term) ||
          (u.name ?? '').toLowerCase().includes(term),
        )
      : all;
    res.json({
      users: filtered.map(u => ({
        id: u.id,
        email: emailById.get(u.id) ?? null,
        name: u.name ?? null,
        subscriptionPlanId: u.subscriptionPlanId ?? 'freemium',
        onboarded: u.onboarded ?? false,
        updatedAt: u.updatedAt ?? null,
      })),
    });
  } catch (err) {
    next(err);
  }
}

/**
 * POST /admin/rag/reindex — força re-leitura do bucket Storage + reindex
 * de embeddings. Chamar quando subir/remover arquivo .md no painel admin
 * (base é quase estática, então invalidação é manual).
 */
export async function postRagReindex(_req: Request, res: Response, next: NextFunction): Promise<void> {
  try {
    invalidateRunningKnowledgeStorageCache();
    // Força a próxima query a rebuildar imediatamente — pra admin ver feedback
    const chunks = await getRunningKnowledgeCorpusWithStorage();
    res.json({
      ok: true,
      totalChunks: chunks.length,
      withEmbedding: chunks.filter(c => c.embedding && c.embedding.length > 0).length,
      fromStorage: chunks.filter(c => c.storagePath).length,
      fromCorpus: chunks.filter(c => !c.storagePath).length,
    });
  } catch (err) {
    next(err);
  }
}

/**
 * GET /admin/rag/status — lista documentos da base RAG com status indexed/
 * pending, contagem de chunks por doc e timestamps.
 */
export async function getRagStatus(_req: Request, res: Response, next: NextFunction): Promise<void> {
  try {
    const db = getFirestore();
    const snap = await db.collection('rag_documents').limit(200).get();
    const docs = snap.docs.map(d => {
      const data = d.data();
      return {
        id: d.id,
        originalName: data.originalName ?? null,
        storagePath: data.storagePath ?? null,
        ragStatus: data.ragStatus ?? 'unknown',
        chunkCount: data.chunkCount ?? 0,
        uploadedAt: data.uploadedAt ?? null,
        indexedAt: data.indexedAt ?? null,
        uploadedByEmail: data.uploadedByEmail ?? null,
        size: data.size ?? null,
      };
    });
    // Também conta chunks que vieram do corpus estático embutido
    const chunks = await getRunningKnowledgeCorpusWithStorage();
    res.json({
      documents: docs,
      summary: {
        adminDocs: docs.length,
        indexed: docs.filter(d => d.ragStatus === 'indexed').length,
        pending: docs.filter(d => d.ragStatus === 'pending').length,
        totalChunksInUse: chunks.length,
        chunksWithEmbedding: chunks.filter(c => c.embedding && c.embedding.length > 0).length,
        builtinCorpusChunks: chunks.filter(c => !c.storagePath).length,
      },
    });
  } catch (err) {
    next(err);
  }
}

/**
 * POST /admin/users/:userId/reset?mode=plan|full — apaga dados do user e
 * força nova jornada. Auth admin.
 *  - mode=plan: zera só planos + onboarded=false. Histórico (runs) preserva.
 *  - mode=full: zera planos + runs + biometric_samples + coach_messages +
 *    reports + period-analysis + rag_chunks per-user. onboarded=false.
 * Sempre revoga refresh tokens pro user re-logar.
 */
export async function postUserReset(req: Request, res: Response, next: NextFunction): Promise<void> {
  try {
    const userId = req.params.userId;
    const mode = (req.query.mode as string | undefined) === 'full' ? 'full' : 'plan';
    if (!userId || typeof userId !== 'string') {
      res.status(400).json({ error: 'userId required' });
      return;
    }
    const auth = getAuth();
    const db = getFirestore();
    await auth.getUser(userId); // valida que existe

    const counts: Record<string, number> = {};

    // Apaga planos sempre
    const plansCol = db.collection(`users/${userId}/plans`);
    const plansSnap = await plansCol.get();
    let batch = db.batch();
    let opsInBatch = 0;
    const commitIfNeeded = async () => {
      if (opsInBatch >= 400) {
        await batch.commit();
        batch = db.batch();
        opsInBatch = 0;
      }
    };
    for (const d of plansSnap.docs) {
      batch.delete(d.ref);
      opsInBatch++;
      await commitIfNeeded();
    }
    counts.plans = plansSnap.size;

    if (mode === 'full') {
      // Subcollections que apagamos: runs (e nested gps_points/coach_messages/
      // reports), biometric_samples, period-analysis, rag_chunks, devices.
      const userScopedCols = [
        'runs',
        'biometric_samples',
        'period-analysis',
        'rag_chunks',
        'devices',
        'onboarding_history',
      ];
      for (const col of userScopedCols) {
        const snap = await db.collection(`users/${userId}/${col}`).get();
        for (const d of snap.docs) {
          // pra runs, também apaga nested subcollections
          if (col === 'runs') {
            const subCols = ['gps_points', 'coach_messages', 'reports'];
            for (const sc of subCols) {
              const subSnap = await d.ref.collection(sc).get();
              for (const sd of subSnap.docs) {
                batch.delete(sd.ref);
                opsInBatch++;
                await commitIfNeeded();
              }
            }
          }
          batch.delete(d.ref);
          opsInBatch++;
          await commitIfNeeded();
        }
        counts[col] = snap.size;
      }
    }
    if (opsInBatch > 0) await batch.commit();

    // Marca onboarded=false (mantém dados do perfil — user só re-passa UI)
    await db.collection('users').doc(userId).set({
      onboarded: false,
      planRevisions: { usedThisWeek: 0, max: 1, resetAt: new Date().toISOString() },
      updatedAt: new Date().toISOString(),
    }, { merge: true });

    // Revoga refresh tokens
    await auth.revokeRefreshTokens(userId);

    res.json({
      ok: true,
      userId,
      mode,
      deletedCounts: counts,
      onboardedReset: true,
      tokensRevoked: true,
    });
  } catch (err) {
    next(err);
  }
}

export async function patchUserPlan(req: Request, res: Response, next: NextFunction): Promise<void> {
  try {
    const userId = req.params.userId;
    if (!userId || typeof userId !== 'string') throw new Error('userId required');
    const { plan } = SetUserPlanSchema.parse(req.body);
    const existing = await userRepo.findById(userId);
    if (!existing) {
      res.status(404).json({ error: 'user_not_found' });
      return;
    }
    await userRepo.upsert({ ...existing, subscriptionPlanId: plan });
    res.json({ ok: true, userId, plan });
  } catch (err) {
    next(err);
  }
}
