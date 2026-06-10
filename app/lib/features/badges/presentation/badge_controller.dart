import 'package:flutter/foundation.dart';
import 'package:runnin/core/logger/logger.dart';
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

  /// True se o último refresh/checkRecentUnseen falhou. UI usa pra
  /// mostrar erro com retry em vez de "Nenhum badge ainda" — diferenciar
  /// "vazio porque novato" de "vazio porque rede/server falhou".
  bool _lastErrored = false;
  bool get lastErrored => _lastErrored;

  /// TF 79: próximo badge mais próximo de desbloquear (teaser na home).
  /// Carregado via `loadNext()` e cacheado até o próximo refresh.
  NextBadgeProgress? _nextBadge;
  NextBadgeProgress? get nextBadge => _nextBadge;

  /// TF 79: catálogo completo (atingidos + bloqueados) pra galeria.
  /// Carregado via `loadCatalog()`.
  List<BadgeCatalogEntry> _catalog = const [];
  List<BadgeCatalogEntry> get catalog => _catalog;

  Future<void> refresh() async {
    _loading = true;
    notifyListeners();
    try {
      _all = await _ds.getMine();
      _lastErrored = false;
    } catch (e, st) {
      _lastErrored = true;
      // Logger.error vai pro analytics/Crashlytics — diagnosticável remoto.
      Logger.error('badges.refresh.fail', e, st);
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  /// Chamado no app boot/resume. Se há novo badge não-visto, popa o mais
  /// recente. Se já visto, segue silencioso.
  Future<void> checkRecentUnseen() async {
    try {
      final unseen = await _ds.getRecentUnseen();
      if (unseen.isEmpty) return;
      _pendingPopup = unseen.first;
      notifyListeners();
    } catch (e, st) {
      Logger.error('badges.recent_unseen.fail', e, st);
    }
  }

  Future<void> dismissPopup() async {
    final b = _pendingPopup;
    _pendingPopup = null;
    notifyListeners();
    if (b != null) {
      try {
        await _ds.markSeen(b.badgeId);
      } catch (e, st) {
        Logger.error('badges.mark_seen.fail', e, st, {'badgeId': b.badgeId});
      }
    }
  }

  Future<void> trackShare(String badgeId) async {
    try {
      await _ds.trackShare(badgeId);
    } catch (e, st) {
      Logger.error('badges.share.fail', e, st, {'badgeId': badgeId});
    }
  }

  /// Carrega o próximo badge mais perto de desbloquear. Chamado pelo card
  /// teaser da home no boot/resume. Best-effort: falha silenciosa não
  /// quebra a home; só não mostra o card.
  Future<void> loadNext() async {
    try {
      _nextBadge = await _ds.getNext();
      notifyListeners();
    } catch (e, st) {
      Logger.error('badges.next.fail', e, st);
    }
  }

  /// Carrega o catálogo completo dos badges (atingidos + bloqueados). Usado
  /// pela galeria pra mostrar tudo de uma vez, com cadeado nos locked.
  Future<void> loadCatalog() async {
    _loading = true;
    notifyListeners();
    try {
      _catalog = await _ds.getCatalog();
      _lastErrored = false;
    } catch (e, st) {
      _lastErrored = true;
      Logger.error('badges.catalog.fail', e, st);
    } finally {
      _loading = false;
      notifyListeners();
    }
  }
}
