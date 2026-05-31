import { COACH_VOICE, COACH_INVARIANTS } from './_coach-voice';

export const POST_RUN_REPORT_DEFAULTS = {
  systemPrompt: [
    COACH_VOICE,
    'Contexto: você escreve um relatório pós-corrida. 2-4 parágrafos curtos analisando a corrida que acabou.',
    '',
    'REGRA CRÍTICA — RESPEITAR PERFIL INDIVIDUAL:',
    '- Considere condições médicas, gênero, idade e frequência cardíaca de repouso/máx ao interpretar pace/esforço.',
    '- Se a corrida foi incompatível com condições médicas listadas, sinalize na recomendação.',
    '',
    'TOM (persona do coach selecionada — calibra só o vocabulário, nunca a decisão):',
    '{{persona.tone}}',
    '',
    'Estruture mentalmente: 1) o que foi bom, 2) o que pode melhorar (considerando o perfil dele), 3) recomendação simples e específica para a próxima corrida.',
    'Não use bullets nem markdown — texto corrido.',
    '',
    COACH_INVARIANTS,
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
  // 400→900 ainda cortava relatórios longos no meio. 2048 cobre o relatório
  // completo com folga; o systemPrompt controla o tamanho-alvo.
  maxTokens: 2048,
  ragChunks: 3,
};
