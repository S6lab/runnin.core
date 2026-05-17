import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:runnin/core/audio/coach_audio_player.dart';
import 'package:runnin/core/theme/app_palette.dart';
import 'package:runnin/core/warmup/warmup_exercises.dart';
import 'package:runnin/features/auth/data/user_remote_datasource.dart';
import 'package:runnin/features/run/data/datasources/run_coach_remote_datasource.dart';
import 'package:runnin/features/run/presentation/bloc/run_bloc.dart';
import 'package:runnin/features/training/data/datasources/plan_remote_datasource.dart';
import 'package:runnin/features/training/domain/entities/plan.dart';
import 'package:runnin/core/theme/design_system_tokens.dart';
import 'package:runnin/shared/widgets/runnin_app_bar.dart';
import 'package:runnin/shared/widgets/section_heading.dart';
import 'package:url_launcher/url_launcher.dart';

class PrepPage extends StatelessWidget {
  const PrepPage({super.key});

  @override
  Widget build(BuildContext context) => const _PrepView();
}

class _PrepView extends StatefulWidget {
  const _PrepView();

  @override
  State<_PrepView> createState() => _PrepViewState();
}

class _PrepViewState extends State<_PrepView> {
  final _coachRemote = RunCoachRemoteDatasource();
  final _userRemote = UserRemoteDatasource();
  final _planRemote = PlanRemoteDatasource();
  // Tipo selecionado: 'Free Run' (sempre disponível) ou o type da sessão
  // do plano do dia (quando premium + plano + sessão hoje).
  String _selectedType = 'Free Run';
  // Sessão do plano de HOJE, se existir. Null = freemium OU sem plano OU
  // sem sessão hoje. Mostra o card "Sessão do Plano" no seletor.
  PlanSession? _planTodaySession;

  StreamSubscription<CoachCue>? _coachSub;
  Timer? _coachDebounce;
  String? _coachCue;
  bool _coachLoading = false;
  bool _coachMuted = false;
  bool? _isPro;

  List<WarmupExercise> _exercises = const [];

  /// Wizard step: 0=Config (alertas+música+coach), 1=Tipo, 2=Aquecimento.
  /// Tela 4 (corrida ativa) é /run após INICIAR.
  int _step = 0;

  /// Status do GPS no warm-up. unknown=ainda checando, ok=permissão+pos
  /// cacheada, denied=permissão recusada, off=serviço desligado. Renderizado
  /// como badge no header do step config.
  _GpsStatus _gpsStatus = _GpsStatus.unknown;

  final Map<String, bool> _alerts = {
    'kmAlert': true,
    'paceOutOfRange': true,
    'highBpm': true,
    'kmSplits': false,
    'motivation': true,
  };

  static const _alertLabels = {
    'kmAlert': 'Alerta a cada km',
    'paceOutOfRange': 'Pace fora do range',
    'highBpm': 'BPM elevado',
    'kmSplits': 'Splits por km',
    'motivation': 'Motivação',
  };

  @override
  void initState() {
    super.initState();
    _resolvePremiumThenLoadCue();
    _loadTodaySessionFromPlan();
    _loadExercises();
    // GPS warm-up: solicita permissão + posição inicial AGORA pra que no
    // step 4 (corrida) o stream já esteja autorizado e o primeiro fix
    // tenha menos latência. Falha silenciosa — RunBloc._onStart faz a
    // checagem oficial de novo.
    unawaited(_warmGps());
  }

