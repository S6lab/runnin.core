import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:runnin/core/theme/app_palette.dart';
import 'package:runnin/core/theme/design_system_tokens.dart';
import 'package:runnin/shared/widgets/section_heading.dart';

/// Modal educacional pra solicitação de GPS no web. Dois modos:
///
/// **pre-request** (status unknown/denied não-forever):
///   Avisa o user que vamos pedir permissão e como responder. Botão
///   "ATIVAR GPS" dispara Geolocator.requestPermission() e fecha o
///   modal com o resultado.
///
/// **blocked** (status deniedForever / serviço off):
///   Mostra passo-a-passo de como liberar no Chrome (ícone cadeado →
///   Site permissions → Location: Allow). Botão "VERIFIQUEI, TENTAR
///   DE NOVO" re-checa permissão.
///
/// Retorna Future<bool> indicando se a permissão ficou OK ao fechar.
class GpsPermissionModal extends StatefulWidget {
  /// Mode default = pre-request. Se o caller sabe que está blocked,
  /// passa true pra abrir direto na tela de instruções.
  final bool blocked;
  const GpsPermissionModal({super.key, this.blocked = false});

  /// Helper conveniente: mostra o modal e devolve true se permissão OK.
  static Future<bool> show(BuildContext context, {bool blocked = false}) async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (_) => GpsPermissionModal(blocked: blocked),
    );
    return result ?? false;
  }

  @override
  State<GpsPermissionModal> createState() => _GpsPermissionModalState();
}

class _GpsPermissionModalState extends State<GpsPermissionModal> {
  late bool _isBlocked = widget.blocked;
  bool _requesting = false;

  Future<void> _requestPermission() async {
    setState(() => _requesting = true);
    try {
      final serviceOn = await Geolocator.isLocationServiceEnabled();
      if (!serviceOn) {
        setState(() {
          _isBlocked = true;
          _requesting = false;
        });
        return;
      }
      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.deniedForever) {
        setState(() {
          _isBlocked = true;
          _requesting = false;
        });
        return;
      }
      final ok = perm == LocationPermission.always ||
          perm == LocationPermission.whileInUse;
      if (mounted) Navigator.of(context).pop(ok);
    } catch (_) {
      if (mounted) {
        setState(() {
          _isBlocked = true;
          _requesting = false;
        });
      }
    }
  }

  Future<void> _recheckAfterUnblock() async {
    final serviceOn = await Geolocator.isLocationServiceEnabled();
    final perm = await Geolocator.checkPermission();
    final ok = serviceOn &&
        (perm == LocationPermission.always ||
            perm == LocationPermission.whileInUse);
    if (!mounted) return;
    if (ok) {
      Navigator.of(context).pop(true);
    } else {
      // Continua mostrando instruções
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.runninPalette;
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 60),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 420),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: palette.surface,
          border: Border.all(
            color: _isBlocked
                ? FigmaColors.brandOrange.withValues(alpha: 0.6)
                : FigmaColors.brandCyan.withValues(alpha: 0.6),
            width: 1,
          ),
        ),
        child: _isBlocked
            ? _buildBlocked(context, palette)
            : _buildPreRequest(context, palette),
      ),
    );
  }

  Widget _buildPreRequest(BuildContext context, RunninPalette palette) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionHeading(label: '> PERMISSÃO DE GPS'),
        const SizedBox(height: 14),
        Text(
          'O coach precisa do GPS pra acompanhar sua corrida em tempo real.',
          style: GoogleFonts.jetBrainsMono(
            color: palette.text,
            fontSize: 14,
            height: 1.5,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 10),
        Text(
          'Quando o navegador pedir, clique em "Permitir". Sem isso o mapa não consegue desenhar seu trajeto.',
          style: TextStyle(
            color: palette.text.withValues(alpha: 0.78),
            fontSize: 13,
            height: 1.5,
          ),
        ),
        const SizedBox(height: 20),
        Row(
          children: [
            Expanded(
              child: SizedBox(
                height: 46,
                child: OutlinedButton(
                  onPressed: _requesting
                      ? null
                      : () => Navigator.of(context).pop(false),
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: palette.border),
                    shape: const RoundedRectangleBorder(
                      borderRadius: BorderRadius.zero,
                    ),
                  ),
                  child: Text(
                    'AGORA NÃO',
                    style: TextStyle(color: palette.muted),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              flex: 2,
              child: SizedBox(
                height: 46,
                child: ElevatedButton(
                  onPressed: _requesting ? null : _requestPermission,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: FigmaColors.brandCyan,
                    foregroundColor: palette.background,
                    shape: const RoundedRectangleBorder(
                      borderRadius: BorderRadius.zero,
                    ),
                  ),
                  child: _requesting
                      ? SizedBox(
                          height: 18,
                          width: 18,
                          child: CircularProgressIndicator(
                            color: palette.background,
                            strokeWidth: 2,
                          ),
                        )
                      : const Text(
                          'ATIVAR GPS',
                          style: TextStyle(
                            fontWeight: FontWeight.w500,
                            letterSpacing: 1.2,
                          ),
                        ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildBlocked(BuildContext context, RunninPalette palette) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionHeading(
          label: '> PERMISSÃO BLOQUEADA',
          dotColor: FigmaColors.brandOrange,
        ),
        const SizedBox(height: 14),
        Text(
          'O navegador está bloqueando o GPS deste site.',
          style: GoogleFonts.jetBrainsMono(
            color: palette.text,
            fontSize: 14,
            height: 1.5,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 12),
        _Step(num: '1', text: 'Clique no ícone de cadeado (ou de info) na barra de endereço, à esquerda da URL.'),
        const SizedBox(height: 6),
        _Step(num: '2', text: 'Procure por "Localização" / "Site settings" e marque como Permitir.'),
        const SizedBox(height: 6),
        _Step(num: '3', text: 'Recarregue a página se o navegador pedir.'),
        const SizedBox(height: 20),
        Row(
          children: [
            Expanded(
              child: SizedBox(
                height: 46,
                child: OutlinedButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: palette.border),
                    shape: const RoundedRectangleBorder(
                      borderRadius: BorderRadius.zero,
                    ),
                  ),
                  child: Text(
                    'FECHAR',
                    style: TextStyle(color: palette.muted),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              flex: 2,
              child: SizedBox(
                height: 46,
                child: ElevatedButton(
                  onPressed: _recheckAfterUnblock,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: FigmaColors.brandCyan,
                    foregroundColor: palette.background,
                    shape: const RoundedRectangleBorder(
                      borderRadius: BorderRadius.zero,
                    ),
                  ),
                  child: const Text(
                    'VERIFIQUEI, TENTAR',
                    style: TextStyle(
                      fontWeight: FontWeight.w500,
                      letterSpacing: 1.2,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _Step extends StatelessWidget {
  final String num;
  final String text;
  const _Step({required this.num, required this.text});

  @override
  Widget build(BuildContext context) {
    final palette = context.runninPalette;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 22,
          height: 22,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: FigmaColors.brandOrange.withValues(alpha: 0.18),
            border: Border.all(
              color: FigmaColors.brandOrange.withValues(alpha: 0.55),
            ),
          ),
          child: Text(
            num,
            style: GoogleFonts.jetBrainsMono(
              color: FigmaColors.brandOrange,
              fontSize: 11,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(top: 3),
            child: Text(
              text,
              style: TextStyle(
                color: palette.text.withValues(alpha: 0.85),
                fontSize: 12.5,
                height: 1.5,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
