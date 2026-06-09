import { createHash } from 'crypto';
import type { CoachContext } from './coach-message.use-case';
import type { CoachRuntimeContext } from './coach-runtime-context.service';
import type { PlanSession, PlanSegment } from '@modules/plans/domain/plan.entity';

/**
 * Templates determinísticos pros eventos mecânicos da corrida — substitui
 * o LLM em cues cuja informação é totalmente derivável de runtime data.
 *
 * Eventos cobertos:
 *   - no_movement
 *   - segment_start (3 sub-posições: first/middle/last)
 *   - segment_end (só pra última fase do roteiro)
 *   - check_in (idle 4min E distância 500m — distinguidos por presença de minIdle)
 *   - goal_reached
 *   - finish
 *
 * Eventos QUE CONTINUAM LLM (não cobertos aqui):
 *   - start (saudação rica com briefing)
 *   - km_reached (LLM, reage a pace/BPM)
 *   - pace_alert (contextual — porquê do desvio)
 *   - high_bpm (contextual — overtraining/calor?)
 *
 * Eventos NO-OP (não fala):
 *   - km_split (deletado — info subset de km_reached, mantido aceito por
 *     retrocompat com TFs antigas, retorna skipped)
 *
 * Seleção de variação: hash determinístico de (runId + event + index).
 * Mesma run nunca repete variação em sequência; runs diferentes pegam
 * ordens diferentes. Sem aleatoriedade — auditável.
 */

export type TemplateNoopReason =
  | 'deprecated_event'
  | 'no_segment_data'
  | 'transition_handled_by_start'
  | 'not_last_segment';

export type TemplateResult =
  | { kind: 'text'; text: string; source: 'template'; variation: number }
  | { kind: 'noop'; source: 'template'; reason: TemplateNoopReason };

export interface TemplateContext {
  ctx: CoachContext;
  runtime: CoachRuntimeContext;
  /** Para dedup server-side: se segment_start foi enviado nos últimos 5s
   *  e chega segment_end pra um segmento NÃO-último, suprimimos. */
  lastSegmentStartAtMs?: number;
}

/** Eventos cujo cue inteiro é deterministico — pulam LLM. */
const TEMPLATE_EVENTS = new Set<CoachContext['event']>([
  'no_movement',
  'segment_start',
  'segment_end',
  'goal_reached',
  'finish',
  'motivation', // motivation = check_in idle (legacy name) — quando vier do timer 4min
  'check_in',
]);

/** Eventos que viraram NO-OP (retrocompat). */
const NOOP_EVENTS = new Set<CoachContext['event']>(['km_split']);

/** True se o evento deve ser tratado por template (ou no-op). */
export function isTemplateEvent(event: CoachContext['event']): boolean {
  return TEMPLATE_EVENTS.has(event) || NOOP_EVENTS.has(event);
}

/**
 * Resolve o cue por template. Retorna `null` se evento NÃO é template
 * (caller segue pro LLM). Retorna `noop` quando o evento foi
 * intencionalmente silenciado (km_split, ou segment_end suprimido por
 * dedup com segment_start recente).
 */
export function tryBuildTemplate(
  tctx: TemplateContext,
): TemplateResult | null {
  const { ctx } = tctx;
  if (NOOP_EVENTS.has(ctx.event)) {
    return { kind: 'noop', source: 'template', reason: 'deprecated_event' };
  }
  if (!TEMPLATE_EVENTS.has(ctx.event)) return null;

  switch (ctx.event) {
    case 'no_movement':
      return buildNoMovement(tctx);
    case 'segment_start':
      return buildSegmentStart(tctx);
    case 'segment_end':
      return buildSegmentEnd(tctx);
    case 'goal_reached':
      return buildGoalReached(tctx);
    case 'finish':
      return buildFinish(tctx);
    case 'motivation':
      return buildCheckInIdle(tctx);
    case 'check_in':
      // check_in por distância (500m) — distinguido de motivation que é idle
      return buildCheckInDistance(tctx);
    default:
      return null;
  }
}

