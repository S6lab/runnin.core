import 'package:flutter_test/flutter_test.dart';
import 'package:runnin/features/run/domain/entities/run.dart';

// ~0.0001° de latitude ≈ 11.12m (mesma longitude). Usado pra montar pontos
// a uma distância conhecida sem depender de lng.
const _degPerMeterLat = 0.0001 / 11.12;

GpsPoint _pt(double metersFromBase, int tsMs) => GpsPoint(
      lat: -23.5 + metersFromBase * _degPerMeterLat,
      lng: -46.6,
      ts: tsMs,
      accuracy: 5,
    );

void main() {
  group('rollingPaceMinKm', () {
    test('lista vazia ou com 1 ponto → null', () {
      expect(rollingPaceMinKm(const []), isNull);
      expect(rollingPaceMinKm([_pt(0, 0)]), isNull);
    });

    test('correndo a ~5:00/km → pace plausível', () {
      // ~3.333 m/s, 1 ponto/s por 15s.
      final pts = List.generate(15, (i) => _pt(i * 3.333, i * 1000));
      final pace = rollingPaceMinKm(pts);
      expect(pace, isNotNull);
      expect(pace!, closeTo(5.0, 0.5));
    });

    test('parado (sem deslocamento) → null', () {
      // 30 pontos no mesmo lugar ao longo de 30s.
      final pts = List.generate(30, (i) => _pt(0, i * 1000));
      expect(rollingPaceMinKm(pts), isNull);
    });

    test('drift minúsculo (velocidade ~0) → null, não pace absurdo', () {
      // Antes: pos.speed ~0.07 m/s → pace ~235 min/km exibido. Agora a janela
      // junta pouca distância em muito tempo → pace > maxPaceMinKm → null.
      final pts = [_pt(0, 0), _pt(10, 25000)]; // 10m em 25s = 0.4 m/s ≈ 41/km
      expect(rollingPaceMinKm(pts), isNull);
    });
  });
}
