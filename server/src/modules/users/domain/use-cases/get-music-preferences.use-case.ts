import { UserRepository } from '../user.repository';
import { UserProfile, MusicPreferences } from '../user.entity';
import { NotFoundError } from '@shared/errors/app-error';

const defaultMusicPreferences: MusicPreferences = {
  serviceEnabled: false,
  lastService: 'device',
  lastVolume: 0.7,
};

export class GetMusicPreferencesUseCase {
  constructor(private readonly userRepo: UserRepository) {}

  async execute(userId: string): Promise<MusicPreferences> {
    const user = await this.userRepo.findById(userId);
    if (!user) throw new NotFoundError('User');
    return user.musicPreferences ?? defaultMusicPreferences;
  }
}
