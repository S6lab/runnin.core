import { GeminiLiveSession, GeminiServerContent } from '@shared/infra/llm/gemini-live.service';
import { logger } from '@shared/logger/logger';
import { CueSession } from './cue-session';

/** Rotação preventiva da sessão Gemini (cap real do Live ~10min): o que
 *  vier primeiro. 4min/6turns era trauma do caminho legado (mic streaming
 *  inflava o histórico); server-side só injeta texto — rotação às 4min
 *  caía NO MEIO da entrega do km1 (smoke 2026-06-11). */
const ROTATE_AFTER_TURNS = 10;
const ROTATE_AFTER_MS = 8 * 60 * 1000;

/** Entrega aguarda turnComplete até esse teto antes de liberar a fila. */
const TURN_COMPLETE_TIMEOUT_MS = 15_000;

/** Gate G2: espera máx. pelo setupComplete antes do fallback de replay. */
const PREAMBLE_WAIT_MS = 2_000;

const RECONNECT_BACKOFF_MS = [1_000, 2_000, 4_000, 8_000, 16_000, 30_000];
const MAX_RECONNECT_ATTEMPTS = 10;

export interface BridgeCallbacks {
  /** Chunk PCM 24kHz base64 do modelo → repassar ao app como frame binário. */
  onAudioChunk: (base64: string, mimeType: string) => void;
  onState: (state: 'preambleReady' | 'turnStart' | 'turnComplete' | 'interrupted' | 'gone') => void;
  /** Transcript acumulado do turn (quando o modelo emite texto). */
  onTranscript: (text: string) => void;
}

/**
 * Dono da sessão Gemini Live de UMA corrida, server-side. Responsável por:
 *  - G2: preambleReady — nenhum cue antes do setupComplete; reconexão e
 *    rotação re-injetam contexto (replay do último cue) ANTES do próximo cue.
 *  - G1 (entrega): speak() serializa — resolve no turnComplete (timeout 15s).
 *  - Rotação preventiva (6 turns / 4min) — portado do app
 *    (live_run_coach_session.dart), que deixa de fazer isso no PR4.
 */
export class GeminiBridge {
  private gemini: GeminiLiveSession | null = null;
  private disposed = false;
  private turnsInSession = 0;
  private sessionOpenedAt = 0;
  private transcriptBuffer = '';
  private turnResolver: (() => void) | null = null;
  private reconnectAttempt = 0;
  private reconnecting = false;

  constructor(
    private readonly session: CueSession,
    private readonly systemInstruction: string,
    private readonly voice: string,
    private readonly callbacks: BridgeCallbacks,
  ) {}

  async open(): Promise<void> {
    this.gemini = this._buildSession();
    await this.gemini.open();
    this.sessionOpenedAt = Date.now();
    this.turnsInSession = 0;
    this.session.markPreambleReady();
    this.callbacks.onState('preambleReady');
    logger.info('live.bridge.opened', {
      sessionId: this.session.id,
      generation: this.session.generation,
    });
  }

  /** Áudio do microfone do atleta (PCM16 base64) → Gemini. */
  sendUserAudio(base64: string, mimeType = 'audio/pcm;rate=16000'): void {
    this.gemini?.sendAudio(base64, mimeType);
  }

  /**
   * Fala um cue: gate de preamble (G2) → rotação preventiva se devida →
   * sendText → aguarda turnComplete (15s). Chamar SEMPRE serializado pela
   * CueQueue (1 speak em voo por sessão).
   */
  async speak(text: string): Promise<void> {
    if (this.disposed) return;

    const ready = await this._waitPreamble();
    let payload = text;
    if (!ready) {
      // Fallback G2: replay inline do último cue como contexto — Gemini
      // Live não permite trocar systemInstruction mid-session.
      const replay = this.session.replayContext;
      payload = replay ? `<context>${replay}</context>\n${text}` : text;
      logger.warn('coach.deliver.preamble_missing', {
        sessionId: this.session.id,
        generation: this.session.generation,
      });
    }

    if (this._shouldRotate()) {
      await this._rotate();
    }

    this.callbacks.onState('turnStart');
    this.transcriptBuffer = '';
    this.gemini?.sendText(payload);
    this.turnsInSession += 1;

    await this._awaitTurnComplete();
    this.session.appendCue(text);
    if (this.session.underTokenPressure) {
      logger.warn('coach.session.token_pressure', {
        sessionId: this.session.id,
        tokens: this.session.totalTokensApprox,
      });
    }
  }