// =============================================================================
// Variable resolvers
// =============================================================================

interface ResolvedVars {
  /** Vocativo pronto pra uso: ", Eduardo" ou "" — caller insere onde precisa */
  voc: string;
  /** Nome puro (sem vírgula): "Eduardo" ou "" */
  nome: string;
  /** sessionType: "Easy Run", "Tempo Run" — fallback "corrida" */
  sessionType: string;
  /** Pace atual formatado MM:SS — null safe */
  currentPace: string | null;
  /** Pace dos últimos 500m — fallback no currentPace se ausente */
  pace500m: string | null;
  /** Target pace formatado — null se sem alvo */
  targetPace: string | null;
  /** BPM atual */
  bpm: number | null;
  /** km já percorridos (floor) */
  kmDone: number;
  /** km restantes da sessão planejada */
  kmRemaining: number | null;
  /** Tempo decorrido MM:SS */
  elapsed: string;
  /** Calorias estimadas (MET-based, peso × tempo × 9.8/3600) */
  calories: number | null;
  /** Total planejado em km */
  plannedKm: number | null;
}

function resolveVars(tctx: TemplateContext): ResolvedVars {
  const { ctx, runtime } = tctx;
  const profile = runtime.profile;
  const session = runtime.currentSession;
  const firstName = profile?.name?.split(' ')[0] ?? '';

  const plannedKm = session?.distanceKm ?? null;
  const kmDone = Math.floor(ctx.distanceM / 100) / 10; // 1 casa decimal
  const kmRemaining = plannedKm != null
    ? Math.max(0, Number((plannedKm - kmDone).toFixed(1)))
    : null;

  const calories = (typeof profile?.weight === 'number' && ctx.elapsedS > 0)
    ? Math.round((9.8 * profile.weight * ctx.elapsedS) / 3600)
    : null;

  return {
    voc: firstName ? `, ${firstName}` : '',
    nome: firstName,
    sessionType: session?.type ?? ctx.runType ?? 'corrida',
    currentPace: formatPace(ctx.currentPaceMinKm),
    pace500m: formatPace(ctx.currentPaceMinKm),
    targetPace: formatPace(ctx.targetPaceMinKm),
    bpm: ctx.bpm ?? null,
    kmDone,
    kmRemaining,
    elapsed: formatTime(ctx.elapsedS),
    calories,
    plannedKm,
  };
}

function formatPace(minKm: number | undefined | null): string | null {
  if (minKm == null || !Number.isFinite(minKm) || minKm <= 0) return null;
  const totalSec = Math.round(minKm * 60);
  const min = Math.floor(totalSec / 60);
  const sec = totalSec % 60;
  return `${min}:${sec.toString().padStart(2, '0')}`;
}

function formatTime(seconds: number): string {
  const s = Math.max(0, Math.round(seconds));
  const m = Math.floor(s / 60);
  const r = s % 60;
  return `${m}:${r.toString().padStart(2, '0')}`;
}

// =============================================================================
// Variation selector — deterministic hash-based
// =============================================================================

function pickVariation(seed: string, count: number): number {
  if (count <= 1) return 0;
  const hash = createHash('sha1').update(seed).digest();
  // pega 4 bytes como uint32 e tira módulo
  const n = hash.readUInt32BE(0);
  return n % count;
}

function seedFor(ctx: CoachContext, suffix: string = ''): string {
  return `${ctx.runId ?? 'no_run'}|${ctx.event}|${suffix}`;
}

// =============================================================================
// no_movement
// =============================================================================

function buildNoMovement(tctx: TemplateContext): TemplateResult {
  const v = resolveVars(tctx);
  const variations: ((v: ResolvedVars) => string)[] = [
    (v) => `Oi${v.voc}, tô esperando o GPS pegar aqui. Tá demorando um pouco — dá uma olhada no sinal, ok?`,
    (v) => `Sem movimento há 30 segundos${v.voc}. Quer dar uma checada se o GPS travou?`,
  ];
  const idx = pickVariation(seedFor(tctx.ctx), variations.length);
  return { kind: 'text', text: variations[idx]!(v), source: 'template', variation: idx };
}

