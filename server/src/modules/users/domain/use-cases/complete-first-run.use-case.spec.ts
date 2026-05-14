import { CompleteFirstRunUseCase } from './complete-first-run.use-case';
import { UserRepository } from '../user.repository';

jest.mock('../user.repository');

const mockUserRepo = {
  findById: jest.fn(),
  upsert: jest.fn(),
};

describe('CompleteFirstRunUseCase', () => {
  let useCase: CompleteFirstRunUseCase;
  const userId = 'user-123';

  beforeEach(() => {
    jest.clearAllMocks();
    useCase = new CompleteFirstRunUseCase(mockUserRepo as any);
  });

  const defaultUserProfile = {
    id: userId,
    name: 'Test Runner',
    level: 'intermediario' as const,
    goal: 'Correr 10k',
    frequency: 3,
    hasWearable: false,
    medicalConditions: [],
    premium: false,
    onboarded: true,
    hasCompletedFirstRun: false,
    createdAt: '2025-01-01T00:00:00Z',
    updatedAt: '2025-01-01T00:00:00Z',
  };

  it('should set hasCompletedFirstRun to true when user exists', async () => {
    mockUserRepo.findById.mockResolvedValue(defaultUserProfile);
    mockUserRepo.upsert.mockResolvedValue(undefined);

    const result = await useCase.execute(userId);

    expect(result).toEqual({ hasCompletedFirstRun: true });
    expect(mockUserRepo.upsert).toHaveBeenCalledWith(expect.objectContaining({
      hasCompletedFirstRun: true,
    }));
  });

  it('should update the updatedAt timestamp', async () => {
    const originalTimestamp = defaultUserProfile.updatedAt;
    mockUserRepo.findById.mockResolvedValue({ ...defaultUserProfile, updatedAt: originalTimestamp });

    await useCase.execute(userId);

    const calledProfile = (mockUserRepo.upsert as jest.Mock).mock.calls[0][0];
    expect(calledProfile.updatedAt).not.toEqual(originalTimestamp);
  });

  it('should throw error when user not found', async () => {
    mockUserRepo.findById.mockResolvedValue(null);

    await expect(useCase.execute('non-existent-user')).rejects.toThrow('User not found');
  });

  it('should be idempotent - calling twice is safe', async () => {
    const userWithFlagAlreadySet = { ...defaultUserProfile, hasCompletedFirstRun: true };
    mockUserRepo.findById.mockResolvedValueOnce(defaultUserProfile);
    mockUserRepo.findById.mockResolvedValueOnce(userWithFlagAlreadySet);
    mockUserRepo.upsert.mockResolvedValue(undefined);

    await useCase.execute(userId);
    const result = await useCase.execute(userId);

    expect(result).toEqual({ hasCompletedFirstRun: true });
  });
});
