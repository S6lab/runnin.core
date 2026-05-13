import { VoiceAlertType } from './generate-voice-alert.use-case';
import { logger } from '@shared/logger/logger';

export interface RunMetrics {
  currentPace?: string; // e.g., "5:30"
  targetPace?: string;
  currentBpm?: number;
  targetBpmZone?: { min: number; max: number };
  distanceKm: number;
  targetDistanceKm?: number;
  elapsedSeconds: number;
  sessionType?: string;
  lastAlertTimestamp?: number; // Unix ms
  lastAlertType?: VoiceAlertType;
}

export interface AlertTrigger {
  shouldTrigger: boolean;
  alertType: VoiceAlertType;
  priority: number; // 1=highest, 5=lowest
  reason: string;
}

/**
 * Voice Alert Rules Engine
 * Determines when and what type of voice alerts should be triggered during a run.
 * Implements cooldown logic and prioritization to avoid alert fatigue.
 */
export class VoiceAlertRulesEngine {
  private readonly MIN_ALERT_INTERVAL_MS = 120_000; // 2 minutes between alerts (general)
  private readonly CRITICAL_ALERT_INTERVAL_MS = 60_000; // 1 minute for critical alerts (HR/pace safety)
  private readonly MILESTONE_COOLDOWN_MS = 30_000; // 30 seconds after milestone alerts

  /**
   * Evaluate current run metrics and determine if an alert should be triggered
   */
  evaluateAlerts(metrics: RunMetrics): AlertTrigger | null {
    const triggers: AlertTrigger[] = [];

    // Check all possible alert conditions
    triggers.push(...this.checkPaceAlerts(metrics));
    triggers.push(...this.checkHeartRateAlerts(metrics));
    triggers.push(...this.checkMilestoneAlerts(metrics));
    triggers.push(...this.checkEncouragementAlerts(metrics));

    // Filter by cooldown and priority
    const validTriggers = triggers.filter((t) => t.shouldTrigger);

    if (validTriggers.length === 0) return null;

    // Return highest priority alert
    validTriggers.sort((a, b) => a.priority - b.priority);
    return validTriggers[0];
  }

  private checkPaceAlerts(metrics: RunMetrics): AlertTrigger[] {
    const alerts: AlertTrigger[] = [];

    if (!metrics.currentPace || !metrics.targetPace) {
      return alerts;
    }

    const currentPaceSeconds = this.paceToSeconds(metrics.currentPace);
    const targetPaceSeconds = this.paceToSeconds(metrics.targetPace);

    if (!currentPaceSeconds || !targetPaceSeconds) return alerts;

    const paceDeviation = currentPaceSeconds - targetPaceSeconds;
    const deviationPercent = Math.abs(paceDeviation) / targetPaceSeconds;

    // Too fast (>10% faster than target)
    if (paceDeviation < 0 && deviationPercent > 0.1) {
      alerts.push({
        shouldTrigger: this.checkCooldown(metrics, 'pace_too_fast', true),
        alertType: 'pace_too_fast',
        priority: 2, // High priority (safety)
        reason: `Pace ${((deviationPercent * 100).toFixed(1))}% faster than target`,
      });
    }

    // Too slow (>15% slower than target)
    else if (paceDeviation > 0 && deviationPercent > 0.15) {
      alerts.push({
        shouldTrigger: this.checkCooldown(metrics, 'pace_too_slow', false),
        alertType: 'pace_too_slow',
        priority: 3, // Medium priority
        reason: `Pace ${((deviationPercent * 100).toFixed(1))}% slower than target`,
      });
    }

    // On target (within 5% of target) - only after previous correction
    else if (deviationPercent <= 0.05 && this.wasRecentPaceAlert(metrics)) {
      alerts.push({
        shouldTrigger: this.checkCooldown(metrics, 'pace_on_target', false),
        alertType: 'pace_on_target',
        priority: 4, // Lower priority (positive feedback)
        reason: 'Pace corrected to target',
      });
    }

    return alerts;
  }

  private checkHeartRateAlerts(metrics: RunMetrics): AlertTrigger[] {
    const alerts: AlertTrigger[] = [];

    if (!metrics.currentBpm || !metrics.targetBpmZone) {
      return alerts;
    }

    const { min, max } = metrics.targetBpmZone;
    const currentBpm = metrics.currentBpm;

    // Too high (>10 bpm above max zone)
    if (currentBpm > max + 10) {
      alerts.push({
        shouldTrigger: this.checkCooldown(metrics, 'hr_zone_high', true),
        alertType: 'hr_zone_high',
        priority: 1, // Highest priority (safety)
        reason: `HR ${currentBpm} bpm, ${currentBpm - max} bpm above max zone`,
      });
    }

    // Too low (>10 bpm below min zone)
    else if (currentBpm < min - 10) {
      alerts.push({
        shouldTrigger: this.checkCooldown(metrics, 'hr_zone_low', false),
        alertType: 'hr_zone_low',
        priority: 3, // Medium priority
        reason: `HR ${currentBpm} bpm, ${min - currentBpm} bpm below min zone`,
      });
    }

    // Optimal (within zone) - only after previous HR alert
    else if (currentBpm >= min && currentBpm <= max && this.wasRecentHRAlert(metrics)) {
      alerts.push({
        shouldTrigger: this.checkCooldown(metrics, 'hr_zone_optimal', false),
        alertType: 'hr_zone_optimal',
        priority: 4, // Lower priority (positive feedback)
        reason: `HR ${currentBpm} bpm in optimal zone`,
      });
    }

    return alerts;
  }

