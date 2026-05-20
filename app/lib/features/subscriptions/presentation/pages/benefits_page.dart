import 'package:flutter/material.dart';
import 'package:runnin/core/theme/app_palette.dart';
import 'package:runnin/features/subscriptions/data/benefit_remote_datasource.dart';
import 'package:runnin/features/subscriptions/domain/benefit.dart';
import 'package:runnin/features/subscriptions/presentation/benefit_controller.dart';
import 'package:runnin/features/subscriptions/presentation/subscription_controller.dart';
import 'package:runnin/shared/widgets/app_panel.dart';
import 'package:runnin/shared/widgets/figma/figma_top_nav.dart';

/// Perfil → Conta → VERIFICAR BENEFÍCIO. Lista as assinaturas de benefício do
/// usuário e permite ativar as que ainda não foram ativadas.
class BenefitsPage extends StatefulWidget {
  const BenefitsPage({super.key});

  @override
  State<BenefitsPage> createState() => _BenefitsPageState();
}

class _BenefitsPageState extends State<BenefitsPage> {
  final _ds = BenefitRemoteDatasource();
  List<Benefit>? _benefits;
  bool _loading = true;
  String? _activatingId;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final list = await _ds.listBenefits();
    if (mounted) {
      setState(() {
        _benefits = list;
        _loading = false;
      });
    }
  }

  Future<void> _activate(Benefit b) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: context.runninPalette.surface,
        title: const Text('Ativar benefício?'),
        content: Text(
          'Ativar o ${b.planName} (${b.providerName}) na sua conta?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('CANCELAR'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('ATIVAR'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    setState(() => _activatingId = b.id);
    try {
      await _ds.activate(b.id);
      await subscriptionController.refresh();
      benefitController.clear();
      await _load();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Não foi possível ativar agora.')),
        );
      }
    } finally {
      if (mounted) setState(() => _activatingId = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.runninPalette;
    final type = context.runninType;
    final benefits = _benefits ?? [];

    return Scaffold(
      backgroundColor: palette.background,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const FigmaTopNav(breadcrumb: 'BENEFÍCIOS', showBackButton: true),
            Expanded(
              child: _loading
                  ? Center(child: CircularProgressIndicator(color: palette.primary))
                  : benefits.isEmpty
                      ? _EmptyBenefits()
                      : ListView(
                          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                          children: [
                            Text(
                              'Seus benefícios de parceiro.',
                              style: type.bodyMd.copyWith(color: palette.muted),
                            ),
                            const SizedBox(height: 16),
                            ...benefits.map((b) => Padding(
                                  padding: const EdgeInsets.only(bottom: 12),
                                  child: _BenefitCard(
                                    benefit: b,
                                    activating: _activatingId == b.id,
                                    onActivate: () => _activate(b),
                                  ),
                                )),
                          ],
                        ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BenefitCard extends StatelessWidget {
  final Benefit benefit;
  final bool activating;
  final VoidCallback onActivate;
  const _BenefitCard({
    required this.benefit,
    required this.activating,
    required this.onActivate,
  });

  @override
  Widget build(BuildContext context) {
    final palette = context.runninPalette;
    final type = context.runninType;
    return AppPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.card_giftcard, size: 18, color: palette.primary),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  '${benefit.planName} · ${benefit.providerName}',
                  style: type.bodyMd.copyWith(
                    color: palette.text,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              if (benefit.isActivated)
                Icon(Icons.check_circle, size: 18, color: palette.primary),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            benefit.isActivated
                ? 'Benefício ativo na sua conta.'
                : '${benefit.priceLabel} ${benefit.periodLabel}'.trim(),
            style: type.bodySm.copyWith(color: palette.muted),
          ),
          if (!benefit.isActivated) ...[
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              height: 46,
              child: ElevatedButton(
                onPressed: activating ? null : onActivate,
                style: ElevatedButton.styleFrom(
                  backgroundColor: palette.primary,
                  foregroundColor: palette.background,
                  shape: const RoundedRectangleBorder(
                    borderRadius: BorderRadius.zero,
                  ),
                ),
                child: activating
                    ? SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: palette.background,
                        ),
                      )
                    : Text(
                        'ATIVAR',
                        style: type.labelMd.copyWith(
                          fontWeight: FontWeight.w500,
                          letterSpacing: 1.2,
                        ),
                      ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _EmptyBenefits extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final palette = context.runninPalette;
    final type = context.runninType;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.card_giftcard_outlined, size: 40, color: palette.border),
            const SizedBox(height: 12),
            Text(
              'Nenhum benefício encontrado pra sua conta.',
              textAlign: TextAlign.center,
              style: type.bodyMd.copyWith(color: palette.muted),
            ),
          ],
        ),
      ),
    );
  }
}
