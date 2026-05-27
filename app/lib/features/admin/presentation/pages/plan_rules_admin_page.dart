import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:runnin/core/theme/app_palette.dart';
import 'package:runnin/features/admin/data/admin_registry_datasource.dart';
import 'package:runnin/features/admin/domain/registry_entries.dart';

/// Viewer read-only das constantes de regra do plano. Source-of-truth:
/// `server/.../plan-windows.constants.ts`. Endpoint: GET
/// `/admin/constants/plan-rules`. Mudanças só via deploy.
class PlanRulesAdminPage extends StatefulWidget {
  const PlanRulesAdminPage({super.key});

  @override
  State<PlanRulesAdminPage> createState() => _PlanRulesAdminPageState();
}

class _PlanRulesAdminPageState extends State<PlanRulesAdminPage> {
  final _ds = AdminRegistryDatasource();
  PlanRulesSnapshot? _rules;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final rules = await _ds.getPlanRules();
      if (!mounted) return;
      setState(() {
        _rules = rules;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Erro ao carregar: $e';
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.runninPalette;
    return Scaffold(
      backgroundColor: palette.background,
      appBar: AppBar(
        backgroundColor: palette.background,
        title: Text(
          'REGRAS DO PLANO',
          style: context.runninType.labelCaps.copyWith(
            fontSize: 12,
            letterSpacing: 0.12,
            color: palette.text,
          ),
        ),
      ),
      body: _buildBody(palette),
    );
  }

  Widget _buildBody(RunninPalette palette) {
    if (_loading) {
      return Center(
        child: CircularProgressIndicator(color: palette.primary, strokeWidth: 2),
      );
    }
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_error!, style: context.runninType.bodyMd.copyWith(color: palette.muted)),
            const SizedBox(height: 12),
            TextButton(onPressed: _load, child: const Text('TENTAR NOVAMENTE')),
          ],
        ),
      );
    }
    final r = _rules!;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _intro(palette),
          const SizedBox(height: 16),
          _section(palette, 'Rampa de volume', {
            'WEEKLY_RAMP_RATE': r.weeklyRampRate.toString(),
            'RAMP_BASE_FLOOR_KM': r.rampBaseFloorKm.toString(),
          }),
          _jsonSection(palette, 'Janelas de prova (RACE_WINDOWS)', r.raceWindows),
          _jsonSection(palette, 'Pico semanal por distância (PEAK_WEEKLY_KM)', r.peakWeeklyKm),
          _jsonSection(palette, 'Frequência mínima (MIN_FREQ_BY_PROFILE_DISTANCE)', r.minFreqByProfileDistance),
          _jsonSection(palette, 'Restrições de janela (WINDOW_RESTRICTION_BY_PROFILE)', r.windowRestrictionByProfile),
          _jsonSection(palette, 'Bypass improve_pace por nível (IMPROVE_PACE_BYPASS_BY_LEVEL)', r.improvePaceBypassByLevel),
          _jsonSection(palette, 'Cap de km por sessão (MAX_KM_PER_SESSION)', r.maxKmPerSession),
          _jsonSection(palette, 'Idade — restrições (AGE_RESTRICTION_THRESHOLDS)', r.ageRestrictionThresholds),
          _jsonSection(palette, 'Ceiling de melhora de pace (PACE_IMPROVEMENT_CEILING_PCT)', r.paceImprovementCeilingPct),
          _stringListSection(palette, 'Comorbidades sérias (SERIOUS_MEDICAL_KEYWORDS)', r.seriousMedicalKeywords),
        ],
      ),
    );
  }

  Widget _intro(RunninPalette palette) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: palette.surface,
        border: Border.all(color: palette.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'READ-ONLY',
            style: context.runninType.labelCaps.copyWith(
              fontSize: 10,
              color: palette.secondary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Constantes que controlam validações de geração de plano (volume, pace, frequência, restrições por idade/comorbidade). Mudanças só via PR no server (`plan-windows.constants.ts`).',
            style: context.runninType.bodySm.copyWith(color: palette.muted, height: 1.4),
          ),
        ],
      ),
    );
  }

  Widget _section(RunninPalette palette, String title, Map<String, String> kv) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: palette.surface,
          border: Border.all(color: palette.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: context.runninType.labelCaps.copyWith(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: palette.text,
              ),
            ),
            const SizedBox(height: 8),
            for (final entry in kv.entries)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        entry.key,
                        style: context.runninType.bodySm.copyWith(color: palette.muted),
                      ),
                    ),
                    Text(
                      entry.value,
                      style: context.runninType.dataSm.copyWith(color: palette.text),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _jsonSection(RunninPalette palette, String title, Map<String, dynamic> data) {
    final pretty = const JsonEncoder.withIndent('  ').convert(data);
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: palette.surface,
          border: Border.all(color: palette.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: context.runninType.labelCaps.copyWith(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: palette.text,
              ),
            ),
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(8),
              color: palette.background,
              child: SelectableText(
                pretty,
                style: context.runninType.dataSm.copyWith(
                  fontSize: 11,
                  color: palette.text,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _stringListSection(RunninPalette palette, String title, List<String> items) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: palette.surface,
          border: Border.all(color: palette.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: context.runninType.labelCaps.copyWith(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: palette.text,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: items
                  .map((s) => Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: palette.surfaceAlt,
                          border: Border.all(color: palette.border),
                        ),
                        child: Text(
                          s,
                          style: context.runninType.bodyXs.copyWith(color: palette.text),
                        ),
                      ))
                  .toList(),
            ),
          ],
        ),
      ),
    );
  }
}
