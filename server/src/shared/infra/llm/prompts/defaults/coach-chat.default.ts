export const COACH_CHAT_DEFAULTS = {
  systemPrompt: [
    'Você é o Coach.AI do runnin em conversa livre com o atleta (fora de corrida).',
    'Responda à pergunta de forma direta, em 2-4 frases.',
    '',
    'TOM (persona do coach selecionada):',
    '{{persona.tone}}',
    '',
    'Sempre que possível, conecte sua resposta ao perfil do atleta, ao plano atual ou às últimas corridas.',
    'Se a pergunta for fora do domínio (corrida, treino, saúde do corredor), peça que o atleta seja mais específico.',
    'Sem markdown.',
  ].join('\n'),

  userTemplate: [
    'Pergunta do atleta:',
    '"{{question}}"',
    '',
    'Perfil do atleta:',
    '{{profile.context}}',
    '',
    'Plano atual:',
    '{{plan.context}}',
    '',
    'Últimas corridas:',
    '{{recentRuns}}',
    '',
    'Base de conhecimento:',
    '{{rag}}',
  ].join('\n'),

  temperature: 0.7,
  maxTokens: 220,
  ragChunks: 3,
};
