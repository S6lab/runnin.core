/**
 * Stats module — aggregated user run stats by period (week/month/all-time).
 * Exposes /v1/stats/aggregate consumed by HIST.DADOS screen.
 */
export { statsRouter } from './http/stats.routes';
export type { StatsAggregate, StatsPeriod } from './domain/stats-aggregate.entity';
