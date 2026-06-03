import 'package:flutter_test/flutter_test.dart';
import 'package:runnin/core/logger/logger.dart';

void main() {
  group('Logger', () {
    test('error não lança quando reason é vazio', () {
      expect(
        () => Logger.error('test.reason', Exception('x'), StackTrace.current),
        returnsNormally,
      );
    });

    test('warn não lança quando context é null', () {
      expect(() => Logger.warn('any.message'), returnsNormally);
    });

    test('info é silencioso em release (não lança)', () {
      expect(
        () => Logger.info('any.info', context: {'key': 'value'}),
        returnsNormally,
      );
    });

    test('error aceita context map', () {
      expect(
        () => Logger.error(
          'with.context',
          Exception('boom'),
          StackTrace.current,
          {'step': 'parse', 'rec': 42},
        ),
        returnsNormally,
      );
    });
  });
}
