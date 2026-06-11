import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:latlong2/latlong.dart';
import 'package:runnin/core/network/api_client.dart';
import 'package:runnin/core/theme/app_palette.dart';
import 'package:runnin/core/theme/design_system_tokens.dart';
import 'package:runnin/features/auth/data/user_remote_datasource.dart';
import 'package:runnin/features/biometrics/data/biometric_remote_datasource.dart';
import 'package:runnin/features/biometrics/data/health_sync_service.dart';
import 'package:runnin/features/biometrics/domain/run_zones.dart';
import 'package:runnin/features/run/data/datasources/run_remote_datasource.dart';
import 'package:runnin/features/run/domain/entities/run.dart';
import 'package:runnin/shared/widgets/figma/figma_split_row.dart';
import 'package:runnin/shared/widgets/figma/figma_zone_card.dart';
import 'package:runnin/shared/widgets/figma/figma_zone_distribution_bar.dart';
import 'package:runnin/shared/widgets/metric_card.dart';

class RunDetailPage extends StatefulWidget {
  final String runId;
  const RunDetailPage({super.key, required this.runId});

  @override
  State<RunDetailPage> createState() => _RunDetailPageState();
}

class _RunDetailPageState extends State<RunDetailPage> {
  final _remote = RunRemoteDatasource();
  final _userRemote = UserRemoteDatasource();
  final _biometricRemote = BiometricRemoteDatasource();
  Run? _run;
  List<GpsPoint> _gpsPoints = const [];
  String? _summary;
  RunZoneDistribution? _zones;
  /// Passos no intervalo da corrida lidos do Apple Health/Health Connect.
  /// null = ainda carregando ou plataforma sem health; 0 = sem dados; >0 = ok.
  int? _stepsInRun;
  bool _loadingRun = true;
  bool _loadingReport = true;

  @override
  void initState() {
    super.initState();
    _loadRun();
    _loadReport();
  }

