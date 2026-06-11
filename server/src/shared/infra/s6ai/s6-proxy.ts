import { IncomingMessage, Server as HttpServer } from 'http';
import { Request, Response } from 'express';
import WebSocket, { WebSocketServer } from 'ws';
import { logger } from '@shared/logger/logger';

/**
 * Proxy autenticado runnin-api → s6-ai para STAGING.
 *
 * Por quê: nenhuma conta credenciada na máquina de deploy tem
 * `run.services.setIamPolicy` (só o owner), então o serviço s6-ai ficou
 * SEM binding allUsers — invocável apenas por identidades com
 * `run.routes.invoke` (Editor). O runnin-api-staging roda como deploy@
 * (Editor) e encaminha o tráfego do app com ID token do metadata server.
 *
 * O ID token vai em `X-Serverless-Authorization` (Cloud Run valida e
 * REMOVE esse header), preservando o `Authorization: Bearer <firebase>`
 * original que o s6-ai usa pra autenticar o usuário.
 *
 * Quando o owner aplicar o binding allUsers no s6-ai, é só apontar o
 * wsUrl de volta pro s6-ai direto (env S6_WS_PROXY=false) — este proxy
 * vira bypass morto sem precisar de deploy do app.
 */

const METADATA_IDENTITY_URL =
  'http://metadata.google.internal/computeMetadata/v1/instance/service-accounts/default/identity';

let cachedToken: { token: string; audience: string; expiresAt: number } | null = null;

/** ID token do runtime SA pro audience (URL do s6-ai). Cache ~50min (TTL 1h). */
export async function mintIdToken(audience: string): Promise<string | null> {
  if (
    cachedToken &&
    cachedToken.audience === audience &&
    Date.now() < cachedToken.expiresAt
  ) {
    return cachedToken.token;
  }
  try {
    const res = await fetch(
      `${METADATA_IDENTITY_URL}?audience=${encodeURIComponent(audience)}`,
      { headers: { 'Metadata-Flavor': 'Google' } },
    );
    if (!res.ok) return null;
    const token = (await res.text()).trim();
    cachedToken = { token, audience, expiresAt: Date.now() + 50 * 60 * 1000 };
    return token;
  } catch {
    // Dev local: sem metadata server. s6-ai local não exige IAM.
    return null;
  }
}

function s6Base(): string {
  return (process.env['S6_AI_URL'] ?? '').trim().replace(/\/$/, '');
}

/** true quando o app deve falar com o s6-ai ATRAVÉS deste proxy. */
export function s6WsProxyEnabled(): boolean {
  return (process.env['S6_WS_PROXY'] ?? 'true').toLowerCase() !== 'false';
}

/**
 * Passthrough HTTP montado em `/v1/live` — cobre o fallback de eventos
 * (POST /sessions/:id/events) e o encerramento (DELETE /sessions/:id)
 * que o app chama no host do wsUrl.
 */
export async function s6LiveHttpProxy(req: Request, res: Response): Promise<void> {
  const base = s6Base();
  if (!base) {
    res.status(503).json({ error: { code: 'S6_UNCONFIGURED' } });
    return;
  }
  const idToken = await mintIdToken(base);
  const headers: Record<string, string> = { 'Content-Type': 'application/json' };
  const auth = req.headers['authorization'];
  if (typeof auth === 'string') headers['Authorization'] = auth;
  if (idToken) headers['X-Serverless-Authorization'] = `Bearer ${idToken}`;

  try {
    const upstream = await fetch(`${base}/v1/live${req.url}`, {
      method: req.method,
      headers,
      body: req.method === 'GET' || req.method === 'HEAD' || req.method === 'DELETE'
        ? undefined
        : JSON.stringify(req.body ?? {}),
    });
    res.status(upstream.status);
    const skipReason = upstream.headers.get('x-cue-skip-reason');
    if (skipReason) res.setHeader('X-Cue-Skip-Reason', skipReason);
    const contentType = upstream.headers.get('content-type');
    if (contentType) res.setHeader('Content-Type', contentType);
    const buf = Buffer.from(await upstream.arrayBuffer());
    res.send(buf);
  } catch (err) {
    logger.warn('s6.http_proxy.failed', { path: req.url, err: String(err) });
    res.status(502).json({ error: { code: 'S6_PROXY_FAILED' } });
  }
}

/**
 * Túnel WS bidirecional `/v1/live` ↔ s6-ai. Frames binários (PCM) e JSON
 * passam intactos nos dois sentidos; a query (sessionId + token Firebase)
 * é repassada — o s6-ai segue dono da autenticação do usuário.
 */
export function attachS6LiveWsProxy(httpServer: HttpServer): void {
  const wss = new WebSocketServer({ noServer: true });

  httpServer.on('upgrade', (req: IncomingMessage, socket, head) => {
    const url = new URL(req.url ?? '/', `http://${req.headers.host}`);
    if (url.pathname !== '/v1/live') return; // outros handlers cuidam dos seus paths

    const base = s6Base();
    if (!base) {
      socket.write('HTTP/1.1 503 Service Unavailable\r\n\r\n');
      socket.destroy();
      return;
    }

    void (async () => {
      const idToken = await mintIdToken(base);
      const target = `${base.replace(/^http/, 'ws')}/v1/live${url.search}`;
      const upstream = new WebSocket(target, {
        headers: idToken ? { 'X-Serverless-Authorization': `Bearer ${idToken}` } : {},
      });

      let settled = false;
      upstream.on('open', () => {
        settled = true;
        wss.handleUpgrade(req, socket, head, (client) => {
          logger.info('s6.ws_proxy.connected', { search: url.search.slice(0, 60) });
          const closeBoth = (): void => {
            try { client.close(); } catch { /* ignore */ }
            try { upstream.close(); } catch { /* ignore */ }
          };
          client.on('message', (data, isBinary) => {
            try { upstream.send(data as Buffer, { binary: isBinary }); } catch { /* ignore */ }
          });
          upstream.on('message', (data, isBinary) => {
            try { client.send(data as Buffer, { binary: isBinary }); } catch { /* ignore */ }
          });
          client.on('close', closeBoth);
          upstream.on('close', closeBoth);
          client.on('error', closeBoth);
          upstream.on('error', closeBoth);
        });
      });
      upstream.on('error', (err) => {
        logger.warn('s6.ws_proxy.upstream_error', { err: String(err) });
        if (!settled) {
          try {
            socket.write('HTTP/1.1 502 Bad Gateway\r\n\r\n');
            socket.destroy();
          } catch { /* ignore */ }
        }
      });
    })();
  });
}