// =============================================================================
// segment_start (FIRST / MIDDLE / LAST)
// =============================================================================

interface SegmentSnapshot {
  index: number;        // 0-based
  total: number;
  current: PlanSegment;
  previous?: PlanSegment;
  position: 'first' | 'middle' | 'last';
  typeName: string;
  trainingIntent: string;
  distanceKm: number;
  /** Estima duração em min via distance / targetPace (se ambos presentes). */
  durationMin: number | null;
  instructionSnippet: string;
}

function buildSegmentStart(tctx: TemplateContext): TemplateResult {
  const seg = snapshotSegment(tctx);
  if (!seg) {
    // Sem segmento estruturado disponível — caller cai pro LLM (retorna null
    // pra coach-message.use-case.ts seguir o fluxo normal).
    return { kind: 'noop', source: 'template', reason: 'no_segment_data' };
  }
  const v = resolveVars(tctx);
  // O targetPace nas variáveis vem do ctx (session-level). Em segment_start
  // sempre prevalece o pace do segmento atual — é o que o coach precisa
  // anunciar ("acelera pra 5:00 nesse segmento de tempo run").
  const segmentTarget = seg.current.targetPace ?? v.targetPace;
  const scopedVars: ResolvedVars = { ...v, targetPace: segmentTarget };

  let variations: ((v: ResolvedVars, s: SegmentSnapshot) => string)[];
  switch (seg.position) {
    case 'first':
      variations = SEGMENT_START_FIRST;
      break;
    case 'last':
      variations = SEGMENT_START_LAST;
      break;
    case 'middle':
    default:
      variations = SEGMENT_START_MIDDLE;
  }
  const idx = pickVariation(seedFor(tctx.ctx, `seg${seg.index}`), variations.length);
  return { kind: 'text', text: variations[idx]!(scopedVars, seg), source: 'template', variation: idx };
}

const SEGMENT_START_FIRST: ((v: ResolvedVars, s: SegmentSnapshot) => string)[] = [
  (v, s) =>
    `Bora começar${v.voc}! Primeiros ${s.distanceKm}km a pace ${paceOr(v.targetPace, 'leve')} — é seu aquecimento. Solta o corpo, sem pressa, deixa a respiração entrar no ritmo.${suffixIf(s.instructionSnippet)}`,
  (v, s) =>
    `Vamos lá${v.voc}. Abrimos com ${s.typeName}: ${durOrDist(s.durationMin, s.distanceKm)} no pace ${paceOr(v.targetPace, 'leve')}. Foca em forma, tronco solto, vai puxando ar tranquilo. Eu te acompanho.`,
  (v, s) =>
    `Tô aqui contigo${v.voc}. Primeira parte é ${s.typeName} — ${s.distanceKm}km no pace ${paceOr(v.targetPace, 'leve')}. Esse pace tá easy de propósito, é pra preparar o motor antes da parte boa do treino.`,
  (v, s) =>
    `Sessão começa${v.voc}. Aquecimento: ${s.distanceKm}km a ${paceOr(v.targetPace, 'pace conversável')}, ritmo conversável. Sem afobação — isso aqui é preparação. A parte forte vem depois.`,
];

