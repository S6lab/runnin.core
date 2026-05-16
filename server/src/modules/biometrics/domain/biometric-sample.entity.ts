/**
 * Sample biométrico individual (1 leitura). Origina de Apple HealthKit,
 * Google Health Connect, wearable OAuth ou input manual.
 */
export type BiometricSampleType =
  | 'bpm'              // batimentos cardíacos (instantâneo)
  | 'resting_bpm'      // BPM em repouso (média do dia)
  | 'max_bpm'          // BPM máximo (medido ou estimado)
  | 'hrv'              // heart rate variability (ms, RMSSD ou SDNN)
  | 'sleep_hours'      // horas de sono na noite
  | 'sleep_deep'       // horas em sono profundo
  | 'steps'            // passos no período
  | 'spo2'             // saturação de oxigênio (%)
  | 'weight'           // peso (kg)
  | 'calories_burned'  // kcal queimadas
  | 'vo2max'           // VO2 max estimado
  | 'respiratory_rate';

export type BiometricSource =
  | 'apple_health'
  | 'health_connect'    // Google Health Connect (Android)
  | 'garmin'
  | 'polar'
  | 'fitbit'
  | 'whoop'
  | 'manual'            // input manual no app
  | 'terra'             // aggregator opcional (fase 2)
  | 'seed';             // dados de teste/seed

export interface BiometricSample {
  id: string;                  // uuid
  userId: string;
  type: BiometricSampleType;
  value: number;
  unit: string;                // 'bpm' | 'hours' | 'count' | 'ms' | '%' | 'kg' | 'kcal'
  source: BiometricSource;
  recordedAt: string;          // ISO — quando o sample aconteceu
  receivedAt: string;          // ISO — quando o server registrou
  context?: Record<string, unknown>; // opcional (ex: sleep stages)
}
