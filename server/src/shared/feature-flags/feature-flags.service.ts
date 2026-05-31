import { getFirestore } from '@shared/infra/firebase/firebase.client';

/**
 * Feature flags globais (kill switches independentes do plano).
 *
 * Diferente de PlanFeatures (que é por usuário/plano), feature flags são
 * globais — ex: "desativa coachLive porque Gemini Live tá com bug" mesmo
 * pra usuários Pro.
 *
 * Lidos de Firestore `app_config/feature_flags`. Cache 60s.
 *
 * Pra usar:
 *   if (await featureFlags.isEnabled('coachLiveEnabled')) { ... }
 *
 * Uso recomendado: combinar com PlanFeatures
 *   const allowed = planFeatures.coachLive && await flags.isEnabled('coachLiveEnabled');
 */

export type FeatureFlagId =
  | 'coachLiveEnabled'    // Gemini Live (WebSocket)
  | 'examsOcrEnabled'     // OCR Gemini multimodal
  | 'planGenerationEnabled' // Geração de plano AI
  | 'wearableSyncEnabled' // OAuth Garmin/Polar/etc
  | 'newOnboardingFlow';  // canary release

const DEFAULTS: Record<FeatureFlagId, boolean> = {
  coachLiveEnabled: true,
  examsOcrEnabled: true,
  planGenerationEnabled: true,
  wearableSyncEnabled: false,
  newOnboardingFlow: false,
};

const CACHE_TTL_MS = 60_000;

class FeatureFlagsService {
  private cache: { flags: Record<string, boolean>; expiresAt: number } | null = null;

  async isEnabled(flag: FeatureFlagId): Promise<boolean> {
    const flags = await this.load();
    return flags[flag] ?? DEFAULTS[flag] ?? false;
  }

  async getAll(): Promise<Record<FeatureFlagId, boolean>> {
    const flags = await this.load();
    return { ...DEFAULTS, ...flags } as Record<FeatureFlagId, boolean>;
  }

  private async load(): Promise<Record<string, boolean>> {
    if (this.cache && this.cache.expiresAt > Date.now()) return this.cache.flags;
    try {
      const doc = await getFirestore().collection('app_config').doc('feature_flags').get();
      const flags = (doc.data() as Record<string, boolean>) ?? {};
      this.cache = { flags, expiresAt: Date.now() + CACHE_TTL_MS };
      return flags;
    } catch {
      return DEFAULTS;
    }
  }

  invalidate(): void {
    this.cache = null;
  }
}

export const featureFlags = new FeatureFlagsService();
