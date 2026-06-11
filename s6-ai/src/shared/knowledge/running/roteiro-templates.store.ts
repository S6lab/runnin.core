import { getFirestore } from '@shared/infra/firebase/firebase.client';
import { logger } from '@shared/logger/logger';
import roteiroTemplatesJson from './roteiro-templates.json';

/** Uma fase do roteiro tem N opções de instrução (o builder alterna entre elas). */
export type RoteiroTemplateEntry = { label?: string; phases?: Record<string, string[]> };
export type RoteiroTemplates = Record<string, RoteiroTemplateEntry>;

const CACHE_TTL_MS = 60_000;
const DOC_PATH = { col: 'app_config', doc: 'roteiro_templates' };

// Default versionado (Dossiê 4). `_doc` é só nota — removido do default exposto.
function buildDefault(): RoteiroTemplates {
  const raw = roteiroTemplatesJson as unknown as Record<string, unknown>;
  const out: RoteiroTemplates = {};
  for (const [k, v] of Object.entries(raw)) {
    if (k === '_doc') continue;
    out[k] = v as RoteiroTemplateEntry;
  }
  return out;
}

const DEFAULT_TEMPLATES: RoteiroTemplates = buildDefault();

let cached: { templates: RoteiroTemplates; loadedAt: number } | null = null;

/** Templates default (do JSON versionado) — usado pelo admin como base. */
export function getRoteiroTemplatesDefault(): RoteiroTemplates {
  return DEFAULT_TEMPLATES;
}

/**
 * Templates efetivos: override do Firestore (app_config/roteiro_templates)
 * mesclado POR TIPO sobre o default. Cache 60s. Editável no admin sem deploy.
 */
export async function getRoteiroTemplates(): Promise<RoteiroTemplates> {
  const now = Date.now();
  if (cached && now - cached.loadedAt < CACHE_TTL_MS) return cached.templates;
  try {
    const snap = await getFirestore().collection(DOC_PATH.col).doc(DOC_PATH.doc).get();
    const override = (snap.exists ? snap.data()?.['templates'] : null) as RoteiroTemplates | null;
    const templates = override && typeof override === 'object'
      ? { ...DEFAULT_TEMPLATES, ...override } // override substitui por TIPO
      : DEFAULT_TEMPLATES;
    cached = { templates, loadedAt: now };
    return templates;
  } catch (err) {
    logger.warn('roteiro_templates.load_failed', {
      err: err instanceof Error ? err.message : String(err),
    });
    return cached?.templates ?? DEFAULT_TEMPLATES;
  }
}

export function invalidateRoteiroTemplatesCache(): void {
  cached = null;
}
