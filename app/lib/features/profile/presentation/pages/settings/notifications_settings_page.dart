import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:runnin/core/network/api_client.dart';
import 'package:runnin/core/theme/design_system_tokens.dart';
import 'package:runnin/shared/widgets/figma/figma_top_nav.dart';
import 'package:runnin/shared/widgets/section_heading.dart';

class NotificationsSettingsPage extends StatefulWidget {
  const NotificationsSettingsPage({super.key});

  @override
  State<NotificationsSettingsPage> createState() =>
      _NotificationsSettingsPageState();
}

class _NotificationsSettingsPageState extends State<NotificationsSettingsPage> {
  final bool _saving = false;
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
  final bool _pushEnabled = true;
  final bool _inAppBannerEnabled = true;
  final bool _emailEnabled = false;

  final Map<String, bool> _dailyNotificationTypes = {
    'melhor_horario': true,
    'preparo_nutricional': true,
    'hidratacao': true,
    'checklist_pre_run': true,
    'sono_performance': true,
    'bpm_real': true,
    'fechamento_mensal': true,
  };

  final String _dndStart = '22:00';
  final String _dndEnd = '06:30';

  final Map<String, String> _channelStatus = {
    'push': 'Ativo',
    'in_app': 'Ativo',
    'email': 'Em breve',
  };

  final List<Map<String, String>> _channels = [
    {'type': 'push', 'label': 'Push notifications'},
    {'type': 'in_app', 'label': 'In-app banner'},
    {'type': 'email', 'label': 'Email'},
  ];

  final List<Map<String, String>> _notificationTypes = [
    {'key': 'melhor_horario', 'label': 'Melhor horário para correr'},
    {'key': 'preparo_nutricional', 'label': 'Preparo nutricional'},
    {'key': 'hidratacao', 'label': 'Hidratação'},
    {
      'key': 'checklist_pre_run',
      'label': 'Checklist pré-easy run'
    },
    {'key': 'sono_performance', 'label': 'Sono → performance'},
    {'key': 'bpm_real', 'label': 'BPM real'},
    {
      'key': 'fechamento_mensal',
      'label': 'Fechamento mensal'
    },
  ];

  bool _dndEnabled = true;

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
                  ),
                  const SizedBox(height: AppSpacing.xxl),
                  _Section2(notificationTypes: _notificationTypes),
                  const SizedBox(height: AppSpacing.xxl),
                  _Section3(
                    dndStart: _dndStart,
                    dndEnd: _dndEnd,
                    onToggle: (enabled) => setState(() => _dndEnabled = enabled),
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

  void _save() async {
    setState(() => _saving = true);
    try {
      await apiClient.patch('/users/me', data: {
        'notificationPreferences': _notificationPreferences,
      });
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Preferências salvas com sucesso.'),
            backgroundColor: FigmaColors.brandCyan,
          ),
        );
        context.pop();
      }
    } on DioException catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao salvar: ${e.message}'),
            backgroundColor: FigmaColors.brandOrange,
          ),
        );
      }
    } finally {
      if (context.mounted) setState(() => _saving = false);
    }
  }
}

class _Section1 extends StatelessWidget {
  final List<Map<String, String>> channels;
  final List<Map<String, String>> notificationTypes;

