import 'package:flutter_test/flutter_test.dart';
import 'package:runnin/features/training/domain/plan_admissibility.dart';

void main() {
  group('AdmissibilityConstants.applyRemoteConfig', () {
    test('sobrescreve raceWindows e tabelas com payload v1 do server', () {
      AdmissibilityConstants.applyRemoteConfig({
        'version': 1,
        'raceWindows': {
          '5': {
            'iniciante': {'aggressive': 7, 'feasible': 9, 'safe': 11},
          },
        },
        'peakWeeklyKm': {'5': 0, '10': 20},
        'weeklyRampRate': 1.12,
        'rampBaseFloorKm': 6,
        'ageRestrictionThresholds': {'blockAggressiveAge': 50},
        'paceImprovementCeilingPct': {'iniciante': 9.0},
        'medicalConditionOptions': [
          {'label': 'Historico de AVC', 'serious': true},
          {'label': 'Asma', 'serious': false},
        ],
      });

      expect(AdmissibilityConstants.raceWindows[5]!['iniciante']!.aggressive, 7);
      expect(AdmissibilityConstants.raceWindows[5]!['iniciante']!.safe, 11);
      expect(AdmissibilityConstants.peakWeeklyKm[10], 20);
      expect(AdmissibilityConstants.weeklyRampRate, 1.12);
      expect(AdmissibilityConstants.rampBaseFloorKm, 6);
      expect(AdmissibilityConstants.blockAggressiveAge, 50);
      expect(AdmissibilityConstants.paceImprovementCeilingPct['iniciante'], 9.0);
      expect(
        AdmissibilityConstants.seriousMedicalKeywords,
        contains('historico de avc'),
      );
      expect(AdmissibilityConstants.appliedConfigVersion, 1);
    });

    test('versão desconhecida não toca nas tabelas', () {
      final before = AdmissibilityConstants.raceWindows;
      AdmissibilityConstants.applyRemoteConfig({'version': 99, 'raceWindows': {}});
      expect(identical(AdmissibilityConstants.raceWindows, before), isTrue);
    });

    test('pedaço malformado mantém fallback daquele pedaço', () {
      final peakBefore = Map<int, int>.from(AdmissibilityConstants.peakWeeklyKm);
      AdmissibilityConstants.applyRemoteConfig({
        'version': 1,
        'peakWeeklyKm': 'corrupted',
      });
      expect(AdmissibilityConstants.peakWeeklyKm, peakBefore);
    });
  });
}
