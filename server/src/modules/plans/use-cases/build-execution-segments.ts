import { PlanSegment, PlanSession } from '../domain/plan.entity';

/**
 * Gera o roteiro km-a-km (executionSegments) de uma sessão de forma
 * DETERMINÍSTICA — sem LLM. Cobre os 5 tipos principais (easy, tempo,
 * long, interval, recovery) com templates baseados em distância e pace.
 *
 * Estratégia: a maioria das corridas tem 3 fases:
 *   warmup (5-10min) → main (núcleo) → cooldown (5min)
 * Intervalados adicionam alternância tiro/recovery dentro do main.
 *
 * Sem LLM porque (a) salva quota Gemini, (b) é instantâneo, (c) o
 * conteúdo é genérico-mas-útil por natureza (pace alvo + instrução
 * curta vinda do plano já tem tudo que o atleta precisa pra executar).
 * Polish via LLM pode ser layer futura.
 */
export function buildExecutionSegments(session: PlanSession): PlanSegment[] {
  const dist = session.distanceKm;
  if (!dist || dist <= 0) return [];

  const type = (session.type ?? '').toLowerCase();
  const pace = session.targetPace?.trim() || null;

  if (type.includes('interval') || type.includes('tiro')) {
    return buildIntervalSegments(dist, pace);
  }
  if (type.includes('tempo') || type.includes('limiar')) {
    return buildTempoSegments(dist, pace);
  }
  if (type.includes('long') || type.includes('longão') || type.includes('longao')) {
    return buildLongSegments(dist, pace);
  }
  if (
    type.includes('recovery') ||
    type.includes('regenerativ') ||
    type.includes('recup')
  ) {
    return buildRecoverySegments(dist, pace);
  }
  // default = easy / base / qualquer outro
  return buildEasySegments(dist, pace);
}

function paceLine(pace: string | null, fallback: string): string {
  return pace ? `pace alvo ${pace}/km` : fallback;
}

function durationMinFromKm(km: number, pace: string | null, defaultMinPerKm: number): number {
  const minPerKm = parsePaceToMinPerKm(pace) ?? defaultMinPerKm;
  return Math.round(km * minPerKm * 10) / 10;
}

function parsePaceToMinPerKm(pace: string | null): number | null {
  if (!pace) return null;
  const m = pace.match(/^(\d+):(\d{1,2})/);
  if (!m) return null;
  const min = Number(m[1]);
  const sec = Number(m[2]);
  if (Number.isNaN(min) || Number.isNaN(sec)) return null;
  return min + sec / 60;
}

function buildEasySegments(dist: number, pace: string | null): PlanSegment[] {
  // Easy: 1km warmup + (dist-2)km main + 1km cooldown (mínimo 3km).
  // Pra distâncias < 3km, fica só 1 segmento principal.
  if (dist < 3) {
    return [
      {
        kmStart: 0,
        kmEnd: dist,
        phase: 'main',
        targetPace: pace ?? undefined,
        durationMin: durationMinFromKm(dist, pace, 6.5),
        instruction:
          `Easy run de ${dist.toFixed(1)}km, conversável. ` +
          paceLine(pace, 'mantenha respiração nasal confortável') +
          '. Sem heroísmo — easy é easy.',
      },
    ];
  }
  const warmKm = 1;
  const coolKm = 1;
  const mainKm = round1(dist - warmKm - coolKm);
  return [
    {
      kmStart: 0,
      kmEnd: warmKm,
      phase: 'warmup',
      durationMin: durationMinFromKm(warmKm, null, 7.5),
      instruction:
        'Aquecimento: comece bem leve, 5-7 min caminhando rápido ou trote suave. ' +
        'Solte os ombros, respire pelo nariz. Vou avisando se você acelerar demais.',
    },
    {
      kmStart: warmKm,
      kmEnd: round1(warmKm + mainKm),
      phase: 'main',
      targetPace: pace ?? undefined,
      durationMin: durationMinFromKm(mainKm, pace, 6.5),
      instruction:
        `Núcleo da sessão (${mainKm.toFixed(1)}km). ` +
        paceLine(pace, 'mantenha respiração nasal — easy é easy') +
        '. Se acelerar e perder conversa, é sinal de que está rápido demais.',
    },
    {
      kmStart: round1(warmKm + mainKm),
      kmEnd: dist,
      phase: 'cooldown',
      durationMin: durationMinFromKm(coolKm, null, 7.5),
      instruction:
        'Cooldown: 5 min de trote bem leve até caminhada. Foco em recuperar fôlego ' +
        'e baixar o cardio antes de parar de vez.',
    },
  ];
}

