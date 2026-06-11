import { IncomingMessage, Server as HttpServer } from 'http';
import { WebSocketServer, WebSocket, RawData } from 'ws';
import { z } from 'zod';
import { getAuth } from '@shared/infra/firebase/firebase.client';
import { logger } from '@shared/logger/logger';
import { cueSessionStore } from './cue-session.store';
import { GeminiBridge } from './gemini-bridge';
import { buildLiveInstruction } from './instruction-builder';
import { processCueEvent } from './cue-pipeline';
import { CUE_EVENTS, TelemetrySnapshotSchema } from './cue-events';
import { CueSession } from './cue-session';

const EventFrameSchema = z.object({
  type: z.literal('event'),
  event: z.enum(CUE_EVENTS),
  data: TelemetrySnapshotSchema.default({ kmDone: 0, elapsedS: 0 }),
});

/** Bridges ativos por sessionId — 1 por sessão (instância única no v1). */
const bridges = new Map<string, GeminiBridge>();

export function getActiveBridge(sessionId: string): GeminiBridge | null {
  return bridges.get(sessionId) ?? null;
}

/**
 * WS /v1/live?sessionId=&token=
 * app→s6: binário = PCM16 mic | JSON {type:'event', event, data}
 * s6→app: binário = PCM24k do coach | JSON {type:'state'|'cue_text'|'error'}
 */
export function attachLiveWebSocket(httpServer: HttpServer): void {
  const wss = new WebSocketServer({ noServer: true });

  httpServer.on('upgrade', (req: IncomingMessage, socket, head) => {
    const url = new URL(req.url ?? '/', `http://${req.headers.host}`);
    if (url.pathname !== '/v1/live') return;

    const token = url.searchParams.get('token');
    const sessionId = url.searchParams.get('sessionId');
    if (!token || !sessionId) {
      socket.write('HTTP/1.1 400 Bad Request\r\n\r\n');
      socket.destroy();
      return;
    }

    getAuth().verifyIdToken(token).then((decoded) => {
      wss.handleUpgrade(req, socket, head, (ws) => {
        wss.emit('connection', ws, req, decoded.uid, sessionId);
      });
    }).catch((err) => {
      logger.warn('live.ws.auth_failed', { err: String(err) });
      socket.write('HTTP/1.1 401 Unauthorized\r\n\r\n');
      socket.destroy();
    });
  });

  wss.on('connection', async (ws: WebSocket, _req: IncomingMessage, uid: string, sessionId: string) => {
    // Listener registrado SÍNCRONO, antes de QUALQUER await deste handler.
    // O app dispara o evento 'start' ~0ms após o WS abrir; os awaits abaixo
    // (rehydrate + prompt config Firestore + abrir socket Gemini) levam
    // centenas de ms — sem este buffer cru, o frame chegava sem listener e
    // era perdido (a lib ws NÃO bufferiza; saudação muda nos smokes
    // 2026-06-11, duas tentativas de fix em camadas mais internas falharam
    // porque a janela começa JÁ no upgrade).
    const preReady: Array<{ data: RawData; isBinary: boolean }> = [];
    let onFrame: ((data: RawData, isBinary: boolean) => void) | null = null;
    ws.on('message', (data: RawData, isBinary: boolean) => {
      if (onFrame) {
        onFrame(data, isBinary);
      } else {
        preReady.push({ data, isBinary });
      }
    });

    const session = await cueSessionStore.getOrRehydrate(sessionId);
    if (!session || session.context.userId !== uid) {
      ws.send(JSON.stringify({ type: 'error', code: session ? 'forbidden' : 'session_not_found' }));
      ws.close(1008, 'invalid_session');
      return;
    }
    logger.info('live.ws.client_connected', { sessionId, uid, generation: session.generation });

    // Reconexão do app com a mesma sessão: derruba o bridge anterior —
    // generation++ e preamble re-estabelecido na abertura nova.
    const existing = bridges.get(sessionId);
    if (existing) {
      session.bumpGeneration();
      existing.dispose();
      bridges.delete(sessionId);
    }

    const sendJson = (obj: unknown): void => {
      if (ws.readyState === WebSocket.OPEN) ws.send(JSON.stringify(obj));
    };

    let bridge: GeminiBridge;
    try {
      const instruction = await buildLiveInstruction(session.context);
      bridge = new GeminiBridge(session, instruction.text, session.context.voice, {
        onAudioChunk: (b64) => {
          if (ws.readyState === WebSocket.OPEN) ws.send(Buffer.from(b64, 'base64'));
        },
        onState: (state) => sendJson({ type: 'state', state, generation: session.generation }),
        onTranscript: (text) => sendJson({ type: 'cue_text', text }),
      });
      bridges.set(sessionId, bridge);
    } catch (err) {
      logger.error('live.ws.bridge_build_failed', { sessionId, err: String(err) });
      sendJson({ type: 'error', code: 'gemini_unavailable' });
      ws.close(1011, 'gemini_open_failed');
      return;
    }

    const handleFrame = (data: RawData, isBinary: boolean): void => {
      try {
        if (isBinary) {
          bridge.sendUserAudio(Buffer.isBuffer(data) ? data.toString('base64') : Buffer.from(data as ArrayBuffer).toString('base64'));
          return;
        }
        const parsed = JSON.parse(data.toString('utf-8')) as { type?: string };
        if (parsed.type === 'event') {
          const frame = EventFrameSchema.parse(parsed);
          const result = processCueEvent(session, bridge, frame.event, frame.data);
          if (result.outcome === 'skipped') {
            sendJson({ type: 'state', state: 'cue_skipped', event: frame.event, reason: result.reason });
          }
        } else if (parsed.type === 'close') {
          teardown(sessionId, session, bridge);
          ws.close(1000, 'client_close');
        }
      } catch (err) {
        logger.warn('live.ws.message_failed', { sessionId, err: String(err) });
      }
    };

    try {
      await bridge.open();
    } catch (err) {
      logger.error('live.ws.bridge_open_failed', { sessionId, err: String(err) });
      sendJson({ type: 'error', code: 'gemini_unavailable' });
      ws.close(1011, 'gemini_open_failed');
      bridges.delete(sessionId);
      return;
    }

    // Pipeline pronta: drena os frames que chegaram durante os awaits
    // (tipicamente o 'start') e passa a processar direto. A CueQueue +
    // gate de preamble cuidam da serialização dali em diante.
    onFrame = handleFrame;
    for (const f of preReady.splice(0)) {
      logger.info('live.ws.frame_buffered_pre_open', { sessionId });
      handleFrame(f.data, f.isBinary);
    }

    ws.on('close', () => {
      logger.info('live.ws.client_disconnected', { sessionId, uid });
      teardown(sessionId, session, bridge);
    });

    ws.on('error', (err) => {
      logger.warn('live.ws.client_error', { sessionId, err: String(err) });
      teardown(sessionId, session, bridge);
    });
  });
}

function teardown(sessionId: string, session: CueSession, bridge: GeminiBridge): void {
  if (bridges.get(sessionId) === bridge) {
    bridges.delete(sessionId);
    bridge.dispose();
  }
  session.touch();
}
