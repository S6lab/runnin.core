import { vi } from 'vitest';

// Sem credenciais no ambiente de teste, getFirestore().get() PENDURA
// (metadata server timeout) em vez de falhar — estourava o timeout de 5s
// dos specs. Mock que lança síncrono faz config-store/RAG caírem nos
// defaults imediatamente (os try/catch de produção cobrem).
vi.mock('@shared/infra/firebase/firebase.client', () => {
  const boom = (): never => {
    throw new Error('firebase mocked out in s6-ai tests');
  };
  return {
    getFirebaseApp: boom,
    getFirestore: boom,
    getAuth: boom,
    getStorageBucket: boom,
    getMessaging: boom,
  };
});
