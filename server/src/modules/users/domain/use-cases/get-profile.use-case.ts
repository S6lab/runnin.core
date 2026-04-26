import { UserRepository } from '../user.repository';
import { UserProfile } from '../user.entity';
import { NotFoundError } from '@shared/errors/app-error';

export class GetProfileUseCase {
  constructor(private readonly userRepo: UserRepository) {}

  async execute(userId: string): Promise<UserProfile> {
    const user = await this.userRepo.findById(userId);
    if (!user) throw new NotFoundError('User');
    return user;
  }
}
