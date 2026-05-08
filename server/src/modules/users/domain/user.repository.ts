import { UserProfile } from './user.entity';

export interface UserRepository {
  findById(id: string): Promise<UserProfile | null>;
  upsert(profile: UserProfile): Promise<void>;
  archiveOnboarding(userId: string, snapshot: UserProfile): Promise<void>;
}
