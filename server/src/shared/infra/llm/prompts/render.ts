/**
 * Render template substituindo `{{key.subkey}}` por valores do dict.
 * Suporta nested via dot-notation. Valor não encontrado vira string vazia.
 */
export function renderTemplate(template: string, values: Record<string, unknown>): string {
  return template.replace(/\{\{\s*([\w.]+)\s*\}\}/g, (_, path: string) => {
    const parts = path.split('.');
    let cur: unknown = values;
    for (const p of parts) {
      if (cur && typeof cur === 'object' && p in (cur as Record<string, unknown>)) {
        cur = (cur as Record<string, unknown>)[p];
      } else {
        return '';
      }
    }
    if (cur === null || cur === undefined) return '';
    if (typeof cur === 'string') return cur;
    if (typeof cur === 'number' || typeof cur === 'boolean') return String(cur);
    return JSON.stringify(cur);
  });
}
