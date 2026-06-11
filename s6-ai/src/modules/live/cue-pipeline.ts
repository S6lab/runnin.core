import { logger } from '@shared/logger/logger';
import { CueEvent, TelemetrySnapshot } from './cue-events';
import { CueSession } from './cue-session';
import { cueSessionStore } from './cue-session.store';
import { GeminiBridge } from './gemini-bridge';

/** Eventos críticos de segurança/fechamento: furam silent e DND. */
const CRITICAL_EVENTS: ReadonlySet<CueEvent> = new Set(['bpm_alert', 'pace_alert']);

export type SkipReason = 'silent' | 'dnd' | 'frequency';

/**
 * Decision layer por preferências do atleta (prefs do blob de contexto).
 * bpm_alert é crítico (segurança fisiológica) — mesma semântica do Fix 4.1.
 */
export function applyPrefsGate(
  session: CueSession,
  event: CueEvent,
): SkipReason | null {
  const prefs = session.context.prefs;

  if (prefs.freq === 'silent') {
    // Dois sub-modos da UI:
    //   silent + critical=true  → SILENCIOSO: início, fim e críticos falam
    //   silent + critical=false → SEM ÁUDIO: mudo total (nada fala)
    if (prefs.allowCriticalAlertsInSilent &&
        (event === 'start' || event === 'finish' || CRITICAL_EVENTS.has(event))) {
      return null;
    }
    return 'silent';
  }
  if (prefs.dnd && !CRITICAL_EVENTS.has(event) && event !== 'finish') {
    return 'dnd';
  }
  if (prefs.freq === 'alerts_only' && !CRITICAL_EVENTS.has(event) && event !== 'finish' && event !== 'goal_reached') {
    return 'frequency';
  }
  // per_2km: half_km vira ruído; km ímpar é filtrado no processCueEvent
  // (precisa do snapshot).
  if (prefs.freq === 'per_2km' && event === 'half_km') return 'frequency';
  return null;
}

/**
 * Formata o turn de telemetria injetado no Gemini Live.
 *
 * IMPORTANTE (lição do app legado, _telemetryText): o turn é a VOZ DO
 * ATLETA em primeira pessoa pedindo feedback. O modelo native-audio trata
 * cada turn como fala de um interlocutor — instrução em 3ª pessoa ("dê
 * feedback") faz ele responder como COLEGA ("fechei sim, e vc?"); em 1ª
 * pessoa ele responde como COACH.
 *
 * Pace chega PRÉ-FORMATADO do caller no formato falável "5min30" (TF 81 —
 * "5:30" virava "cinco mil e quinhentos" na narração).
 *
 * Modo free (pós-goal_reached): omite alvo/roteiro — corrida virou livre.
 */
export function formatEventTurn(
  event: CueEvent,
  data: TelemetrySnapshot,
  session: CueSession,
): string {
  const free = session.mode === 'free';
  const dist = data.kmDone.toFixed(2);
  // Pace MÉDIO real (elapsed/dist) — antes o totals rotulava "pace médio"
  // usando o pace ATUAL suavizado e divergia da UI (smoke 2026-06-11).
  const avgPace = data.kmDone > 0.05 && data.elapsedS > 0
    ? formatPaceSpoken(data.elapsedS / 60 / data.kmDone)
    : null;
  // Indoor: sem GPS o kmDone fica 0 — totals vira só tempo pro LLM não
  // narrar "0.00km" na esteira.
  const totals = data.indoor === true
    ? `Já se passaram ${formatElapsed(data.elapsedS)} de corrida na esteira.`
    : `No total já são ${dist}km em ${formatElapsed(data.elapsedS)}${
        avgPace ? `, pace médio ${avgPace}/km` : ''
      }.`;
  // Bandeira de idle (Watch 0 passos ~1min): sem isso o LLM alucinava pace
  // de drift GPS ("5:42" parado — TF 75).
  const idlePrefix = data.idle === true
    ? '[ESTADO: PARADO há ~1min (0 passos). NÃO mencione pace nem distância; sugira retomar.] '
    : '';
  // Diretiva rotativa de clima: o modelo retomava clima em TODA cue.
  // Determinístico: bloqueado na maioria das falas (start não recebe a
  // diretiva — o briefing DEVE citar o clima).
  const weatherGate = event !== 'start' && !session.weatherAllowedNow
    ? '[NÃO mencione clima/temperatura/umidade/vento nesta fala.] '
    : '';
  const tgt = !free && data.targetPace ? `${data.targetPace}/km` : 'livre';
  const pre = `${idlePrefix}${weatherGate}`;

  switch (event) {
    case 'start':
      return data.indoor === true
        ? 'Oi coach! Vou começar minha corrida agora, na esteira. [CORRIDA INDOOR: sem GPS — não mencione pace nem distância durante a corrida; foque em tempo decorrido, frequência cardíaca e ritmo percebido.]'
        : 'Oi coach! Vou começar minha corrida agora.';
    case 'km_reached': {
      const m = [
        data.currentPace ? `pace deste km ${data.currentPace}/km` : null,
        `alvo ${tgt}`,
        data.kmDurationS != null ? `tempo do km ${formatElapsed(data.kmDurationS)}` : null,
        data.kmAvgBpm != null ? `FC ${Math.round(data.kmAvgBpm)}` : null,
      ].filter(Boolean).join(', ');
      return `${pre}Coach, fechei o km ${Math.floor(data.kmDone)}. ${m}. ${totals}`;
    }
    case 'half_km': {
      // Indoor: check-in disparado por TEMPO (4min) — não há 500m nem pace.
      if (data.indoor === true) {
        const fc = data.bpm != null ? ` Minha FC tá em ${Math.round(data.bpm)}.` : '';
        return `${pre}Coach, check-in da esteira: ${totals}${fc} Como estou indo?`;
      }
      const last500 = data.pace500m
        ? `pace dos últimos 500m: ${data.pace500m}/km`
        : 'mais 500m completados';
      const remaining = !free && data.kmRemaining != null && data.kmRemaining > 0
        ? `faltam ${data.kmRemaining.toFixed(1)}km. `
        : '';
      const alvo = !free && data.targetPace ? `Alvo ${tgt}. ` : '';
      return `${pre}Coach, check-in 500m: ${last500}. ${alvo}${remaining}${totals}`;
    }
    case 'pace_alert':
      return `${pre}Coach, meu pace está ${data.currentPace ?? '—'}/km. Alvo: ${tgt}. ${totals}`;
    case 'bpm_alert': {
      const max = data.maxBpm != null ? ` (minha FC máxima é ${Math.round(data.maxBpm)})` : '';
      return `${pre}Coach, meu BPM tá em ${data.bpm != null ? Math.round(data.bpm) : '—'}${max}. ${totals}`;
    }
    case 'no_movement':
      return 'Coach, iniciei mas ainda não comecei a me mover.';
    case 'goal_reached':
      // Indoor o alvo é por TEMPO (durationMin da sessão), não distância.
      return data.indoor === true
        ? `${pre}Coach, completei o tempo alvo da sessão na esteira. ${totals}`
        : `${pre}Coach, bati a meta de distância da sessão. ${totals}`;
    case 'finish':
      return `${pre}Coach, finalizei! Total ${dist}km em ${formatElapsed(data.elapsedS)}${
        avgPace ? `, pace médio ${avgPace}/km` : ''
      }.`;
    default:
      return `${pre}Coach, como estou indo? ${totals}`;
  }
}