  Future<void> _loadRun() async {
    try {
      final run = await _remote.getRun(widget.runId);
      // Pontos GPS salvos da corrida → mesmo mapa da tela de compartilhar.
      final points =
          await _remote.getGpsPoints(widget.runId).catchError((_) => <GpsPoint>[]);
      // Zonas cardíacas: precisamos do profile (resting/maxBpm declarados) e do
      // summary (fallback observado de 30d). Best-effort — sem profile, cai
      // pro fallback 220-idade; sem nada, banner "sem dados" na seção.
      UserProfile? profile;
      BiometricSummary? summary;
      try {
        final results = await Future.wait([
          _userRemote.getMe(),
          _biometricRemote.getSummary(windowDays: 30),
        ]);
        profile = results[0] as UserProfile?;
        summary = results[1] as BiometricSummary?;
      } catch (_) {/* segue sem zonas */}
      final zones = computeRunZoneDistribution(
        run: run,
        profile: profile,
        summary: summary,
      );
      // Passos da sessão via Apple Health/Health Connect — best-effort.
      // Janela: createdAt → createdAt + durationS. Sem campo na Run entity;
      // o que temos é a agregação direta do HK no intervalo da corrida.
      int? steps;
      try {
        final start = DateTime.tryParse(run.createdAt);
        if (start != null && run.durationS > 0) {
          final end = start.add(Duration(seconds: run.durationS));
          steps = await healthSyncService.stepsBetween(start, end);
        }
      } catch (_) {/* segue sem passos */}
      if (mounted) {
        setState(() {
          _run = run;
          _gpsPoints = points;
          _zones = zones;
          _stepsInRun = steps;
          _loadingRun = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loadingRun = false);
    }
  }

  Future<void> _loadReport() async {
    try {
      final res = await apiClient.get('/coach/report/${widget.runId}');
      final data = res.data as Map<String, dynamic>;
      if (data['status'] == 'ready') {
        if (mounted) setState(() { _summary = data['summary'] as String?; _loadingReport = false; });
      } else {
        if (mounted) setState(() => _loadingReport = false);
      }
    } catch (_) {
      if (mounted) setState(() => _loadingReport = false);
    }
  }

  String _fmtDate(String iso) {
    try {
      return DateFormat("dd 'de' MMMM, yyyy", 'pt_BR').format(DateTime.parse(iso).toLocal());
    } catch (_) {
      return iso.substring(0, 10);
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.runninPalette;
    final type = context.runninType;

    return Scaffold(
      backgroundColor: palette.background,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => context.pop(),
                    child: Container(
                      width: FigmaDimensions.backButton,
                      height: FigmaDimensions.backButton,
                      decoration: BoxDecoration(
                        border: Border.all(color: FigmaColors.borderBackBtn, width: FigmaDimensions.borderUniversal),
                      ),
                      child: Icon(Icons.arrow_back, size: 18, color: palette.text),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text('DETALHE DA CORRIDA', style: type.labelCaps),
                ],
              ),
            ),
            const SizedBox(height: 20),

            Expanded(
              child: _loadingRun
                  ? Center(child: CircularProgressIndicator(color: palette.primary, strokeWidth: 2))
                  : _run == null
                      ? Center(child: Text('Corrida não encontrada.', style: type.bodySm.copyWith(color: palette.muted)))
                      : SingleChildScrollView(
                          padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Date & type
                              Text(
                                _fmtDate(_run!.createdAt).toUpperCase(),
                                style: type.bodyXs.copyWith(
                                  letterSpacing: 1.1,
                                  color: FigmaColors.textMuted,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.xs),
                                color: palette.primary.withValues(alpha: 0.15),
                                child: Text(
                                  _run!.type.toUpperCase(),
                                  style: type.labelCaps.copyWith(color: palette.primary),
                                ),
                              ),
                              const SizedBox(height: 20),

                              // 1 ── MAPA: trajeto salvo da corrida (mesmo mapa
                              //      do compartilhar, em altura contida).
                              //      Indoor: sem rota — banner de esteira no
                              //      lugar do mapa vazio.
                              if (_run!.environment == 'indoor')
                                Container(
                                  width: double.infinity,
                                  height: 120,
                                  decoration: BoxDecoration(
                                    color: palette.surface,
                                    border: Border.all(color: palette.border),
                                  ),
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        Icons.fitness_center_outlined,
                                        size: 32,
                                        color: palette.primary,
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        'CORRIDA INDOOR · ESTEIRA',
                                        style: type.labelCaps.copyWith(
                                          color: palette.muted,
                                          letterSpacing: 1.5,
                                        ),
                                      ),
                                    ],
                                  ),
                                )
                              else
                                _RunRouteMap(points: _gpsPoints),
                              const SizedBox(height: 24),

                              // 2 ── DADOS DA CORRIDA: grid 2×2 de MetricCard
                              //      (mesmo padrão da periodização).
                              _SectionLabel('DADOS DA CORRIDA'),
                              const SizedBox(height: 12),
                              _RunDataGrid(run: _run!, stepsInRun: _stepsInRun),
                              const SizedBox(height: 24),

                              // 3 ── ZONAS CARDÍACAS: distribuição de tempo por
                              //      zona usando avgBpm de cada split + Karvonen
                              //      a partir do profile (ou fallback 220-idade).
                              if (_zones != null) ...[
                                _RunZonesSection(distribution: _zones!),
                                const SizedBox(height: 24),
                              ],

                              // 4 ── SPLITS
                              _SectionLabel('SPLITS'),
                              const SizedBox(height: 12),
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: FigmaColors.surfaceCard,
                                  border: Border.all(color: palette.border),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    if (_run!.splits.isEmpty)
                                      Text(
                                        'Sem splits por km registrados nesta corrida.',
                                        style: type.bodySm.copyWith(color: FigmaColors.textMuted),
                                      )
                                    else
                                      ..._buildSplitRows(_run!.splits),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 24),

                              // 4 ── ANÁLISE DO COACH
                              _SectionLabel('ANÁLISE DO COACH'),
                              const SizedBox(height: 12),
                              Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  border: Border(left: BorderSide(color: palette.secondary, width: 3)),
                                  color: palette.secondary.withValues(alpha: 0.05),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'COACH.AI',
                                      style: type.labelCaps.copyWith(color: palette.secondary),
                                    ),
                                    const SizedBox(height: 8),
                                    _loadingReport
                                        ? Row(children: [
                                            SizedBox(
                                              width: 12, height: 12,
                                              child: CircularProgressIndicator(strokeWidth: 1.5, color: palette.muted),
                                            ),
                                            const SizedBox(width: 10),
                                            Text('Carregando análise...', style: type.bodySm),
                                          ])
                                        : Text(
                                            _summary ?? 'Relatório não disponível para esta corrida.',
                                            style: type.bodyMd.copyWith(height: 1.6),
                                          ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 32),

