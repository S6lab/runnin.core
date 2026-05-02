import 'package:dio/dio.dart';
import 'package:firebase_auth/firebase_auth.dart';

const _defaultProdBaseUrl =
    'https://runnin-api-rogiz7losq-rj.a.run.app/v1';
const _baseUrlFromEnv = String.fromEnvironment('API_BASE_URL', defaultValue: '');

String _resolveBaseUrl() {
  if (_baseUrlFromEnv.trim().isEmpty) return _defaultProdBaseUrl;
  return _normalizeBaseUrl(_baseUrlFromEnv.trim());
}

String _normalizeBaseUrl(String raw) {
  var base = raw;
  while (base.endsWith('/')) {
    base = base.substring(0, base.length - 1);
  }
  if (!base.endsWith('/v1')) {
    base = '$base/v1';
  }
  return base;
}

Dio createApiClient() {
  final dio = Dio(BaseOptions(
    baseUrl: _resolveBaseUrl(),
    connectTimeout: const Duration(seconds: 10),
    receiveTimeout: const Duration(seconds: 30),
    headers: {'Content-Type': 'application/json'},
  ));

  // Injeta token Firebase em toda request autenticada
  dio.interceptors.add(InterceptorsWrapper(
    onRequest: (options, handler) async {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final token = await user.getIdToken();
        options.headers['Authorization'] = 'Bearer $token';
      }
      handler.next(options);
    },
    onError: (err, handler) {
      // Token expirado — tenta renovar e refaz a request
      if (err.response?.statusCode == 401) {
        FirebaseAuth.instance.currentUser?.getIdToken(true);
      }
      handler.next(err);
    },
  ));

  return dio;
}

final apiClient = createApiClient();
