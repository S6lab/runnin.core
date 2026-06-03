import 'package:flutter_test/flutter_test.dart';
import 'package:runnin/core/units/relative_period_label.dart';

void main() {
  group('formatRelativePeriod — week', () {
    test('cursor 0 → ESTA SEMANA', () {
      expect(formatRelativePeriod(PeriodKind.week, 0), 'ESTA SEMANA');
    });
    test('cursor -1 → SEMANA PASSADA', () {
      expect(formatRelativePeriod(PeriodKind.week, -1), 'SEMANA PASSADA');
    });
    test('cursor -2 → HÁ 2 SEMANAS', () {
      expect(formatRelativePeriod(PeriodKind.week, -2), 'HÁ 2 SEMANAS');
    });
    test('cursor -5 → HÁ 5 SEMANAS', () {
      expect(formatRelativePeriod(PeriodKind.week, -5), 'HÁ 5 SEMANAS');
    });
  });

  group('formatRelativePeriod — month', () {
    test('cursor 0 → ESTE MÊS', () {
      expect(formatRelativePeriod(PeriodKind.month, 0), 'ESTE MÊS');
    });
    test('cursor -1 → MÊS PASSADO', () {
      expect(formatRelativePeriod(PeriodKind.month, -1), 'MÊS PASSADO');
    });
    test('cursor -3 → HÁ 3 MESES', () {
      expect(formatRelativePeriod(PeriodKind.month, -3), 'HÁ 3 MESES');
    });
    test('cursor -12 → ANO PASSADO', () {
      expect(formatRelativePeriod(PeriodKind.month, -12), 'ANO PASSADO');
    });
    test('cursor -13 → HÁ 13 MESES', () {
      expect(formatRelativePeriod(PeriodKind.month, -13), 'HÁ 13 MESES');
    });
  });

  group('formatRelativePeriod — threeMonths', () {
    test('cursor 0 → ÚLTIMOS 90 DIAS', () {
      expect(formatRelativePeriod(PeriodKind.threeMonths, 0), 'ÚLTIMOS 90 DIAS');
    });
    test('cursor -1 → TRIMESTRE PASSADO', () {
      expect(formatRelativePeriod(PeriodKind.threeMonths, -1), 'TRIMESTRE PASSADO');
    });
    test('cursor -2 → HÁ 2 TRIMESTRES', () {
      expect(formatRelativePeriod(PeriodKind.threeMonths, -2), 'HÁ 2 TRIMESTRES');
    });
    test('cursor -1 singular → TRIMESTRE (não TRIMESTRES)', () {
      expect(formatRelativePeriod(PeriodKind.threeMonths, -1),
          'TRIMESTRE PASSADO');
    });
  });
}
