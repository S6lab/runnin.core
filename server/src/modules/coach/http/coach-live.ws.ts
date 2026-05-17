import { IncomingMessage, Server as HttpServer } from 'http';
import { randomUUID } from 'crypto';
import { WebSocketServer, WebSocket, RawData } from 'ws';
import { getAuth } from '@shared/infra/firebase/firebase.client';
import { GeminiLiveSession } from '@shared/infra/llm/gemini-live.service';
import { CoachRuntimeContextService } from '@modules/coach/use-cases/coach-runtime-context.service';
import { resolvePersonaTone } from '@shared/infra/llm/prompts';
import { FirestoreCoachMessageLogRepository } from '@modules/coach/infra/firestore-coach-message-log.repository';
import { CoachMessageLog } from '@modules/coach/domain/coach-message-log.entity';
import { logger } from '@shared/logger/logger';

/**
 * Proxy WebSocket: cliente Flutter <-> nosso server <-> Gemini Live.
 *
 * Cliente conecta em: ws://api/v1/coach/live?token=<firebase-id-token>
 * - Mensagens cliente→server: { type: 'audio', mimeType, data } | { type: 'text', text } | { type: 'close' }
 * - Mensagens server→cliente: passthrough do serverContent do Gemini Live
 *
 * Mantém GEMINI_API_KEY segura no server.
 */
export function attachCoachLiveWebSocket(httpServer: HttpServer): void {
  const wss = new WebSocketServer({ noServer: true });

  httpServer.on('upgrade', (req: IncomingMessage, socket, head) => {
    const url = new URL(req.url ?? '/', `http://${req.headers.host}`);
    logger.info('coach.live.upgrade_received', { url: url.pathname, host: req.headers.host });
    if (url.pathname !== '/coach-live' && url.pathname !== '/v1/coach/live') {
      return;
    }

    const token = url.searchParams.get('token');
    if (!token) {
      socket.write('HTTP/1.1 401 Unauthorized\r\n\r\n');
      socket.destroy();
      return;
    }
    // runId é opcional: quando presente, persistimos a conversa em
    // users/{uid}/runs/{runId}/coach_messages pra replay no histórico.
    const runId = url.searchParams.get('runId') ?? undefined;

    getAuth().verifyIdToken(token).then((decoded) => {
      wss.handleUpgrade(req, socket, head, (ws) => {
        wss.emit('connection', ws, req, decoded.uid, runId);
      });
    }).catch((err) => {
      logger.warn('coach.live.auth_failed', { err: String(err) });
      socket.write('HTTP/1.1 401 Unauthorized\r\n\r\n');
      socket.destroy();
    });
  });

  const messageLog = new FirestoreCoachMessageLogRepository();

  wss.on('connection', async (clientWs: WebSocket, _req: IncomingMessage, uid: string, runId?: string) => {
    logger.info('coach.live.client_connected', { uid, runId: runId ?? null });
    let coachTextBuffer = '';
    const persistLog = async (
      author: 'user' | 'coach',
      text: string,
    ) => {
      if (!runId || !text.trim()) return;
      const log: CoachMessageLog = {
        id: randomUUID(),
        runId,
        userId: uid,
        author,
        text: text.trim(),
        promptVersion: 'live-coach.v1',
        promptSource: 'default',
        createdAt: new Date().toISOString(),
      };
      try {
        await messageLog.save(log);
      } catch (err) {
        logger.warn('coach.live.persist_failed', { uid, runId, err: String(err) });
      }
    };
    const runtimeService = new CoachRuntimeContextService();
    const runtime = await runtimeService.getContext(uid);
    const tone = await resolvePersonaTone(runtime.profile?.coachPersonality);

    // SystemInstruction curto. Antes mandávamos JSON.stringify do profile
    // E plano completo — fechava o WS com 1008 (safety filter ou tamanho
    // excedido). Agora só persona + snippet do perfil + próxima sessão.
    const p = runtime.profile;
    const profileSnippet = p
      ? [
          p.name ? `nome ${p.name}` : null,
          p.level ? `nível ${p.level}` : null,
          p.goal ? `objetivo "${p.goal}"` : null,
          p.frequency ? `${p.frequency}x/semana` : null,
        ].filter(Boolean).join(', ')
      : 'sem perfil completo';
    const planSnippet = runtime.currentPlan
      ? `Plano em andamento (${runtime.currentPlan.weeksCount} semanas, ${runtime.currentPlan.goal}).`
      : 'Sem plano ativo.';

    const systemInstruction = [
      'Você é o Coach.AI do runnin em conversa por voz com o atleta. PT-BR.',
      `Persona: ${tone}`,
      `Atleta: ${profileSnippet}.`,
      planSnippet,
      'Respostas curtas (1-3 frases, 10-20s de áudio). Tom direto e prático.',
    ].join('\n\n');

    const session = new GeminiLiveSession({
      config: {
        systemInstruction,
        responseModalities: ['AUDIO'],
        voice: 'Charon', // Voz padrão masculina; Aoede feminina, etc
      },
      onMessage: (msg) => {
        if (clientWs.readyState === WebSocket.OPEN) {
          clientWs.send(JSON.stringify(msg));
        }
        // Acumula texto do coach durante o turn; salva quando turnComplete.
        if (runId) {
          try {
            const sc = (msg as { serverContent?: { modelTurn?: { parts?: Array<{ text?: string }> }; turnComplete?: boolean } }).serverContent;
            const parts = sc?.modelTurn?.parts;
            if (parts) {
              for (const p of parts) {
                if (typeof p.text === 'string') coachTextBuffer += p.text;
              }
            }
            if (sc?.turnComplete && coachTextBuffer.trim()) {
              const toSave = coachTextBuffer;
              coachTextBuffer = '';
              void persistLog('coach', toSave);
            }
          } catch (_) {/* ignore parse */}
        }
      },
      onClose: (code, reason) => {
        logger.info('coach.live.gemini_closed', { uid, code, reason });
        if (clientWs.readyState === WebSocket.OPEN) clientWs.close(1000, 'gemini_closed');
      },
    });

    try {
      await session.open();
      clientWs.send(JSON.stringify({ kind: 'ready' }));
    } catch (err) {
      logger.error('coach.live.gemini_open_failed', { uid, err: String(err) });
      clientWs.send(JSON.stringify({ kind: 'error', message: 'Gemini Live indisponível' }));
      clientWs.close(1011, 'gemini_open_failed');
      return;
    }

    clientWs.on('message', (data: RawData) => {
      try {
        const msg = JSON.parse(data.toString('utf-8')) as {
          type?: string;
          mimeType?: string;
          data?: string;
          text?: string;
        };
        if (msg.type === 'audio' && msg.data) {
          session.sendAudio(msg.data, msg.mimeType ?? 'audio/pcm;rate=16000');
        } else if (msg.type === 'text' && msg.text) {
          session.sendText(msg.text);
          void persistLog('user', msg.text);
        } else if (msg.type === 'close') {
          session.close();
          clientWs.close(1000, 'client_close');
        }
      } catch (err) {
        logger.warn('coach.live.client_message_parse_failed', { err: String(err) });
      }
    });

    clientWs.on('close', () => {
      logger.info('coach.live.client_disconnected', { uid });
      session.close();
    });

    clientWs.on('error', (err) => {
      logger.warn('coach.live.client_ws_error', { uid, err: String(err) });
      session.close();
    });
  });
}
