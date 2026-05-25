import { UserProfile } from '@modules/users/domain/user.entity';
import { getPromptConfig } from '../config-store';
import { renderTemplate } from '../render';
import { resolvePersonaTone } from '../persona/resolver';
import { formatProfileContext } from '../context/profile-context';
import { stampVersion } from '../versions';
import { BuiltPrompt } from './types';

export interface PlanInitBuildInput {
  profile: Partial<UserProfile> | null | undefined;
  input: {
    goal: string;
    level: string;
    frequency: number;
    weeksCount: number;
    /** D0 escolhida pelo user no onboarding (ISO YYYY-MM-DD). */
    startDate?: string;
    /** Matiz fino do nível dentro de 'iniciante' (vindo da jornada de criação
     *  do plano: nunca_corri | esporadico | iniciante_freq). null se já
     *  cobre o enum direto (intermediario/avancado). */
    levelHint?: string | null;
    /** Volume atual do atleta em km/sem (informado na jornada). */
    currentWeeklyKm?: number | null;
    /** Pace atual confortável "M:SS/km" (informado na jornada). */
    currentPaceMinKm?: string | null;
    /** Dias em que o atleta pode treinar (1=seg…7=dom). [] = sem restrição. */
    availableDays?: number[] | null;
    /** Tipo de objetivo: 'flow' (sem prova) ou 'race' (meta de distância/pace). */
    goalKind?: 'flow' | 'race';
    /** Sub-meta dentro do FLOW: start | improve | injury_return | postpartum. */
    flowSubgoal?: 'start' | 'improve' | 'injury_return' | 'postpartum';
    /** Distância alvo quando goalKind=race (5, 10, 21, 42 km). */
    raceDistanceKm?: number;
    /** Modo da meta: completar a distância ou bater pace alvo. */
    raceMode?: 'complete' | 'improve_pace';
    /** Pace alvo M:SS/km (só quando raceMode=improve_pace). */
    targetPaceMinKm?: string;
    /** Modo da janela escolhida pelo user: agressiva / factível / segura.
     *  Quando 'aggressive' ou 'feasible', a culminação é OBRIGATÓRIA (plano
     *  termina com a meta sendo executada na última sessão). Quando 'safe'
     *  ou ausente, mantém filosofia de "fundação". */
    windowMode?: 'aggressive' | 'feasible' | 'safe';
    /** Dia preferido pro long run (1=seg…7=dom). */
    longRunDayOfWeek?: number;
    /** Data alvo da prova (ISO YYYY-MM-DD). Quando presente, prompt cita
     *  explicitamente "no dia DD/MM/AAAA você executa a sessão-meta" pra
     *  fixar o foco do LLM na culminação. */
    raceDate?: string;
    /** Tempo máximo disponível pro long run (em minutos). Coach calcula
     *  a distância max do long run respeitando esse cap. */
    longRunMaxMinutes?: number;
  };
  ragContext: string;
}

