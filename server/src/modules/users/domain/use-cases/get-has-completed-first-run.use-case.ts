import { UserRepository } from '../user.repository';
import { NotFoundError } from '@shared/errors/app-error';

/**
 * Use case to retrieve the hasCompletedFirstRun status for a user
 *
 * Description: Returns whether the specified user has completed their first run.
 * This is used to determine if the initial onboarding briefing should be shown.
 *
 * Access: Authenticated - only the user can retrieve their own status
 */
export class GetHasCompletedFirstRunUseCase {
  constructor(private readonly userRepo: UserRepository) {}

  /**
   * Execute the use case
   * @param userId - The unique identifier of the user
   * @returns Object containing hasCompletedFirstRun boolean status
   * @throws NotFoundError if user does not exist
   */
  async execute(userId: string): Promise<{ hasCompletedFirstRun: boolean }> {
    const user = await this.userRepo.findById(userId);
    if (!user) throw new NotFoundError('User');
    return { hasCompletedFirstRun: user.hasCompletedFirstRun };
  }
}
