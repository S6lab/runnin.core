import { z } from 'zod';

/**
 * Blob de contexto agnóstico que o caller (runnin-api ou qualquer app
 * futuro) envia ao criar uma sessão Live. s6-ai NÃO lê o schema do app —
 * profileSnippet/sessionBriefing chegam pré-formatados; segments/weather
 * são estruturados porque o instruction-builder os formata e trunca.
 */
export const SegmentBriefSchema = z.object({
  kmStart: z.number().nonnegative(),
  kmEnd: z.number().positive(),
  phase: z.string().min(1),
  targetPace: z.string().nullish(),
  instruction: z.string().nullish(),
});

export const WeatherBlockSchema = z.object({
  temperatureC: z.number().nullish(),
  humidityPercent: z.number().nullish(),
  windKmh: z.number().nullish(),
});

export const LiveSessionContextSchema = z.object({
  /** uid do dono — atribuição de llm_usage + checagem no WS handshake. */
  userId: z.string().min(1),
  /** Persona do coach (id resolvido via config-store de personas). */
  persona: z.string().nullish(),
  voice: z.string().default('Charon'),
  locale: z.string().default('pt-BR'),
  /** "nome Edu, nível iniciante, objetivo \"5km\", 3x/semana" */
  profileSnippet: z.string().default('sem perfil completo'),
  /** "SESSÃO DE HOJE: Tiros · 6km · pace alvo 5:30" ou corrida livre. */
  sessionBriefing: z.string().default(''),
  /** Foco/notes da sessão — primeira coisa truncada junto do weather. */
  sessionNotes: z.string().nullish(),
  segments: z.array(SegmentBriefSchema).max(30).default([]),
  weather: WeatherBlockSchema.nullish(),
  prefs: z
    .object({
      freq: z.enum(['high', 'normal', 'per_2km', 'alerts_only', 'silent']).default('normal'),
      dnd: z.boolean().default(false),
      allowCriticalAlertsInSilent: z.boolean().default(true),
    })
    .default({ freq: 'normal', dnd: false, allowCriticalAlertsInSilent: true }),
  /** Nome curto do atleta pra vocativos nos templates. */
  athleteName: z.string().nullish(),
});

export type LiveSessionContext = z.infer<typeof LiveSessionContextSchema>;

export type SessionMode = 'planned' | 'free';

/** Doc persistido em `live_sessions/{id}` (coleção interna do s6-ai). */
export interface LiveSessionDoc {
  id: string;
  context: LiveSessionContext;
  mode: SessionMode;
  createdAt: string;
  expiresAt: string;
  /** Estado quente persistido pós-cue: sem ele, a rehidratação (restart/
   *  reconexão de instância) zerava o dedup e cues repetiam (3.5km em
   *  dobro no smoke 2026-06-11). */
  queueSnapshot?: {
    firedOnce: string[];
    lastKmBucket: number;
    lastHalfKmBucket: number;
  };
  cueCount?: number;
}
