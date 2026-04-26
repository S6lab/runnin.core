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

    final leftItems = [
      _NavItem(icon: Icons.home_outlined, label: 'HOME', path: '/home'),
      _NavItem(
        icon: Icons.calendar_today_outlined,
        label: 'TREINO',
        path: '/training',
      ),
    ];
    final rightItems = [
      _NavItem(icon: Icons.history_outlined, label: 'HIST', path: '/history'),
      _NavItem(icon: Icons.person_outline, label: 'CONTA', path: '/profile'),
    ];

    return Container(
      decoration: BoxDecoration(
        color: palette.surface,
        border: Border(top: BorderSide(color: palette.border)),
      ),
      child: SafeArea(
        child: SizedBox(
          height: 60,
          child: Row(
            children: [
              // Itens da esquerda
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
                        const SizedBox(height: 2),
                        Text(
                          item.label,
                          style: TextStyle(
                            fontSize: 9,
                            letterSpacing: 0.08,
                            fontWeight: FontWeight.w700,
                            color: isActive ? palette.primary : palette.muted,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }),

              // Botão RUN central
              SizedBox(
                width: 72,
                child: GestureDetector(
                  onTap: () => context.push('/prep'),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: palette.primary,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.play_arrow,
                          color: Colors.black,
                          size: 22,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'RUN',
                        style: TextStyle(
                          fontSize: 9,
                          letterSpacing: 0.08,
                          fontWeight: FontWeight.w900,
                          color: palette.primary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Itens da direita
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
                        const SizedBox(height: 2),
                        Text(
                          item.label,
                          style: TextStyle(
                            fontSize: 9,
                            letterSpacing: 0.08,
                            fontWeight: FontWeight.w700,
                            color: isActive ? palette.primary : palette.muted,
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