                              // CTAs — ambos no padrão do design system
                              // (quadrado, cores da skin via palette).
                              SizedBox(
                                width: double.infinity,
                                child: OutlinedButton.icon(
                                  onPressed: () => context.push('/share', extra: {'runId': widget.runId}),
                                  icon: Icon(Icons.share_outlined, size: 16, color: palette.primary),
                                  label: Text('COMPARTILHAR', style: type.labelCaps.copyWith(color: palette.primary)),
                                  style: OutlinedButton.styleFrom(
                                    side: BorderSide(color: palette.primary.withValues(alpha: 0.4)),
                                    padding: const EdgeInsets.symmetric(vertical: 14),
                                    shape: const RoundedRectangleBorder(),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 10),
                              SizedBox(
                                width: double.infinity,
                                child: ElevatedButton.icon(
                                  onPressed: () => context.push('/history/run/${widget.runId}/conversa'),
                                  icon: Icon(Icons.chat_bubble_outline, size: 16, color: palette.background),
                                  label: Text(
                                    'VER CONVERSA COM COACH',
                                    style: type.labelCaps.copyWith(color: palette.background),
                                  ),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: palette.secondary,
                                    foregroundColor: palette.background,
                                    elevation: 0,
                                    padding: const EdgeInsets.symmetric(vertical: 14),
                                    shape: const RoundedRectangleBorder(),
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
    );
  }

  /// Monta uma lista de FigmaSplitRow. Best split (menor pace numérico) fica
  /// destacado em cyan via isBest; demais em dim. barRatio = pace/maxPace
  /// (split mais lento ocupa toda a largura, mais rápido proporcionalmente
  /// menos — leitura visual de "mais curto = mais rápido").
  ///
  /// Splits parciais (isPartial=true, tail < 1km da run, ex: 2.18km → 0.18km
  /// no fim) renderizam:
  ///  - kmLabel: "+0.18" (distância real do trecho, prefixo + sinaliza tail)
  ///  - time: duração real do trecho (não pace normalizado, que era confuso
  ///    pra 180m — "~05:00" sugeria pace de 5min/km mas o user só andou 50s)
  ///  - ficam fora do best/maxPace pra comparação não ficar injusta.
  List<Widget> _buildSplitRows(List<KmSplit> splits) {
    final sorted = [...splits]..sort((a, b) => a.kmIndex.compareTo(b.kmIndex));
    final paceMins = sorted.map(_paceToMin).toList();
    // Best/maxPace só considera splits completos — partial fica fora.
    final validPaces = <double>[];
    for (var i = 0; i < sorted.length; i++) {
      final p = paceMins[i];
      if (p != null && !sorted[i].isPartial) validPaces.add(p);
    }

    String labelOf(KmSplit s) {
      if (!s.isPartial) return 'KM${s.kmIndex + 1}';
      final km = (s.distanceM ?? 0) / 1000;
      return '+${km.toStringAsFixed(2)}';
    }

    String timeOf(KmSplit s) {
      // Partial: duração real (não pace normalizado), porque pace/km extrapolado
      // de 180m em 50s = 4:38/km não ajuda a entender que foram só 50s.
      if (s.isPartial) return _formatDuration(s.durationS);
      return s.avgPaceMinKm ?? _formatDuration(s.durationS);
    }

    if (validPaces.isEmpty) {
      return sorted
          .map((s) => Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: FigmaSplitRow(
                  kmLabel: labelOf(s),
                  time: timeOf(s),
                  barRatio: 0,
                  isBest: false,
                  bpm: s.avgBpm,
                  calories: s.calories,
                ),
              ))
          .toList();
    }
    final maxPace = validPaces.reduce((a, b) => a > b ? a : b);
    final minPace = validPaces.reduce((a, b) => a < b ? a : b);

    return List.generate(sorted.length, (i) {
      final s = sorted[i];
      final p = paceMins[i];
      final ratio = (p != null && maxPace > 0 && !s.isPartial) ? p / maxPace : 0.0;
      // best só entre completos: partial nunca ganha estrela.
      final isBest = !s.isPartial && p != null && p == minPace;
      return Padding(
        padding: EdgeInsets.only(bottom: i == sorted.length - 1 ? 0 : 6),
        child: FigmaSplitRow(
          kmLabel: labelOf(s),
          time: timeOf(s),
          barRatio: ratio,
          isBest: isBest,
          bpm: s.avgBpm,
          calories: s.calories,
          elevationGainM: s.elevationGain,
        ),
      );
    });
  }

  double? _paceToMin(KmSplit s) {
    final p = s.avgPaceMinKm;
    if (p == null) return null;
    final parts = p.split(':');
    if (parts.length != 2) return null;
    final min = int.tryParse(parts[0]);
    final sec = int.tryParse(parts[1]);
    if (min == null || sec == null) return null;
    return min + sec / 60.0;
  }

  String _formatDuration(int s) {
    final m = (s ~/ 60).toString();
    final r = (s % 60).toString().padLeft(2, '0');
    return '$m:$r';
  }
}

/// Seção ZONAS CARDÍACAS — barra de distribuição (5 zonas) em cima + cards
/// Z1-Z5 (mesmo widget de perfil/saúde/zonas) com nome+range+% de tempo.
/// FC máx da corrida fica como sufixo do header. Sem dados de BPM válidos
/// nos splits, mostra banner explicativo em vez do gráfico.
class _RunZonesSection extends StatelessWidget {
  final RunZoneDistribution distribution;
  const _RunZonesSection({required this.distribution});

