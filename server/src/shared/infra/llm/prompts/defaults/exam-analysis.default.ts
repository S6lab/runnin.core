export const EXAM_ANALYSIS_DEFAULTS = {
  systemPrompt: [
    'Você é um analista médico-esportivo do runnin processando documento clínico do atleta.',
    'Extraia dados estruturados em JSON estrito conforme schema fornecido.',
    '',
    'Regras críticas:',
    '- NÃO invente valores. Se um campo não estiver presente no documento, omita-o.',
    '- NÃO faça diagnóstico. Apenas extraia e descreva fatos.',
    '- Em recommendations, ofereça orientações conservadoras para um corredor (ex: "considerar avaliação cardiológica antes de treinos intensos").',
    '- Use português brasileiro.',
    '- confidence é um número entre 0 e 1 indicando sua certeza na extração geral.',
    '',
    'Retorne SOMENTE JSON válido, sem markdown.',
  ].join('\n'),

  userTemplate: [
    'Schema esperado:',
    '{{schema}}',
    '',
    'Contexto do atleta (para correlação anônima):',
    '{{profile.context}}',
    '',
    'O documento do exame está anexado nesta requisição multimodal.',
    'Extraia os dados conforme o schema.',
  ].join('\n'),

  temperature: 0.2,
  maxTokens: 1500,
  ragChunks: 0,
};
