import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:runnin/core/network/api_client.dart';
import 'package:runnin/core/theme/app_palette.dart';
import 'package:runnin/core/theme/design_system_tokens.dart';
import 'package:runnin/features/auth/data/user_remote_datasource.dart';
import 'package:runnin/shared/widgets/figma/figma_selection_button.dart';
import 'package:runnin/shared/widgets/figma/figma_top_nav.dart';
import 'package:runnin/shared/widgets/settings_toggle.dart';
import 'package:runnin/shared/widgets/time_picker_button.dart';
import 'package:runnin/shared/widgets/section_heading.dart';

class NotificationsSettingsPage extends StatefulWidget {
  const NotificationsSettingsPage({super.key});

  @override
  State<NotificationsSettingsPage> createState() =>
      _NotificationsSettingsPageState();
}

class _NotificationsSettingsPageState extends State<NotificationsSettingsPage> {
  bool _saving = false;
  bool _loading = true;

  bool _pushEnabled = true;
  bool _inAppBannerEnabled = true;

  Map<String, bool> _dailyNotificationTypes = {
    'melhor_horario': true,
    'preparo_nutricional': true,
    'hidratacao': true,
    'checklist_pre_run': true,
    'sono_performance': true,
    'bpm_real': true,
    'fechamento_mensal': true,
  };

  bool _dndEnabled = false;
  String _dndStart = '22:00';
  String _dndEnd = '06:30';

  final _datasource = UserRemoteDatasource();

  @override
  void initState() {
    super.initState();
    _loadFromBackend();
  }

