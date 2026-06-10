import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:runnin/core/theme/context_extension.dart';
import 'package:runnin/features/badges/domain/entities/badge.dart' as badge_e;

/// Card visual do badge — reusa em popup, galeria, share.
/// Cores 100% dinâmicas via `context.runninPalette` (segue skin do user).
class BadgeCardView extends StatelessWidget {
  final badge_e.Badge badge;
  /// Quando true (galeria), reduz padding e esconde footer "compartilhar".
  final bool compact;

  const BadgeCardView({
    super.key,
    required this.badge,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final palette = context.runninPalette;
    final type = context.runninType;
    // Cor dominante do card vem do skin do user. Layout: hero em primary,
    // texto em background (alto contraste sobre cor dominante).
    final bg = palette.primary;
    final fg = _onColor(bg);
    final mutedFg = fg.withValues(alpha: 0.7);
    final faintFg = fg.withValues(alpha: 0.5);

    return Container(
      decoration: BoxDecoration(
        color: bg,
        borderRadius: compact ? BorderRadius.circular(12) : BorderRadius.zero,
      ),
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 18 : 28,
        vertical: compact ? 20 : 32,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header: RUNIN.AI logo + chip
          Row(
            children: [
              Text(
                'RUNNIN.AI',
                style: type.labelCaps.copyWith(
                  color: fg,
                  fontSize: compact ? 10 : 12,
                  letterSpacing: 1.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const Spacer(),
              if (badge.badgeChip != null)
                Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: compact ? 8 : 10,
                    vertical: compact ? 4 : 5,
                  ),
                  decoration: BoxDecoration(
                    color: fg.withValues(alpha: 0.12),
                  ),
                  child: Text(
                    badge.badgeChip!,
                    style: type.labelCaps.copyWith(
                      color: fg,
                      fontSize: compact ? 9 : 10,
                      letterSpacing: 0.8,
                    ),
                  ),
                ),
            ],
          ),

          SizedBox(height: compact ? 18 : 36),

          // Hero: número gigante
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Flexible(
                child: Text(
                  badge.primaryDisplay,
                  maxLines: 1,
                  style: TextStyle(
                    color: fg,
                    fontSize: compact ? 64 : 96,
                    fontWeight: FontWeight.w900,
                    height: 0.95,
                    letterSpacing: -2,
                    fontFamily: 'monospace',
                  ),
                ),
              ),
              if (badge.primaryUnit != null) ...[
                const SizedBox(width: 6),
                Padding(
                  padding: EdgeInsets.only(bottom: compact ? 8 : 16),
                  child: Text(
                    badge.primaryUnit!,
                    style: type.labelMd.copyWith(
                      color: mutedFg,
                      fontSize: compact ? 14 : 20,
                    ),
                  ),
                ),
              ],
            ],
          ),

          SizedBox(height: compact ? 8 : 12),

          // Subtítulo caps
          Text(
            badge.title.toUpperCase(),
            style: type.labelCaps.copyWith(
              color: fg,
              fontSize: compact ? 11 : 13,
              letterSpacing: 1.5,
              fontWeight: FontWeight.w600,
            ),
          ),

          SizedBox(height: compact ? 4 : 6),

          // Subtítulo + descrição curta
          Text(
            badge.subtitle,
            style: type.bodyMd.copyWith(
              color: mutedFg,
              fontSize: compact ? 12 : 14,
            ),
          ),

          if (!compact) ...[
            const SizedBox(height: 6),
            Text(
              'Atingido em ${_fmtDate(badge.unlockedAt)}',
              style: type.bodyXs.copyWith(
                color: faintFg,
                fontSize: 11,
              ),
            ),
          ],

          SizedBox(height: compact ? 14 : 28),

          // Stats grid
          if (!compact) _StatsGrid(badge: badge, fg: fg, mutedFg: mutedFg),

          if (!compact) ...[
            const SizedBox(height: 24),
            // Footer: handle + url. Nome vem do Firebase Auth (displayName ou
            // primeiro pedaço do email como fallback). Sem hardcode "Lucas".
            Row(
              children: [
                Text(
                  _userHandle(),
                  style: type.bodyXs.copyWith(color: faintFg, fontSize: 11),
                ),
                const Spacer(),
                Text(
                  'runnin.ai',
                  style: type.bodyXs.copyWith(color: faintFg, fontSize: 11),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  String _fmtDate(int ms) {
    if (ms <= 0) return '';
    return DateFormat('dd MMM yyyy', 'pt_BR').format(
      DateTime.fromMillisecondsSinceEpoch(ms),
    );
  }

  /// Handle do user no footer do card. Prioridade: displayName do Firebase
  /// Auth → primeiro pedaço do email → "Runner" como fallback genérico.
  String _userHandle() {
    final user = FirebaseAuth.instance.currentUser;
    final name = user?.displayName?.trim();
    if (name != null && name.isNotEmpty) return name.split(' ').first;
    final email = user?.email?.trim();
    if (email != null && email.isNotEmpty) return email.split('@').first;
    return 'Runner';
  }

  /// Decide texto branco ou preto baseado na luminância da cor dominante.
  /// Skins variam (cyan claro / verde / magenta / verde-amarelado) — força
  /// contraste correto.
  Color _onColor(Color bg) {
    final l = (0.299 * bg.r + 0.587 * bg.g + 0.114 * bg.b) / 255;
    return l > 0.6 ? const Color(0xFF0A0A0F) : Colors.white;
  }
}

class _StatsGrid extends StatelessWidget {
  final badge_e.Badge badge;
  final Color fg;
  final Color mutedFg;
  const _StatsGrid({required this.badge, required this.fg, required this.mutedFg});

  @override
  Widget build(BuildContext context) {
    final s = badge.stats;
    final cells = <_StatCell>[];
    if (s.distanceKm != null) {
      cells.add(_StatCell('DISTÂNCIA', '${s.distanceKm!.toStringAsFixed(1)}km'));
    }
    if (s.paceMinKm != null) {
      cells.add(_StatCell('PACE', '${s.paceMinKm}/km'));
    }
    if (s.durationS != null) {
      cells.add(_StatCell('DURAÇÃO', _fmtDuration(s.durationS!)));
    }
    if (s.bestPaceMinKm != null) {
      cells.add(_StatCell('MELHOR PACE', '${s.bestPaceMinKm}/km'));
    }
    if (s.avgBpm != null) {
      cells.add(_StatCell('FC MÉDIA', '${s.avgBpm}'));
    }
    if (s.weekKm != null) {
      cells.add(_StatCell('SEMANA', '${s.weekKm!.toStringAsFixed(1)}km'));
    }
    if (s.monthKm != null) {
      cells.add(_StatCell('MÊS', '${s.monthKm!.toStringAsFixed(1)}km'));
    }
    if (cells.isEmpty) return const SizedBox.shrink();

    // Grid 2 colunas
    final rows = <Widget>[];
    for (var i = 0; i < cells.length; i += 2) {
      final right = i + 1 < cells.length ? cells[i + 1] : null;
      rows.add(_buildRow(context, cells[i], right));
      if (i + 2 < cells.length) rows.add(const SizedBox(height: 12));
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: rows,
    );
  }

  Widget _buildRow(BuildContext context, _StatCell left, _StatCell? right) {
    final type = context.runninType;
    return Row(
      children: [
        Expanded(child: _cell(type, left)),
        const SizedBox(width: 12),
        Expanded(child: right != null ? _cell(type, right) : const SizedBox.shrink()),
      ],
    );
  }

  Widget _cell(dynamic type, _StatCell c) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: fg.withValues(alpha: 0.10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            c.label,
            style: type.labelCaps.copyWith(
              color: mutedFg,
              fontSize: 10,
              letterSpacing: 1.0,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            c.value,
            style: type.labelMd.copyWith(
              color: fg,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  String _fmtDuration(int s) {
    final h = s ~/ 3600;
    final m = (s % 3600) ~/ 60;
    if (h > 0) return '${h}h${m.toString().padLeft(2, '0')}m';
    return '${m}min';
  }
}

class _StatCell {
  final String label;
  final String value;
  const _StatCell(this.label, this.value);
}
