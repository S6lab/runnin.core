import {
  Cue,
  CueEvent,
  CuePriority,
  CUE_PRIORITY,
  CUE_COOLDOWN_MS,
  ONE_SHOT_EVENTS,
  TelemetrySnapshot,
} from './cue-events';

export type EnqueueResult =
  | { accepted: true; interruptActive: boolean }
  | { accepted: false; reason: DropReason };

export type DropReason =
  | 'duplicate_one_shot'
  | 'cooldown'
  | 'dedup_km_bucket'
  | 'dedup_half_km_bucket'
  | 'superseded_by_km'
  | 'queue_busy_p3';

/**
 * Fila de cues com prioridade P0–P3, dedup por bucket de km e preempção.
 * Entidade pura (sem I/O), clock injetável — coração da garantia G1:
 * nunca dois cues falados ao mesmo tempo, km_reached vence half_km.
 */
export class CueQueue {
  private pending: Cue[] = [];
  private active: Cue | null = null;
  private firedOnce = new Set<CueEvent>();
  private lastFiredAtMs = new Map<CueEvent, number>();
  private lastKmBucket = -1;
  private lastHalfKmBucket = -1;

  constructor(private readonly clock: () => number = () => Date.now()) {}

  /**
   * Aplica dedup/cooldown/prioridade. Retorna se aceitou e se o caller
   * deve interromper a fala ativa (P0, ou km_reached sobre half_km ativo).
   */
  /** Bucket de dedup do half_km. Outdoor: meio-km (floor(kmDone*2)).
   *  Indoor: kmDone fica 0 a corrida toda (sem GPS) — o 1º check-in
   *  ocupava o bucket 0 e TODOS os seguintes eram dropados (bug visto no
   *  sim: check-ins de 8/12min mudos). Indoor usa janela de 3min de
   *  elapsedS: o trigger do app dispara a cada 4min, então cada check-in
   *  cai num bucket novo e o dedup só barra retry duplicado. */
  private halfKmBucketOf(data: TelemetrySnapshot): number {
    if (data.indoor === true) return Math.floor(data.elapsedS / 180);
    return Math.floor(data.kmDone * 2);
  }

  tryEnqueue(event: CueEvent, data: TelemetrySnapshot): EnqueueResult {
    const now = this.clock();
    const priority = CUE_PRIORITY[event];

    if (ONE_SHOT_EVENTS.has(event) && this.firedOnce.has(event)) {
      return { accepted: false, reason: 'duplicate_one_shot' };
    }

    const cooldown = CUE_COOLDOWN_MS[event];
    if (cooldown !== undefined) {
      const last = this.lastFiredAtMs.get(event);
      if (last !== undefined && now - last < cooldown) {
        return { accepted: false, reason: 'cooldown' };
      }
    }

    if (event === 'km_reached') {
      const bucket = Math.floor(data.kmDone);
      if (bucket <= this.lastKmBucket) {
        return { accepted: false, reason: 'dedup_km_bucket' };
      }
    }

    if (event === 'half_km') {
      const halfBucket = this.halfKmBucketOf(data);
      if (halfBucket <= this.lastHalfKmBucket) {
        return { accepted: false, reason: 'dedup_half_km_bucket' };
      }
      // half ATRASADO de um marco que o km já cobriu é ruído — mas a
      // comparação é por MEIO-bucket: km_reached N cobre halfs até
      // kmDone==N (halfBucket 2N). floor(kmDone) <= N dropava o half de
      // 1.5km (floor=1) depois do km 1 — coach mudou no 1.5km (smoke
      // 2026-06-11, cue_skipped superseded_by_km).
      // Indoor não tem km_reached — guard só vale outdoor.
      if (data.indoor !== true &&
          this.lastKmBucket >= 0 && halfBucket <= this.lastKmBucket * 2) {
        return { accepted: false, reason: 'superseded_by_km' };
      }
    }

    // P3 só entra com sistema ocioso — é background, não vale enfileirar.
    if (priority === 3 && (this.active !== null || this.pending.length > 0)) {
      return { accepted: false, reason: 'queue_busy_p3' };
    }

    let interruptActive = false;

    if (event === 'km_reached') {
      // Anúncio de km supersede qualquer half_km: dropa pendentes e pede
      // interrupção se um half_km está sendo falado agora (G1).
      this.pending = this.pending.filter(c => c.event !== 'half_km');
      if (this.active?.event === 'half_km') interruptActive = true;
    }

    if (priority === 0 && this.active !== null) {
      interruptActive = true;
    }

    if (priority <= 2) {
      // P2 chegando descarta P3 pendentes (não vale falar half_km depois
      // de um km_reached/start enfileirado).
      this.pending = this.pending.filter(c => c.priority < 3);
    }

    // Dedup intra-evento na fila: substitui pendente do mesmo evento pelo
    // snapshot mais novo em vez de falar duas vezes.
    this.pending = this.pending.filter(c => c.event !== event);

    const cue: Cue = { event, data, priority, enqueuedAt: now };
    this.pending.push(cue);
    this.pending.sort((a, b) =>
      a.priority !== b.priority ? a.priority - b.priority : a.enqueuedAt - b.enqueuedAt,
    );

    // Buckets/one-shot marcados no ACEITE (não na fala): mesmo que a entrega
    // falhe, não queremos repetir o mesmo marco numa corrida.
    if (event === 'km_reached') this.lastKmBucket = Math.floor(data.kmDone);
    if (event === 'half_km') this.lastHalfKmBucket = this.halfKmBucketOf(data);
    if (ONE_SHOT_EVENTS.has(event)) this.firedOnce.add(event);
    if (CUE_COOLDOWN_MS[event] !== undefined) this.lastFiredAtMs.set(event, now);

    return { accepted: true, interruptActive };
  }

  /** Próximo cue quando ocioso. Marca como ativo (busy) até complete(). */
  next(): Cue | null {
    if (this.active !== null) return null;
    const cue = this.pending.shift() ?? null;
    this.active = cue;
    return cue;
  }

  /** Chamado no turnComplete (ou timeout) da entrega do cue ativo. */
  complete(): void {
    this.active = null;
  }

  /** Cue ativo foi interrompido (preempção) — libera a fila. */
  markInterrupted(): void {
    this.active = null;
  }

  get isBusy(): boolean {
    return this.active !== null;
  }

  get activeCue(): Cue | null {
    return this.active;
  }

  get pendingCount(): number {
    return this.pending.length;
  }

  /** Estado serializável pra rehidratação pós-restart. */
  snapshot(): {
    firedOnce: CueEvent[];
    lastKmBucket: number;
    lastHalfKmBucket: number;
  } {
    return {
      firedOnce: [...this.firedOnce],
      lastKmBucket: this.lastKmBucket,
      lastHalfKmBucket: this.lastHalfKmBucket,
    };
  }

  restore(snap: { firedOnce: CueEvent[]; lastKmBucket: number; lastHalfKmBucket: number }): void {
    this.firedOnce = new Set(snap.firedOnce);
    this.lastKmBucket = snap.lastKmBucket;
    this.lastHalfKmBucket = snap.lastHalfKmBucket;
  }
}

export function priorityOf(event: CueEvent): CuePriority {
  return CUE_PRIORITY[event];
}
