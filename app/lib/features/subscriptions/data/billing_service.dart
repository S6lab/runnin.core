import 'package:dio/dio.dart';
import 'package:runnin/core/logger/logger.dart';
import 'package:runnin/core/network/api_client.dart';
import 'package:runnin/features/subscriptions/presentation/subscription_controller.dart';

/// Resultado de uma tentativa de compra/assinatura. Caller (Paywall) usa
/// pra decidir: navigate next, exibir banner de erro, ou silenciar (cancel).
class BillingPurchaseResult {
  const BillingPurchaseResult.success() : error = null, cancelled = false;
  const BillingPurchaseResult.cancelled() : error = null, cancelled = true;
  const BillingPurchaseResult.failed(this.error) : cancelled = false;

  final String? error;
  final bool cancelled;
  bool get isSuccess => error == null && !cancelled;
}

/// Abstração da camada de billing. Hoje uma implementação mock troca o
/// flag `premium` no backend via PATCH /users/me; quando integrarmos com
/// RevenueCat, criamos `RevenueCatBillingService implements BillingService`
/// e trocamos o singleton no final do arquivo. Paywall não muda.
///
/// Pontos de integração futuros (RevenueCat):
///   - [purchase]: chamar `Purchases.purchasePackage(...)` com o pkg
///     do offering atual e converter `CustomerInfo.entitlements` em
///     premium flag no nosso backend.
///   - [restorePurchases]: `Purchases.restorePurchases()` + reportar
///     entitlements ao backend pra sincronizar.
///   - [getOfferings]: `Purchases.getOfferings()` pra preços localizados
///     da App Store / Play Store em vez do priceLabel do server.
abstract class BillingService {
  /// Compra/assina o pacote premium. Implementações reais (RevenueCat)
  /// abrirão a sheet de pagamento nativa do StoreKit/Play Billing.
  Future<BillingPurchaseResult> purchase({String productId = 'pro_monthly'});

  /// Restaura compras feitas em outros devices (App Store / Play Store).
  /// No mock atual é no-op + refresh do controller; com RevenueCat
  /// chamará `Purchases.restorePurchases()`.
  Future<BillingPurchaseResult> restorePurchases();
}

/// Implementação atual: PATCH /users/me {premium: true}.
/// Sem cobrança real. Útil pra dev/QA e flow do paywall em TestFlight
/// sem precisar configurar produtos no App Store Connect ainda.
class MockBillingService implements BillingService {
  MockBillingService({Dio? dio}) : _dio = dio ?? apiClient;

  final Dio _dio;

  @override
  Future<BillingPurchaseResult> purchase({String productId = 'pro_monthly'}) async {
    try {
      await _dio.patch<void>('/users/me', data: {'premium': true});
      await subscriptionController.refresh();
      Logger.info('billing.mock.purchase_ok', context: {'productId': productId});
      return const BillingPurchaseResult.success();
    } on DioException catch (e, st) {
      Logger.error('billing.mock.purchase_failed', e, st, {
        'productId': productId,
        'status': '${e.response?.statusCode}',
      });
      return BillingPurchaseResult.failed('Não foi possível assinar agora.');
    } catch (e, st) {
      Logger.error('billing.mock.purchase_failed', e, st);
      return const BillingPurchaseResult.failed('Erro inesperado.');
    }
  }

  @override
  Future<BillingPurchaseResult> restorePurchases() async {
    try {
      await subscriptionController.refresh();
      Logger.info('billing.mock.restore_ok');
      return const BillingPurchaseResult.success();
    } catch (e, st) {
      Logger.error('billing.mock.restore_failed', e, st);
      return const BillingPurchaseResult.failed('Não foi possível restaurar.');
    }
  }
}

/// Singleton ativo. Troca pra `RevenueCatBillingService()` quando o SDK
/// for adicionado e o entitlement "pro" estiver configurado no dashboard.
BillingService billingService = MockBillingService();
