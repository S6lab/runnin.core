import { getFirestore } from '@shared/infra/firebase/firebase.client';
import { Plan, PlanWeek } from '@modules/plans/domain/plan.entity';
import { Run } from '@modules/runs/domain/run.entity';
import { UserProfile } from '@modules/users/domain/user.entity';
import { logger } from '@shared/logger/logger';

export interface CoachRuntimeContext {
  profile: Pick<UserProfile, 'name' | 'level' | 'goal' | 'frequency' | 'hasWearable' | 'coachVoiceId'> | null;
  currentPlan: {
    goal: string;
    level: string;
    weeksCount: number;
    status: string;
    currentWeek: PlanWeek | null;
  } | null;
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
}

export class CoachRuntimeContextService {
  async getContext(userId: string): Promise<CoachRuntimeContext> {
    try {
      const db = getFirestore();
      const [profileDoc, plansSnap, runsSnap, examsSnap] = await Promise.all([
        db.collection('users').doc(userId).get(),
        db.collection(`users/${userId}/plans`).get(),
        db.collection(`users/${userId}/runs`)
          .orderBy('createdAt', 'desc')
          .limit(8)
          .get(),
        db.collection(`users/${userId}/exams`)
          .where('deletedAt', '==', null)
          .orderBy('uploadedAt', 'desc')
          .limit(3)
          .get(),
      ]);

      const profile = profileDoc.exists
        ? ({ id: profileDoc.id, ...profileDoc.data() } as UserProfile)
        : null;

      const plan = latestPlan(plansSnap.docs.map(doc => ({
        id: doc.id,
        userId,
        ...doc.data(),
      }) as Plan));

      const runs = runsSnap.docs
        .map(doc => ({
          id: doc.id,
          userId,
          ...doc.data(),
        }) as Run)
        .filter(run => run.status === 'completed')
        .slice(0, 5);

      const exams = examsSnap.docs
        .map(doc => ({
          id: doc.id,
          userId,
          ...doc.data(),
        }) as any)
        .filter((exam: any) => exam.extractedData?.summary)
        .slice(0, 3);

      return {
        profile: profile
          ? {
              name: profile.name,
              level: profile.level,
              goal: profile.goal,
              frequency: profile.frequency,
              hasWearable: profile.hasWearable,
              coachVoiceId: profile.coachVoiceId,
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
        recentRuns: runs.map(run => ({
          type: run.type,
          distanceKm: Number((run.distanceM / 1000).toFixed(2)),
          durationMin: Math.round(run.durationS / 60),
          avgPace: run.avgPace,
          avgBpm: run.avgBpm,
          completedAt: run.completedAt ?? run.createdAt,
        })),
        recentExams: exams.map(exam => ({
          summary: exam.extractedData.summary,
          keyFindings: exam.extractedData.keyFindings || [],
          recommendations: exam.extractedData.recommendations || [],
          uploadedAt: exam.uploadedAt,
        })),
      };
    } catch (err) {
      logger.warn('coach.runtime_context.unavailable', {
        userId,
        err: err instanceof Error ? err.message : String(err),
      });
      return { profile: null, currentPlan: null, recentRuns: [], recentExams: [] };
    }
  }
}

function latestPlan(plans: Plan[]): Plan | null {
  if (plans.length === 0) return null;
  return [...plans].sort((a, b) => b.createdAt.localeCompare(a.createdAt))[0] ?? null;
}

function currentPlanWeek(plan: Plan): PlanWeek | null {
  if (plan.weeks.length === 0) return null;
  const createdAt = Date.parse(plan.createdAt);
  if (Number.isNaN(createdAt)) return plan.weeks[0] ?? null;
  const elapsedDays = Math.max(0, Math.floor((Date.now() - createdAt) / 86_400_000));
  const weekIndex = Math.min(Math.floor(elapsedDays / 7), plan.weeks.length - 1);
  return plan.weeks[weekIndex] ?? plan.weeks[0] ?? null;
}