  private checkMilestoneAlerts(metrics: RunMetrics): AlertTrigger[] {
    const alerts: AlertTrigger[] = [];
    const targetDistance = metrics.targetDistanceKm ?? 0;

    if (targetDistance === 0) return alerts;

    const progressPercent = (metrics.distanceKm / targetDistance) * 100;

    // Halfway point (50% ±2%)
    if (progressPercent >= 48 && progressPercent <= 52) {
      alerts.push({
        shouldTrigger: this.checkMilestoneCooldown(metrics, 'halfway_point'),
        alertType: 'halfway_point',
        priority: 4,
        reason: 'Reached halfway point',
      });
    }

    // Final push (90% completed)
    else if (progressPercent >= 90 && progressPercent <= 92) {
      alerts.push({
        shouldTrigger: this.checkMilestoneCooldown(metrics, 'final_push'),
        alertType: 'final_push',
        priority: 3,
        reason: 'Approaching finish',
      });
    }

    // Distance milestones (every full km after first 2km)
    else if (metrics.distanceKm >= 2) {
      const isFullKm = Math.abs(metrics.distanceKm - Math.round(metrics.distanceKm)) < 0.05;
      const kmMilestone = Math.round(metrics.distanceKm);

      // Only trigger for km milestones: 3, 5, 7, 10, 15, 20, etc.
      if (isFullKm && (kmMilestone % 5 === 0 || kmMilestone === 3)) {
        alerts.push({
          shouldTrigger: this.checkMilestoneCooldown(metrics, 'distance_milestone'),
          alertType: 'distance_milestone',
          priority: 5,
          reason: `Completed ${kmMilestone}km`,
        });
      }
    }

    // Time milestones (every 15 minutes)
    const elapsedMinutes = Math.floor(metrics.elapsedSeconds / 60);
    if (elapsedMinutes > 0 && elapsedMinutes % 15 === 0) {
      const justReached = metrics.elapsedSeconds % 60 < 10; // Within first 10 seconds of the minute
      if (justReached) {
        alerts.push({
          shouldTrigger: this.checkMilestoneCooldown(metrics, 'time_milestone'),
          alertType: 'time_milestone',
          priority: 5,
          reason: `Completed ${elapsedMinutes} minutes`,
        });
      }
    }

    return alerts;
  }

  private checkEncouragementAlerts(metrics: RunMetrics): AlertTrigger[] {
    const alerts: AlertTrigger[] = [];

    // General encouragement every 8-10 minutes if no other alerts
    const elapsedMinutes = Math.floor(metrics.elapsedSeconds / 60);
    const timeSinceLastAlert = metrics.lastAlertTimestamp
      ? Date.now() - metrics.lastAlertTimestamp
      : Number.MAX_SAFE_INTEGER;

    // Encourage if >8 minutes elapsed and no alert in last 5 minutes
    if (elapsedMinutes >= 8 && timeSinceLastAlert > 300_000) {
      alerts.push({
        shouldTrigger: true,
        alertType: 'encouragement',
        priority: 5, // Lowest priority
        reason: 'General encouragement',
      });
    }

    return alerts;
  }

  private checkCooldown(
    metrics: RunMetrics,
    alertType: VoiceAlertType,
    isCritical: boolean,
  ): boolean {
    if (!metrics.lastAlertTimestamp) return true;

    const timeSinceLastAlert = Date.now() - metrics.lastAlertTimestamp;
    const cooldown = isCritical ? this.CRITICAL_ALERT_INTERVAL_MS : this.MIN_ALERT_INTERVAL_MS;

    // Allow same alert type only after cooldown
    if (metrics.lastAlertType === alertType) {
      return timeSinceLastAlert >= cooldown;
    }

    // Allow different alert type after shorter cooldown for critical alerts
    if (isCritical) {
      return timeSinceLastAlert >= this.CRITICAL_ALERT_INTERVAL_MS;
    }

    return timeSinceLastAlert >= this.MIN_ALERT_INTERVAL_MS;
  }

  private checkMilestoneCooldown(metrics: RunMetrics, alertType: VoiceAlertType): boolean {
    if (!metrics.lastAlertTimestamp) return true;

    const timeSinceLastAlert = Date.now() - metrics.lastAlertTimestamp;
    return timeSinceLastAlert >= this.MILESTONE_COOLDOWN_MS;
  }

  private wasRecentPaceAlert(metrics: RunMetrics): boolean {
    if (!metrics.lastAlertType || !metrics.lastAlertTimestamp) return false;
    const timeSinceLastAlert = Date.now() - metrics.lastAlertTimestamp;
    return (
      (metrics.lastAlertType === 'pace_too_fast' || metrics.lastAlertType === 'pace_too_slow') &&
      timeSinceLastAlert < this.MIN_ALERT_INTERVAL_MS * 2
    );
  }

  private wasRecentHRAlert(metrics: RunMetrics): boolean {
    if (!metrics.lastAlertType || !metrics.lastAlertTimestamp) return false;
    const timeSinceLastAlert = Date.now() - metrics.lastAlertTimestamp;
    return (
      (metrics.lastAlertType === 'hr_zone_high' || metrics.lastAlertType === 'hr_zone_low') &&
      timeSinceLastAlert < this.MIN_ALERT_INTERVAL_MS * 2
    );
  }

  /**
   * Convert pace string (e.g., "5:30") to total seconds per km
   */
  private paceToSeconds(pace: string): number | null {
    try {
      const parts = pace.split(':');
      if (parts.length !== 2) return null;

      const minutes = parseInt(parts[0], 10);
      const seconds = parseInt(parts[1], 10);

      if (isNaN(minutes) || isNaN(seconds)) return null;
      if (minutes < 0 || seconds < 0 || seconds >= 60) return null;

      return minutes * 60 + seconds;
    } catch (err) {
      logger.warn('voice_alert.pace_parse_failed', { pace, err });
      return null;
    }
  }
}
