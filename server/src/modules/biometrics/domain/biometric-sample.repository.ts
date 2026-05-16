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
  deleteByUser(userId: string): Promise<number>;
}
