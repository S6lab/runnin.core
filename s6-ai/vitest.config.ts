import { defineConfig } from 'vitest/config';
import { resolve } from 'path';

export default defineConfig({
  resolve: {
    alias: {
      '@shared': resolve(__dirname, 'src/shared'),
      '@modules': resolve(__dirname, 'src/modules'),
    },
  },
  test: {
    include: ['tests/**/*.spec.ts', 'src/**/*.spec.ts'],
    setupFiles: ['tests/setup.ts'],
    environment: 'node',
    globals: false,
    coverage: {
      provider: 'v8',
      reporter: ['text', 'lcov'],
      include: ['src/modules/**/*.ts'],
      exclude: ['**/*.spec.ts', '**/*.d.ts', 'src/modules/**/http/**'],
    },
  },
});