const SEGMENT_START_MIDDLE: ((v: ResolvedVars, s: SegmentSnapshot) => string)[] = [
  (v, s) =>
    `Boa${v.voc}! Fechamos ${s.previous ? typeNameOf(s.previous.phase) : 'a fase anterior'}. Agora começa a parte que importa: ${s.distanceKm}km a pace ${paceOr(v.targetPace, 'firme')} — isso é ${s.trainingIntent}.${suffixIf(s.instructionSnippet)} Eu sei que você consegue, mantém forma firme.`,
  (v, s) =>
    `${s.previous ? `${capitalize(typeNameOf(s.previous.phase))} no bolso` : 'Aquecimento no bolso'}${v.voc}. Agora ${s.typeName}: alvo é pace ${paceOr(v.targetPace, 'firme')} por ${durOrDist(s.durationMin, s.distanceKm)}. Esse é ${s.trainingIntent} — esforço controlado, respiração ritmada, sem all-out. Bora.`,
  (v, s) =>
    `${s.previous ? `${capitalize(typeNameOf(s.previous.phase))} fechada` : 'Fase anterior fechada'}${v.voc}. Próxima fase é ${s.typeName}: você vai segurar pace ${paceOr(v.targetPace, 'firme')} por ${s.distanceKm}km. ${capitalize(s.trainingIntent)} — é o ponto central da sessão hoje. Confia no processo.`,
  (v, s) =>
    `Tô vendo seu aquecimento${v.voc}, mandou bem. Bora pra fase ${s.index + 1} de ${s.total}: ${s.typeName} a pace ${paceOr(v.targetPace, 'firme')}, ${s.distanceKm}km. ${capitalize(s.trainingIntent)}. Você sabe fazer, eu sigo contigo.`,
];

const SEGMENT_START_LAST: ((v: ResolvedVars, s: SegmentSnapshot) => string)[] = [
  (v, s) =>
    `Última fase${v.voc}! ${s.typeName}: ${s.distanceKm}km a pace ${paceOr(v.targetPace, 'controlado')}. Fecha controlado, sem afundar — você fez o trabalho pesado, agora é finalizar com forma.`,
  (v, s) =>
    `Final do roteiro chegou${v.voc}. ${s.typeName} agora — ${durOrDist(s.durationMin, s.distanceKm)} a ${paceOr(v.targetPace, 'pace leve')}. Você fez tudo certo até aqui, esse é só o fechamento. Vai com calma.`,
  (v, s) =>
    `Bora fechar${v.voc}. ${s.typeName} é a última fase: pace ${paceOr(v.targetPace, 'controlado')} até completar. Segura forma firme, controla respiração. Tô contigo até o fim.`,
];

// =============================================================================
// segment_end (só pra ÚLTIMA fase)
// =============================================================================

function buildSegmentEnd(tctx: TemplateContext): TemplateResult {
  const seg = snapshotSegment(tctx);
  if (!seg) {
    return { kind: 'noop', source: 'template', reason: 'no_segment_data' };
  }
  // Dedup: se segment_start foi enviado nos últimos 5s (transição comum),
  // suprimimos esse segment_end. A transição já foi comunicada pelo start.
  const lastStart = tctx.lastSegmentStartAtMs ?? 0;
  if (Date.now() - lastStart < 5000) {
    return { kind: 'noop', source: 'template', reason: 'transition_handled_by_start' };
  }
  // Só fala se é a ÚLTIMA fase. Pra fases do meio, o segment_start próximo
  // que carrega a narrativa de transição.
  if (seg.position !== 'last') {
    return { kind: 'noop', source: 'template', reason: 'not_last_segment' };
  }

  const v = resolveVars(tctx);
  const variations: ((v: ResolvedVars, s: SegmentSnapshot) => string)[] = [
    (v, s) =>
      `Fechamos a ${s.typeName}${v.voc} — pace médio ${v.currentPace ?? 'estável'}${v.targetPace ? `, alvo era ${v.targetPace}` : ''}. Roteiro do dia inteiro entregue. Bom trabalho até aqui.`,
    (v, s) =>
      `Última fase no bolso${v.voc}. ${s.typeName} em ${v.elapsed}, pace médio ${v.currentPace ?? 'consistente'}. Você cumpriu o que o plano pediu hoje.`,
    (v, s) =>
      `Pronto${v.voc}. Última fase fechada — ${v.currentPace ?? 'pace'} médio${v.targetPace ? `, dentro do alvo de ${v.targetPace}` : ''}.${v.kmRemaining != null && v.kmRemaining > 0 ? ` Faltam só ${v.kmRemaining}km pra completar a distância total da sessão.` : ''}`,
  ];
  const idx = pickVariation(seedFor(tctx.ctx, `seg${seg.index}`), variations.length);
  return { kind: 'text', text: variations[idx]!(v, seg), source: 'template', variation: idx };
}

