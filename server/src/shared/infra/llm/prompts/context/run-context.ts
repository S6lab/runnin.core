export interface RunContextInput {
  runId?: string;
  event?: string;
  runType?: string;
  currentPaceMinKm?: number;
  targetPaceMinKm?: number;
  distanceM?: number;
  elapsedS?: number;
  bpm?: number;
  kmReached?: number;
  /** Tempo (s) do km que acabou de ser cruzado — duração do km, não acumulado. */
  kmDurationS?: number;
  /** FC média (bpm) durante o km que acabou de ser cruzado. */
  kmAvgBpm?: number;
  /** Calorias estimadas (kcal) do km — derivado server-side de MET × peso × tempo. */
  kmCalories?: number;
  /** Nome do atleta — pra coach personalizar a saudação ("Muito bem, João..."). */
  athleteName?: string;
  /** Índice (0-based) do segment ativo na PlanSession do dia. Setado
   *  pelo client quando há plano com executionSegments. Server resolve
   *  o segment correspondente via runtime.currentSession. */
  currentSegmentIndex?: number;
  /** Snapshot de clima do local da corrida (capturado pelo app ao iniciar
   *  o run). Opcional — quando ausente, coach não fala sobre clima. */
  temperatureC?: number;
  humidityPercent?: number;
  windKmh?: number;
}

/** Pace double (min/km) → "5min30" pra Gemini narrar corretamente. TF 81
 *  (Issue #3): formato anterior `5:30` era lido como "cinco mil por km"
 *  (Gemini parsing :00 como milhar) ou "sete vírgula 45" (Gemini parsing :
 *  como vírgula decimal). `5min30` evita ambiguidade — TTS expande pra
 *  "cinco minutos e trinta segundos". */
function formatPaceMmSs(p: number | undefined): string | null {
  if (typeof p !== 'number' || !isFinite(p) || p <= 0) return null;
  const min = Math.floor(p);
  const sec = Math.round((p - min) * 60);
  if (sec === 60) return `${min + 1}min00`;
  return `${min}min${sec.toString().padStart(2, '0')}`;
}

export function formatRunContext(ctx: RunContextInput): string {
  const lines: string[] = [];
  if (ctx.athleteName) lines.push(`- Atleta: ${ctx.athleteName}`);
  if (ctx.runType) lines.push(`- Tipo: ${ctx.runType}`);
  if (typeof ctx.distanceM === 'number') lines.push(`- Distância acumulada: ${(ctx.distanceM / 1000).toFixed(2)} km`);
  if (typeof ctx.elapsedS === 'number') lines.push(`- Tempo total: ${Math.floor(ctx.elapsedS / 60)} min ${ctx.elapsedS % 60}s`);
  // Pace formatado `5min30/km` (TF 81, Issue #3) — Gemini lia `5:30` mal
  // ("cinco mil por km" ou "cinco vírgula cinquenta"). `5min30` expande
  // naturalmente pra "cinco minutos e trinta segundos por quilômetro".
  const curPace = formatPaceMmSs(ctx.currentPaceMinKm);
  if (curPace) lines.push(`- Pace atual: ${curPace}/km`);
  const tgtPace = formatPaceMmSs(ctx.targetPaceMinKm);
  if (tgtPace) lines.push(`- Pace alvo: ${tgtPace}/km`);
  if (typeof ctx.bpm === 'number') lines.push(`- BPM atual: ${ctx.bpm}`);
  if (typeof ctx.kmReached === 'number') lines.push(`- KM completado: ${ctx.kmReached}`);
  if (typeof ctx.kmDurationS === 'number') {
    const m = Math.floor(ctx.kmDurationS / 60);
    const s = ctx.kmDurationS % 60;
    lines.push(`- Tempo do km ${ctx.kmReached ?? ''}: ${m}min ${s}s`);
  }
  if (typeof ctx.kmAvgBpm === 'number') lines.push(`- FC média do km: ${ctx.kmAvgBpm} bpm`);
  if (typeof ctx.kmCalories === 'number') lines.push(`- Calorias do km: ${ctx.kmCalories} kcal`);
  if (typeof ctx.temperatureC === 'number') lines.push(`- Temperatura ambiente: ${ctx.temperatureC}°C`);
  if (typeof ctx.humidityPercent === 'number') lines.push(`- Umidade: ${ctx.humidityPercent}%`);
  if (typeof ctx.windKmh === 'number') lines.push(`- Vento: ${ctx.windKmh} km/h`);
  return lines.length > 0 ? lines.join('\n') : '- Sem contexto de corrida.';
}

