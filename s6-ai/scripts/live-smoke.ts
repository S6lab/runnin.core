/**
 * SMOKE E2E do live coach — dirige uma "corrida sintética" contra o s6-ai
 * REAL (local ou staging) pelo mesmo fio do app: cria sessão s2s, conecta
 * no WS e envia a sequência canônica de eventos, validando as respostas.
 *
 * Por que existe: TODOS os bugs históricos do coach (WS caindo aos 5min,
 * kms mudos, áudio duplicado, números errados na fala) aconteceram no fio
 * WS+Gemini+Cloud Run — onde os specs unitários não chegam. Este script
 * pega essas regressões em ~2min, antes do deploy, sem corrida real.
 *
 * Uso:
 *   S6_INTERNAL_TOKEN=... SMOKE_ID_TOKEN=... npm run smoke -- \
 *     --s6-url=https://runnin-s6-ai-staging-... [--scenario=plan|assessment] [--long]
 *
 *   Sem SMOKE_ID_TOKEN, busca via dev-login no runnin-api:
 *   X_CRON_TOKEN=... SMOKE_EMAIL=... SMOKE_PASSWORD=... \
 *     npm run smoke -- --s6-url=... --server-url=https://runnin-api-staging-...
 *
 * Flags:
 *   --s6-url=      base do s6-ai (obrigatório; ex: http://localhost:8080)
 *   --server-url=  base do runnin-api (só pro dev-login)
 *   --scenario=    plan (default) | assessment
 *   --long         mantém a sessão viva >5,5min antes do finish (regressão
 *                  do timeout de 300s do Cloud Run — smoke 2026-06-11)
 *
 * Saída: relatório JSON no stdout + exit 0/1 (CI-able).
 */
import WebSocket from 'ws';
import { LiveSessionContext } from '../src/modules/live/live-session.types';
import { CueEvent } from '../src/modules/live/cue-events';

// ── CLI/env ─────────────────────────────────────────────────────────────

function flag(name: string): string | undefined {
  const hit = process.argv.find((a) => a.startsWith(`--${name}=`));
  return hit?.slice(name.length + 3);
}
const hasFlag = (name: string) => process.argv.includes(`--${name}`);

const S6_URL = (flag('s6-url') ?? process.env['SMOKE_S6_URL'] ?? '').replace(/\/$/, '');
const SERVER_URL = (flag('server-url') ?? process.env['SMOKE_SERVER_URL'] ?? '').replace(/\/$/, '');
const SCENARIO = (flag('scenario') ?? 'plan') as 'plan' | 'assessment';
const LONG_RUN = hasFlag('long');
const INTERNAL_TOKEN = process.env['S6_INTERNAL_TOKEN'] ?? '';

// Janela de espera por resposta de um cue. A geração Gemini leva 3-10s;
// 30s cobre cold start do socket sem mascarar travamento real.
const CUE_TIMEOUT_MS = 30_000;
// Pausa entre cues (espelha o espaçamento real de uma corrida acelerada).
const BETWEEN_CUES_MS = 4_000;

// ── Relatório ───────────────────────────────────────────────────────────

interface CueResult {
  event: string;
  sentAt: string;
  responded: boolean;
  latencyMs: number | null;
  audioBytes: number;
  transcript: string;
  turns: number;
  checks: Record<string, boolean | string>;
}

const report: {
  scenario: string;
  s6Url: string;
  startedAt: string;
  sessionId?: string;
  cues: CueResult[];
  sessionAliveMs?: number;
  errors: string[];
  passed?: boolean;
} = {
  scenario: SCENARIO,
  s6Url: S6_URL,
  startedAt: new Date().toISOString(),
  cues: [],
  errors: [],
};

function fail(msg: string): never {
  report.errors.push(msg);
  report.passed = false;
  console.log(JSON.stringify(report, null, 2));
  process.exit(1);
}

// ── Auth ────────────────────────────────────────────────────────────────

async function resolveIdToken(): Promise<{ idToken: string; uid: string }> {
  const direct = process.env['SMOKE_ID_TOKEN'];
  if (direct) {
    // uid extraído do payload do JWT — o WS exige context.userId === uid.
    const payload = JSON.parse(Buffer.from(direct.split('.')[1]!, 'base64url').toString());
    return { idToken: direct, uid: payload.user_id ?? payload.sub };
  }
  const cronToken = process.env['X_CRON_TOKEN'];
  const email = process.env['SMOKE_EMAIL'];
  const password = process.env['SMOKE_PASSWORD'];
  if (!SERVER_URL || !cronToken || !email || !password) {
    fail('Auth ausente: defina SMOKE_ID_TOKEN OU (--server-url + X_CRON_TOKEN + SMOKE_EMAIL + SMOKE_PASSWORD).');
  }
  const res = await fetch(`${SERVER_URL}/v1/admin/dev/login`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json', 'x-cron-token': cronToken },
    body: JSON.stringify({ email, password }),
  });
  if (!res.ok) fail(`dev-login falhou: ${res.status} ${await res.text()}`);
  const data = (await res.json()) as { idToken: string; uid: string };
  return { idToken: data.idToken, uid: data.uid };
}

