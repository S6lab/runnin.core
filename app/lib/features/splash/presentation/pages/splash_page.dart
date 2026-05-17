import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:runnin/core/theme/design_system_tokens.dart';

/// Splash screen per `docs/figma/screens/SPLASH.md` (Figma node 1:4283).
///
/// Renders the brand lockup centered on a dark background, then advances to
/// `/onboarding` after [duration]. The router's redirect logic takes over
/// from there based on auth + onboarding cache state.
class SplashPage extends StatefulWidget {
  const SplashPage({super.key, this.duration = const Duration(milliseconds: 1800)});

  final Duration duration;

  @override
  State<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends State<SplashPage>
    with SingleTickerProviderStateMixin {
  Timer? _advanceTimer;
  late final AnimationController _fadeController;
  late final Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
    _fadeAnimation =
        Tween<double>(begin: 1.0, end: 0.0).animate(_fadeController);
    _advanceTimer = Timer(widget.duration, _advance);
  }

  @override
  void dispose() {
    _advanceTimer?.cancel();
    _fadeController.dispose();
    super.dispose();
  }

  Future<void> _advance() async {
    if (!mounted) return;
    await _fadeController.forward();
    if (!mounted) return;
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      context.go('/home');
      return;
    }
    final box = Hive.isBoxOpen('runnin_settings')
        ? Hive.box<dynamic>('runnin_settings')
        : await Hive.openBox<dynamic>('runnin_settings');
    final introSeen = (box.get('intro_seen') as bool?) ?? false;
    if (!mounted) return;
    context.go(introSeen ? '/login' : '/intro');
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      // Tap to skip — common UX courtesy.
      onTap: () {
        _advanceTimer?.cancel();
        _advance();
      },
      child: Scaffold(
        backgroundColor: FigmaColors.bgBase,
        body: FadeTransition(
          opacity: _fadeAnimation,
          child: const Center(
            child: SizedBox(
              width: 201.59,
              height: 109.95,
              child: _SplashLockup(),
            ),
          ),
        ),
      ),
    );
  }
}

/// Brand lockup: "RUNNIN .AI" wordmark + tagline + cyan accent line.
class _SplashLockup extends StatelessWidget {
  const _SplashLockup();

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        // Wordmark + .AI badge — top of the lockup
        const Positioned(left: 26.64, top: 0, child: _SplashWordmark()),
        // Tagline — opacity 40% per Figma container opacity spec
        Positioned(
          left: 0,
          top: 57.98,
          child: SizedBox(
            width: 201.59,
            child: Opacity(
              opacity: 0.40,
              child: Text(
                'FEITO PARA VENCEDORES',
                textAlign: TextAlign.center,
                style: GoogleFonts.jetBrainsMono(
                  fontSize: 12,
                  height: 18 / 12,
                  letterSpacing: 2.4,
                  fontWeight: FontWeight.w400,
                  color: FigmaColors.textSecondary,
                ),
              ),
            ),
          ),
        ),
        // Decorative cyan line
        const Positioned(
          left: 36.78,
          top: 107.96,
          child: SizedBox(
            width: 121.93,
            height: 2,
            child: ColoredBox(color: FigmaColors.brandCyan),
          ),
        ),
      ],
    );
  }
}

/// "RUNNIN" wordmark + cyan ".AI" badge, in a row with 5.99px gap.
class _SplashWordmark extends StatelessWidget {
  const _SplashWordmark();

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Runnin AI',
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            'RUNNIN',
            style: GoogleFonts.jetBrainsMono(
              fontSize: 28,
              height: 42 / 28,
              letterSpacing: 3.36,
              fontWeight: FontWeight.w500,
              color: FigmaColors.textPrimary,
            ),
          ),
          const SizedBox(width: 5.99),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            color: FigmaColors.brandCyan,
            child: Text(
              '.AI',
              style: GoogleFonts.jetBrainsMono(
                fontSize: 12,
                height: 18 / 12,
                fontWeight: FontWeight.w500,
                color: FigmaColors.bgBase,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
