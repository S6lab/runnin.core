import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:runnin/core/theme/app_palette.dart';
import 'package:runnin/features/training/data/plan_revision_remote_datasource.dart';
import 'package:runnin/shared/widgets/figma/figma_top_nav.dart';
import 'package:runnin/shared/widgets/app_panel.dart';
import 'package:runnin/shared/widgets/figma/figma_wizard_choice_card.dart';
import 'package:runnin/shared/widgets/figma/figma_coach_ai_block.dart';

enum _Step { choice, drillDown, confirm, postApply }

class RevisionFlowPage extends StatefulWidget {
  final String planId;
  const RevisionFlowPage({super.key, required this.planId});

  @override
  State<RevisionFlowPage> createState() => _RevisionFlowPageState();
}

class _RevisionFlowPageState extends State<RevisionFlowPage> {
  final _ds = PlanRevisionRemoteDatasource();
  _Step _step = _Step.choice;
  String? _selectedType;
  String? _selectedSubOption;
  String? _coachExplanation;
  bool _submitting = false;
  String? _error;

  static const _choices = [
    _ChoiceOption(type: 'more_load', icon: '↑', title: 'Mais carga', subtitle: 'Volume ou intensidade'),
    _ChoiceOption(type: 'less_load', icon: '↓', title: 'Menos carga', subtitle: 'Reduzir esforço'),
    _ChoiceOption(type: 'more_days', icon: '+', title: 'Mais dias', subtitle: 'Adicionar sessões'),
    _ChoiceOption(type: 'less_days', icon: '−', title: 'Menos dias', subtitle: 'Menos frequência'),
    _ChoiceOption(type: 'more_tempo', icon: '⚡', title: 'Mais tempo runs', subtitle: 'Ritmo sustentado'),
    _ChoiceOption(type: 'more_resistance', icon: '🌀', title: 'Mais resistência', subtitle: 'Long runs'),
    _ChoiceOption(type: 'more_intervals', icon: '📊', title: 'Mais intervalados', subtitle: 'Velocidade'),
    _ChoiceOption(type: 'change_days', icon: '📅', title: 'Mudar dias', subtitle: 'Reorganizar semana'),
    _ChoiceOption(type: 'pain_or_discomfort', icon: '⚠️', title: 'Dor/Desconforto', subtitle: 'Reduzir carga'),
    _ChoiceOption(type: 'other', icon: '⋯', title: 'Outro', subtitle: 'Texto livre'),
  ];

  static const _subOptions = {
    'more_load': ['+5km/semana', '+10km/semana', 'Mais intensidade', 'Volume + intensidade'],
    'less_load': ['-5km/semana', 'Reduzir intensidade', 'Mais descanso'],
    'more_days': ['+1 dia', '+2 dias'],
    'less_days': ['-1 dia', '-2 dias'],
    'more_tempo': ['1 tempo run', '2 tempos por semana'],
    'more_resistance': ['+1 long run', 'Aumentar long run'],
    'more_intervals': ['400m', '800m', '1km repeats'],
    'change_days': ['Editar manualmente'],
    'pain_or_discomfort': ['Reduzir volume 50%', 'Pausar 1 semana'],
    'other': <String>[],
  };

  String _typeLabel(String type) {
    return _choices.firstWhere((c) => c.type == type, orElse: () => _choices.last).title;
  }

