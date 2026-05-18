import { getFirestore } from '@shared/infra/firebase/firebase.client';
import { CoachReport } from '../domain/coach-report.entity';
import { CoachReportRepository } from '../domain/coach-report.repository';

export class FirestoreCoachReportRepository implements CoachReportRepository {
  private doc = (userId: string, runId: string) =>
    getFirestore()
      .collection(`users/${userId}/runs/${runId}/reports`)
      .doc(runId);

  async findByRunId(userId: string, runId: string): Promise<CoachReport | null> {
    const snap = await this.doc(userId, runId).get();
    if (!snap.exists) return null;
    return this.mapToReport(userId, runId, snap.data() ?? {});
  }

  async findByRunIds(userId: string, runIds: string[]): Promise<CoachReport[]> {
    if (runIds.length === 0) return [];
    const db = getFirestore();
    const docRefs = runIds.map((runId) => this.doc(userId, runId));
    const snapshots = await db.getAll(...docRefs);
    return snapshots
      .filter((s) => s.exists)
      .map((s) => this.mapToReport(userId, s.id, s.data() ?? {}));
  }

  /**
   * Two-phase save: fase A (summary_ready) grava `set` substituindo o doc;
   * fase B (enriched) usa merge pra acrescentar sections + status sem
   * perder o summary já gravado.
   */
  async save(report: CoachReport): Promise<void> {
    const { runId, userId, sections, ...rest } = report;
    const payload: Record<string, unknown> = { ...rest };
    if (sections) payload['sections'] = sections;
    await this.doc(userId, runId).set(payload, { merge: true });
  }

  private mapToReport(userId: string, runId: string, data: FirebaseFirestore.DocumentData): CoachReport {
    const sectionsRaw = data['sections'];
    const sections = sectionsRaw && typeof sectionsRaw === 'object'
      ? {
          runAnalysis: String(sectionsRaw['runAnalysis'] ?? ''),
          planEvolution: String(sectionsRaw['planEvolution'] ?? ''),
          nextSessions: String(sectionsRaw['nextSessions'] ?? ''),
          recommendations: String(sectionsRaw['recommendations'] ?? ''),
        }
      : undefined;
    return {
      runId,
      userId,
      summary: data['summary'] ?? '',
      status: (data['status'] ?? 'pending') as CoachReport['status'],
      generatedAt: data['generatedAt'] ?? '',
      sections,
      enrichedAt: data['enrichedAt'],
    };
  }
}
