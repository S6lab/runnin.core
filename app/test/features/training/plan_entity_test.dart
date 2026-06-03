import 'package:flutter_test/flutter_test.dart';
import 'package:runnin/features/training/domain/entities/plan.dart';

void main() {
  group('PlanWeek.fromJson — regression cast int/double', () {
    test('weekNumber aceita int', () {
      final w = PlanWeek.fromJson(_weekJson(weekNumberRaw: 1));
      expect(w.weekNumber, 1);
    });

    test('weekNumber aceita double (Firestore wire)', () {
      final w = PlanWeek.fromJson(_weekJson(weekNumberRaw: 1.0));
      expect(w.weekNumber, 1);
    });
  });

  group('PlanSession.fromJson', () {
    test('dayOfWeek double não estoura', () {
      final s = PlanSession.fromJson({
        'id': 's1',
        'dayOfWeek': 2.0,
        'type': 'Easy Run',
        'distanceKm': 5.0,
        'notes': '',
      });
      expect(s.dayOfWeek, 2);
    });

    test('campos opcionais em skeleton não estouram', () {
      // Plan two-tier: weeks 3+ vêm sem hydrationLiters/nutritionPre/durationMin
      final s = PlanSession.fromJson({
        'id': 's1',
        'dayOfWeek': 1.0,
        'type': 'Easy Run',
        'distanceKm': 3.0,
        'targetPace': '6:30',
        'notes': 'Easy Run.',
      });
      expect(s.dayOfWeek, 1);
      expect(s.hydrationLiters, null);
      expect(s.nutritionPre, null);
      expect(s.durationMin, null);
    });
  });

  group('Plan.fromJson — regression two-tier', () {
    test('plano com weeks skeleton parsea sem crashar', () {
      final p = Plan.fromJson({
        'id': 'plan_1',
        'goal': 'completar 10K',
        'level': 'iniciante',
        'weeksCount': 8.0, // double do Firestore
        'status': 'ready',
        'createdAt': '2026-06-02T00:00:00.000Z',
        'weeks': [
          {
            'weekNumber': 1.0,
            'detailLevel': 'full',
            'sessions': [
              {
                'id': 's1',
                'dayOfWeek': 1.0,
                'type': 'Easy Run',
                'distanceKm': 5.0,
                'notes': '',
                'hydrationLiters': 2.5,
              },
            ],
          },
          {
            'weekNumber': 3.0,
            'detailLevel': 'skeleton',
            'sessions': [
              {
                'id': 's2',
                'dayOfWeek': 1.0,
                'type': 'Easy Run',
                'distanceKm': 6.0,
                'notes': '',
              },
            ],
          },
        ],
      });
      expect(p.weeksCount, 8);
      expect(p.weeks.length, 2);
      expect(p.weeks[0].isSkeleton, false);
      expect(p.weeks[1].isSkeleton, true);
      expect(p.weeks[0].sessions[0].hydrationLiters, 2.5);
      expect(p.weeks[1].sessions[0].hydrationLiters, null);
    });
  });
}

Map<String, dynamic> _weekJson({required num weekNumberRaw}) => {
      'weekNumber': weekNumberRaw,
      'sessions': <Map<String, dynamic>>[],
    };