  @override
  Widget build(BuildContext context) {
    final palette = context.runninPalette;
    final type = context.runninType;
    final hasData = distribution.hasEnoughBpmData && distribution.zones.isNotEmpty;
    final maxBpm = distribution.maxBpmRun;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _SectionLabel('ZONAS CARDÍACAS'),
            if (maxBpm != null && maxBpm > 0)
              Text(
                'FC máx ${maxBpm}bpm',
                style: type.bodyXs.copyWith(
                  color: FigmaColors.textMuted,
                  letterSpacing: 0.6,
                ),
              ),
          ],
        ),
        const SizedBox(height: 12),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: FigmaColors.surfaceCard,
            border: Border.all(color: palette.border),
          ),
          child: hasData
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    FigmaZoneDistributionBar(
                      zonePercentages: distribution.zones.map((z) => z.pctTime).toList(),
                    ),
                    const SizedBox(height: 16),
                    for (var i = 0; i < distribution.zones.length; i++) ...[
                      FigmaZoneCard(
                        zoneNumber: distribution.zones[i].number,
                        zoneLabel: distribution.zones[i].label,
                        bpmRange:
                            '${distribution.zones[i].minBpm}-${distribution.zones[i].maxBpm} bpm',
                        percent: distribution.zones[i].pctTime,
                        zoneColor: distribution.zones[i].color,
                      ),
                      if (i < distribution.zones.length - 1)
                        const SizedBox(height: 8),
                    ],
                  ],
                )
              : Text(
                  'Sem BPM coletado nessa corrida pra distribuir por zona — '
                  'corra com um sensor de FC conectado pra ativar.',
                  style: type.bodySm.copyWith(color: FigmaColors.textMuted),
                ),
        ),
      ],
    );
  }
}

/// Título de seção (DADOS DA CORRIDA / SPLITS / ANÁLISE DO COACH) na mesma
/// escala dos headers de painel do app (displaySm 14).
class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: context.runninType.displaySm.copyWith(
        color: context.runninPalette.text,
        fontSize: 14,
      ),
    );
  }
}

/// Mapa do trajeto da corrida — mesma renderização do compartilhar (tiles
/// OSM + rota em cyan), em altura contida. Usa os pontos GPS salvos da
/// corrida; sem GPS suficiente, mostra um placeholder neutro.
class _RunRouteMap extends StatelessWidget {
  final List<GpsPoint> points;
  const _RunRouteMap({required this.points});

