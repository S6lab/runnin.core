import 'package:flutter_test/flutter_test.dart';
import 'package:runnin/features/biometrics/domain/recovery_score.dart';

void main() {
  group('computeRecoveryScore', () {
    test('< 2 sinais retorna score null + componentes vazios', () {
      final r1 = computeRecoveryScore();
      expect(r1.score, isNull);
      expect(r1.components.signalCount, 0);

      final r2 = computeRecoveryScore(avgSleepHours: 7.5);
      expect(r2.score, isNull);
      expect(r2.components.sleepUsed, true);
      expect(r2.components.signalCount, 1);
    });

    test('todos os 3 sinais perfeitos → 100', () {
      final r = computeRecoveryScore(
        avgSleepHours: 7.5,
        avgRestingBpm: 50,
        avgHrv: 100,
      );
      expect(r.score, 100);
      expect(r.components.signalCount, 3);
    });

    test('só sono+bpm com valores médios → score plausível', () {
      // sono 7h (0.875) + bpm resting 65 (0.5) → (0.875*0.4 + 0.5*0.35) /
      // (0.4+0.35) = 0.525/0.75 = 0.7 → 70.
      final r = computeRecoveryScore(
        avgSleepHours: 7.0,
        avgRestingBpm: 65,
      );
      expect(r.score, isNotNull);
      expect(r.score, inInclusiveRange(65, 75));
      expect(r.components.hrvUsed, false);
    });

    test('bpm muito alto puxa score pra baixo', () {
      final r = computeRecoveryScore(
        avgSleepHours: 7.5,
        avgRestingBpm: 85, // acima do range — clampa em 0
      );
      // sono perfeito (1.0) com peso 0.53, bpm 0 com peso 0.47 → ~53.
      expect(r.score, isNotNull);
      expect(r.score, lessThan(60));
    });

    test('sono fora do sweet spot reduz pontuação', () {
      final perfectSleep = computeRecoveryScore(
        avgSleepHours: 7.5,
        avgRestingBpm: 60,
      );
      final shortSleep = computeRecoveryScore(
        avgSleepHours: 5.0,
        avgRestingBpm: 60,
      );
      expect(perfectSleep.score, greaterThan(shortSleep.score!));
    });

    test('valores zero ou negativos são ignorados', () {
      final r = computeRecoveryScore(
        avgSleepHours: 0,
        avgRestingBpm: 60,
        avgHrv: 60,
      );
      // Sono inválido → só bpm+hrv contam → 2 sinais válidos, score sai.
      expect(r.components.sleepUsed, false);
      expect(r.score, isNotNull);
    });
  });
}
