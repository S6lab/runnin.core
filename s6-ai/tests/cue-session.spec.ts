import { describe, it, expect } from 'vitest';
import { CueSession, approxTokens, TOKEN_PRESSURE_THRESHOLD } from '@modules/live/cue-session';
import { LiveSessionContextSchema } from '@modules/live/live-session.types';
import { applyPrefsGate, formatEventTurn } from '@modules/live/cue-pipeline';

function ctx(overrides: Record<string, unknown> = {}) {
  return LiveSessionContextSchema.parse({ userId: 'u1', ...overrides });
}

describe('CueSession', () => {
  it('replay = só o último cue (G3)', () => {
    const s = new CueSession('s1', ctx());
    s.appendCue('primeiro');
    s.appendCue('segundo');
    s.appendCue('terceiro');
    s.appendCue('quarto');
    expect(s.replayContext).toBe('quarto');
    expect(s.lastCueTexts).toHaveLength(3);
  });

  it('token pressure dispara no threshold', () => {
    const s = new CueSession('s1', ctx());
    const text = 'x'.repeat(400); // ~100 tokens + 120 resposta = 220/cue
    const per = approxTokens(text) + 120;
    const needed = Math.ceil(TOKEN_PRESSURE_THRESHOLD / per);
    for (let i = 0; i < needed; i++) s.appendCue(text);
    expect(s.underTokenPressure).toBe(true);
  });

  it('bumpGeneration reseta preambleReady (G2)', () => {
    const s = new CueSession('s1', ctx());
    s.markPreambleReady();
    expect(s.preambleReady).toBe(true);
    s.bumpGeneration();
    expect(s.preambleReady).toBe(false);
    expect(s.generation).toBe(1);
  });
});

describe('applyPrefsGate', () => {
  it('silent: bloqueia narrativos, deixa bpm_alert/pace_alert/finish', () => {
    const s = new CueSession('s1', ctx({ prefs: { freq: 'silent', dnd: false, allowCriticalAlertsInSilent: true } }));
    expect(applyPrefsGate(s, 'km_reached')).toBe('silent');
    expect(applyPrefsGate(s, 'half_km')).toBe('silent');
    expect(applyPrefsGate(s, 'bpm_alert')).toBeNull();
    expect(applyPrefsGate(s, 'pace_alert')).toBeNull();
    expect(applyPrefsGate(s, 'finish')).toBeNull();
  });

  it('silent + allowCritical=false: bloqueia até bpm_alert', () => {
    const s = new CueSession('s1', ctx({ prefs: { freq: 'silent', dnd: false, allowCriticalAlertsInSilent: false } }));
    expect(applyPrefsGate(s, 'bpm_alert')).toBe('silent');
    expect(applyPrefsGate(s, 'finish')).toBeNull();
  });

  it('dnd: só críticos e finish', () => {
    const s = new CueSession('s1', ctx({ prefs: { freq: 'normal', dnd: true, allowCriticalAlertsInSilent: true } }));
    expect(applyPrefsGate(s, 'km_reached')).toBe('dnd');
    expect(applyPrefsGate(s, 'bpm_alert')).toBeNull();
    expect(applyPrefsGate(s, 'finish')).toBeNull();
  });

  it('alerts_only: narrativos bloqueados, goal_reached passa', () => {
    const s = new CueSession('s1', ctx({ prefs: { freq: 'alerts_only', dnd: false, allowCriticalAlertsInSilent: true } }));
    expect(applyPrefsGate(s, 'km_reached')).toBe('frequency');
    expect(applyPrefsGate(s, 'half_km')).toBe('frequency');
    expect(applyPrefsGate(s, 'goal_reached')).toBeNull();
    expect(applyPrefsGate(s, 'pace_alert')).toBeNull();
  });
});

describe('formatEventTurn — modo free', () => {
  it('planned inclui alvo e km restantes; free omite (1ª pessoa)', () => {
    const s = new CueSession('s1', ctx());
    const data = {
      kmDone: 5.5,
      kmRemaining: 4.5,
      elapsedS: 1800,
      targetPace: '5min30',
      pace500m: '5min45',
    };
    const planned = formatEventTurn('half_km', { ...data }, s);
    expect(planned).toContain('Coach, check-in 500m');
    expect(planned).toContain('Alvo 5min30/km');
    expect(planned).toContain('faltam 4.5km');

    s.switchToFreeMode();
    const free = formatEventTurn('half_km', { ...data }, s);
    expect(free).not.toContain('Alvo');
    expect(free).not.toContain('faltam');
  });

  it('idle=true injeta bandeira de estado parado', () => {
    const s = new CueSession('s1', ctx());
    const turn = formatEventTurn('km_reached', { kmDone: 3, elapsedS: 900, idle: true }, s);
    expect(turn).toContain('PARADO');
  });
});
