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
}

export function formatRunContext(ctx: RunContextInput): string {
  const lines: string[] = [];
  if (ctx.athleteName) lines.push(`- Atleta: ${ctx.athleteName}`);
  if (ctx.runType) lines.push(`- Tipo: ${ctx.runType}`);
  if (typeof ctx.distanceM === 'number') lines.push(`- Distância acumulada: ${(ctx.distanceM / 1000).toFixed(2)} km`);
  if (typeof ctx.elapsedS === 'number') lines.push(`- Tempo total: ${Math.floor(ctx.elapsedS / 60)} min ${ctx.elapsedS % 60}s`);
  if (typeof ctx.currentPaceMinKm === 'number') lines.push(`- Pace atual: ${ctx.currentPaceMinKm.toFixed(2)}/km`);
  if (typeof ctx.targetPaceMinKm === 'number') lines.push(`- Pace alvo: ${ctx.targetPaceMinKm.toFixed(2)}/km`);
  if (typeof ctx.bpm === 'number') lines.push(`- BPM atual: ${ctx.bpm}`);
  if (typeof ctx.kmReached === 'number') lines.push(`- KM completado: ${ctx.kmReached}`);
  if (typeof ctx.kmDurationS === 'number') {
    const m = Math.floor(ctx.kmDurationS / 60);
    const s = ctx.kmDurationS % 60;
    lines.push(`- Tempo do km ${ctx.kmReached ?? ''}: ${m}min ${s}s`);
  }
  if (typeof ctx.kmAvgBpm === 'number') lines.push(`- FC média do km: ${ctx.kmAvgBpm} bpm`);
  if (typeof ctx.kmCalories === 'number') lines.push(`- Calorias do km: ${ctx.kmCalories} kcal`);
  return lines.length > 0 ? lines.join('\n') : '- Sem contexto de corrida.';
}

export function buildEventPrompt(ctx: RunContextInput): string {
  const base = formatRunContext(ctx);
  switch (ctx.event) {
    case 'pre_run':
      return `O corredor quer iniciar uma corrida do tipo ${ctx.runType ?? 'livre'}. Prepare o atleta com foco no objetivo, no plano atual e no cuidado com intensidade.\n\n${base}`;
    case 'km_reached':
      return `O atleta${ctx.athleteName ? ' ' + ctx.athleteName : ''} acabou de completar o km ${ctx.kmReached}. Dê um feedback CURTO (1-2 frases, 8-12 segundos de áudio) que **mencione naturalmente** os 5 dados do km — pace, distância do km (1 km), tempo do km, calorias gastas e FC média — e termine com uma ação simples (manter/acelerar/recuperar) ou observação técnica. Use o nome do atleta na saudação. Varie a ordem dos dados a cada km pra não soar robótico — destaque o mais relevante do momento (ex: se FC alta, abre por aí; se pace ideal, abre por aí).\n\nExemplo de tom (NÃO copie literal, varie): "Muito bem, João. Pace em 8, 1 km em 8 minutos, 80 cal, FC 150 bpm. Mantém esse ritmo, respiração tranquila."\n\n${base}`;
    case 'km_split':
      return `O corredor fechou o km ${ctx.kmReached}. Compare o pace deste km com o anterior e diga se acelerou, manteve ou caiu, em 1-2 frases.\n\n${base}`;
    case 'pace_alert':
      return `O pace do corredor desviou do plano. Corrija com firmeza e cuidado.\n\n${base}`;
    case 'motivation':
      return `Mensagem de motivação no meio da corrida — nenhum alerta específico, apenas mantenha o corredor engajado. 1 frase curta, foco na constância.\n\n${base}`;
    case 'start':
      return `Corredor iniciando treino. Dê uma frase de largada com foco claro.\n\n${base}`;
    case 'finish':
      return `Corrida finalizada. Dê parabéns e um insight rápido do desempenho.\n\n${base}`;
    case 'question':
      return `O corredor fez uma pergunta. Responda brevemente.\n\n${base}`;
    case 'segment_start':
      return `O corredor entrou no próximo segmento do plano (índice ${ctx.currentSegmentIndex ?? '?'}). Anuncie a transição em 1 frase referenciando o briefing do segmento (fase + instrução).\n\n${base}`;
    case 'segment_pace_off':
      return `O pace do corredor desviou do alvo DESTE segmento do plano. Corrija com firmeza e cuidado, citando o pace alvo do segmento atual (não o pace alvo geral da sessão).\n\n${base}`;
    case 'segment_end':
      return `O corredor terminou o segmento atual (índice ${ctx.currentSegmentIndex ?? '?'}). Em 1 frase, valide a execução do segmento e prepare a transição.\n\n${base}`;
    case 'no_movement':
      return `O atleta${ctx.athleteName ? ' ' + ctx.athleteName : ''} apertou INICIAR mas em 30 segundos não se moveu (distância ~0). Pergunte gentilmente em 1 frase curta se está tudo bem — talvez esteja só esperando, talvez tenha trocado de planos. Sem tom alarmista. Sugira começar a se deslocar quando estiver pronto.\n\n${base}`;
    default:
      return base;
  }
}
