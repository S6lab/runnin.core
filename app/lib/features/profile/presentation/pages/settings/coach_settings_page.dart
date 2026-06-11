import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:runnin/core/network/api_client.dart';
import 'package:runnin/core/theme/app_palette.dart';
import 'package:runnin/core/theme/design_system_tokens.dart';
import 'package:runnin/features/auth/data/user_remote_datasource.dart';
import 'package:runnin/shared/widgets/feedback_toggle.dart';
import 'package:runnin/shared/widgets/figma/figma_selection_button.dart';
import 'package:runnin/shared/widgets/figma/figma_top_nav.dart';
import 'package:runnin/shared/widgets/section_heading.dart';

const _hiveBox = 'runnin_settings';
const _hiveKeyPersonality = 'coach_personality';
const _hiveKeyFrequency = 'coach_message_frequency';
const _hiveKeyAllowCriticalInSilent = 'coach_allow_critical_in_silent';

class CoachSettingsPage extends StatefulWidget {
  const CoachSettingsPage({super.key});

  @override
  State<CoachSettingsPage> createState() => _CoachSettingsPageState();
}

class _CoachSettingsPageState extends State<CoachSettingsPage> {
  String _personality = 'motivador';
  String _frequency = 'per_km';
  // Quando frequency=silent, deixa pace_alert/segment_pace_off/finish furarem
  // o silêncio. Default true (silêncio é pra ruído, não pra risco).
  // UI esconde toggle se frequency != silent — sem efeito nas outras.
  bool _allowCriticalInSilent = true;

  bool _saving = false;

  final _remote = UserRemoteDatasource();

  @override
  void initState() {
    super.initState();
    _loadFromHive();
    _loadFromRemote();
  }

  void _loadFromHive() {
    if (!Hive.isBoxOpen(_hiveBox)) return;
    final box = Hive.box<dynamic>(_hiveBox);
    setState(() {
      _personality = box.get(_hiveKeyPersonality, defaultValue: 'motivador') as String;
      _frequency = box.get(_hiveKeyFrequency, defaultValue: 'per_km') as String;
      _allowCriticalInSilent = box.get(_hiveKeyAllowCriticalInSilent, defaultValue: true) as bool;
    });
  }

  Future<void> _loadFromRemote() async {
    try {
      final profile = await _remote.getMe();
      if (profile == null || !mounted) return;
      setState(() {
        if (profile.coachPersonality != null) _personality = profile.coachPersonality!;
        if (profile.coachMessageFrequency != null) _frequency = profile.coachMessageFrequency!;
        if (profile.allowCriticalAlertsInSilent != null) {
          _allowCriticalInSilent = profile.allowCriticalAlertsInSilent!;
        }
      });
      // Update Hive cache with remote values
      if (Hive.isBoxOpen(_hiveBox)) {
        final box = Hive.box<dynamic>(_hiveBox);
        await box.put(_hiveKeyPersonality, _personality);
        await box.put(_hiveKeyFrequency, _frequency);
        await box.put(_hiveKeyAllowCriticalInSilent, _allowCriticalInSilent);
      }
    } catch (_) {
      // Remote load is best-effort; Hive values remain
    }
  }

