import { GetMusicPreferencesUseCase } from './get-music-preferences.use-case';
import { UserRepository } from '../user.repository';
import { UserProfile, MusicPreferences } from '../user.entity';

jest.mock('../user.repository');

const mockUserRepo = {
  findById: jest.fn(),
};

describe('GetMusicPreferencesUseCase', () => {
  let useCase: GetMusicPreferencesUseCase;
  let mockUserProfile: UserProfile;

  beforeEach(() => {
    jest.clearAllMocks();
    useCase = new GetMusicPreferencesUseCase(mockUserRepo as any);

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

  const defaultMusicPreferences: MusicPreferences = {
    serviceEnabled: false,
    lastService: 'device',
    lastVolume: 0.7,
  };

  it('should return default preferences when user has no preferences set', async () => {
    mockUserRepo.findById.mockResolvedValue(mockUserProfile);

    const result = await useCase.execute('user-123');

    expect(result).toEqual(defaultMusicPreferences);
  });

  it('should return custom preferences when user has them set', async () => {
    const customPreferences: MusicPreferences = {
      ...defaultMusicPreferences,
      serviceEnabled: true,
      lastService: 'spotify',
      lastVolume: 0.9,
    };
    mockUserProfile.musicPreferences = customPreferences;
    mockUserRepo.findById.mockResolvedValue(mockUserProfile);

    const result = await useCase.execute('user-123');

    expect(result).toEqual(customPreferences);
  });

  it('should throw error when user not found', async () => {
    mockUserRepo.findById.mockResolvedValue(null);

    await expect(useCase.execute('non-existent-user')).rejects.toThrow('User not found');
  });
});
