import 'package:flutter/material.dart';
import 'package:runnin/core/theme/app_palette.dart';
import 'package:runnin/shared/widgets/app_page_header.dart';
import 'package:runnin/shared/widgets/app_panel.dart';
import 'package:runnin/shared/widgets/toggle_row.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  bool _coachFeedback = true;
  bool _voiceGuidance = true;
  bool _autoPause = false;
  bool _kmLapAlerts = true;
  bool _weeklyDigest = false;
  String _unitSystem = 'km';
  String _theme = 'dark';

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
            const AppPageHeader(title: 'AJUSTES'),
            const SizedBox(height: 16),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
                children: [
                  _sectionLabel('COACH', type),
                  const SizedBox(height: 8),
                  AppPanel(
                    child: Column(
                      children: [
                        ToggleRow(
                          label: 'Feedback do Coach',
                          subtitle: 'Receba análises após cada corrida',
                          value: _coachFeedback,
                          onChanged: (v) => setState(() => _coachFeedback = v),
                        ),
                        const Divider(height: 1, color: palette.border),
                        ToggleRow(
                          label: 'Orientação por voz',
                          subtitle: 'Instruções faladas durante a corrida',
                          value: _voiceGuidance,
                          onChanged: (v) => setState(() => _voiceGuidance = v),
                        ),
                        const Divider(height: 1, color: palette.border),
                        ToggleRow(
                          label: 'Alerta de KM',
                          subtitle: 'Aviso a cada km percorrido',
                          value: _kmLapAlerts,
                          onChanged: (v) => setState(() => _kmLapAlerts = v),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  _sectionLabel('CORRIDA', type),
                  const SizedBox(height: 8),
                  AppPanel(
                    child: Column(
                      children: [
                        ToggleRow(
                          label: 'Pausa automática',
                          subtitle: 'Pausa quando parar de correr',
                          value: _autoPause,
                          onChanged: (v) => setState(() => _autoPause = v),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  _sectionLabel('UNIDADES', type),
                  const SizedBox(height: 8),
                  AppPanel(
                    child: Column(
                      children: [
                        _unitSelector('km / kg / °C'),
                        const Divider(height: 1, color: palette.border),
                        _unitSelector('mi / lb / °F'),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  _sectionLabel('NOTIFICAÇÕES', type),
                  const SizedBox(height: 8),
                  AppPanel(
                    child: Column(
                      children: [
                        ToggleRow(
                          label: 'Resumo semanal',
                          subtitle: 'Relatório de desempenho toda segunda',
                          value: _weeklyDigest,
                          onChanged: (v) => setState(() => _weeklyDigest = v),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sectionLabel(String label, RunninTypography type) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: Text(label, style: type.labelCaps),
    );
  }

  Widget _unitSelector(String label) {
    final palette = context.runninPalette;
    final type = context.runninType;
    final selected = label.startsWith('km');
    return InkWell(
      onTap: () => setState(() => _unitSystem = selected ? 'km' : 'mi'),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          children: [
            Icon(
              selected ? Icons.radio_button_checked : Icons.radio_button_off,
              color: selected ? palette.primary : palette.muted,
              size: 18,
            ),
            const SizedBox(width: 12),
            Text(label, style: type.bodyMd),
          ],
        ),
      ),
    );
  }
}
