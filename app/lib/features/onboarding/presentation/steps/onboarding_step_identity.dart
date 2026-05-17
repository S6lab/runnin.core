import 'package:flutter/material.dart';
import 'package:runnin/shared/widgets/figma/export.dart';

class OnboardingStepIdentity extends StatelessWidget {
  final TextEditingController nameController;
  final TextEditingController birthDateController;

  const OnboardingStepIdentity({
    super.key,
    required this.nameController,
    required this.birthDateController,
  });

  Future<void> _pickDate(BuildContext context) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now().subtract(const Duration(days: 365 * 25)),
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      birthDateController.text =
          '${picked.day.toString().padLeft(2, '0')}/${picked.month.toString().padLeft(2, '0')}/${picked.year}';
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
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
            readOnly: true,
            onTap: () => _pickDate(context),
            placeholder: 'dd/mm/aaaa',
          ),
        ],
      ),
    );
  }
}
