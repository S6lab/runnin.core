import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:runnin/core/theme/app_palette.dart';
import 'package:runnin/features/wearable/data/providers/wearable_providers.dart';
import 'package:runnin/shared/widgets/app_page_header.dart';
import 'package:runnin/shared/widgets/app_panel.dart';
import 'package:runnin/shared/widgets/metric_card.dart';
import 'package:runnin/shared/widgets/segmented_tab_bar.dart';

enum _HealthTab { trends, zones, device, exams }

class HealthPage extends ConsumerStatefulWidget {
  const HealthPage({super.key});

  @override
  ConsumerState<HealthPage> createState() => _HealthPageState();
}

class _HealthPageState extends ConsumerState<HealthPage> {
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

class _TrendsView extends ConsumerWidget {
  const _TrendsView();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.runninPalette;
    final type = context.runninType;

    final heartRateAsync = ref.watch(recentHeartRateProvider);
    final sleepAsync = ref.watch(recentSleepProvider);
    final recoveryAsync = ref.watch(recoveryScoreProvider);
    final connectionAsync = ref.watch(wearableConnectionProvider);

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
      children: [
        Text('TENDÊNCIAS', style: type.displaySm),
        const SizedBox(height: 16),

        // Metrics Row
        connectionAsync.when(
          data: (connection) {
            if (!connection.isConnected) {
              return AppPanel(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Conecte um wearable para ver suas tendências', style: type.bodyMd),
                    const SizedBox(height: 8),
                    Text(
                      'Seus dados de saúde aparecerão aqui após conectar um dispositivo compatível.',
                      style: type.bodySm.copyWith(color: palette.muted),
                    ),
                  ],
                ),
              );
            }

            // Calculate average heart rate
            final avgHR = heartRateAsync.when(
              data: (hrData) {
                if (hrData.isEmpty) return '---';
                final avg = hrData.map((d) => d.bpm).reduce((a, b) => a + b) / hrData.length;
                return avg.round().toString();
              },
              loading: () => '---',
              error: (_, __) => '---',
            );

            // Calculate average sleep
            final avgSleep = sleepAsync.when(
              data: (sleepData) {
                if (sleepData.isEmpty) return '---';
                final avg = sleepData.map((d) => d.durationHours).reduce((a, b) => a + b) / sleepData.length;
                return avg.toStringAsFixed(1);
              },
              loading: () => '---',
              error: (_, __) => '---',
            );

            // Recovery score
            final recovery = recoveryAsync.when(
              data: (score) => score?.score.round().toString() ?? '---',
              loading: () => '---',
              error: (_, __) => '---',
            );

            return Column(
              children: [
                Row(children: [
                  Expanded(child: MetricCard(label: 'BPM MÉDIO', value: avgHR, unit: 'bpm')),
                  const SizedBox(width: 8),
                  Expanded(child: MetricCard(label: 'SONO MÉDIO', value: avgSleep, unit: 'h')),
                  const SizedBox(width: 8),
                  Expanded(child: MetricCard(label: 'RECUPERAÇÃO', value: recovery, unit: '%')),
                ]),
                const SizedBox(height: 16),
                recoveryAsync.when(
                  data: (score) {
                    if (score == null) return const SizedBox.shrink();
                    return AppPanel(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Recomendação de Recuperação', style: type.labelMd),
                          const SizedBox(height: 8),
                          Text(
                            score.recommendation ?? 'Continue treinando regularmente.',
                            style: type.bodyMd.copyWith(color: palette.muted),
                          ),
                        ],
                      ),
                    );
                  },
                  loading: () => const SizedBox.shrink(),
                  error: (_, __) => const SizedBox.shrink(),
                ),
              ],
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, __) => AppPanel(
            child: Text('Erro ao carregar dados de saúde', style: type.bodyMd),
          ),
        ),
      ],
    );
  }
}

// ── Zones ────────────────────────────────────────────────────────────────────

class _ZonesView extends ConsumerWidget {
  const _ZonesView();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.runninPalette;
    final type = context.runninType;