function buildTempoSegments(dist: number, pace: string | null): PlanSegment[] {
  // Tempo: 1.5km warmup + tempo em pace alvo + 1km cooldown.
  const warmKm = Math.min(1.5, Math.max(1, dist * 0.2));
  const coolKm = 1;
  const tempoKm = round1(dist - warmKm - coolKm);
  if (tempoKm <= 0) {
    return buildEasySegments(dist, pace);
  }
  return [
    {
      kmStart: 0,
      kmEnd: round1(warmKm),
      phase: 'warmup',
      durationMin: durationMinFromKm(warmKm, null, 7.0),
      instruction:
        'Aquecimento progressivo (8-10 min): comece em trote suave e nos últimos 2 min ' +
        'acelere até quase o pace de tempo. Faça 4-5 inspirações profundas no final.',
    },
    {
      kmStart: round1(warmKm),
      kmEnd: round1(warmKm + tempoKm),
      phase: 'main',
      targetPace: pace ?? undefined,
      durationMin: durationMinFromKm(tempoKm, pace, 5.5),
      instruction:
        `Tempo Run (${tempoKm.toFixed(1)}km). ` +
        paceLine(pace, 'pace forte porém sustentável') +
        '. Sensação alvo: "confortavelmente difícil" — você conseguiria falar 2-3 ' +
        'palavras, não mais. Se passar disso, segura.',
    },
    {
      kmStart: round1(warmKm + tempoKm),
      kmEnd: dist,
      phase: 'cooldown',
      durationMin: durationMinFromKm(coolKm, null, 7.5),
      instruction:
        'Cooldown ativo: 5 min de trote leve. Solta os braços, respira fundo. ' +
        'Hidrate logo após e estique posterior + panturrilha.',
    },
  ];
}

function buildLongSegments(dist: number, pace: string | null): PlanSegment[] {
  // Long Run: 1km warmup + 2 fases main (estável + leve aumento opcional) + 1km cooldown.
  const warmKm = 1;
  const coolKm = 1;
  const remaining = dist - warmKm - coolKm;
  if (remaining <= 0) return buildEasySegments(dist, pace);
  // Primeiros 70% do main em pace base, últimos 30% pode subir 5-10s/km
  // se atleta sentir bem. Conservador.
  const baseKm = round1(remaining * 0.7);
  const finishKm = round1(remaining - baseKm);
  return [
    {
      kmStart: 0,
      kmEnd: warmKm,
      phase: 'warmup',
      durationMin: durationMinFromKm(warmKm, null, 8.0),
      instruction:
        'Largue MUITO devagar. Os primeiros 5-7 min do longão são pra acordar o motor ' +
        'aeróbico — se sair rápido, paga lá no fim. Respiração toda nasal.',
    },
    {
      kmStart: warmKm,
      kmEnd: round1(warmKm + baseKm),
      phase: 'main',
      targetPace: pace ?? undefined,
      durationMin: durationMinFromKm(baseKm, pace, 7.0),
      instruction:
        `Núcleo aeróbico (${baseKm.toFixed(1)}km). ` +
        paceLine(pace, 'pace conversável') +
        '. Hidrate a cada 20-25 min (gole pequeno). Se passar de 60 min, gel ou ' +
        'banana ajuda a manter glicogênio.',
    },
    {
      kmStart: round1(warmKm + baseKm),
      kmEnd: round1(warmKm + baseKm + finishKm),
      phase: 'main',
      targetPace: pace ?? undefined,
      durationMin: durationMinFromKm(finishKm, pace, 6.7),
      instruction:
        `Reta final do longão (${finishKm.toFixed(1)}km). Se está bem, pode segurar o ` +
        'pace ou acelerar 5-10s/km nos últimos km — simula final de prova. ' +
        'Se não está bem, mantém pace e termina. Não force o que não tem.',
    },
    {
      kmStart: round1(warmKm + baseKm + finishKm),
      kmEnd: dist,
      phase: 'cooldown',
      durationMin: durationMinFromKm(coolKm, null, 8.5),
      instruction:
        'Cooldown longo (5-7 min de trote → caminhada). Eletrólito + carbo nos 30 min ' +
        'seguintes, alongue posterior, quadril e panturrilha. Foam roller hoje à noite.',
    },
  ];
}

