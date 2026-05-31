import { UserRepository } from '@modules/users/domain/user.repository';
import { RunRepository } from '@modules/runs/domain/run.repository';
import { Zone } from '../domain/zone.entity';

const ZONE_FACTORS = [0.5, 0.6, 0.7, 0.8, 0.9] as const;
type ZoneFactor = typeof ZONE_FACTORS[number];
const ZONE_NAMES = ['Z1', 'Z2', 'Z3', 'Z4', 'Z5'] as const;
type ZoneName = typeof ZONE_NAMES[number];
const ZONE_LABELS = [
  'Futurologico',
  'Manutenção',
  'Intensidade Moderada',
  'Aeróbico',
  'Anaeróbico'
] as const;
type ZoneLabel = typeof ZONE_LABELS[number];

function calculateKarvonenZone(maxBpm: number, restingBpm: number, factor: ZoneFactor): [number, number] {
  const karvonen = ((maxBpm - restingBpm) * factor) + restingBpm;
  
  if (factor === 0.9) {
    return [Math.round(karvonen), Math.ceil(maxBpm)];
  }
  
  const nextFactor = ZONE_FACTORS[ZONE_FACTORS.indexOf(factor) + 1];
  const nextZoneMin = ((maxBpm - restingBpm) * nextFactor) + restingBpm;
  return [Math.round(karvonen), Math.round(nextZoneMin)];
}

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