    final zonesAsync = ref.watch(heartRateZonesProvider);

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
      children: [
        Text('ZONAS CARDÍACAS', style: type.displaySm),
        const SizedBox(height: 16),

        zonesAsync.when(
          data: (zones) {
            if (zones == null) {
              return AppPanel(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Conecte um wearable para calcular suas zonas', style: type.bodyMd),
                    const SizedBox(height: 8),
                    Text(
                      'Suas zonas cardíacas personalizadas serão calculadas com base na sua frequência cardíaca de repouso.',
                      style: type.bodySm.copyWith(color: palette.muted),
                    ),
                  ],
                ),
              );
            }

            final zoneData = [
              _ZoneInfo(
                label: 'Z1 — Muito Leve',
                bpm: '< ${zones.zone1Max}',
                desc: 'Aquecimento, recuperação ativa. Conversa fluente.',
                color: const Color(0xFF4CAF50),
              ),
              _ZoneInfo(
                label: 'Z2 — Leve',
                bpm: '${zones.zone1Max}–${zones.zone2Max}',
                desc: 'Resistência aeróbica base. Conversa possível.',
                color: const Color(0xFF8BC34A),
              ),
              _ZoneInfo(
                label: 'Z3 — Moderado',
                bpm: '${zones.zone2Max}–${zones.zone3Max}',
                desc: 'Ritmo de treino. Frases curtas.',
                color: const Color(0xFFFFC107),
              ),
              _ZoneInfo(
                label: 'Z4 — Intenso',
                bpm: '${zones.zone3Max}–${zones.zone4Max}',
                desc: 'Limiar anaeróbico. Respiração pesada.',
                color: const Color(0xFFFF9800),
              ),
              _ZoneInfo(
                label: 'Z5 — Máximo',
                bpm: '≥ ${zones.zone4Max}',
                desc: 'Esforço máximo. Poucos segundos.',
                color: const Color(0xFFF44336),
              ),
            ];

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AppPanel(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      Column(
                        children: [
                          Text('FC Repouso', style: type.bodySm.copyWith(color: palette.muted)),
                          Text('${zones.restingHeartRate}', style: type.dataMd),
                        ],
                      ),
                      Column(
                        children: [
                          Text('FC Máxima', style: type.bodySm.copyWith(color: palette.muted)),
                          Text('${zones.maxHeartRate}', style: type.dataMd),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                ...zoneData.map((z) => Padding(
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
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, __) => AppPanel(
            child: Text('Erro ao calcular zonas cardíacas', style: type.bodyMd),
          ),
        ),
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

class _DeviceView extends ConsumerWidget {
  const _DeviceView();

  Future<void> _connectWearable(BuildContext context, WidgetRef ref) async {
    final service = ref.read(wearableServiceProvider);

    try {
      // Show loading
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Solicitando permissões...')),
        );
      }

      // Request permissions
      final granted = await service.requestPermissions();

      if (!context.mounted) return;

      if (granted) {
        // Refresh connection status
        ref.invalidate(wearableConnectionProvider);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Wearable conectado com sucesso!'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Permissões negadas. Verifique as configurações do dispositivo.'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erro ao conectar: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final palette = context.runninPalette;
    final type = context.runninType;

    final connectionAsync = ref.watch(wearableConnectionProvider);

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
      children: [
        Text('DISPOSITIVO', style: type.displaySm),
        const SizedBox(height: 16),

        connectionAsync.when(
          data: (connection) {
            final isConnected = connection.isConnected;

            return Column(
              children: [
                AppPanel(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            isConnected ? Icons.check_circle : Icons.watch_outlined,
                            color: isConnected ? Colors.green : palette.muted,
                            size: 32,
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  isConnected
                                      ? '${connection.deviceName ?? "Wearable"} Conectado'
                                      : 'Nenhum wearable conectado',
                                  style: type.labelMd,
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  isConnected
                                      ? 'Última sincronização: ${_formatLastSync(connection.lastSyncAt)}'
                                      : 'Conecte seu Garmin, Apple Watch ou outro dispositivo compatível para dados de saúde em tempo real.',
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
                        child: isConnected
                            ? OutlinedButton(
                                onPressed: () {
                                  // Reconnect/refresh
                                  ref.invalidate(wearableConnectionProvider);
                                },
                                child: const Text('ATUALIZAR CONEXÃO'),
                              )
                            : ElevatedButton(
                                onPressed: () => _connectWearable(context, ref),
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
                      Row(
                        children: [
                          Icon(Icons.info_outline, color: palette.muted, size: 20),
                          const SizedBox(width: 8),
                          Text('Dispositivos Suportados', style: type.labelMd),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        '• Apple Watch (via HealthKit)\n'
                        '• Garmin\n'
                        '• Samsung Galaxy Watch\n'
                        '• Fitbit\n'
                        '• Polar\n'
                        '• COROS\n'
                        '• Whoop\n'
                        '• E outros compatíveis com Health Connect/HealthKit',
                        style: type.bodySm.copyWith(color: palette.muted),
                      ),
                    ],
                  ),
                ),
                if (isConnected) ...[
                  const SizedBox(height: 24),
                  AppPanel(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Dados Sincronizados', style: type.labelMd),
                        const SizedBox(height: 12),
                        Text(
                          '• Frequência cardíaca em tempo real\n'
                          '• FC de repouso\n'
                          '• Variabilidade da frequência cardíaca (HRV)\n'
                          '• Dados de sono\n'
                          '• Passos e atividade diária\n'
                          '• Histórico de treinos',
                          style: type.bodySm.copyWith(color: palette.muted),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, _) => AppPanel(
            child: Text('Erro ao verificar conexão: $error', style: type.bodyMd),
          ),
        ),
      ],
    );
  }

  String _formatLastSync(DateTime? lastSync) {
    if (lastSync == null) return 'Nunca';

    final now = DateTime.now();
    final diff = now.difference(lastSync);

    if (diff.inMinutes < 1) return 'Agora mesmo';
    if (diff.inMinutes < 60) return '${diff.inMinutes} min atrás';
    if (diff.inHours < 24) return '${diff.inHours}h atrás';
    return '${diff.inDays}d atrás';
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