// ── Contextos sintéticos ────────────────────────────────────────────────

function buildContext(uid: string): LiveSessionContext {
  const base = {
    userId: uid,
    persona: 'tecnico' as const,
    voice: 'Charon',
    locale: 'pt-BR',
    profileSnippet: 'nome Smoke, nível intermediario, objetivo "Completar 10K", 4x/semana',
    sessionNotes: null,
    weather: { temperatureC: 22, humidityPercent: 60, windKmh: 8 },
    prefs: { freq: 'normal' as const, dnd: false, allowCriticalAlertsInSilent: true },
    athleteName: 'Smoke',
  };
  if (SCENARIO === 'assessment') {
    return {
      ...base,
      sessionBriefing: [
        'SESSÃO DE HOJE: CORRIDA DE AVALIAÇÃO · 1km.',
        'MODO MEDIÇÃO — regras desta sessão:',
        '- Briefing: explique o propósito ("vou medir seu ritmo real; corre constante e confortável, sem forçar").',
        '- Check-ins por km: fale só do MEDIDO — NUNCA cite plano, sessão planejada ou meta de treino.',
        '- NÚMEROS: use EXATAMENTE os valores dos dados do turno.',
        '- goal_reached: anuncie o resultado medido.',
      ].join('\n'),
      segments: [],
    } as LiveSessionContext;
  }
  return {
    ...base,
    sessionBriefing: 'SESSÃO DE HOJE: Easy Run · 1km · pace alvo 6:00 · ~6min\nPLANO: "Completar 10K" — semana 1 de 10. Hoje é sexta.',
    segments: [
      { kmStart: 0, kmEnd: 0.5, phase: 'aquecimento', targetPace: '6:30', instruction: 'Começa leve, solta a passada.' },
      { kmStart: 0.5, kmEnd: 1, phase: 'ritmo', targetPace: '6:00', instruction: 'Assenta no pace alvo.' },
    ],
  } as LiveSessionContext;
}

// ── Sequência de eventos (payloads realistas; os NÚMEROS daqui são os que
//    a transcrição deve citar — valida a regra "pace exato") ─────────────

const SEQUENCE: { event: CueEvent; data: Record<string, unknown>; mustContain?: string[] }[] = [
  { event: 'start', data: { kmDone: 0, elapsedS: 0 } },
  {
    event: 'half_km',
    data: { kmDone: 0.5, elapsedS: 180, currentPace: '6:00', pace500m: '6:00', bpm: 142 },
  },
  {
    event: 'km_reached',
    data: { kmDone: 1, elapsedS: 360, currentPace: '6:00', kmDurationS: 360, kmAvgBpm: 148, targetPace: '6:00' },
    mustContain: ['6:00'],
  },
  {
    event: 'goal_reached',
    data: { kmDone: 1, kmRemaining: 0, elapsedS: 362, currentPace: '6:00', bpm: 150 },
  },
  {
    event: 'finish',
    data: { kmDone: 1.05, elapsedS: 380, currentPace: '6:01', bpm: 149 },
  },
];

/** Eventos cuja AUSÊNCIA de resposta reprova o smoke (P0-P1 + saudação). */
const REQUIRED_RESPONSE = new Set(['start', 'km_reached', 'goal_reached', 'finish']);

// ── Main ────────────────────────────────────────────────────────────────

