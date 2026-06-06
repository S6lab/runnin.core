import 'dart:convert';
import 'dart:io' show Directory, File, Platform;
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:gal/gal.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import 'package:runnin/core/logger/logger.dart';
import 'package:runnin/core/theme/app_palette.dart';
import 'package:runnin/core/theme/design_system_tokens.dart';
import 'package:runnin/features/run/data/datasources/run_remote_datasource.dart';
import 'package:runnin/features/run/domain/entities/run.dart';
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

  /// Proporção da imagem de share. 9:16 = story (IG/Stories), 4:5 = feed
  /// (post quadrado-ish). Default story porque é o formato mais usado pelo
  /// público alvo. Aplicado em ambas as abas (mapa + foto) — o user escolhe
  /// uma vez e ambas usam.
  double _aspectRatio = 9 / 16;

  /// Offsets custom (em pixels relativos à RepaintBoundary) dos grupos
  /// arrastáveis na foto. Null = usar posição default do canto. Reset
  /// ao trocar de aspect ratio (pixels não escalam corretamente entre
  /// 9:16 e 4:5).
  ///
  /// Keys: 'stats' (chips pace/dist/tempo/bpm, top-left),
  /// 'splits' (lista de splits, top-right),
  /// 'route' (mini-mapa do traçado, bottom-left).
  /// Logo RUNNIN.AI fica fixo no bottom-right (branding).
  final Map<String, Offset> _overlayOffsets = {};

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
    try {
      // FlutterMap renderiza tiles async via network. Espera ~500ms
      // pra garantir que os tiles visíveis já estejam pintados antes de
      // capturar — sem isso, o PNG do mapa sai quase em branco
      // (RepaintBoundary só captura o que JÁ foi pintado).
      await Future<void>.delayed(const Duration(milliseconds: 500));
      // ignore: use_build_context_synchronously — key.currentContext é um getter
      // de GlobalKey, não BuildContext capturado antes do gap async.
      final ctx = key.currentContext;
      if (ctx == null) {
        Logger.warn('share.render_png.no_context');
        return null;
      }
      final boundary = ctx.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) {
        Logger.warn('share.render_png.no_boundary');
        return null;
      }
      final image = await boundary.toImage(pixelRatio: 3.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      final bytes = byteData?.buffer.asUint8List();
      Logger.info('share.render_png.ok', context: {'bytes': bytes?.length ?? 0});
      return bytes;
    } catch (e, st) {
      Logger.error('share.render_png.failed', e, st);
      return null;
    }
  }

  /// Salva o PNG em arquivo e devolve o XFile. share_plus tem bugs
  /// conhecidos com XFile.fromData em iOS — alguns apps (WhatsApp,
  /// Twitter/X) não pegam a imagem na share sheet quando vem só de bytes.
  /// File on-disk com path absoluto resolve.
  ///
  /// IMPORTANTE: usar applicationDocumentsDirectory (não temporary). iOS 17
  /// limpa o temp dir em momentos imprevisíveis e a share sheet às vezes
  /// mantém o picker aberto por segundos antes do user escolher o destino;
  /// se o temp file sumir nesse meio, WhatsApp/Twitter recebem "imagem
  /// quebrada" e não compartilham. Documents é persistente até a app
  /// remover. Limpamos shares antigos no fim do método.
  Future<XFile?> _writeTempPng(Uint8List png) async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final shareDir = Directory('${dir.path}/share');
      if (!await shareDir.exists()) {
        await shareDir.create(recursive: true);
      }
      // GC: remove shares com mais de 1h pra não acumular MB na app.
      _cleanupOldShares(shareDir);
      final ts = DateTime.now().millisecondsSinceEpoch;
      final file = File('${shareDir.path}/runnin_share_$ts.png');
      await file.writeAsBytes(png);
      return XFile(file.path, mimeType: 'image/png', name: 'runnin_share.png');
    } catch (e, st) {
      Logger.error('share.write_temp.failed', e, st);
      return null;
    }
  }

  /// Fire-and-forget: deleta PNGs de share gerados há mais de 1h. Rodado
  /// a cada _writeTempPng pra manter o dir enxuto. Falhas silenciosas.
  void _cleanupOldShares(Directory dir) {
    () async {
      try {
        final now = DateTime.now();
        await for (final entity in dir.list()) {
          if (entity is! File) continue;
          if (!entity.path.endsWith('.png')) continue;
          final stat = await entity.stat();
          if (now.difference(stat.modified) > const Duration(hours: 1)) {
            try {
              await entity.delete();
            } catch (_) {/* concorrência com share sheet aberto */}
          }
        }
      } catch (_) {/* dir vazio ou indisponível */}
    }();
  }

  /// Calcula o rect de origem pro share sheet no iPad — sem isso,
  /// `Share.shareXFiles` lança em iPad. iPhone ignora.
  Rect? _sharePositionOrigin() {
    final box = context.findRenderObject() as RenderBox?;
    if (box == null) return null;
    return box.localToGlobal(Offset.zero) & box.size;
  }

  /// Salva PNG na galeria. Em web, share_plus não persiste; mantém aviso.
  Future<void> _saveImage(GlobalKey key) async {
    final png = await _renderPng(key);
    if (png == null) return;
    if (kIsWeb) {
      _showSnack('Salvar imagem disponível apenas no app mobile');
      return;
    }
    try {
      final hasAccess = await Gal.hasAccess(toAlbum: true);
      if (!hasAccess) {
        final granted = await Gal.requestAccess(toAlbum: true);
        if (!granted) {
          Logger.warn('share.save.permission_denied');
          _showSnack('Sem permissão pra galeria. Libere em Ajustes > runnin.');
          return;
        }
      }
      await Gal.putImageBytes(
        png,
        name: 'runnin_${DateTime.now().millisecondsSinceEpoch}',
      );
      _showSnack('Imagem salva na galeria.');
    } on GalException catch (e, st) {
      Logger.error('share.save_failed.gal', e, st, {'code': e.type.message});
      _showSnack('Falha ao salvar: ${e.type.message}');
    } catch (e, st) {
      Logger.error('share.save_failed', e, st);
      _showSnack('Falha ao salvar imagem.');
    }
  }

  static const _igStoriesChannel = MethodChannel('runnin/instagram_stories');

  /// Instagram Stories: iOS via plugin nativo que escreve no UIPasteboard
  /// com chave `com.instagram.sharedSticker.backgroundImage` e abre o
  /// deeplink `instagram-stories://share`. Sem isso, o IG abria vazio.
  /// Fallback pra action sheet genérico se IG não estiver instalado ou
  /// se o plugin retornar false.
  Future<void> _shareToInstagramStories(GlobalKey key) async {
    final png = await _renderPng(key);
    if (png == null) return;
    if (!kIsWeb && Platform.isIOS) {
      try {
        final ok = await _igStoriesChannel.invokeMethod<bool>(
          'shareToStories',
          {
            'imageBase64': base64Encode(png),
            'appId': 'com.s6lab.runnin',
          },
        );
        if (ok == true) {
          Logger.info('share.instagram.opened_native');
          return;
        }
        Logger.info('share.instagram.not_installed_or_failed');
      } catch (e, st) {
        Logger.error('share.instagram_native_failed', e, st);
      }
    }
    // Fallback: action sheet do OS (também usado em Android e quando IG
    // não estiver instalado).
    final file = await _writeTempPng(png);
    if (file == null) {
      _showSnack('Falha ao preparar a imagem.');
      return;
    }
    try {
      await Share.shareXFiles([file], subject: 'Stories Instagram');
    } catch (e, st) {
      Logger.error('share.instagram_fallback_failed', e, st);
      _showSnack('Não conseguimos abrir o Instagram.');
    }
  }

  /// WhatsApp share — usa share_plus com file on-disk (XFile.fromData não
  /// passa pra WA em iOS de forma confiável; com path absoluto, a share
  /// sheet do iOS resolve direito). Arquivo vai em applicationDocuments
  /// (não temp) pra sobreviver à janela que o iOS 17 mantém aberta antes
  /// do user escolher o destino.
  Future<void> _shareToWhatsApp(GlobalKey key) async {
    final png = await _renderPng(key);
    if (png == null) {
      _showSnack('Não consegui capturar a imagem.');
      return;
    }
    final file = await _writeTempPng(png);
    if (file == null) {
      _showSnack('Falha ao preparar a imagem.');
      return;
    }
    try {
      final result = await Share.shareXFiles(
        [file],
        subject: 'Runnin',
        sharePositionOrigin: _sharePositionOrigin(),
      );
      Logger.info('share.whatsapp.result', context: {
        'status': result.status.name,
        if (result.raw.isNotEmpty) 'raw': result.raw,
      });
    } catch (e, st) {
      Logger.error('share.whatsapp_failed', e, st);
      _showSnack('Não conseguimos abrir o WhatsApp.');
    }
  }

  /// Twitter/X share — mesma estratégia do WhatsApp (file on-disk via
  /// share sheet). Antes caía no _shareImage genérico sem subject e sem
  /// log dedicado; agora dá pra rastrear se o user dismissou ou se o
  /// destino simplesmente recusou a imagem.
  Future<void> _shareToTwitter(GlobalKey key) async {
    final png = await _renderPng(key);
    if (png == null) {
      _showSnack('Não consegui capturar a imagem.');
      return;
    }
    final file = await _writeTempPng(png);
    if (file == null) {
      _showSnack('Falha ao preparar a imagem.');
      return;
    }
    try {
      final result = await Share.shareXFiles(
        [file],
        subject: 'Runnin',
        sharePositionOrigin: _sharePositionOrigin(),
      );
      Logger.info('share.twitter.result', context: {
        'status': result.status.name,
        if (result.raw.isNotEmpty) 'raw': result.raw,
      });
    } catch (e, st) {
      Logger.error('share.twitter_failed', e, st);
      _showSnack('Não conseguimos abrir o Twitter / X.');
    }
  }

  void _showSnack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  /// Pergunta câmera ou galeria via bottom sheet. Web cai direto pra galeria
  /// (sem câmera no browser). Native abre sheet → captura/escolhe → bytes.
  Future<void> _pickPhoto() async {
    final ImageSource? source;
    if (kIsWeb) {
      source = ImageSource.gallery;
    } else {
      source = await showModalBottomSheet<ImageSource>(
        context: context,
        backgroundColor: FigmaColors.surfaceCard,
        builder: (sheetContext) => SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: Icon(Icons.photo_camera_outlined,
                    color: context.runninPalette.primary),
                title: const Text('Tirar foto agora'),
                onTap: () => Navigator.pop(sheetContext, ImageSource.camera),
              ),
              ListTile(
                leading: Icon(Icons.photo_library_outlined,
                    color: context.runninPalette.primary),
                title: const Text('Escolher da galeria'),
                onTap: () => Navigator.pop(sheetContext, ImageSource.gallery),
              ),
              const SizedBox(height: 12),
            ],
          ),
        ),
      );
    }
    if (source == null) return;
    try {
      final picker = ImagePicker();
      final picked = await picker.pickImage(source: source, imageQuality: 90);
      if (picked != null) {
        final bytes = await picked.readAsBytes();
        if (mounted) {
          setState(() => _photoBytes = bytes);
        }
      }
    } catch (e, st) {
      Logger.error('share.photo_pick_failed', e, st, {
        'source': source.name,
      });
      _showSnack('Não foi possível abrir ${source == ImageSource.camera ? 'a câmera' : 'a galeria'}.');
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
          _buildAspectSelector(),
          const SizedBox(height: 12),
          RepaintBoundary(
            key: _mapBoundaryKey,
            child: ShareMapCard(
              run: _run!,
              points: _gpsPoints,
              aspectRatio: _aspectRatio,
            ),
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
          // Mesmos 4 destinos da aba FOTO — antes a aba MAPA tinha só
          // COMPARTILHAR/SALVAR genéricos. Agora user envia direto pro
          // IG/WA/Twitter sem precisar passar pela action sheet.
          ..._buildShareTargets(_mapBoundaryKey),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  /// Seletor de proporção 9:16 (story) / 4:5 (feed). Renderizado acima de
  /// cada preview (MAPA e FOTO). Compartilha estado entre as abas — user
  /// escolhe uma vez, ambas usam.
  Widget _buildAspectSelector() {
    Widget chip({required String label, required double value}) {
      final active = (_aspectRatio - value).abs() < 0.001;
      return GestureDetector(
        onTap: () => setState(() {
          _aspectRatio = value;
          // Pixels não escalam corretamente entre 9:16 e 4:5; reseta as
          // posições custom dos chips arrastáveis pra voltar aos cantos.
          _overlayOffsets.clear();
        }),
        behavior: HitTestBehavior.opaque,
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
            label,
            style: context.runninType.labelMd.copyWith(
              fontSize: 10,
              letterSpacing: 0.8,
              color: active ? FigmaColors.bgBase : FigmaColors.textSecondary,
            ),
          ),
        ),
      );
    }

    return Row(
      children: [
        chip(label: '9:16  STORY', value: 9 / 16),
        const SizedBox(width: 8),
        chip(label: '4:5  FEED', value: 4 / 5),
      ],
    );
  }

  /// Lista padrão de 4 destinos de share, reusada em ambas as abas
  /// (MAPA e FOTO). Cada handler renderiza a `RepaintBoundary` apontada
  /// pela [boundaryKey] e dispatcha pra IG/WA/Twitter/Galeria.
  List<Widget> _buildShareTargets(GlobalKey boundaryKey) {
    return [
      _ShareTarget(
        icon: Icons.camera_alt_outlined,
        label: 'Instagram Stories',
        onTap: () => _shareToInstagramStories(boundaryKey),
      ),
      _ShareTarget(
        icon: Icons.chat_bubble_outline,
        label: 'WhatsApp',
        onTap: () => _shareToWhatsApp(boundaryKey),
      ),
      _ShareTarget(
        icon: Icons.alternate_email,
        label: 'Twitter / X',
        onTap: () => _shareToTwitter(boundaryKey),
      ),
      _ShareTarget(
        icon: Icons.save_alt,
        label: 'Salvar imagem',
        onTap: () => _saveImage(boundaryKey),
      ),
    ];
  }

  // ─── TAB 2: CÂMERA + OVERLAY ─────────────────────────────────────────────────

  Widget _buildOverlayTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 12),
          _buildAspectSelector(),
          const SizedBox(height: 12),

          // Photo preview with overlay
          RepaintBoundary(
            key: _overlayBoundaryKey,
            child: _buildOverlayPreview(),
          ),
          if (_photoBytes != null) ...[
            const SizedBox(height: 8),
            Text(
              'Foto: pinça pra ajustar · Chips: arraste pra reposicionar',
              style: context.runninType.bodyXs.copyWith(
                fontSize: 10,
                color: FigmaColors.textMuted,
              ),
            ),
          ],
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

          // Mesmos 4 destinos da aba MAPA — paridade entre abas.
          ..._buildShareTargets(_overlayBoundaryKey),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildOverlayPreview() {
    final distKm = ((_run?.distanceM ?? 0) / 1000).toStringAsFixed(1);
    final pace = _run?.avgPace ?? '--:--';
    final duration = _fmtDuration(_run?.durationS ?? 0);
    final splitLabels = _splitLabels();

    return AspectRatio(
      aspectRatio: _aspectRatio,
      child: LayoutBuilder(
        builder: (context, constraints) {
          // Dimensões reais da RepaintBoundary — usadas pros defaults
          // (top-right precisa de boxWidth, bottom-left de boxHeight) e
          // pra clampar os drags dentro do box.
          final boxSize = Size(constraints.maxWidth, constraints.maxHeight);
          return Container(
            clipBehavior: Clip.hardEdge,
            decoration: BoxDecoration(
              color: const Color(0xFF1A1A2E),
              border: Border.all(color: FigmaColors.borderDefault, width: 1),
            ),
            child: Stack(
              fit: StackFit.expand,
              children: [
                // Photo base or placeholder (placeholder é tappável → abre o
                // seletor de foto, como diz o texto). Com foto, o usuário pode
                // ARRASTAR (posição) e PINÇAR/scroll (tamanho) — só a foto
                // transforma; os textos dos cantos ficam fixos por cima.
                if (_photoBytes != null)
                  Positioned.fill(
                    child: InteractiveViewer(
                      // ValueKey pela identidade dos bytes → ao trocar de foto,
                      // o transform reseta (volta ao enquadramento inicial).
                      key: ValueKey(_photoBytes),
                      panEnabled: true,
                      scaleEnabled: true,
                      minScale: 1.0,
                      maxScale: 5.0,
                      boundaryMargin: const EdgeInsets.all(double.infinity),
                      clipBehavior: Clip.none,
                      child: Image.memory(_photoBytes!, fit: BoxFit.cover),
                    ),
                  )
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

                // CANTO SUPERIOR ESQUERDO: pace / distância / tempo / BPM
                // (um abaixo do outro). Arrastável.
                _draggableOverlay(
                  id: 'stats',
                  defaultPosition: const Offset(16, 16),
                  boxSize: boxSize,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
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

                // CANTO SUPERIOR DIREITO: splits por km. Arrastável; default
                // estimado em ~100px de largura pro chip ficar dentro do box.
                if (_activeToggles.contains(5) && splitLabels.isNotEmpty)
                  _draggableOverlay(
                    id: 'splits',
                    defaultPosition: Offset(boxSize.width - 110, 16),
                    boxSize: boxSize,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                      color: Colors.black.withValues(alpha: 0.45),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          for (final l in splitLabels)
                            Text(
                              l,
                              style: context.runninType.labelCaps.copyWith(
                                fontSize: 9,
                                height: 1.55,
                                letterSpacing: 0.5,
                                color: Colors.white,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),

                // CANTO INFERIOR ESQUERDO: traçado da rota. Arrastável; trace
                // é 84x84 fixo, default na base com 16px de padding.
                if (_activeToggles.contains(4) && _gpsPoints.length >= 2)
                  _draggableOverlay(
                    id: 'route',
                    defaultPosition: Offset(16, boxSize.height - 84 - 16),
                    boxSize: boxSize,
                    child: Container(
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
                  ),

                // CANTO INFERIOR DIREITO: logo RUNNIN.AI. Fixo — é branding.
                Positioned(
                  bottom: 16,
                  right: 16,
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
              ],
            ),
          );
        },
      ),
    );
  }

  /// Wrapper Positioned + Listener pro drag de overlays. Usa Listener
  /// (raw pointer events) em vez de GestureDetector porque o
  /// InteractiveViewer da foto ganha a arena de gestos do GestureDetector
  /// — chip nem se mexia. Listener bypassa a arena: enquanto o pointer
  /// começa em cima do chip, recebemos todos os onPointerMove até soltar,
  /// independente do InteractiveViewer também querer pan.
  ///
  /// Clamp 40px de margem mantém pelo menos um pedaço do grupo dentro do
  /// box mesmo se o user arrastar pra borda.
  Widget _draggableOverlay({
    required String id,
    required Offset defaultPosition,
    required Size boxSize,
    required Widget child,
  }) {
    final pos = _overlayOffsets[id] ?? defaultPosition;
    return Positioned(
      left: pos.dx,
      top: pos.dy,
      child: Listener(
        behavior: HitTestBehavior.opaque,
        onPointerMove: (event) {
          setState(() {
            final cur = _overlayOffsets[id] ?? defaultPosition;
            final next = cur + event.localDelta;
            _overlayOffsets[id] = Offset(
              next.dx.clamp(0.0, boxSize.width - 40),
              next.dy.clamp(0.0, boxSize.height - 40),
            );
          });
        },
        child: child,
      ),
    );
  }

  /// Splits por km como "KM1  mm:ss". Prefere os splits reais da corrida
  /// (run.splits); fallback no cálculo a partir do GPS. Vazio quando não há
  /// dado suficiente (não inventa). Splits parciais (tail < 1km) renderizam
  /// distância+duração reais (ex: '+0.18  0:50') em vez de pace normalizado
  /// — para uma run de 2.18km, o trecho final foram 180m em 50s; pace/km
  /// extrapolado (~05:00) confundia ao sugerir 5min de corrida.
  List<String> _splitLabels() {
    String fmt(int s) => '${s ~/ 60}:${(s % 60).toString().padLeft(2, '0')}';
    final rs = _run?.splits ?? const [];
    if (rs.isNotEmpty) {
      return rs.map((s) {
        if (s.isPartial) {
          final km = (s.distanceM ?? 0) / 1000;
          return '+${km.toStringAsFixed(2)}  ${fmt(s.durationS)}';
        }
        final pace = s.avgPaceMinKm ?? fmt(s.durationS);
        return 'KM${s.kmIndex + 1}  $pace';
      }).toList();
    }
    final secs = computeKmSplitsSeconds(_gpsPoints);
    if (secs.length < 2) return const [];
    return List.generate(secs.length, (i) => 'KM${i + 1}  ${fmt(secs[i].round())}');
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
