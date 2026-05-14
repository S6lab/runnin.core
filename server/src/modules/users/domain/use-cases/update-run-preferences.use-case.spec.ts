import { UpdateRunPreferencesUseCase, RunAlertPreferencesSchema } from './update-run-preferences.use-case';
import { UserRepository } from '../user.repository';
import { UserProfile, RunAlertPreferences } from '../user.entity';

jest.mock('../user.repository');

const mockUserRepo = {
  findById: jest.fn(),
  upsert: jest.fn(),
};

describe('UpdateRunPreferencesUseCase', () => {
  let useCase: UpdateRunPreferencesUseCase;
  let mockUserProfile: UserProfile;

  const defaultRunAlertPreferences: RunAlertPreferences = {
    paceAlertsEnabled: true,
    paceAlertFrequency: 'every_km',
    hrZoneAlertsEnabled: true,
    distanceMilestonesEnabled: true,
    distanceMilestones: [5.0, 10.0],
    timeMilestonesEnabled: false,
    timeMilestones: [],
  };

  beforeEach(() => {
    jest.clearAllMocks();
    useCase = new UpdateRunPreferencesUseCase(mockUserRepo as any);

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
      hasCompletedFirstRun: false,
      createdAt: '2025-01-01T00:00:00Z',
      updatedAt: '2025-01-01T00:00:00Z',
    };
  });

  it('should create preferences when none exist and validate input', async () => {
    const input = {
      paceAlertsEnabled: false,
      distanceMilestones: [5.0, 10.0, 21.1],
    };
    mockUserRepo.findById.mockResolvedValue(mockUserProfile);
    mockUserRepo.upsert.mockImplementation((profile: UserProfile) => Promise.resolve());

    const result = await useCase.execute('user-123', input);

    expect(result.runAlertPreferences).toBeDefined();
    expect(result.runAlertPreferences?.paceAlertsEnabled).toBe(false);
    expect(result.runAlertPreferences?.distanceMilestones).toEqual([5.0, 10.0, 21.1]);
    expect(mockUserRepo.upsert).toHaveBeenCalled();
  });

  it('should update existing preferences', async () => {
    const existingPreferences: RunAlertPreferences = {
      ...defaultRunAlertPreferences,
      paceAlertsEnabled: false,
    };
    mockUserProfile.runAlertPreferences = existingPreferences;
    mockUserRepo.findById.mockResolvedValue(mockUserProfile);
    mockUserRepo.upsert.mockImplementation((profile: UserProfile) => Promise.resolve());

    const input = {
      paceAlertsEnabled: true,
    };
    const result = await useCase.execute('user-123', input);

    expect(result.runAlertPreferences?.paceAlertsEnabled).toBe(true);
    expect(result.runAlertPreferences?.distanceMilestones).toEqual([5.0, 10.0]);
  });

  it('should throw validation error when distance milestones exceed maximum', async () => {
    const manyDistances = Array(11).fill(5.0);
    const input = {
      distanceMilestones: manyDistances,
    };

    await expect(useCase.execute('user-123', input)).rejects.toThrow(/Maximum \d+ distance milestones/);
  });

  it('should throw validation error when time milestones exceed maximum', async () => {
    const manyTimes = Array(11).fill(300);
    const input = {
      timeMilestones: manyTimes,
    };

    await expect(useCase.execute('user-123', input)).rejects.toThrow(/Maximum \d+ time milestones/);
  });

  it('should throw validation error for non-positive distance values', async () => {
    const input = {
      distanceMilestones: [5.0, -1, 10.0],
    };

    await expect(useCase.execute('user-123', input)).rejects.toThrow();
  });

  it('should throw error when user not found', async () => {
    mockUserRepo.findById.mockResolvedValue(null);

    await expect(useCase.execute('non-existent-user', {})).rejects.toThrow('User not found');
  });

  it('should allow incomplete updates', async () => {
    mockUserProfile.runAlertPreferences = { ...defaultRunAlertPreferences };
    mockUserRepo.findById.mockResolvedValue(mockUserProfile);
    mockUserRepo.upsert.mockImplementation((profile: UserProfile) => Promise.resolve());

    const input = {
      hrZoneAlertsEnabled: false,
    };
    const result = await useCase.execute('user-123', input);

    expect(result.runAlertPreferences?.paceAlertsEnabled).toBe(true);
    expect(result.runAlertPreferences?.hrZoneAlertsEnabled).toBe(false);
  });
});