  Future<void> _submit() async {
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      final response = await _ds.requestRevision(
        widget.planId,
        type: _selectedType!,
        subOption: _selectedSubOption,
      );
      if (!mounted) return;
      setState(() {
        _coachExplanation = response.revision.coachExplanation;
        _step = _Step.postApply;
        _submitting = false;
      });
    } on DioException catch (e) {
      if (!mounted) return;
      final statusCode = e.response?.statusCode;
      final msg = statusCode == 429
          ? 'Quota esgotada. Tente novamente na próxima semana.'
          : 'Erro ao solicitar alteração.';
      setState(() {
        _error = msg;
        _submitting = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'Erro ao solicitar alteração.';
        _submitting = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.runninPalette;

    return Scaffold(
      backgroundColor: palette.background,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const FigmaTopNav(
                breadcrumb: 'Treino / Solicitar alteração',
                showBackButton: true,
              ),
              const SizedBox(height: 20),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: switch (_step) {
                  _Step.choice => _buildChoiceScreen(palette),
                  _Step.drillDown => _buildDrillDownScreen(palette),
                  _Step.confirm => _buildConfirmScreen(palette),
                  _Step.postApply => _buildPostApplyScreen(palette),
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildChoiceScreen(RunninPalette palette) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'O que você quer mudar?',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w900,
            color: palette.text,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Baseado no seu relatório semanal e dados clínicos',
          style: TextStyle(color: palette.muted, height: 1.4),
        ),
        const SizedBox(height: 20),
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 8,
          crossAxisSpacing: 8,
          childAspectRatio: 1.6,
          children: _choices.map((choice) {
            final selected = _selectedType == choice.type;
            return FigmaWizardChoiceCard(
              iconLabel: choice.icon,
              title: choice.title,
              subtitle: choice.subtitle,
              selected: selected,
              onTap: () => setState(() => _selectedType = choice.type),
            );
          }).toList(),
        ),
        const SizedBox(height: 16),
        if (_selectedType != null) ...[
          AppPanel(
            borderColor: palette.primary.withValues(alpha: 0.4),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    '1 ALTERAÇÃO SELECIONADA',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: palette.primary,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              onPressed: () {
                final subs = _subOptions[_selectedType] ?? [];
                if (subs.isEmpty) {
                  _selectedSubOption = null;
                  setState(() => _step = _Step.confirm);
                  _submit();
                } else {
                  setState(() => _step = _Step.drillDown);
                }
              },
              child: const Text('CONVERSAR COM COACH ↗'),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildDrillDownScreen(RunninPalette palette) {
    final subs = _subOptions[_selectedType] ?? [];
    final typeLabel = _typeLabel(_selectedType!);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'SESSÃO DE AJUSTE · $typeLabel',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.08,
            color: palette.muted,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          '✓ Exames integrados · Limites clínicos ativos',
          style: TextStyle(color: palette.primary, fontSize: 12),
        ),
        const SizedBox(height: 20),
        AppPanel(
          borderColor: palette.primary.withValues(alpha: 0.5),
          child: Text(
            'Quero: $typeLabel',
            style: TextStyle(color: palette.text, fontWeight: FontWeight.w600),
          ),
        ),
        const SizedBox(height: 12),
        FigmaCoachAIBlock(
          variant: CoachAIBlockVariant.appGeneral,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Qual ajuste específico?',
                style: TextStyle(
                  color: palette.text,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 12),
              ...subs.map((sub) {
                final selected = _selectedSubOption == sub;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: FigmaQuickReplyButton(
                    label: sub,
                    selected: selected,
                    onTap: () {
                      setState(() {
                        _selectedSubOption = sub;
                        _step = _Step.confirm;
                      });
                      _submit();
                    },
                  ),
                );
              }),
            ],
          ),
        ),
        const SizedBox(height: 16),
        TextButton(
          onPressed: () => setState(() => _step = _Step.choice),
          child: Text('← Voltar', style: TextStyle(color: palette.muted)),
        ),
      ],
    );
  }

  Widget _buildConfirmScreen(RunninPalette palette) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppPanel(
          borderColor: palette.primary.withValues(alpha: 0.5),
          child: Text(
            _selectedSubOption ?? _typeLabel(_selectedType!),
            style: TextStyle(color: palette.text, fontWeight: FontWeight.w600),
          ),
        ),
        const SizedBox(height: 12),
        if (_submitting)
          Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: CircularProgressIndicator(
                color: palette.primary,
                strokeWidth: 2,
              ),
            ),
          )
        else if (_error != null) ...[
          FigmaCoachAIBlock(
            variant: CoachAIBlockVariant.appGeneral,
            child: Text(
              _error!,
              style: TextStyle(color: palette.text, height: 1.5),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => setState(() {
                    _step = _Step.choice;
                    _error = null;
                  }),
                  child: const Text('Voltar'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: _submit,
                  child: const Text('Tentar novamente'),
                ),
              ),
            ],
          ),
        ] else if (_coachExplanation != null) ...[
          FigmaCoachAIBlock(
            variant: CoachAIBlockVariant.appGeneral,
            child: Text(
              _coachExplanation!,
              style: TextStyle(color: palette.text, height: 1.5),
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              onPressed: () => setState(() => _step = _Step.postApply),
              child: const Text('Confirmar alteração'),
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: OutlinedButton(
              onPressed: () => setState(() {
                _step = _Step.choice;
                _selectedType = null;
                _selectedSubOption = null;
                _coachExplanation = null;
              }),
              child: const Text('Cancelar'),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildPostApplyScreen(RunninPalette palette) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 32),
        Center(
          child: Icon(
            Icons.check_circle_outline,
            size: 64,
            color: palette.primary,
          ),
        ),
        const SizedBox(height: 20),
        Center(
          child: Text(
            'Plano recalculado!',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w900,
              color: palette.text,
            ),
          ),
        ),
        const SizedBox(height: 8),
        Center(
          child: Text(
            'As mudanças entram em vigor a partir da próxima sessão.',
            textAlign: TextAlign.center,
            style: TextStyle(color: palette.muted, height: 1.5),
          ),
        ),
        const SizedBox(height: 32),
        SizedBox(
          width: double.infinity,
          height: 48,
          child: ElevatedButton(
            onPressed: () => context.go('/training'),
            child: const Text('VER PLANO ATUALIZADO ↗'),
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          width: double.infinity,
          height: 48,
          child: OutlinedButton(
            onPressed: () => context.go('/home'),
            child: const Text('HOME'),
          ),
        ),
      ],
    );
  }
}

class _ChoiceOption {
  final String type;
  final String icon;
  final String title;
  final String subtitle;

  const _ChoiceOption({
    required this.type,
    required this.icon,
    required this.title,
    required this.subtitle,
  });
}