  /**
   * Preempção P0 / km_reached sobre half_km ativo — FALLBACK definitivo
   * do plano: NÃO usamos o spike de clientContent vazio (o modelo
   * RESPONDIA ao turno vazio e gerava fala fantasma — "km6 duplicado" no
   * smoke 2026-06-11). Em vez disso: o resto do turn cortado fica mudo
   * (suppress) e o cue vencedor sai assim que o turn terminar
   * naturalmente (1-3s; timeout de 15s cobre o caso raro).
   */
  interrupt(): void {
    this.suppressTurnAudio = true;
    this.callbacks.onState('interrupted');
    // Libera o speak() do cue cortado: a fila segue pro vencedor, cujo
    // sendText faz o próprio Gemini cancelar a geração em curso
    // (sc.interrupted chega e morre no suppress).
    this._resolveTurn();
  }

  dispose(): void {
    this.disposed = true;
    this._resolveTurn();
    this.gemini?.close();
    this.gemini = null;
  }

  // ────────────────────────── internos ──────────────────────────

  private _buildSession(): GeminiLiveSession {
    // eslint-disable-next-line prefer-const
    let ref: GeminiLiveSession;
    ref = new GeminiLiveSession({
      config: {
        systemInstruction: this.systemInstruction,
        responseModalities: ['AUDIO'],
        voice: this.voice,
      },
      onMessage: (msg) => {
        // Mensagens só do socket ATUAL — o velho ainda emite durante o
        // swap de rotação.
        if (this.gemini !== ref) return;
        if (msg.kind !== 'content') return;
        this._handleContent(msg.serverContent);
      },
      onClose: (code, reason) => {
        const isCurrent = this.gemini === ref;
        logger.info('live.bridge.gemini_closed', {
          sessionId: this.session.id,
          code,
          reason,
          isCurrent,
          generation: this.session.generation,
        });
        // Só reconecta se quem caiu foi o socket ATUAL. O close do socket
        // VELHO na rotação disparava _reconnect espúrio (generation bump +
        // 3ª sessão por cima da recém-aberta) e engolia os cues do km1
        // (smoke 2026-06-11).
        if (!this.disposed && isCurrent) void this._reconnect();
      },
    });
    return ref;
  }

  /** Dedup do fim de turno: Gemini emite generationComplete E turnComplete
   *  pro MESMO turno — sem isso o app recebia 2 frames de fim, dava flush
   *  no meio do áudio do turno seguinte e os players sobrepunham (4 cues
   *  em cima no km1, smoke 2026-06-11). */
  private turnEndEmitted = false;

  /** O turn de replay (rotação/reconnect) re-contextualiza o modelo mas a
   *  RESPOSTA dele não deve tocar no app — sem isso a reconexão gerava uma
   *  fala extra "do nada" (duplicado do 3.5km, smoke 2026-06-11). */
  private suppressTurnAudio = false;

  private _handleContent(sc: GeminiServerContent): void {
    const parts = sc.modelTurn?.parts ?? [];
    for (const p of parts) {
      if (p.inlineData?.data) {
        // Áudio chegando depois de um fim emitido = turno NOVO começou.
        if (this.turnEndEmitted) this.turnEndEmitted = false;
        if (!this.suppressTurnAudio) {
          this.callbacks.onAudioChunk(p.inlineData.data, p.inlineData.mimeType);
        }
      }
    }
    // Transcript = outputTranscription (texto == voz, PT). parts.text no
    // native-audio é "pensamento" interno em inglês — ignorado.
    const t = sc.outputTranscription?.text;
    if (typeof t === 'string' && t.length > 0 && !this.suppressTurnAudio) {
      this.transcriptBuffer += t;
    }
    if (sc.interrupted) {
      // Preempção NOSSA (suppress ativo): interrupt() já liberou a fila e o
      // resolver atual pode ser do cue VENCEDOR — resolver aqui de novo
      // soltaria a fila cedo. Só limpa o suppress (fim do turn cortado;
      // o áudio do próximo deve tocar).
      const wasOurPreemption = this.suppressTurnAudio;
      this.suppressTurnAudio = false;
      this.turnEndEmitted = true;
      this.transcriptBuffer = '';
      if (!wasOurPreemption) {
        this.callbacks.onState('interrupted');
        this._resolveTurn();
      }
      return;
    }
    // generationComplete conta como fim de turno: no native-audio o
    // turnComplete atrasava/faltava e cada cue segurava a fila por 15s
    // (coach.deliver.turn_complete_timeout no smoke 2026-06-11). Emitido
    // UMA vez por turno (vide turnEndEmitted).
    if ((sc.turnComplete || sc.generationComplete) && !this.turnEndEmitted) {
      this.turnEndEmitted = true;
      const wasSuppressed = this.suppressTurnAudio;
      this.suppressTurnAudio = false;
      if (!wasSuppressed && this.transcriptBuffer.trim()) {
        this.callbacks.onTranscript(this.transcriptBuffer.trim());
      }
      this.transcriptBuffer = '';
      if (!wasSuppressed) this.callbacks.onState('turnComplete');
      this._resolveTurn();
    }
  }

