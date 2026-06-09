import { describe, it, expect, vi, beforeEach } from 'vitest';
import { IngestSamplesUseCase } from '@modules/biometrics/use-cases/ingest-samples.use-case';
import { BiometricSample } from '@modules/biometrics/domain/biometric-sample.entity';
import { BiometricSampleRepository } from '@modules/biometrics/domain/biometric-sample.repository';
import { UserProfile } from '@modules/users/domain/user.entity';
import { UserRepository } from '@modules/users/domain/user.repository';

vi.mock('@shared/logger/logger', () => ({
  logger: { info: vi.fn(), warn: vi.fn(), error: vi.fn() },
}));

class InMemoryBiometricRepo implements BiometricSampleRepository {
  samples: BiometricSample[] = [];
  async saveBatch(samples: BiometricSample[]) {
    this.samples.push(...samples);
    return { saved: samples.length, duplicates: 0 };
  }
  async findLatestByType(_userId: string, _type: BiometricSample['type']) {
    return null;
  }
  async findByDateRange(
    _userId: string,
    _type: BiometricSample['type'] | undefined,
    _from: Date,
    _to: Date,
  ) {
    return [];
  }
  async findByDateRangeAndTypes(
    _userId: string,
    _types: BiometricSample['type'][],
    _from: Date,
    _to: Date,
  ) {
    return [];
  }
  async deleteByUser(_userId: string) {
    return 0;
  }
}

class InMemoryUserRepo implements UserRepository {
  patches: Array<{ id: string; patch: Partial<UserProfile> }> = [];
  async findById(_id: string) {
    return null;
  }
  async upsert(_p: UserProfile) {}
  async updatePartial(id: string, patch: Partial<UserProfile>) {
    this.patches.push({ id, patch });
  }
  async delete(_id: string) {}
  async archiveOnboarding(_id: string, _snap: UserProfile) {}
}

describe('IngestSamplesUseCase — promotion pro profile (Frente Bug 1 / 18526fa)', () => {
  let bioRepo: InMemoryBiometricRepo;
  let userRepo: InMemoryUserRepo;
  let useCase: IngestSamplesUseCase;

  beforeEach(() => {
    bioRepo = new InMemoryBiometricRepo();
    userRepo = new InMemoryUserRepo();
    useCase = new IngestSamplesUseCase(bioRepo, userRepo);
  });

  it('promove resting_bpm mais recente do batch pro profile', async () => {
    await useCase.execute('uid_1', {
      samples: [
        {
          type: 'resting_bpm',
          value: 50,
          unit: 'bpm',
          source: 'apple_health',
          recordedAt: '2026-06-01T00:00:00.000Z',
        },
        {
          type: 'resting_bpm',
          value: 52,
          unit: 'bpm',
          source: 'apple_health',
          recordedAt: '2026-06-02T00:00:00.000Z', // mais recente
        },
      ],
    });

    expect(userRepo.patches).toHaveLength(1);
    expect(userRepo.patches[0]?.patch.restingBpm).toBe(52);
  });

  it('promove max_bpm derivado do pico dos samples bpm (HealthKit não tem max nativo)', async () => {
    await useCase.execute('uid_1', {
      samples: [
        {
          type: 'bpm',
          value: 130, // recovery, dentro da janela mas baixo
          unit: 'bpm',
          source: 'apple_health',
          recordedAt: '2026-06-01T00:00:00.000Z',
        },
        {
          type: 'bpm',
          value: 188.4, // pico do treino → vira maxBpm
          unit: 'bpm',
          source: 'apple_health',
          recordedAt: '2026-06-01T00:30:00.000Z',
        },
        {
          type: 'bpm',
          value: 95, // easy, abaixo do floor 140 — não conta
          unit: 'bpm',
          source: 'apple_health',
          recordedAt: '2026-06-01T01:00:00.000Z',
        },
      ],
    });

    expect(userRepo.patches[0]?.patch.maxBpm).toBe(188);
  });

  it('não promove maxBpm se pico estiver abaixo de 140 (recovery/easy, não pico real)', async () => {
    await useCase.execute('uid_1', {
      samples: [
        {
          type: 'bpm',
          value: 120,
          unit: 'bpm',
          source: 'apple_health',
          recordedAt: '2026-06-01T00:00:00.000Z',
        },
      ],
    });

    expect(userRepo.patches).toHaveLength(0);
  });

  it('só atualiza maxBpm se for MAIOR que o atual (monotônico)', async () => {
    // Mock profile.maxBpm = 195 já existente. Sample novo com pico 170 não deve sobrescrever.
    userRepo.findById = async () => ({ maxBpm: 195 } as UserProfile);
    await useCase.execute('uid_1', {
      samples: [
        {
          type: 'bpm',
          value: 170,
          unit: 'bpm',
          source: 'apple_health',
          recordedAt: '2026-06-01T00:00:00.000Z',
        },
      ],
    });

    expect(userRepo.patches).toHaveLength(0);
  });

  it('não chama updatePartial quando não há nenhum bpm relevante no batch', async () => {
    await useCase.execute('uid_1', {
      samples: [
        {
          type: 'sleep_hours',
          value: 7.5,
          unit: 'hours',
          source: 'apple_health',
          recordedAt: '2026-06-01T00:00:00.000Z',
        },
      ],
    });

    expect(userRepo.patches).toHaveLength(0);
  });

  it('retorna received + saved', async () => {
    const r = await useCase.execute('uid_1', {
      samples: [
        {
          type: 'bpm',
          value: 72,
          unit: 'bpm',
          source: 'apple_health',
          recordedAt: '2026-06-01T00:00:00.000Z',
        },
      ],
    });
    expect(r.received).toBe(1);
    expect(r.saved).toBe(1);
  });
});
