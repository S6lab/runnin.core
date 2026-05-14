import { GetHasCompletedFirstRunUseCase } from './get-has-completed-first-run.use-case';
import { UserRepository } from '../user.repository';

jest.mock('../user.repository');

const mockUserRepo = {
  findById: jest.fn(),
};

describe('GetHasCompletedFirstRunUseCase', () => {
  let useCase: GetHasCompletedFirstRunUseCase;
  const userId = 'user-123';

  beforeEach(() => {
    jest.clearAllMocks();
    useCase = new GetHasCompletedFirstRunUseCase(mockUserRepo as any);
  });

  it('should return hasCompletedFirstRun status for existing user', async () => {
    const mockUser = {
      id: userId,
      name: 'Test Runner',
      level: 'intermediario' as const,
      goal: 'Correr 10k',
      frequency: 3,
      hasWearable: false,
      medicalConditions: [],
      premium: false,
      onboarded: true,
      hasCompletedFirstRun: true,
      createdAt: '2025-01-01T00:00:00Z',
      updatedAt: '2025-01-01T00:00:00Z',
    };

    mockUserRepo.findById.mockResolvedValue(mockUser);

    const result = await useCase.execute(userId);

    expect(result).toEqual({ hasCompletedFirstRun: true });
  });

  it('should return false when user has not completed first run', async () => {
    const mockUser = {
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

    mockUserRepo.findById.mockResolvedValue(mockUser);

    const result = await useCase.execute(userId);

    expect(result).toEqual({ hasCompletedFirstRun: false });
  });

  it('should throw error when user not found', async () => {
    mockUserRepo.findById.mockResolvedValue(null);

    await expect(useCase.execute('non-existent-user')).rejects.toThrow('User not found');
  });
});
