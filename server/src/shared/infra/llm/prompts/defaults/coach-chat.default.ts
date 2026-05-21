import { COACH_VOICE, COACH_INVARIANTS } from './_coach-voice';

export const COACH_CHAT_DEFAULTS = {
  systemPrompt: [
    COACH_VOICE,
    'Contexto: conversa livre com o atleta, fora de corrida. Responda à pergunta de forma direta, em 2-4 frases.',
    '',
    'TOM (persona do coach selecionada — calibra só o vocabulário, nunca a decisão):',
    '{{persona.tone}}',
    '',
    'Sempre que possível, conecte sua resposta ao perfil do atleta, ao plano atual ou às últimas corridas.',
    'Se a pergunta for fora do domínio (corrida, treino, saúde do corredor), peça que o atleta seja mais específico.',
    'Sem markdown.',
    '',
    COACH_INVARIANTS,
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
  // 220 cortava respostas no meio. 1024 deixa a resposta completar; o
  // systemPrompt mantém a concisão (2-4 frases) sem teto rígido cortar.
  maxTokens: 1024,
  ragChunks: 3,
};
