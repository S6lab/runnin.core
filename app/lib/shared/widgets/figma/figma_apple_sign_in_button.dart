import 'package:flutter/material.dart';
import 'package:runnin/core/theme/design_system_tokens.dart';

class FigmaAppleSignInButton extends StatelessWidget {
  final VoidCallback? onPressed;

  const FigmaAppleSignInButton({super.key, this.onPressed});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        width: double.infinity,
        constraints: const BoxConstraints(minHeight: 48.5),
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
        decoration: BoxDecoration(
          color: const Color(0x0CFFFFFF),
          border: Border.all(
            width: 1.041,
            color: FigmaColors.borderInput,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.apple, color: Colors.white, size: 18),
            const SizedBox(width: AppSpacing.sm),
            const Text(
              'ENTRAR COM APPLE',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
