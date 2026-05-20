import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:runnin/core/theme/app_palette.dart';
import 'package:runnin/features/subscriptions/data/benefit_remote_datasource.dart';
import 'package:runnin/features/subscriptions/domain/benefit.dart';
import 'package:runnin/features/subscriptions/presentation/benefit_controller.dart';
import 'package:runnin/features/subscriptions/presentation/subscription_controller.dart';
import 'package:runnin/shared/widgets/runnin_app_bar.dart';

/// Tela exibida no fim do onboarding QUANDO há um benefício de parceiro
/// disponível (substitui o paywall do Pro). Mostra o parceiro + plano e um
/// botão de ativar com confirmação. Após ativar, migra o plano e segue pra
/// geração do plano de treino.
class BenefitActivationPage extends StatefulWidget {
  const BenefitActivationPage({super.key, this.startDate});

  /// D0 do plano (vem do onboarding). Após ativar, gera o plano em /plan-loading.
  final String? startDate;

  @override
  State<BenefitActivationPage> createState() => _BenefitActivationPageState();
}

class _BenefitActivationPageState extends State<BenefitActivationPage> {
  final _ds = BenefitRemoteDatasource();
  bool _activating = false;
  String? _error;

  Future<void> _activate(Benefit benefit) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: context.runninPalette.surface,
        title: const Text('Ativar benefício?'),
        content: Text(
          'Vamos ativar o ${benefit.planName} (${benefit.providerName}) na sua conta. '
          'Você passa a ter o plano completo do coach.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('AGORA NÃO'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('ATIVAR'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() {
      _activating = true;
      _error = null;
    });
    try {
      await _ds.activate(benefit.id);
      await subscriptionController.refresh();
      benefitController.clear();
      if (!mounted) return;
      // Plano do benefício é Pro → gera o plano de treino.
      if (subscriptionController.has('generatePlan')) {
        context.go('/plan-loading?startDate=${widget.startDate ?? ''}');
      } else {
        context.go('/home');
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Não foi possível ativar agora. Tente de novo.';
          _activating = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.runninPalette;
    final type = context.runninType;
    final benefit = benefitController.pending;

    // Sem benefício (ex: deep-link direto) → segue o fluxo normal.
    if (benefit == null) {
      return Scaffold(
        backgroundColor: palette.background,
        appBar: const RunninAppBar(title: 'BENEFÍCIO', fallbackRoute: '/home'),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Nenhum benefício disponível agora.',
                  style: type.bodyMd.copyWith(color: palette.muted),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                OutlinedButton(
                  onPressed: () => context.go('/home'),
                  child: const Text('CONTINUAR'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: palette.background,
      appBar: const RunninAppBar(title: 'BENEFÍCIO', fallbackRoute: '/home'),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.card_giftcard, size: 24, color: palette.primary),
                  const SizedBox(width: 10),
                  Text(
                    'BENEFÍCIO ENCONTRADO',
                    style: type.labelCaps.copyWith(
                      fontSize: 12,
                      color: palette.primary,
                      letterSpacing: 1.4,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                'Você tem um benefício ${benefit.providerName}.',
                style: type.displayMd.copyWith(
                  fontSize: 26,
                  color: palette.text,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: palette.surface,
                  border: Border.all(color: palette.primary, width: 1.041),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      benefit.planName,
                      style: type.dataXs.copyWith(color: palette.text),
                    ),
                    if (benefit.priceLabel.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(
                        '${benefit.priceLabel} ${benefit.periodLabel}'.trim(),
                        style: type.bodySm.copyWith(color: palette.muted),
                      ),
                    ],
                    const SizedBox(height: 12),
                    Text(
                      'Plano completo do coach: plano de treino personalizado por IA, '
                      'coach ao vivo durante a corrida, análise pós-corrida, relatórios '
                      'semanais e integração com wearable.',
                      style: type.bodyMd.copyWith(color: palette.text, height: 1.5),
                    ),
                  ],
                ),
              ),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(_error!, style: type.bodySm.copyWith(color: palette.error)),
              ],
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: _activating ? null : () => _activate(benefit),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: palette.primary,
                    foregroundColor: palette.background,
                    shape: const RoundedRectangleBorder(
                      borderRadius: BorderRadius.zero,
                    ),
                  ),
                  child: _activating
                      ? SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: palette.background,
                          ),
                        )
                      : Text(
                          'ATIVAR BENEFÍCIO',
                          style: type.labelMd.copyWith(
                            fontWeight: FontWeight.w500,
                            letterSpacing: 1.2,
                          ),
                        ),
                ),
              ),
              const SizedBox(height: 10),
              TextButton(
                onPressed: _activating ? null : () => context.go('/home'),
                child: Text(
                  'AGORA NÃO',
                  style: type.labelCaps.copyWith(
                    color: palette.muted,
                    letterSpacing: 1.0,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
