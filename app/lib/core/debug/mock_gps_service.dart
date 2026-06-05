import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';

/// Simula o stream de posições do GPS pra debug em simulator (que tem
/// localização estática) ou pra testar fluxo de corrida sem precisar
/// estar correndo de verdade.
///
/// **Apenas em [kDebugMode]** — em release, [enabled] sempre retorna false
/// independentemente do que foi setado, e [stream] retorna um Stream vazio.
///
/// Uso (já integrado no [RunBloc]):
/// ```
/// mockGpsService.enabled = true;
/// mockGpsService.paceMinKm = 7.0;
/// // RunBloc._onStart troca Geolocator.getPositionStream pelo mock
/// ```
///
/// Trajeto: linha reta a partir de [start] no bearing 0° (norte), com
/// passo proporcional ao pace. Suficiente pra exercitar km_reached,
/// splits, coach cues. Pace é editável on-the-fly.
class MockGpsService {
  MockGpsService._();
  static final MockGpsService instance = MockGpsService._();

  bool _enabled = false;
  double _paceMinKm = 7.0;
  // São Paulo - Av Paulista como ponto de partida default. Troque pelo
  // que quiser exercitar (geocercas de algum POI específico, etc).
  double _startLat = -23.5613;
  double _startLng = -46.6565;

  /// Liga/desliga o mock. Em release sempre false (guard via [kDebugMode]).
  bool get enabled => kDebugMode && _enabled;
  set enabled(bool v) {
    if (!kDebugMode) return;
    _enabled = v;
  }

  /// Pace alvo em min/km. 7.0 = 7:00/km ≈ 2.38 m/s.
  double get paceMinKm => _paceMinKm;
  set paceMinKm(double v) {
    if (v > 0) _paceMinKm = v;
  }

  /// Coordenadas iniciais do trajeto mock. Troque antes de ligar o mock.
  void setStart({required double lat, required double lng}) {
    _startLat = lat;
    _startLng = lng;
  }

  /// Stream que emite [Position] a cada 1s, deslocando o ponto pra norte
  /// com velocidade derivada do [paceMinKm] atual. Reposiciona a cada
  /// `listen` (não mantém estado entre subs).
  Stream<Position> stream() async* {
    if (!enabled) return;
    var lat = _startLat;
    var lng = _startLng;
    final stopwatch = Stopwatch()..start();

    // Mete uma primeira posição imediatamente pra a UI sair do "AGUARDANDO".
    yield _build(lat, lng, 0);

    while (enabled) {
      await Future<void>.delayed(const Duration(seconds: 1));
      if (!enabled) break;
      final speedMs = 1000 / (_paceMinKm * 60); // m/s do pace atual
      // 1° latitude ≈ 111000m. Avanço puro pra norte simplifica
      // (longitude varia com cos(lat), mas no eixo norte só lat muda).
      lat += speedMs / 111000.0;
      yield _build(lat, lng, speedMs, elapsed: stopwatch.elapsed);
    }
  }

  Position _build(double lat, double lng, double speedMs, {Duration? elapsed}) {
    return Position(
      latitude: lat,
      longitude: lng,
      timestamp: DateTime.now(),
      accuracy: 5,
      altitude: 750,
      altitudeAccuracy: 5,
      heading: 0,
      headingAccuracy: 5,
      speed: speedMs,
      speedAccuracy: 0.5,
      isMocked: true,
    );
  }
}

/// Atalho top-level no padrão do app (alinhado com healthSyncService,
/// workoutRealtimeService, etc).
final mockGpsService = MockGpsService.instance;