// =============================================================================
// check_in idle (4min sem coach falar)
// =============================================================================

function buildCheckInIdle(tctx: TemplateContext): TemplateResult {
  const v = resolveVars(tctx);
  const minIdle = 4; // fallback se ctx não trouxer — coach abre o check-in em 4min
  const variations: ((v: ResolvedVars) => string)[] = [
    (v) =>
      `Oi${v.voc}, ainda tô aqui — ${minIdle} minutos em silêncio porque tá tudo certinho do meu lado. Pace ${v.currentPace ?? 'firme'}${v.bpm ? `, FC ${v.bpm}` : ''}, tá no rumo.`,
    (v) =>
      `${v.nome ? v.nome + ', segue firme' : 'Segue firme'}. ${v.kmRemaining != null ? `Faltam ${v.kmRemaining}km` : 'Falta pouco'} pra fechar a ${v.sessionType}. Você tá em zona aeróbica — bom sinal, adaptação acontecendo.`,
    (v) =>
      `Tô acompanhando${v.voc}. Faz ${minIdle} minutos sem novidade — sinal que você tá fluindo. Respiração ritmada? Tronco solto?`,
    (v) =>
      `Sem alertas${v.voc} — tudo dentro do plano. Pace ${v.currentPace ?? 'firme'}${v.bpm ? `, FC ${v.bpm} controlada` : ''}. Mantém o esforço, eu sigo de olho aqui.`,
  ];
  const idx = pickVariation(seedFor(tctx.ctx, `${tctx.ctx.elapsedS >> 6}`), variations.length);
  return { kind: 'text', text: variations[idx]!(v), source: 'template', variation: idx };
}

// =============================================================================
// check_in distância (500m sem coach falar)
// =============================================================================

function buildCheckInDistance(tctx: TemplateContext): TemplateResult {
  const v = resolveVars(tctx);
  const variations: ((v: ResolvedVars) => string)[] = [
    (v) =>
      `Tô vendo seu pace aqui${v.voc} — últimos 500m em ${v.pace500m ?? 'pace firme'}. ${v.targetPace ? `Mantendo o alvo de ${v.targetPace} bem dentro` : 'Cadência consistente'}. Continua, tá ótimo.`,
    (v) =>
      `${v.nome ? v.nome + ', passou de ' + v.kmDone + 'km' : `Passou de ${v.kmDone}km`}. Pace nos últimos 500m foi ${v.pace500m ?? 'consistente'}${v.targetPace ? `, alvo ${v.targetPace}` : ''}. Tá no rumo certo — mantém forma, ombros baixos.`,
    (v) =>
      `Bora${v.voc}. ${v.kmRemaining != null && v.kmRemaining > 0 ? `${v.kmRemaining}km pra fechar` : 'Reta final'}. Pace estável em ${v.pace500m ?? 'ritmo firme'}${v.bpm ? `, FC em ${v.bpm}` : ''}. Foca na respiração, tronco solto.`,
    (v) =>
      `Acompanhando aqui${v.voc}. ${v.kmDone}km feitos, ${v.pace500m ?? 'pace'} médio. Você tá conduzindo bem essa sessão — segue confiante.`,
  ];
  const idx = pickVariation(seedFor(tctx.ctx, `km${Math.floor(tctx.ctx.distanceM / 500)}`), variations.length);
  return { kind: 'text', text: variations[idx]!(v), source: 'template', variation: idx };
}

// =============================================================================
// goal_reached
// =============================================================================

