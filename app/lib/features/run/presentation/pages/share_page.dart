import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:share_plus/share_plus.dart';

import 'package:runnin/core/theme/design_system_tokens.dart';
import 'package:runnin/features/run/data/datasources/run_remote_datasource.dart';
import 'package:runnin/features/run/domain/entities/run.dart';
import 'package:runnin/shared/widgets/figma/figma_chart_line_spark.dart';
import 'package:runnin/shared/widgets/figma/figma_share_card_preview.dart';

const _overlayToggleLabels = [
  'Pace',
  'Distância',
  'Tempo',
  'BPM',
  'Streak',
  'Plano',
  'Trajeto',
  'Splits',
  'Coach',
];

const _defaultToggles = {0, 1, 2, 4, 5, 6}; // Pace, Distância, Tempo, Streak, Plano, Trajeto

class SharePage extends StatefulWidget {
  final String runId;
  const SharePage({super.key, required this.runId});

  @override
  State<SharePage> createState() => _SharePageState();
}

class _SharePageState extends State<SharePage> with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  final _cardBoundaryKey = GlobalKey();
  final _overlayBoundaryKey = GlobalKey();

  final _remote = RunRemoteDatasource();
  Run? _run;
  bool _loading = true;

  ShareTheme _selectedTheme = ShareTheme.dark;
  final Set<int> _activeToggles = Set.from(_defaultToggles);
  Uint8List? _photoBytes;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadRun();
  }

  Future<void> _loadRun() async {
    try {
      final run = await _remote.getRun(widget.runId);
      if (mounted) setState(() { _run = run; _loading = false; });
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
          style: GoogleFonts.jetBrainsMono(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.1,
            color: FigmaColors.textPrimary,
          ),
        ),
        centerTitle: true,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: FigmaColors.brandCyan, strokeWidth: 2))
          : _run == null
              ? Center(
                  child: Text(
                    'Corrida não encontrada',
                    style: GoogleFonts.jetBrainsMono(color: FigmaColors.textMuted),
                  ),
                )
              : Column(
                  children: [
                    _buildTabBar(),
                    Expanded(
                      child: TabBarView(
                        controller: _tabController,
                        children: [
                          _buildCardTab(),
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
        indicator: const BoxDecoration(color: FigmaColors.brandCyan),
        labelColor: FigmaColors.bgBase,
        unselectedLabelColor: FigmaColors.textSecondary,
        labelStyle: GoogleFonts.jetBrainsMono(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.1,
        ),
        unselectedLabelStyle: GoogleFonts.jetBrainsMono(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.1,
        ),
        dividerHeight: 0,
        tabs: const [
          Tab(height: 44, text: 'CARD'),
          Tab(height: 44, text: 'CÂMERA + OVERLAY'),
        ],
      ),
    );
  }

  // ─── TAB 1: CARD ──────────────────────────────────────────────────────────────

  Widget _buildCardTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 12),
          // Preview
          RepaintBoundary(
            key: _cardBoundaryKey,
            child: FigmaShareCardPreview(run: _run!, theme: _selectedTheme),
          ),
          const SizedBox(height: 20),

          // Theme switcher
          _buildThemeSwitcher(),
          const SizedBox(height: 24),

          // Share targets
          _ShareTarget(
            icon: Icons.camera_alt_outlined,
            label: 'Instagram Stories',
            onTap: () => _shareImage(_cardBoundaryKey),
          ),
          _ShareTarget(
            icon: Icons.chat_bubble_outline,
            label: 'WhatsApp',
            onTap: () => _shareImage(_cardBoundaryKey),
          ),
          _ShareTarget(
            icon: Icons.alternate_email,
            label: 'Twitter / X',
            onTap: () => _shareImage(_cardBoundaryKey),
          ),
          _ShareTarget(
            icon: Icons.save_alt,
            label: 'Salvar imagem',
            onTap: () => _saveImage(_cardBoundaryKey),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildThemeSwitcher() {
    return Row(
      children: ShareTheme.values.map((t) {
        final active = t == _selectedTheme;
        final label = switch (t) {
          ShareTheme.dark => 'DARK',
          ShareTheme.color => 'COLOR',
          ShareTheme.minimal => 'MINIMAL',
        };
        return Expanded(
          child: GestureDetector(
            onTap: () => setState(() => _selectedTheme = t),
            child: Container(
              height: 38,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: active ? FigmaColors.brandCyan : Colors.transparent,
                border: Border.all(
                  color: active ? FigmaColors.brandCyan : FigmaColors.borderDefault,
                  width: 1.041,
                ),
              ),
              child: Text(
                label,
                style: GoogleFonts.jetBrainsMono(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.1,
                  color: active ? FigmaColors.bgBase : FigmaColors.textSecondary,
                ),
              ),
            ),
          ),
        );
      }).toList(),
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
                  style: GoogleFonts.jetBrainsMono(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.1,
                    color: FigmaColors.brandCyan,
                  ),
                ),
                const SizedBox(width: 4),
                const Icon(Icons.north_east, size: 14, color: FigmaColors.brandCyan),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Toggle section header
          Text(
            'DADOS NO OVERLAY',
            style: GoogleFonts.jetBrainsMono(
              fontSize: 11,
              fontWeight: FontWeight.w700,
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
                    color: active ? FigmaColors.brandCyan : Colors.transparent,
                    border: Border.all(
                      color: active ? FigmaColors.brandCyan : FigmaColors.borderDefault,
                      width: 1.041,
                    ),
                  ),
                  child: Text(
                    _overlayToggleLabels[i],
                    style: GoogleFonts.jetBrainsMono(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
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
            // Photo base or placeholder
            if (_photoBytes != null)
              Image.memory(_photoBytes!, fit: BoxFit.cover)
            else
              Container(
                color: const Color(0xFF1A1A2E),
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.camera_alt, size: 48, color: FigmaColors.textMuted),
                      const SizedBox(height: 12),
                      Text(
                        'TOQUE PARA ADICIONAR FOTO',
                        style: GoogleFonts.jetBrainsMono(
                          fontSize: 10,
                          color: FigmaColors.textMuted,
                          letterSpacing: 1,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

            // Branding top-left
            Positioned(
              top: 16,
              left: 16,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                color: Colors.black.withValues(alpha: 0.5),
                child: Text(
                  'RUNNIN.AI',
                  style: GoogleFonts.jetBrainsMono(
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 2,
                    color: FigmaColors.brandCyan,
                  ),
                ),
              ),
            ),

            // Sparkline overlay
            if (_activeToggles.contains(0) || _activeToggles.contains(1)) // Pace or Distância
              Positioned(
                top: 16,
                right: 16,
                left: 80,
                child: Container(
                  padding: const EdgeInsets.all(8),
                  color: Colors.black.withValues(alpha: 0.4),
                  child: FigmaChartLineSpark(
                    values: _run != null ? _generateSplits() : [1, 1],
                    height: 40,
                    lineColor: FigmaColors.brandCyan,
                  ),
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

            // Tagline bottom-left
            Positioned(
              bottom: 16,
              left: 16,
              right: 100,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                color: Colors.black.withValues(alpha: 0.5),
                child: Text(
                  'Corrida ${_run?.type ?? ''} concluída',
                  style: GoogleFonts.jetBrainsMono(
                    fontSize: 10,
                    color: Colors.white.withValues(alpha: 0.9),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<double> _generateSplits() {
    final km = (_run?.distanceM ?? 0) / 1000;
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
                style: GoogleFonts.jetBrainsMono(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
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
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      color: Colors.black.withValues(alpha: 0.6),
      child: Text(
        label,
        style: GoogleFonts.jetBrainsMono(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: FigmaColors.brandCyan,
        ),
      ),
    );
  }
}
