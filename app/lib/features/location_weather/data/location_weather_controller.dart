import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:runnin/core/logger/logger.dart';
import 'package:runnin/core/network/api_client.dart';

/// Snapshot de clima retornado pelo /v1/weather/current. Strings null
/// quando API falhou ou permissão não foi concedida.
class WeatherSnapshot {
  final double temperatureC;
  final int humidityPercent;
  final double windKmh;
  final DateTime fetchedAt;

  const WeatherSnapshot({
    required this.temperatureC,
    required this.humidityPercent,
    required this.windKmh,
    required this.fetchedAt,
  });

  factory WeatherSnapshot.fromJson(Map<String, dynamic> j) => WeatherSnapshot(
        temperatureC: (j['temperatureC'] as num).toDouble(),
        humidityPercent: (j['humidityPercent'] as num).toInt(),
        windKmh: (j['windKmh'] as num).toDouble(),
        fetchedAt: DateTime.parse(j['fetchedAt'] as String),
      );
}

/// Controller global de cidade + clima, alimentado por GPS do device.
/// Padrão singleton (igual ao subscriptionController). Estado começa
/// vazio; home chama `initIfNeeded()` no primeiro build e dispara
/// permissão + reverse geocode + clima em paralelo. Se user negar,
/// `permissionGranted` vira false e o resto fica null silenciosamente.
class LocationWeatherController extends ChangeNotifier {
  String? _city;
  WeatherSnapshot? _weather;
  double? _lat;
  double? _lng;
  bool _initialized = false;
  bool _loading = false;
  bool _permissionGranted = false;

  String? get city => _city;
  WeatherSnapshot? get weather => _weather;
  double? get lat => _lat;
  double? get lng => _lng;
  bool get permissionGranted => _permissionGranted;
  bool get loading => _loading;

  /// Idempotente. Chamar várias vezes não dispara múltiplos fetches.
  Future<void> initIfNeeded() async {
    if (_initialized || _loading) return;
    _loading = true;
    notifyListeners();
    try {
      // Web/iOS exigem requestPermission no gesture; aqui no init da home
      // não temos gesture, então fazemos checkPermission primeiro e só
      // pedimos se for necessário (na primeira vez). Se negado, sai
      // silencioso — sem modal, sem re-prompt.
      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm != LocationPermission.always &&
          perm != LocationPermission.whileInUse) {
        _permissionGranted = false;
        _initialized = true;
        return;
      }
      final serviceOn = await Geolocator.isLocationServiceEnabled();
      if (!serviceOn) {
        _permissionGranted = false;
        _initialized = true;
        return;
      }
      _permissionGranted = true;

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.low,
          timeLimit: Duration(seconds: 8),
        ),
      );
      _lat = position.latitude;
      _lng = position.longitude;

      // Dispara cidade + clima em paralelo — independentes.
      await Future.wait([_fetchCity(), _fetchWeather()]);
      _initialized = true;
    } catch (_) {
      _initialized = true;
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<void> _fetchCity() async {
    if (_lat == null || _lng == null) return;
    try {
      final res = await apiClient.post(
        '/users/me/location',
        data: {'lat': _lat, 'lng': _lng},
      );
      final data = res.data as Map<String, dynamic>;
      _city = data['city'] as String?;
    } catch (e, st) {
      // UI fica sem cidade (header funciona normal), mas o erro vira
      // breadcrumb pro Crashlytics — debugamos 404/401/timeout depois.
      Logger.warn('location.fetch_city_failed', context: {'err': '$e'});
      Logger.error('location.fetch_city_failed', e, st);
    }
  }

  Future<void> _fetchWeather() async {
    if (_lat == null || _lng == null) return;
    try {
      final res = await apiClient.get(
        '/weather/current',
        queryParameters: {'lat': _lat, 'lng': _lng},
      );
      if (res.statusCode == 204 || res.data == null) return;
      _weather = WeatherSnapshot.fromJson(res.data as Map<String, dynamic>);
    } catch (e, st) {
      Logger.warn('location.fetch_weather_failed', context: {'err': '$e'});
      Logger.error('location.fetch_weather_failed', e, st);
    }
  }
}

final locationWeatherController = LocationWeatherController();
