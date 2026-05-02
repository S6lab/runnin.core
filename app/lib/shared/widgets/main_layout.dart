import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:runnin/core/theme/app_palette.dart';

class MainLayout extends StatelessWidget {
  final Widget child;
  const MainLayout({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final location = GoRouterState.of(context).matchedLocation;

    return Scaffold(
      body: child,
      bottomNavigationBar: _BottomNav(currentLocation: location),
    );
  }
}

class _BottomNav extends StatelessWidget {
  final String currentLocation;
  const _BottomNav({required this.currentLocation});

  @override
  Widget build(BuildContext context) {
    final palette = context.runninPalette;
    final type = context.runninType;

    final leftItems = [
      _NavItem(icon: Icons.home_outlined, label: 'HOME', path: '/home'),
      _NavItem(icon: Icons.calendar_today_outlined, label: 'TREINO', path: '/training'),
    ];
    final rightItems = [
      _NavItem(icon: Icons.history_outlined, label: 'HIST', path: '/history'),
      _NavItem(icon: Icons.person_outline, label: 'PERFIL', path: '/profile'),
    ];

    return Container(
      decoration: BoxDecoration(
        color: palette.surface,
        border: Border(top: BorderSide(color: palette.border)),
      ),
      child: SafeArea(
        child: SizedBox(
          height: 64,
          child: Row(
            children: [
              // Itens esquerda
              ...leftItems.map((item) {
                final isActive = currentLocation.startsWith(item.path);
                return Expanded(
                  child: InkWell(
                    onTap: () => context.go(item.path),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          item.icon,
                          size: 20,
                          color: isActive ? palette.primary : palette.muted,
                        ),
                        const SizedBox(height: 3),
                        Text(
                          item.label,
                          style: type.labelCaps.copyWith(
                            color: isActive ? palette.primary : palette.muted,
                            fontSize: 9,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }),

              // Botão RUN central — retangular conforme protótipo
              GestureDetector(
                onTap: () => context.push('/prep'),
                child: Container(
                  width: 72,
                  height: 64,
                  color: palette.primary,
                  alignment: Alignment.center,
                  child: Text(
                    'RUN',
                    style: type.labelCaps.copyWith(
                      color: palette.background,
                      fontSize: 11,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.15,
                    ),
                  ),
                ),
              ),

              // Itens direita
              ...rightItems.map((item) {
                final isActive = currentLocation.startsWith(item.path);
                return Expanded(
                  child: InkWell(
                    onTap: () => context.go(item.path),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          item.icon,
                          size: 20,
                          color: isActive ? palette.primary : palette.muted,
                        ),
                        const SizedBox(height: 3),
                        Text(
                          item.label,
                          style: type.labelCaps.copyWith(
                            color: isActive ? palette.primary : palette.muted,
                            fontSize: 9,
                          ),
                        ),
                      ],
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
  final String path;
  const _NavItem({required this.icon, required this.label, required this.path});
}