  Future<void> _warmGps() async {
    try {
      final enabled = await Geolocator.isLocationServiceEnabled();
      if (!enabled) {
        if (mounted) setState(() => _gpsStatus = _GpsStatus.off);
        return;
      }
      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.denied ||
          perm == LocationPermission.deniedForever) {
        if (mounted) setState(() => _gpsStatus = _GpsStatus.denied);
        return;
      }
      await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
      );
      if (mounted) setState(() => _gpsStatus = _GpsStatus.ok);
    } catch (_) {
      if (mounted) setState(() => _gpsStatus = _GpsStatus.off);
    }
  }

  Future<void> _loadTodaySessionFromPlan() async {
    try {
      final plan = await _planRemote.getCurrentPlan();
      if (!mounted || plan == null || !plan.isReady) return;
      final today = DateTime.now().weekday; // 1=Mon..7=Sun
      // Calcula a semana atual baseado em startDate.
      final start = plan.effectiveStartDate;
      final daysFromStart = DateTime.now().difference(start).inDays;
      final weekIdx = (daysFromStart / 7).floor().clamp(0, plan.weeks.length - 1);
      final week = plan.weeks[weekIdx];
      final session = week.sessions
          .where((s) => s.dayOfWeek == today)
          .cast<PlanSession?>()
          .firstWhere((_) => true, orElse: () => null);
      if (mounted && session != null) {
        setState(() {
          _planTodaySession = session;
          // Default: pré-selecionado a sessão do plano (user pode trocar
          // pra Free Run se quiser).
          _selectedType = session.type;
        });
        _loadExercises();
      }
    } catch (_) {/* Sem plano OU erro de network — segue free run */}
  }

  Future<void> _resolvePremiumThenLoadCue() async {
    try {
      final profile = await _userRemote.getMe();
      if (!mounted) return;
      final isPro = profile?.isPro ?? false;
      setState(() => _isPro = isPro);
      if (isPro) _requestPreRunCue();

      final saved = profile?.preRunAlerts;
      if (saved != null) {
        setState(() {
          for (final e in saved.entries) {
            if (_alerts.containsKey(e.key)) _alerts[e.key] = e.value;
          }
        });
      }
    } catch (_) {
      if (!mounted) return;
      setState(() => _isPro = false);
    }
  }

  Future<void> _loadExercises() async {
    final list = await loadWarmupExercises(_selectedType);
    if (mounted) setState(() => _exercises = list);
  }

  @override
  void dispose() {
    _coachDebounce?.cancel();
    _coachSub?.cancel();
    super.dispose();
  }

  void _selectType(String type) {
    setState(() => _selectedType = type);
    _loadExercises();
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

  void _toggleAlert(String key, bool value) {
    setState(() => _alerts[key] = value);
    _userRemote.patchMe(preRunAlerts: Map<String, bool>.from(_alerts));
  }

  Future<void> _openMusicApp(_MusicProvider provider) async {
    final nativeUri = Uri.parse(provider.scheme);
    if (await canLaunchUrl(nativeUri)) {
      await launchUrl(nativeUri, mode: LaunchMode.externalApplication);
    } else {
      await launchUrl(
        Uri.parse(provider.webUrl),
        mode: LaunchMode.externalApplication,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.runninPalette;
    final type = context.runninType;
    // detail card removido — descrição agora vem direto do _RunModeCard.

    return BlocListener<RunBloc, RunState>(
      // PrepPage não dispara mais StartRun — só navega pra /run com o tipo
      // selecionado. Mantemos só o handler de erro caso algo dispare bloc
      // por engano (defensivo).
      listenWhen: (prev, curr) => prev.error != curr.error,
      listener: (context, state) {
        if (state.status == RunStatus.error && state.error != null) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(state.error!)));
        }
      },
      child: Scaffold(
        backgroundColor: palette.background,
        appBar: RunninAppBar(
          title: 'PREPARAR · ${_step + 1}/3',
        ),
        body: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _StepProgressBar(step: _step, total: 3),
              const SizedBox(height: 16),
              Expanded(
                child: SingleChildScrollView(
                  child: switch (_step) {
                    0 => _buildConfigStep(context, type),
                    1 => _buildTypeStep(context, type),
                    _ => _buildWarmupStep(context, type),
                  },
                ),
              ),
              const SizedBox(height: 16),
              _buildStepNav(context, palette),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }

  // ─── Step 1: Config (coach + alertas + música) ──────────────────
  Widget _buildConfigStep(BuildContext context, RunninTypography type) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionHeading(label: '> COACH'),
        const SizedBox(height: 12),
        if (_isPro == false)
          _PreRunCoachLockedCard(onTap: () => context.push('/profile'))
        else
          _PreRunCoachCard(
            loading: _coachLoading,
            cue: _coachCue,
            muted: _coachMuted,
            onToggleMute: () => setState(() => _coachMuted = !_coachMuted),
            onRefresh: _requestPreRunCue,
          ),
        const SizedBox(height: 24),
        Row(
          children: [
            const SectionHeading(label: '> GPS'),
            const SizedBox(width: 10),
            _GpsStatusChip(status: _gpsStatus, onRetry: _warmGps),
          ],
        ),
        const SizedBox(height: 24),
        const SectionHeading(label: '> ALERTAS PRÉ-CORRIDA'),
        const SizedBox(height: 8),
        ..._alerts.entries.map(
          (e) => _AlertToggleRow(
            label: _alertLabels[e.key] ?? e.key,
            value: e.value,
            onChanged: (v) => _toggleAlert(e.key, v),
          ),
        ),
        const SizedBox(height: 24),
        const SectionHeading(label: '> MÚSICA'),
        const SizedBox(height: 12),
        Row(
          children: _MusicProvider.values.map((p) {
            return Expanded(
              child: Padding(
                padding: EdgeInsets.only(
                  right: p != _MusicProvider.values.last ? 8 : 0,
                ),
                child: _MusicProviderButton(
                  provider: p,
                  onTap: () => _openMusicApp(p),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  // ─── Step 2: Tipo de corrida ────────────────────────────────────
  Widget _buildTypeStep(BuildContext context, RunninTypography type) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionHeading(label: '> COMO VOCÊ VAI CORRER HOJE'),
        const SizedBox(height: 12),
        if (_planTodaySession != null && _isPro == true) ...[
          _RunModeCard(
            icon: Icons.assignment_outlined,
            title: _planTodaySession!.type.toUpperCase(),
            subtitle:
                'SESSÃO DO PLANO DE HOJE · ${_planTodaySession!.distanceKm.toStringAsFixed(1)}km'
                '${_planTodaySession!.targetPace != null ? " · ${_planTodaySession!.targetPace}/km" : ""}'
                '${_planTodaySession!.durationMin != null ? " · ~${_planTodaySession!.durationMin!.round()}min" : ""}',
            description: _planTodaySession!.notes.isNotEmpty
                ? _planTodaySession!.notes
                : 'Sessão estruturada pra seu objetivo. Coach acompanha pace alvo e BPM.',
            selected: _selectedType == _planTodaySession!.type,
            accent: true,
            onTap: () => _selectType(_planTodaySession!.type),
          ),
          const SizedBox(height: 10),
          _RunModeCard(
            icon: Icons.directions_run_outlined,
            title: 'FREE RUN',
            subtitle: 'Corrida livre, sem meta',
            description:
                'Sai sem protocolo. O coach observa o que você faz e ajusta a próxima sessão do plano com base nesses dados.',
            selected: _selectedType == 'Free Run',
            accent: false,
            onTap: () => _selectType('Free Run'),
          ),
        ] else
          _RunModeCard(
            icon: Icons.directions_run_outlined,
            title: 'FREE RUN',
            subtitle: 'Corrida livre, sem meta',
            description: _isPro == true
                ? 'Não há sessão planejada pra hoje. Free run registra a corrida e ajusta o plano.'
                : 'Versão grátis. Plano AI personalizado é premium — assine pra ter sessões estruturadas.',
            selected: true,
            accent: false,
            onTap: () => _selectType('Free Run'),
          ),
      ],
    );
  }

  // ─── Step 3: Aquecimento ────────────────────────────────────────
  Widget _buildWarmupStep(BuildContext context, RunninTypography type) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionHeading(label: '> AQUECIMENTO'),
        const SizedBox(height: 12),
        if (_exercises.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 24),
            child: Text(
              'Sem exercícios específicos pra esse tipo. Faça 5min de trote leve + mobilidade básica de quadril/tornozelo antes de começar.',
              style: TextStyle(
                color: context.runninPalette.muted,
                fontSize: 13,
                height: 1.5,
              ),
            ),
          )
        else
          ..._exercises.map((ex) => _WarmupExerciseTile(exercise: ex)),
      ],
    );
  }

  // ─── Bottom navigation ──────────────────────────────────────────
  Widget _buildStepNav(BuildContext context, RunninPalette palette) {
    final isLast = _step == 2;
    return Row(
      children: [
        if (_step > 0) ...[
          Expanded(
            child: SizedBox(
              height: 52,
              child: OutlinedButton(
                onPressed: () => setState(() => _step--),
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: palette.border),
                  shape: const RoundedRectangleBorder(
                    borderRadius: BorderRadius.zero,
                  ),
                ),
                child: Text('VOLTAR', style: TextStyle(color: palette.muted)),
              ),
            ),
          ),
          const SizedBox(width: 10),
        ],
        Expanded(
          flex: _step == 0 ? 1 : 2,
          child: SizedBox(
            height: 52,
            child: ElevatedButton(
              onPressed: isLast
                  // Última tela do wizard → vai pra /run em modo IDLE.
                  // INICIAR de verdade acontece na /run (vide ActiveRunPage)
                  // pra dar tempo do user revisar tudo antes do timer rodar.
                  ? () => context.push('/run', extra: _selectedType)
                  : () => setState(() => _step++),
              child: Text(isLast ? 'CONTINUAR' : 'CONTINUAR'),
            ),
          ),
        ),
      ],
    );
  }
}

