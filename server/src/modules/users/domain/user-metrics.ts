/**
 * Coerção canônica de métricas do perfil. `weight` é persistido como
 * string livre do onboarding ("72kg", "72,5", 72) — todo consumidor
 * numérico passa por aqui em vez de reimplementar regex/typeof local
 * (3 cópias divergentes existiam, duas com `typeof === 'number'` que
 * nunca disparava num campo tipado string).
 */
export function parseWeightKg(raw: string | number | null | undefined): number | null {
  if (typeof raw === 'number') {
    return Number.isFinite(raw) && raw > 0 && raw < 400 ? raw : null;
  }
  if (!raw) return null;
  const n = Number(raw.replace(',', '.').replace(/[^0-9.]/g, ''));
  if (!Number.isFinite(n) || n <= 0 || n >= 400) return null;
  return n;
}
