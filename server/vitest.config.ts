import { defineConfig } from 'vitest/config';
import { resolve } from 'path';

// Bootstrap inicial de testes. Os specs vivem em `tests/` (espelhando
// a estrutura de `src/`). Quando o projeto adotar testes em hot path,
// vale considerar mover `*.spec.ts` pra junto do código fonte — fica
// como evolução natural.
export default defineConfig({
  resolve: {
    alias: {
      '@shared': resolve(__dirname, 'src/shared'),
      '@modules': resolve(__dirname, 'src/modules'),
    },
  },
  test: {
    include: ['tests/**/*.spec.ts', 'src/**/*.spec.ts'],
    environment: 'node',
    globals: false,
    silent: false,
  },
});
