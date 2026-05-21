import { PlanSession, PlanSegment } from '@modules/plans/domain/plan.entity';
import { getPromptConfig } from '@shared/infra/llm/prompts/config-store';
import { renderTemplate } from '@shared/infra/llm/prompts/render';
import { resolvePersonaTone } from '@shared/infra/llm/prompts/persona/resolver';
import { CoachRuntimeContext } from './coach-runtime-context.service';

/**
 * Monta o systemInstruction da sessão Gemini Live nativa que acompanha a
 * corrida inteira (Doc 5 §XIV — "Voz ao Vivo"). É o ÚNICO cérebro: recebe
 * os 3 inputs (contexto+segments, telemetria via turns, mood) e narra.
 *
 * Reaproveita o prompt `live-voice` (objetivo + estilo, editável em
 * /admin/prompts) e anexa o briefing compacto da sessão do dia + os
 * executionSegments do roteiro pra o coach comparar o desempenho real com
 * a fase planejada a cada km.
 *
 * IMPORTANTE: manter ENXUTO. SystemInstruction grande fechava o socket Live
 * com 1008 (safety filter / tamanho). Por isso segments viram 1 linha cada
 * e o perfil entra como snippet, não JSON.
 */
export async function buildRunCoachInstruction(
  runtime: CoachRuntimeContext,
  coachPersonality: string | null | undefined,
): Promise<string> {
  const { config } = await getPromptConfig('live-voice');
  const tone = await resolvePersonaTone(coachPersonality);

  const p = runtime.profile;
  const profileSnippet = p
    ? [
        p.name ? `nome ${p.name}` : null,
        p.level ? `nível ${p.level}` : null,
        p.goal ? `objetivo "${p.goal}"` : null,
        p.frequency ? `${p.frequency}x/semana` : null,
      ]
        .filter(Boolean)
        .join(', ')
    : 'sem perfil completo';

  const planSnippet = runtime.currentPlan
    ? `Plano em andamento (${runtime.currentPlan.weeksCount} semanas, ${runtime.currentPlan.goal}).`
    : 'Sem plano ativo (corrida livre).';

  const values = {
    persona: { tone },
    profile: { snippet: profileSnippet },
    plan: { snippet: planSnippet },
  };

  // Objetivo + estilo da voz (live-voice) + persona/perfil/plano.
  const base = [
    renderTemplate(config.systemPrompt, values),
    renderTemplate(config.userTemplate, values),
  ].join('\n\n');

  const sessionBlock = formatSessionBriefing(runtime.currentSession);

  // Como interpretar os turns: cada mensagem que chega é a VOZ DO ATLETA
  // falando com você em primeira pessoa (ex: "Coach, como estou indo? Fechei
  // o km 1: pace ..."). VOCÊ É O COACH e responde como coach — NUNCA como um
  // colega de corrida ("fechei sim, e vc?"), NUNCA pergunta de volta, NUNCA
  // assume que está correndo junto. Responda com UM feedback curto: leia as
  // métricas que o atleta passou (pace, pace alvo, tempo, elevação, frequência
  // cardíaca quando houver), compare com a fase atual do roteiro e dê uma
  // sugestão curta só quando estiver fora do planejado. Não fale sem o atleta
  // te chamar.
  const cadence = [
    'INTERAÇÃO: cada mensagem é o ATLETA falando em primeira pessoa pedindo seu',
    'feedback, já com as métricas da corrida. Você responde como COACH — afirma,',
    'orienta, nunca pergunta de volta e nunca fala como se também estivesse',
    'correndo. Um feedback curto por mensagem, comparando o pace/tempo reais com',
    'o alvo da fase atual do roteiro e sugerindo ajuste só quando fora do plano.',
  ].join(' ');

  return [base, '', sessionBlock, '', cadence].filter(Boolean).join('\n');
}

/** Briefing compacto da sessão do dia + roteiro km-a-km (1 linha por fase). */
function formatSessionBriefing(session: PlanSession | null): string {
  if (!session) {
    return 'SESSÃO DE HOJE: corrida livre (sem roteiro planejado). Comente o esforço real.';
  }
  const head: string[] = [`SESSÃO DE HOJE: ${session.type}`];
  if (typeof session.distanceKm === 'number') head.push(`${session.distanceKm}km`);
  if (session.targetPace) head.push(`pace alvo ${session.targetPace}`);
  if (typeof session.durationMin === 'number') head.push(`~${session.durationMin}min`);
  const lines = [head.join(' · ')];
  if (session.notes) lines.push(`Foco: ${session.notes}`);

  const segs = session.executionSegments ?? [];
  if (segs.length > 0) {
    lines.push('ROTEIRO (fases):');
    for (const s of segs) lines.push(`- ${formatSegment(s)}`);
  }
  return lines.join('\n');
}

function formatSegment(s: PlanSegment): string {
  const range = `${fmtKm(s.kmStart)}–${fmtKm(s.kmEnd)}km`;
  const parts = [`${range} ${s.phase}`];
  if (s.targetPace) parts.push(`@ ${s.targetPace}`);
  if (s.instruction) parts.push(`— ${s.instruction}`);
  return parts.join(' ');
}

function fmtKm(n: number): string {
  return Number.isInteger(n) ? String(n) : n.toFixed(1);
}
