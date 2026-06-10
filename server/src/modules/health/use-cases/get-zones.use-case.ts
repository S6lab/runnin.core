import { UserRepository } from '@modules/users/domain/user.repository';
import { RunRepository } from '@modules/runs/domain/run.repository';
import {
  Zone,
  ZoneName,
  ZoneLabel,
  ZONE_FACTORS,
  ZONE_NAMES,
  ZONE_LABELS,
  calculateKarvonenZone,
} from '../domain/zone.entity';

export class GetZonesUseCase {
  constructor(
    private readonly userRepo: UserRepository,
    private readonly runRepo: RunRepository
  ) {}

  async execute(userId: string): Promise<Zone[]> {
    const user = await this.userRepo.findById(userId);
    if (!user) throw new Error('User not found');

    const restingBpm = user.restingBpm;
    const maxBpm = user.maxBpm;

    if (!restingBpm || !maxBpm) {
      throw new Error('User must have restingBpm and maxBpm set');
    }

    const zones: Zone[] = [];

    for (let i = 0; i < ZONE_FACTORS.length; i++) {
      const [bpmMin, bpmMax] = calculateKarvonenZone(maxBpm, restingBpm, ZONE_FACTORS[i]);
      
      zones.push({
        zone: ZONE_NAMES[i] as ZoneName,
        name: ZONE_LABELS[i] as ZoneLabel,
        bpmMin,
        bpmMax
      });
    }

    const last30Runs = await this.runRepo.findByUser(userId, 30);
    
    for (const zone of zones) {
      const runsInZone = last30Runs.runs.filter(run => {
        if (!run.avgBpm) return false;
        return run.avgBpm >= zone.bpmMin && run.avgBpm < zone.bpmMax;
      });
      
      zone.percentTime = runsInZone.length / last30Runs.runs.length;
    }

    return zones;
  }
}