function buildIntervalSegments(dist: number, pace: string | null): PlanSegment[] {
  // Interval: 1.5km warmup + N tiros 400m com 200m recovery + 1km cooldown.
  // Calcula N tiros pra fechar a distância total.
  const warmKm = 1.5;
  const coolKm = 1;
  const remaining = dist - warmKm - coolKm;
  if (remaining <= 0.8) return buildEasySegments(dist, pace);
  // 1 ciclo = 0.4 (tiro) + 0.2 (recovery) = 0.6km
  const cycles = Math.max(3, Math.min(10, Math.floor(remaining / 0.6)));
  const segments: PlanSegment[] = [];
  segments.push({
    kmStart: 0,
    kmEnd: warmKm,
    phase: 'warmup',
    durationMin: durationMinFromKm(warmKm, null, 7.0),
    instruction:
      'Aquecimento robusto (10-12 min): trote crescente + 4 educativos (skipping, ' +
      'puxada, caneco, anfersen) de 20m cada. Sem isso o primeiro tiro vira lesão.',
  });
  let cursor = warmKm;
  for (let i = 0; i < cycles; i++) {
    const repPace = pace; // tiro em pace alvo se informado
    segments.push({
      kmStart: round1(cursor),
      kmEnd: round1(cursor + 0.4),
      phase: 'interval',
      targetPace: repPace ?? undefined,
      durationMin: durationMinFromKm(0.4, repPace, 4.0),
      instruction:
        `Tiro ${i + 1}/${cycles} (400m). ` +
        paceLine(repPace, 'forte, controlado — não é all-out') +
        '. Postura ereta, frequência alta, respiração ritmada (2 inspira / 2 expira).',
    });
    cursor += 0.4;
    segments.push({
      kmStart: round1(cursor),
      kmEnd: round1(cursor + 0.2),
      phase: 'recovery',
      durationMin: durationMinFromKm(0.2, null, 9.0),
      instruction:
        `Recovery ${i + 1}/${cycles} (200m): trote bem leve ou caminhada. ` +
        'Foco em baixar pulso pro próximo tiro. Não é descanso parado.',
    });
    cursor += 0.2;
  }
  segments.push({
    kmStart: round1(cursor),
    kmEnd: dist,
    phase: 'cooldown',
    durationMin: durationMinFromKm(coolKm, null, 8.0),
    instruction:
      'Cooldown: 5-8 min de trote → caminhada. Alongue quadríceps, isquios e ' +
      'panturrilha. Repõe carbo + proteína em 30 min — músculo absorve melhor.',
  });
  return segments;
}

function buildRecoverySegments(dist: number, pace: string | null): PlanSegment[] {
  // Recovery: tudo em pace muito leve. Sem warmup/cooldown explícitos.
  return [
    {
      kmStart: 0,
      kmEnd: dist,
      phase: 'recovery',
      targetPace: pace ?? undefined,
      durationMin: durationMinFromKm(dist, pace, 7.5),
      instruction:
        `Recuperação ativa (${dist.toFixed(1)}km). ` +
        paceLine(pace, 'pace BEM leve — propositalmente lento') +
        '. Se acelerar, perde o ponto: hoje é circulação, não estímulo. ' +
        'Se sente perna pesada, vira caminhada — sem culpa.',
    },
  ];
}

function round1(n: number): number {
  return Math.round(n * 10) / 10;
}
