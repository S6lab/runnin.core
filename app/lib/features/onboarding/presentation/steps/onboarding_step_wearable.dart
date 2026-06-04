import 'package:flutter/material.dart';
import 'package:runnin/core/theme/app_palette.dart';
import 'package:runnin/core/theme/design_system_tokens.dart';
import 'package:runnin/features/biometrics/data/health_sync_service.dart';
import 'package:runnin/features/profile/data/exam_uploader.dart';
import 'package:runnin/shared/widgets/figma/export.dart';

/// Step do onboarding que oferece sincronizar dados de saúde.
///
/// "Sim (conectar agora)" dispara `requestPermissions` + `syncSince`,
/// confirmando a conexão real (antes só salvava um boolean sem nunca abrir o
/// diálogo de permissão). Quando o permission grant volta true, marcamos
/// hasWearable=true; o `syncSince` em background promove resting_bpm/max_bpm
/// pro perfil (server-side em IngestSamplesUseCase) — esses dados vão alimentar
/// a geração do plano em seguida.
///
/// "Depois" mantém comportamento atual: hasWearable=false, sem conexão. User
/// pode conectar depois em Perfil → Saúde → Dispositivos.
class OnboardingStepWearable extends StatefulWidget {
  final bool selected;
  final ValueChanged<bool> onSelect;

  const OnboardingStepWearable({
    super.key,
    required this.selected,
    required this.onSelect,
  });

  @override
  State<OnboardingStepWearable> createState() => _OnboardingStepWearableState();
}

class _OnboardingStepWearableState extends State<OnboardingStepWearable> {
  final _examUploader = ExamUploader();
  bool _connecting = false;
  bool _connected = false;
  int? _syncedCount;
  String? _error;
  bool _uploadingExam = false;
  int _examsUploaded = 0;
  String? _examError;

  bool get _isSupported => healthSyncService.isSupported;

  Future<void> _onConnectTap() async {
    if (_connecting) return;
    if (!_isSupported) {
      setState(() {
        _error = 'Sincronização de saúde está disponível só em iOS e Android.';
      });
      return;
    }
    setState(() {
      _connecting = true;
      _error = null;
    });

    final granted = await healthSyncService.requestPermissions();
    if (!mounted) return;

    if (!granted) {
      setState(() {
        _connecting = false;
        _error =
            'Permissão negada. Você pode liberar depois em Ajustes do iPhone > Saúde > runnin (ou em Health Connect no Android).';
      });
      widget.onSelect(false);
      return;
    }

    // Permission OK — registra hasWearable=true imediatamente e dispara o sync
    // em background. O resultado do sync (samples_saved) chega em segundos e
    // atualiza o feedback visual. Server-side promote já joga restingBpm /
    // maxBpm no perfil pra alimentar a geração do plano.
    widget.onSelect(true);
    setState(() {
      _connecting = false;
      _connected = true;
    });

    final count = await healthSyncService.syncSince().catchError((_) => 0);
    if (!mounted) return;
    setState(() => _syncedCount = count);
  }

  void _onSkipTap() {
    setState(() {
      _connected = false;
      _syncedCount = null;
      _error = null;
    });
    widget.onSelect(false);
  }

