import { GetRunPreferencesUseCase } from './get-run-preferences.use-case';
import { UserRepository } from '../user.repository';
import { UserProfile, RunAlertPreferences } from '../user.entity';

jest.mock('../user.repository');

const mockUserRepo = {
  findById: jest.fn(),
};

describe('GetRunPreferencesUseCase', () => {
  let useCase: GetRunPreferencesUseCase;
  let mockUserProfile: UserProfile;

  beforeEach(() => {
    jest.clearAllMocks();
    useCase = new GetRunPreferencesUseCase(mockUserRepo as any);

    mockUserProfile = {
      id: 'user-123',
      name: 'Test Runner',
      level: 'intermediario' as const,
      goal: 'Correr 10k',
      frequency: 3,
     hasWearable: false,
      medicalConditions: [],
      premium: false,
      onboarded: true,
      createdAt: '2025-01-01T00:00:00Z',
      updatedAt: '2025-01-01T00:00:00Z',
    };
  });

  const defaultRunAlertPreferences: RunAlertPreferences = {
    paceAlertsEnabled: true,
    paceAlertFrequency: 'every_km',
    hrZoneAlertsEnabled: true,
    distanceMilestonesEnabled: true,
    distanceMilestones: [5.0, 10.0],
    timeMilestonesEnabled: false,
    timeMilestones: [],
  };

  it('should return default preferences when user has no preferences set', async () => {
    mockUserRepo.findById.mockResolvedValue(mockUserProfile);

    const result = await useCase.execute('user-123');

    expect(result).toEqual(defaultRunAlertPreferences);
  });

  it('should return custom preferences when user has them set', async () => {
    const customPreferences: RunAlertPreferences = {
      ...defaultRunAlertPreferences,
      paceAlertsEnabled: false,
      distanceMilestones: [5.0],
    };
    mockUserProfile.runAlertPreferences = customPreferences;
    mockUserRepo.findById.mockResolvedValue(mockUserProfile);

    const result = await useCase.execute('user-123');

    expect(result).toEqual(customPreferences);
  });

  it('should throw error when user not found', async () => {
    mockUserRepo.findById.mockResolvedValue(null);

    await expect(useCase.execute('non-existent-user')).rejects.toThrow('User not found');
  });
});
