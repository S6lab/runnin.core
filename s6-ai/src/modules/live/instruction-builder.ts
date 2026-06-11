import { getPromptConfig } from '@shared/infra/llm/prompts/config-store';
import { renderTemplate } from '@shared/infra/llm/prompts/render';
import { resolvePersonaTone } from '@shared/infra/llm/prompts/persona/resolver';
import { logger } from '@shared/logger/logger';
import { approxTokens } from './cue-session';
import { LiveSessionContext, SegmentBriefSchema } from './live-session.types';
import { z } from 'zod';

type SegmentBrief = z.infer<typeof SegmentBriefSchema>;

/**
 * Cap G3: systemInstruction grande fechava o socket Gemini Live com 1008
 * (safety/tamanho). Truncamento determinístico em ordem de descarte:
 * weather → notes → detalhe de segments → cauda do briefing.
 */
export const INSTRUCTION_TOKEN_CAP = 1200;

export interface BuiltInstruction {
  text: string;
  tokensApprox: number;
  truncated: string[];
}

export async function buildLiveInstruction(ctx: LiveSessionContext): Promise<BuiltInstruction> {
  const { config } = await getPromptConfig('live-voice');
  const tone = await resolvePersonaTone(ctx.persona ?? undefined);

  const values = {
    persona: { tone },
    profile: { snippet: ctx.profileSnippet },
    plan: { snippet: ctx.sessionBriefing || 'Sem plano ativo (corrida livre).' },
  };

  const base = [
    renderTemplate(config.systemPrompt, values),
    renderTemplate(config.userTemplate, values),
  ].join('\n\n');

  const truncated: string[] = [];

  const assemble = (opts: { weather: boolean; notes: boolean; maxSegments: number }): string => {
    const blocks = [base];
    const sessionLines: string[] = [];
    if (ctx.sessionBriefing) sessionLines.push(ctx.sessionBriefing);
    if (opts.notes && ctx.sessionNotes) sessionLines.push(`Foco: ${ctx.sessionNotes}`);
    const segs = ctx.segments.slice(0, opts.maxSegments);
    if (segs.length === 0) {
      // Free run: o modelo anunciava "reta final" inventando meta
      // (smoke 2026-06-11) — sem roteiro, não existe reta final.
      sessionLines.push(
        'CORRIDA LIVRE: NÃO existe distância-alvo. NUNCA anuncie "reta final", "falta pouco" ou estimativas de término — o atleta decide quando parar.',
      );
    }
    if (segs.length > 0) {
      sessionLines.push('ROTEIRO (fases):');
      for (const s of segs) sessionLines.push(`- ${formatSegment(s)}`);
      if (ctx.segments.length > segs.length) {
        sessionLines.push(`(+${ctx.segments.length - segs.length} fases finais omitidas)`);
      }
    }
    if (sessionLines.length > 0) blocks.push(sessionLines.join('\n'));
    if (opts.weather) {
      const w = formatWeather(ctx);
      if (w) blocks.push(w);
    }
    return blocks.filter(Boolean).join('\n\n');
  };

  let text = assemble({ weather: true, notes: true, maxSegments: ctx.segments.length });

  if (approxTokens(text) > INSTRUCTION_TOKEN_CAP) {
    truncated.push('weather');
    text = assemble({ weather: false, notes: true, maxSegments: ctx.segments.length });
  }
  if (approxTokens(text) > INSTRUCTION_TOKEN_CAP) {
    truncated.push('notes');
    text = assemble({ weather: false, notes: false, maxSegments: ctx.segments.length });
  }
  let maxSegments = ctx.segments.length;
  while (approxTokens(text) > INSTRUCTION_TOKEN_CAP && maxSegments > 3) {
    maxSegments = Math.max(3, Math.floor(maxSegments / 2));
    if (!truncated.includes('segments')) truncated.push('segments');
    text = assemble({ weather: false, notes: false, maxSegments });
  }
  if (approxTokens(text) > INSTRUCTION_TOKEN_CAP) {
    truncated.push('hard_cap');
    text = text.slice(0, INSTRUCTION_TOKEN_CAP * 4);
  }

  if (truncated.length > 0) {
    logger.warn('live.instruction.truncated', {
      userId: ctx.userId,
      dropped: truncated,
      tokensApprox: approxTokens(text),
    });
  }

  return { text, tokensApprox: approxTokens(text), truncated };
}

function formatSegment(s: SegmentBrief): string {
  const range = `${fmtKm(s.kmStart)}–${fmtKm(s.kmEnd)}km`;
  const parts = [`${range} ${s.phase}`];
  if (s.targetPace) parts.push(`@ ${s.targetPace}`);
  if (s.instruction) parts.push(`— ${s.instruction}`);
  return parts.join(' ');
}

function formatWeather(ctx: LiveSessionContext): string {
  const w = ctx.weather;
  if (!w) return '';
  const parts: string[] = [];
  if (typeof w.temperatureC === 'number') parts.push(`${w.temperatureC}°C`);
  if (typeof w.humidityPercent === 'number') parts.push(`umidade ${w.humidityPercent}%`);
  if (typeof w.windKmh === 'number') parts.push(`vento ${w.windKmh}km/h`);
  if (parts.length === 0) return '';
  return [
    `CLIMA NO MOMENTO: ${parts.join(' · ')}.`,
    'Mencione o clima APENAS no primeiro turno (briefing), citando o número real.',
    'Depois disso NÃO repita o clima — só volte ao assunto se o turno do atleta liberar explicitamente, e mesmo assim em meia frase. Falar de clima em cada km é irritante.',
    'Bandas (pra usar QUANDO falar): calor (>25°C) → pace conservador + hidratação; frio (<13°C) → aquece mais antes de acelerar; umidade alta (>70%) → suor não dissipa, alerta sinais de fadiga térmica; vento contra forte (>15km/h) → custo extra, ajuste expectativa de pace.',
  ].join(' ');
}

function fmtKm(n: number): string {
  return Number.isInteger(n) ? String(n) : n.toFixed(1);
}
