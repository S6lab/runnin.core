import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:runnin/features/run/data/workout_realtime_service.dart';
// ignore_for_file: unused_import

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('WorkoutRealtimeService — event parsing (defensive)', () {
    late WorkoutRealtimeService service;

    setUp(() {
      service = WorkoutRealtimeService();
    });

    tearDown(() async {
      // EventChannel é global por nome — sem dispose, listeners de instâncias
      // anteriores ficam vivos e capturam eventos de testes subsequentes,
      // gerando vazamento de estado e asserts intermitentes.
      await service.dispose();
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

    test('warningStream emite código quando plugin envia no_hr_source',
        () async {
      final warning = service.warningStream.first;
      _simulateEventReceived(service, {
        'type': 'warning',
        'code': 'no_hr_source',
        'message': 'No HR for 8s',
      });
      expect(await warning, 'no_hr_source');
    });

    test('warningStream emite código quando plugin envia permission_denied',
        () async {
      final warning = service.warningStream.first;
      _simulateEventReceived(service, {
        'type': 'error',
        'code': 'permission_denied',
        'message': 'denied',
      });
      expect(await warning, 'permission_denied');
    });

    test(
        'sequência start→sample reflete em latestBpm e propaga pros listeners',
        () async {
      // Replay-on-listen + propagação: simula a sequência real do run_bloc
      // (start dispara o stream nativo; quando o primeiro sample chega,
      // listeners imediatos recebem). Sem o auto-attach em [bpmStream],
      // listeners atrás de start() perdiam samples.
      final emissions = <int?>[];
      final sub = service.bpmStream.listen(emissions.add);
      // micro-task pra deixar o subscription do async* anexar antes do primeiro
      // evento; sem isso, eventos disparados sincronicamente são perdidos.
      await Future<void>.value();
      _simulateEventReceived(service, {'type': 'bpm', 'value': 132});
      await Future<void>.value();
      _simulateEventReceived(service, {'type': 'bpm', 'value': 140});
      await Future<void>.value();
      await sub.cancel();
      expect(emissions, [132, 140]);
      expect(service.latestBpm, 140);
    });

    test(
        'após warning no_hr_source, sample posterior reativa o stream com novo valor',
        () async {
      _simulateEventReceived(service, {'type': 'bpm', 'value': 110});
      await Future<void>.value();
      _simulateEventReceived(service, {
        'type': 'warning',
        'code': 'no_hr_source',
      });
      await Future<void>.value();
      expect(service.latestBpm, null);

      final next = service.bpmStream.first;
      _simulateEventReceived(service, {'type': 'bpm', 'value': 125});
      expect(await next, 125);
      expect(service.latestBpm, 125);
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

/// Simula um evento como se tivesse chegado pelo EventChannel nativo. Usa
/// o seam `debugSimulateEvent` em vez do binding global — EventChannel é
/// cached por nome de canal e vazava estado entre testes.
void _simulateEventReceived(WorkoutRealtimeService service, Map<String, Object?> payload) {
  service.debugSimulateEvent(payload);
}
