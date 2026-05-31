import { RunRepository } from '@modules/runs/domain/run.repository';

export interface UserTotals {
  totalRuns: number;
  totalDistanceM: number;
  totalDurationS: number;
  totalCalories: number;
  totalXp: number;
}

export class GetUserTotalsUseCase {
  constructor(private readonly runs: RunRepository) {}

  async execute(userId: string): Promise<UserTotals> {
    const { runs } = await this.runs.findByUser(userId, 1000);
    const completed = runs.filter(r => r.status === 'completed');
    return {
      totalRuns: completed.length,
      totalDistanceM: completed.reduce((s, r) => s + (r.distanceM || 0), 0),
      totalDurationS: completed.reduce((s, r) => s + (r.durationS || 0), 0),
      totalCalories: completed.reduce((s, r) => s + (r.calories || 0), 0),
      totalXp: completed.reduce((s, r) => s + (r.xpEarned || 0), 0),
    };
  }
}
