import { z } from 'zod';
import { UserRepository } from '../user.repository';
import { UserProfile, MusicPreferences } from '../user.entity';
import { NotFoundError, ValidationError } from '@shared/errors/app-error';

export const MusicPreferencesSchema = z.object({
  serviceEnabled: z.boolean().optional(),
  lastService: z.enum(['device', 'spotify', 'youtube_music', 'apple_music']).optional(),
  lastVolume: z.number().min(0).max(1).optional(),
});

export type UpdateMusicPreferencesInput = z.infer<typeof MusicPreferencesSchema>;

const defaultMusicPreferences: MusicPreferences = {
  serviceEnabled: false,
  lastService: 'device',
  lastVolume: 0.7,
};

export class UpdateMusicPreferencesUseCase {
  constructor(private readonly userRepo: UserRepository) {}

  async execute(userId: string, input: UpdateMusicPreferencesInput): Promise<UserProfile> {
    const user = await this.userRepo.findById(userId);
    if (!user) throw new NotFoundError('User');

    const validation = MusicPreferencesSchema.safeParse(input);
    if (!validation.success) {
      throw new ValidationError(validation.error.toString());
    }

    const existing = user.musicPreferences ?? defaultMusicPreferences;
    const updated: MusicPreferences = {
      serviceEnabled:
        validation.data.serviceEnabled !== undefined
          ? validation.data.serviceEnabled
          : existing.serviceEnabled,
      lastService:
        validation.data.lastService !== undefined ? validation.data.lastService : existing.lastService,
      lastVolume:
        validation.data.lastVolume !== undefined ? validation.data.lastVolume : existing.lastVolume,
    };

    const profile: UserProfile = {
      ...user,
      musicPreferences: updated,
      updatedAt: new Date().toISOString(),
    };

    await this.userRepo.upsert(profile);
    return profile;
  }
}
