import 'dotenv/config';
import { createServer as createHttpServer } from 'http';
import { getFirebaseApp } from '@shared/infra/firebase/firebase.client';
import { createServer } from './server';
import { attachCoachLiveWebSocket } from '@modules/coach/http/coach-live.ws';
import { attachS6LiveWsProxy } from '@shared/infra/s6ai/s6-proxy';
import { logger } from '@shared/logger/logger';

const PORT = Number(process.env.PORT ?? 3000);

// Inicializa Firebase antes de subir o servidor
getFirebaseApp();

const app = createServer();
const httpServer = createHttpServer(app);

// WebSocket pra Coach Live (chat avulso — proxy pro Gemini Live API)
attachCoachLiveWebSocket(httpServer);
// Túnel WS /v1/live ↔ s6-ai (staging sem allUsers — vide s6-proxy.ts)
attachS6LiveWsProxy(httpServer);

httpServer.listen(PORT, () => {
  logger.info('server.started', { port: PORT, env: process.env.NODE_ENV ?? 'development' });
});