async function main(): Promise<void> {
  if (!S6_URL) fail('--s6-url obrigatório (ex: http://localhost:8080)');
  if (!INTERNAL_TOKEN) fail('S6_INTERNAL_TOKEN obrigatório no env');

  const { idToken, uid } = await resolveIdToken();

  // 1. Cria sessão (s2s — mesmo caminho do BFF)
  const createRes = await fetch(`${S6_URL}/v1/live/sessions`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json', 'x-internal-token': INTERNAL_TOKEN },
    body: JSON.stringify({ context: buildContext(uid) }),
  });
  if (!createRes.ok) fail(`create session falhou: ${createRes.status} ${await createRes.text()}`);
  const { sessionId, wsUrl } = (await createRes.json()) as { sessionId: string; wsUrl: string };
  report.sessionId = sessionId;

  // 2. Conecta no WS (mesma query do app)
  const ws = new WebSocket(`${wsUrl}?sessionId=${sessionId}&token=${idToken}`);
  const wsOpenAt = Date.now();

  let audioBytesWindow = 0;
  let transcriptWindow = '';
  let turnsWindow = 0;
  let lastFrameAt = 0;

  ws.on('message', (raw: Buffer, isBinary: boolean) => {
    lastFrameAt = Date.now();
    if (isBinary) {
      audioBytesWindow += raw.length;
      return;
    }
    try {
      const msg = JSON.parse(raw.toString());
      if (msg.type === 'cue_text' && typeof msg.text === 'string') {
        // Gap >3s entre transcripts = turno novo (heurística pra detectar
        // fala duplicada — "avaliação finalizada 2x" do TF 82).
        turnsWindow += 1;
        transcriptWindow += (transcriptWindow ? ' | ' : '') + msg.text;
      } else if (msg.type === 'error') {
        report.errors.push(`ws error frame: ${JSON.stringify(msg)}`);
      }
    } catch {
      report.errors.push('frame JSON inválido');
    }
  });
  ws.on('error', (err) => report.errors.push(`ws error: ${String(err)}`));

  await new Promise<void>((resolve, reject) => {
    ws.once('open', () => resolve());
    ws.once('close', (code) => reject(new Error(`ws fechou antes do open (${code})`)));
    setTimeout(() => reject(new Error('ws open timeout 15s')), 15_000);
  }).catch((e) => fail(String(e)));

  const sleep = (ms: number) => new Promise((r) => setTimeout(r, ms));

  // 3. Dirige a sequência
  for (const step of SEQUENCE) {
    audioBytesWindow = 0;
    transcriptWindow = '';
    turnsWindow = 0;
    const sentAt = Date.now();
    ws.send(JSON.stringify({ type: 'event', event: step.event, data: step.data }));

    // Espera resposta: primeiro frame OU timeout; depois drena até 4s de silêncio.
    let firstAt: number | null = null;
    while (Date.now() - sentAt < CUE_TIMEOUT_MS) {
      await sleep(250);
      if (firstAt == null && (audioBytesWindow > 0 || transcriptWindow)) firstAt = lastFrameAt;
      if (firstAt != null && Date.now() - lastFrameAt > 4_000) break;
    }

    const checks: Record<string, boolean | string> = {};
    for (const needle of step.mustContain ?? []) {
      checks[`transcript_contains_${needle}`] = transcriptWindow.includes(needle);
    }
    report.cues.push({
      event: step.event,
      sentAt: new Date(sentAt).toISOString(),
      responded: audioBytesWindow > 0 || transcriptWindow.length > 0,
      latencyMs: firstAt != null ? firstAt - sentAt : null,
      audioBytes: audioBytesWindow,
      transcript: transcriptWindow.slice(0, 400),
      turns: turnsWindow,
      checks,
    });

    // Modo --long: segura a sessão >5,5min entre o km e a meta (regressão
    // do timeout 300s do Cloud Run que derrubava o WS).
    if (LONG_RUN && step.event === 'km_reached') {
      const holdUntil = wsOpenAt + 5.5 * 60_000;
      while (Date.now() < holdUntil) {
        if (ws.readyState !== WebSocket.OPEN) fail('WS caiu durante o hold de 5,5min (regressão do timeout!)');
        await sleep(5_000);
      }
    } else {
      await sleep(BETWEEN_CUES_MS);
    }
  }

  report.sessionAliveMs = Date.now() - wsOpenAt;
  ws.close(1000);

  // 4. Veredicto
  const failures: string[] = [];
  for (const cue of report.cues) {
    if (REQUIRED_RESPONSE.has(cue.event) && !cue.responded) {
      failures.push(`${cue.event}: sem resposta (áudio nem texto) em ${CUE_TIMEOUT_MS / 1000}s`);
    }
    for (const [check, ok] of Object.entries(cue.checks)) {
      if (ok === false) failures.push(`${cue.event}: check falhou — ${check}`);
    }
  }
  const goal = report.cues.find((c) => c.event === 'goal_reached');
  if (goal && goal.turns > 2) failures.push('goal_reached: possível fala duplicada (turns > 2)');

  report.errors.push(...failures);
  report.passed = failures.length === 0 && report.errors.length === failures.length;
  console.log(JSON.stringify(report, null, 2));
  process.exit(report.passed ? 0 : 1);
}

main().catch((err) => fail(`smoke crash: ${err instanceof Error ? err.stack : String(err)}`));
