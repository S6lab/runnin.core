import { z } from 'zod';
import { UserRepository } from '../user.repository';
import { UserProfile, RunAlertPreferences } from '../user.entity';
import { NotFoundError, ValidationError } from '@shared/errors/app-error';

const MAX_MILESTONES = 10;

export const RunAlertPreferencesSchema = z.object({
  paceAlertsEnabled: z.boolean().optional(),
  paceAlertFrequency: z.enum(['every_km', 'every_500m', 'off']).optional(),
  hrZoneAlertsEnabled: z.boolean().optional(),
  distanceMilestonesEnabled: z.boolean().optional(),
  distanceMilestones: z
    .array(z.number().positive())
    .max(MAX_MILESTONES, `Maximum ${MAX_MILESTONES} distance milestones allowed`)
    .optional(),
  timeMilestonesEnabled: z.boolean().optional(),
  timeMilestones: z
    .array(z.number().min(0))
    .max(MAX_MILESTONES, `Maximum ${MAX_MILESTONES} time milestones allowed`)
    .optional(),
});

export type UpdateRunPreferencesInput = z.infer<typeof RunAlertPreferencesSchema>;

const defaultRunAlertPreferences: RunAlertPreferences = {
  paceAlertsEnabled: true,
  paceAlertFrequency: 'every_km',
  hrZoneAlertsEnabled: true,
  distanceMilestonesEnabled: true,
  distanceMilestones: [5.0, 10.0],
  timeMilestonesEnabled: false,
  timeMilestones: [],
};

export class UpdateRunPreferencesUseCase {
  constructor(private readonly userRepo: UserRepository) {}

  async execute(userId: string, input: UpdateRunPreferencesInput): Promise<UserProfile> {
    const user = await this.userRepo.findById(userId);
    if (!user) throw new NotFoundError('User');

    const validation = RunAlertPreferencesSchema.safeParse(input);
    if (!validation.success) {
      throw new ValidationError(validation.error.toString());
    }

    const existing = user.runAlertPreferences ?? defaultRunAlertPreferences;
    const updated: RunAlertPreferences = {
      paceAlertsEnabled:
        validation.data.paceAlertsEnabled !== undefined
          ? validation.data.paceAlertsEnabled
          : existing.paceAlertsEnabled,
      paceAlertFrequency:
        validation.data.paceAlertFrequency !== undefined
          ? validation.data.paceAlertFrequency
          : existing.paceAlertFrequency,
      hrZoneAlertsEnabled:
        validation.data.hrZoneAlertsEnabled !== undefined
          ? validation.data.hrZoneAlertsEnabled
          : existing.hrZoneAlertsEnabled,
      distanceMilestonesEnabled:
        validation.data.distanceMilestonesEnabled !== undefined
          ? validation.data.distanceMilestonesEnabled
          : existing.distanceMilestonesEnabled,
      distanceMilestones:
        validation.data.distanceMilestones !== undefined
          ? validation.data.distanceMilestones
          : existing.distanceMilestones,
      timeMilestonesEnabled:
        validation.data.timeMilestonesEnabled !== undefined
          ? validation.data.timeMilestonesEnabled
          : existing.timeMilestonesEnabled,
      timeMilestones:
        validation.data.timeMilestones !== undefined
          ? validation.data.timeMilestones
          : existing.timeMilestones,
    };

    const profile: UserProfile = {
      ...user,
      runAlertPreferences: updated,
      updatedAt: new Date().toISOString(),
    };

    await this.userRepo.upsert(profile);
    return profile;
  }
}