  Future<void> _saveToHive() async {
    if (!Hive.isBoxOpen(_hiveBox)) return;
    final box = Hive.box<dynamic>(_hiveBox);
    await box.put(_hiveKeyPersonality, _personality);
    await box.put(_hiveKeyFrequency, _frequency);
    await box.put(_hiveKeyAllowCriticalInSilent, _allowCriticalInSilent);
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      // coachFeedbackEnabled saiu do payload: o mapa nunca foi consumido
      // por server/s6-ai (toggles decorativos removidos da UI).
      await apiClient.patch('/users/me', data: {
        'coachPersonality': _personality,
        'coachMessageFrequency': _frequency,
        'allowCriticalAlertsInSilent': _allowCriticalInSilent,
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
    } on DioException catch (e) {
      if (mounted) {
        final msg = e.response?.statusCode == 422
            ? 'Erro 422: dados inválidos.'
            : 'Erro ao salvar. Tente novamente.';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(msg),
            backgroundColor: context.runninPalette.secondary,
            duration: const Duration(seconds: 3),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: FigmaColors.bgBase,
      body: Column(
        children: [
          const FigmaTopNav(
            breadcrumb: 'COACH',
            showBackButton: true,
          ),
          Expanded(
            child: SingleChildScrollView(
              // Bottom 240: a barra fixa (SALVAR + tab nav) cobre ~200px —
              // com 100 a nota de ALERTAS POR CORRIDA ficava escondida
              // atrás do botão mesmo com scroll no fim.
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 240),
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

                  const SizedBox(height: AppSpacing.xxl),

                  // §2 Frequência
                  const SectionHeading(label: 'FREQUÊNCIA DURANTE CORRIDA'),
                  const SizedBox(height: 12),
                  FigmaSelectionButton(
                    label: 'A cada km',
                    description:
                        'Fecha cada km com pace, tempo e FC + check-in a cada 500m',
                    selected: _frequency == 'per_km',
                    onTap: () => setState(() => _frequency = 'per_km'),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  FigmaSelectionButton(
                    label: 'A cada 2km',
                    description: 'Metade das falas — só nos km pares',
                    selected: _frequency == 'per_2km',
                    onTap: () => setState(() => _frequency = 'per_2km'),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  FigmaSelectionButton(
                    label: 'Só alertas críticos',
                    description:
                        'Fala apenas FC fora da zona, pace fora do alvo, meta e fim',
                    selected: _frequency == 'alerts_only',
                    onTap: () => setState(() => _frequency = 'alerts_only'),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  FigmaSelectionButton(
                    label: 'Silencioso',
                    description:
                        'Coach não fala durante a corrida — o resumo final sempre toca',
                    selected: _frequency == 'silent',
                    onTap: () => setState(() => _frequency = 'silent'),
                  ),

                  // Sub-controle do modo silencioso. Críticos no s6-ai =
                  // bpm_alert + pace_alert (CRITICAL_EVENTS); o finish fura
                  // o silêncio SEMPRE, independente deste toggle — o copy
                  // antigo "(pace fora do alvo / fim)" omitia FC e citava
                  // fim errado.
                  if (_frequency == 'silent') ...[
                    const SizedBox(height: AppSpacing.sm),
                    FeedbackToggle(
                      label:
                          'Furar o silêncio em alertas críticos: FC fora da zona e pace fora do alvo',
                      feedbackKey: 'allow_critical_in_silent',
                      value: _allowCriticalInSilent,
                      onChanged: (v) => setState(() => _allowCriticalInSilent = v),
                    ),
                  ],

                  const SizedBox(height: AppSpacing.xxl),

                  // §3 — O que mais dá pra controlar (e onde). A antiga
                  // seção "TIPOS DE FEEDBACK ATIVOS" tinha 6 toggles que o
                  // server/s6-ai NUNCA consumiram (decorativos) e dois deles
                  // duplicavam os alertas do pré-corrida — removida.
                  const SectionHeading(label: 'ALERTAS POR CORRIDA'),
                  const SizedBox(height: 12),
                  Text(
                    'Anúncio por km, pace fora do alvo e FC fora da zona são '
                    'configurados no PRÉ-CORRIDA, valem por sessão e podem ser '
                    'salvos como padrão. Na esteira (indoor), o coach faz '
                    'check-ins por tempo (~4min) e os alertas de GPS ficam '
                    'desativados. Notificações diárias ficam em Ajustes → '
                    'Alertas.',
                    style: context.runninType.bodyXs.copyWith(
                      color: context.runninPalette.muted,
                      height: 1.6,
                    ),
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
                  color: context.runninPalette.primary,
                  border: Border.all(color: context.runninPalette.primary, width: 1.041),
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
                        style: context.runninType.bodyMd.copyWith(
                          color: FigmaColors.bgBase,
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
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

