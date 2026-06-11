import { CueQueue } from './cue-queue';
import { LiveSessionContext, SessionMode } from './live-session.types';

/** ~4 chars por token — aproximação suficiente pra guard rails. */
export function approxTokens(text: string): number {
  return Math.ceil(text.length / 4);
}

/** Threshold de alerta de volume de tokens da sessão (G3). */
export const TOKEN_PRESSURE_THRESHOLD = 24_000;

/** Tokens estimados de resposta do modelo por cue falado. */
const RESPONSE_TOKENS_PER_CUE = 120;

/**
 * Estado de runtime de UMA sessão Live de corrida. Vive no CueSessionStore
 * (in-memory, TTL 8h) e rehidrata de `live_sessions/{id}` após restart.
 */
export class CueSession {
  readonly queue: CueQueue;
  mode: SessionMode = 'planned';
  /** false até o setupComplete do Gemini — gate G2 (nenhum cue sem contexto). */
  preambleReady = false;
  /** Incrementa a cada reconexão/rotação da sessão Gemini. */
  generation = 0;
  /** Últimos textos falados — replay de contexto em rotação/reconnect. */
  lastCueTexts: string[] = [];
  /** Falas entregues na sessão — alimenta diretivas rotativas (ex: clima). */
  cueCount = 0;
  totalTokensApprox = 0;
  lastTouchedAt: number;

  constructor(
    readonly id: string,
    readonly context: LiveSessionContext,
    private readonly clock: () => number = () => Date.now(),
  ) {
    this.queue = new CueQueue(clock);
    this.lastTouchedAt = clock();
  }

  touch(): void {
    this.lastTouchedAt = this.clock();
  }

  bumpGeneration(): void {
    this.generation += 1;
    this.preambleReady = false;
  }

  markPreambleReady(): void {
    this.preambleReady = true;
  }

  appendCue(text: string): void {
    this.lastCueTexts.push(text);
    if (this.lastCueTexts.length > 3) this.lastCueTexts.shift();
    this.cueCount += 1;
    this.totalTokensApprox += approxTokens(text) + RESPONSE_TOKENS_PER_CUE;
  }

  /** Clima liberado APENAS a cada 5ª fala — o briefing (start) não passa
   *  pelo gate por construção. `cueCount === 0` NÃO libera: rehidratação/
   *  rotação zera o contador e o clima voltava em toda reconexão
   *  (feedback do smoke 2026-06-11, 2.5km pós-rehydrate). */
  get weatherAllowedNow(): boolean {
    return this.cueCount > 0 && this.cueCount % 5 === 0;
  }

  /** Replay: APENAS o último cue (G3 — não os 3) na reconexão. */
  get replayContext(): string | null {
    return this.lastCueTexts[this.lastCueTexts.length - 1] ?? null;
  }

  get underTokenPressure(): boolean {
    return this.totalTokensApprox >= TOKEN_PRESSURE_THRESHOLD;
  }

  switchToFreeMode(): void {
    this.mode = 'free';
  }
}
