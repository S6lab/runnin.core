import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:runnin/core/network/api_client.dart';
import 'package:runnin/core/theme/design_system_tokens.dart';
import 'package:runnin/shared/widgets/figma/figma_selection_button.dart';
import 'package:runnin/shared/widgets/figma/figma_top_nav.dart';
import 'package:runnin/shared/widgets/section_heading.dart';

const _hiveBox = 'runnin_settings';
const _hiveKeyPersonality = 'coach_personality';
const _hiveKeyVoice = 'coach_voice_id';
const _hiveKeyFrequency = 'coach_message_frequency';
const _hiveKeyFeedback = 'coach_feedback_enabled';

class CoachSettingsPage extends StatefulWidget {
  const CoachSettingsPage({super.key});

  @override
  State<CoachSettingsPage> createState() => _CoachSettingsPageState();
}

class _CoachSettingsPageState extends State<CoachSettingsPage> {
  String _personality = 'motivador';
  String _voiceId = 'bruno';
  String _frequency = 'per_km';
  Map<String, bool> _feedback = {
    'pre_training': true,
    'pace_alerts': true,
    'bpm_alerts': true,
    'live_splits': true,
    'post_training': true,
    'daily_notifications': true,
  };

  bool _saving = false;
  bool _previewLoading = false;

  @override
  void initState() {
    super.initState();
    _loadFromHive();
  }

  void _loadFromHive() {
    if (!Hive.isBoxOpen(_hiveBox)) return;
    final box = Hive.box<dynamic>(_hiveBox);
    setState(() {
      _personality = box.get(_hiveKeyPersonality, defaultValue: 'motivador') as String;
      _voiceId = box.get(_hiveKeyVoice, defaultValue: 'bruno') as String;
      _frequency = box.get(_hiveKeyFrequency, defaultValue: 'per_km') as String;
      final stored = box.get(_hiveKeyFeedback);
      if (stored is Map) {
        _feedback = Map<String, bool>.from(stored.map(
          (k, v) => MapEntry(k.toString(), v as bool? ?? true),
        ));
      }
    });
  }

