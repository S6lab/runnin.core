import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:dio/dio.dart';
import 'package:runnin/core/alerts/alert_settings_service.dart';
import 'package:runnin/core/audio/coach_audio_player.dart';
import 'package:runnin/core/network/api_client.dart';
import 'package:runnin/core/theme/app_palette.dart';
import 'package:runnin/features/auth/data/user_remote_datasource.dart';
import 'package:runnin/features/run/data/datasources/run_coach_remote_datasource.dart';
import 'package:runnin/features/run/presentation/bloc/run_bloc.dart';
import 'package:runnin/shared/widgets/music_player_widget.dart';
import 'package:runnin/features/training/domain/entities/plan.dart';

export 'package:runnin/features/coach/data/coach_data.dart';

class PrepPage extends StatelessWidget {
  final PlanSession? session;
  final PlanWeek? week;
  final String? planId;

  const PrepPage({super.key, this.session, this.week, this.planId});

  @override
  Widget build(BuildContext context) => _PrepView(session: session, week: week, planId: planId);
}

class _PrepView extends StatefulWidget {
  final PlanSession? session;
  final PlanWeek? week;
  final String? planId;

  const _PrepView({this.session, this.week, this.planId});

  @override
  State<_PrepView> createState() => _PrepViewState();
}

class _PrepViewState extends State<_PrepView> {
  final _coachRemote = RunCoachRemoteDatasource();
  final _types = [
    'Easy Run',
    'Intervalado',
    'Tempo Run',
    'Long Run',
    'Free Run',
  ];
  late String _selectedType;

  @override
  void initState() {
    super.initState();
    final session = widget.session;
    if (session != null) {
      _selectedType = _mapSessionTypeToPrep(session.type);
    } else {
      _selectedType = 'Easy Run';
    }
  }

  String _mapSessionTypeToPrep(String sessionType) {
    final typeLC = sessionType.toLowerCase();
    if (typeLC.contains('interval') || typeLC.contains('intervalado')) {
      return 'Intervalado';
    }
    if (typeLC.contains('tempo') || typeLC.contains('ritmo')) {
      return 'Tempo Run';
    }
    if (typeLC.contains('long') || typeLC.contains('volume')) {
      return 'Long Run';
    }
    if (typeLC.contains('easy') || typeLC.contains('leve') || typeLC.contains('rodagem')) {
      return 'Easy Run';
    }
    if (typeLC.contains('free') || typeLC.contains('livre')) {
      return 'Free Run';
    }
    return 'Easy Run';
  }

  static const _typeDetails = {
    'Easy Run': (
      'Rodagem leve para construir consistencia',
      'Ideal para dias de base, recuperacao ativa e ajuste tecnico sem subir demais a carga.',
      ['Ritmo solto', 'Respiracao controlada', 'Foco em economia'],
    ),
    'Intervalado': (
      'Blocos fortes com recuperacao entre tiros',
      'Boa opcao para velocidade e VO2. Vale chegar com aquecimento caprichado.',
      ['Tiros curtos', 'Recuperacao guiada', 'Alta intensidade'],
    ),
    'Tempo Run': (
      'Ritmo sustentado para limiar e consistencia',
      'Pede concentracao e estabilidade. O objetivo e correr forte sem quebrar no final.',
      ['Ritmo estavel', 'Esforco controlado', 'Mental firme'],
    ),
    'Long Run': (
      'Volume para resistencia e adaptacao',
      'Sessao boa para base aerobica. Hidratacao e paciencia fazem diferenca aqui.',
      ['Duracao maior', 'Pace conservador', 'Foco em resistencia'],
    ),
    'Free Run': (
      'Corrida livre para registrar o momento',
      'Quando quiser apenas sair para correr, o app acompanha sem travar voce num protocolo.',
      ['Sem meta fixa', 'Leitura livre', 'Bom para explorar'],
    ),
  };

  StreamSubscription<CoachCue>? _coachSub;
  Timer? _coachDebounce;
  String? _coachCue;
  bool _coachLoading = false;
  bool _coachMuted = false;
  bool? _isPro;

  @override
  void initState() {
    super.initState();
    _resolvePremiumThenLoadCue();
  }

  Future<void> _resolvePremiumThenLoadCue() async {
    try {
      final profile = await UserRemoteDatasource().getMe();
      if (!mounted) return;
      final isPro = profile?.isPro ?? false;
      setState(() => _isPro = isPro);
      if (isPro) _requestPreRunCue();
    } catch (_) {
      if (!mounted) return;
      setState(() => _isPro = false);
    }
  }

  @override
  void dispose() {
    _coachDebounce?.cancel();
    _coachSub?.cancel();
    super.dispose();
  }