/// Status visual do GPS exibido no step Config.
enum _GpsStatus { unknown, ok, denied, off }

class _GpsStatusChip extends StatelessWidget {
  final _GpsStatus status;
  final VoidCallback onRetry;
  const _GpsStatusChip({required this.status, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    final palette = context.runninPalette;
    final (label, color) = switch (status) {
      _GpsStatus.unknown => ('CONECTANDO', palette.muted),
      _GpsStatus.ok => ('OK', palette.primary),
      _GpsStatus.denied => ('PERMISSÃO NEGADA', FigmaColors.brandOrange),
      _GpsStatus.off => ('SERVIÇO DESLIGADO', FigmaColors.brandOrange),
    };
    return InkWell(
      onTap: status == _GpsStatus.ok ? null : onRetry,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.15),
          border: Border.all(color: color.withValues(alpha: 0.5), width: 1),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w500,
                color: color,
                letterSpacing: 1.0,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Barra de progresso visual do wizard. 3 segments, ativo destacado.
class _StepProgressBar extends StatelessWidget {
  final int step;
  final int total;
  const _StepProgressBar({required this.step, required this.total});

  @override
  Widget build(BuildContext context) {
    final palette = context.runninPalette;
    return Row(
      children: List.generate(total, (i) {
        final active = i <= step;
        return Expanded(
          child: Container(
            margin: EdgeInsets.only(right: i < total - 1 ? 6 : 0),
            height: 3,
            color: active ? palette.primary : palette.border,
          ),
        );
      }),
    );
  }
}

// --- Coach Cards ---

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

// --- Warmup Exercise Tile ---

class _WarmupExerciseTile extends StatelessWidget {
  final WarmupExercise exercise;

  const _WarmupExerciseTile({required this.exercise});

  @override
  Widget build(BuildContext context) {
    final palette = context.runninPalette;
    final type = context.runninType;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: palette.surface,
          border: Border.all(color: palette.border),
        ),
        child: Row(
          children: [
            Icon(exercise.icon, color: palette.primary, size: 22),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    exercise.title,
                    style: type.bodySm.copyWith(fontWeight: FontWeight.w500),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    exercise.description,
                    style: type.bodySm.copyWith(
                      color: palette.muted,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: palette.primary.withValues(alpha: 0.12),
              ),
              child: Text(
                exercise.reps,
                style: type.labelCaps.copyWith(
                  color: palette.primary,
                  fontSize: 10,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// --- Alert Toggle Row ---

class _AlertToggleRow extends StatelessWidget {
  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _AlertToggleRow({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final palette = context.runninPalette;
    final type = context.runninType;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Expanded(
            child: Text(label, style: type.bodySm),
          ),
          Switch.adaptive(
            value: value,
            onChanged: onChanged,
            activeTrackColor: palette.primary,
          ),
        ],
      ),
    );
  }
}

// --- Music Provider ---

enum _MusicProvider {
  spotify(
    label: 'Spotify',
    icon: Icons.music_note,
    scheme: 'spotify://',
    webUrl: 'https://open.spotify.com',
  ),
  youtubeMusic(
    label: 'YT Music',
    icon: Icons.play_circle_outline,
    scheme: 'vnd.youtube.music://',
    webUrl: 'https://music.youtube.com',
  ),
  appleMusic(
    label: 'Apple Music',
    icon: Icons.library_music,
    scheme: 'music://',
    webUrl: 'https://music.apple.com',
  );

  final String label;
  final IconData icon;
  final String scheme;
  final String webUrl;

  const _MusicProvider({
    required this.label,
    required this.icon,
    required this.scheme,
    required this.webUrl,
  });
}

class _MusicProviderButton extends StatelessWidget {
  final _MusicProvider provider;
  final VoidCallback onTap;

  const _MusicProviderButton({
    required this.provider,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final palette = context.runninPalette;
    final type = context.runninType;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: palette.surface,
          border: Border.all(color: palette.border),
        ),
        child: Column(
          children: [
            Icon(provider.icon, color: palette.primary, size: 24),
            const SizedBox(height: 6),
            Text(
              provider.label,
              style: type.labelCaps.copyWith(fontSize: 10),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

/// Card grande de seleção do modo de corrida. Substitui os chips antigos.
/// `accent: true` destaca a opção principal (sessão do plano).
class _RunModeCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final String description;
  final bool selected;
  final bool accent;
  final VoidCallback onTap;

  const _RunModeCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.description,
    required this.selected,
    required this.accent,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final palette = context.runninPalette;
    final type = context.runninType;
    final borderCol = selected
        ? palette.primary
        : (accent
            ? palette.primary.withValues(alpha: 0.4)
            : palette.border);
    final bgCol = selected
        ? palette.primary.withValues(alpha: 0.12)
        : palette.surface;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: bgCol,
          border: Border.all(color: borderCol, width: selected ? 1.5 : 1.0),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: accent
                    ? palette.primary.withValues(alpha: 0.15)
                    : palette.surface,
                border: Border.all(color: palette.border, width: 1.0),
              ),
              alignment: Alignment.center,
              child: Icon(
                icon,
                size: 20,
                color: accent ? palette.primary : palette.muted,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: type.labelCaps.copyWith(
                      color: palette.text,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      letterSpacing: 1.0,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: type.bodySm.copyWith(
                      color: accent ? palette.primary : palette.muted,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    description,
                    style: type.bodySm.copyWith(
                      color: palette.text.withValues(alpha: 0.78),
                      height: 1.45,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Icon(
              selected ? Icons.check_circle : Icons.radio_button_unchecked,
              size: 20,
              color: selected ? palette.primary : palette.muted,
            ),
          ],
        ),
      ),
    );
  }
}
