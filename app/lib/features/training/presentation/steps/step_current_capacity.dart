import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:runnin/core/theme/app_palette.dart';
import 'package:runnin/features/training/domain/plan_admissibility.dart';
import 'package:runnin/shared/widgets/figma/export.dart';

/// Tela de captura de capacidade atual.
/// Substitui o step_current_load.dart com UX mais natural:
///   1. "Já corre?" sim/não
///   2. Se sim: slider de distância (3/5/10/21/42 km) + tempo (mm:ss)
///   3. Pace calculado automaticamente e mostrado em destaque
///   4. Volume semanal (km/sem) com hint do histórico
class StepCurrentCapacity extends StatefulWidget {
  /// Distância selecionada no slider (km).
  final int? selectedDistanceKm;
  /// Tempo em segundos pra essa distância.
  final int? timeSeconds;
  /// Volume semanal médio atual (km/sem).
  final double? weeklyKm;
  /// Já corre? null = ainda não respondeu; true/false = decidido.
  final bool? alreadyRuns;
  final String? historyHint;
  /// Quando RACE: distância alvo + weeksCount já escolhidos → mostra warning
  /// de volume insuficiente em tempo real.
  final int? raceDistanceKm;
  final int? weeksCount;

  final ValueChanged<bool> onAlreadyRunsChange;
  final ValueChanged<int> onDistanceChange;
  final ValueChanged<int> onTimeChange;
  final ValueChanged<double?> onWeeklyKmChange;

  const StepCurrentCapacity({
    super.key,
    required this.selectedDistanceKm,
    required this.timeSeconds,
    required this.weeklyKm,
    required this.alreadyRuns,
    required this.historyHint,
    required this.raceDistanceKm,
    required this.weeksCount,
    required this.onAlreadyRunsChange,
    required this.onDistanceChange,
    required this.onTimeChange,
    required this.onWeeklyKmChange,
  });

  @override
  State<StepCurrentCapacity> createState() => _StepCurrentCapacityState();
}