  Future<void> _onUploadExamTap() async {
    if (_uploadingExam) return;
    setState(() {
      _uploadingExam = true;
      _examError = null;
    });
    final outcome = await _examUploader.pickAndUpload(context);
    if (!mounted) return;
    if (outcome.isSuccess) {
      setState(() {
        _examsUploaded += 1;
        _uploadingExam = false;
      });
    } else {
      setState(() {
        _uploadingExam = false;
        _examError = outcome.errorMessage;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 12),
          const FigmaAssessmentHeading(text: 'Sincronizar dados de saúde?'),
          const SizedBox(height: 10),
          const FigmaAssessmentDescription(
            text:
                'A gente lê BPM, sono e atividade da Apple Health (iOS) ou do '
                'Google Health Connect (Android) — o que o seu relógio já '
                'envia pra essas plataformas. Não conectamos ao dispositivo direto.',
          ),
          const SizedBox(height: 24),
          if (_connected)
            _ConnectedCard(syncedCount: _syncedCount)
          else ...[
            FigmaSelectionButton(
              label: _connecting
                  ? 'Conectando…'
                  : 'Sim, conectar agora (recomendado)',
              selected: widget.selected && !_connecting,
              onTap: _connecting ? () {} : _onConnectTap,
            ),
            const SizedBox(height: 8),
            FigmaSelectionButton(
              label: 'Depois',
              selected: !widget.selected && !_connecting,
              onTap: _connecting ? () {} : _onSkipTap,
            ),
          ],
          if (_error != null) ...[
            const SizedBox(height: 12),
            _ErrorBanner(message: _error!),
          ],
          const SizedBox(height: 24),
          FigmaCoachAIBlock(
            variant: CoachAIBlockVariant.assessment,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      color: context.runninPalette.secondary.withValues(alpha: 0.50),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '> COACH.AI',
                      style: context.runninType.bodyXs.copyWith(
                        letterSpacing: 1.65,
                        color: context.runninPalette.secondary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  _connected
                      ? 'Recebi seus dados. Vou usar BPM em repouso e padrão de sono pra calibrar zonas cardíacas reais (Karvonen) e ajustar a intensidade dos treinos ao seu estado atual.'
                      : 'Tenho tudo que preciso — incluindo sua rotina de sono e horário preferido. Vou calcular a janela metabólica ideal para cada tipo de treino, enviar lembretes de hidratação e preparo nutricional, e sugerir o melhor horário com base no seu padrão de sono.',
                  style: context.runninType.bodyMd.copyWith(
                    height: 23.1 / 14,
                    color: const Color(0xCCFFFFFF),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          FigmaCyanInfoBlock(
            icon: Icons.description_outlined,
            title: 'Tem exames médicos recentes?',
            bodyWidget: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text.rich(
                  TextSpan(
                    style: context.runninType.bodySm.copyWith(
                      height: 19.2 / 12,
                      color: FigmaColors.textSecondary,
                    ),
                    children: [
                      const TextSpan(
                        text:
                            'Testes ergométricos, exames de sangue e laudos médicos permitem que eu calibre zonas cardíacas com FC máx real, monitore ferritina e identifique restrições. Envie agora (PDF ou foto, máx 10MB) ou depois em ',
                      ),
                      TextSpan(
                        text: 'Perfil → Saúde → Exames',
                        style: context.runninType.labelMd.copyWith(
                          fontWeight: FontWeight.w500,
                          height: 19.2 / 12,
                          color: context.runninPalette.primary,
                        ),
                      ),
                      const TextSpan(text: '.'),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                _ExamUploadButton(
                  uploading: _uploadingExam,
                  uploadedCount: _examsUploaded,
                  onTap: _onUploadExamTap,
                ),
                if (_examError != null) ...[
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    _examError!,
                    style: context.runninType.bodySm.copyWith(
                      color: context.runninPalette.error,
                      height: 19.2 / 12,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Botão de upload de exame dentro do FigmaCyanInfoBlock. Mostra estado de
/// carregamento e contador de exames enviados sem bloquear o avanço do
/// onboarding — exames são opcionais.
class _ExamUploadButton extends StatelessWidget {
  final bool uploading;
  final int uploadedCount;
  final VoidCallback onTap;

  const _ExamUploadButton({
    required this.uploading,
    required this.uploadedCount,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final palette = context.runninPalette;
    final hasUploads = uploadedCount > 0;
    final label = uploading
        ? 'Enviando…'
        : hasUploads
            ? 'Enviar mais um exame (+$uploadedCount)'
            : 'Enviar exame agora';
    return SizedBox(
      width: double.infinity,
      height: 44,
      child: OutlinedButton.icon(
        onPressed: uploading ? null : onTap,
        icon: Icon(
          uploading
              ? Icons.hourglass_top_outlined
              : hasUploads
                  ? Icons.check_circle_outline
                  : Icons.upload_file_outlined,
          color: palette.primary,
          size: 18,
        ),
        label: Text(
          label,
          style: context.runninType.labelMd.copyWith(
            color: palette.primary,
            fontWeight: FontWeight.w500,
          ),
        ),
        style: OutlinedButton.styleFrom(
          side: BorderSide(color: palette.primary, width: 1),
          shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
          padding: const EdgeInsets.symmetric(horizontal: 16),
        ),
      ),
    );
  }
}

class _ConnectedCard extends StatelessWidget {
  final int? syncedCount;

  const _ConnectedCard({required this.syncedCount});

  @override
  Widget build(BuildContext context) {
    final palette = context.runninPalette;
    final statusLine = syncedCount == null
        ? 'Sincronizando seus dados…'
        : syncedCount! > 0
            ? '$syncedCount amostras dos últimos 7 dias importadas.'
            : 'Sem amostras novas. Coach.AI vai usar valores padrão pelo perfil.';
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.xl),
      decoration: BoxDecoration(
        color: FigmaColors.surfaceCard,
        border: Border.all(
          color: palette.primary.withValues(alpha: 0.5),
          width: 1.041,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.check_circle_outline, color: palette.primary, size: 20),
              const SizedBox(width: 8),
              Text(
                'CONECTADO',
                style: context.runninType.labelMd.copyWith(
                  fontWeight: FontWeight.w500,
                  letterSpacing: 1.0,
                  color: palette.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            statusLine,
            style: context.runninType.bodySm.copyWith(
              height: 1.5,
              color: FigmaColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  final String message;

  const _ErrorBanner({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: FigmaColors.surfaceCard,
        border: Border.all(
          color: FigmaColors.borderDefault,
          width: 1.041,
        ),
      ),
      child: Text(
        message,
        style: context.runninType.bodySm.copyWith(
          height: 1.5,
          color: FigmaColors.textSecondary,
        ),
      ),
    );
  }
}
