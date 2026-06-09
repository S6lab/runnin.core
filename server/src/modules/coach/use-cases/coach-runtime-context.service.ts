import { getFirestore } from '@shared/infra/firebase/firebase.client';
import { Plan, PlanSession, PlanWeek, effectivePlanWeeks } from '@modules/plans/domain/plan.entity';
import { Run } from '@modules/runs/domain/run.entity';
import { UserProfile } from '@modules/users/domain/user.entity';
import { logger } from '@shared/logger/logger';

export type CoachRuntimeProfile = Pick<
  UserProfile,
  | 'name'
  | 'level'
  | 'goal'
  | 'frequency'
  | 'hasWearable'
  | 'coachVoiceId'
  | 'gender'
  | 'birthDate'
  | 'weight'
  | 'height'
  | 'runPeriod'
  | 'wakeTime'
  | 'sleepTime'
  | 'restingBpm'
  | 'maxBpm'
  | 'medicalConditions'
  | 'coachPersonality'
  | 'coachMessageFrequency'
  | 'coachFeedbackEnabled'
  | 'allowCriticalAlertsInSilent'
  | 'preRunAlerts'
  | 'dndWindow'
  | 'unitsSystem'
  | 'paceFormat'
>;

export interface CoachRuntimeContext {
  profile: CoachRuntimeProfile | null;
  currentPlan: {
    goal: string;
    level: string;
    weeksCount: number;
    status: string;
    currentWeek: PlanWeek | null;
  } | null;
  /** Sessão planejada referente à run em andamento. Setada quando o
   *  cliente passa `planSessionId` no payload — server resolve via
   *  lookup no plano vigente. Carrega o briefing completo (notes,
   *  segments, nutrição, hidratação) que o LLM usa pra contextualizar
   *  intervenções estruturais (segment_start, segment_pace_off, finish).
   *  Null quando run é Free Run ou planSessionId inválido. */
  currentSession: PlanSession | null;
  recentRuns: Array<{
    type: string;
    distanceKm: number;
    durationMin: number;
    avgPace?: string;
    avgBpm?: number;
    completedAt?: string;
  }>;
  recentExams?: Array<{
    summary: string;
    keyFindings: string[];
    recommendations: string[];
    uploadedAt?: string;
  }>;
  runningKnowledgeContext?: {
    name: 'recent_exams';
    description: string;
    chunks: Array<{
      relevanceScore?: number;
      text: string;
      metadata: {
        examId?: string;
        examType?: string;
        uploadedAt?: string;
      };
    }>;
  };
}