  void _selectType(String type) {
    setState(() => _selectedType = type);
    _coachDebounce?.cancel();
    _coachDebounce = Timer(
      const Duration(milliseconds: 350),
      _requestPreRunCue,
    );
  }

  void _requestPreRunCue() {
    _coachSub?.cancel();
    setState(() {
      _coachLoading = true;
      _coachCue = null;
    });

    _coachSub = _coachRemote
        .streamCoachCue(
          event: 'pre_run',
          runType: _selectedType,
          currentPaceMinKm: 0,
          distanceM: 0,
          elapsedS: 0,
        )
        .listen(
          (cue) {
            if (!mounted) return;
            setState(() {
              _coachCue = cue.text;
              _coachLoading = false;
            });
            final audio = cue.audioBase64;
            if (!_coachMuted && audio != null && audio.isNotEmpty) {
              playCoachAudio(
                audio,
                mimeType: cue.audioMimeType ?? 'audio/mpeg',
                volume: 1.0,
              );
            }
          },
          onError: (_) {
            if (mounted) setState(() => _coachLoading = false);
          },
          onDone: () {
            if (mounted) setState(() => _coachLoading = false);
          },
        );
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.runninPalette;
    final type = context.runninType;
    final detail = _typeDetails[_selectedType] ?? _typeDetails['Free Run']!;

    return BlocListener<RunBloc, RunState>(
      listenWhen: (prev, curr) =>
          prev.status != curr.status || prev.error != curr.error,
      listener: (context, state) {
        if (state.runId != null) {
          if (state.status == RunStatus.active) {
            context.pushReplacement('/run', extra: state.runId);
          }
        }

        if (state.status == RunStatus.error && state.error != null) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(state.error!)));
        }
      },
      child: Scaffold(
        backgroundColor: palette.background,
        appBar: AppBar(
          title: const Text('PREPARAR CORRIDA'),
          leading: IconButton(
            icon: const Icon(Icons.close),
            onPressed: () {
              if (context.canPop()) {
                context.pop();
              } else {
                context.go('/home');
              }
            },
          ),
        ),
        body: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('TIPO DE TREINO', style: type.labelCaps),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: _types.map((t) {
                          final sel = _selectedType == t;
                          return GestureDetector(
                            onTap: () => _selectType(t),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 8,
                              ),
                              decoration: BoxDecoration(
                                color: sel ? palette.primary : palette.surface,
                                border: Border.all(
                                  color: sel ? palette.primary : palette.border,
                                ),
                              ),
                              child: Text(
                                t.toUpperCase(),
                                style: type.labelCaps.copyWith(
                                  color: sel
                                      ? palette.background
                                      : palette.muted,
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 20),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          color: palette.surface,
                          border: Border.all(color: palette.border),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              detail.$1.toUpperCase(),
                              style: type.labelCaps.copyWith(
                                color: palette.primary,
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 10),
                            Text(detail.$2, style: type.bodyMd),
                            const SizedBox(height: 16),
                            ...detail.$3.map(
                              (item) => Padding(
                                padding: const EdgeInsets.only(bottom: 8),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Padding(
                                      padding: const EdgeInsets.only(top: 5),
                                      child: Icon(
                                        Icons.circle,
                                        size: 6,
                                        color: palette.primary,
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Text(
                                        item,
                                        style: type.bodySm.copyWith(
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                       const SizedBox(height: 14),
                        // Warmup guidance section
                        if (_isPro == true) ...[
                          _WarmupGuidanceSection(
                            sessionType: _selectedType,
                            loading: false,
                            briefing: null, // will be populated when backend API is ready (SUP-58)
                          ),
                        ],
                        if (_isPro == false)
                          _PreRunCoachLockedCard(
                            onTap: () => context.push('/profile'),
                          )
                        else
                          _PreRunCoachCard(
                            loading: _coachLoading,
                            cue: _coachCue,
                            muted: _coachMuted,
                            onToggleMute: () =>
                                setState(() => _coachMuted = !_coachMuted),
                            onRefresh: _requestPreRunCue,
                          ),
                        const SizedBox(height: 14),
                        // Alert configuration panel
                        _AlertConfigurationPanel(),
                        const SizedBox(height: 14),
                        // Music player controls
                        const MusicPlayerWidget(),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
              BlocBuilder<RunBloc, RunState>(
                builder: (context, state) => SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    onPressed: state.status == RunStatus.starting
                        ? null
                        : () {
                            context.read<RunBloc>().add(
                              StartRun(type: _selectedType),
                            );
                          },
                    child: state.status == RunStatus.starting
                        ? CircularProgressIndicator(
                            color: palette.background,
                            strokeWidth: 2,
                          )
                        : const Text('INICIAR CORRIDA'),
                  ),
                ),
              ),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }
}

class _PreRunCoachCard extends StatelessWidget {
  final bool loading;
  final String? cue;
  final bool muted;
  final VoidCallback onToggleMute;
  final VoidCallback onRefresh;

  const _PreRunCoachCard({
    required this.loading,
    required this.cue,
    required this.muted,
    required this.onToggleMute,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    final palette = context.runninPalette;
    final type = context.runninType;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: palette.surfaceAlt,
        border: Border.all(color: palette.primary.withValues(alpha: 0.28)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.record_voice_over_outlined, color: palette.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('COACH', style: type.labelCaps),
                const SizedBox(height: 8),
                if (loading)
                  Row(
                    children: [
                      SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(
                          color: palette.muted,
                          strokeWidth: 1.5,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text('Analisando seu contexto...', style: type.bodySm),
                    ],
                  )
                else
                  Text(
                    cue ??
                        'Vou cruzar seu objetivo, plano e histórico para orientar a largada.',
                    style: type.bodySm.copyWith(height: 1.45),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            tooltip: muted ? 'Ativar voz' : 'Mutar voz',
            onPressed: onToggleMute,
            icon: Icon(
              muted ? Icons.volume_off_outlined : Icons.volume_up_outlined,
            ),
          ),
          IconButton(
            tooltip: 'Atualizar orientação',
            onPressed: loading ? null : onRefresh,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
    );
  }
}

class _PreRunCoachLockedCard extends StatelessWidget {
  final VoidCallback onTap;

  const _PreRunCoachLockedCard({required this.onTap});

  @override
  Widget build(BuildContext context) {
    final palette = context.runninPalette;
    final type = context.runninType;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: palette.surfaceAlt,
          border: Border.all(color: palette.border),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.lock_outline, color: palette.muted),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('COACH', style: type.labelCaps),
                  const SizedBox(height: 8),
                  Text(
                    'O Coach AI guia você antes da largada com base no seu plano e histórico. Disponível no plano Pro.',
                    style: type.bodySm.copyWith(height: 1.45),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'ASSINAR PRO →',
                    style: type.labelCaps.copyWith(color: palette.primary),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _WarmupGuidanceSection extends StatefulWidget {
  final String sessionType;
  final bool loading;
  final dynamic briefing;

  const _WarmupGuidanceSection({
    required this.sessionType,
    required this.loading,
    required this.briefing,
  });

  @override
  State<_WarmupGuidanceSection> createState() =>
      _WarmupGuidanceSectionState();
}

class _WarmupGuidanceSectionState extends State<_WarmupGuidanceSection> {
  String? _briefingText;
  bool _loading = false;
  late final Dio _dio;

  @override
  void initState() {
    super.initState();
    _dio = apiClient;
    
    if (widget.briefing != null) {
      _briefingText = widget.briefing.text ?? '';
    } else if (!widget.loading) {
      _fetchBriefing();
    }
  }

  Future<void> _fetchBriefing() async {
    setState(() => _loading = true);
    
    try {
      final response = await _dio.post('/warmup/guidance', data: {
        'sessionType': widget.sessionType,
      });
      
      if (!mounted) return;
      
      final data = response.data as Map<String, dynamic>;
      _briefingText = data['guidance'] as String?;
      
      setState(() => _loading = false);
    } catch (e) {
      if (!mounted) return;
      
      final briefingMap = {
        'Intervalado': 'Complete 3-5 min de aquecimento progressivo. Inclua 2x30s de acelerações para preparar o corpo para os intervalos.',
        'Tempo Run': '10-15 min de aquecimento leve. Foco em mobilidade e postura para manter o ritmo constante durante a sessão.',
        'Long Run': '15-20 min de aquecimento suave. Atenção a hidratação e preparação mental para a longa distância.',
        'Free Run': 'Aquecimento livre de 5-10 min. Ajuste conforme sua disposição no momento.',
        'Corrida': '8-12 min de aquecimento dinâmico. Prepare o corpo para a intensidade da corrida.',
      };
      
      _briefingText = briefingMap[widget.sessionType] ??
          'Configure seu aquecimento personalizado.';
      
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.runninPalette;
    final type = context.runninType;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: palette.surface,
        border: Border.all(color: palette.border),
      ),
      child: Column(
        children: [
          Icon(IconsDirections.walk_rounded, color: palette.primary),
          const SizedBox(height: 8),
          Text('AQUECIMENTO', style: type.labelCaps),
          const SizedBox(height: 8),
          if (_loading || widget.loading)
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(
                    color: palette.muted,
                    strokeWidth: 1.5,
                  ),
                ),
                const SizedBox(width: 10),
                Text('Buscando orientação...', style: type.bodySm),
              ],
            )
          else if (_briefingText != null)
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_briefingText!, style: type.bodySm),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: palette.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.play_arrow_rounded, size: 14),
                      SizedBox(width: 6),
                      Text('PLAY AQUECIMENTO', style: TextStyle(fontSize: 12)),
                    ],
                  ),
                ),
              ],
            )
          else
            Text(
              'Configure seu aquecimento personalizado.',
              style: type.bodySm.copyWith(color: palette.muted),
            ),
        ],
      ),
    );
  }
}

