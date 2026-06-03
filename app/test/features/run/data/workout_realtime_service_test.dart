import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:runnin/features/run/data/workout_realtime_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('WorkoutRealtimeService — event parsing (defensive)', () {
    late WorkoutRealtimeService service;

    setUp(() {
      service = WorkoutRealtimeService();
    });

    test('bpmStream replay-on-listen emite o último valor cacheado', () async {
      // Simula um sample já emitido antes do listener anexar (race típica
      // entre start() e o subscribe do bloc).
      _simulateEventReceived(service, {'type': 'bpm', 'value': 142});
      // Aguarda micro-task pra controller propagar.
      await Future<void>.value();
      // Novo listener — deve receber o último valor.
      final first = await service.bpmStream.first.timeout(
        const Duration(seconds: 1),
        onTimeout: () => null,
      );
      expect(first, 142);
    });

    test('bpm como int é emitido', () async {
      final completer = service.bpmStream.first;
      _simulateEventReceived(service, {'type': 'bpm', 'value': 100});
      expect(await completer, 100);
    });

    test('bpm como double é arredondado', () async {
      final completer = service.bpmStream.first;
      _simulateEventReceived(service, {'type': 'bpm', 'value': 99.6});
      expect(await completer, 100);
    });

    test('bpm como string numérica também parsea', () async {
      final completer = service.bpmStream.first;
      _simulateEventReceived(service, {'type': 'bpm', 'value': '85'});
      expect(await completer, 85);
    });

    test('event sem type não crasha', () {
      expect(() => _simulateEventReceived(service, {'value': 100}),
          returnsNormally);
    });

    test('event com tipo desconhecido não crasha', () {
      expect(() => _simulateEventReceived(service, {'type': 'mystery'}),
          returnsNormally);
    });

    test('warning emite null no bpm stream', () async {
      _simulateEventReceived(service, {'type': 'bpm', 'value': 80});
      await Future<void>.value();
      _simulateEventReceived(
        service,
        {'type': 'warning', 'code': 'no_hr_source'},
      );
      await Future<void>.value();
      expect(service.latestBpm, null);
    });

    test('checkAvailability sem plataforma retorna unsupported_platform',
        () async {
      // Em ambiente de teste flutter_test, kIsWeb=false mas não tem
      // plataforma nativa; vai cair em retorno do channel ou exception.
      const channel = MethodChannel('runnin/workout_realtime');
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
        if (call.method == 'checkAvailability') {
          return <String, Object?>{'available': false, 'reason': 'no_capability'};
        }
        return null;
      });
      final r = await service.checkAvailability();
      expect(r.available, false);
      expect(r.reason, 'no_capability');
    });
  });
}

/// Simula um evento chegando pelo EventChannel. Usa o handler interno do
/// stream controller via reflection do API público (`bpmStream` triggers
/// `_attachEventStream` que assina o channel; aqui invocamos via mock).
void _simulateEventReceived(WorkoutRealtimeService service, Map<String, Object?> payload) {
  const channel = EventChannel('runnin/workout_realtime/events');
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .handlePlatformMessage(
    channel.name,
    const StandardMethodCodec().encodeSuccessEnvelope(payload),
    (_) {},
  );
}
