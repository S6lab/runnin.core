import 'dart:async';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:runnin/core/audio/coach_audio_player.dart';
import 'package:runnin/core/theme/app_palette.dart';
import 'package:runnin/core/warmup/warmup_exercises.dart';
import 'package:runnin/features/auth/data/user_remote_datasource.dart';
import 'package:runnin/features/run/data/workout_realtime_service.dart';
import 'package:runnin/features/location_weather/data/location_weather_controller.dart';
import 'package:runnin/features/run/data/datasources/run_coach_remote_datasource.dart';
import 'package:runnin/features/run/data/datasources/run_remote_datasource.dart';
import 'package:runnin/features/run/domain/entities/run.dart';
import 'package:runnin/features/run/presentation/bloc/run_bloc.dart';
import 'package:runnin/features/training/data/datasources/plan_remote_datasource.dart';
import 'package:runnin/features/training/domain/entities/plan.dart';
import 'package:runnin/features/subscriptions/presentation/subscription_controller.dart';
import 'package:runnin/features/training/presentation/widgets/execution_timeline.dart';
import 'package:runnin/features/run/presentation/widgets/gps_permission_modal.dart';
import 'package:runnin/shared/widgets/planned_vs_actual_row.dart';
import 'package:runnin/shared/widgets/runnin_app_bar.dart';

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
  final _runRemote = RunRemoteDatasource();
  // Tipo selecionado: 'Free Run' (sempre disponível) ou o type da sessão
  // do plano do dia (quando premium + plano + sessão hoje).
  String _selectedType = 'Free Run';
  // Sessão do plano de HOJE, se existir. Null = freemium OU sem plano OU
  // sem sessão hoje. Mostra o card "Sessão do Plano" no seletor.
  PlanSession? _planTodaySession;
  // Run que executou a sessão do dia (quando session.executedRunId != null).
  // Usado pra mostrar planejado vs feito no card e badge "CONCLUÍDA".
  Run? _executedRunToday;

  StreamSubscription<CoachCue>? _coachSub;
  // Vira true ao navegar pra /run. PrepPage segue montada (push), então
  // bloqueia qualquer cue pre_run tardio de tocar por cima da saudação.
  bool _navigatedToRun = false;
  Timer? _coachDebounce;
  final bool _coachMuted = false;
  bool? _isPro;

  List<WarmupExercise> _exercises = const [];

  /// Wizard step (5 telas):
  ///   0 = TIPO (como vai correr hoje)
  ///   1 = CHECKLIST DA SESSÃO (mesmo padrão do DayDetail)
  ///   2 = ALERTAS + MÚSICA + GPS
  ///   3 = AQUECIMENTO (só mobilidade/exercícios)
  ///   4 = BRIEFING DA SESSÃO (briefing do coach + roteiro km-a-km)
  /// Após CONTINUAR na 5 → /run (corrida ativa).
  int _step = 0;

  /// Status do GPS no warm-up. unknown=ainda checando, ok=permissão+pos
  /// cacheada, denied=permissão recusada, off=serviço desligado.
  _GpsStatus _gpsStatus = _GpsStatus.unknown;

  final Map<String, bool> _alerts = {
    'kmAlert': true,
    'paceOutOfRange': true,
    'highBpm': true,
    'kmSplits': false,
    'motivation': true,
  };

  /// Items do checklist marcados (índice). Gate do step 2 fica liberado
  /// só quando todos os items estão marcados. Reseta sempre que o
  /// conjunto de items muda (troca de tipo de corrida).
  final Set<int> _checkedItems = {};
  int? _checkedItemsLen;

  static const _alertLabels = {
    'kmAlert': 'ALERTA A CADA KM',
    'paceOutOfRange': 'PACE FORA DO RANGE',
    'highBpm': 'BPM ELEVADO',
    'kmSplits': 'SPLITS POR KM',
    'motivation': 'MOTIVAÇÃO',
  };

  static const _alertDescriptions = {
    'kmAlert': 'Coach comenta pace e distância',
    'paceOutOfRange': 'Avisa se sair do alvo',
    'highBpm': 'Alerta se BPM entrar zona 5',
    'kmSplits': 'Mostra split detalhado',
    'motivation': 'Mensagens de motivação durante a corrida',
  };

  @override
  void initState() {
    super.initState();
    // Gate: se user nunca viu o briefing inicial do coach, redireciona
    // pro /coach-intro antes de mostrar prep. Cobre TODOS os caminhos
    // de entrada (home button, nav bar, deep link) — antes só 1 callsite
    // checava `coachIntroSeen` e os outros pulavam o briefing.
    _redirectToCoachIntroIfFirstTime();
    _resolvePremiumThenLoadCue();
    _loadTodaySessionFromPlan();
    _loadExercises();
    // GPS warm-up: solicita permissão + posição inicial AGORA pra que no
    // step 4 (corrida) o stream já esteja autorizado e o primeiro fix
    // tenha menos latência. Falha silenciosa — RunBloc._onStart faz a
    // checagem oficial de novo.
    unawaited(_warmGps());
  }

  Future<void> _warmGps({bool showModalIfNeeded = false}) async {
    try {
      // ignore: avoid_print
      print('gps.prep.warm start showModal=$showModalIfNeeded');
      final enabled = await Geolocator.isLocationServiceEnabled();
      // ignore: avoid_print
      print('gps.prep.service_enabled=$enabled');
      if (!enabled) {
        if (mounted) setState(() => _gpsStatus = _GpsStatus.off);
        if (showModalIfNeeded && mounted) {
          await GpsPermissionModal.show(context, blocked: true);
        }
        return;
      }
      var perm = await Geolocator.checkPermission();
      // ignore: avoid_print
      print('gps.prep.permission_initial=$perm');
      // Se ainda não decidiu E user quer modal: abre modal educacional
      // ANTES do prompt nativo. User vê contexto e clica ATIVAR GPS,
      // o que dispara o requestPermission do browser.
      if (perm == LocationPermission.denied && showModalIfNeeded && mounted) {
        final granted = await GpsPermissionModal.show(context);
        perm = await Geolocator.checkPermission();
        if (!granted &&
            perm != LocationPermission.always &&
            perm != LocationPermission.whileInUse) {
          if (mounted) setState(() => _gpsStatus = _GpsStatus.denied);
          return;
        }
      } else if (perm == LocationPermission.denied) {
        // Caller não quis modal — pede direto (warm-up silencioso original).
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.deniedForever) {
        if (mounted) setState(() => _gpsStatus = _GpsStatus.denied);
        if (showModalIfNeeded && mounted) {
          await GpsPermissionModal.show(context, blocked: true);
        }
        return;
      }
      if (perm == LocationPermission.denied) {
        if (mounted) setState(() => _gpsStatus = _GpsStatus.denied);
        return;
      }
      // Web usa medium + timeLimit pra resolver via WiFi.
      // Alinhado em 20s pro run_bloc (antes 8s) — WiFi triangulation em
      // primeira chamada às vezes leva 10-15s e o cancelamento aqui
      // estava deixando o chip eternamente "PROCURANDO" no prep.
      final settings = kIsWeb
          ? const LocationSettings(
              accuracy: LocationAccuracy.medium,
              timeLimit: Duration(seconds: 20),
            )
          : const LocationSettings(accuracy: LocationAccuracy.high);
      try {
        final p = await Geolocator.getCurrentPosition(locationSettings: settings);
        // ignore: avoid_print
        print('gps.prep.first_fix accuracy=${p.accuracy.toStringAsFixed(0)}m');
      } catch (err) {
        // ignore: avoid_print
        print('gps.prep.first_fix_failed: $err — tentando lastKnown');
        try {
          await Geolocator.getLastKnownPosition();
        } catch (e2) {
          // ignore: avoid_print
          print('gps.prep.cache_failed: $e2');
        }
      }
      if (mounted) setState(() => _gpsStatus = _GpsStatus.ok);
    } catch (err) {
      // ignore: avoid_print
      print('gps.prep.warm_failed: $err');
      if (mounted) setState(() => _gpsStatus = _GpsStatus.off);
    }
  }

  Future<void> _loadTodaySessionFromPlan() async {
    try {
      final plan = await _planRemote.getCurrentPlan();
      if (!mounted || plan == null || !plan.isReady) return;
      final today = DateTime.now().weekday; // 1=Mon..7=Sun
      // Semana civil (seg→dom). Antes usávamos floor(daysFromStart/7) que
      // colocava 1 dia após start na "semana 0" (errado quando o plano
      // começa num domingo e hoje é segunda: deveria ser semana 2, não
      // semana 1). Mesma fórmula do server `currentWeekNumber`.
      final start = plan.effectiveStartDate;
      final mondayOfStart = _startOfCivilWeek(start);
      final mondayOfToday = _startOfCivilWeek(DateTime.now());
      final diffWeeks = mondayOfToday.difference(mondayOfStart).inDays ~/ 7;
      // RUN 1/5 mostra a sessão do dia DO SNAPSHOT VIGENTE (revisão semanal
      // pode ter trocado a sessão de hoje vs o plano base).
      final weeksRef = plan.effectiveWeeks;
      final weekNumber = (diffWeeks + 1).clamp(1, weeksRef.length);
      final week = weeksRef
          .firstWhere((w) => w.weekNumber == weekNumber, orElse: () => weeksRef.first);
      final session = week.sessions
          .where((s) => s.dayOfWeek == today)
          .cast<PlanSession?>()
          .firstWhere((_) => true, orElse: () => null);
      if (mounted && session != null) {
        // Se já foi executada, default vira Free Run (user pode rodar uma
        // segunda sessão livre pra complementar carga); senão, pré-seleciona
        // a sessão do plano como antes.
        setState(() {
          _planTodaySession = session;
          _selectedType = session.isExecuted ? 'Free Run' : session.type;
        });
        _loadExercises();
        // Se a sessão foi executada, busca a Run vinculada pra alimentar
        // o comparativo planejado vs feito no card. Best-effort — falha
        // silenciosa deixa o card sem stats do feito (ainda mostra badge
        // CONCLUÍDA via session.isExecuted).
        if (session.isExecuted) {
          unawaited(() async {
            try {
              final run = await _runRemote.getRun(session.executedRunId!);
              if (mounted) setState(() => _executedRunToday = run);
            } catch (_) {/* segue sem stats do feito */}
          }());
        }
        // Empurra a sessão pro Watch pra ele mostrar "SESSÃO DO DIA" no
        // TypeSelectorScreen. Best-effort — Watch app pode não estar
        // instalado, plugin skipa silenciosamente. Quando isExecuted=true,
        // o Watch troca o botão "INICIAR SESSÃO" por badge "CONCLUÍDA"
        // e deixa só a Free Run disponível como ação.
        unawaited(workoutRealtimeService.pushRunState({
          'type': 'today_session',
          'session': {
            'type': session.type,
            'distanceKm': session.distanceKm,
            'planSessionId': session.id,
            'isExecuted': session.isExecuted,
          },
        }));
      } else if (mounted) {
        // Sem sessão hoje — limpa a vista do Watch (only_free_run).
        unawaited(workoutRealtimeService.pushRunState({
          'type': 'today_session',
          'session': null,
        }));
      }
    } catch (_) {/* Sem plano OU erro de network — segue free run */}
  }

  /// Segunda-feira 00:00 LOCAL da semana civil que contém [d]. Espelha
  /// `startOfCivilWeek` do server (checkpoint-shared.ts) pra avaliação
  /// de semana atual coerente entre os dois lados.
  DateTime _startOfCivilWeek(DateTime d) {
    final local = DateTime(d.year, d.month, d.day);
    final back = local.weekday - 1; // weekday: Mon=1..Sun=7 → back 0..6
    return local.subtract(Duration(days: back));
  }

  /// Se profile.coachIntroSeen != true, manda o user pro briefing inicial
  /// e SAI desse prep (redirect imediato). Best-effort: se fetch falhar
  /// (offline, etc), segue sem redirect — user pode acessar o briefing
  /// depois pelo menu de PERFIL. Freemium NÃO é redirecionado — o coach
  /// AI ao vivo é premium, então o intro do coach não se aplica.
  Future<void> _redirectToCoachIntroIfFirstTime() async {
    try {
      final profile = await _userRemote.getMe().timeout(
            const Duration(seconds: 2),
            onTimeout: () => null,
          );
      if (!mounted) return;
      if (!(profile?.isPro ?? false)) return;
      final seen = profile?.coachIntroSeen ?? false;
      if (!seen) {
        // Pequena espera pra evitar race com transitions do GoRouter.
        await Future.delayed(const Duration(milliseconds: 50));
        if (!mounted) return;
        context.go('/coach-intro');
      }
    } catch (_) {/* segue sem redirect */}
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
    // Freemium não tem coach AI — não dispara cue de pre_run no backend.
    // Premium mantém debounce pra re-pedir cue quando o tipo muda no prep.
    if (_isPro != true) return;
    _coachDebounce = Timer(
      const Duration(milliseconds: 350),
      _requestPreRunCue,
    );
  }

  void _requestPreRunCue() {
    if (_navigatedToRun) return;
    // Hard gate: freemium não consome /coach/cue. Defensivo — call sites já
    // bloqueiam, mas evita regressão se alguém esquecer.
    if (_isPro != true) return;
    _coachSub?.cancel();

    final weather = locationWeatherController.weather;
    _coachSub = _coachRemote
        .streamCoachCue(
          event: 'pre_run',
          runType: _selectedType,
          currentPaceMinKm: 0,
          distanceM: 0,
          elapsedS: 0,
          temperatureC: weather?.temperatureC,
          humidityPercent: weather?.humidityPercent,
          windKmh: weather?.windKmh,
        )
        .listen(
          (cue) {
            if (!mounted) return;
            final audio = cue.audioBase64;
            if (!_navigatedToRun && !_coachMuted && audio != null && audio.isNotEmpty) {
              playCoachAudio(
                audio,
                mimeType: cue.audioMimeType ?? 'audio/mpeg',
                volume: 1.0,
              );
            }
          },
        );
  }

  // Toggle PER-SESSION: vale só pra esta corrida (herda do default global
  // carregado no init). Não grava no perfil — pra virar padrão, o user usa
  // "Salvar como padrão".
  void _toggleAlert(String key, bool value) {
    setState(() => _alerts[key] = value);
  }

  Future<void> _saveAlertsAsDefault() async {
    await _userRemote.patchMe(preRunAlerts: Map<String, bool>.from(_alerts));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Alertas salvos como padrão.'),
          duration: Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
        ),
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
          title: 'PREPARAR · ${_step + 1}/5',
        ),
        body: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _StepProgressBar(step: _step, total: 5),
              const SizedBox(height: 16),
              Expanded(
                child: SingleChildScrollView(
                  // Ordem: 0 TIPO → 1 CHECKLIST → 2 ALERTAS →
                  // 3 AQUECIMENTO → 4 BRIEFING DA SESSÃO
                  child: switch (_step) {
                    0 => _buildTypeStep(context, type),
                    1 => _buildChecklistStep(context, type),
                    2 => _buildConfigStep(context, type),
                    3 => _buildWarmupStep(context, type),
                    _ => _buildBriefingStep(context, type),
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

  // ─── Step 1: Config (alertas + música + GPS) ────────────────────
  // Coach card REMOVIDO daqui — coach só fala na tela 4 (corrida ativa)
  // via saudação disparada no INICIAR. Evita áudio inesperado no prep.
  Widget _buildConfigStep(BuildContext context, RunninTypography type) {
    final palette = context.runninPalette;
    final isPro = _isPro == true;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text('GPS', style: type.displaySm),
            const SizedBox(width: 10),
            _GpsStatusChip(
              status: _gpsStatus,
              onRetry: () => _warmGps(showModalIfNeeded: true),
            ),
          ],
        ),
        const SizedBox(height: 32),
        Text('ALERTAS', style: type.displaySm),
        const SizedBox(height: 4),
        Text(
          isPro
              ? 'Valem só para esta corrida (herdam do seu padrão).'
              : 'Na versão grátis, a telemetria fala automática a cada km com pace e tempo. Os toggles abaixo ainda valem para esta corrida.',
          style: type.bodyXs.copyWith(color: palette.muted),
        ),
        const SizedBox(height: 14),
        ..._alerts.entries.map(
          (e) => _AlertToggleRow(
            label: _alertLabels[e.key] ?? e.key,
            description: _alertDescriptions[e.key],
            value: e.value,
            onChanged: (v) => _toggleAlert(e.key, v),
          ),
        ),
        const SizedBox(height: 8),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton(
            onPressed: _saveAlertsAsDefault,
            child: const Text('SALVAR COMO PADRÃO'),
          ),
        ),
      ],
    );
  }

  // ─── Step 2: Tipo de corrida ────────────────────────────────────
  Widget _buildTypeStep(BuildContext context, RunninTypography type) {
    final session = _planTodaySession;
    final hasPlanned = session != null && _isPro == true;
    final isPro = _isPro == true;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header mono cyan estilo "// INICIAR CORRIDA" (sem >).
        Text(
          '// INICIAR CORRIDA',
          style: type.bodyMd.copyWith(
            color: context.runninPalette.primary,
            fontWeight: FontWeight.w500,
            letterSpacing: 1.5,
          ),
        ),
        const SizedBox(height: 24),
        if (hasPlanned) ...[
          _PlanSessionHeroCard(
            session: session,
            selected: _selectedType == session.type,
            onTap: () => _selectType(session.type),
            executedRun: _executedRunToday,
          ),
          const SizedBox(height: 12),
          // Free Run continua disponível, mas como opção secundária menor.
          // Pill "Integrado ao relatório semanal" mora DENTRO desse card
          // pra deixar claro que mesmo Free Run alimenta o report semanal.
          _SecondaryModeCard(
            label: 'CORRIDA LIVRE',
            description:
                'Sai sem protocolo. Coach observa e usa esses dados no próximo checkpoint semanal pra ajustar as 2 próximas semanas do plano.',
            selected: _selectedType == 'Free Run',
            footerLabel: 'Integrado ao relatório semanal',
            onTap: () => _selectType('Free Run'),
          ),
        ] else ...[
          _PlanSessionHeroCard(
            session: null,
            isFreeOnly: true,
            isPro: isPro,
            selected: true,
            onTap: () => _selectType('Free Run'),
          ),
          // Freemium-only: CTA pro paywall logo abaixo do hero. Deixa
          // explícito que a corrida grátis só registra histórico +
          // telemetria — sem coach ao vivo, sem análise, sem planejamento.
          if (!isPro) ...[
            const SizedBox(height: 12),
            const _FreemiumUpgradeCard(
              title: 'COACH AI AO VIVO É PREMIUM',
              description:
                  'Sua corrida livre salva histórico e fala a telemetria (pace, tempo, distância) a cada km. Não rola coach analisando ou ajustando o plano pelo checkpoint semanal. Pra isso, assine o premium.',
            ),
          ],
        ],
      ],
    );
  }

  // ─── Step 2: Checklist da sessão ────────────────────────────────
  Widget _buildChecklistStep(BuildContext context, RunninTypography type) {
    final palette = context.runninPalette;
    final isPlanned = _planTodaySession != null &&
        _selectedType == _planTodaySession!.type;
    final session = isPlanned ? _planTodaySession : null;

    final items = _buildChecklistItems(session);
    // Reseta marcações se mudou o tamanho do checklist (troca de tipo).
    // Sem isso, marcar item 3 num checklist de 5 e trocar pro de 7 deixa
    // item 3 "marcado" no novo conjunto que pode ser outro item.
    if (_checkedItemsLen != items.length) {
      _checkedItems.clear();
      _checkedItemsLen = items.length;
    }
    final isPro = _isPro == true;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('CHECKLIST DA SESSÃO', style: type.displaySm),
        const SizedBox(height: 14),
        // Coach card de contexto: o que/quanto/por quê dessa sessão.
        // Freemium: vira card de telemetria sem o "Coach.AI" namespace.
        _CoachAccentCard(
          topic: 'PREPARO',
          isPro: isPro,
          body: isPlanned
              ? '${session!.type} · ${session.distanceKm.toStringAsFixed(session.distanceKm % 1 == 0 ? 0 : 1)}km. '
                  'Revise os itens abaixo antes de sair — economia de fôlego no quilômetro 1.'
              : 'Corrida livre. Faça uma revisão rápida — hidratação, calçado e telefone carregado evitam dor de cabeça no meio do trajeto.',
          accent: context.runninPalette.primary,
        ),
        const SizedBox(height: 14),
        // Estado do Apple Watch companion (iOS apenas — Android/web fica null).
        // Quando paired+installed+reachable está OK, mostra confirmação verde.
        // Quando falta algo, instrui o user (conecta Watch / instala o app).
        const _WatchStatusBanner(),
        const SizedBox(height: 14),
        // Tiles checkáveis. Gate do CONTINUAR depende de todos marcados.
        for (var i = 0; i < items.length; i++) ...[
          if (i > 0) const SizedBox(height: 8),
          InkWell(
            onTap: () => setState(() {
              if (_checkedItems.contains(i)) {
                _checkedItems.remove(i);
              } else {
                _checkedItems.add(i);
              }
            }),
            child: Container(
              padding: const EdgeInsets.fromLTRB(14, 12, 16, 12),
              decoration: BoxDecoration(
                color: palette.surface,
                border: Border.all(
                  color: _checkedItems.contains(i) ? palette.primary : palette.border,
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 2, right: 10),
                    child: Icon(
                      _checkedItems.contains(i)
                          ? Icons.check_box_outlined
                          : Icons.check_box_outline_blank,
                      size: 18,
                      color: _checkedItems.contains(i) ? palette.primary : palette.muted,
                    ),
                  ),
                  Expanded(
                    child: Text(
                      items[i].toUpperCase(),
                      style: type.bodySm.copyWith(
                        color: _checkedItems.contains(i) ? palette.text : palette.muted,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
        const SizedBox(height: 16),
        // Pular o checklist: avança sem exigir todos os itens marcados.
        Align(
          alignment: Alignment.center,
          child: TextButton(
            onPressed: () => setState(() => _step++),
            child: Text(
              'PULAR ESTA ETAPA  →',
              style: type.bodySm.copyWith(
                color: palette.muted,
                letterSpacing: 1.0,
              ),
            ),
          ),
        ),
      ],
    );
  }

  /// Items adaptados ao tipo (Long → gel + garrafa; Intervalado → aquecimento
  /// robusto; etc.) Free Run cai no caso genérico (sem session).
  List<String> _buildChecklistItems(PlanSession? s) {
    final items = <String>[];
    final type = (s?.type ?? 'free run').toLowerCase();
    final isLong = type.contains('long');
    final isInterval = type.contains('interval') || type.contains('tiro');
    final isTempo = type.contains('tempo');
    final hydration = s?.hydrationLiters;
    final pre = s?.nutritionPre?.trim();

    items.add(
      hydration != null
          ? 'Hidratei ao longo do dia (meta: ${hydration.toStringAsFixed(1)}L)'
          : 'Hidratei bem ao longo do dia',
    );
    if (pre != null && pre.isNotEmpty) {
      items.add('Comi 60-90min antes: $pre');
    } else {
      items.add('Refeição leve 60-90min antes (carbo + pouca gordura)');
    }
    if (isLong) {
      items.add('Levei gel/banana se passar de 60min');
      items.add('Garrafa de água ou eletrólito comigo');
    }
    if (isInterval) {
      items.add('Aquecimento robusto (10-12min) + educativos');
    }
    if (isTempo) {
      items.add('Aquecimento progressivo (8-10min) antes do tempo');
    }
    items.add('Tênis confortável + cadarço firme');
    items.add('GPS ativo, celular e relógio carregados');
    items.add('Fone com Coach AI pronto');
    return items;
  }

  // ─── Step 3: Aquecimento (só mobilidade/exercícios) ─────────────
  Widget _buildWarmupStep(BuildContext context, RunninTypography type) {
    final palette = context.runninPalette;
    final session = _planTodaySession;
    final hasPlanned = session != null;
    final isPro = _isPro == true;

    final tipText = !hasPlanned
        ? 'Faça 5min de trote leve antes de começar — articulações soltas + frequência cardíaca elevada gradualmente reduzem chance de lesão e melhoram o desempenho.'
        : 'Pra sessões de ${session.type.toLowerCase()}, foque em tornozelos, quadril e panturrilha. Em dias de intervalados, adicione Skip A e leg swings pra ativar fibras rápidas.';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'AQUECIMENTO & MOBILIDADE',
          style: type.displaySm,
        ),
        const SizedBox(height: 14),
        _CoachAccentCard(
          topic: 'MOBILIDADE PRÉ-CORRIDA',
          isPro: isPro,
          body:
              'Prepare articulações e ative cadeias musculares antes de correr. 5-8 minutos reduzem risco de lesão e melhoram economia de corrida.',
          accent: context.runninPalette.primary,
        ),
        const SizedBox(height: 14),
        if (_exercises.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Text(
              'Sem exercícios específicos pra esse tipo. Faça 5min de trote leve + mobilidade básica de quadril/tornozelo.',
              style: type.bodySm.copyWith(color: palette.muted),
            ),
          )
        else
          ..._exercises.map((ex) => _WarmupExerciseTile(exercise: ex)),
        const SizedBox(height: 8),
        _CoachAccentCard(
          topic: 'DICA',
          isPro: isPro,
          body: tipText,
          accent: context.runninPalette.secondary,
        ),
      ],
    );
  }

  // ─── Step 4: Briefing da sessão (briefing do coach + roteiro km-a-km)
  // O roteiro reusa o mesmo widget do detalhe da sessão em TREINO/PLANO/
  // SEMANA (ExecutionTimeline).
  Widget _buildBriefingStep(BuildContext context, RunninTypography type) {
    final palette = context.runninPalette;
    final session = _planTodaySession;
    final hasPlanned = session != null &&
        _selectedType == session.type;
    final isPro = _isPro == true;

    // Briefing dinâmico: usa notes da sessão se houver, senão monta linha
    // genérica com tipo + km + pace. Freemium é explícito: só histórico +
    // telemetria, sem coach analisando a corrida nem planejando a próxima.
    final briefingText = !hasPlanned
        ? (isPro
            ? 'Corrida livre. Sem distância pré-definida — coach observa e usa esses dados no checkpoint semanal pra ajustar as 2 próximas semanas do plano.'
            : 'Corrida livre. Salvamos o histórico desta corrida e a telemetria km a km. Não há coach analisando a sessão nem planejando a próxima — isso é premium.')
        : (session.notes.trim().isNotEmpty
            ? session.notes.trim()
            : '${session.type} hoje — '
                '${session.distanceKm.toStringAsFixed(session.distanceKm % 1 == 0 ? 0 : 1)}km'
                '${session.targetPace != null ? ", pace alvo ${session.targetPace}/km" : ""}. '
                'Foco em consistência.');

    final segments = hasPlanned ? session.executionSegments : const <PlanSegment>[];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('BRIEFING DA SESSÃO', style: type.displaySm),
        const SizedBox(height: 14),
        _CoachAccentCard(
          topic: 'BRIEFING',
          isPro: isPro,
          body: briefingText,
          accent: context.runninPalette.secondary,
        ),
        if (!isPro) ...[
          const SizedBox(height: 12),
          const _FreemiumUpgradeCard(
            title: 'COACH ANALISA E PLANEJA — PREMIUM',
            description:
                'Premium: coach AI ao vivo durante a corrida, análise pós-sessão e ajuste automático das 2 próximas semanas via checkpoint semanal. Freemium: só histórico + telemetria falada a cada km, sem análise nem planejamento.',
          ),
        ],
        if (segments.isNotEmpty) ...[
          const SizedBox(height: 28),
          ExecutionTimeline(segments: segments),
        ] else if (hasPlanned) ...[
          const SizedBox(height: 20),
          Text(
            'Roteiro km-a-km ainda não disponível para esta sessão.',
            style: type.bodySm.copyWith(color: palette.muted),
          ),
        ],
      ],
    );
  }

  /// Navega pra /run passando type + planSessionId quando for sessão
  /// do plano. Se a sessão já foi executada antes (executedRunId !=
  /// null), avisa o user que a nova run vai sobrescrever a anterior.
  Future<void> _continueToRun(BuildContext context) async {
    final isPlannedSession = _planTodaySession != null &&
        _selectedType == _planTodaySession!.type;
    final session = isPlannedSession ? _planTodaySession : null;

    if (session != null && session.isExecuted) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('SOBRESCREVER CORRIDA ANTERIOR?'),
          content: Text(
            'Você já completou a sessão "${session.type} · ${session.distanceKm.toStringAsFixed(session.distanceKm % 1 == 0 ? 0 : 1)}km" do plano hoje. '
            'Iniciar de novo vai SOBRESCREVER o registro anterior dessa sessão.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('CANCELAR'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('SOBRESCREVER'),
            ),
          ],
        ),
      );
      if (confirmed != true || !context.mounted) return;
    }

    final extra = <String, dynamic>{
      'type': _selectedType,
      if (session != null) 'planSessionId': session.id,
      // Toggles per-session: o que o user ligou/desligou pra ESTA corrida.
      'alertPrefs': Map<String, bool>.from(_alerts),
      // Plano resolvido aqui: freemium → TTS de telemetria a cada km;
      // premium → Coach AI ao vivo (LiveRunCoachSession). Server checa
      // de novo, mas o client decide qual sessão abrir já no INICIAR
      // pra evitar montar o socket Live pro freemium em vão. Fallback
      // pro subscriptionController quando _isPro ainda não resolveu
      // (network lenta no prep).
      'isPremium': _isPro ?? subscriptionController.isPro,
    };
    if (!context.mounted) return;
    // push() mantém a PrepPage viva sob a /run (dispose não roda), então o
    // cue pre_run (stream + debounce do _selectType) continua tocando por
    // cima da saudação da corrida = "dois coaches". Corta tudo e bloqueia
    // novos cues via _navigatedToRun antes de navegar.
    _navigatedToRun = true;
    _coachDebounce?.cancel();
    _coachSub?.cancel();
    _coachSub = null;
    context.push('/run', extra: extra);
  }

  // ─── Bottom navigation ──────────────────────────────────────────
  Widget _buildStepNav(BuildContext context, RunninPalette palette) {
    final isLast = _step == 4;
    // Gate do step 1 (CHECKLIST): só libera CONTINUAR quando todos os
    // items estão marcados. Item explícito do produto pra forçar revisão.
    final checklistBlocked = _step == 1 &&
        _checkedItemsLen != null &&
        _checkedItems.length < _checkedItemsLen!;
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
                child: Text('VOLTAR', style: context.runninType.bodyMd.copyWith(color: palette.muted)),
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
              onPressed: checklistBlocked
                  ? null
                  : (isLast
                      // Última tela do wizard → vai pra /run em modo IDLE.
                      // INICIAR de verdade acontece na /run (vide ActiveRunPage)
                      // pra dar tempo do user revisar tudo antes do timer rodar.
                      ? () => _continueToRun(context)
                      : () => setState(() => _step++)),
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
      _GpsStatus.denied => ('PERMISSÃO NEGADA', context.runninPalette.secondary),
      _GpsStatus.off => ('SERVIÇO DESLIGADO', context.runninPalette.secondary),
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
              style: context.runninType.labelCaps.copyWith(
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
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Icon(exercise.icon, color: palette.primary, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Linha 1: título à esquerda, reps mono cyan à direita.
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          exercise.title.toUpperCase(),
                          style: type.labelCaps.copyWith(
                            color: palette.text,
                            fontSize: 12,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        exercise.reps,
                        style: type.labelCaps.copyWith(color: palette.primary),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    exercise.description,
                    style: type.labelCaps.copyWith(color: palette.muted),
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

/// Card de contexto do coach (BRIEFING / MOBILIDADE / DICA). Borda
/// esquerda colorida + "COACH.AI > TOPIC" (premium) ou "TELEMETRIA >
/// TOPIC" (freemium) header em mono + corpo em aspas. Cor configurável.
class _CoachAccentCard extends StatelessWidget {
  final String topic;
  final String body;
  final Color accent;
  // Freemium: troca prefix "COACH.AI" por "TELEMETRIA" pra não prometer
  // coach AI ao vivo. Default true pra manter retro-compat das call sites
  // que ainda não passam o flag.
  final bool isPro;
  const _CoachAccentCard({
    required this.topic,
    required this.body,
    required this.accent,
    this.isPro = true,
  });

  @override
  Widget build(BuildContext context) {
    final palette = context.runninPalette;
    final type = context.runninType;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: BoxDecoration(
        color: palette.surface,
        border: Border(
          left: BorderSide(color: accent, width: 2.5),
          top: BorderSide(color: palette.border),
          right: BorderSide(color: palette.border),
          bottom: BorderSide(color: palette.border),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${isPro ? "COACH.AI" : "TELEMETRIA"} > $topic',
            style: type.labelMd.copyWith(color: accent),
          ),
          const SizedBox(height: 10),
          Text(
            '"$body"',
            style: type.bodySm.copyWith(
              color: palette.text.withValues(alpha: 0.78),
            ),
          ),
        ],
      ),
    );
  }
}

/// Banner inline com CTA pra paywall — usado em telas do prep quando o
/// user é freemium pra explicar diferença entre TTS de telemetria e o
/// Coach AI ao vivo + empurrar pra assinatura.
class _FreemiumUpgradeCard extends StatelessWidget {
  final String title;
  final String description;
  const _FreemiumUpgradeCard({required this.title, required this.description});

  @override
  Widget build(BuildContext context) {
    final palette = context.runninPalette;
    final type = context.runninType;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
      decoration: BoxDecoration(
        color: palette.primary.withValues(alpha: 0.08),
        border: Border.all(color: palette.primary, width: 1.041),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.lock_outline, size: 16, color: palette.primary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: type.labelMd.copyWith(
                    color: palette.primary,
                    letterSpacing: 1.2,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            description,
            style: type.bodySm.copyWith(
              color: palette.text.withValues(alpha: 0.75),
              height: 1.5,
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            height: 40,
            child: ElevatedButton(
              onPressed: () {
                final encoded = Uri.encodeQueryComponent('/run/prep');
                context.push('/paywall?next=$encoded');
              },
              child: const Text('ASSINAR PREMIUM'),
            ),
          ),
        ],
      ),
    );
  }
}

// --- Alert Toggle Row ---

class _AlertToggleRow extends StatelessWidget {
  final String label;
  final String? description;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _AlertToggleRow({
    required this.label,
    required this.value,
    required this.onChanged,
    this.description,
  });

  @override
  Widget build(BuildContext context) {
    final palette = context.runninPalette;
    final type = context.runninType;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
        decoration: BoxDecoration(
          color: palette.surface,
          border: Border.all(color: palette.border),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: type.labelCaps.copyWith(
                      color: palette.text,
                      fontSize: 12,
                      letterSpacing: 0.5,
                    ),
                  ),
                  if (description != null && description!.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      description!,
                      style: type.labelCaps.copyWith(color: palette.muted),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 8),
            // Cores da skin: LIGADO = trilho ciano + polegar preto; DESLIGADO
            // = trilho escuro + polegar cinza. Antes o polegar ficava branco
            // (Switch.adaptive default) e destoava dos cards escuros.
            Switch(
              value: value,
              onChanged: onChanged,
              thumbColor: WidgetStateProperty.resolveWith(
                (states) => states.contains(WidgetState.selected)
                    ? palette.background
                    : palette.muted,
              ),
              trackColor: WidgetStateProperty.resolveWith(
                (states) => states.contains(WidgetState.selected)
                    ? palette.primary
                    : palette.surfaceAlt,
              ),
              trackOutlineColor: WidgetStateProperty.all(palette.border),
            ),
          ],
        ),
      ),
    );
  }
}

