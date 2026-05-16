import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:runnin/core/network/api_client.dart';
import 'package:runnin/core/theme/design_system_tokens.dart';
import 'package:runnin/core/units/units.dart';
import 'package:runnin/shared/widgets/figma/figma_selection_button.dart';
import 'package:runnin/shared/widgets/figma/figma_top_nav.dart';
import 'package:runnin/shared/widgets/section_heading.dart';

const _hiveBox = 'runnin_settings';
const _hiveKeyUnitsSystem = 'units_system';
const _hiveKeyPaceFormat = 'pace_format';
const _hiveKeyTimeFormat = 'time_format';

class UnitsSettingsPage extends StatefulWidget {
  const UnitsSettingsPage({super.key});

  @override
  State<UnitsSettingsPage> createState() => _UnitsSettingsPageState();
}

class _UnitsSettingsPageState extends State<UnitsSettingsPage> {
  UnitsSystem _unitsSystem = UnitsSystem.metric;
  PaceFormat _paceFormat = PaceFormat.minPerKm;
  String _timeFormat = '24h';

  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _loadFromHive();
  }

  void _loadFromHive() {
    if (!Hive.isBoxOpen(_hiveBox)) return;
    final box = Hive.box<dynamic>(_hiveBox);
    setState(() {
      _unitsSystem = box.get(_hiveKeyUnitsSystem, defaultValue: UnitsSystem.metric) as UnitsSystem? ?? UnitsSystem.metric;
      _paceFormat = box.get(_hiveKeyPaceFormat, defaultValue: PaceFormat.minPerKm) as PaceFormat? ?? PaceFormat.minPerKm;
      _timeFormat = box.get(_hiveKeyTimeFormat, defaultValue: '24h') as String? ?? '24h';
    });
  }

  Future<void> _saveToHive() async {
    if (!Hive.isBoxOpen(_hiveBox)) return;
    final box = Hive.box<dynamic>(_hiveBox);
    await box.put(_hiveKeyUnitsSystem, _unitsSystem.index);
    await box.put(_hiveKeyPaceFormat, _paceFormat.index);
    await box.put(_hiveKeyTimeFormat, _timeFormat);
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await apiClient.patch('/users/me', data: {
        'unitsSystem': _unitsSystem.name,
        'paceFormat':
            _paceFormat == PaceFormat.minPerKm ? 'min_per_km' : 'min_per_mi',
        'timeFormat': _timeFormat,
      });
      await _saveToHive();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Preferências de unidades salvas.'),
            duration: Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } on DioException {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Erro ao salvar. Tente novamente.'),
            backgroundColor: FigmaColors.brandOrange,
            duration: const Duration(seconds: 3),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  String _formatDistance(double meters) {
    return UnitsHelper(
      unitsSystem: _unitsSystem,
      paceFormat: _paceFormat,
    ).formatDistance(meters);
  }

  String _formatWeight(double kg) {
    return UnitsHelper(
      unitsSystem: _unitsSystem,
      paceFormat: _paceFormat,
    ).formatWeight(kg);
  }

  String _formatHeight(double cm) {
    return UnitsHelper(
      unitsSystem: _unitsSystem,
      paceFormat: _paceFormat,
    ).formatHeight(cm);
  }

  String _formatPace(double minPerKm) {
    return UnitsHelper(
      unitsSystem: _unitsSystem,
      paceFormat: _paceFormat,
    ).formatPace(minPerKm);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: FigmaColors.bgBase,
      body: Column(
        children: [
          const FigmaTopNav(
            breadcrumb: 'Perfil / Ajustes / Unidades',
            showBackButton: true,
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 100),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 24),
                  
                 const SectionHeading(label: 'SISTEMA DE UNIDADES'),
                  const SizedBox(height: 12),
                  FigmaSelectionButton(
                    label: 'Métrico — km, kg, cm, °C',
                    selected: _unitsSystem == UnitsSystem.metric,
                    onTap: () => setState(() => _unitsSystem = UnitsSystem.metric),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  FigmaSelectionButton(
                    label: 'Imperial — mi, lb, ft, °F',
                    selected: _unitsSystem == UnitsSystem.imperial,
                    onTap: () => setState(() => _unitsSystem = UnitsSystem.imperial),
                  ),

                  const SizedBox(height: AppSpacing.xxl),

                  SectionHeading(label: 'FORMATO DE PACE'),
                  const SizedBox(height: 12),
                  if (_unitsSystem == UnitsSystem.metric) ...[
                    FigmaSelectionButton(
                      label: 'min/km',
                      selected: _paceFormat == PaceFormat.minPerKm,
                      onTap: () => setState(() => _paceFormat = PaceFormat.minPerKm),
                    ),
                  ] else ...[
                    FigmaSelectionButton(
                      label: 'min/mi',
                      selected: _paceFormat == PaceFormat.minPerMi,
                      onTap: () => setState(() => _paceFormat = PaceFormat.minPerMi),
                    ),
                  ],

                  const SizedBox(height: AppSpacing.xxl),

                  SectionHeading(label: 'FORMATO DE HORÁRIO'),
                  const SizedBox(height: 12),
                  FigmaSelectionButton(
                    label: '24h',
                    selected: _timeFormat == '24h',
                    onTap: () => setState(() => _timeFormat = '24h'),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  FigmaSelectionButton(
                    label: '12h AM/PM',
                    selected: _timeFormat == '12h',
                    onTap: () => setState(() => _timeFormat = '12h'),
                  ),

                  const SizedBox(height: AppSpacing.xxl),

                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: FigmaColors.surfaceCard,
                      border: Border.all(
                        color: FigmaColors.borderDefault,
                        width: AppDimensions.borderUniversal,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'PRÉVIA',
                          style: GoogleFonts.jetBrainsMono(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: FigmaColors.brandCyan,
                            letterSpacing: 1.0,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('Distância:', style: GoogleFonts.jetBrainsMono(color: FigmaColors.textMuted, fontSize: 12)),
                            Text(_formatDistance(5000), style: GoogleFonts.jetBrainsMono(color: FigmaColors.textPrimary, fontSize: 12)),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('Peso:', style: GoogleFonts.jetBrainsMono(color: FigmaColors.textMuted, fontSize: 12)),
                            Text(_formatWeight(70), style: GoogleFonts.jetBrainsMono(color: FigmaColors.textPrimary, fontSize: 12)),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('Altura:', style: GoogleFonts.jetBrainsMono(color: FigmaColors.textMuted, fontSize: 12)),
                            Text(_formatHeight(175), style: GoogleFonts.jetBrainsMono(color: FigmaColors.textPrimary, fontSize: 12)),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('Pace:', style: GoogleFonts.jetBrainsMono(color: FigmaColors.textMuted, fontSize: 12)),
                            Text(_formatPace(5.5), style: GoogleFonts.jetBrainsMono(color: FigmaColors.textPrimary, fontSize: 12)),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
          child: SizedBox(
            height: 48,
            width: double.infinity,
            child: GestureDetector(
              onTap: _saving ? null : _save,
              child: Container(
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: FigmaColors.brandCyan,
                  border: Border.all(color: FigmaColors.brandCyan, width: 1.041),
                ),
                child: _saving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation(Colors.black),
                        ),
                      )
                    : Text(
                        'SALVAR',
                        style: GoogleFonts.jetBrainsMono(
                          color: FigmaColors.bgBase,
                          fontSize: 13,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.5,
                        ),
                      ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
