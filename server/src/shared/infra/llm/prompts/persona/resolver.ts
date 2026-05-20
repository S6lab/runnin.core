import { getPersonaDescription } from '../config-store';
import { CoachPersonaId, DEFAULT_PERSONA_ID } from './defaults';

export async function resolvePersonaTone(id: string | undefined | null): Promise<string> {
  return getPersonaDescription(id ?? DEFAULT_PERSONA_ID);
}

export function normalizePersonaId(id: string | undefined | null): CoachPersonaId {
  if (id === 'motivador' || id === 'tecnico') return id;
  // 'sereno' legado e qualquer outro → motivador (default).
  return DEFAULT_PERSONA_ID;
}
