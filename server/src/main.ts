import 'dotenv/config';
import { getFirebaseApp } from '@shared/infra/firebase/firebase.client';
import { createServer } from './server';
import { logger } from '@shared/logger/logger';

const PORT = Number(process.env.PORT ?? 3000);

// Inicializa Firebase antes de subir o servidor
getFirebaseApp();

const app = createServer();

app.listen(PORT, () => {
  logger.info('server.started', { port: PORT, env: process.env.NODE_ENV ?? 'development' });
});
