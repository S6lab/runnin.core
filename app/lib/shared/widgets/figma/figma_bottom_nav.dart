import 'package:flutter/material.dart';
import 'package:runnin/core/theme/app_palette.dart';

class FigmaBottomNav extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;

  const FigmaBottomNav({
    super.key,
    required this.currentIndex,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final palette = context.runninPalette;
    const double navHeight = 78.591;

    final items = [
      _NavItem(icon: Icons.home, label: 'HOME', path: 0),
      _NavItem(icon: Icons.directions_run, label: 'TREINO', path: 1),
      _NavItem(icon: Icons.play_arrow, label: 'RUN', path: 2),
      _NavItem(icon: Icons.history, label: 'HIST', path: 3),
      _NavItem(icon: Icons.person, label: 'PERFIL', path: 4),
    ];

    return Container(
      decoration: BoxDecoration(
        color: palette.background,
        border: Border(top: BorderSide(color: palette.border)),
      ),
      child: SafeArea(
        child: SizedBox(
          height: navHeight,
          child: Row(
            children: [
              ...items.asMap().entries.map((entry) {
                final index = entry.key;
                final item = entry.value;

                if (item.label == 'RUN') {
                  return Expanded(
                    child: _RunFAB(onPressed: () => onTap(2)),
                  );
                }

                final isActive = currentIndex == index;
                // Inactive em cinza neutro (sem matiz da skin); só o ativo
                // recebe a cor do tema. Mantém o RUN central já colorido.
                const inactiveColor = Color(0xFF6B7280);
                final color = isActive ? palette.primary : inactiveColor;
                return Expanded(
                  child: InkWell(
                    onTap: () => onTap(index),
                    borderRadius: BorderRadius.zero,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(item.icon, size: 20, color: color),
                          const SizedBox(height: 4),
                          Text(
                            item.label,
                            style: TextStyle(
                              color: color,
                              fontSize: 10,
                              fontWeight: FontWeight.w500,
                              letterSpacing: 0.5,
                            ),
                          ),
                          if (isActive) ...[
                            const SizedBox(height: 3),
                            Container(
                              height: 1.979,
                              width: 19.98,
                              color: palette.primary,
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                );
              }),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavItem {
  final IconData icon;
  final String label;
  final int path;

  const _NavItem({required this.icon, required this.label, required this.path});
}

class _RunFAB extends StatelessWidget {
  final VoidCallback onPressed;

  const _RunFAB({required this.onPressed});

  @override
  Widget build(BuildContext context) {
    final palette = context.runninPalette;

    return InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.zero,
      child: Container(
        width: 55.982,
        height: 55.982,
        decoration: BoxDecoration(
          color: palette.primary,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.4),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Center(
          child: Text(
            'RUN',
            style: TextStyle(
              color: palette.background,
              fontSize: 18,
              fontWeight: FontWeight.w700,
              fontStyle: FontStyle.italic,
            ),
          ),
        ),
      ),
    );
  }
}
