import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:share_plus/share_plus.dart';

import 'package:runnin/core/theme/app_palette.dart';
import 'package:runnin/core/theme/design_system_tokens.dart';
import 'package:runnin/features/run/data/datasources/run_remote_datasource.dart';
import 'package:runnin/features/run/domain/entities/run.dart';
import 'package:runnin/shared/widgets/figma/figma_chart_line_spark.dart';
import 'package:runnin/features/run/presentation/widgets/share_map_card.dart';

// Só toggles que de fato desenham algo sobre a foto (revisado): chips de
// pace/distância/tempo/bpm + traçado da rota + sparkline de splits. Removidos
// Streak/Plano (sem dado nesta tela) e Coach.
const _overlayToggleLabels = [
  'Pace',       // 0 → chip
  'Distância',  // 1 → chip
  'Tempo',      // 2 → chip
  'BPM',        // 3 → chip (se houver)
  'Trajeto',    // 4 → traçado da rota (igual ao mapa)
  'Splits',     // 5 → sparkline de pace por km
];

const _defaultToggles = {0, 1, 2, 4}; // Pace, Distância, Tempo, Trajeto

class SharePage extends StatefulWidget {
  final String runId;
  const SharePage({super.key, required this.runId});

  @override
  State<SharePage> createState() => _SharePageState();
}

