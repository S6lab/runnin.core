import 'package:flutter/material.dart';
import 'package:runnin/core/theme/app_palette.dart';
import 'package:runnin/shared/widgets/figma/export.dart';

/// Intro da criação do plano: avisa que as próximas perguntas moldam o plano.
/// Extraído do onboarding pra ser reusado na jornada de criação do plano em
/// TREINO.
class OnboardingPrepStep extends StatelessWidget {
  const OnboardingPrepStep({super.key});

  @override
  Widget build(BuildContext context) {
    final palette = context.runninPalette;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 12),
        const FigmaAssessmentLabel(text: '// SEU PLANO'),
        const SizedBox(height: 14),
        const FigmaAssessmentHeading(text: 'Vamos montar SEU plano.'),
        const SizedBox(height: 18),
        Text(
          'Pra ter o melhor resultado, preciso da sua atenção total e honestidade nas próximas perguntas.',
          style: context.runninType.bodyMd.copyWith(color: palette.text, height: 1.55),
        ),
        const SizedBox(height: 14),
        Text(
          'Nível, objetivo, frequência, pace e data de início moldam cada sessão do seu plano.',
          style: context.runninType.bodyMd.copyWith(color: palette.muted, height: 1.55),
        ),
        const SizedBox(height: 18),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: palette.primary.withValues(alpha: 0.08),
            border: Border.all(color: palette.primary.withValues(alpha: 0.4), width: 1),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.info_outline, size: 18, color: palette.primary),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Quanto mais preciso, mais o coach acerta a carga e a progressão do seu plano.',
                  style: context.runninType.bodySm.copyWith(
                    color: palette.text,
                    height: 1.45,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        Text(
          'Bora? Toque CONTINUAR pra começar.',
          style: context.runninType.bodyMd.copyWith(
            color: palette.primary,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

/// Step de data de início (D0). User escolhe HOJE, AMANHÃ, PRÓXIMA SEGUNDA ou
/// CUSTOM. Toda a periodização começa nessa data. Extraído do onboarding pra
/// reuso na jornada de criação do plano.
class OnboardingStartDateStep extends StatelessWidget {
  final String selected;
  final DateTime customDate;
  final void Function(String choice, DateTime date) onSelect;

  const OnboardingStartDateStep({
    super.key,
    required this.selected,
    required this.customDate,
    required this.onSelect,
  });

  /// D0 default (hoje, à meia-noite). Público pra a jornada de criação do
  /// plano inicializar o estado sem duplicar a lógica.
  static DateTime today() {
    final n = DateTime.now();
    return DateTime(n.year, n.month, n.day);
  }

  static DateTime _today() => today();

  static DateTime _tomorrow() => _today().add(const Duration(days: 1));

  static DateTime _nextMonday() {
    final t = _today();
    final dow = t.weekday; // Mon=1...Sun=7
    final daysAhead = dow == 1 ? 7 : (8 - dow);
    return t.add(Duration(days: daysAhead));
  }

  String _fmt(DateTime d) {
    const names = ['', 'segunda', 'terça', 'quarta', 'quinta', 'sexta', 'sábado', 'domingo'];
    return '${names[d.weekday]} · ${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.runninPalette;
    final today = _today();
    final tomorrow = _tomorrow();
    final nextMonday = _nextMonday();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 12),
        const FigmaAssessmentHeading(text: 'Quando você quer começar?'),
        const SizedBox(height: 10),
        FigmaAssessmentDescription(
          text:
              'A semana 1 e a periodização toda começam nessa data. O coach respeita o D0 que você escolher.',
        ),
        const SizedBox(height: 24),
        _DateChoice(
          label: 'COMEÇAR HOJE',
          subtitle: _fmt(today),
          selected: selected == 'today',
          onTap: () => onSelect('today', today),
        ),
        const SizedBox(height: 8),
        _DateChoice(
          label: 'AMANHÃ',
          subtitle: _fmt(tomorrow),
          selected: selected == 'tomorrow',
          onTap: () => onSelect('tomorrow', tomorrow),
        ),
        const SizedBox(height: 8),
        _DateChoice(
          label: 'PRÓXIMA SEGUNDA',
          subtitle: _fmt(nextMonday),
          selected: selected == 'next_monday',
          onTap: () => onSelect('next_monday', nextMonday),
        ),
        const SizedBox(height: 8),
        _DateChoice(
          label: 'ESCOLHER DATA',
          subtitle: selected == 'custom'
              ? _fmt(customDate)
              : 'toque pra abrir o calendário',
          selected: selected == 'custom',
          onTap: () async {
            final picked = await showDatePicker(
              context: context,
              initialDate: customDate,
              firstDate: today,
              lastDate: today.add(const Duration(days: 60)),
            );
            if (picked != null) onSelect('custom', picked);
          },
        ),
        const SizedBox(height: 18),
        Padding(
          padding: const EdgeInsets.all(12),
          child: Text(
            'Dica: começar amanhã ou próxima segunda dá tempo de ajustar a rotina e separar o material (tênis, garrafa, etc).',
            style: context.runninType.bodySm.copyWith(
              color: palette.muted,
              height: 1.5,
            ),
          ),
        ),
      ],
    );
  }
}

class _DateChoice extends StatelessWidget {
  final String label;
  final String subtitle;
  final bool selected;
  final VoidCallback onTap;

  const _DateChoice({
    required this.label,
    required this.subtitle,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final palette = context.runninPalette;
    return InkWell(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: selected
              ? palette.primary.withValues(alpha: 0.12)
              : palette.surface,
          border: Border.all(
            color: selected ? palette.primary : palette.border,
            width: 1.041,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: context.runninType.labelMd.copyWith(
                color: selected ? palette.primary : palette.text,
                fontWeight: FontWeight.w500,
                letterSpacing: 1.2,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: context.runninType.bodySm.copyWith(
                color: palette.muted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
