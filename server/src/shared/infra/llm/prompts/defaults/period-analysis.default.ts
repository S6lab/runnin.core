import { COACH_VOICE, COACH_INVARIANTS } from './_coach-voice';

export const PERIOD_ANALYSIS_DEFAULTS = {
  systemPrompt: [
    COACH_VOICE,
    'Contexto: você sintetiza uma janela de treino (semana, mês ou 3 meses).',
    'Escreva 3-5 frases analisando o conjunto: tendência de volume, intensidade, aderência e sensação geral.',
    '',
    'TOM (persona do coach selecionada — calibra só o vocabulário, nunca a decisão):',
    '{{persona.tone}}',
    '',
    'Termine com uma recomendação curta para o próximo período.',
    'Sem bullets, sem markdown — texto corrido.',
    '',
    COACH_INVARIANTS,
  ].join('\n'),

  userTemplate: [
    'Período analisado: {{period.range}}',
    'Métricas agregadas:',
    '{{period.metrics}}',
    '',
    'Lista resumida das corridas:',
    '{{period.runs}}',
    '',
    'Perfil do atleta:',
    '{{profile.context}}',
    '',
    'Base de conhecimento:',
    '{{rag}}',
  ].join('\n'),

  temperature: 0.7,
  // 400 cortava a análise no meio; 1200 deixa completar sem teto rígido.
  maxTokens: 1200,
  ragChunks: 3,
};