class _AlertConfigurationPanel extends StatefulWidget {
  @override
  State<_AlertConfigurationPanel> createState() =>
      _AlertConfigurationPanelState();
}

class _AlertConfigurationPanelState
    extends State<_AlertConfigurationPanel> {
  late final AlertSettingsService _alertService;
  bool _paceAlertEnabled = false;
  bool _heartRateAlertEnabled = false;
  bool _distanceMarkAlertEnabled = true;

  @override
  void initState() {
    super.initState();
    _alertService = AlertSettingsService();
    _loadAlerts();
  }

  Future<void> _loadAlerts() async {
    try {
      final settings = _alertService.settings;
      if (!mounted) return;
      setState(() {
        _paceAlertEnabled = settings.paceAlertEnabled;
        _heartRateAlertEnabled = settings.heartRateAlertEnabled;
        _distanceMarkAlertEnabled = settings.distanceMarkAlertEnabled;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _paceAlertEnabled = false;
        _heartRateAlertEnabled = false;
        _distanceMarkAlertEnabled = true;
      });
    }
  }

  Future<void> _updatePaceAlert(bool value) async {
    try {
      await _alertService.updatePaceAlert(value);
      if (!mounted) return;
      setState(() => _paceAlertEnabled = value);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro ao atualizar alerta de ritmo')),
      );
    }
  }

  Future<void> _updateHeartRateAlert(bool value) async {
    try {
      await _alertService.updateHeartRateAlert(value);
      if (!mounted) return;
      setState(() => _heartRateAlertEnabled = value);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro ao atualizar alerta de frequência cardíaca')),
      );
    }
  }

  Future<void> _updateDistanceMarkAlert(bool value) async {
    try {
      await _alertService.updateDistanceMarkAlert(value);
      if (!mounted) return;
      setState(() => _distanceMarkAlertEnabled = value);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro ao atualizar alerta de marcas de distância')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.runninPalette;
    final type = context.runninType;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: palette.surface,
        border: Border.all(color: palette.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.warning_rounded, color: palette.primary),
          const SizedBox(height: 8),
          Text('CONFIGURAR ALERTAS', style: type.labelCaps),
          const SizedBox(height: 12),
          Text(
            'Personalize alertas de ritmo, frequência cardíaca e marcas de distância.',
            style: type.bodySm.copyWith(color: palette.muted),
          ),
          const SizedBox(height: 16),
          _AlertToggle(
            label: 'Ritmo (kms)',
            subLabel: 'Alerta quando o ritmo sair da faixa',
            enabled: _paceAlertEnabled,
            onChanged: (value) => _updatePaceAlert(value),
          ),
          const SizedBox(height: 12),
          _AlertToggle(
            label: 'Frequência cardíaca',
            subLabel: 'Monitora zonas de FCemax e alerta se sair delas',
            enabled: _heartRateAlertEnabled,
            onChanged: (value) => _updateHeartRateAlert(value),
          ),
          const SizedBox(height: 12),
          _AlertToggle(
            label: 'Marcas de distância',
            subLabel: 'Notificações em marcas como 5km, 10km, meia maratona',
            enabled: _distanceMarkAlertEnabled,
            onChanged: (value) => _updateDistanceMarkAlert(value),
          ),
        ],
      ),
    );
  }
}

class _AlertToggle extends StatelessWidget {
  final String label;
  final String subLabel;
  final bool enabled;
  final ValueChanged<bool> onChanged;

  const _AlertToggle({
    required this.label,
    required this.subLabel,
    required this.enabled,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final palette = context.runninPalette;
    final type = context.runninType;

    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(label, style: type.bodyMd),
                  const SizedBox(width: 8),
                  if (enabled)
                    Container(
                      padding:
                          const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: palette.primary.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        'On',
                        style: type.labelSmall
                            .copyWith(color: palette.primary),
                      ),
                    )
                  else
                    Container(
                      padding:
                          const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: palette.muted.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        'Off',
                        style: type.labelSmall
                            .copyWith(color: palette.muted),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 4),
 Text(subLabel, style: type.bodySm.copyWith(color: palette.muted)),
            ],
          ),
        ),
        Switch(
          value: enabled,
          onChanged: onChanged,
          activeColor: palette.primary,
        ),
      ],
    );
  }
}