export function buildEventPrompt(ctx: RunContextInput): string {
  const base = formatRunContext(ctx);
  switch (ctx.event) {
    case 'pre_run':
      return `O corredor quer iniciar uma corrida do tipo ${ctx.runType ?? 'livre'}. Prepare o atleta com foco no objetivo, no plano atual e no cuidado com intensidade.\n\n${base}`;
    case 'km_reached': {
      const curPace = formatPaceMmSs(ctx.currentPaceMinKm) ?? 'XminXX';
      const tgtPace = formatPaceMmSs(ctx.targetPaceMinKm);
      const tgtSuffix = tgtPace ? `, alvo ${tgtPace}/km` : '';
      const bpmHint = typeof ctx.kmAvgBpm === 'number'
        ? ` Quando "FC média do km" estiver no contexto, considere mencionar ela na 2ª frase ("FC ${ctx.kmAvgBpm}, tá dentro" ou "FC ${ctx.kmAvgBpm}, vamos segurar pra não estourar") como observação técnica mais informativa que cadência genérica.`
        : '';
      return `O atleta${ctx.athleteName ? ' ' + ctx.athleteName : ''} acabou de completar o km ${ctx.kmReached}. ESTRUTURA OBRIGATÓRIA, 2 frases:\n\n1) "Fechamos o ${ctx.kmReached}º km${ctx.athleteName ? ', ' + ctx.athleteName : ''}. Seu pace foi ${curPace}/km${tgtSuffix}." — anúncio claro do fechamento + comparação direta com o alvo (se houver alvo).\n2) Uma frase curta com ação ("mantém", "segura", "acelera 5 segundos") ou observação técnica de cadência/respiração baseada no que mais se destaca (FC alta, elevação, distância vs km anterior). Use o tom da persona configurada.${bpmHint}\n\nNão pule a 1ª frase, não inverta a ordem, não enrole. 8-12s de áudio total.\n\n${base}`;
    }
    case 'km_split': {
      const cur = formatPaceMmSs(ctx.currentPaceMinKm) ?? 'XminXX';
      const tgt = formatPaceMmSs(ctx.targetPaceMinKm) ?? 'YminYY';
      const bpmHint = typeof ctx.kmAvgBpm === 'number'
        ? ` Quando "FC média do km" estiver no contexto, MENCIONE ela na 2ª frase se for relevante ("FC média ${ctx.kmAvgBpm}, tá dentro" ou "FC subiu pra ${ctx.kmAvgBpm}, segura no próximo km").`
        : '';
      return `O atleta${ctx.athleteName ? ' ' + ctx.athleteName : ''} acabou de fechar o km ${ctx.kmReached}. Diga claramente, NESTE formato (varie só o nome e o tom final), 1-2 frases: "${ctx.athleteName ?? 'Atleta'}, seu pace no km ${ctx.kmReached} foi ${cur}/km, a meta é manter em ${tgt}/km." Depois UMA frase curta com tom da persona (motivador: gás pra manter; técnico: ajuste objetivo de cadência/postura). NÃO troque a 1ª frase pelo livre — ela é o feedback de split que o user pediu.${bpmHint}\n\n${base}`;
    }
    case 'pace_alert': {
      const curPace = formatPaceMmSs(ctx.currentPaceMinKm) ?? 'XminXX';
      const tgtPace = formatPaceMmSs(ctx.targetPaceMinKm) ?? 'YminYY';
      const bpmHint = typeof ctx.bpm === 'number'
        ? ` Se "BPM atual" estiver elevado (>~85% do máximo), correlacione com o pace alto na 2ª frase ("FC tá em ${ctx.bpm}, segura").`
        : '';
      return `O pace do corredor desviou do alvo da sessão. Corrija explicitamente, NESTE formato, 2 frases:\n\n1) "${ctx.athleteName ?? 'Atleta'}, seu pace agora é ${curPace}/km, o alvo é ${tgtPace}/km." — números claros, sem rodeio.\n2) Ação direta no tom da persona: motivador puxa pra acelerar/segurar com energia; técnico instrui cadência/respiração. Sempre indique a DIREÇÃO do ajuste (acelera/segura) — não deixe ambíguo.${bpmHint}\n\n${base}`;
    }
    case 'high_bpm': {
      // Disparado em [run_bloc._onBpmTick] quando BPM > 92% do maxBpm
      // declarado. ctx.kmAvgBpm carrega o valor atual (não a média do km).
      // Antes esse evento caía no `default` e o LLM recebia só o base — sem
      // instrução. Resultado: cue silencioso ou frase genérica.
      const bpm = typeof ctx.kmAvgBpm === 'number' ? ctx.kmAvgBpm : ctx.bpm;
      const bpmTxt = typeof bpm === 'number' ? `${bpm}` : 'muito alta';
      return `Alerta de FC ELEVADA. O atleta${ctx.athleteName ? ' ' + ctx.athleteName : ''} está com BPM em ${bpmTxt} — acima de 92% do limite seguro declarado. NESTE formato, 2 frases curtas (8-10s áudio):\n\n1) "${ctx.athleteName ?? 'Atleta'}, FC em ${bpmTxt}, atenção." — direto, sem alarmismo.\n2) Ação prescritiva (respira fundo agora, reduz pace por 30s, anda 100m se for crítico) no tom da persona. NÃO instrua a parar a menos que o BPM seja extremo.\n\n${base}`;
    }
    case 'motivation':
      return `Mensagem de motivação no meio da corrida — nenhum alerta específico, apenas mantenha o corredor engajado. 1 frase curta, foco na constância.\n\n${base}`;
    case 'check_in': {
      // Regra canônica: coach DEVE estar presente a cada 500m ou 4min,
      // mesmo quando tudo segue o plano. Diferente de motivation (motivacional
      // genérica), check_in cita os números atuais (km/pace/tempo) pra mostrar
      // ao user que o coach está acompanhando ativamente.
      const curPace = formatPaceMmSs(ctx.currentPaceMinKm) ?? 'XminXX';
      const km = typeof ctx.distanceM === 'number' ? (ctx.distanceM / 1000).toFixed(2) : '?';
      const bpmHint = typeof ctx.bpm === 'number'
        ? ` Se "BPM atual" estiver no contexto, prefira usar ele como sinal vital ("FC em ${ctx.bpm}, ritmo confortável") em vez de adivinhar respiração — é mais informativo.`
        : '';
      return `Check-in de presença do coach. Em 1 frase curta (10-15 palavras), confirma que está acompanhando${ctx.athleteName ? ' ' + ctx.athleteName : ''} citando os números atuais ("você está em ${km}km, pace ${curPace}/km") e UMA observação rápida sobre o que está vendo (constância, ritmo estável, respiração — escolha 1 baseado no contexto). Sem alerta nem instrução — só presença. Não soe robótico: varia abertura ("Acompanhando", "${ctx.athleteName ? ctx.athleteName + ', tudo certo aqui' : 'Tudo certo'}", "Passando pra dizer", etc.).${bpmHint}\n\n${base}`;
    }
    case 'start':
      return `Corredor iniciando treino. Dê uma frase de largada com foco claro.\n\n${base}`;
    case 'finish':
      return `Corrida finalizada. Dê parabéns e um insight rápido do desempenho.\n\n${base}`;
    case 'question':
      return `O corredor fez uma pergunta. Responda brevemente.\n\n${base}`;
    case 'segment_start':
      return `O corredor entrou no próximo segmento do plano (índice ${ctx.currentSegmentIndex ?? '?'}). Anuncie a transição em 1 frase referenciando o briefing do segmento (fase + instrução).\n\n${base}`;
    case 'segment_pace_off': {
      const curPace = formatPaceMmSs(ctx.currentPaceMinKm) ?? 'XminXX';
      const tgtPace = formatPaceMmSs(ctx.targetPaceMinKm) ?? 'YminYY';
      return `O pace do corredor desviou do alvo DESTE segmento do plano (índice ${ctx.currentSegmentIndex ?? '?'}). Corrija explicitamente, NESTE formato, 2 frases:\n\n1) "${ctx.athleteName ?? 'Atleta'}, na fase atual seu pace é ${curPace}/km, o alvo da fase é ${tgtPace}/km." — cite o ALVO DO SEGMENTO (não o pace alvo geral da sessão).\n2) Ação direta com DIREÇÃO clara (acelera X segundos, segura na próxima curva) no tom da persona.\n\n${base}`;
    }
    case 'segment_end':
      return `O corredor terminou o segmento atual (índice ${ctx.currentSegmentIndex ?? '?'}). Em 1 frase, valide a execução do segmento e prepare a transição.\n\n${base}`;
    case 'goal_reached':
      return `O atleta${ctx.athleteName ? ' ' + ctx.athleteName : ''} acabou de atingir a META DE DISTÂNCIA da sessão planejada do dia. Fale exatamente na linha (varie só o nome): "${ctx.athleteName ?? 'Atleta'}, sua sessão termina aqui. Se você optar por continuar, eu sigo contigo, ok? Mas a meta do dia já foi alcançada." Tom calmo, sem pressão pra parar — o atleta decide se finaliza ou continua. NÃO sugira pace nem mude o assunto pra outro tema.\n\n${base}`;
    case 'no_movement':
      return `O atleta${ctx.athleteName ? ' ' + ctx.athleteName : ''} apertou INICIAR mas em 30 segundos não se moveu (distância ~0). Pergunte gentilmente em 1 frase curta se está tudo bem — talvez esteja só esperando, talvez tenha trocado de planos. Sem tom alarmista. Sugira começar a se deslocar quando estiver pronto.\n\n${base}`;
    default:
      return base;
  }
}
