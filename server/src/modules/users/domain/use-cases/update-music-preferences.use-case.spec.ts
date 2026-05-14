import { UpdateMusicPreferencesUseCase, MusicPreferencesSchema } from './update-music-preferences.use-case';
import { UserRepository } from '../user.repository';
import { UserProfile, MusicPreferences } from '../user.entity';

jest.mock('../user.repository');

const mockUserRepo = {
  findById: jest.fn(),
  upsert: jest.fn(),
};

describe('UpdateMusicPreferencesUseCase', () => {
  let useCase: UpdateMusicPreferencesUseCase;
  let mockUserProfile: UserProfile;

  const defaultMusicPreferences: MusicPreferences = {
    serviceEnabled: false,
    lastService: 'device',
    lastVolume: 0.7,
  };

  beforeEach(() => {
    jest.clearAllMocks();
    useCase = new UpdateMusicPreferencesUseCase(mockUserRepo as any);

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

  it('should create preferences when none exist', async () => {
    const input = {
      serviceEnabled: true,
      lastService: 'spotify' as const,
      lastVolume: 0.8,
    };
    mockUserRepo.findById.mockResolvedValue(mockUserProfile);
    mockUserRepo.upsert.mockImplementation((profile: UserProfile) => Promise.resolve());

    const result = await useCase.execute('user-123', input);

    expect(result.musicPreferences).toBeDefined();
    expect(result.musicPreferences?.serviceEnabled).toBe(true);
    expect(result.musicPreferences?.lastService).toBe('spotify');
    expect(result.musicPreferences?.lastVolume).toBe(0.8);
    expect(mockUserRepo.upsert).toHaveBeenCalled();
  });

  it('should update existing preferences', async () => {
    const existingPreferences: MusicPreferences = {
      ...defaultMusicPreferences,
      serviceEnabled: false,
    };
    mockUserProfile.musicPreferences = existingPreferences;
    mockUserRepo.findById.mockResolvedValue(mockUserProfile);
    mockUserRepo.upsert.mockImplementation((profile: UserProfile) => Promise.resolve());

    const input = {
      lastVolume: 0.9,
    };
    const result = await useCase.execute('user-123', input);

    expect(result.musicPreferences?.lastVolume).toBe(0.9);
    expect(result.musicPreferences?.serviceEnabled).toBe(false);
  });

  it('should throw validation error for volume > 1', async () => {
    const input = {
      lastVolume: 1.5,
    };

    await expect(useCase.execute('user-123', input)).rejects.toThrow();
  });

  it('should throw validation error for volume < 0', async () => {
    const input = {
      lastVolume: -0.1,
    };

    await expect(useCase.execute('user-123', input)).rejects.toThrow();
  });

  it('should throw error when user not found', async () => {
    mockUserRepo.findById.mockResolvedValue(null);

    await expect(useCase.execute('non-existent-user', {})).rejects.toThrow('User not found');
  });

  it('should allow incomplete updates', async () => {
    mockUserProfile.musicPreferences = { ...defaultMusicPreferences };
    mockUserRepo.findById.mockResolvedValue(mockUserProfile);
    mockUserRepo.upsert.mockImplementation((profile: UserProfile) => Promise.resolve());

    const input = {
      lastService: 'apple_music' as const,
    };
    const result = await useCase.execute('user-123', input);

    expect(result.musicPreferences?.lastService).toBe('apple_music');
    expect(result.musicPreferences?.serviceEnabled).toBe(false);
  });
});
