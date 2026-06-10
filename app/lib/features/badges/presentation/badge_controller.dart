import 'package:flutter/foundation.dart';
import 'package:runnin/features/badges/data/badge_remote_datasource.dart';
import 'package:runnin/features/badges/domain/entities/badge.dart';

/// Controlador simples (ChangeNotifier) — carrega galeria + popup.
/// Não usa BLoC pra não puxar dependência adicional; segue padrão dos
/// outros controllers globais (themeController, locationWeatherController).
class BadgeController extends ChangeNotifier {
  BadgeController._();
  static final instance = BadgeController._();

  final BadgeRemoteDatasource _ds = BadgeRemoteDatasource();

  List<Badge> _all = const [];
  List<Badge> get all => _all;

  Badge? _pendingPopup;
  Badge? get pendingPopup => _pendingPopup;

  bool _loading = false;
  bool get loading => _loading;

  Future<void> refresh() async {
    _loading = true;
    notifyListeners();
    try {
      _all = await _ds.getMine();
    } catch (_) {/* best-effort */}
    _loading = false;
    notifyListeners();
  }

  /// Chamado no app boot/resume. Se há novo badge não-visto, popa o mais
  /// recente. Se já visto, segue silencioso.
  Future<void> checkRecentUnseen() async {
    try {
      final unseen = await _ds.getRecentUnseen();
      if (unseen.isEmpty) return;
      _pendingPopup = unseen.first;
      notifyListeners();
    } catch (_) {/* ignore */}
  }

  Future<void> dismissPopup() async {
    final b = _pendingPopup;
    _pendingPopup = null;
    notifyListeners();
    if (b != null) {
      try {
        await _ds.markSeen(b.badgeId);
      } catch (_) {/* ignore */}
    }
  }

  Future<void> trackShare(String badgeId) async {
    try {
      await _ds.trackShare(badgeId);
    } catch (_) {/* ignore */}
  }
}
