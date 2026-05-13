import 'package:flutter_test/flutter_test.dart';
import 'package:runnin/features/coach/domain/entities/coach_report.dart';

void main() {
  group('CoachReport', () {
    test('fromJson parses ready report', () {
      final json = {
        'status': 'ready',
        'summary': 'Great run! Keep it up.',
        'generatedAt': '2026-05-13T10:00:00Z',
      };
      final report = CoachReport.fromJson(json);
      expect(report.status, 'ready');
      expect(report.summary, 'Great run! Keep it up.');
      expect(report.generatedAt, '2026-05-13T10:00:00Z');
      expect(report.isReady, isTrue);
    });

    test('fromJson parses pending report', () {
      final json = {
        'status': 'pending',
        'summary': null,
        'generatedAt': null,
      };
      final report = CoachReport.fromJson(json);
      expect(report.status, 'pending');
      expect(report.summary, isNull);
      expect(report.generatedAt, isNull);
      expect(report.isReady, isFalse);
    });

    test('fromJson handles missing fields', () {
      final json = <String, dynamic>{};
      final report = CoachReport.fromJson(json);
      expect(report.status, 'pending');
      expect(report.summary, isNull);
      expect(report.generatedAt, isNull);
      expect(report.isReady, isFalse);
    });

    test('isReady returns false for empty summary', () {
      final json = {
        'status': 'ready',
        'summary': '   ',
        'generatedAt': '2026-05-13T10:00:00Z',
      };
      final report = CoachReport.fromJson(json);
      expect(report.isReady, isFalse);
    });
  });
}