  Future<void> _loadFromBackend() async {
    try {
      final profile = await _datasource.getMe();
      if (profile == null || !mounted) return;
      final notif = profile.notificationsEnabled;
      final dnd = profile.dndWindow;
      setState(() {
        if (notif != null) {
          _pushEnabled = notif['push'] ?? true;
          _inAppBannerEnabled = notif['in_app_banner'] ?? true;
          _dailyNotificationTypes = {
            for (final k in _dailyNotificationTypes.keys)
              k: notif[k] ?? true,
          };
        }
        if (dnd != null) {
          _dndEnabled = true;
          _dndStart = dnd['start'] ?? '22:00';
          _dndEnd = dnd['end'] ?? '06:30';
        }
      });
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  final List<Map<String, String>> _channels = [
    {'type': 'push', 'label': 'Push'},
    {'type': 'in_app', 'label': 'In-App Banner'},
  ];

  final List<Map<String, String>> _notificationTypes = [
    {'key': 'melhor_horario', 'label': 'Melhor Horário'},
    {'key': 'preparo_nutricional', 'label': 'Preparo Nutricional'},
    {'key': 'hidratacao', 'label': 'Hidratação'},
    {'key': 'checklist_pre_run', 'label': 'Checklist Pré-Run'},
    {'key': 'sono_performance', 'label': 'Sono & Performance'},
    {'key': 'bpm_real', 'label': 'BPM Real'},
    {'key': 'fechamento_mensal', 'label': 'Fechamento Mensal'},
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: FigmaColors.bgBase,
      body: Column(
        children: [
          const FigmaTopNav(
            breadcrumb: 'ALERTAS',
            showBackButton: true,
          ),
          if (_loading)
            Expanded(
              child: Center(
                child: CircularProgressIndicator(
                  color: context.runninPalette.primary,
                ),
              ),
            )
          else
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _Section1(
                    channels: _channels,
                    notificationTypes: _notificationTypes,
                    pushEnabled: _pushEnabled,
                    inAppBannerEnabled: _inAppBannerEnabled,
                    onToggleChannel: (type, enabled) {
                      setState(() {
                        if (type == 'push') _pushEnabled = enabled;
                        if (type == 'in_app') _inAppBannerEnabled = enabled;
                      });
                    },
                  ),
                  const SizedBox(height: AppSpacing.xxl),
                  _Section2(
                    notificationTypes: _notificationTypes,
                    dailyNotificationTypes: _dailyNotificationTypes,
                    onToggleType: (key, enabled) {
                      setState(() {
                        _dailyNotificationTypes[key] = enabled;
                      });
                    },
                  ),
                  const SizedBox(height: AppSpacing.xxl),
                   _Section3(
                     dndStart: _dndStart,
                     dndEnd: _dndEnd,
                     dndEnabled: _dndEnabled,
                     onToggle: (enabled) {
                       setState(() => _dndEnabled = enabled);
                     },
                     onSelectStartTime: (time) {
                       setState(() => _dndStart = _formatTimeOfDay(time));
                     },
                     onSelectEndTime: (time) {
                       setState(() => _dndEnd = _formatTimeOfDay(time));
                     },
                   ),
                  const SizedBox(height: AppSpacing.xl),
                  _SaveButton(
                    saving: _saving,
                    onSave: () => _save(),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatTimeOfDay(TimeOfDay time) {
    final hour = time.hour.toString().padLeft(2, '0');
    final minute = time.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  void _save() async {
    setState(() => _saving = true);
    try {
      await apiClient.patch('/users/me', data: {
        'notificationsEnabled': {
          'push': _pushEnabled,
          'in_app_banner': _inAppBannerEnabled,
          ..._dailyNotificationTypes,
        },
        if (_dndEnabled)
          'dndWindow': {'start': _dndStart, 'end': _dndEnd},
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Preferências salvas com sucesso.'),
            backgroundColor: context.runninPalette.primary,
          ),
        );
        context.pop();
      }
    } on DioException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao salvar: ${e.message}'),
            backgroundColor: context.runninPalette.secondary,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}

class _Section1 extends StatelessWidget {
  final List<Map<String, String>> channels;
  final List<Map<String, String>> notificationTypes;
  final bool pushEnabled;
  final bool inAppBannerEnabled;
  final Function(String, bool) onToggleChannel;

  const _Section1({
    required this.channels,
    required this.notificationTypes,
    required this.pushEnabled,
    required this.inAppBannerEnabled,
    required this.onToggleChannel,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionHeading(label: 'CANAIS ATIVOS'),
        const SizedBox(height: AppSpacing.md),
        for (final channel in channels) ...[
          SettingsToggle(
            id: channel['type']!,
            label: channel['label']!,
            enabled: channel['type'] == 'push'
                ? pushEnabled
                : inAppBannerEnabled,
            onToggle: (enabled) => onToggleChannel(channel['type']!, enabled),
          ),
          const SizedBox(height: AppSpacing.sm),
        ],
      ],
    );
  }
}

class _Section2 extends StatelessWidget {
  final List<Map<String, String>> notificationTypes;
  final Map<String, bool> dailyNotificationTypes;
  final Function(String, bool) onToggleType;

  const _Section2({
    required this.notificationTypes,
    required this.dailyNotificationTypes,
    required this.onToggleType,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionHeading(label: 'TIPOS DE NOTIFICAÇÃO DIÁRIA'),
        const SizedBox(height: AppSpacing.md),
        ...notificationTypes.map((type) => SettingsToggle(
              id: type['key']!,
              label: type['label']!,
              enabled: dailyNotificationTypes[type['key']] ?? true,
              onToggle: (enabled) => onToggleType(type['key']!, enabled),
            )),
      ],
    );
  }
}

class _Section3 extends StatefulWidget {
  final String dndStart;
  final String dndEnd;
  final bool dndEnabled;
  final Function(bool) onToggle;
  final Function(TimeOfDay) onSelectStartTime;
  final Function(TimeOfDay) onSelectEndTime;

  const _Section3({
    required this.dndStart,
    required this.dndEnd,
    required this.dndEnabled,
    required this.onToggle,
    required this.onSelectStartTime,
    required this.onSelectEndTime,
  });

  @override
  State<_Section3> createState() => _Section3State();
}

class _Section3State extends State<_Section3> {
  late bool _dndEnabled;

  @override
  void initState() {
    super.initState();
    _dndEnabled = widget.dndEnabled;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionHeading(label: 'JANELA DE SILÊNCIO (DND)'),
        const SizedBox(height: AppSpacing.md),
        FigmaSelectionButton(
          label: _dndEnabled ? 'Ativo' : 'Inativo',
          selected: _dndEnabled,
          onTap: () {
            setState(() => _dndEnabled = !_dndEnabled);
            widget.onToggle(_dndEnabled);
          },
        ),
        const SizedBox(height: AppSpacing.sm),
        if (_dndEnabled) ...[
          Container(
            height: 58.73,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: FigmaColors.surfaceInput,
              border: Border.all(color: FigmaColors.borderInput),
            ),
            child: Row(
              children: [
                Expanded(
                  child: TimePickerButton(
                    label: 'Início',
                    displayValue: widget.dndStart,
                    initialTime: const TimeOfDay(hour: 22, minute: 0),
                    onTimeSelected: widget.onSelectStartTime,
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: TimePickerButton(
                    label: 'Fim',
                    displayValue: widget.dndEnd,
                    initialTime: const TimeOfDay(hour: 6, minute: 30),
                    onTimeSelected: widget.onSelectEndTime,
                  ),
                ),
              ],
            ),
          ),
        ] else
          const SizedBox(height: 58.73),
      ],
    );
  }
}

class _SaveButton extends StatelessWidget {
  final bool saving;
  final VoidCallback onSave;

  const _SaveButton({
    required this.saving,
    required this.onSave,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 54.71,
      child: ElevatedButton(
        onPressed: saving ? null : onSave,
        style: ElevatedButton.styleFrom(
          backgroundColor: context.runninPalette.primary,
          foregroundColor: FigmaColors.bgBase,
          shape: const RoundedRectangleBorder(
            borderRadius: FigmaBorderRadius.zero,
          ),
        ),
        child: saving
            ? SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                      valueColor:
                          AlwaysStoppedAnimation(FigmaColors.bgBase),
                ),
              )
            : Text(
                'SALVAR',
                style: context.runninType.dataSm.copyWith(
                  letterSpacing:
                      AppDimensions.borderUniversal - 0.2,
                ),
              ),
      ),
    );
  }
}
