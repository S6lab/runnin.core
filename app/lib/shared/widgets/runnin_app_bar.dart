import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:runnin/core/theme/app_palette.dart';

/// Padrão único de header pra páginas do app.
///
/// Substitui o legado AppPageHeader e a Row+IconButton ad-hoc espalhada
/// em várias pages. Garante back button funcional + título consistente.
///
/// Comportamento do back:
/// - Se `onBack` informado, executa
/// - Senão, GoRouter.canPop() ? pop : ir pra `fallbackRoute` (default '/home')
class RunninAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final String? subtitle;
  final bool showBack;
  final VoidCallback? onBack;
  final String fallbackRoute;
  final List<Widget> actions;

  const RunninAppBar({
    super.key,
    required this.title,
    this.subtitle,
    this.showBack = true,
    this.onBack,
    this.fallbackRoute = '/home',
    this.actions = const [],
  });

  @override
  Size get preferredSize => Size.fromHeight(subtitle != null ? 72 : 56);

  @override
  Widget build(BuildContext context) {
    final palette = context.runninPalette;

    return Container(
      decoration: BoxDecoration(
        color: palette.background,
        border: Border(
          bottom: BorderSide(color: palette.border, width: 1.041),
        ),
      ),
      padding: EdgeInsets.fromLTRB(
        showBack ? 4 : 20,
        MediaQuery.of(context).padding.top,
        4,
        0,
      ),
      child: SizedBox(
        height: subtitle != null ? 72 : 56,
        child: Row(
          children: [
            if (showBack)
              IconButton(
                tooltip: 'Voltar',
                icon: const Icon(Icons.arrow_back, size: 22),
                color: palette.text,
                onPressed: () => _handleBack(context),
              ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.jetBrainsMono(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.4,
                      color: palette.text,
                    ),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      subtitle!,
                      style: GoogleFonts.jetBrainsMono(
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        color: palette.muted,
                        letterSpacing: 0.8,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            ...actions,
            const SizedBox(width: 8),
          ],
        ),
      ),
    );
  }

  void _handleBack(BuildContext context) {
    if (onBack != null) {
      onBack!();
      return;
    }
    final router = GoRouter.of(context);
    if (router.canPop()) {
      router.pop();
    } else {
      router.go(fallbackRoute);
    }
  }
}
