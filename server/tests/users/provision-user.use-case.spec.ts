import { describe, it, expect, vi, beforeEach } from 'vitest';
import { ProvisionUserUseCase } from '@modules/users/domain/use-cases/provision-user.use-case';
import { UserProfile } from '@modules/users/domain/user.entity';
import { UserRepository } from '@modules/users/domain/user.repository';

// Mocks pro Firebase Auth admin SDK
vi.mock('@shared/infra/firebase/firebase.client', () => ({
  getAuth: () => ({
    getUser: vi.fn(async (uid: string) => ({
      uid,
      email: 'nalin@s6lab.com',
      phoneNumber: '+5511999999999',
      displayName: null,
      photoURL: null,
      providerData: [],
    })),
  }),
}));

vi.mock('@shared/logger/logger', () => ({
  logger: { info: vi.fn(), warn: vi.fn(), error: vi.fn() },
}));

class InMemoryUserRepo implements UserRepository {
  private store = new Map<string, UserProfile>();

  async findById(id: string): Promise<UserProfile | null> {
    return this.store.get(id) ?? null;
  }
  async upsert(profile: UserProfile): Promise<void> {
    this.store.set(profile.id, profile);
  }
  async updatePartial(id: string, patch: Partial<UserProfile>): Promise<void> {
    const existing = this.store.get(id);
    if (!existing) throw new Error('not found');
    this.store.set(id, { ...existing, ...patch, updatedAt: new Date().toISOString() });
  }
  async delete(_id: string): Promise<void> {
    throw new Error('not implemented in stub');
  }
  async archiveOnboarding(_id: string, _snapshot: UserProfile): Promise<void> {}
}

describe('ProvisionUserUseCase', () => {
  let repo: InMemoryUserRepo;
  let useCase: ProvisionUserUseCase;

  beforeEach(() => {
    repo = new InMemoryUserRepo();
    useCase = new ProvisionUserUseCase(repo);
  });

  it('cria novo user com authId/email/phone vindos do Firebase Auth', async () => {
    const profile = await useCase.execute('uid_new');

    expect(profile.id).toBe('uid_new');
    expect(profile.authId).toBe('uid_new');
    expect(profile.email).toBe('nalin@s6lab.com');
    expect(profile.phone).toBe('+5511999999999');
    expect(profile.onboarded).toBe(false);
    expect(profile.premium).toBe(false);
  });

  it('retorna existing sem mudar quando já tem authId/email', async () => {
    const existing: UserProfile = {
      id: 'uid_old',
      authId: 'uid_old',
      email: 'foo@bar.com',
      name: 'Old',
      level: 'iniciante',
      goal: '',
      frequency: 3,
      hasWearable: false,
      medicalConditions: [],
      premium: false,
      onboarded: false,
      createdAt: '2026-01-01T00:00:00.000Z',
      updatedAt: '2026-01-01T00:00:00.000Z',
    };
    await repo.upsert(existing);

    const got = await useCase.execute('uid_old');

    expect(got.email).toBe('foo@bar.com');
    expect(got.authId).toBe('uid_old');
  });

  it('backfilla user legado sem authId/email', async () => {
    const legacy = {
      id: 'uid_legacy',
      name: 'Legacy',
      level: 'iniciante',
      goal: '',
      frequency: 3,
      hasWearable: false,
      medicalConditions: [],
      premium: false,
      onboarded: false,
      createdAt: '2026-01-01T00:00:00.000Z',
      updatedAt: '2026-01-01T00:00:00.000Z',
    } as unknown as UserProfile; // bypass strict pra simular legacy doc
    await repo.upsert(legacy);

    const got = await useCase.execute('uid_legacy');

    expect(got.authId).toBe('uid_legacy');
    expect(got.email).toBe('nalin@s6lab.com');
    expect(got.phone).toBe('+5511999999999');
  });
});
