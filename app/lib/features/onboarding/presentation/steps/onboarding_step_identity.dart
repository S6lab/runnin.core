import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:runnin/shared/widgets/figma/export.dart';

class OnboardingStepIdentity extends StatelessWidget {
  final TextEditingController nameController;
  final TextEditingController birthDateController;

  const OnboardingStepIdentity({
    super.key,
    required this.nameController,
    required this.birthDateController,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 12),
        const FigmaAssessmentHeading(text: 'Como te chamo?'),
        const SizedBox(height: 10),
        const FigmaAssessmentDescription(
          text:
              'Nome e data de nascimento ajudam o Coach a personalizar comunicacao, zonas e progressao.',
        ),
        const SizedBox(height: 28),
        const FigmaFormFieldLabel(text: 'SEU NOME'),
        const SizedBox(height: 8),
        FigmaFormTextField(
          controller: nameController,
          autofocus: true,
          textCapitalization: TextCapitalization.words,
          height: 51.5,
          placeholder: 'Ex: Lucas',
        ),
        const SizedBox(height: 28),
        const FigmaFormFieldLabel(text: 'DATA DE NASCIMENTO'),
        const SizedBox(height: 8),
        FigmaFormTextField(
          controller: birthDateController,
          height: 51.5,
          keyboardType: TextInputType.datetime,
          placeholder: 'dd/mm/aaaa',
          inputFormatters: [
            FilteringTextInputFormatter.digitsOnly,
            _BirthDateMaskFormatter(),
            LengthLimitingTextInputFormatter(10),
          ],
        ),
      ],
    );
  }
}

/// Formata input numérico contínuo em dd/mm/aaaa.
class _BirthDateMaskFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final digits = newValue.text.replaceAll(RegExp(r'[^0-9]'), '');
    final buf = StringBuffer();
    for (var i = 0; i < digits.length && i < 8; i++) {
      if (i == 2 || i == 4) buf.write('/');
      buf.write(digits[i]);
    }
    final formatted = buf.toString();
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}