  private _awaitTurnComplete(): Promise<void> {
    return new Promise<void>((resolve) => {
      const timer = setTimeout(() => {
        logger.warn('coach.deliver.turn_complete_timeout', {
          sessionId: this.session.id,
          timeoutMs: TURN_COMPLETE_TIMEOUT_MS,
        });
        finish();
      }, TURN_COMPLETE_TIMEOUT_MS);
      const finish = (): void => {
        clearTimeout(timer);
        this.turnResolver = null;
        resolve();
      };
      this.turnResolver = finish;
    });
  }

  private _resolveTurn(): void {
    this.turnResolver?.();
  }

  private async _waitPreamble(): Promise<boolean> {
    if (this.session.preambleReady) return true;
    const deadline = Date.now() + PREAMBLE_WAIT_MS;
    while (Date.now() < deadline) {
      if (this.session.preambleReady) return true;
      await sleep(100);
    }
    return this.session.preambleReady;
  }

  private _shouldRotate(): boolean {
    if (!this.gemini) return false;
    return (
      this.turnsInSession >= ROTATE_AFTER_TURNS ||
      Date.now() - this.sessionOpenedAt >= ROTATE_AFTER_MS
    );
  }

  /** Pré-aquece sessão nova, injeta replay do último cue, troca, fecha a velha. */
  private async _rotate(): Promise<void> {
    const old = this.gemini;
    this.session.bumpGeneration();
    logger.info('live.bridge.rotating', {
      sessionId: this.session.id,
      generation: this.session.generation,
      turns: this.turnsInSession,
    });
    try {
      const fresh = this._buildSession();
      this.gemini = null; // evita reconnect do onClose da velha contar como queda
      await fresh.open();
      this.gemini = fresh;
      this.sessionOpenedAt = Date.now();
      this.turnsInSession = 0;
      const replay = this.session.replayContext;
      if (replay) {
        // Replay silencioso: contexto sem pedir resposta longa. Vai como
        // turn normal — o modelo responde curto; aceitável na rotação.
        this.suppressTurnAudio = true; // resposta do replay não toca no app
        fresh.sendText(`<context>Último aviso dado ao atleta: "${replay}". Apenas continue acompanhando, não repita.</context>`);
        await this._awaitTurnComplete();
      }
      this.session.markPreambleReady();
      this.callbacks.onState('preambleReady');
      old?.close();
    } catch (err) {
      logger.error('live.bridge.rotate_failed', {
        sessionId: this.session.id,
        err: String(err),
      });
      // Mantém a sessão velha se a nova falhou — melhor TTL arriscado que mudez.
      this.gemini = old;
    }
  }

  private async _reconnect(): Promise<void> {
    if (this.reconnecting || this.disposed) return;
    this.reconnecting = true;
    this.session.bumpGeneration();
    this._resolveTurn();

    while (!this.disposed && this.reconnectAttempt < MAX_RECONNECT_ATTEMPTS) {
      const delay = RECONNECT_BACKOFF_MS[
        Math.min(this.reconnectAttempt, RECONNECT_BACKOFF_MS.length - 1)
      ] as number;
      this.reconnectAttempt += 1;
      await sleep(delay);
      if (this.disposed) break;
      try {
        await this.open();
        const replay = this.session.replayContext;
        if (replay) {
          this.suppressTurnAudio = true; // resposta do replay não toca no app
          this.gemini?.sendText(`<context>Último aviso dado ao atleta: "${replay}". Apenas continue acompanhando, não repita.</context>`);
          await this._awaitTurnComplete();
        }
        this.reconnectAttempt = 0;
        this.reconnecting = false;
        logger.info('live.bridge.reconnected', {
          sessionId: this.session.id,
          generation: this.session.generation,
        });
        return;
      } catch (err) {
        logger.warn('live.bridge.reconnect_failed', {
          sessionId: this.session.id,
          attempt: this.reconnectAttempt,
          err: String(err),
        });
      }
    }
    this.reconnecting = false;
    if (!this.disposed) {
      logger.error('live.bridge.reconnect_exhausted', { sessionId: this.session.id });
      this.callbacks.onState('gone');
    }
  }
}

function sleep(ms: number): Promise<void> {
  return new Promise((r) => setTimeout(r, ms));
}