export async function buildPlanInitPrompt(args: PlanInitBuildInput): Promise<BuiltPrompt> {
  const { config, source } = await getPromptConfig('plan-init');
  const tone = await resolvePersonaTone(args.profile?.coachPersonality);

  const dowNames = ['', 'segunda', 'terça', 'quarta', 'quinta', 'sexta', 'sábado', 'domingo'];
  // startDate vem do onboarding ("começar hoje" ou "começar dia X"). Sem
  // ela, default = hoje. A semana 1 e a periodização toda começam aqui.
  const startIso = args.input.startDate ?? new Date().toISOString().slice(0, 10);
  const startD = new Date(`${startIso}T00:00:00`);
  const dow = startD.getDay() || 7;
  const endD = new Date(startD.getTime() + (args.input.weeksCount * 7 - 1) * 86_400_000);
  const today = {
    dayOfWeek: dow,
    weekday: dowNames[dow],
    dateLabel: `${String(startD.getDate()).padStart(2, '0')}/${String(startD.getMonth() + 1).padStart(2, '0')}/${startD.getFullYear()}`,
    endDateLabel: `${String(endD.getDate()).padStart(2, '0')}/${String(endD.getMonth() + 1).padStart(2, '0')}/${endD.getFullYear()}`,
  };

  // Bloco extra de contexto da jornada nova de criação do plano: matiz fino
  // do nível, volume/pace atuais, dias disponíveis, e tratamento especial pro
  // objetivo "Flow". Montamos um único parágrafo em `journey.context` que vai
  // no userTemplate — string vazia quando não há nada a comunicar, sem inflar
  // o prompt.
  const dayNamesShort = ['', 'seg', 'ter', 'qua', 'qui', 'sex', 'sáb', 'dom'];
  const goalNorm = (args.input.goal ?? '').toLowerCase();
  const isFlow = goalNorm === 'flow' || goalNorm.includes('flow');
  const journeyLines: string[] = [];
  if (args.input.levelHint) {
    const hintLabel =
      args.input.levelHint === 'nunca_corri'
        ? 'NUNCA correu antes — começar com walk-run conservador, foco em criar o hábito.'
        : args.input.levelHint === 'esporadico'
          ? 'Corre esporadicamente (1-2x/sem sem regularidade) — base aeróbica frágil, sem qualidade nas 3 primeiras semanas.'
          : 'Já corre com alguma frequência — pode aceitar 1 qualidade leve a partir da semana 2.';
    journeyLines.push(`Matiz do nível (refinamento dentro de "iniciante"): ${hintLabel}`);
  }
  if (typeof args.input.currentWeeklyKm === 'number' && args.input.currentWeeklyKm > 0) {
    journeyLines.push(`Volume atual auto-reportado: ~${args.input.currentWeeklyKm} km/sem — calibre a semana 1 NUNCA acima desse valor + 10%.`);
  }
  if (args.input.currentPaceMinKm) {
    journeyLines.push(`Pace confortável auto-reportado: ${args.input.currentPaceMinKm}/km — use como referência pro Easy Run (não acelere acima).`);
  }
  const days = args.input.availableDays ?? [];
  if (days.length > 0) {
    const label = days.map((d) => dayNamesShort[d] ?? '').filter(Boolean).join(', ');
    journeyLines.push(
      `Dias disponíveis pra treinar (HARD CONSTRAINT): ${label}. Distribua as sessões SOMENTE nestes dias. Se frequency (${args.input.frequency}) for menor que esses dias, escolha os melhores; se for maior, mantenha frequency = ${days.length}.`,
    );
  }
  // FLOW: bloco de melhoria contínua sem meta de prova. Sub-metas
  // refinam o protocolo (lesão/pós-parto pedem mais cautela; iniciar
  // pede walk-run; performance abre espaço pra qualidade).
  const isFlowGoal = args.input.goalKind === 'flow' || isFlow;
  if (isFlowGoal) {
    journeyLines.push(
      'Objetivo FLOW ("você contra você mesmo"): SEM meta de distância/pace específica. Construa um bloco de melhoria contínua com incrementos graduais (+5-10% volume/semana). Pace conversável (zona 1-2) na maioria das corridas. Os checkpoints semanais propõem evoluções — não force pace alvo agressivo aqui.',
    );
    if (args.input.flowSubgoal === 'start') {
      journeyLines.push(
        'Sub-meta FLOW: INICIAR. Atleta começando do zero (ou retomando após muito tempo parado). Walk-run obrigatório nas 3 primeiras semanas (alternância 1min trote / 2min caminhada). Zero qualidade. Sessões curtas (15-30min). Foco em hábito, não em distância.',
      );
    } else if (args.input.flowSubgoal === 'improve') {
      journeyLines.push(
        'Sub-meta FLOW: MELHORAR PERFORMANCE. Atleta já tem base. Permite 1-2 sessões de qualidade/sem (tempo run, fartlek, intervalado leve). Long run progressivo. Foco em estímulo variado pra romper plateau.',
      );
    } else if (args.input.flowSubgoal === 'injury_return') {
      journeyLines.push(
        'Sub-meta FLOW: VOLTA DE LESÃO. Pré-requisito: liberação médica (ler medicalConditions). Volume 50-60% do antigo histórico. ZERO qualidade nas 3-4 primeiras semanas — só easy + recovery + caminhada. Progressão conservadora 5-8%/sem. Cada sessão menciona "respeitando a recuperação" nas notes.',
      );
    } else if (args.input.flowSubgoal === 'postpartum') {
      journeyLines.push(
        'Sub-meta FLOW: PÓS-PARTO. Pré-requisito: liberação médica (ler medicalConditions; se ausente, primeira nota da semana 1 deve recomendar consulta antes de progredir). Iniciar com caminhada 2-4 semanas, depois walk-run muito gradual. ZERO qualidade nas primeiras 6 semanas. Atenção à hidratação (aleitamento) e fadiga (sono fragmentado). Sem cobrança de pace.',
      );
    }
  }

  // RACE: meta de distância (e opcionalmente pace). Plano SEMPRE culmina
  // na meta na última sessão da última semana — independente da janela.
  // O sanitizer `markTargetSession` pós-LLM garante (override de
  // distance+type+notes na última sessão), mas reforça aqui no prompt
  // pra economizar correção e dar contexto pro LLM periodizar certo.
  if (args.input.goalKind === 'race' && args.input.raceDistanceKm) {
    const dist = args.input.raceDistanceKm;
    const paceClause = args.input.raceMode === 'improve_pace' && args.input.targetPaceMinKm
      ? ` ao pace alvo de ${args.input.targetPaceMinKm}/km`
      : '';
    const raceDateClause = args.input.raceDate
      ? (() => {
          const [y, m, d] = args.input.raceDate!.split('-');
          return ` (data fixa da prova/meta: ${d}/${m}/${y})`;
        })()
      : '';
    const windowLabel = args.input.windowMode === 'aggressive'
      ? 'AGRESSIVA'
      : args.input.windowMode === 'feasible'
        ? 'FACTÍVEL'
        : 'SEGURA';
    journeyLines.push(
      `Objetivo RACE — janela ${windowLabel}${raceDateClause}: o plano DEVE culminar com o atleta executando ${dist}km${paceClause} na ÚLTIMA sessão da última semana — essa é a SESSÃO-META (type="${dist === 42 ? 'Maratona' : dist === 21 ? 'Meia Maratona' : dist + 'K'}", distanceKm=${dist}). Periodize pra isso: long run cresce gradualmente até atingir ${dist}km na semana de pico; qualidade (tempo run, intervalado específico) nas semanas centrais alinhada com o pace alvo; última semana = taper (volume reduzido nos dias anteriores) + SESSÃO-META no último dia disponível. NÃO trate este plano como "fundação" — é o ciclo completo até a meta.${args.input.raceDate ? ' Se a data da prova permitir antecipar (atleta progride bem nos checkpoints), o coach pode oferecer a sessão-meta antes — mas o plano BASE termina exatamente nessa data.' : ''}`,
    );
  }

  // Long run preferido (1=seg…7=dom) — quando user escolheu, força o LLM
  // a colocar o long run sempre nesse dia.
  if (args.input.longRunDayOfWeek) {
    const lrDay = dayNamesShort[args.input.longRunDayOfWeek] ?? '';
    journeyLines.push(
      `Dia preferido pro LONG RUN: ${lrDay}. SEMPRE coloque o Long Run da semana neste dia da semana, salvo quando dayOfWeek estiver fora dos availableDays (nesse caso escolha o dia mais próximo nos disponíveis).`,
    );
  }

  // Cap de tempo do long run — quando user disse "só tenho X minutos no
  // dia do long run", coach respeita esse teto. Estima distance = tempo
  // (min) / pace_easy_estimado (min/km). Atletas com cap baixo (60min)
  // crescerão o long run mais devagar — ok, é tradeoff aceito pra
  // viabilidade real.
  if (args.input.longRunMaxMinutes) {
    journeyLines.push(
      `Cap do LONG RUN: máximo ${args.input.longRunMaxMinutes} minutos de duração. NUNCA coloque um Long Run que exija mais tempo que isso. Calcule distanceKm máxima = ${args.input.longRunMaxMinutes} / pace_easy_estimado (min/km). Se mesmo o long run de pico exceder esse cap, distribua a quilometragem perdida em outra sessão de easy/recovery durante a semana.`,
    );
  }

  const journey = {
    context: journeyLines.length === 0 ? '' : `CONTEXTO DA JORNADA DE CRIAÇÃO DO PLANO (sobrepõe defaults do perfil):\n- ${journeyLines.join('\n- ')}`,
  };

  const values = {
    persona: { tone },
    profile: { context: formatProfileContext(args.profile) },
    input: args.input,
    journey,
    rag: args.ragContext,
    today,
  };

  return {
    systemPrompt: renderTemplate(config.systemPrompt, values),
    userPrompt: renderTemplate(config.userTemplate, values),
    maxTokens: config.maxTokens,
    temperature: config.temperature,
    ragChunks: config.ragChunks,
    version: stampVersion('plan-init', source),
    source,
  };
}
