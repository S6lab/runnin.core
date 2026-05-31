import 'dotenv/config';
import { createServer as createHttpServer } from 'http';
import { getFirebaseApp } from '@shared/infra/firebase/firebase.client';
import { createServer } from './server';
import { attachCoachLiveWebSocket } from '@modules/coach/http/coach-live.ws';
import { logger } from '@shared/logger/logger';

const PORT = Number(process.env.PORT ?? 3000);

// Inicializa Firebase antes de subir o servidor
getFirebaseApp();

const app = createServer();
const httpServer = createHttpServer(app);

// WebSocket pra Coach Live (proxy pro Gemini Live API)
attachCoachLiveWebSocket(httpServer);

httpServer.listen(PORT, () => {
  logger.info('server.started', { port: PORT, env: process.env.NODE_ENV ?? 'development' });
});
