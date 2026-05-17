import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:runnin/core/network/api_client.dart';
import 'package:runnin/core/theme/design_system_tokens.dart';
import 'package:runnin/shared/widgets/figma/figma_selection_button.dart';
import 'package:runnin/shared/widgets/figma/figma_top_nav.dart';
import 'package:runnin/shared/widgets/section_heading.dart';

class NotificationsSettingsPage extends StatefulWidget {
  const NotificationsSettingsPage({super.key});

  @override
  State<NotificationsSettingsPage> createState() =>
      _NotificationsSettingsPageState();
}

class _NotificationsSettingsPageState extends State<NotificationsSettingsPage> {
  bool _saving = false;
  final Map<String, dynamic> _notificationPreferences = {
    'notificationsEnabled': {
      'push': true,
      'in_app_banner': true,
      'email': false,
    },
    'dndWindow': {
      'start': '22:00',
      'end': '06:30',
    },
  };
  bool _pushEnabled = true;
  bool _inAppBannerEnabled = true;

  final Map<String, bool> _dailyNotificationTypes = {
    'melhor_horario': true,
    'preparo_nutricional': true,
    'hidratacao': true,
    'checklist_pre_run': true,
    'sono_performance': true,
    'bpm_real': true,
    'fechamento_mensal': true,
  };

  final List<Map<String, String>> _channels = [
    {'type': 'push', 'label': 'Push'},
    {'type': 'in_app', 'label': 'In-App Banner'},
    {'type': 'email', 'label': 'E-mail'},
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

  bool _dndEnabled = false;

  String _dndStart = '22:00';
  String _dndEnd = '06:30';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: FigmaColors.bgBase,
      body: Column(
        children: [
          const FigmaTopNav(
            breadcrumb: 'Perfil / Ajustes / Alertas',
            showBackButton: true,
          ),
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
                        _notificationPreferences['notificationsEnabled'] = {
                          'push': _pushEnabled,
                          'in_app_banner': _inAppBannerEnabled,
                        };
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
                    notificationPreferences: _notificationPreferences,
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
          const SnackBar(
            content: Text('Preferências salvas com sucesso.'),
            backgroundColor: FigmaColors.brandCyan,
          ),
        );
        context.pop();
      }
    } on DioException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao salvar: ${e.message}'),
            backgroundColor: FigmaColors.brandOrange,
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
          _ChannelToggle(
            type: channel['type']!,
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

class _ChannelToggle extends StatefulWidget {
  final String type;
  final String label;
  final bool enabled;
  final Function(bool) onToggle;

  const _ChannelToggle({
    required this.type,
    required this.label,
    required this.enabled,
    required this.onToggle,
  });

  @override
  State<_ChannelToggle> createState() => _ChannelToggleState();
}

class _ChannelToggleState extends State<_ChannelToggle> {
  late bool _enabled;

  @override
  void initState() {
    super.initState();
    _enabled = widget.enabled;
  }

  @override
  Widget build(BuildContext context) {
    return FigmaSelectionButton(
      label: widget.label,
      selected: _enabled,
      onTap: () {
        setState(() => _enabled = !_enabled);
        widget.onToggle(_enabled);
      },
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
        ...notificationTypes.map((type) => _DailyNotificationToggle(
              keyId: type['key']!,
              label: type['label']!,
              enabled: dailyNotificationTypes[type['key']] ?? true,
              onToggle: (enabled) => onToggleType(type['key']!, enabled),
            )),
      ],
    );
  }
}

class _DailyNotificationToggle extends StatefulWidget {
  final String keyId;
  final String label;
  final bool enabled;
  final Function(bool) onToggle;

  const _DailyNotificationToggle({
    required this.keyId,
    required this.label,
    required this.enabled,
    required this.onToggle,
  });

  @override
  State<_DailyNotificationToggle> createState() =>
      _DailyNotificationToggleState();
}

class _DailyNotificationToggleState extends State<_DailyNotificationToggle> {
  late bool _enabled;

  @override
  void initState() {
    super.initState();
    _enabled = widget.enabled;
  }

  @override
  Widget build(BuildContext context) {
    return FigmaSelectionButton(
      label: widget.label,
      selected: _enabled,
      onTap: () {
        setState(() => _enabled = !_enabled);
        widget.onToggle(_enabled);
      },
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
  late TimeOfDay _startTime;
  late TimeOfDay _endTime;

  @override
  void initState() {
    super.initState();
    _dndEnabled = widget.dndEnabled;
    _startTime = TimeOfDay(hour: 22, minute: 0);
    _endTime = TimeOfDay(hour: 6, minute: 30);
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
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'Início',
                        style: GoogleFonts.jetBrainsMono(
                          fontSize: 8,
                          fontWeight: FontWeight.w500,
                          color: FigmaColors.textMuted,
                        ),
                      ),
                      const SizedBox(height: 4),
                      TextButton(
                        onPressed: () async {
                          final time = await showTimePicker(
                            context: context,
                            initialTime: _startTime,
                          );
                          if (time != null) {
                            setState(() {
                              _startTime = time;
                              widget.onSelectStartTime(time);
                            });
                          }
                        },
                        style: TextButton.styleFrom(
                          padding: EdgeInsets.zero,
                          
                        ),
                        child: Text(
                          widget.dndStart,
                          style: GoogleFonts.jetBrainsMono(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                            color: FigmaColors.textPrimary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'Fim',
                        style: GoogleFonts.jetBrainsMono(
                          fontSize: 8,
                          fontWeight: FontWeight.w500,
                          color: FigmaColors.textMuted,
                        ),
                      ),
                      const SizedBox(height: 4),
                      TextButton(
                        onPressed: () async {
                          final time = await showTimePicker(
                            context: context,
                            initialTime: _endTime,
                          );
                          if (time != null) {
                            setState(() {
                              _endTime = time;
                              widget.onSelectEndTime(time);
                            });
                          }
                        },
                        style: TextButton.styleFrom(
                          padding: EdgeInsets.zero,
                          
                        ),
                        child: Text(
                          widget.dndEnd,
                          style: GoogleFonts.jetBrainsMono(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                            color: FigmaColors.textPrimary,
                          ),
                        ),
                      ),
                    ],
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
  final Map<String, dynamic> notificationPreferences;
  final VoidCallback onSave;

  const _SaveButton({
    required this.saving,
    required this.notificationPreferences,
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
          backgroundColor: FigmaColors.brandCyan,
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
                style: GoogleFonts.jetBrainsMono(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                      letterSpacing:
                          AppDimensions.borderUniversal - 0.2,
                ),
              ),
      ),
    );
  }
}