class _StepCurrentCapacityState extends State<StepCurrentCapacity> {
  static const _distances = [3, 5, 10, 21, 42];
  late final TextEditingController _minCtrl;
  late final TextEditingController _secCtrl;
  late final TextEditingController _kmCtrl;
  // TF 79: FocusNodes nos campos de tempo pra disparar auto-scroll que
  // mantém o campo de VOLUME SEMANAL visível quando o teclado sobe. Sem
  // isso o user clica em min/seg, teclado cobre o volume, ele não vê
  // o campo e bate "continuar" sem preencher → plano sem baseline.
  late final FocusNode _minFocus;
  late final FocusNode _secFocus;
  /// Key do bloco "VOLUME SEMANAL ATUAL" pra `Scrollable.ensureVisible`.
  final GlobalKey _weeklyKmKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    final m = (widget.timeSeconds ?? 0) ~/ 60;
    final s = (widget.timeSeconds ?? 0) % 60;
    _minCtrl = TextEditingController(text: m > 0 ? m.toString() : '');
    _secCtrl = TextEditingController(text: s > 0 ? s.toString().padLeft(2, '0') : '');
    _kmCtrl = TextEditingController(
      text: widget.weeklyKm != null ? widget.weeklyKm!.toStringAsFixed(0) : '',
    );
    _minFocus = FocusNode();
    _secFocus = FocusNode();
    // Quando teclado abre nos campos de tempo, agenda scroll pro bloco
    // VOLUME SEMANAL ficar visível na linha de baixo (logo após o tempo).
    // Sem isso o teclado cobria o campo e o user nem sabia que existia.
    _minFocus.addListener(_handleTimeFocus);
    _secFocus.addListener(_handleTimeFocus);
  }

  void _handleTimeFocus() {
    if (!(_minFocus.hasFocus || _secFocus.hasFocus)) return;
    // Espera o teclado terminar de subir (~300ms) e o scroll viewport
    // recomputar viewInsets antes de chamar ensureVisible.
    Future<void>.delayed(const Duration(milliseconds: 320), () {
      if (!mounted) return;
      final ctx = _weeklyKmKey.currentContext;
      if (ctx == null || !ctx.mounted) return;
      Scrollable.ensureVisible(
        ctx,
        duration: const Duration(milliseconds: 240),
        curve: Curves.easeOutCubic,
        alignment: 1.0, // alinha o bloco no FUNDO do viewport visível
      );
    });
  }

  @override
  void dispose() {
    _minFocus.removeListener(_handleTimeFocus);
    _secFocus.removeListener(_handleTimeFocus);
    _minFocus.dispose();
    _secFocus.dispose();
    _minCtrl.dispose();
    _secCtrl.dispose();
    _kmCtrl.dispose();
    super.dispose();
  }

  void _emitTimeChange() {
    final m = int.tryParse(_minCtrl.text.trim()) ?? 0;
    final s = int.tryParse(_secCtrl.text.trim()) ?? 0;
    widget.onTimeChange(m * 60 + s);
  }

  String? _computedPaceLabel() {
    if (widget.selectedDistanceKm == null || widget.timeSeconds == null || widget.timeSeconds! <= 0) {
      return null;
    }
    final paceSecPerKm = widget.timeSeconds! / widget.selectedDistanceKm!;
    final m = paceSecPerKm ~/ 60;
    final s = (paceSecPerKm % 60).round();
    return '$m:${s.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.runninPalette;
    final paceLabel = _computedPaceLabel();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 12),
        const FigmaAssessmentLabel(text: '// CAPACIDADE ATUAL'),
        const SizedBox(height: 14),
        const FigmaAssessmentHeading(text: 'Quanto você corre hoje?'),
        const SizedBox(height: 10),
        const FigmaAssessmentDescription(
          text: 'Coach calibra a primeira semana sem te jogar em pace ou volume que não cabe.',
        ),
        const SizedBox(height: 22),
        // "Já corre?" toggle
        Row(
          children: [
            Expanded(child: _YesNoButton(
              label: 'JÁ CORRO',
              selected: widget.alreadyRuns == true,
              onTap: () => widget.onAlreadyRunsChange(true),
            )),
            const SizedBox(width: 10),
            Expanded(child: _YesNoButton(
              label: 'AINDA NÃO',
              selected: widget.alreadyRuns == false,
              onTap: () => widget.onAlreadyRunsChange(false),
            )),
          ],
        ),
        if (widget.alreadyRuns == true) ...[
          const SizedBox(height: 26),
          Text(
            'CORRIDA RECENTE CONFORTÁVEL (não PR)',
            style: context.runninType.labelMd.copyWith(
              color: palette.muted,
              letterSpacing: 1.2,
              fontSize: 11,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final d in _distances)
                _DistChip(
                  km: d,
                  selected: widget.selectedDistanceKm == d,
                  onTap: () => widget.onDistanceChange(d),
                ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            'EM QUANTO TEMPO?',
            style: context.runninType.labelMd.copyWith(
              color: palette.muted,
              letterSpacing: 1.2,
              fontSize: 11,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _minCtrl,
                  focusNode: _minFocus,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  textAlign: TextAlign.center,
                  style: context.runninType.dataMd,
                  // scrollPadding generoso garante que o campo NÃO seja
                  // empurrado p/ borda — sobra espaço pra ver o bloco
                  // de VOLUME logo abaixo.
                  scrollPadding: const EdgeInsets.only(bottom: 240),
                  decoration: const InputDecoration(
                    hintText: 'min',
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (_) => _emitTimeChange(),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Text(':', style: context.runninType.dataMd),
              ),
              Expanded(
                child: TextField(
                  controller: _secCtrl,
                  focusNode: _secFocus,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  textAlign: TextAlign.center,
                  style: context.runninType.dataMd,
                  scrollPadding: const EdgeInsets.only(bottom: 240),
                  decoration: const InputDecoration(
                    hintText: 'seg',
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (_) => _emitTimeChange(),
                ),
              ),
            ],
          ),
          if (paceLabel != null) ...[
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: palette.primary.withValues(alpha: 0.08),
                border: Border.all(color: palette.primary.withValues(alpha: 0.4)),
              ),
              child: Row(
                children: [
                  Icon(Icons.speed, size: 18, color: palette.primary),
                  const SizedBox(width: 10),
                  Text(
                    'Pace atual:',
                    style: context.runninType.bodySm.copyWith(color: palette.muted),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '$paceLabel/km',
                    style: context.runninType.dataMd.copyWith(color: palette.primary),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 26),
          // Key usada pelo _handleTimeFocus pra rolar este bloco pra
          // dentro do viewport quando o teclado dos campos de tempo sobe.
          Container(
            key: _weeklyKmKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'VOLUME SEMANAL ATUAL (KM/SEM) *',
                  style: context.runninType.labelMd.copyWith(
                    color: palette.muted,
                    letterSpacing: 1.2,
                    fontSize: 11,
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _kmCtrl,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^[0-9]*\.?[0-9]{0,1}'))],
                  style: context.runninType.dataMd,
                  scrollPadding: const EdgeInsets.only(bottom: 240),
                  decoration: const InputDecoration(
                    hintText: 'ex: 25',
                    suffixText: 'km',
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (v) {
                    final n = double.tryParse(v.trim());
                    widget.onWeeklyKmChange(n);
                  },
                ),
              ],
            ),
          ),
          if (widget.historyHint != null) ...[
            const SizedBox(height: 8),
            Text(
              widget.historyHint!,
              style: context.runninType.bodyXs.copyWith(color: palette.muted),
            ),
          ],
          ..._buildVolumeRampHint(context, palette),
        ],
        if (widget.alreadyRuns == false) ...[
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: palette.surface,
              border: Border.all(color: palette.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Beleza — começamos do zero.',
                  style: context.runninType.labelMd.copyWith(color: palette.primary),
                ),
                const SizedBox(height: 8),
                Text(
                  'O plano usa walk-run (alternância trote leve / caminhada) nas '
                  'primeiras semanas pra construir base sem te machucar. Sem '
                  'cobrança de pace.',
                  style: context.runninType.bodySm.copyWith(color: palette.muted, height: 1.4),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  /// Em RACE: projeta ramping do volume atual contra o pico semanal exigido
  /// pela distância. Mostra ✅ (verde) ou ⚠️ (amarelo).
  List<Widget> _buildVolumeRampHint(BuildContext context, RunninPalette palette) {
    final dist = widget.raceDistanceKm;
    final weeks = widget.weeksCount;
    if (dist == null || weeks == null || weeks <= 0) return const [];
    final peak = AdmissibilityConstants.peakWeeklyKm[dist] ?? 0;
    if (peak <= 0) return const []; // 5K skip

    final current = widget.weeklyKm ?? 0;
    final base = current > AdmissibilityConstants.rampBaseFloorKm
        ? current
        : AdmissibilityConstants.rampBaseFloorKm.toDouble();
    var ramped = base;
    for (var i = 0; i < weeks; i++) {
      ramped *= AdmissibilityConstants.weeklyRampRate;
    }
    final ok = ramped >= peak;
    return [
      const SizedBox(height: 12),
      Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: (ok ? palette.success : palette.warning).withValues(alpha: 0.10),
          border: Border.all(
            color: (ok ? palette.success : palette.warning).withValues(alpha: 0.55),
          ),
        ),
        child: Row(
          children: [
            Icon(
              ok ? Icons.check_circle_outline : Icons.warning_amber_outlined,
              size: 16,
              color: ok ? palette.success : palette.warning,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                ok
                    ? 'Com ${current.toStringAsFixed(0)}km/sem rampando 10%/sem em $weeks sem, '
                        'chega a ~${ramped.toStringAsFixed(0)}km/sem. Pico pra ${dist}K = ${peak}km/sem. ✓'
                    : 'Volume atual (${current.toStringAsFixed(0)}km/sem) só rampa pra '
                        '~${ramped.toStringAsFixed(0)}km/sem em $weeks sem. Pico ${peak}km/sem pra ${dist}K não cabe.',
                style: context.runninType.bodyXs.copyWith(color: palette.text, height: 1.4),
              ),
            ),
          ],
        ),
      ),
    ];
  }
}

class _YesNoButton extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _YesNoButton({required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final palette = context.runninPalette;
    return InkWell(
      onTap: onTap,
      child: Container(
        height: 52,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? palette.primary.withValues(alpha: 0.12) : palette.surface,
          border: Border.all(
            color: selected ? palette.primary : palette.border,
            width: 1.041,
          ),
        ),
        child: Text(
          label,
          style: context.runninType.labelMd.copyWith(
            color: selected ? palette.primary : palette.text,
            fontWeight: FontWeight.w500,
            letterSpacing: 1.2,
          ),
        ),
      ),
    );
  }
}

class _DistChip extends StatelessWidget {
  final int km;
  final bool selected;
  final VoidCallback onTap;
  const _DistChip({required this.km, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final palette = context.runninPalette;
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? palette.primary.withValues(alpha: 0.12) : palette.surface,
          border: Border.all(
            color: selected ? palette.primary : palette.border,
            width: 1.041,
          ),
        ),
        child: Text(
          '${km}K',
          style: context.runninType.labelMd.copyWith(
            color: selected ? palette.primary : palette.text,
            fontWeight: FontWeight.w500,
            letterSpacing: 1.2,
          ),
        ),
      ),
    );
  }
}