function buildGoalReached(tctx: TemplateContext): TemplateResult {
  const v = resolveVars(tctx);
  const totalKm = v.plannedKm ?? v.kmDone;
  const variations: ((v: ResolvedVars) => string)[] = [
    (v) =>
      `Você bateu o objetivo${v.voc}! ${totalKm}km completados em ${v.elapsed}. Se quiser fechar agora, eu encerro pra você. Se preferir continuar correndo, eu sigo do seu lado — escolha é sua.`,
    (v) =>
      `Cumprimos a ${v.sessionType} hoje${v.voc} — ${totalKm}km em ${v.elapsed}${v.currentPace ? `, pace médio ${v.currentPace}` : ''}. Continuar é bônus, mas eu sigo contigo se quiser explorar um pouco mais.`,
    (v) =>
      `${v.nome ? v.nome + ', objetivo do dia feito!' : 'Objetivo do dia feito!'} ${totalKm}km em ${v.elapsed}${v.bpm ? `, FC média ${v.bpm}` : ''}. Daqui pra frente é território extra, sem cobrança — eu continuo no seu ritmo enquanto você quiser correr.`,
    (v) =>
      `Bati a meta${v.voc}. ${totalKm}km a ${v.currentPace ?? 'pace consistente'} médio — tudo dentro da zona certa. Pode parar tranquilo agora ou seguir mais um pouco, decisão é toda sua.`,
  ];
  const idx = pickVariation(seedFor(tctx.ctx), variations.length);
  return { kind: 'text', text: variations[idx]!(v), source: 'template', variation: idx };
}

// =============================================================================
// finish (após user dar stop)
// =============================================================================

function buildFinish(tctx: TemplateContext): TemplateResult {
  const v = resolveVars(tctx);
  // Distância final com 2 decimais (5.02km, 10.15km) — fechamento merece
  // precisão. Strings prontas pra preservar trailing zeros (Number strip).
  const totalKm = (tctx.ctx.distanceM / 1000).toFixed(2);
  const cal = v.calories ?? null;
  const variations: ((v: ResolvedVars) => string)[] = [
    (v) =>
      `Boa${v.voc}! Fechamos a sessão: ${totalKm}km em ${v.elapsed}${v.currentPace ? `, pace médio ${v.currentPace}` : ''}${v.bpm ? `, FC média ${v.bpm}` : ''}${cal ? `, ${cal} calorias queimadas` : ''}. Tá tudo guardado aqui. Bora dar uma olhada na análise completa do coach na tela de relatório — detalhei a sessão lá com mais nuance.`,
    (v) =>
      `Run concluída${v.voc}. ${totalKm}km em ${v.elapsed}${v.currentPace ? ` a ${v.currentPace} médio` : ''}. A análise completa do coach já carregou na tela de relatório — explica tendência e o que vem na próxima sessão. Vale a leitura.`,
    (v) =>
      `Fechamos a sessão${v.voc}: ${totalKm}km, ${v.elapsed}${v.currentPace ? `, pace ${v.currentPace}` : ''}${v.bpm ? `, FC média ${v.bpm}` : ''}. Bom trabalho hoje. Os detalhes técnicos e a tendência das últimas semanas tão no relatório da run — abre lá pra ver.`,
  ];
  const idx = pickVariation(seedFor(tctx.ctx), variations.length);
  return { kind: 'text', text: variations[idx]!(v), source: 'template', variation: idx };
}

// =============================================================================
// Segment snapshot — resolve position / typeName / trainingIntent
// =============================================================================