/** Pace falável "5min30" (TF 81 — "5:30" virava "cinco mil e quinhentos"). */
function formatPaceSpoken(paceMinKm: number): string {
  const m = Math.floor(paceMinKm);
  const s = Math.round((paceMinKm - m) * 60);
  return `${m}min${String(s).padStart(2, '0')}`;
}

function formatElapsed(totalS: number): string {
  const s = Math.max(0, Math.round(totalS));
  const min = Math.floor(s / 60);
  const sec = s % 60;
  if (min >= 60) {
    const h = Math.floor(min / 60);
    return `${h}h${String(min % 60).padStart(2, '0')}`;
  }
  return `${min}min${String(sec).padStart(2, '0')}`;
}

export type ProcessResult =
  | { outcome: 'enqueued' }
  | { outcome: 'skipped'; reason: string };

/**
 * Entrada única de eventos (frames WS e fallback HTTP usam o mesmo
 * caminho): prefs gate → CueQueue (dedup/prioridade) → drain serializado
 * pelo bridge (1 fala em voo; próxima só após turnComplete).
 */
export function processCueEvent(
  session: CueSession,
  bridge: GeminiBridge,
  event: CueEvent,
  data: TelemetrySnapshot,
): ProcessResult {
  session.touch();

  const skip = applyPrefsGate(session, event);
  if (skip === null && session.context.prefs.freq === 'per_2km') {
    // per_2km depende do km do snapshot — gate fino aqui.
    if (event === 'km_reached' && Math.floor(data.kmDone) % 2 !== 0) {
      logger.info('coach.cue.skipped', { sessionId: session.id, event, reason: 'frequency' });
      return { outcome: 'skipped', reason: 'frequency' };
    }
  }
  if (skip) {
    logger.info('coach.cue.skipped', { sessionId: session.id, event, reason: skip });
    return { outcome: 'skipped', reason: skip };
  }

  const result = session.queue.tryEnqueue(event, data);
  if (!result.accepted) {
    logger.info('coach.queue.drop', { sessionId: session.id, event, reason: result.reason });
    return { outcome: 'skipped', reason: result.reason };
  }
  logger.info('coach.queue.enqueue', {
    sessionId: session.id,
    event,
    pending: session.queue.pendingCount,
    interrupt: result.interruptActive,
  });

  if (result.interruptActive) {
    logger.info('coach.queue.preempt_active', {
      sessionId: session.id,
      preemptedBy: event,
      active: session.queue.activeCue?.event,
    });
    session.queue.markInterrupted();
    bridge.interrupt();
  }

  void drainQueue(session, bridge);
  return { outcome: 'enqueued' };
}

/** Loop de drenagem — só 1 em voo por sessão (guard no isBusy). */
export async function drainQueue(session: CueSession, bridge: GeminiBridge): Promise<void> {
  if (session.queue.isBusy) return;
  for (;;) {
    const cue = session.queue.next();
    if (!cue) return;
    const text = formatEventTurn(cue.event, cue.data, session);
    try {
      await bridge.speak(text);
    } catch (err) {
      logger.warn('coach.deliver.failed', {
        sessionId: session.id,
        event: cue.event,
        err: String(err),
      });
    } finally {
      session.queue.complete();
      // Persiste dedup/contadores — rehidratação sem isso repetia cues.
      cueSessionStore.persistHotState(session);
    }
    if (cue.event === 'goal_reached') {
      // Meta batida: se o atleta seguir correndo, próximo half_km/km_reached
      // sai sem alvo/roteiro.
      session.switchToFreeMode();
    }
  }
}
