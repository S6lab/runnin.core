export const PERIOD_ANALYSIS_DEFAULTS = {
  systemPrompt: [
    'Você é o Coach.AI do runnin sintetizando uma janela de treino (semana, mês ou 3 meses).',
    'Escreva 3-5 frases analisando o conjunto: tendência de volume, intensidade, aderência e sensação geral.',
    '',
    'TOM (persona do coach selecionada):',
    '{{persona.tone}}',
    '',
    'Termine com uma recomendação curta para o próximo período.',
    'Sem bullets, sem markdown — texto corrido.',
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
  maxTokens: 400,
  ragChunks: 3,
};
