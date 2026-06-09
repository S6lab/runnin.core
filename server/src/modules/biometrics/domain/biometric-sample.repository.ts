import { BiometricSample, BiometricSampleType } from './biometric-sample.entity';

export interface BiometricSampleRepository {
  saveBatch(samples: BiometricSample[]): Promise<{ saved: number; duplicates: number }>;
  findLatestByType(userId: string, type: BiometricSampleType): Promise<BiometricSample | null>;
  findByDateRange(
    userId: string,
    type: BiometricSampleType | undefined,
    from: Date,
    to: Date,
  ): Promise<BiometricSample[]>;
  /**
   * Variante específica pra agregados que só consomem alguns tipos (ex:
   * summary precisa de resting_bpm, sleep_*, steps, hrv, weight). Em vez
   * de carregar todos os ~260k samples de 30d (BPM live + novos tipos),
   * filtra server-side via `where('type', 'in', types)` — Firestore aceita
   * até 30 valores nessa clause. Reduz carga em ~99% pra summary.
   */
  findByDateRangeAndTypes(
    userId: string,
    types: BiometricSampleType[],
    from: Date,
    to: Date,
  ): Promise<BiometricSample[]>;
  deleteByUser(userId: string): Promise<number>;
}
