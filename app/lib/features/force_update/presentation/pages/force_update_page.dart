import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:runnin/core/remote_config/force_update_controller.dart';
import 'package:runnin/core/theme/app_palette.dart';

/// Tela de bloqueio: janela de manutenção OU atualização obrigatória (versão
/// do app abaixo do mínimo no Remote Config). Bloqueante — sem voltar.
class ForceUpdatePage extends StatefulWidget {
  const ForceUpdatePage({super.key});

  @override
  State<ForceUpdatePage> createState() => _ForceUpdatePageState();
}

class _ForceUpdatePageState extends State<ForceUpdatePage> {
  bool _busy = false;

  Future<void> _update() async {
    final url = forceUpdateController.updateUrl.trim();
    if (url.isEmpty) return;
    setState(() => _busy = true);
    try {
      final uri = Uri.parse(url);
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      // ignora — botão segue disponível pra nova tentativa
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _retry() async {
    setState(() => _busy = true);
    await forceUpdateController.check();
    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.runninPalette;
    final type = context.runninType;
    final isMaintenance = forceUpdateController.isMaintenance;
    final hasUrl = forceUpdateController.updateUrl.trim().isNotEmpty;

    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: palette.background,
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(28),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    isMaintenance
                        ? Icons.build_circle_outlined
                        : Icons.system_update_alt,
                    size: 48,
                    color: palette.primary,
                  ),
                  const SizedBox(height: 20),
                  Text(
                    isMaintenance ? 'EM MANUTENÇÃO' : 'ATUALIZE O APP',
                    style: type.displaySm.copyWith(
                      color: palette.text,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    forceUpdateController.message,
                    style: type.bodyMd.copyWith(
                      color: palette.muted,
                      height: 1.55,
                    ),
                  ),
                  const SizedBox(height: 28),
                  if (!isMaintenance && hasUrl)
                    _PrimaryButton(
                      label: 'ATUALIZAR AGORA',
                      busy: _busy,
                      onTap: _update,
                    )
                  else
                    _PrimaryButton(
                      label: 'TENTAR NOVAMENTE',
                      busy: _busy,
                      onTap: _retry,
                    ),
                  if (isMaintenance && hasUrl) ...[
                    const SizedBox(height: 12),
                    TextButton(
                      onPressed: _busy ? null : _update,
                      child: Text(
                        'MAIS INFORMAÇÕES',
                        style: type.labelCaps.copyWith(
                          color: palette.muted,
                          letterSpacing: 1.0,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PrimaryButton extends StatelessWidget {
  final String label;
  final bool busy;
  final VoidCallback onTap;
  const _PrimaryButton({
    required this.label,
    required this.busy,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final palette = context.runninPalette;
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: ElevatedButton(
        onPressed: busy ? null : onTap,
        style: ElevatedButton.styleFrom(
          backgroundColor: palette.primary,
          foregroundColor: palette.background,
          shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
        ),
        child: busy
            ? SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: palette.background,
                ),
              )
            : Text(
                label,
                style: context.runninType.labelMd.copyWith(
                  fontWeight: FontWeight.w500,
                  letterSpacing: 1.2,
                ),
              ),
      ),
    );
  }
}
