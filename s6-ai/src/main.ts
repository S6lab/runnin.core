import 'dotenv/config';
import { createServer as createHttpServer } from 'http';
import { getFirebaseApp } from '@shared/infra/firebase/firebase.client';
import { createServer } from './server';
import { attachLiveWebSocket } from '@modules/live/live.ws';
import { cueSessionStore } from '@modules/live/cue-session.store';
import { logger } from '@shared/logger/logger';

const PORT = Number(process.env.PORT ?? 8080);

// Rastro estruturado pra crashes de processo (espelho do runnin-api):
// unhandled em sessão WS/Gemini derrubava o container sem log indexável.
process.on('unhandledRejection', (reason) => {
  logger.error('process.unhandled_rejection', {
    reason: reason instanceof Error ? reason.message : String(reason),
    stack: reason instanceof Error ? reason.stack : undefined,
  });
});
process.on('uncaughtException', (err) => {
  logger.error('process.uncaught_exception', {
    err: err.message,
    stack: err.stack,
  });
  process.exit(1);
});

// Inicializa Firebase antes de subir o servidor (verificação de ID tokens +
// Firestore do serviço: app_config/prompts, llm_usage, live_sessions).
getFirebaseApp();

const app = createServer();
const httpServer = createHttpServer(app);

attachLiveWebSocket(httpServer);
cueSessionStore.startSweeper();

httpServer.listen(PORT, () => {
  logger.info('s6ai.started', { port: PORT, env: process.env.NODE_ENV ?? 'development' });
});
