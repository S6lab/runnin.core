import { getAsyncLLM } from '@shared/infra/llm/llm.factory';
import { PlanWeek, effectivePlanWeeks } from '../domain/plan.entity';
import {
  CheckpointAnalysisInput,
  CheckpointAnalysisOutput,
  CheckpointAnalysisStrategy,
} from './checkpoint-analysis.strategy';
import { logger } from '@shared/logger/logger';

/**
 * Estratégia default: 1 chamada LLM que combina análise (descritiva)
 * e ajuste do plano (estrutural). Devolve JSON estrito.
 *
 * Fallback se LLM falha ou JSON não parseia:
 *   - autoAnalysis = descrição mecânica das métricas
 *   - newWeeks = [] (sem ajuste estrutural)
 *   - coachExplanation = texto curto reconhecendo a falha
 *
 * Mantém a aplicação progressível mesmo sem LLM disponível.
 */
export class LlmCheckpointAnalysisStrategy
  implements CheckpointAnalysisStrategy
{
  private llm = getAsyncLLM();

  async analyze(input: CheckpointAnalysisInput): Promise<CheckpointAnalysisOutput> {
    const { plan, weekNumber, userInputs, weekRuns, weekMetrics, biometricSummary } = input;

    const effective = effectivePlanWeeks(plan);
    // Fix 7: janela revisável = current+1 e current+2 (igual ao manual
    // revision builder). Cron analisa wk N (just-ended) e ajusta apenas
    // wk N+1 (current vigente) e wk N+2 (próxima). Demais permanecem
    // skeleton com volume bruto até o próximo checkpoint.
    const followingWeeks = effective.filter(
      (w) => w.weekNumber === weekNumber + 1 || w.weekNumber === weekNumber + 2,
    );
    if (followingWeeks.length === 0) {
      return {
        autoAnalysis: 'Última semana do mesociclo — sem semanas seguintes pra ajustar.',
        newWeeks: [],
        coachExplanation:
          'Esta era a última semana do plano. Nenhum ajuste foi aplicado. '
          + 'Considere gerar um novo plano com base na evolução desta jornada.',
      };
    }

    const inputsDigest = userInputs.length
      ? userInputs
          .map((i) => `- ${i.type}${i.note ? `: ${i.note}` : ''}`)
          .join('\n')
      : '(nenhum input do usuário — só análise objetiva)';

    const runsDigest = weekRuns.length
      ? weekRuns
          .map((r) => {
            // Marca explicitamente PLANO vs LIVRE. Free run = compensação
            // espontânea — o coach precisa creditar isso na análise (não
            // contar só "sessões faltadas").
            const tag = r.planSessionId ? '[PLANO]' : '[LIVRE]';
            const head =
              `- ${tag} ${r.date}: ${r.distanceKm.toFixed(1)}km em ${Math.round(r.durationS / 60)}min` +
              `${r.avgPace ? `, pace ${r.avgPace}` : ''}` +
              `${r.avgBpm ? `, BPM méd ${r.avgBpm}` : ''}`;
            if (!r.userFeedback || r.userFeedback.length === 0) return head;
            const fb = r.userFeedback
              .map((i) => `${i.type}${i.note ? ` (${i.note})` : ''}`)
              .join(', ');
            return `${head}\n  feedback do user: ${fb}`;
          })
          .join('\n')
      : '(nenhuma corrida concluída na semana)';

    // Bloco BIOMETRICS pro prompt — dá ao LLM contexto fisiológico real
    // (HealthKit/Health Connect) pra tomar decisões mais informadas além
    // dos dados das corridas. Null quando o user não conectou wearable.
    const biometricsDigest = biometricSummary && biometricSummary.sampleCount > 0
      ? [
          biometricSummary.avgSleepHours != null
            ? `- Sono médio 7d: ${biometricSummary.avgSleepHours.toFixed(1)}h${biometricSummary.avgSleepQualityScore != null ? ` (qualidade ${biometricSummary.avgSleepQualityScore}/100)` : ''}${biometricSummary.lastNightSleepHours != null ? `, última noite ${biometricSummary.lastNightSleepHours.toFixed(1)}h` : ''}`
            : null,
          biometricSummary.avgRestingBpm != null
            ? `- BPM em repouso médio: ${biometricSummary.avgRestingBpm}`
            : null,
          biometricSummary.avgHrv != null
            ? `- HRV médio: ${biometricSummary.avgHrv}ms (proxy de recuperação autonômica — quanto maior, melhor recovery)`
            : null,
          biometricSummary.maxBpm != null
            ? `- BPM máximo observado: ${biometricSummary.maxBpm}`
            : null,
          biometricSummary.totalSteps != null
            ? `- Passos totais 7d: ${biometricSummary.totalSteps.toLocaleString('pt-BR')}`
            : null,
        ].filter(Boolean).join('\n')
      : '(sem dados biométricos sincronizados — decida com base nas corridas e chips)';

    const followingDigest = followingWeeks
      .map(
        (w) =>
          `Semana ${w.weekNumber}: ${w.sessions.length} sessões / ${w.sessions
            .reduce((s, x) => s + x.distanceKm, 0)
            .toFixed(1)}km (${w.detailLevel ?? 'full'})`,
      )
      .join('\n');

    // As 2 PRÓXIMAS semanas são DETALHADAS neste checkpoint (esqueleto→full).
    // As demais seguem esqueleto, com volume/pace ajustados.
    const detailWeeks = followingWeeks.slice(0, 2);
    const detailWeekNums = detailWeeks.map((w) => w.weekNumber).join(' e ');
    const skeletonWeekNums = followingWeeks
      .slice(2)
      .map((w) => w.weekNumber)
      .join(', ');

    // ─── PACE OVERSHOOT anchor: regra dura quando atleta correu MUITO
    //     mais rápido que o pace alvo da semana ──────────────────────────
    // Vetor de risco distinto do volume: correr 30s/km mais rápido que o
    // planejado é fadiga musculotendínea + cardiovascular extra mesmo se
    // o KM total bate. Compara avg pace REAL da semana vs avg pace ALVO
    // das sessões planejadas (apenas sessões que tinham targetPace).
    const currentWk = effective.find((w) => w.weekNumber === weekNumber);
    const plannedPaceSecs = (currentWk?.sessions ?? [])
      .map((s) => paceStrToSeconds(s.targetPace))
      .filter((v): v is number => v != null);
    const plannedAvgPaceSec = plannedPaceSecs.length
      ? Math.round(plannedPaceSecs.reduce((a, b) => a + b, 0) / plannedPaceSecs.length)
      : null;
    const actualAvgPaceSec = weekMetrics.avgPaceMinPerKm
      ? Math.round(weekMetrics.avgPaceMinPerKm * 60)
      : null;
    const paceDeltaSec = actualAvgPaceSec != null && plannedAvgPaceSec != null
      ? plannedAvgPaceSec - actualAvgPaceSec   // positivo = correu mais rápido
      : 0;
    let paceOvershootBlock = '';
    if (paceDeltaSec >= 15) {
      const cut = paceDeltaSec >= 30 ? 'pelo menos 15s/km mais LENTO'
        : 'pelo menos 8s/km mais LENTO';
      paceOvershootBlock = [
        '',
        'PACE OVERSHOOT DETECTADO — REGRA DURA:',
        `- Atleta correu em média ${paceDeltaSec}s/km MAIS RÁPIDO que o pace planejado da semana (real ${secondsToPaceStr(actualAvgPaceSec!)}/km vs planejado ${secondsToPaceStr(plannedAvgPaceSec!)}/km).`,
        `- Correr acima do alvo é fadiga musculotendínea + cardiovascular extra, MESMO QUE o volume total bata o plano. Risco cumulativo: rigidez, tendinopatia, queda de adaptação.`,
        `- REGRA DURA: nas próximas 2 semanas (${followingWeeks[0]?.weekNumber} e ${followingWeeks[1]?.weekNumber}), AJUSTE o targetPace de TODAS as sessões Easy / Long / Recovery pra ${cut} que o pace real desta semana. Sessões de qualidade (tempo/tiros/intervalado) ficam no alvo original.`,
        `- No coachExplanation, deixe explícito que a redução de intensidade é pra ANCORAR a base aeróbica (zona 2) que foi atropelada — o easy precisa ser easy de verdade pra trabalho de tendão/coração e recuperação.`,
        '',
      ].join('\n');
    } else if (paceDeltaSec <= -20 && actualAvgPaceSec != null && plannedAvgPaceSec != null) {
      // UNDERSHOOT: atleta correu BEM mais lento que o alvo. Pode ser:
      // condicionamento abaixo do esperado, fadiga, calor, mochila pesada.
      // Re-calibra o targetPace pra base mais realista — evita user "atrás
      // do plano" semana após semana e desistir.
      const slow = Math.abs(paceDeltaSec);
      paceOvershootBlock = [
        '',
        'PACE UNDERSHOOT DETECTADO — RE-CALIBRAR ALVO:',
        `- Atleta correu em média ${slow}s/km MAIS LENTO que o alvo (real ${secondsToPaceStr(actualAvgPaceSec)}/km vs alvo ${secondsToPaceStr(plannedAvgPaceSec)}/km).`,
        `- O alvo da semana estava acima do que o atleta de fato sustenta hoje. Continuar mirando o mesmo pace = frustração crônica e potencial overreaching pra "alcançar".`,
        `- REGRA DURA: nas próximas 2 semanas, RECALIBRE o targetPace de cada sessão (Easy / Long / Tempo / Tiros) pra ${Math.min(slow, 20)}s/km mais lento que o que estava antes. Mantém a hierarquia entre tipos de sessão (easy é o mais lento; tiros, o mais rápido).`,
        `- No coachExplanation, valide a leitura sem julgamento: "seu pace real esta semana ficou em X/km. Vamos ajustar o alvo pra você ter uma semana de WIN antes de subir de novo".`,
        '',
      ].join('\n');
    }

    // ─── VOLUME DELTA anchor: ajuste obrigatório quando volume diverge
    //     muito do planejado (sobre OU sub) ─────────────────────────────
    // Antes o LLM caía na regra "rodou além e tolerou bem → suba 5-10%"
    // mesmo com 174% acima. Agora forçamos ajuste proporcional em AMBAS
    // direções (over E under), com números absolutos no prompt.
    const overloadDeltaPct = weekMetrics.plannedDistanceKm > 0
      ? ((weekMetrics.actualDistanceKm - weekMetrics.plannedDistanceKm) / weekMetrics.plannedDistanceKm) * 100
      : 0;
    let overloadBlock = '';
    if (overloadDeltaPct >= 50) {
      // Contexto pra decidir entre DELOAD, SEGURAR INTENSIDADE ou CALIBRAR
      // PRA CIMA. Antes cortávamos volume sempre que o atleta correu muito
      // acima do plano — "castigo" pra quem está cumprindo. Agora olhamos:
      //  1. Sintomas (chips do user)
      //  2. BPM relativo ao max estimado (zona aeróbica vs não)
      //  3. Magnitude do overload (200%+ é deload obrigatório mesmo sem
      //     sinal, porque o risco mecânico é alto demais)
      const NEGATIVE_SYMPTOMS = new Set([
        'pain', 'sleep_bad', 'low_energy', 'fatigue', 'sore',
        'load_down', 'schedule_conflict',
      ]);
      const hasNegativeSymptom = userInputs.some(
        (i) => NEGATIVE_SYMPTOMS.has(i.type),
      );
      // BPM elevado = média da semana > 85% do max estimado. Prioriza
      // maxBpm REAL do HealthKit (biometricSummary); fallback profile
      // declarado; último fallback 190 (220-30 conservador).
      const maxBpm = biometricSummary?.maxBpm ?? 190;
      const avgBpm = weekMetrics.avgBpm ?? 0;
      const bpmPct = maxBpm > 0 ? (avgBpm / maxBpm) * 100 : 0;
      const bpmElevated = bpmPct >= 85;

      // Sono ruim: média < 6.5h OU score qualidade < 50. Risco fisiológico
      // mesmo sem o user reportar chip de sintoma — recovery comprometido
      // multiplica risco de lesão em overload.
      const avgSleep = biometricSummary?.avgSleepHours ?? null;
      const sleepScore = biometricSummary?.avgSleepQualityScore ?? null;
      const sleepPoor = (avgSleep != null && avgSleep < 6.5)
        || (sleepScore != null && sleepScore < 50);

      // HRV baixo: indicador de stress autonômico / recovery incompleto.
      // <30ms (RMSSD/SDNN) tipicamente sinaliza fadiga. Threshold conservador
      // pra detectar overtraining incipiente.
      const hrv = biometricSummary?.avgHrv ?? null;
      const hrvLow = hrv != null && hrv < 30;

      // Resting BPM elevado: >5bpm acima do baseline esperado (proxy
      // simples — não temos histórico de baseline aqui ainda).
      const restingBpm = biometricSummary?.avgRestingBpm ?? null;
      const restingHigh = restingBpm != null && restingBpm > 75;

      // Fix 2: convergência de sinais. Antes 1 sinal isolado (sono ruim
      // de uma noite OU HRV baixo num dia OU resting alto pontual) jogava
      // direto no CAMINHO A. Agora exige PELO MENOS 2 dos 3 sinais
      // fisiológicos OU 1 chip negativo do user (chip = relato consciente,
      // mais confiável que biometria de 7d).
      const physioSignalCount = [sleepPoor, hrvLow, restingHigh].filter(Boolean).length;
      const hasPhysiologicalRisk = physioSignalCount >= 2;

      // Fix 2: performance positiva como amortecedor. Se o atleta cumpriu
      // pelo menos 90% do volume planejado E o pace real ficou dentro de
      // +10s/km do alvo, **não cai em CAMINHO A com 1 sinal fisiológico
      // isolado**. Só com sintoma reportado (chip) OU 2 sinais convergentes.
      const performancePositive = weekMetrics.plannedDistanceKm > 0
        && weekMetrics.actualDistanceKm >= weekMetrics.plannedDistanceKm * 0.9
        && (plannedAvgPaceSec == null || actualAvgPaceSec == null
            || actualAvgPaceSec <= plannedAvgPaceSec + 10);

      // Magnitude extrema: 200%+ é deload obrigatório (3× o planejado é
      // ferro fundido, sem espaço pra "calibrar pra cima").
      const isExtremeOverload = overloadDeltaPct >= 200;

      // Caminho A só dispara se: chip negativo (sempre conta), OU 2 sinais
      // fisiológicos convergentes, OU overload extremo. Performance positiva
      // amortece sinal isolado.
      const triggerCaminhoA = hasNegativeSymptom
        || (hasPhysiologicalRisk && !performancePositive)
        || isExtremeOverload;

      if (triggerCaminhoA) {
        // CAMINHO A — DELOAD moderado. Dispara quando há sinal real:
        // chip sintoma OU sono ruim/HRV baixo/resting alto OU magnitude
        // extrema. Sem ferramentas pra ajustar muito mais que isso de forma
        // segura — proteção mecânica e fisiológica.
        const wk1Cut = Math.max(15, Math.min(30, Math.round(overloadDeltaPct / 6)));
        const wk2Cut = Math.max(8, Math.min(15, Math.round(overloadDeltaPct / 12)));
        const riskBits: string[] = [];
        if (isExtremeOverload) riskBits.push(`magnitude extrema (${overloadDeltaPct.toFixed(0)}% acima)`);
        if (hasNegativeSymptom) {
          const symptoms = userInputs.filter((i) => NEGATIVE_SYMPTOMS.has(i.type)).map((i) => i.type).join(', ');
          riskBits.push(`sintomas (${symptoms})`);
        }
        if (sleepPoor) riskBits.push(`sono comprometido (média ${avgSleep?.toFixed(1)}h${sleepScore != null ? `, qualidade ${sleepScore}/100` : ''})`);
        if (hrvLow) riskBits.push(`HRV baixo (${hrv}ms)`);
        if (restingHigh) riskBits.push(`resting BPM alto (${restingBpm})`);
        const reason = riskBits.join(' + ');
        overloadBlock = [
          '',
          'OVERLOAD COM SINAL DE RISCO — DELOAD MODERADO:',
          `- Atleta correu ${overloadDeltaPct.toFixed(0)}% ACIMA do volume planejado E há sinal de risco: ${reason}.`,
          `- REGRA: próxima semana (${followingWeeks[0]?.weekNumber}) reduza o volume em ${wk1Cut}%. Inclua 1 sessão de Recovery extra.`,
          `- REGRA: semana seguinte (${followingWeeks[1]?.weekNumber}) reduza em ${wk2Cut}%.`,
          `- No coachExplanation: reconheça a capacidade do atleta, valide o esforço, e explique o deload como "absorver pra sustentar" (não castigo).`,
          '',
        ].join('\n');
      } else if (bpmElevated) {
        // CAMINHO B — SEGURAR INTENSIDADE, MANTER VOLUME. Atleta correu
        // muito acima E BPM ficou elevado: capacidade aeróbica não acompanhou
        // o esforço mecânico. Não corta volume; ancora pace nas próximas
        // 2 semanas pra forçar zona aeróbica (zona 2).
        overloadBlock = [
          '',
          'OVERLOAD COM BPM ELEVADO — SEGURAR INTENSIDADE, MANTER VOLUME:',
          `- Atleta correu ${overloadDeltaPct.toFixed(0)}% ACIMA do volume planejado; BPM médio ${avgBpm} (~${bpmPct.toFixed(0)}% do max ${maxBpm}) — esforço cardiovascular alto.`,
          `- REGRA: MANTENHA o volume original das próximas semanas (${followingWeeks[0]?.weekNumber} e ${followingWeeks[1]?.weekNumber}) — não corte.`,
          `- REGRA: AJUSTE targetPace das sessões Easy / Long / Recovery pra +10-20s/km mais lento que o pace real desta semana. Foco em zona 2 (BPM conversável).`,
          `- Sessões de qualidade (tempo/tiros/intervalado) ficam no alvo original — intensidade controlada só onde ela faz sentido.`,
          `- No coachExplanation: explique que o volume tá ok mas a intensidade subiu junto; vamos ancorar a base aeróbica antes de subir de novo.`,
          '',
        ].join('\n');
      } else {
        // CAMINHO C — CALIBRAR PRA CIMA. Atleta correu muito acima, SEM
        // sintomas, BPM ok. O plano estava subestimando a capacidade real.
        // Sobe progressão em vez de cortar (mas com teto — máx +15% pra
        // não acelerar demais e perder adaptação).
        const upPct = Math.max(5, Math.min(15, Math.round(overloadDeltaPct / 12)));
        overloadBlock = [
          '',
          'OVERLOAD SEM SINAL DE RISCO — CALIBRAR PROGRESSÃO PRA CIMA:',
          `- Atleta correu ${overloadDeltaPct.toFixed(0)}% ACIMA do volume planejado, SEM sintomas negativos e com BPM dentro da zona esperada.`,
          `- Leitura: o plano subestimou a capacidade do atleta. Não corte volume — recalibra pra cima.`,
          `- REGRA: próxima semana (${followingWeeks[0]?.weekNumber}) sobe volume em ${upPct}% vs o plano atual. Mantém estrutura (sessões e tipos).`,
          `- REGRA: semana seguinte (${followingWeeks[1]?.weekNumber}) sobe outros ${Math.max(3, upPct - 5)}% — progressão linear, sem saltos.`,
          `- IMPORTANTE: respeite o targetPace original das sessões Easy/Long (não suba intensidade junto com volume — risco multiplicativo).`,
          `- No coachExplanation: celebre a leitura ("você mostrou que tem base maior que o estimado"), explique a calibração e reforce a importância de respeitar os paces alvos pra construção segura.`,
          '',
        ].join('\n');
      }
    } else if (overloadDeltaPct <= -40 && weekMetrics.plannedDistanceKm > 0) {
      // UNDERLOAD: atleta ficou abaixo do plano (aderência ruim OU sessões
      // mais curtas). Não force progressão padrão — re-modula pra retomada
      // realista. Pode ser falta de tempo, fadiga acumulada, motivação.
      const downPct = Math.abs(overloadDeltaPct).toFixed(0);
      overloadBlock = [
        '',
        'UNDERLOAD DETECTADO — RE-MODULAR PROGRESSÃO:',
        `- Atleta correu ${downPct}% ABAIXO do volume planejado (${weekMetrics.actualDistanceKm.toFixed(1)}km feito vs ${weekMetrics.plannedDistanceKm.toFixed(1)}km planejado).`,
        `- REGRA DURA: NÃO mantenha o volume original das próximas semanas — re-modula pra base mais próxima do que o atleta de fato sustentou. Próxima semana (${followingWeeks[0]?.weekNumber}) com volume ~ ${(weekMetrics.actualDistanceKm * 1.1).toFixed(1)}km (10% acima do real desta semana, não do planejado).`,
        `- A semana seguinte (${followingWeeks[1]?.weekNumber}) progride mais 5-10% a partir dali.`,
        `- Investigue no coachExplanation: foi falta de tempo, fadiga acumulada, ou motivação? Adapte o tom e proponha redução de N sessões/semana se necessário (mantém o km total redistribuído).`,
        '',
      ].join('\n');
    }

    // ─── RACE anchor block (só em planos RACE com raceDate) ──────────────
    // Mesmo recebendo a instrução, o LLM pode tentar mexer na race week ou
    // subir carga próximo dela. enforceRevisionInvariants (no apply) repara
    // se ele violar — esse bloco é o primeiro line of defense.
    const isRace = !!plan.raceDate && !!plan.raceDayOfWeek;
    const raceWeekNumber = plan.weeksCount;
    const taperWeekNumber = raceWeekNumber - 1;
    const deltaPct = weekMetrics.plannedDistanceKm > 0
      ? ((weekMetrics.actualDistanceKm - weekMetrics.plannedDistanceKm) / weekMetrics.plannedDistanceKm) * 100
      : 0;
    let raceAnchorBlock = '';
    if (isRace) {
      const dowName = ['', 'segunda', 'terça', 'quarta', 'quinta', 'sexta', 'sábado', 'domingo'][plan.raceDayOfWeek!];
      const [y, m, d] = plan.raceDate!.split('-');
      const antiFatigue = deltaPct > 15
        ? `- DETECÇÃO: atleta está ${deltaPct.toFixed(0)}% ACIMA do volume planejado nesta semana. NÃO suba carga nas próximas semanas — MANTÉM ou REDUZA 5-10%. Objetivo é chegar fresco na prova (semana ${raceWeekNumber}), não maximizar treino no meio do mesociclo. Cite essa leitura no coachExplanation com o aviso "vamos preservar pra você chegar inteiro na prova".`
        : deltaPct < -15
          ? `- DETECÇÃO: atleta está ${Math.abs(deltaPct).toFixed(0)}% ABAIXO do volume planejado. Ajuste pra cima com cautela, mas RESPEITE a curva do plano — nada de "recuperar carga perdida" próximo do taper (semana ${taperWeekNumber}).`
          : `- Performance dentro do esperado. Progressão padrão na janela revisável.`;
      raceAnchorBlock = [
        '',
        'ÂNCORA DA PROVA — REGRA DURA IMUTÁVEL:',
        `- Prova: ${d}/${m}/${y} (semana ${raceWeekNumber}, dia ${plan.raceDayOfWeek} = ${dowName}).`,
        `- weeksCount permanece ${plan.weeksCount}. NÃO adicione/remova semanas.`,
        `- Race week (${raceWeekNumber}) e Taper week (${taperWeekNumber}) são INTOCÁVEIS — devolva exatamente como estão no plano atual (cópia verbatim no \`newWeeks\`).`,
        `- AJUSTES reais apenas em ${detailWeekNums || `semanas ${weekNumber + 1}+`} (janela de revisão).`,
        '',
        'ANTI-FADIGA (objetivo é chegar inteiro na prova, não brilhar no meio do plano):',
        antiFatigue,
        '',
      ].join('\n');
    }

    const prompt = `Você é o Coach AI do runnin executando um CHECKPOINT semanal.

CONTEXTO DA SEMANA ${weekNumber}:
- Aderência: ${weekMetrics.completedRuns}/${weekMetrics.plannedSessions} sessões (${Math.round(weekMetrics.completionRate * 100)}%)
- Volume planejado: ${weekMetrics.plannedDistanceKm.toFixed(1)}km
- Volume realizado em sessões DO PLANO: ${weekMetrics.plannedRunsDistanceKm.toFixed(1)}km
- Volume EXTRA em FREE RUNS (compensação espontânea, conta como carga): ${weekMetrics.freeRunsDistanceKm.toFixed(1)}km
- Volume total realizado: ${weekMetrics.actualDistanceKm.toFixed(1)}km
${weekMetrics.avgBpm ? `- BPM médio: ${weekMetrics.avgBpm}` : ''}
${weekMetrics.avgPaceMinPerKm ? `- Pace médio (todas runs): ${weekMetrics.avgPaceMinPerKm.toFixed(2)}min/km` : ''}
${weekMetrics.plannedRunsAvgPaceMinPerKm ? `- Pace médio nas sessões do plano: ${weekMetrics.plannedRunsAvgPaceMinPerKm.toFixed(2)}min/km` : ''}
${weekMetrics.freeRunsAvgPaceMinPerKm ? `- Pace médio nas free runs: ${weekMetrics.freeRunsAvgPaceMinPerKm.toFixed(2)}min/km` : ''}

IMPORTANTE — leia ANTES de avaliar:
- Free runs contam como CARGA EFETIVA. Atleta que fez 2 sessões do plano + 1 free run que cobre o déficit das outras 3 sessões cumpriu a SEMANA (não "faltou 3 vezes").
- Pace melhor que o planejado em qualquer run = sinal POSITIVO de capacidade, deve ser RECONHECIDO antes de mencionar alertas.
- Sono ruim isolado NÃO justifica deload drástico se a performance foi boa e pace estava no alvo. Calibre, não pune.

CORRIDAS DA SEMANA (cada item pode trazer feedback subjetivo enviado pelo user logo após a corrida — use pra correlacionar chips com a corrida específica):
${runsDigest}

SINAIS FISIOLÓGICOS DA SEMANA (HealthKit / Health Connect):
${biometricsDigest}

FEEDBACK AGREGADO DA SEMANA (união deduplicada dos chips submetidos em todas as corridas — use como leitura macro):
${inputsDigest}

SEMANAS RESTANTES NO PLANO (você vai ajustar essas):
${followingDigest}
${paceOvershootBlock}${overloadBlock}${raceAnchorBlock}
Sua tarefa: avaliar a semana, considerar inputs do usuário e ajustar as semanas SEGUINTES (NÃO mexa em semanas anteriores nem na semana ${weekNumber}). Mantenha estrutura/ID das sessions onde possível; ajuste distanceKm, targetPace, durationMin, type, notes conforme necessário.

REGRA DURA — TIPO DE SESSÃO (igual à criação do plano): o runnin é um app de CORRIDA. As sessões agendadas SÓ podem ser corrida (Easy Run, Intervalado, Tempo Run, Long Run, Recovery, Fartlek, Progressivo, Tiros) ou "Caminhada" (único tipo não-corrida permitido como sessão, pra baixo impacto/base aeróbica/recuperação). NUNCA agende ciclismo/bike, natação, elíptico, remo ou musculação como uma SESSÃO (campo type). Esses cross-trainings podem, no MÁXIMO, ser SUGERIDOS no campo notes como atividade complementar opcional — jamais viram uma sessão do plano.

REGRA DURA — TIPO DE SESSÃO POR NÍVEL DO ATLETA (level=${plan.level}):
- INICIANTE: SÓ pode prescrever: Easy Run, Long Run, Recovery, Caminhada, Progressivo. **NÃO PODE Fartlek, Intervalado, Tempo Run, Tiros** — esses tipos exigem base aeróbica e técnica de respiração que o iniciante ainda não tem. Prescrever-os é convidar lesão e frustração. Diversidade pra iniciante = variar entre Easy/Long/Recovery/Progressivo, NÃO criar sessões de qualidade.
- INTERMEDIÁRIO: pode adicionar Tempo Run + Fartlek (intensidade controlada).
- AVANÇADO: pode usar todos os tipos, incluindo Intervalado e Tiros (sessões de qualidade).
SE você prescrever um tipo NÃO PERMITIDO pro level deste atleta, é um BUG estrutural que vai gerar lesão. CHEQUE antes de devolver o JSON.

GERAÇÃO EM DOIS NÍVEIS (CRÍTICO):
- As 2 PRÓXIMAS semanas (${detailWeekNums || 'as imediatamente seguintes'}) devem vir com DETALHE COMPLETO: cada sessão com targetPace, durationMin, hydrationLiters, nutritionPre, nutritionPost e notes ricas (2-4 frases com fase + foco + cuidado). É AGORA que essas semanas ganham detalhe — antes estavam em esqueleto.${skeletonWeekNums ? `\n- As demais semanas (${skeletonWeekNums}) seguem em ESQUELETO: só type, distanceKm, targetPace e notes curta (1 frase). NÃO preencha hydration/nutrition nessas — serão detalhadas no próximo checkpoint.` : ''}
- Seja CRIATIVO e técnico nos tipos de sessão das 2 semanas detalhadas (Fartlek, Progressivo, Tiros, Tempo em blocos) — evite repetir "Easy Run" demais. Toda variação tecnicamente verdadeira.

Princípios:
- "load_up" + boa aderência → suba volume 5-10% nas próximas 2 semanas
- "load_down" / "low_energy" / "sleep_bad" → reduza volume 10-15% na próxima semana, redistribuir intensidade
- "pain" → tira intervalado/tempo da próxima semana, mantém só easy/recovery; mensagem reforça avaliação clínica
- "schedule_conflict" → reduz N de sessões por semana mas mantém km total redistribuído
- aderência baixa (<50%) sem input do user → reduz volume defensivamente; reconheça e adapte
- aderência alta (>90%) sem input → mantém ou progressão padrão (sem aumento extra)
- usuário rodou ALÉM do planejado (distância maior OU pace mais rápido que targetPace) e completou bem (sem dor/exaustão) → considere subir progressão 5-10% (conservador) ao invés de manter; cite no coachExplanation a leitura "você rodou X km/min/km além do plano e tolerou bem"
- PRINCÍPIO GUARDA: seja CONSERVADOR ao SUBIR carga (lesão custa mais que undertraining); seja RESPONSIVO ao REDUZIR carga ao primeiro sinal de sobrecarga/dor/sono ruim

TOM do coachExplanation (CRÍTICO):
- BALANCE entre verdade técnica e encorajamento. Se o atleta fez MAIS volume com free runs num pace bom, RECONHEÇA isso PRIMEIRO antes de mencionar sinais de alerta.
- NUNCA use linguagem catastrófica ("convite a lesões", "esgotamento extremo", "perigoso", "drástico").
- Use "atenção necessária", "vamos calibrar", "sinal pra cuidar", "ajuste pra sustentar a base", "preparar pra subir bem".
- Se houver puxão de orelha, faça com leveza — não vire palestra de risco.

RESPONDA APENAS JSON estritamente neste schema:

{
  "autoAnalysis": "string (1-3 frases) descrevendo o que você LEU dos dados — não o que vai fazer.",
  "coachExplanation": "string (3-5 parágrafos markdown) explicando os ajustes e o porquê fisiológico/comportamental. Use 'você'. PT-BR. Tom equilibrado.",
  "newWeeks": [
    {
      "weekNumber": ${followingWeeks[0]?.weekNumber ?? weekNumber + 1},
      "narrative": "1-2 frases pra o atleta sobre o foco DESTA semana ajustada (não genérica — combine com as sessões abaixo)",
      "focus": "string curta tipo 'Recuperação · Reset' | 'Build · Volume' | 'Quality · Tempo' (max 30 chars)",
      "blockName": "string didática tipo 'BASE · Adaptação' | 'BUILD · Capacidade' (max 35 chars)",
      "objective": "1 frase com o objetivo da semana",
      "targets": ["bullet 1 do alvo da semana", "bullet 2"],
      "sessions": [
        {
          "dayOfWeek": 1..7,
          "type": "Easy Run | Long Run | Recovery | Tempo Run | Intervalado | Fartlek | Progressivo | Tiros | Caminhada",
          "distanceKm": N,
          "targetPace": "M:SS",
          "durationMin": N,
          "hydrationLiters": N,
          "nutritionPre": "1 frase específica (não 'comer banana')",
          "nutritionPost": "1 frase específica",
          "notes": "2-4 frases explicando o ESTÍMULO (fase do treino + foco fisiológico + cuidado/forma)"
        }
      ]
    },
    ...
  ]
}

REGRAS de preenchimento:
- newWeeks deve conter EXATAMENTE as ${followingWeeks.length} semanas: de ${followingWeeks[0]?.weekNumber} a ${followingWeeks[followingWeeks.length - 1]?.weekNumber}.
- TODOS os campos das sessões e das semanas são OBRIGATÓRIOS — incluindo targetPace, durationMin, hydrationLiters, nutritionPre, nutritionPost, notes, narrative, focus, blockName, objective, targets. Não omita nada.
- narrative DEVE refletir o ajuste atual (se deload, "semana de absorver"; se build, "semana de ganhar"; etc) — não copie narrativa antiga.
- Sem comentários, sem texto fora do JSON.
- Se nenhum ajuste se justifica, devolva newWeeks com as semanas atuais MAS atualize narrative/focus/blockName pra refletir "manutenção, no rumo".`;

    // 1ª tentativa: prompt rico + JSON mode + cap generoso. responseJson=true
    // ativa `responseMimeType: 'application/json'` no Gemini, que força a
    // saída a ser JSON bem-formado (sem aspas escapadas erradas / vírgulas
    // sobrando). maxTokens=16000 cobre planos de 14+ semanas restantes
    // (cada semana ~700-1000 tokens em JSON; 14×900≈12600 + buffer).
    const tryGenerate = (opts: { maxTokens: number; sysExtra: string }) =>
      this.llm.generate(prompt, {
        systemPrompt:
          'Você é o Coach AI. Retorne SOMENTE JSON válido. Sem comentários, sem markdown, sem texto fora do JSON. ' +
          opts.sysExtra,
        userId: plan.userId,
        useCase: 'weekly-revision-analysis',
        maxTokens: opts.maxTokens,
        temperature: 0.35,
        responseJson: true,
      });

    try {
      let raw = await tryGenerate({
        maxTokens: 16000,
        sysExtra: '',
      });
      let parsed = this._parseJson(raw);

      if (!parsed) {
        // 2ª tentativa: prompt mais estrito + cap maior. Quando a 1ª trunca,
        // pedimos ao LLM pra encurtar campos descritivos (notes, nutritionPre/
        // Post) sem mudar a estrutura do plano. Reduz drasticamente o output.
        logger.warn('checkpoint.analysis.retry', {
          weekNumber,
          reason: 'json_invalid_or_truncated',
          firstAttemptLen: raw.length,
        });
        raw = await tryGenerate({
          maxTokens: 24000,
          sysExtra:
            'IMPORTANTE: a tentativa anterior estourou o limite. ' +
            'Mantenha autoAnalysis em no máximo 280 caracteres, coachExplanation em no máximo 200, ' +
            'e cada session.notes / nutritionPre / nutritionPost em no máximo 160 caracteres. ' +
            'Foque no essencial sem perder fidelidade ao formato.',
        });
        parsed = this._parseJson(raw);
        if (!parsed) {
          return this._fallback(input, 'JSON inválido do LLM (após retry)');
        }
      }

      return {
        autoAnalysis: parsed.autoAnalysis ?? this._mechanicalAnalysis(weekMetrics),
        coachExplanation: parsed.coachExplanation ?? 'Ajustes aplicados às semanas seguintes.',
        newWeeks: parsed.newWeeks ?? [],
      };
    } catch (err) {
      logger.warn('checkpoint.analysis.llm_failed', {
        weekNumber,
        err: err instanceof Error ? err.message : String(err),
      });
      return this._fallback(input, 'LLM indisponível');
    }
  }

  private _fallback(
    input: CheckpointAnalysisInput,
    reason: string,
  ): CheckpointAnalysisOutput {
    return {
      autoAnalysis: this._mechanicalAnalysis(input.weekMetrics),
      newWeeks: [],
      coachExplanation:
        `Análise estrutural ficou indisponível neste checkpoint (${reason}). ` +
        'Seu plano segue como estava. Você pode tentar de novo mais tarde ou ' +
        'aguardar o próximo checkpoint semanal.',
    };
  }

  private _mechanicalAnalysis(m: CheckpointAnalysisInput['weekMetrics']): string {
    const pct = Math.round(m.completionRate * 100);
    return (
      `Semana fechou com ${m.completedRuns}/${m.plannedSessions} sessões (${pct}% aderência) ` +
      `e ${m.actualDistanceKm.toFixed(1)}km dos ${m.plannedDistanceKm.toFixed(1)}km planejados.`
    );
  }

  private _parseJson(raw: string): {
    autoAnalysis?: string;
    coachExplanation?: string;
    newWeeks?: PlanWeek[];
  } | null {
    try {
      const cleaned = raw.replace(/^```(?:json)?\s*|\s*```\s*$/g, '').trim();
      const start = cleaned.indexOf('{');
      const end = cleaned.lastIndexOf('}');
      if (start < 0 || end <= start) return null;
      const obj = JSON.parse(cleaned.slice(start, end + 1)) as {
        autoAnalysis?: string;
        coachExplanation?: string;
        newWeeks?: PlanWeek[];
      };
      return obj;
    } catch {
      return null;
    }
  }
}

/** "5:30" → 330 (segundos). Retorna null se inválido/ausente. */
function paceStrToSeconds(pace: string | null | undefined): number | null {
  if (!pace) return null;
  const m = pace.match(/^(\d+):(\d{1,2})$/);
  if (!m) return null;
  return Number(m[1]) * 60 + Number(m[2]);
}

/** 330 → "5:30". */
function secondsToPaceStr(sec: number): string {
  const m = Math.floor(sec / 60);
  const s = sec % 60;
  return `${m}:${s.toString().padStart(2, '0')}`;
}
