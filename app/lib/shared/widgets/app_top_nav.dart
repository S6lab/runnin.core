import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTopNav extends StatelessWidget {
  final String sectionLabel;

  const AppTopNav({
    super.key,
    required this.sectionLabel,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 16, 20, 17.735),
      decoration: BoxDecoration(
        color: const Color(0xEB050510),
        border: Border(
          bottom: BorderSide(
            color: Color(0xFFFFFFFF),
            width: 1.041,
          ),
        ),
      ),
      height: 54.7,
      child: Row(
        children: [
          const _LogoLockup(),
          const SizedBox(width: 4),
          const _Separator(),
          const SizedBox(width: 4),
          Text(
            sectionLabel,
            style: GoogleFonts.jetBrainsMono(
              fontSize: 13,
              fontWeight: FontWeight.w400,
              letterSpacing: 1.3,
              color: const Color(0x8CFFFFFF),
            ),
          ),
        ],
      ),
    );
  }
}

class _LogoLockup extends StatelessWidget {
  const _LogoLockup();

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'RUNNIN',
          style: GoogleFonts.jetBrainsMono(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            letterSpacing: 1.4,
            color: const Color(0xFFFFFFFF),
          ),
        ),
        const SizedBox(width: 4),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          color: const Color(0xFF00D4FF),
          child: Text(
            '.AI',
            style: GoogleFonts.jetBrainsMono(
              fontSize: 9,
              fontWeight: FontWeight.w500,
              color: const Color(0xFF050510),
            ),
          ),
        ),
      ],
    );
  }
}

class _Separator extends StatelessWidget {
  const _Separator();

  @override
  Widget build(BuildContext context) {
    return Text(
      '/',
      style: GoogleFonts.jetBrainsMono(
        fontSize: 12,
        fontWeight: FontWeight.w400,
        letterSpacing: 0,
        color: const Color(0x1FFFFFFF),
      ),
    );
  }
}
