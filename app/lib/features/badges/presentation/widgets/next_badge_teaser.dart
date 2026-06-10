import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:runnin/core/theme/context_extension.dart';
import 'package:runnin/features/badges/presentation/badge_controller.dart';

/// TF 79: card permanente na home mostrando o badge mais próximo de
/// desbloquear (server calcula via `GET /badges/next`). Quando o user
/// ainda está a < 5% do próximo, server retorna null e este widget some.
/// Tap leva pra galeria `/profile/badges`.
class NextBadgeTeaser extends StatelessWidget {
  const NextBadgeTeaser({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: BadgeController.instance,
      builder: (context, _) {
        final next = BadgeController.instance.nextBadge;
        if (next == null) return const SizedBox.shrink();
        final palette = context.runninPalette;
        final type = context.runninType;
        final pct = (next.progress * 100).clamp(0, 100).toStringAsFixed(0);
        return GestureDetector(
          onTap: () => context.push('/profile/badges'),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: palette.primary.withValues(alpha: 0.08),
              border: Border.all(
                color: palette.primary.withValues(alpha: 0.35),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.emoji_events_outlined,
                        size: 16, color: palette.primary),
                    const SizedBox(width: 6),
                    Text(
                      'PRÓXIMO BADGE',
                      style: type.labelCaps.copyWith(
                        color: palette.primary,
                        fontSize: 10.5,
                        letterSpacing: 1.2,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      '$pct%',
                      style: type.labelCaps.copyWith(
                        color: palette.primary,
                        fontSize: 11.0,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  next.title,
                  style: type.labelMd.copyWith(
                    color: palette.text,
                    fontSize: 16.0,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  next.remaining,
                  style: type.bodySm.copyWith(
                    color: palette.muted,
                    fontSize: 12.5,
                  ),
                ),
                const SizedBox(height: 10),
                ClipRect(
                  child: Stack(
                    children: [
                      Container(
                        height: 4,
                        color: palette.primary.withValues(alpha: 0.15),
                      ),
                      FractionallySizedBox(
                        widthFactor: next.progress.clamp(0.0, 1.0),
                        child: Container(
                          height: 4,
                          color: palette.primary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