class _SharePageState extends State<SharePage> with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  final _overlayBoundaryKey = GlobalKey();
  final _mapBoundaryKey = GlobalKey();

  final _remote = RunRemoteDatasource();
  Run? _run;
  List<GpsPoint> _gpsPoints = const [];
  bool _loading = true;

  final Set<int> _activeToggles = Set.from(_defaultToggles);
  Uint8List? _photoBytes;

  @override
  void initState() {
    super.initState();
    // Apenas 2 opções: MAPA e FOTO.
    _tabController = TabController(length: 2, vsync: this);
    _loadRun();
  }

  Future<void> _loadRun() async {
    try {
      final run = await _remote.getRun(widget.runId);
      final points = await _remote.getGpsPoints(widget.runId).catchError((_) => <GpsPoint>[]);
      if (mounted) {
        setState(() {
        _run = run;
        _gpsPoints = points;
        _loading = false;
      });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<Uint8List?> _renderPng(GlobalKey key) async {
    final ctx = key.currentContext;
    if (ctx == null) return null;
    final boundary = ctx.findRenderObject() as RenderRepaintBoundary;
    final image = await boundary.toImage(pixelRatio: 3.0);
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    return byteData?.buffer.asUint8List();
  }

  Future<void> _shareImage(GlobalKey key) async {
    final png = await _renderPng(key);
    if (png == null) return;
    await Share.shareXFiles(
      [XFile.fromData(png, mimeType: 'image/png', name: 'runnin_share.png')],
    );
  }

  Future<void> _saveImage(GlobalKey key) async {
    final png = await _renderPng(key);
    if (png == null) return;
    if (kIsWeb) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Salvar imagem disponível apenas no app mobile')),
        );
      }
      return;
    }
    await Share.shareXFiles(
      [XFile.fromData(png, mimeType: 'image/png', name: 'runnin_share.png')],
    );
  }

  Future<void> _pickPhoto() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: kIsWeb ? ImageSource.gallery : ImageSource.camera,
    );
    if (picked != null) {
      final bytes = await picked.readAsBytes();
      if (mounted) {
        setState(() => _photoBytes = bytes);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: FigmaColors.bgBase,
      appBar: AppBar(
        backgroundColor: FigmaColors.bgBase,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: FigmaColors.textPrimary),
          onPressed: () => context.pop(),
        ),
        title: Text(
          'COMPARTILHAR',
          style: context.runninType.labelCaps.copyWith(
            fontSize: 13,
            letterSpacing: 1.1,
            color: FigmaColors.textPrimary,
          ),
        ),
        centerTitle: true,
      ),
      body: _loading
          ? Center(child: CircularProgressIndicator(color: context.runninPalette.primary, strokeWidth: 2))
          : _run == null
              ? Center(
                  child: Text(
                    'Corrida não encontrada',
                    style: context.runninType.bodyMd.copyWith(color: FigmaColors.textMuted),
                  ),
                )
              : Column(
                  children: [
                    _buildTabBar(),
                    Expanded(
                      child: TabBarView(
                        controller: _tabController,
                        children: [
                          _buildMapTab(),
                          _buildOverlayTab(),
                        ],
                      ),
                    ),
                  ],
                ),
    );
  }

  Widget _buildTabBar() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      decoration: BoxDecoration(
        border: Border.all(color: FigmaColors.borderDefault, width: 1.041),
      ),
      child: TabBar(
        controller: _tabController,
        indicatorSize: TabBarIndicatorSize.tab,
        indicator: BoxDecoration(color: context.runninPalette.primary),
        labelColor: FigmaColors.bgBase,
        unselectedLabelColor: FigmaColors.textSecondary,
        labelStyle: context.runninType.labelCaps.copyWith(
          fontSize: 11,
          letterSpacing: 1.1,
        ),
        unselectedLabelStyle: context.runninType.labelCaps.copyWith(
          fontSize: 11,
          letterSpacing: 1.1,
        ),
        dividerHeight: 0,
        tabs: const [
          Tab(height: 44, text: 'MAPA'),
          Tab(height: 44, text: 'FOTO'),
        ],
      ),
    );
  }

  // ─── TAB: MAPA ────────────────────────────────────────────────────────────────

  Widget _buildMapTab() {
    final hasRoute = _gpsPoints.length >= 2;
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 12),
          RepaintBoundary(
            key: _mapBoundaryKey,
            child: ShareMapCard(run: _run!, points: _gpsPoints),
          ),
          if (!hasRoute) ...[
            const SizedBox(height: 12),
            Text(
              'Sem GPS suficiente nessa corrida — card mostra fundo neutro.',
              style: context.runninType.bodyXs.copyWith(
                color: FigmaColors.textMuted,
              ),
            ),
          ],
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _ShareTarget(
                label: 'COMPARTILHAR',
                icon: Icons.ios_share,
                onTap: () => _shareImage(_mapBoundaryKey),
              ),
              _ShareTarget(
                label: 'SALVAR',
                icon: Icons.download,
                onTap: () => _saveImage(_mapBoundaryKey),
              ),
            ],
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  // ─── TAB 2: CÂMERA + OVERLAY ─────────────────────────────────────────────────

  Widget _buildOverlayTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 12),

          // Photo preview with overlay
          RepaintBoundary(
            key: _overlayBoundaryKey,
            child: _buildOverlayPreview(),
          ),
          const SizedBox(height: 16),

          // Take another photo button
          GestureDetector(
            onTap: _pickPhoto,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _photoBytes == null ? 'TIRAR FOTO' : 'TIRAR OUTRA FOTO',
                  style: context.runninType.labelCaps.copyWith(
                    fontSize: 11,
                    letterSpacing: 1.1,
                    color: context.runninPalette.primary,
                  ),
                ),
                const SizedBox(width: 4),
                Icon(Icons.north_east, size: 14, color: context.runninPalette.primary),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Toggle section header
          Text(
            'DADOS NO OVERLAY',
            style: context.runninType.labelCaps.copyWith(
              fontSize: 11,
              letterSpacing: 1.1,
              color: FigmaColors.textSecondary,
            ),
          ),
          const SizedBox(height: 12),

          // Toggle chips
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: List.generate(_overlayToggleLabels.length, (i) {
              final active = _activeToggles.contains(i);
              return GestureDetector(
                onTap: () => setState(() {
                  if (active) {
                    _activeToggles.remove(i);
                  } else {
                    _activeToggles.add(i);
                  }
                }),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: active ? context.runninPalette.primary : Colors.transparent,
                    border: Border.all(
                      color: active ? context.runninPalette.primary : FigmaColors.borderDefault,
                      width: 1.041,
                    ),
                  ),
                  child: Text(
                    _overlayToggleLabels[i],
                    style: context.runninType.labelMd.copyWith(
                      fontSize: 10,
                      letterSpacing: 0.8,
                      color: active ? FigmaColors.bgBase : FigmaColors.textSecondary,
                    ),
                  ),
                ),
              );
            }),
          ),
          const SizedBox(height: 24),

          // Share targets
          _ShareTarget(
            icon: Icons.camera_alt_outlined,
            label: 'Instagram Stories',
            onTap: () => _shareImage(_overlayBoundaryKey),
          ),
          _ShareTarget(
            icon: Icons.chat_bubble_outline,
            label: 'WhatsApp',
            onTap: () => _shareImage(_overlayBoundaryKey),
          ),
          _ShareTarget(
            icon: Icons.alternate_email,
            label: 'Twitter / X',
            onTap: () => _shareImage(_overlayBoundaryKey),
          ),
          _ShareTarget(
            icon: Icons.save_alt,
            label: 'Salvar imagem',
            onTap: () => _saveImage(_overlayBoundaryKey),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildOverlayPreview() {
    final distKm = ((_run?.distanceM ?? 0) / 1000).toStringAsFixed(1);
    final pace = _run?.avgPace ?? '--:--';
    final duration = _fmtDuration(_run?.durationS ?? 0);

    return AspectRatio(
      aspectRatio: 4 / 5,
      child: Container(
        clipBehavior: Clip.hardEdge,
        decoration: BoxDecoration(
          color: const Color(0xFF1A1A2E),
          border: Border.all(color: FigmaColors.borderDefault, width: 1),
        ),
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Photo base or placeholder (placeholder é tappável → abre o
            // seletor de foto, como diz o texto).
            if (_photoBytes != null)
              Image.memory(_photoBytes!, fit: BoxFit.cover)
            else
              GestureDetector(
                onTap: _pickPhoto,
                behavior: HitTestBehavior.opaque,
                child: Container(
                  color: const Color(0xFF1A1A2E),
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.camera_alt, size: 48, color: FigmaColors.textMuted),
                        const SizedBox(height: 12),
                        Text(
                          'TOQUE PARA ADICIONAR FOTO',
                          style: context.runninType.labelCaps.copyWith(
                            color: FigmaColors.textMuted,
                            letterSpacing: 1,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

            // Branding top-left
            Positioned(
              top: 16,
              left: 16,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.xs),
                color: Colors.black.withValues(alpha: 0.5),
                child: Text(
                  'RUNNIN.AI',
                  style: context.runninType.labelCaps.copyWith(
                    fontSize: 9,
                    letterSpacing: 2,
                    color: context.runninPalette.primary,
                  ),
                ),
              ),
            ),

            // Top-right: traçado da rota (Trajeto) + sparkline (Splits).
            Positioned(
              top: 16,
              right: 16,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Trajeto: MESMO traçado da aba MAPA (polyline dos pontos GPS).
                  if (_activeToggles.contains(4) && _gpsPoints.length >= 2)
                    Container(
                      width: 84,
                      height: 84,
                      padding: const EdgeInsets.all(8),
                      color: Colors.black.withValues(alpha: 0.4),
                      child: CustomPaint(
                        painter: _RouteTracePainter(
                          points: _gpsPoints,
                          color: context.runninPalette.primary,
                        ),
                      ),
                    ),
                  // Splits: sparkline de pace por km.
                  if (_activeToggles.contains(5) && _run != null) ...[
                    const SizedBox(height: 8),
                    Container(
                      width: 140,
                      padding: const EdgeInsets.all(8),
                      color: Colors.black.withValues(alpha: 0.4),
                      child: FigmaChartLineSpark(
                        values: _generateSplits(),
                        height: 36,
                        lineColor: context.runninPalette.primary,
                      ),
                    ),
                  ],
                ],
              ),
            ),

            // Stat chips bottom-right
            Positioned(
              bottom: 16,
              right: 16,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_activeToggles.contains(0)) // Pace
                    _OverlayChip(label: '$pace/km'),
                  if (_activeToggles.contains(1)) // Distância
                    _OverlayChip(label: '${distKm}km'),
                  if (_activeToggles.contains(2)) // Tempo
                    _OverlayChip(label: duration),
                  if (_activeToggles.contains(3) && _run?.avgBpm != null) // BPM
                    _OverlayChip(label: '${_run!.avgBpm} BPM'),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<double> _generateSplits() {
    // Splits reais a partir do GPS. Fallback determinístico quando
    // pontos insuficientes (run legacy / GPS pobre).
    final real = computeKmSplitsSeconds(_gpsPoints);
    if (real.length >= 2) return real;
    final km = (_run?.distanceM ?? 0) / 1000;
    if (km < 2) return const [1, 1];
    final splits = km.floor().clamp(2, 10);
    final basePace = (_run?.durationS ?? 0) / km;
    return List.generate(splits, (i) {
      final variation = (i.isEven ? 1.02 : 0.98) + (i * 0.005);
      return basePace * variation;
    });
  }

  static String _fmtDuration(int seconds) {
    final h = seconds ~/ 3600;
    final m = (seconds % 3600) ~/ 60;
    final s = seconds % 60;
    if (h > 0) {
      return '$h:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
    }
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }
}

/// Desenha o traçado da rota (polyline dos pontos GPS) normalizado pra caber
/// no box, preservando o formato — mesma silhueta que aparece no mapa.
/// Aplica correção de longitude por cos(lat) (Web Mercator local) pra o
/// formato bater com o da aba MAPA.
class _RouteTracePainter extends CustomPainter {
  final List<GpsPoint> points;
  final Color color;
  const _RouteTracePainter({required this.points, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    if (points.length < 2) return;
    final lats = points.map((p) => p.lat).toList();
    final lngs = points.map((p) => p.lng).toList();
    final minLat = lats.reduce(math.min);
    final maxLat = lats.reduce(math.max);
    final minLng = lngs.reduce(math.min);
    final maxLng = lngs.reduce(math.max);
    final meanLatRad = ((minLat + maxLat) / 2) * math.pi / 180;
    final kx = math.cos(meanLatRad); // correção de longitude

    final spanX = (maxLng - minLng) * kx;
    final spanY = (maxLat - minLat);
    final span = math.max(spanX, spanY);
    if (span <= 0) return;

    const pad = 2.0;
    final w = size.width - pad * 2;
    final h = size.height - pad * 2;
    final scale = math.min(w, h) / span; // uniforme → preserva formato
    final drawnW = spanX * scale;
    final drawnH = spanY * scale;
    final offX = pad + (w - drawnW) / 2;
    final offY = pad + (h - drawnH) / 2;

    final path = Path();
    for (var i = 0; i < points.length; i++) {
      final x = offX + ((points[i].lng - minLng) * kx) * scale;
      // y invertido: latitude maior (norte) fica em cima.
      final y = offY + (maxLat - points[i].lat) * scale;
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }

    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..color = color
        ..strokeWidth = 2.5
        ..strokeJoin = StrokeJoin.round
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(_RouteTracePainter old) =>
      old.points != points || old.color != color;
}

// ─── Shared widgets ─────────────────────────────────────────────────────────────

class _ShareTarget extends StatelessWidget {
  const _ShareTarget({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
        margin: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(
          border: Border.all(color: FigmaColors.borderDefault, width: 1.041),
        ),
        child: Row(
          children: [
            Icon(icon, size: 20, color: FigmaColors.textSecondary),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: context.runninType.labelMd.copyWith(
                  fontWeight: FontWeight.w500,
                  letterSpacing: 0,
                  color: FigmaColors.textPrimary,
                ),
              ),
            ),
            const Icon(Icons.arrow_forward_ios, size: 14, color: FigmaColors.textMuted),
          ],
        ),
      ),
    );
  }
}

class _OverlayChip extends StatelessWidget {
  const _OverlayChip({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 4),
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.xs),
      color: Colors.black.withValues(alpha: 0.6),
      child: Text(
        label,
        style: context.runninType.labelCaps.copyWith(
          color: context.runninPalette.primary,
        ),
      ),
    );
  }
}
