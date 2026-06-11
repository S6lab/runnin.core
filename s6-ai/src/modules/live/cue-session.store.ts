import { randomUUID } from 'node:crypto';
import { getFirestore } from '@shared/infra/firebase/firebase.client';
import { logger } from '@shared/logger/logger';
import { CueSession } from './cue-session';
import { LiveSessionContext, LiveSessionContextSchema, LiveSessionDoc } from './live-session.types';

/** TTL 8h — cobre ultramaratona com folga. */
const SESSION_TTL_MS = 8 * 60 * 60 * 1000;
const SWEEP_INTERVAL_MS = 60_000;

const COLLECTION = 'live_sessions';

/**
 * Estado quente das sessões Live (fila, buckets, preamble) em memória —
 * Cloud Run com max-instances=1 + session-affinity torna isso seguro no
 * v1; scale-out = Redis. O blob de contexto persiste no Firestore
 * (coleção interna do s6-ai) pra rehidratar após restart de instância.
 */
export class CueSessionStore {
  private sessions = new Map<string, CueSession>();
  private sweeper: NodeJS.Timeout | null = null;

  constructor(private readonly clock: () => number = () => Date.now()) {}

  startSweeper(): void {
    if (this.sweeper) return;
    this.sweeper = setInterval(() => this.sweep(), SWEEP_INTERVAL_MS);
    this.sweeper.unref();
  }

  stopSweeper(): void {
    if (this.sweeper) clearInterval(this.sweeper);
    this.sweeper = null;
  }

  /** Cria sessão nova: estado em memória + doc Firestore pra rehidratação. */
  async create(context: LiveSessionContext): Promise<CueSession> {
    const id = randomUUID();
    const session = new CueSession(id, context, this.clock);
    this.sessions.set(id, session);

    const now = this.clock();
    const doc: LiveSessionDoc = {
      id,
      context,
      mode: 'planned',
      createdAt: new Date(now).toISOString(),
      expiresAt: new Date(now + SESSION_TTL_MS).toISOString(),
    };
    try {
      await getFirestore().collection(COLLECTION).doc(id).set(doc);
    } catch (err) {
      // Sessão segue funcional em memória; só perde rehidratação pós-restart.
      logger.warn('live.session.persist_failed', { sessionId: id, err: String(err) });
    }
    logger.info('live.session.created', { sessionId: id, userId: context.userId });
    return session;
  }

  get(id: string): CueSession | null {
    const s = this.sessions.get(id) ?? null;
    if (s) s.touch();
    return s;
  }

  /**
   * Busca em memória; em miss (restart de instância), rehidrata do
   * Firestore. Fila/buckets recomeçam zerados — dedup por bucket é
   * reconstruído conforme os próximos eventos chegam.
   */
  async getOrRehydrate(id: string): Promise<CueSession | null> {
    const hot = this.get(id);
    if (hot) return hot;
    try {
      const snap = await getFirestore().collection(COLLECTION).doc(id).get();
      if (!snap.exists) return null;
      const doc = snap.data() as LiveSessionDoc;
      if (new Date(doc.expiresAt).getTime() < this.clock()) return null;
      const context = LiveSessionContextSchema.parse(doc.context);
      const session = new CueSession(id, context, this.clock);
      if (doc.mode === 'free') session.switchToFreeMode();
      if (doc.queueSnapshot) {
        session.queue.restore(doc.queueSnapshot as Parameters<typeof session.queue.restore>[0]);
      }
      if (typeof doc.cueCount === 'number') session.cueCount = doc.cueCount;
      this.sessions.set(id, session);
      logger.info('live.session.rehydrated', { sessionId: id, userId: context.userId });
      return session;
    } catch (err) {
      logger.warn('live.session.rehydrate_failed', { sessionId: id, err: String(err) });
      return null;
    }
  }

  /** Persiste o estado quente (dedup + contadores) — fire-and-forget após
   *  cada cue entregue. Rehidratação restaura e o atleta não ouve repetido. */
  persistHotState(session: CueSession): void {
    void getFirestore()
      .collection(COLLECTION)
      .doc(session.id)
      .set(
        {
          queueSnapshot: session.queue.snapshot(),
          cueCount: session.cueCount,
          mode: session.mode,
        },
        { merge: true },
      )
      .catch((err) => {
        logger.warn('live.session.hot_persist_failed', {
          sessionId: session.id,
          err: String(err),
        });
      });
  }

  async destroy(id: string): Promise<void> {
    this.sessions.delete(id);
    try {
      await getFirestore().collection(COLLECTION).doc(id).delete();
    } catch (err) {
      logger.warn('live.session.delete_failed', { sessionId: id, err: String(err) });
    }
    logger.info('live.session.destroyed', { sessionId: id });
  }

  /** Remove sessões sem toque há mais de TTL. */
  sweep(): number {
    const cutoff = this.clock() - SESSION_TTL_MS;
    let purged = 0;
    for (const [id, s] of this.sessions) {
      if (s.lastTouchedAt < cutoff) {
        this.sessions.delete(id);
        purged++;
        logger.info('cue_session.purged', { sessionId: id });
      }
    }
    return purged;
  }

  getStats(): { total: number } {
    return { total: this.sessions.size };
  }
}

/** Singleton do processo (1 instância Cloud Run no v1). */
export const cueSessionStore = new CueSessionStore();
