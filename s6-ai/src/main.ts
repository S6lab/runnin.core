import 'dotenv/config';
import { createServer as createHttpServer } from 'http';
import { getFirebaseApp } from '@shared/infra/firebase/firebase.client';
import { createServer } from './server';
import { attachLiveWebSocket } from '@modules/live/live.ws';
import { cueSessionStore } from '@modules/live/cue-session.store';
import { logger } from '@shared/logger/logger';

const PORT = Number(process.env.PORT ?? 8080);

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