function snapshotSegment(tctx: TemplateContext): SegmentSnapshot | null {
  const session = tctx.runtime.currentSession;
  const segments = session?.executionSegments;
  if (!session || !segments || segments.length === 0) return null;

  // Index: o client manda currentSegmentIndex em eventos segment_*.
  // Fallback: deriva por distanceM cruzado.
  const explicitIdx = tctx.ctx.currentSegmentIndex;
  const derivedIdx = (() => {
    const kmDone = tctx.ctx.distanceM / 1000;
    for (let i = 0; i < segments.length; i++) {
      const s = segments[i]!;
      if (kmDone >= s.kmStart && kmDone < s.kmEnd) return i;
    }
    // Se passou de todos, considera o último
    return segments.length - 1;
  })();
  const index = explicitIdx != null && explicitIdx >= 0 && explicitIdx < segments.length
    ? explicitIdx
    : derivedIdx;

  const current = segments[index]!;
  const previous = index > 0 ? segments[index - 1] : undefined;
  const total = segments.length;
  const position: 'first' | 'middle' | 'last' =
    index === 0 ? 'first' : index === total - 1 ? 'last' : 'middle';

  const distanceKm = Math.max(0.1, Number((current.kmEnd - current.kmStart).toFixed(1)));
  const targetPaceMin = parsePaceToMin(current.targetPace ?? session.targetPace);
  const durationMin = (targetPaceMin != null && distanceKm > 0)
    ? Math.round(targetPaceMin * distanceKm)
    : null;

  return {
    index,
    total,
    current,
    previous,
    position,
    typeName: typeNameOf(current.phase),
    trainingIntent: trainingIntentOf(current.phase),
    distanceKm,
    durationMin,
    instructionSnippet: shortInstruction(current),
  };
}

function typeNameOf(type: string | undefined): string {
  const t = (type ?? '').toLowerCase();
  if (t.includes('warmup') || t.includes('aquecimento')) return 'Aquecimento';
  if (t.includes('tempo')) return 'Tempo Run';
  if (t.includes('interval') || t.includes('tiro')) return 'Intervalado';
  if (t.includes('fartlek')) return 'Fartlek';
  if (t.includes('long')) return 'Long Run';
  if (t.includes('recovery') || t.includes('cooldown')) return 'Recuperação';
  if (t.includes('progressivo') || t.includes('progressive')) return 'Progressivo';
  if (t.includes('easy')) return 'Easy Run';
  return type ?? 'Fase';
}

function trainingIntentOf(type: string | undefined): string {
  const t = (type ?? '').toLowerCase();
  if (t.includes('tempo')) return 'pace de limiar aeróbico';
  if (t.includes('interval') || t.includes('tiro')) return 'pace forte com recuperação ativa';
  if (t.includes('fartlek')) return 'alternância controlada de intensidade';
  if (t.includes('long')) return 'pace easy pra resistência aeróbica';
  if (t.includes('recovery') || t.includes('cooldown')) return 'pace leve pra ativar recuperação';
  if (t.includes('progressivo') || t.includes('progressive')) return 'começar leve e ir aumentando';
  if (t.includes('warmup') || t.includes('aquecimento')) return 'pace conversável pra preparar o motor';
  return 'pace controlado conforme o plano';
}

function shortInstruction(seg: PlanSegment): string {
  // PlanSegment tem `instruction` (obrigatório). Pega 1ª frase pra não
  // sobrecarregar o cue. Se vazio, retorna ''.
  const text = seg.instruction;
  if (!text || typeof text !== 'string') return '';
  const cleaned = text.trim().replace(/\s+/g, ' ');
  if (cleaned.length === 0) return '';
  const firstSentence = cleaned.split(/(?<=[.!?])\s+/)[0] ?? cleaned;
  return firstSentence.length > 80 ? firstSentence.slice(0, 77) + '...' : firstSentence;
}

// =============================================================================
// Helpers
// =============================================================================

function paceOr(pace: string | null, fallback: string): string {
  return pace ?? fallback;
}

function durOrDist(durationMin: number | null, distanceKm: number): string {
  if (durationMin != null && durationMin > 0) return `${durationMin} minutos`;
  return `${distanceKm}km`;
}

function suffixIf(snippet: string | null | undefined): string {
  return snippet && snippet.length > 0 ? ` ${snippet}` : '';
}

function capitalize(s: string): string {
  if (!s) return s;
  return s.charAt(0).toUpperCase() + s.slice(1);
}

function parsePaceToMin(pace: string | undefined | null): number | null {
  if (!pace) return null;
  const m = pace.match(/^(\d+):(\d{2})$/);
  if (!m) return null;
  const min = parseInt(m[1]!, 10);
  const sec = parseInt(m[2]!, 10);
  return min + sec / 60;
}
