import { describe, it, expect } from 'vitest';
import { renderTemplate } from '@shared/infra/llm/prompts/render';

describe('renderTemplate', () => {
  it('substitui chaves simples e aninhadas', () => {
    const out = renderTemplate('Olá {{profile.name}}, tom {{persona.tone}}.', {
      profile: { name: 'Edu' },
      persona: { tone: 'motivador' },
    });
    expect(out).toBe('Olá Edu, tom motivador.');
  });

  it('chave ausente vira string vazia', () => {
    expect(renderTemplate('a={{missing.key}}b', {})).toBe('a=b');
  });

  it('número e boolean viram string; objeto vira JSON', () => {
    const out = renderTemplate('{{n}}|{{b}}|{{o}}', { n: 5, b: true, o: { k: 1 } });
    expect(out).toBe('5|true|{"k":1}');
  });
});
