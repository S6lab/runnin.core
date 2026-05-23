import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:runnin/core/theme/app_palette.dart';
import 'package:runnin/shared/widgets/app_panel.dart';

/// Card padrão pra bloquear feature Premium e empurrar pro paywall.
/// Usado tanto inline (substituindo seções da home) quanto full-screen
/// (TrainingPage / PlanSetupPage / CoachLivePage quando freemium).
///
/// Visual: AppPanel com ícone de cadeado + título + descrição + botão CTA.
/// O CTA navega pra `/paywall?next=$next` — quando o user assina, o paywall
/// volta pra rota original. `next` default é `/home`.
class PremiumLockedCard extends StatelessWidget {
  final String title;
  final String description;
  final String ctaLabel;
  final IconData icon;
  final String next;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry margin;

  const PremiumLockedCard({
    super.key,
    required this.title,
    required this.description,
    this.ctaLabel = 'DESBLOQUEAR PREMIUM',
    this.icon = Icons.lock_outline,
    this.next = '/home',
    this.padding = const EdgeInsets.all(20),
    this.margin = EdgeInsets.zero,
  });

  void _openPaywall(BuildContext context) {
    final encoded = Uri.encodeQueryComponent(next);
    context.push('/paywall?next=$encoded');
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.runninPalette;
    final type = context.runninType;
    return AppPanel(
      padding: padding,
      margin: margin,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Icon(icon, color: palette.primary, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: type.labelMd,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            description,
            style: type.bodySm.copyWith(color: palette.muted),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            height: 44,
            child: ElevatedButton(
              onPressed: () => _openPaywall(context),
              child: Text(ctaLabel),
            ),
          ),
        ],
      ),
    );
  }
}
