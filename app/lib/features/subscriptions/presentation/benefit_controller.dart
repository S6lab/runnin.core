import 'package:flutter/foundation.dart';
import 'package:runnin/features/subscriptions/data/benefit_remote_datasource.dart';
import 'package:runnin/features/subscriptions/domain/benefit.dart';

/// Controller global dos benefícios de parceiro. A busca roda silenciosamente
/// no login; se houver um benefício NÃO ativado, a jornada de fim de onboarding
/// troca a tela de "assinar Pro" pela tela de ativação do benefício.
class BenefitController extends ChangeNotifier {
  final BenefitRemoteDatasource _ds = BenefitRemoteDatasource();
  Benefit? _pending;

  /// Benefício pendente (encontrado e ainda não ativado).
  Benefit? get pending => _pending;
  bool get hasPending => _pending != null;

  /// Busca silenciosa — nunca lança. Guarda o 1º benefício não ativado.
  Future<void> lookup() async {
    try {
      final list = await _ds.listBenefits();
      _pending = list.where((b) => !b.isActivated).isEmpty
          ? null
          : list.firstWhere((b) => !b.isActivated);
    } catch (_) {
      _pending = null;
    }
    notifyListeners();
  }

  void clear() {
    _pending = null;
    notifyListeners();
  }
}

final benefitController = BenefitController();
