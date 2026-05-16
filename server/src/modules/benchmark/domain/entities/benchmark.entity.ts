export interface CohortAggregate {
  id: string;
  level: string;
  runType: string;
  distance: string;
  cohortSize: number;
  paceAvgs: number[];
  bpmAvgs: number[];
  distAvgs: number[];
  consistencyAvgs: number[];
  updatedAt: string;
}

export interface UserValues {
  pace?: string;
  weeklyDistance?: string;
  consistency?: number;
  avgBpm?: number;
}

export interface CohortValues {
  pace?: string;
  weeklyDistance?: string;
  consistency?: number;
  avgBpm?: number;
}

export interface BenchmarkResponse {
  userPercentile: number;
  userValues: UserValues;
  cohortValues: CohortValues;
  cohortSize: number;
}
