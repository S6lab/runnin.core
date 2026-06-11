import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:runnin/core/network/api_client.dart';
import 'package:runnin/core/theme/design_system_tokens.dart';
import 'package:runnin/shared/widgets/figma/figma_selection_button.dart';

/// Os 3 modos de fala do coach (decisão do produto — antes eram 4
/// frequências + sub-toggle, regras demais).
abstract final class CoachMode {
  static const ativo = 'ativo';
  static const silencioso = 'silencioso';
  static const semAudio = 'sem_audio';
}

/// Persistência única do modo — Perfil→Ajustes→Coach e o PRÉ-CORRIDA usam
/// este helper, então as duas telas ficam espelhadas por construção.
/// Mapeia pros campos que o backend já entende (sem enum novo):
///   ativo      → coachMessageFrequency=per_km
///   silencioso → silent + allowCriticalAlertsInSilent=true
///                (s6-ai fala início, fim e críticos FC/pace)
///   sem_audio  → silent + allowCriticalAlertsInSilent=false (mudo total)
abstract final class CoachModePrefs {
  static const _box = 'runnin_settings';
  static const _keyFrequency = 'coach_message_frequency';
  static const _keyCritical = 'coach_allow_critical_in_silent';

  static String load() {
    if (!Hive.isBoxOpen(_box)) return CoachMode.ativo;
    final box = Hive.box<dynamic>(_box);
    final f = box.get(_keyFrequency, defaultValue: 'per_km');
    final crit = box.get(_keyCritical, defaultValue: true) == true;
    if (f == 'silent') {
      return crit ? CoachMode.silencioso : CoachMode.semAudio;
    }
    // per_km/per_2km/alerts_only legados caem em ativo até o próximo save.
    return CoachMode.ativo;
  }

  static ({String frequency, bool allowCritical}) fieldsFor(String mode) {
    switch (mode) {
      case CoachMode.silencioso:
        return (frequency: 'silent', allowCritical: true);
      case CoachMode.semAudio:
        return (frequency: 'silent', allowCritical: false);
      default:
        return (frequency: 'per_km', allowCritical: true);
    }
  }

  /// Hive síncrono (fonte das duas telas) + PATCH best-effort no profile
  /// (fonte do server na criação da sessão Live).
  static Future<void> save(String mode) async {
    final fields = fieldsFor(mode);
    if (Hive.isBoxOpen(_box)) {
      final box = Hive.box<dynamic>(_box);
      await box.put(_keyFrequency, fields.frequency);
      await box.put(_keyCritical, fields.allowCritical);
    }
    try {
      await apiClient.patch('/users/me', data: {
        'coachMessageFrequency': fields.frequency,
        'allowCriticalAlertsInSilent': fields.allowCritical,
      });
    } catch (_) {/* offline: Hive vale local; próximo save sincroniza */}
  }
}

/// Seletor dos 3 modos — mesmo componente no Perfil e no PRÉ-CORRIDA.
class CoachModeSelector extends StatelessWidget {
  final String value;
  final ValueChanged<String> onChanged;
  const CoachModeSelector({
    super.key,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        FigmaSelectionButton(
          label: 'Coach ativo',
          description:
              'Saudação, fechamento de cada km, check-ins, alertas de FC/pace, meta e resumo final',
          selected: value == CoachMode.ativo,
          onTap: () => onChanged(CoachMode.ativo),
        ),
        const SizedBox(height: AppSpacing.sm),
        FigmaSelectionButton(
          label: 'Silencioso',
          description:
              'Fala só na largada, no fim e em alertas críticos (FC fora da zona / pace fora do alvo)',
          selected: value == CoachMode.silencioso,
          onTap: () => onChanged(CoachMode.silencioso),
        ),
        const SizedBox(height: AppSpacing.sm),
        FigmaSelectionButton(
          label: 'Sem áudio',
          description: 'Coach mudo do início ao fim — só telemetria na tela',
          selected: value == CoachMode.semAudio,
          onTap: () => onChanged(CoachMode.semAudio),
        ),
      ],
    );
  }
}