  Future<void> _saveToHive() async {
    if (!Hive.isBoxOpen(_hiveBox)) return;
    final box = Hive.box<dynamic>(_hiveBox);
    await box.put(_hiveKeyPersonality, _personality);
    await box.put(_hiveKeyVoice, _voiceId);
    await box.put(_hiveKeyFrequency, _frequency);
    await box.put(_hiveKeyFeedback, _feedback);
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await apiClient.patch('/users/me', data: {
        'coachPersonality': _personality,
        'coachVoiceId': _voiceId,
        'coachMessageFrequency': _frequency,
        'coachFeedbackEnabled': _feedback,
      });
      await _saveToHive();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Preferências do Coach salvas.'),
            duration: Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } on DioException {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Erro ao salvar. Tente novamente.'),
            backgroundColor: FigmaColors.brandOrange,
            duration: const Duration(seconds: 3),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _previewVoice(String voiceId) async {
    if (_previewLoading) return;
    setState(() => _previewLoading = true);
    try {
      await apiClient.post('/coach/message', data: {
        'event': 'preview',
        'voiceId': voiceId,
      });
    } catch (_) {
      // Preview is best-effort; silence errors
    } finally {
      if (mounted) setState(() => _previewLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: FigmaColors.bgBase,
      body: Column(
        children: [
          const FigmaTopNav(
            breadcrumb: 'Perfil / Ajustes / Coach',
            showBackButton: true,
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 100),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // §1 Personalidade
                  const SectionHeading(label: 'PERSONALIDADE DO COACH'),
                  const SizedBox(height: 12),
                  FigmaSelectionButton(
                    label: 'Motivador — "Vamos lá! Você consegue."',
                    selected: _personality == 'motivador',
                    onTap: () => setState(() => _personality = 'motivador'),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  FigmaSelectionButton(
                    label: 'Técnico — "Pace 5:30/km, BPM 165, zona 3."',
                    selected: _personality == 'tecnico',
                    onTap: () => setState(() => _personality = 'tecnico'),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  FigmaSelectionButton(
                    label: 'Sereno — "Respire fundo, mantenha o ritmo."',
                    selected: _personality == 'sereno',
                    onTap: () => setState(() => _personality = 'sereno'),
                  ),

                  const SizedBox(height: AppSpacing.xxl),

                  // §2 Voz
                  const SectionHeading(label: 'VOZ DO COACH'),
                  const SizedBox(height: 12),
                  _VoiceOption(
                    label: 'Bruno',
                    subtitle: 'Voz masculina pt-BR',
                    voiceId: 'bruno',
                    selected: _voiceId == 'bruno',
                    previewLoading: _previewLoading && _voiceId == 'bruno',
                    onTap: () {
                      setState(() => _voiceId = 'bruno');
                      _previewVoice('bruno');
                    },
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  _VoiceOption(
                    label: 'Clara',
                    subtitle: 'Voz feminina pt-BR',
                    voiceId: 'clara',
                    selected: _voiceId == 'clara',
                    previewLoading: _previewLoading && _voiceId == 'clara',
                    onTap: () {
                      setState(() => _voiceId = 'clara');
                      _previewVoice('clara');
                    },
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  _VoiceOption(
                    label: 'Luna',
                    subtitle: 'Voz neutra ElevenLabs',
                    voiceId: 'luna',
                    selected: _voiceId == 'luna',
                    previewLoading: _previewLoading && _voiceId == 'luna',
                    onTap: () {
                      setState(() => _voiceId = 'luna');
                      _previewVoice('luna');
                    },
                  ),

                  const SizedBox(height: AppSpacing.xxl),

                  // §3 Frequência
                  const SectionHeading(label: 'FREQUÊNCIA DURANTE CORRIDA'),
                  const SizedBox(height: 12),
                  FigmaSelectionButton(
                    label: 'A cada km',
                    selected: _frequency == 'per_km',
                    onTap: () => setState(() => _frequency = 'per_km'),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  FigmaSelectionButton(
                    label: 'A cada 2km',
                    selected: _frequency == 'per_2km',
                    onTap: () => setState(() => _frequency = 'per_2km'),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  FigmaSelectionButton(
                    label: 'Só em alertas (pace/BPM)',
                    selected: _frequency == 'alerts_only',
                    onTap: () => setState(() => _frequency = 'alerts_only'),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  FigmaSelectionButton(
                    label: 'Silencioso',
                    selected: _frequency == 'silent',
                    onTap: () => setState(() => _frequency = 'silent'),
                  ),

                  const SizedBox(height: AppSpacing.xxl),

                  // §4 Tipos de feedback
                  const SectionHeading(label: 'TIPOS DE FEEDBACK ATIVOS'),
                  const SizedBox(height: 12),
                  _FeedbackToggle(
                    label: 'Análise pré-treino',
                    feedbackKey: 'pre_training',
                    value: _feedback['pre_training'] ?? true,
                    onChanged: (v) => setState(() => _feedback['pre_training'] = v),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  _FeedbackToggle(
                    label: 'Alertas de pace',
                    feedbackKey: 'pace_alerts',
                    value: _feedback['pace_alerts'] ?? true,
                    onChanged: (v) => setState(() => _feedback['pace_alerts'] = v),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  _FeedbackToggle(
                    label: 'Alertas de BPM',
                    feedbackKey: 'bpm_alerts',
                    value: _feedback['bpm_alerts'] ?? true,
                    onChanged: (v) => setState(() => _feedback['bpm_alerts'] = v),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  _FeedbackToggle(
                    label: 'Splits ao vivo',
                    feedbackKey: 'live_splits',
                    value: _feedback['live_splits'] ?? true,
                    onChanged: (v) => setState(() => _feedback['live_splits'] = v),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  _FeedbackToggle(
                    label: 'Relatório pós-treino',
                    feedbackKey: 'post_training',
                    value: _feedback['post_training'] ?? true,
                    onChanged: (v) => setState(() => _feedback['post_training'] = v),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  _FeedbackToggle(
                    label: 'Notificações diárias',
                    feedbackKey: 'daily_notifications',
                    value: _feedback['daily_notifications'] ?? true,
                    onChanged: (v) => setState(() => _feedback['daily_notifications'] = v),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
          child: SizedBox(
            height: 48,
            width: double.infinity,
            child: GestureDetector(
              onTap: _saving ? null : _save,
              child: Container(
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: FigmaColors.brandCyan,
                  border: Border.all(color: FigmaColors.brandCyan, width: 1.041),
                ),
                child: _saving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation(Colors.black),
                        ),
                      )
                    : Text(
                        'SALVAR',
                        style: GoogleFonts.jetBrainsMono(
                          color: FigmaColors.bgBase,
                          fontSize: 13,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.5,
                        ),
                      ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _VoiceOption extends StatelessWidget {
  final String label;
  final String subtitle;
  final String voiceId;
  final bool selected;
  final bool previewLoading;
  final VoidCallback onTap;

  const _VoiceOption({
    required this.label,
    required this.subtitle,
    required this.voiceId,
    required this.selected,
    required this.previewLoading,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        height: 56.5,
        padding: const EdgeInsets.symmetric(horizontal: 21.74, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? FigmaColors.selectionActiveBg : FigmaColors.surfaceCard,
          border: Border.all(
            color: selected ? FigmaColors.selectionActiveBorder : FigmaColors.borderDefault,
            width: FigmaDimensions.borderUniversal,
          ),
          borderRadius: FigmaBorderRadius.zero,
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    label,
                    style: GoogleFonts.jetBrainsMono(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: selected ? FigmaColors.textPrimary : const Color(0xB3FFFFFF),
                    ),
                  ),
                  Text(
                    subtitle,
                    style: GoogleFonts.jetBrainsMono(
                      fontSize: 10,
                      fontWeight: FontWeight.w400,
                      color: FigmaColors.textMuted,
                    ),
                  ),
                ],
              ),
            ),
            if (previewLoading)
              const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 1.5),
              )
            else
              Icon(
                Icons.play_circle_outline,
                size: 20,
                color: selected ? FigmaColors.brandCyan : FigmaColors.textDim,
              ),
          ],
        ),
      ),
    );
  }
}

class _FeedbackToggle extends StatelessWidget {
  final String label;
  final String feedbackKey;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _FeedbackToggle({
    required this.label,
    required this.feedbackKey,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => onChanged(!value),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 21.74, vertical: 14),
        decoration: BoxDecoration(
          color: value ? FigmaColors.selectionActiveBg : FigmaColors.surfaceCard,
          border: Border.all(
            color: value ? FigmaColors.selectionActiveBorder : FigmaColors.borderDefault,
            width: FigmaDimensions.borderUniversal,
          ),
          borderRadius: FigmaBorderRadius.zero,
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: GoogleFonts.jetBrainsMono(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: value ? FigmaColors.textPrimary : const Color(0xB3FFFFFF),
                ),
              ),
            ),
            Container(
              width: 18,
              height: 18,
              decoration: BoxDecoration(
                color: value ? FigmaColors.brandCyan : Colors.transparent,
                border: Border.all(
                  color: value ? FigmaColors.brandCyan : FigmaColors.borderDefault,
                  width: 1.5,
                ),
              ),
              child: value
                  ? const Icon(Icons.check, size: 12, color: Colors.black)
                  : null,
            ),
          ],
        ),
      ),
    );
  }
}