  @override
  Widget build(BuildContext context) {
    final palette = context.runninPalette;
    final latLng =
        points.map((p) => LatLng(p.lat, p.lng)).toList(growable: false);
    final hasRoute = latLng.length >= 2;

    if (!hasRoute) {
      return Container(
        height: 180,
        width: double.infinity,
        decoration: BoxDecoration(
          color: palette.surface,
          border: Border.all(color: palette.border),
        ),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.map_outlined, size: 28, color: palette.muted),
              const SizedBox(height: 8),
              Text(
                'Sem trajeto GPS nesta corrida',
                style: context.runninType.bodySm.copyWith(color: palette.muted),
              ),
            ],
          ),
        ),
      );
    }

    final bounds = LatLngBounds.fromPoints(latLng);
    return Container(
      height: 260,
      decoration: BoxDecoration(border: Border.all(color: palette.border)),
      clipBehavior: Clip.hardEdge,
      child: FlutterMap(
        options: MapOptions(
          initialCenter: bounds.center,
          initialZoom: 14,
          initialCameraFit: CameraFit.bounds(
            bounds: bounds,
            padding: const EdgeInsets.all(36),
          ),
          interactionOptions:
              const InteractionOptions(flags: InteractiveFlag.none),
        ),
        children: [
          TileLayer(
            urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
            userAgentPackageName: 'com.runnin.app',
          ),
          PolylineLayer(
            polylines: [
              Polyline(
                points: latLng,
                color: palette.primary,
                strokeWidth: 4,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Dados da corrida em grid de 2 por linha (MetricCard), mesmo padrão da
/// periodização. Métricas biométricas só aparecem quando há dado.
class _RunDataGrid extends StatelessWidget {
  /// Passos no intervalo da corrida, fetched do Apple Health/Health Connect.
  /// null = HK indisponível / sem permissão; 0 = sem dados; >0 = ok.
  final int? stepsInRun;
  final Run run;
  const _RunDataGrid({required this.run, required this.stepsInRun});

  static String _fmtDur(int s) {
    final h = s ~/ 3600;
    final m = (s % 3600) ~/ 60;
    final sec = s % 60;
    return h > 0
        ? '$h:${m.toString().padLeft(2, '0')}:${sec.toString().padLeft(2, '0')}'
        : '${m.toString().padLeft(2, '0')}:${sec.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final entries = <(String, String, String?)>[
      ('DISTÂNCIA', (run.distanceM / 1000).toStringAsFixed(2), 'km'),
      ('TEMPO', _fmtDur(run.durationS), null),
      ('PACE MÉD', run.avgPace ?? '--:--', '/km'),
    ];
    if (run.avgBpm != null && run.avgBpm! > 0) {
      entries.add(('BPM MÉD', '${run.avgBpm}', 'bpm'));
    }
    if (run.maxBpm != null && run.maxBpm! > 0) {
      entries.add(('BPM MÁX', '${run.maxBpm}', 'bpm'));
    }
    if (run.calories != null && run.calories! > 0) {
      entries.add(('CALORIAS', '${run.calories}', 'kcal'));
    }
    // PASSOS: agregado direto do Apple Health/Health Connect filtrando pela
    // janela da corrida (createdAt → +durationS). Não é campo da Run entity —
    // pulled on-the-fly em [_RunDetailPageState._loadRun]. Quando stepsInRun é
    // null (sem permissão ou plataforma sem HK) o card é omitido.
    if (stepsInRun != null && stepsInRun! > 0) {
      entries.add(('PASSOS', '$stepsInRun', null));
    }
    // Ganho de elevação capturado via GPS/altímetro durante a corrida.
    if (run.elevationGain != null && run.elevationGain! > 0) {
      entries.add(('ELEVAÇÃO', '+${run.elevationGain!.round()}', 'm'));
    }
    if (run.xpEarned != null && run.xpEarned! > 0) {
      entries.add(('XP', '+${run.xpEarned}', null));
    }

    Widget cardFor((String, String, String?) e) =>
        MetricCard(label: e.$1, value: e.$2, unit: e.$3);

    final rows = <Widget>[];
    for (var i = 0; i < entries.length; i += 2) {
      final hasSecond = i + 1 < entries.length;
      // IntrinsicHeight dá altura FINITA pro stretch (sem ele, num
      // SingleChildScrollView o cross-axis é infinito e o layout estoura,
      // sumindo com tudo abaixo do mapa).
      rows.add(IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(child: cardFor(entries[i])),
            const SizedBox(width: 8),
            Expanded(
              child: hasSecond ? cardFor(entries[i + 1]) : const SizedBox(),
            ),
          ],
        ),
      ));
      if (i + 2 < entries.length) rows.add(const SizedBox(height: 8));
    }
    return Column(children: rows);
  }
}
