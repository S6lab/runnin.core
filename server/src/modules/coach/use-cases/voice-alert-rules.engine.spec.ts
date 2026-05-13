import { VoiceAlertRulesEngine, RunMetrics } from './voice-alert-rules.engine';

describe('VoiceAlertRulesEngine', () => {
  let engine: VoiceAlertRulesEngine;

  beforeEach(() => {
    engine = new VoiceAlertRulesEngine();
  });

  describe('Pace Alerts', () => {
    it('should trigger pace_too_fast when >10% faster than target', () => {
      const metrics: RunMetrics = {
        currentPace: '5:00', // 300 seconds
        targetPace: '6:00', // 360 seconds
        distanceKm: 2,
        elapsedSeconds: 600,
      };

      const result = engine.evaluateAlerts(metrics);

      expect(result).not.toBeNull();
      expect(result?.alertType).toBe('pace_too_fast');
      expect(result?.priority).toBe(2);
      expect(result?.shouldTrigger).toBe(true);
    });

    it('should trigger pace_too_slow when >15% slower than target', () => {
      const metrics: RunMetrics = {
        currentPace: '7:00', // 420 seconds
        targetPace: '6:00', // 360 seconds
        distanceKm: 2,
        elapsedSeconds: 600,
      };

      const result = engine.evaluateAlerts(metrics);

      expect(result).not.toBeNull();
      expect(result?.alertType).toBe('pace_too_slow');
      expect(result?.priority).toBe(3);
    });

    it('should not trigger when pace is within acceptable range', () => {
      const metrics: RunMetrics = {
        currentPace: '5:55',
        targetPace: '6:00',
        distanceKm: 2,
        elapsedSeconds: 600,
      };

      const result = engine.evaluateAlerts(metrics);

      // Should either be null or not a pace alert
      if (result !== null) {
        expect(['pace_too_fast', 'pace_too_slow']).not.toContain(result.alertType);
      }
    });

    it('should respect cooldown between pace alerts', () => {
      const metrics: RunMetrics = {
        currentPace: '5:00',
        targetPace: '6:00',
        distanceKm: 2,
        elapsedSeconds: 600,
        lastAlertTimestamp: Date.now() - 30_000, // 30 seconds ago
        lastAlertType: 'pace_too_fast',
      };

      const result = engine.evaluateAlerts(metrics);

      // Should not trigger same alert type within cooldown
      expect(result?.alertType).not.toBe('pace_too_fast');
    });
  });

  describe('Heart Rate Alerts', () => {
    it('should trigger hr_zone_high when >10 bpm above max', () => {
      const metrics: RunMetrics = {
        currentBpm: 180,
        targetBpmZone: { min: 140, max: 160 },
        distanceKm: 2,
        elapsedSeconds: 600,
      };

      const result = engine.evaluateAlerts(metrics);

      expect(result).not.toBeNull();
      expect(result?.alertType).toBe('hr_zone_high');
      expect(result?.priority).toBe(1); // Highest priority (safety)
    });

    it('should trigger hr_zone_low when >10 bpm below min', () => {
      const metrics: RunMetrics = {
        currentBpm: 120,
        targetBpmZone: { min: 140, max: 160 },
        distanceKm: 2,
        elapsedSeconds: 600,
      };

      const result = engine.evaluateAlerts(metrics);

      expect(result).not.toBeNull();
      expect(result?.alertType).toBe('hr_zone_low');
      expect(result?.priority).toBe(3);
    });

    it('should not trigger when HR is within target zone', () => {
      const metrics: RunMetrics = {
        currentBpm: 150,
        targetBpmZone: { min: 140, max: 160 },
        distanceKm: 2,
        elapsedSeconds: 600,
      };

      const result = engine.evaluateAlerts(metrics);

      // Should not trigger HR alerts
      if (result !== null) {
        expect(['hr_zone_high', 'hr_zone_low']).not.toContain(result.alertType);
      }
    });
  });

  describe('Milestone Alerts', () => {
    it('should trigger halfway_point at 50% progress', () => {
      const metrics: RunMetrics = {
        distanceKm: 5.0,
        targetDistanceKm: 10.0,
        elapsedSeconds: 1800,
      };

      const result = engine.evaluateAlerts(metrics);

      expect(result).not.toBeNull();
      expect(result?.alertType).toBe('halfway_point');
    });

    it('should trigger final_push at 90% progress', () => {
      const metrics: RunMetrics = {
        distanceKm: 9.1,
        targetDistanceKm: 10.0,
        elapsedSeconds: 3000,
      };

      const result = engine.evaluateAlerts(metrics);

      expect(result).not.toBeNull();
      expect(result?.alertType).toBe('final_push');
    });

    it('should trigger distance_milestone at 5km', () => {
      const metrics: RunMetrics = {
        distanceKm: 5.01, // Slightly over to ensure it's recognized as crossing the milestone
        targetDistanceKm: 10.0,
        elapsedSeconds: 1500,
      };

      const result = engine.evaluateAlerts(metrics);

      expect(result).not.toBeNull();
      // Should be either distance_milestone or halfway_point (since 5km is also 50%)
      expect(['distance_milestone', 'halfway_point']).toContain(result?.alertType);
    });

    it('should respect milestone cooldown', () => {
      const metrics: RunMetrics = {
        distanceKm: 5.0,
        targetDistanceKm: 10.0,
        elapsedSeconds: 1500,
        lastAlertTimestamp: Date.now() - 10_000, // 10 seconds ago
        lastAlertType: 'distance_milestone',
      };

      const result = engine.evaluateAlerts(metrics);

      // Should not trigger milestone alert within cooldown
      expect(result).toBeNull();
    });
  });

  describe('Priority Ordering', () => {
    it('should prioritize HR alerts over pace alerts', () => {
      const metrics: RunMetrics = {
        currentPace: '5:00',
        targetPace: '6:00',
        currentBpm: 180,
        targetBpmZone: { min: 140, max: 160 },
        distanceKm: 2,
        elapsedSeconds: 600,
      };

      const result = engine.evaluateAlerts(metrics);

      expect(result).not.toBeNull();
      expect(result?.alertType).toBe('hr_zone_high'); // Priority 1
    });

    it('should prioritize pace alerts over milestones', () => {
      const metrics: RunMetrics = {
        currentPace: '5:00',
        targetPace: '6:00',
        distanceKm: 5.0,
        targetDistanceKm: 10.0,
        elapsedSeconds: 1500,
      };

      const result = engine.evaluateAlerts(metrics);

      expect(result).not.toBeNull();
      expect(result?.alertType).toBe('pace_too_fast'); // Priority 2
    });
  });

  describe('Encouragement Alerts', () => {
    it('should trigger encouragement when no alerts for 5+ minutes', () => {
      const metrics: RunMetrics = {
        distanceKm: 3,
        elapsedSeconds: 600, // 10 minutes
        lastAlertTimestamp: Date.now() - 350_000, // 5+ minutes ago
      };

      const result = engine.evaluateAlerts(metrics);

      expect(result).not.toBeNull();
      expect(result?.alertType).toBe('encouragement');
      expect(result?.priority).toBe(5); // Lowest priority
    });

    it('should not trigger encouragement if recent alert exists', () => {
      const metrics: RunMetrics = {
        distanceKm: 3,
        elapsedSeconds: 600,
        lastAlertTimestamp: Date.now() - 60_000, // 1 minute ago
      };

      const result = engine.evaluateAlerts(metrics);

      if (result !== null) {
        expect(result.alertType).not.toBe('encouragement');
      }
    });
  });

  describe('Edge Cases', () => {
    it('should handle missing pace data gracefully', () => {
      const metrics: RunMetrics = {
        distanceKm: 2,
        elapsedSeconds: 600,
      };

      expect(() => engine.evaluateAlerts(metrics)).not.toThrow();
    });

    it('should handle missing HR data gracefully', () => {
      const metrics: RunMetrics = {
        currentPace: '6:00',
        targetPace: '6:00',
        distanceKm: 2,
        elapsedSeconds: 600,
      };

      expect(() => engine.evaluateAlerts(metrics)).not.toThrow();
    });

    it('should handle invalid pace format', () => {
      const metrics: RunMetrics = {
        currentPace: 'invalid',
        targetPace: '6:00',
        distanceKm: 2,
        elapsedSeconds: 600,
      };

      expect(() => engine.evaluateAlerts(metrics)).not.toThrow();
    });
  });
});
