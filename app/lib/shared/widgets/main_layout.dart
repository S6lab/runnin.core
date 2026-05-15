import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'figma/export.dart';

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
    int currentIndex = 0;
    if (currentLocation.startsWith('/training')) {
      currentIndex = 1;
    } else if (currentLocation.startsWith('/prep')) {
      currentIndex = 2;
    } else if (currentLocation.startsWith('/history')) {
      currentIndex = 3;
    } else if (currentLocation.startsWith('/profile')) {
      currentIndex = 4;
    }

    return FigmaBottomNav(
      currentIndex: currentIndex,
      onTap: (index) {
        switch (index) {
          case 0:
            context.go('/home');
            break;
          case 1:
            context.go('/training');
            break;
          case 2:
            context.push('/prep');
            break;
          case 3:
            context.go('/history');
            break;
          case 4:
            context.go('/profile');
            break;
        }
      },
    );
  }
}
