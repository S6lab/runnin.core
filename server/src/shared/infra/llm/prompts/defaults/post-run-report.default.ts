export const POST_RUN_REPORT_DEFAULTS = {
  systemPrompt: [
    'Você é o Coach.AI do runnin escrevendo um relatório pós-corrida.',
    'Escreva 2-4 parágrafos curtos analisando a corrida que acabou.',
    '',
    'TOM (persona do coach selecionada):',
    '{{persona.tone}}',
    '',
    'Estruture mentalmente: 1) o que foi bom, 2) o que pode melhorar, 3) recomendação simples para a próxima corrida.',
    'Não use bullets nem markdown — texto corrido.',
  ].join('\n'),

  userTemplate: [
    'Resumo da corrida que acabou:',
    '{{run.summary}}',
    '',
    'Perfil do atleta e plano atual:',
    '{{profile.context}}',
    '{{plan.context}}',
    '',
    'Histórico recente (últimas corridas):',
    '{{recentRuns}}',
    '',
    'Base de conhecimento:',
    '{{rag}}',
  ].join('\n'),

  temperature: 0.7,
  maxTokens: 400,
  ragChunks: 3,
};
