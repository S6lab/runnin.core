import 'dart:async';
import 'package:flutter/material.dart';
import 'package:runnin/core/theme/app_palette.dart';
import 'package:runnin/features/admin/domain/registry_entries.dart';

/// Badge visual mostrando o estado de override de uma superfície editável:
///  - "USANDO DEFAULT" (cinza): sem override em Firestore
///  - "EM CACHE Ns" (amarelo): override existe mas server ainda pode estar
///    servindo cache antigo (contagem regressiva)
///  - "ATIVO" (verde): override existe e cache TTL já expirou — server
///    consumindo o valor novo
class OverrideStatusBadge extends StatefulWidget {
  final OverrideStatus status;
  final bool dense;

  const OverrideStatusBadge({super.key, required this.status, this.dense = false});

  @override
  State<OverrideStatusBadge> createState() => _OverrideStatusBadgeState();
}

class _OverrideStatusBadgeState extends State<OverrideStatusBadge> {
  Timer? _ticker;
  late int _countdown;
  late String _state;

  @override
  void initState() {
    super.initState();
    _refresh();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      _refresh();
    });
  }

  @override
  void didUpdateWidget(covariant OverrideStatusBadge oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.status.overrideAt != widget.status.overrideAt ||
        oldWidget.status.hasOverride != widget.status.hasOverride) {
      _refresh();
    }
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  void _refresh() {
    setState(() {
      _state = widget.status.visualState;
      _countdown = widget.status.cacheCountdownSec;
    });
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.runninPalette;
    late final Color color;
    late final String label;
    switch (_state) {
      case 'active':
        color = const Color(0xFF22C55E); // green
        label = 'ATIVO';
        break;
      case 'cached':
        color = const Color(0xFFFFB020); // amber
        label = _countdown > 0 ? 'EM CACHE ${_countdown}s' : 'PROPAGANDO…';
        break;
      default:
        color = palette.muted;
        label = 'USANDO DEFAULT';
    }
    final pad = widget.dense
        ? const EdgeInsets.symmetric(horizontal: 6, vertical: 2)
        : const EdgeInsets.symmetric(horizontal: 8, vertical: 4);
    return Tooltip(
      message: _buildTooltip(),
      child: Container(
        padding: pad,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          border: Border.all(color: color.withValues(alpha: 0.5)),
        ),
        child: Text(
          label,
          style: context.runninType.labelCaps.copyWith(
            fontSize: widget.dense ? 9 : 10,
            fontWeight: FontWeight.w600,
            color: color,
          ),
        ),
      ),
    );
  }

  String _buildTooltip() {
    final s = widget.status;
    final parts = <String>[
      'Cache TTL: ${s.cacheTtlSec}s',
      'Consumer: ${s.consumer}',
      if (s.overrideAt != null) 'Override em: ${s.overrideAt}',
    ];
    return parts.join('\n');
  }
}