  const _Section1({
    required this.channels,
    required this.notificationTypes,
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

  const _ChannelToggle({
    required this.type,
    required this.label,
  });

  @override
  State<_ChannelToggle> createState() => _ChannelToggleState();
}

class _ChannelToggleState extends State<_ChannelToggle> {
  bool _enabled = true;

  @override
  Widget build(BuildContext context) {
    final isInApp = widget.type == 'in_app';
    final isEmail = widget.type == 'email';

    return Container(
      height: 56.5,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 17.74),
      decoration: BoxDecoration(
        color: _enabled
            ? (isInApp
                ? FigmaColors.selectionActiveBg
                : FigmaColors.surfaceCard)
            : (isInApp
                ? FigmaColors.selectionActiveBg.withValues(alpha: 0.3)
                : FigmaColors.surfaceCard),
        border: Border.all(
          color: _enabled
              ? (isInApp
                  ? FigmaColors.selectionActiveBorder
                  : FigmaColors.borderDefault)
              : (isInApp
                  ? FigmaColors.selectionActiveBorder.withValues(alpha: 0.3)
                  : FigmaColors.borderDefault),
          width: FigmaDimensions.borderUniversal,
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text(
              widget.label,
              style: GoogleFonts.jetBrainsMono(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                height: 21 / 14,
                letterSpacing: 0,
                color: _enabled
                    ? FigmaColors.textPrimary
                    : FigmaColors.textMuted,
              ),
            ),
          ),
          if (!isEmail)
            Container(
              width: 35.975,
              height: 19.98,
              decoration: BoxDecoration(
                color: _enabled
                    ? FigmaColors.brandCyan
                    : FigmaColors.textMuted,
                borderRadius: FigmaBorderRadius.togglePill,
              ),
              child: Container(
                width: 15.995,
                height: 15.995,
                margin: EdgeInsets.only(
                  left: _enabled ? 19.98 : 0,
                ),
                decoration: BoxDecoration(
                  color: FigmaColors.bgBase,
                  borderRadius: FigmaBorderRadius.togglePill,
                ),
              ),
            )
          else
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: FigmaColors.textMuted.withValues(alpha: 0.1),
                borderRadius: FigmaBorderRadius.togglePill,
                border: Border.all(
                  color: FigmaColors.textMuted.withValues(alpha: 0.3),
                ),
              ),
              child: Text(
            'Em breve',
                style: GoogleFonts.jetBrainsMono(
                  fontSize: 7,
                  fontWeight: FontWeight.w500,
                  color: FigmaColors.textMuted,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _Section2 extends StatelessWidget {
  final List<Map<String, String>> notificationTypes;

  const _Section2({
    required this.notificationTypes,
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
            )),
      ],
    );
  }
}

class _DailyNotificationToggle extends StatefulWidget {
  final String keyId;
  final String label;

  const _DailyNotificationToggle({
    required this.keyId,
    required this.label,
  });

  @override
  State<_DailyNotificationToggle> createState() =>
      _DailyNotificationToggleState();
}

class _DailyNotificationToggleState extends State<_DailyNotificationToggle> {
  bool _enabled = true;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      height: 47.5,
      padding:
          const EdgeInsets.symmetric(horizontal: 14, vertical: 17.74),
      decoration: BoxDecoration(
        color: _enabled
            ? FigmaColors.selectionActiveBg.withValues(alpha: 0.1)
            : FigmaColors.surfaceCard,
        border: Border.all(
          color: _enabled
              ? FigmaColors.selectionActiveBorder.withValues(alpha: 0.5)
              : FigmaColors.borderDefault,
          width: FigmaDimensions.borderUniversal,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 35.975,
            height: 19.98,
            decoration: BoxDecoration(
              color: _enabled
                  ? FigmaColors.brandCyan
                  : FigmaColors.textMuted,
              borderRadius: FigmaBorderRadius.togglePill,
            ),
            child: Container(
              width: 15.995,
              height: 15.995,
              margin: EdgeInsets.only(
                left: _enabled ? 19.98 : 0,
              ),
              decoration: BoxDecoration(
                color: FigmaColors.bgBase,
                borderRadius: FigmaBorderRadius.togglePill,
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Text(
              widget.label,
              style: GoogleFonts.jetBrainsMono(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                height: 21 / 14,
                letterSpacing: 0,
                color: _enabled
                    ? FigmaColors.textPrimary
                    : FigmaColors.textMuted,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Section3 extends StatefulWidget {
  final String dndStart;
  final String dndEnd;
  final Function(bool) onToggle;

  const _Section3({
    required this.dndStart,
    required this.dndEnd,
    required this.onToggle,
  });

  @override
  State<_Section3> createState() => _Section3State();
}

class _Section3State extends State<_Section3> {
  bool _dndEnabled = true;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionHeading(label: 'JANELA DE SILÊNCIO (DND)'),
        const SizedBox(height: AppSpacing.md),
        Container(
          height: 58.73,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: FigmaColors.surfaceInput,
            border:
                Border.all(color: FigmaColors.borderInput),
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
                    Text(
                      widget.dndStart,
                      style: GoogleFonts.jetBrainsMono(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: FigmaColors.textPrimary,
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
                    Text(
                      widget.dndEnd,
                      style: GoogleFonts.jetBrainsMono(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: FigmaColors.textPrimary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
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
        onPressed: saving
            ? null
            : onSave,
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
                  valueColor: AlwaysStoppedAnimation(FigmaColors.bgBase),
                ),
              )
            : Text(
                'SALVAR',
                style: GoogleFonts.jetBrainsMono(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  letterSpacing: AppDimensions.borderUniversal - 0.2,
                ),
              ),
      ),
    );
  }
}
