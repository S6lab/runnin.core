import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';

/// Gate de manutenção / atualização obrigatória via Firebase Remote Config.
///
/// Chaves no Remote Config (console):
///  - `min_app_version` (String): versão mínima suportada (ex: "1.1.0"). Se a
///    versão do app for inferior, bloqueia com a tela de atualização.
///  - `update_url` (String): link da loja/atualização que o botão abre.
///  - `maintenance_mode` (bool): bloqueia o app inteiro (janela de manutenção),
///    independente da versão.
///  - `maintenance_message` (String): texto exibido no modo manutenção.
///
/// Fail-open: se o Remote Config falhar (offline, timeout), NÃO bloqueia o app.
class ForceUpdateController extends ChangeNotifier {
  bool _blocked = false;
  bool _maintenance = false;
  String _message = '';
  String _updateUrl = '';

  /// True quando o app deve exibir a tela de bloqueio (manutenção ou update).
  bool get blocked => _blocked;
  bool get isMaintenance => _maintenance;
  String get message => _message;
  String get updateUrl => _updateUrl;

  Future<void> check() async {
    try {
      final rc = FirebaseRemoteConfig.instance;
      await rc.setConfigSettings(RemoteConfigSettings(
        fetchTimeout: const Duration(seconds: 8),
        minimumFetchInterval: const Duration(minutes: 15),
      ));
      await rc.setDefaults(const {
        'min_app_version': '0.0.0',
        'update_url': '',
        'maintenance_mode': false,
        'maintenance_message':
            'Estamos em manutenção rápida. Volte em instantes.',
      });
      await rc.fetchAndActivate();

      final minVersion = rc.getString('min_app_version');
      _updateUrl = rc.getString('update_url');
      _maintenance = rc.getBool('maintenance_mode');
      final maintMsg = rc.getString('maintenance_message');

      final info = await PackageInfo.fromPlatform();
      final belowMin = _isBelow(info.version, minVersion);

      if (_maintenance) {
        _blocked = true;
        _message = maintMsg;
      } else if (belowMin) {
        _blocked = true;
        _message =
            'Saiu uma versão nova do runnin. Atualize o app pra continuar.';
      } else {
        _blocked = false;
      }
      notifyListeners();
    } catch (e) {
      // Fail-open: erro de config não pode travar o app.
      if (kDebugMode) {
        // ignore: avoid_print
        print('[force_update] check failed: $e');
      }
    }
  }

  /// `current` < `min` por semver (major.minor.patch; partes ausentes = 0).
  bool _isBelow(String current, String min) {
    final c = _parts(current);
    final m = _parts(min);
    for (var i = 0; i < 3; i++) {
      if (c[i] < m[i]) return true;
      if (c[i] > m[i]) return false;
    }
    return false;
  }

  List<int> _parts(String v) {
    // Descarta build (+N) e pré-release (-x); pega major.minor.patch.
    final core = v.split('+').first.split('-').first.trim();
    final segs = core.split('.');
    return List.generate(3, (i) {
      if (i >= segs.length) return 0;
      return int.tryParse(segs[i].replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
    });
  }
}

final forceUpdateController = ForceUpdateController();
