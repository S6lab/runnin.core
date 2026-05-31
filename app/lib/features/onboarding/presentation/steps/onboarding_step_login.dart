import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:runnin/core/theme/app_palette.dart';
import 'package:runnin/features/onboarding/presentation/steps/onboarding_shared.dart';
import 'package:runnin/shared/widgets/figma/export.dart';
import 'package:runnin/shared/widgets/otp_resend_button.dart';

class OnboardingStepLogin extends StatelessWidget {
  final TextEditingController phoneController;
  final TextEditingController smsCodeController;
  final bool codeRequested;
  final bool loading;
  final VoidCallback onGoogleSignIn;
  final OtpResendController resendController;
  final Future<void> Function() onResendCode;
  final String? error;
  final String? message;

  const OnboardingStepLogin({
    super.key,
    required this.phoneController,
    required this.smsCodeController,
    required this.codeRequested,
    required this.loading,
    required this.onGoogleSignIn,
    required this.resendController,
    required this.onResendCode,
    required this.error,
    required this.message,
  });

  @override
  Widget build(BuildContext context) {
    final palette = context.runninPalette;

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 80),
          Text(
            '// LOGIN',
            style: context.runninType.labelMd.copyWith(color: palette.primary),
          ),
          const SizedBox(height: 14),
          Text('Entre na corrida', style: context.runninType.displayMd),
          const SizedBox(height: 28),
          const FigmaFormFieldLabel(text: 'TELEFONE'),
          const SizedBox(height: 8),
          FigmaFormTextField(
            controller: phoneController,
            keyboardType: TextInputType.phone,
            placeholder: '+55 (11) 99999-9999',
            maxLength: 14,
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[0-9+]')),
            ],
          ),
          const SizedBox(height: 18),
          const FigmaFormFieldLabel(text: 'CODIGO OTP'),
          const SizedBox(height: 8),
          FigmaOtpTextField(
            controller: smsCodeController,
            enabled: codeRequested,
          ),
          if (codeRequested) ...[
            const SizedBox(height: 8),
            OtpResendButton(
              controller: resendController,
              onResend: onResendCode,
            ),
          ],
          const SizedBox(height: 18),
          FigmaGoogleSignInButton(
            onPressed: loading ? null : onGoogleSignIn,
          ),
          if (message != null) ...[
            const SizedBox(height: 16),
            OnboardingInlineNotice(text: message!, color: palette.primary),
          ],
          if (error != null) ...[
            const SizedBox(height: 16),
            OnboardingInlineNotice(text: error!, color: palette.error),
          ],
        ],
      ),
    );
  }
}
