import { UserRepository } from '../user.repository';
import { UserProfile, RunAlertPreferences } from '../user.entity';
import { NotFoundError } from '@shared/errors/app-error';

const defaultRunAlertPreferences: RunAlertPreferences = {
  paceAlertsEnabled: true,
  paceAlertFrequency: 'every_km',
  hrZoneAlertsEnabled: true,
  distanceMilestonesEnabled: true,
  distanceMilestones: [5.0, 10.0],
  timeMilestonesEnabled: false,
  timeMilestones: [],
};

export class GetRunPreferencesUseCase {
  constructor(private readonly userRepo: UserRepository) {}

  async execute(userId: string): Promise<RunAlertPreferences> {
    const user = await this.userRepo.findById(userId);
    if (!user) throw new NotFoundError('User');
    return user.runAlertPreferences ?? defaultRunAlertPreferences;
  }
}
