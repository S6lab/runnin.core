import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:runnin/core/theme/app_palette.dart';

/// Renderizado quando o GoRouter não consegue resolver uma rota. Antes:
/// `GoException` tela branca + crash silencioso. Agora: mensagem amigável
/// + auto-redirect pra /home em 1.5s (preserva o user no fluxo).
///
/// O caminho problemático é logado pelo errorBuilder do appRouter via
/// Logger.error('router.no_route', ...) — o user vê o fallback aqui e o
/// Crashlytics captura pra root cause posterior.
class RouterFallbackPage extends StatefulWidget {
  final String path;

  const RouterFallbackPage({super.key, required this.path});

  @override
  State<RouterFallbackPage> createState() => _RouterFallbackPageState();
}

class _RouterFallbackPageState extends State<RouterFallbackPage> {
  Timer? _redirect;

  @override
  void initState() {
    super.initState();
    _redirect = Timer(const Duration(milliseconds: 1500), () {
      if (mounted) context.go('/home');
    });
  }

  @override
  void dispose() {
    _redirect?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.runninPalette;
    return Scaffold(
      backgroundColor: palette.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.error_outline, color: palette.muted, size: 36),
              const SizedBox(height: 16),
              Text(
                'Tela não encontrada',
                style: context.runninType.displayMd.copyWith(
                  color: palette.text,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Voltando pra Home em instantes…',
                style: context.runninType.bodyMd.copyWith(color: palette.muted),
              ),
              const SizedBox(height: 24),
              TextButton(
                onPressed: () => context.go('/home'),
                child: Text(
                  'Voltar agora',
                  style: context.runninType.labelMd.copyWith(
                    color: palette.primary,
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
