import 'dart:async';

import 'package:flutter/material.dart';
import 'package:runnin/core/theme/app_palette.dart';

/// Botão de reenvio de OTP/SMS com timer de cooldown.
///
/// Quando o cooldown está ativo, exibe "Reenviar em 0:45" e fica desabilitado.
/// Quando zera, vira clicável "Reenviar código" e dispara [onResend], que pode
/// reiniciar o cooldown chamando [restart] via [controller].
class OtpResendButton extends StatefulWidget {
  final OtpResendController controller;
  final Future<void> Function() onResend;
  final Duration cooldown;

  const OtpResendButton({
    super.key,
    required this.controller,
    required this.onResend,
    this.cooldown = const Duration(seconds: 60),
  });

  @override
  State<OtpResendButton> createState() => _OtpResendButtonState();
}

class _OtpResendButtonState extends State<OtpResendButton> {
  Timer? _ticker;
  int _remaining = 0;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    widget.controller._attach(this);
    _start();
  }

  @override
  void dispose() {
    widget.controller._detach(this);
    _ticker?.cancel();
    super.dispose();
  }

  void _start() {
    _ticker?.cancel();
    setState(() => _remaining = widget.cooldown.inSeconds);
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      if (_remaining <= 1) {
        _ticker?.cancel();
        setState(() => _remaining = 0);
      } else {
        setState(() => _remaining -= 1);
      }
    });
  }

  Future<void> _handleTap() async {
    if (_busy || _remaining > 0) return;
    setState(() => _busy = true);
    try {
      await widget.onResend();
      if (mounted) _start();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.runninPalette;
    final canResend = _remaining == 0 && !_busy;
    final label = _busy
        ? 'Reenviando...'
        : _remaining > 0
            ? 'Reenviar em ${_formatRemaining(_remaining)}'
            : 'Reenviar código';

    return GestureDetector(
      onTap: canResend ? _handleTap : null,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              canResend ? Icons.refresh : Icons.timer_outlined,
              size: 14,
              color: canResend ? palette.primary : palette.muted,
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                letterSpacing: 0.04,
                color: canResend ? palette.primary : palette.muted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

String _formatRemaining(int seconds) {
  final m = seconds ~/ 60;
  final s = seconds % 60;
  return '$m:${s.toString().padLeft(2, '0')}';
}

/// Permite ao chamador reiniciar o cooldown manualmente, tipicamente após
/// o `_sendPhoneCode` inicial concluir com sucesso.
class OtpResendController {
  _OtpResendButtonState? _state;

  void _attach(_OtpResendButtonState state) => _state = state;
  void _detach(_OtpResendButtonState state) {
    if (identical(_state, state)) _state = null;
  }

  void restart() => _state?._start();
}
