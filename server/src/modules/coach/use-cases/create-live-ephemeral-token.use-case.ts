import { logger } from '@shared/logger/logger';

const AUTH_TOKENS_URL =
  'https://generativelanguage.googleapis.com/v1alpha/auth_tokens';
const DEFAULT_MODEL =
  process.env['GEMINI_LIVE_MODEL']?.trim() ||
  'models/gemini-live-2.5-flash-preview';

/**
 * Cria token efêmero pra app Flutter conectar direto no Gemini Live
 * sem a API key real sair do server. Token format: `auth_tokens/...`.
 * App passa pro pacote gemini_live como apiKey + apiVersion: 'v1alpha'.
 *
 * Janela: token válido por 30min, 1 uso (1 sessão Live).
 * Modelo restringido aqui — app não pode pular pra outro modelo mais
 * caro com o mesmo token.
 */
export class CreateLiveEphemeralTokenUseCase {
  async execute(): Promise<{ token: string; expireTime: string }> {
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
      res = await fetch(url, {
        method: 'POST',
        signal: ctrl.signal,
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          config: {
            uses: 1,
            expireTime,
            newSessionExpireTime,
            liveConnectConstraints: {
              model: DEFAULT_MODEL,
              config: {
                responseModalities: ['AUDIO'],
              },
            },
          },
        }),
      });
    } finally {
      clearTimeout(to);
    }

    if (!res.ok) {
      const body = await res.text().catch(() => '');
      logger.warn('coach.live_token.failed', {
        status: res.status,
        body: body.slice(0, 300),
      });
      throw new Error(`auth_tokens create failed: ${res.status}`);
    }

    const data = (await res.json()) as { name?: string };
    if (!data.name) {
      throw new Error('auth_tokens response missing name');
    }
    // API devolve "name": "auth_tokens/<id>" — usar como apiKey.
    return { token: data.name, expireTime };
  }
}
