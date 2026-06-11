import { describe, it, expect } from 'vitest';
import { CueQueue } from '@modules/live/cue-queue';
import { TelemetrySnapshot } from '@modules/live/cue-events';

function snap(partial: Partial<TelemetrySnapshot> = {}): TelemetrySnapshot {
  return { kmDone: 0, elapsedS: 0, ...partial };
}

function makeClock(start = 1000) {
  let now = start;
  return { clock: () => now, advance: (ms: number) => { now += ms; } };
}

describe('CueQueue — G1', () => {
  it('half_km(0.95) seguido de km_reached(1.0): half dropado da fila, km falado', () => {
    const { clock } = makeClock();
    const q = new CueQueue(clock);

    const half = q.tryEnqueue('half_km', snap({ kmDone: 0.95 }));
    expect(half).toEqual({ accepted: true, interruptActive: false });

    const km = q.tryEnqueue('km_reached', snap({ kmDone: 1.0 }));
    expect(km.accepted).toBe(true);

    // half_km pendente foi removido — só km_reached na fila.
    expect(q.pendingCount).toBe(1);
    expect(q.next()?.event).toBe('km_reached');
  });

  it('km_reached chegando com half_km ATIVO pede interrupção', () => {
    const { clock } = makeClock();
    const q = new CueQueue(clock);
    q.tryEnqueue('half_km', snap({ kmDone: 0.95 }));
    expect(q.next()?.event).toBe('half_km'); // falando agora

    const km = q.tryEnqueue('km_reached', snap({ kmDone: 1.0 }));
    expect(km).toEqual({ accepted: true, interruptActive: true });
  });

  it('dedup por bucket: km_reached do mesmo km é dropado', () => {
    const { clock } = makeClock();
    const q = new CueQueue(clock);
    expect(q.tryEnqueue('km_reached', snap({ kmDone: 1.0 })).accepted).toBe(true);
    q.next();
    q.complete();
    const dup = q.tryEnqueue('km_reached', snap({ kmDone: 1.02 }));
    expect(dup).toEqual({ accepted: false, reason: 'dedup_km_bucket' });
  });

  it('half_km do bucket já anunciado por km_reached é superseded', () => {
    const { clock } = makeClock();
    const q = new CueQueue(clock);
    q.tryEnqueue('km_reached', snap({ kmDone: 1.0 }));
    q.next();
    q.complete();
    const late = q.tryEnqueue('half_km', snap({ kmDone: 0.98 }));
    expect(late.accepted).toBe(false);
  });

  it('half_km do TRECHO SEGUINTE ao km anunciado é aceito (1.5km pós-km1)', () => {
    const { clock } = makeClock();
    const q = new CueQueue(clock);
    q.tryEnqueue('half_km', snap({ kmDone: 0.5 }));
    q.next(); q.complete();
    q.tryEnqueue('km_reached', snap({ kmDone: 1.0 }));
    q.next(); q.complete();
    const next = q.tryEnqueue('half_km', snap({ kmDone: 1.5 }));
    expect(next).toEqual({ accepted: true, interruptActive: false });
  });

  it('P0 (bpm_alert) interrompe cue ativo e fura cooldown só após 60s', () => {
    const { clock, advance } = makeClock();
    const q = new CueQueue(clock);
    q.tryEnqueue('km_reached', snap({ kmDone: 1 }));
    q.next(); // km falando

    const bpm = q.tryEnqueue('bpm_alert', snap({ bpm: 182 }));
    expect(bpm).toEqual({ accepted: true, interruptActive: true });
    q.markInterrupted();
    expect(q.next()?.event).toBe('bpm_alert');
    q.complete();

    advance(30_000);
    expect(q.tryEnqueue('bpm_alert', snap({ bpm: 183 }))).toEqual({
      accepted: false,
      reason: 'cooldown',
    });
    advance(31_000);
    expect(q.tryEnqueue('bpm_alert', snap({ bpm: 184 })).accepted).toBe(true);
  });

  it('P3 só entra com fila ociosa', () => {
    const { clock } = makeClock();
    const q = new CueQueue(clock);
    q.tryEnqueue('km_reached', snap({ kmDone: 1 }));
    q.next(); // busy
    const nm = q.tryEnqueue('no_movement', snap());
    expect(nm).toEqual({ accepted: false, reason: 'queue_busy_p3' });
    q.complete();
    expect(q.tryEnqueue('no_movement', snap()).accepted).toBe(true);
  });

  it('P2 chegando descarta P3 pendente', () => {
    const { clock } = makeClock();
    const q = new CueQueue(clock);
    q.tryEnqueue('no_movement', snap());
    expect(q.pendingCount).toBe(1);
    q.tryEnqueue('km_reached', snap({ kmDone: 2 }));
    expect(q.pendingCount).toBe(1);
    expect(q.next()?.event).toBe('km_reached');
  });

  it('one-shot: start/finish/goal_reached não repetem', () => {
    const { clock } = makeClock();
    const q = new CueQueue(clock);
    expect(q.tryEnqueue('start', snap()).accepted).toBe(true);
    q.next();
    q.complete();
    expect(q.tryEnqueue('start', snap())).toEqual({
      accepted: false,
      reason: 'duplicate_one_shot',
    });
  });

  it('prioridade ordena a fila: P1 fala antes de P2 enfileirado', () => {
    const { clock } = makeClock();
    const q = new CueQueue(clock);
    q.tryEnqueue('start', snap());
    q.next(); // start falando
    q.tryEnqueue('km_reached', snap({ kmDone: 1 }));
    q.tryEnqueue('pace_alert', snap({ deviationPct: 15 }));
    q.complete();
    expect(q.next()?.event).toBe('pace_alert');
    q.complete();
    expect(q.next()?.event).toBe('km_reached');
  });

  it('snapshot/restore preserva dedup pós-restart', () => {
    const { clock } = makeClock();
    const q = new CueQueue(clock);
    q.tryEnqueue('km_reached', snap({ kmDone: 3 }));
    q.tryEnqueue('start', snap());

    const q2 = new CueQueue(clock);
    q2.restore(q.snapshot());
    expect(q2.tryEnqueue('km_reached', snap({ kmDone: 3.01 })).accepted).toBe(false);
    expect(q2.tryEnqueue('start', snap()).accepted).toBe(false);
    expect(q2.tryEnqueue('km_reached', snap({ kmDone: 4 })).accepted).toBe(true);
  });
});