/// Card grande de seleção do modo de corrida. Substitui os chips antigos.
/// `accent: true` destaca a opção principal (sessão do plano).
/// Card hero da sessão planejada — destaca tipo, distância, pace alvo
/// e indica que coach vai guiar a sessão. Tag "RECOMENDADO" no canto.
/// Fallback pra Free Run quando não há plano (mostra como única opção).
class _PlanSessionHeroCard extends StatelessWidget {
  final PlanSession? session;
  final bool selected;
  final VoidCallback onTap;
  final bool isFreeOnly;
  final bool isPro;
  /// Run que executou a sessão, quando session.isExecuted. Habilita o
  /// modo "CONCLUÍDA" com 3 linhas de planejado vs feito (distância,
  /// pace, duração).
  final Run? executedRun;
  const _PlanSessionHeroCard({
    required this.session,
    required this.selected,
    required this.onTap,
    this.isFreeOnly = false,
    this.isPro = false,
    this.executedRun,
  });

  String _fmtKm(double km) =>
      km % 1 == 0 ? '${km.toInt()}K' : '${km.toStringAsFixed(1)}K';

  @override
  Widget build(BuildContext context) {
    final palette = context.runninPalette;
    final type = context.runninType;
    final isExecuted = !isFreeOnly && (session?.isExecuted ?? false);
    final label = isFreeOnly ? 'FREE RUN' : 'SESSÃO DO PLANO';
    final title = (isFreeOnly
            ? 'Corrida livre'
            : (session?.type ?? '').replaceAll('_', ' '))
        .toUpperCase();
    final dist = session?.distanceKm;
    final pace = session?.targetPace;
    final desc = isFreeOnly
        ? (isPro
            ? 'Sem sessão planejada hoje. Coach observa o que você faz.'
            : 'Versão grátis. Plano AI personalizado é premium ↗')
        : (isExecuted
            ? 'Sessão concluída — você pode sair pra uma Free Run pra complementar a carga da semana.'
            : 'Coach IA irá te guiar durante toda a sessão ↗');
    final borderColor = selected
        ? context.runninPalette.primary
        : context.runninPalette.primary.withValues(alpha: 0.4);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: selected
              ? context.runninPalette.primary.withValues(alpha: 0.06)
              : palette.surface,
          border: Border.all(color: borderColor, width: selected ? 2 : 1.5),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header row: label (mono cyan) + RECOMENDADO badge.
            Row(
              children: [
                Expanded(
                  child: Text(
                    label,
                    style: type.labelMd.copyWith(
                      color: context.runninPalette.primary,
                      fontWeight: FontWeight.w500,
                      letterSpacing: 1.5,
                    ),
                  ),
                ),
                if (!isFreeOnly)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    color: isExecuted
                        ? context.runninPalette.success
                        : context.runninPalette.primary,
                    child: Text(
                      isExecuted ? 'CONCLUÍDA' : 'RECOMENDADO',
                      style: type.labelCaps.copyWith(
                        color: palette.background,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            // Título grande (sentence case) — Easy Run, Tempo Run, etc.
            Text(
              title,
              style: type.displayMd.copyWith(
                color: palette.text,
                letterSpacing: -0.6,
              ),
            ),
            if (isExecuted && session != null) ...[
              const SizedBox(height: 20),
              // Sessão concluída: 3 linhas META vs FEITO. Quando executedRun
              // ainda não chegou (request em flight), só mostra META.
              PlannedVsActualRow(
                label: 'DISTÂNCIA',
                planned: _fmtKm(session!.distanceKm),
                actual: executedRun != null
                    ? '${(executedRun!.distanceM / 1000).toStringAsFixed(1)}K'
                    : null,
              ),
              const SizedBox(height: 6),
              PlannedVsActualRow(
                label: 'PACE',
                planned: session!.targetPace != null
                    ? '${session!.targetPace}/km'
                    : '—',
                actual: executedRun?.avgPace != null
                    ? '${executedRun!.avgPace}/km'
                    : null,
              ),
              const SizedBox(height: 6),
              PlannedVsActualRow(
                label: 'DURAÇÃO',
                planned: session!.durationMin != null
                    ? '${session!.durationMin!.round()}min'
                    : '—',
                actual: executedRun != null
                    ? '${(executedRun!.durationS / 60).round()}min'
                    : null,
              ),
            ] else if (dist != null || pace != null) ...[
              const SizedBox(height: 20),
              // 2-column stat grid: DIST | PACE ALV.
              Row(
                children: [
                  if (dist != null)
                    Expanded(
                      child: _HeroStatCell(
                        label: 'DIST',
                        value: _fmtKm(dist),
                      ),
                    ),
                  if (pace != null)
                    Expanded(
                      child: _HeroStatCell(
                        label: 'PACE ALV',
                        value: '$pace/km',
                      ),
                    ),
                ],
              ),
            ],
            const SizedBox(height: 18),
            Text(
              desc,
              style: type.bodyMd.copyWith(
                color: palette.text.withValues(alpha: 0.55),
                fontSize: 13,
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HeroStatCell extends StatelessWidget {
  final String label;
  final String value;
  const _HeroStatCell({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final palette = context.runninPalette;
    final type = context.runninType;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: type.labelCaps.copyWith(
            color: palette.text.withValues(alpha: 0.5),
            fontSize: 11,
            fontWeight: FontWeight.w500,
            letterSpacing: 1.2,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          value,
          style: type.dataXs.copyWith(
            color: context.runninPalette.secondary,
            fontSize: 24,
            letterSpacing: -0.5,
          ),
        ),
      ],
    );
  }
}

/// Card secundário compacto pra Free Run quando há plano (opção
/// alternativa de-emphasized).
class _SecondaryModeCard extends StatelessWidget {
  final String label;
  final String description;
  final bool selected;
  final VoidCallback onTap;
  final String? footerLabel;
  const _SecondaryModeCard({
    required this.label,
    required this.description,
    required this.selected,
    required this.onTap,
    this.footerLabel,
  });

  @override
  Widget build(BuildContext context) {
    final palette = context.runninPalette;
    final type = context.runninType;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: selected
              ? palette.primary.withValues(alpha: 0.08)
              : palette.surface,
          border: Border.all(
            color: selected ? palette.primary : palette.border,
            width: selected ? 1.5 : 1.0,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        label,
                        style: type.labelMd.copyWith(
                          color: palette.text,
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          letterSpacing: 1.2,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        description,
                        style: type.bodySm.copyWith(
                          color: palette.text.withValues(alpha: 0.6),
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                Icon(
                  selected
                      ? Icons.radio_button_checked
                      : Icons.radio_button_unchecked,
                  size: 18,
                  color: selected ? palette.primary : palette.muted,
                ),
              ],
            ),
            if (footerLabel != null) ...[
              const SizedBox(height: 12),
              // Pill compacto laranja — sinaliza que mesmo Free Run
              // alimenta o relatório semanal pro coach ajustar a próxima.
              Row(
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    color: context.runninPalette.secondary,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      footerLabel!,
                      style: type.labelCaps.copyWith(
                        color: context.runninPalette.secondary,
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        letterSpacing: 0.4,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Card pequeno que reflete o estado do Apple Watch companion no pre-run.
/// Estados:
///   - paired+installed+reachable: verde, "Apple Watch conectado · BPM em
///     tempo real durante a corrida"
///   - paired+installed mas não reachable: amarelo, "Apple Watch pareado
///     mas app não respondeu — abra o Runnin no Watch e tente de novo"
///   - paired mas !installed: amarelo, "Instale o Runnin no seu Apple Watch
///     (app Watch → toque em INSTALAR no Runnin)"
///   - !paired: muted, "Sem Apple Watch pareado — BPM cai pra polling lento"
///   - null (Android/web): widget some via SizedBox.shrink
class _WatchStatusBanner extends StatelessWidget {
  const _WatchStatusBanner();

  @override
  Widget build(BuildContext context) {
    final palette = context.runninPalette;
    final type = context.runninType;
    final status = context.select<RunBloc, WatchPairingStatus?>(
      (b) => b.state.watchStatus,
    );
    // Android / web / iOS antes do plugin emitir nada → não renderiza.
    if (status == null) return const SizedBox.shrink();

    final ({String label, Color color, IconData icon}) info;
    if (status.isOptimal) {
      info = (
        label: 'Apple Watch conectado · BPM em tempo real',
        color: palette.primary,
        icon: Icons.watch,
      );
    } else if (status.paired && status.appInstalled) {
      info = (
        label: 'Watch pareado, app não respondeu — abra o Runnin no Watch',
        color: palette.muted,
        icon: Icons.watch_off_outlined,
      );
    } else if (status.paired) {
      info = (
        label: 'Instale o Runnin no Apple Watch pra ler BPM em tempo real',
        color: palette.muted,
        icon: Icons.download_for_offline_outlined,
      );
    } else {
      info = (
        label: 'Sem Apple Watch pareado — BPM cai pra leitura espaçada',
        color: palette.muted,
        icon: Icons.watch_off_outlined,
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: palette.surface,
        border: Border.all(color: info.color.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          Icon(info.icon, size: 16, color: info.color),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              info.label,
              style: type.bodyXs.copyWith(color: info.color),
            ),
          ),
        ],
      ),
    );
  }
}
