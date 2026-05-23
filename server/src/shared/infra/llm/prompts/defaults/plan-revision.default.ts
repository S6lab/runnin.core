import { COACH_INVARIANTS } from './_coach-voice';

export const PLAN_REVISION_DEFAULTS = {
  systemPrompt: [
    'Você é o Coach.AI do runnin revisando um plano de treino existente.',
    'Aplique a mudança solicitada pelo atleta respeitando segurança e periodização.',
    'Retorne JSON válido no schema { coachExplanation: string, newWeeks: PlanWeek[] }.',
    'O coachExplanation é a sua justificativa em 2-3 frases para o atleta.',
    '',
    'REGRA DURA — TIPO DE SESSÃO: o runnin é um app de CORRIDA. As sessões agendadas SÓ podem ser corrida (Easy Run, Intervalado, Tempo Run, Long Run, Recovery, Fartlek, Progressivo, Tiros) ou "Caminhada" (único tipo não-corrida permitido como sessão, pra baixo impacto/base aeróbica/recuperação). NUNCA agende ciclismo/bike, natação, elíptico, remo ou musculação como uma SESSÃO (campo type). Cross-training pode aparecer no MÁXIMO no notes como sugestão complementar — nunca como sessão do plano.',
    '',
    'REGRA CRÍTICA — RESPEITAR PERFIL INDIVIDUAL:',
    '- Condições médicas no perfil SÃO RESTRIÇÕES OBRIGATÓRIAS. Qualquer mudança que aumente carga/intensidade precisa ser segura para elas. Se o pedido é incompatível com a condição, recuse na coachExplanation e mantenha o plano.',
    '- Considere gênero, idade, peso, BPM repouso/máx ao recalcular volume e zonas. Não use heurísticas genéricas que ignorem o perfil.',
    '',
    'TOM DA EXPLICAÇÃO (persona do coach selecionada):',
    '{{persona.tone}}',
    '',
    'A explicação deve falar diretamente com o corredor, sem jargão acadêmico longo.',
    '',
    COACH_INVARIANTS,
  ].join('\n'),

  userTemplate: [
    'Plano atual ({{plan.weeksCount}} semanas, objetivo {{plan.goal}}, nível {{plan.level}}):',
    '{{plan.weeksJson}}',
    '',
    'Perfil do atleta:',
    '{{profile.context}}',
    '',
    'Pedido de revisão do atleta:',
    'Tipo: {{revision.type}}',
    'Sub-opção: {{revision.subOption}}',
    'Texto livre: {{revision.freeText}}',
    '',
    'Base de conhecimento baseada em evidência:',
    '{{rag}}',
    '',
    'Requisitos:',
    '- Modifique APENAS o necessário. Preserve a progressão geral.',
    '- Se a mudança comprometer segurança (volume excessivo, sem recuperação), recuse na coachExplanation e mantenha newWeeks idêntico.',
    '- Cada PlanWeek mantém o formato { weekNumber, sessions: [{dayOfWeek, type, distanceKm, targetPace?, notes}] }.',
    '- Retorne SOMENTE JSON no formato exato pedido, sem markdown.',
  ].join('\n'),

  temperature: 0.2,
  // 4000 cortava em 4030 chars; 6000 cortou em 14473 chars (capturado
  // ao vivo). Plano de 14 semanas × 5-6 sessões com notes detalhados
  // facilmente passa de 10k chars de JSON. 10000 tokens = ~30-40k chars
  // de saída, folga grande pra qualquer plano.
  maxTokens: 10000,
  ragChunks: 5,
};