export class CoachRuntimeContextService {
  async getContext(userId: string, planSessionId?: string): Promise<CoachRuntimeContext> {
    try {
      const db = getFirestore();
      // Cada fetch é INDEPENDENTE. Antes era Promise.all com try/catch
      // global → se EXAMS falhava por índice ausente, profile vinha null
      // e o coach gerava plano genérico ("perfil não fornecido"). Agora
      // cada um falha isolado e mantemos o resto.
      const safeFetch = async <T>(label: string, fn: () => Promise<T>, fallback: T): Promise<T> => {
        try { return await fn(); }
        catch (err) {
          logger.warn('coach.runtime_context.partial', {
            userId, what: label,
            err: err instanceof Error ? err.message : String(err),
          });
          return fallback;
        }
      };
      const [profileDoc, plansSnap, runsSnap, examsSnap, ragSnap] = await Promise.all([
        safeFetch('profile', () => db.collection('users').doc(userId).get(), null as any),
        safeFetch('plans', () => db.collection(`users/${userId}/plans`).get(), { docs: [] } as any),
        safeFetch('runs', () => db.collection(`users/${userId}/runs`)
          .orderBy('createdAt', 'desc')
          .limit(8)
          .get(), { docs: [] } as any),
        safeFetch('exams', () => db.collection(`users/${userId}/exams`)
          .where('deletedAt', '==', null)
          .orderBy('uploadedAt', 'desc')
          .limit(3)
          .get(), { docs: [] } as any),
        safeFetch('rag_chunks', () => db.collection(`users/${userId}/rag_chunks`).orderBy('updatedAt', 'desc').limit(5).get(), { docs: [] } as any),
      ]);
      // Se profile falhou de vez, sai com profile=null mas mantemos
      // arrays vazios pro resto.
      if (!profileDoc) {
        return { profile: null, currentPlan: null, currentSession: null, recentRuns: [], recentExams: [] };
      }

      const profile = profileDoc.exists
        ? ({ id: profileDoc.id, ...profileDoc.data() } as UserProfile)
        : null;

      const plan = latestPlan(
        (plansSnap.docs as Array<{ id: string; data: () => Record<string, unknown> }>).map((doc) => ({
          id: doc.id,
          userId,
          ...doc.data(),
        }) as Plan)
      );

      // Lookup da sessão específica que está sendo executada na run atual.
      // Procura por id em qualquer semana do plano vigente. Se não achar,
      // currentSession fica null e o prompt cai no fallback genérico.
      const currentSession = planSessionId && plan
        ? findSessionById(plan, planSessionId)
        : null;

      const runs: Run[] = (runsSnap.docs as Array<{ id: string; data: () => Record<string, unknown> }>)
        .map((doc) => ({
          id: doc.id,
          userId,
          ...doc.data(),
        }) as Run)
        .filter((run: Run) => run.status === 'completed')
        .slice(0, 5);

      type ExamShape = { extractedData: { summary?: string; keyFindings?: unknown[]; recommendations?: unknown[] }; uploadedAt?: string };
      const exams: ExamShape[] = (examsSnap.docs as Array<{ id: string; data: () => Record<string, unknown> }>)
        .map((doc) => ({
          id: doc.id,
          userId,
          ...doc.data(),
        }) as unknown as ExamShape)
        .filter((exam) => exam.extractedData?.summary)
        .slice(0, 3);

      const ragChunks = (ragSnap.docs as Array<{ data: () => Record<string, unknown> }>).map((doc) => {
        const d = doc.data();
        return {
          text: (d.text as string) ?? '',
          embedding: d.embedding as number[] | undefined,
          updatedAt: d.updatedAt as string | undefined,
          examId: d.examId as string | undefined,
        };
      });

      return {
        profile: profile
          ? {
              name: profile.name,
              level: profile.level,
              goal: profile.goal,
              frequency: profile.frequency,
              hasWearable: profile.hasWearable,
              coachVoiceId: profile.coachVoiceId,
              gender: profile.gender,
              birthDate: profile.birthDate,
              weight: profile.weight,
              height: profile.height,
              runPeriod: profile.runPeriod,
              wakeTime: profile.wakeTime,
              sleepTime: profile.sleepTime,
              restingBpm: profile.restingBpm,
              maxBpm: profile.maxBpm,
              medicalConditions: profile.medicalConditions,
              coachPersonality: profile.coachPersonality,
              coachMessageFrequency: profile.coachMessageFrequency,
              coachFeedbackEnabled: profile.coachFeedbackEnabled,
              allowCriticalAlertsInSilent: profile.allowCriticalAlertsInSilent,
              preRunAlerts: profile.preRunAlerts,
              dndWindow: profile.dndWindow,
              unitsSystem: profile.unitsSystem,
              paceFormat: profile.paceFormat,
            }
          : null,
        currentPlan: plan
          ? {
              goal: plan.goal,
              level: plan.level,
              weeksCount: plan.weeksCount,
              status: plan.status,
              currentWeek: currentPlanWeek(plan),
            }
          : null,
        currentSession,
        recentRuns: runs.map((run: Run) => ({
          type: run.type,
          distanceKm: Number((run.distanceM / 1000).toFixed(2)),
          durationMin: Math.round(run.durationS / 60),
          avgPace: run.avgPace,
          avgBpm: run.avgBpm,
          completedAt: (run as { completedAt?: string }).completedAt ?? run.createdAt,
        })),
        recentExams: exams.map((exam) => ({
          summary: exam.extractedData.summary ?? '',
          keyFindings: (exam.extractedData.keyFindings ?? []) as string[],
          recommendations: (exam.extractedData.recommendations ?? []) as string[],
          uploadedAt: exam.uploadedAt ?? '',
        })),
        runningKnowledgeContext: {
          name: 'recent_exams',
          description: 'Exames médicos recentes do usuário extraídos via OCR e RAG',
          chunks: ragChunks.map((chunk: { text: string; updatedAt?: string; examId?: string }) => ({
            relevanceScore: 0.9,
            text: chunk.text,
            metadata: {
              examId: chunk.examId,
              uploadedAt: chunk.updatedAt,
            },
          })),
        },
      };
    } catch (err) {
      logger.warn('coach.runtime_context.unavailable', {
        userId,
        err: err instanceof Error ? err.message : String(err),
      });
      return { profile: null, currentPlan: null, currentSession: null, recentRuns: [], recentExams: [] };
    }
  }
}

function findSessionById(plan: Plan, sessionId: string): PlanSession | null {
  // Olha primeiro o vigente (pode ter sido ajustado); cai pra base se não achar
  // (revisão pode ter removido a sessão, mas o link da run aponta pra ela).
  for (const week of effectivePlanWeeks(plan)) {
    const session = week.sessions.find((s) => s.id === sessionId);
    if (session) return session;
  }
  if (plan.adjustedWeeks && plan.adjustedWeeks.length > 0) {
    for (const week of plan.weeks) {
      const session = week.sessions.find((s) => s.id === sessionId);
      if (session) return session;
    }
  }
  return null;
}

function latestPlan(plans: Plan[]): Plan | null {
  if (plans.length === 0) return null;
  return [...plans].sort((a, b) => b.createdAt.localeCompare(a.createdAt))[0] ?? null;
}

function currentPlanWeek(plan: Plan): PlanWeek | null {
  const weeks = effectivePlanWeeks(plan);
  if (weeks.length === 0) return null;
  const createdAt = Date.parse(plan.createdAt);
  if (Number.isNaN(createdAt)) return weeks[0] ?? null;
  const elapsedDays = Math.max(0, Math.floor((Date.now() - createdAt) / 86_400_000));
  const weekIndex = Math.min(Math.floor(elapsedDays / 7), weeks.length - 1);
  return weeks[weekIndex] ?? weeks[0] ?? null;
}
