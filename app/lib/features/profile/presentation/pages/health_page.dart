import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:runnin/core/theme/app_palette.dart';
import 'package:runnin/shared/widgets/app_page_header.dart';
import 'package:runnin/shared/widgets/app_panel.dart';
import 'package:runnin/shared/widgets/metric_card.dart';
import 'package:runnin/shared/widgets/segmented_tab_bar.dart';

enum _HealthTab { trends, zones, device, exams }

class HealthPage extends StatefulWidget {
  const HealthPage({super.key});

  @override
  State<HealthPage> createState() => _HealthPageState();
}

class _HealthPageState extends State<HealthPage> {
  _HealthTab _tab = _HealthTab.trends;

  @override
  Widget build(BuildContext context) {
    final palette = context.runninPalette;

    return Scaffold(
      backgroundColor: palette.background,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const AppPageHeader(title: 'SAÚDE'),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: SegmentedTabBar(
                tabs: const ['TENDÊNCIAS', 'ZONAS', 'DISPOSITIVO', 'EXAMES'],
                selectedIndex: _HealthTab.values.indexOf(_tab),
                onChanged: (i) => setState(() => _tab = _HealthTab.values[i]),
              ),
            ),
            const SizedBox(height: 16),
            Expanded(child: _buildTab()),
          ],
        ),
      ),
    );
  }

  Widget _buildTab() {
    return switch (_tab) {
      _HealthTab.trends => const _TrendsView(),
      _HealthTab.zones  => const _ZonesView(),
      _HealthTab.device => const _DeviceView(),
      _HealthTab.exams  => const _ExamsView(),
    };
  }
}

// ── Trends ──────────────────────────────────────────────────────────────────

class _TrendsView extends StatelessWidget {
  const _TrendsView();

  @override
  Widget build(BuildContext context) {
    final palette = context.runninPalette;
    final type = context.runninType;

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
      children: [
        Text('TENDÊNCIAS', style: type.displaySm),
        const SizedBox(height: 16),
        Row(children: [
          Expanded(child: MetricCard(label: 'BPM MÉDIO', value: '142', unit: 'bpm')),
          const SizedBox(width: 8),
          Expanded(child: MetricCard(label: 'SONO MÉDIO', value: '7.2', unit: 'h')),
          const SizedBox(width: 8),
          Expanded(child: MetricCard(label: 'RECUPERAÇÃO', value: '84', unit: '%')),
        ]),
        const SizedBox(height: 16),
        AppPanel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Tendências de saúde disponíveis após mais corridas.', style: type.bodyMd),
              const SizedBox(height: 8),
              Text(
                'Conecte um wearable para acompanhar BPM, qualidade do sono e nível de recuperação ao longo do tempo.',
                style: type.bodySm.copyWith(color: palette.muted),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ── Zones ────────────────────────────────────────────────────────────────────

class _ZonesView extends StatelessWidget {
  const _ZonesView();

  @override
  Widget build(BuildContext context) {
    final palette = context.runninPalette;
    final type = context.runninType;

    const zones = [
      _ZoneInfo(label: 'Z1 — Muito Leve', bpm: '< 120', desc: 'Aquecimento, recuperação ativa. Conversa fluente.', color: Color(0xFF4CAF50)),
      _ZoneInfo(label: 'Z2 — Leve', bpm: '120–139', desc: 'Resistência aeróbica base. Conversa possível.', color: Color(0xFF8BC34A)),
      _ZoneInfo(label: 'Z3 — Moderado', bpm: '140–159', desc: 'Ritmo de treino. Frases curtas.', color: Color(0xFFFFC107)),
      _ZoneInfo(label: 'Z4 — Intenso', bpm: '160–179', desc: 'Limiar anaeróbico. Respiração pesada.', color: Color(0xFFFF9800)),
      _ZoneInfo(label: 'Z5 — Máximo', bpm: '≥ 180', desc: 'Esforço máximo. Poucos segundos.', color: Color(0xFFF44336)),
    ];

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
      children: [
        Text('ZONAS CARDÍACAS', style: type.displaySm),
        const SizedBox(height: 16),
        ...zones.map((z) => Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: z.color.withValues(alpha: 0.08),
              border: Border.all(color: z.color.withValues(alpha: 0.3)),
              borderLeft: BorderSide(color: z.color, width: 3),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(z.label, style: type.labelMd),
                      const SizedBox(height: 4),
                      Text(z.desc, style: type.bodySm.copyWith(color: palette.muted)),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Text(z.bpm, style: type.dataMd.copyWith(color: z.color)),
              ],
            ),
          ),
        )),
      ],
    );
  }
}

class _ZoneInfo {
  final String label;
  final String bpm;
  final String desc;
  final Color color;
  const _ZoneInfo({required this.label, required this.bpm, required this.desc, required this.color});
}

// ── Device ───────────────────────────────────────────────────────────────────

class _DeviceView extends StatelessWidget {
  const _DeviceView();

  @override
  Widget build(BuildContext context) {
    final palette = context.runninPalette;
    final type = context.runninType;

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
      children: [
        Text('DISPOSITIVO', style: type.displaySm),
        const SizedBox(height: 16),
        AppPanel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.watch_outlined, color: palette.muted, size: 32),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Nenhum wearable conectado', style: type.labelMd),
                        const SizedBox(height: 4),
                        Text(
                          'Conecte seu Garmin, Apple Watch ou outro dispositivo compatível para dados de saúde em tempo real.',
                          style: type.bodySm.copyWith(color: palette.muted),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Conexão de dispositivo disponível em breve.')),
                    );
                  },
                  child: const Text('CONECTAR WEARABLE'),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        AppPanel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Health Connect (Android)', style: type.labelMd),
              const SizedBox(height: 4),
              Text(
                'Na próxima fase, o app integrará com Health Connect / HealthKit para importar dados de saúde automaticamente.',
                style: type.bodySm.copyWith(color: palette.muted),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ── Exams ────────────────────────────────────────────────────────────────────

class _ExamsView extends StatelessWidget {
  const _ExamsView();

  @override
  Widget build(BuildContext context) {
    final palette = context.runninPalette;
    final type = context.runninType;

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
      children: [
        Text('EXAMES', style: type.displaySm),
        const SizedBox(height: 16),
        AppPanel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.upload_file_outlined, color: palette.muted, size: 32),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Nenhum exame cadastrado', style: type.labelMd),
                        const SizedBox(height: 4),
                        Text(
                          'Faça upload de exames (sangue, ergoespirometria, bioimpedância) para receber análise do Coach.',
                          style: type.bodySm.copyWith(color: palette.muted),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Upload de exames disponível em breve.')),
                    );
                  },
                  icon: const Icon(Icons.add, size: 16),
                  label: const Text('ADICIONAR EXAME'),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
