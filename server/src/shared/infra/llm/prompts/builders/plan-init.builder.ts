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
    /** Distância confortável recente em km (chip 3/5/10/21/42). Base do cap
     *  de long run das primeiras semanas. */
    capacityDistanceKm?: number | null;
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

  // ─── DADOS DO ASSESSMENT (HARD CONSTRAINTS) ─────────────────────────────
  // Todos os campos do onboarding aparecem aqui — incluindo os NÃO
  // INFORMADOS — pra o LLM não cair em defaults silenciosos. Cada campo
  // informado vira REGRA DURA quando aplicável. Campos NÃO INFORMADOS
  // recebem heurística do level explicitamente.
  const assessmentLines: string[] = [];
  if (args.input.levelHint) {
    const hintLabel =
      args.input.levelHint === 'nunca_corri'
        ? 'NUNCA correu antes — começar com walk-run conservador, foco em criar o hábito.'
        : args.input.levelHint === 'esporadico'
          ? 'Corre esporadicamente (1-2x/sem sem regularidade) — base aeróbica frágil, sem qualidade nas 3 primeiras semanas.'
          : 'Já corre com alguma frequência — pode aceitar 1 qualidade leve a partir da semana 2.';
    assessmentLines.push(`Matiz do nível (refinamento dentro de "iniciante"): ${hintLabel}`);
  }

  const hasWeeklyKm = typeof args.input.currentWeeklyKm === 'number' && args.input.currentWeeklyKm > 0;
  if (hasWeeklyKm) {
    assessmentLines.push(
      `Volume semanal atual: ${args.input.currentWeeklyKm} km/sem (REPORTADO PELO ATLETA). ` +
      `REGRA DURA: o volume total da Semana 1 NUNCA pode exceder ${(args.input.currentWeeklyKm! * 1.1).toFixed(1)} km (=1.1× reportado). Cresça as semanas seguintes em rampa 5-10%/sem.`,
    );
  } else {
    assessmentLines.push(
      'Volume semanal atual: NÃO INFORMADO — use heurística conservadora pelo nível ' +
      `(${args.input.level === 'iniciante' ? '5-15 km/sem na semana 1' : args.input.level === 'intermediario' ? '20-30 km/sem' : '35-50 km/sem'}).`,
    );
  }

  const hasPace = !!args.input.currentPaceMinKm;
  if (hasPace) {
    assessmentLines.push(
      `Pace confortável: ${args.input.currentPaceMinKm}/km (REPORTADO PELO ATLETA). ` +
      'REGRA DURA — DERIVAÇÃO DE PACES POR TIPO DE SESSÃO a partir desse pace P:\n' +
      '    • Easy Run / Long Run: P + 30 a 60s/km (zona conversável)\n' +
      '    • Recovery: P + 60 a 90s/km (zona regenerativa)\n' +
      '    • Tempo Run / Progressivo: P − 10 a 20s/km (limiar confortavelmente difícil)\n' +
      '    • Intervalado / Tiros / Fartlek (no esforço): P − 30 a 45s/km\n' +
      '    • Caminhada: pace próprio de caminhada (não derivar)\n' +
      '  Esses paces são MAIS RÁPIDOS que os defaults do nível — RESPEITE o reportado, NÃO desconte aplicando defaults de iniciante por cima.',
    );
  } else {
    assessmentLines.push(
      'Pace confortável: NÃO INFORMADO — derive paces das heurísticas do nível ' +
      `(${args.input.level === 'iniciante' ? '~7-8min/km zona 2' : args.input.level === 'intermediario' ? '~5-6min/km' : '~4-5min/km'}).`,
    );
  }

  const hasCapacityDist = typeof args.input.capacityDistanceKm === 'number' && args.input.capacityDistanceKm > 0;
  if (hasCapacityDist) {
    assessmentLines.push(
      `Distância confortável recente: ${args.input.capacityDistanceKm} km (REPORTADO PELO ATLETA). ` +
      `REGRA DURA: Long Run das 4 primeiras semanas NUNCA acima de ${(args.input.capacityDistanceKm! * 1.5).toFixed(1)} km (=1.5× reportado). Cresça progressivamente nas semanas seguintes.`,
    );
  } else {
    assessmentLines.push(
      'Distância confortável recente: NÃO INFORMADO — começar Long Run com cap conservador pelo nível ' +
      `(${args.input.level === 'iniciante' ? '4-6 km' : args.input.level === 'intermediario' ? '10-14 km' : '16-22 km'}).`,
    );
  }

  // Frequência semanal alvo: sempre auditar (o LLM tende a propor < frequency
  // pra "ser conservador"; precisa ouvir explicitamente que freq é HARD).
  assessmentLines.push(
    `Frequência semanal alvo: ${args.input.frequency} sessões/sem (REPORTADO PELO ATLETA). REGRA DURA: cada semana DEVE ter exatamente ${args.input.frequency} sessões de treino (sem contar caminhada como "extra"). Não reduza por conta própria.`,
  );

  const days = args.input.availableDays ?? [];
  if (days.length > 0) {
    const label = days.map((d) => dayNamesShort[d] ?? '').filter(Boolean).join(', ');
    assessmentLines.push(
      `Dias disponíveis (REPORTADO PELO ATLETA): ${label}. REGRA DURA: distribua as sessões SOMENTE nesses dias. Se frequency (${args.input.frequency}) for menor que esses dias, escolha os melhores; se maior, mantenha frequency = ${days.length}.`,
    );
  } else {
    assessmentLines.push('Dias disponíveis: NÃO INFORMADO — IA escolhe livremente.');
  }

  // Long run preferências (movido pra cá pra centralizar o bloco
  // "ASSESSMENT"; instruções imperativas permanecem).
  if (args.input.longRunDayOfWeek) {
    const lrDay = dayNamesShort[args.input.longRunDayOfWeek] ?? '';
    assessmentLines.push(
      `Long Run no ${lrDay} (REPORTADO PELO ATLETA). REGRA DURA: SEMPRE coloque o Long Run da semana neste dia, salvo se fora dos availableDays (nesse caso o dia mais próximo nos disponíveis).`,
    );
  }
  if (args.input.longRunMaxMinutes) {
    assessmentLines.push(
      `Tempo máximo do Long Run: ${args.input.longRunMaxMinutes} minutos (REPORTADO PELO ATLETA). REGRA DURA: NUNCA proponha Long Run que exija mais tempo. distanceKm_max = ${args.input.longRunMaxMinutes} / pace_easy_estimado.`,
    );
  }

  // Adiciona o bloco completo ao journey final (header explicativo no topo)
  if (assessmentLines.length > 0) {
    journeyLines.push(
      'DADOS DO ASSESSMENT DO ATLETA (HARD CONSTRAINTS — todos os valores REPORTADOS são lei; NUNCA os contradiga; use defaults do level APENAS pros campos marcados NÃO INFORMADO):',
    );
    for (const line of assessmentLines) journeyLines.push(`  • ${line}`);
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
    if (args.input.raceMode === 'improve_pace' && args.input.targetPaceMinKm) {
      const tp = args.input.targetPaceMinKm;
      journeyLines.push(
        `REGRA DURA — TARGET PACE: a SESSÃO-META (última da última semana) DEVE ter targetPace = "${tp}" (não mais lento). Sessões de QUALIDADE (Tempo Run, Tiros, Intervalado, Progressivo, Fartlek) nas semanas centrais (entre 40% e 90% do plano) DEVEM aproximar-se de ${tp}/km — pace ≤ ${tp} no esforço principal. Esses paces NÃO podem ser mais lentos que os defaults do level; o atleta declarou meta concreta.`,
      );
    }
  }

  // Long run prefs (longRunDayOfWeek + longRunMaxMinutes) já estão no bloco
  // "DADOS DO ASSESSMENT" acima como REGRAS DURAS.

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
