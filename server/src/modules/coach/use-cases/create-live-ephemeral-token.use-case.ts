import { logger } from '@shared/logger/logger';

const AUTH_TOKENS_URL =
  'https://generativelanguage.googleapis.com/v1alpha/auth_tokens';
// gemini-live-2.5-flash-preview funciona pra TEXT response em bidi mas
// é rejeitado pra AUDIO. O modelo native-audio é o suportado pra AUDIO
// modality em BidiGenerateContentConstrained (vide README do pacote
// gemini_live e docs Google Live API).
// DEVE bater com live_coach_voice_service.dart `_model` no app (token efêmero
// é vinculado ao modelo). Descasar gera voz sobreposta no início da corrida.
// preview-12-2025 expirou (1008 "Operation not implemented"). GA atual
// é gemini-live-2.5-flash-native-audio (vide admin-registries.ts).
const DEFAULT_MODEL =
  process.env['GEMINI_LIVE_MODEL']?.trim() ||
  'models/gemini-live-2.5-flash-native-audio';

/**
 * Cria token efêmero pra app Flutter conectar direto no Gemini Live
 * sem a API key real sair do server. Token format: `auth_tokens/...`.
 * App passa pro pacote gemini_live como apiKey + apiVersion: 'v1alpha'.
 *
 * Janela: token válido por 30min, 999 usos (saudação + km_reached +
 * pace_alert + finish na mesma corrida sem precisar renovar). Modelo +
 * modalidades restringidos por liveConnectConstraints — app não pode
 * abusar pra outro modelo ou mais caro.
 *
 * Mudado de uses:1 → uses:999 porque o cache do app guardava token
 * gasto e cues subsequentes falhavam silenciosamente com
 * resource_exhausted.
 */
export interface CreateLiveTokenOptions {
  /** systemInstruction travado no token (objetivo + mood + sessão+segments).
   *  O app é OBRIGADO a enviar o MESMO texto no setup pra casar a constraint. */
  systemInstruction?: string;
  /** Liga a transcrição do áudio de saída — o app exibe o transcript no
   *  banner, garantindo texto == voz (uma fonte só). */
  outputTranscription?: boolean;
}

export class CreateLiveEphemeralTokenUseCase {
  async execute(
    opts: CreateLiveTokenOptions = {},
  ): Promise<{
    token: string;
    expireTime: string;
    model: string;
    voice: string;
    systemInstruction?: string;
    outputTranscription: boolean;
  }> {
    const apiKey = (process.env['GEMINI_API_KEY'] ?? '').trim();
    if (!apiKey) {
      throw new Error('GEMINI_API_KEY not configured on server');
    }

    const now = new Date();
    const expireTime = new Date(now.getTime() + 30 * 60 * 1000).toISOString();
    const newSessionExpireTime = new Date(
      now.getTime() + 2 * 60 * 1000,
    ).toISOString();

    const url = new URL(AUTH_TOKENS_URL);
    url.searchParams.set('key', apiKey);

    const ctrl = new AbortController();
    const to = setTimeout(() => ctrl.abort(), 6000);
    let res: Response;
    try {
      // Formato CORRETO da AuthToken REST API (Google AI docs):
      // body é o objeto AuthToken FLAT no top-level. Sem wrapper `config`
      // (Python SDK) nem wrapper `authToken` (especulação anterior que o
      // Google rejeitou com 400 "Unknown name authToken at 'auth_token'").
      // uses: 0 = unlimited (token reutilizável até expirar em 30min).
      res = await fetch(url, {
        method: 'POST',
        signal: ctrl.signal,
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          expireTime,
          newSessionExpireTime,
          uses: 0,
          // bidiGenerateContentSetup = "constraint" do token. App é OBRIGADO
          // a mandar config compatível na hora de abrir bidi. Setup anterior
          // só declarava responseModalities; o app mandava speechConfig
          // (voiceName='Charon') → Google rejeitava silenciosamente E o
          // setupComplete nunca chegava → app travava em "WebSocket setup
          // timed out after 10s". Agora declaramos tudo que o app vai usar.
          bidiGenerateContentSetup: {
            model: DEFAULT_MODEL,
            generationConfig: {
              responseModalities: ['AUDIO'],
              speechConfig: {
                voiceConfig: {
                  prebuiltVoiceConfig: { voiceName: 'Charon' },
                },
              },
            },
            // Declaramos TUDO que o app vai enviar no setup (a constraint
            // precisa casar 1:1, senão o setupComplete não chega — vide
            // histórico do speechConfig). systemInstruction define o cérebro
            // server-side; outputAudioTranscription liga o transcript pro
            // banner (texto == voz).
            ...(opts.systemInstruction
              ? { systemInstruction: { parts: [{ text: opts.systemInstruction }] } }
              : {}),
            ...(opts.outputTranscription ? { outputAudioTranscription: {} } : {}),
          },
        }),
      });
    } finally {
      clearTimeout(to);
    }

    if (!res.ok) {
      const body = await res.text().catch(() => '');
      // Body completo (sem truncar) — diagnóstico das falhas anteriores
      // mostrou que truncar em 300 chars cortava a parte importante
      // (fieldViolations details).
      logger.error('coach.live_token.failed', {
        status: res.status,
        body,
      });
      throw new Error(`auth_tokens create failed: ${res.status}`);
    }

    const data = (await res.json()) as { name?: string };
    if (!data.name) {
      throw new Error('auth_tokens response missing name');
    }
    // API devolve "name": "auth_tokens/<id>" — usar como apiKey.
    return {
      token: data.name,
      expireTime,
      model: DEFAULT_MODEL,
      voice: 'Charon',
      systemInstruction: opts.systemInstruction,
      outputTranscription: !!opts.outputTranscription,
    };
  }
}
