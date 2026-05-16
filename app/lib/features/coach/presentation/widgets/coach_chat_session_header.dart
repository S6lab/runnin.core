import 'package:flutter/material.dart';
import 'package:runnin/core/presentation/widgets/app_panel.dart';
import 'package:runnin/core/presentation/widgets/app_tag.dart';
import 'package:runnin/features/coach/domain/entities/chat_message.dart';
import 'package:runnin/core/utils/extensions/context_extensions.dart';
import '../cubit/coach_chat_cubit.dart';

class CoachChatSessionHeader extends StatelessWidget {
  final CoachChatState state;
  final List<QuickPrompt> prompts;
  final ValueChanged<String> onFillPrompt;
  final ValueChanged<String> onSendPrompt;

  const CoachChatSessionHeader({
    super.key,
    required this.state,
    required this.prompts,
    required this.onFillPrompt,
    required this.onSendPrompt,
  });

  @override
  Widget build(BuildContext context) {
    final palette = context.runninPalette;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppPanel(
          color: palette.surfaceAlt,
          borderColor: palette.primary.withValues(alpha: 0.35),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'BRIEF DA SEMANA',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w900,
                            letterSpacing: -0.02,
                          ),
                    ),
                  ),
                  AppTag(label: 'REVISAO 01', color: palette.primary),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'Estou acompanhando seu plano. Me chama para ajustar volume, ritmo, recuperação ou a estratégia da próxima corrida.',
                style: TextStyle(
                  color: palette.text.withValues(alpha: 0.8),
                  height: 1.45,
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: _CoachMetric(
                      label: 'STATUS',
                      value: 'ATIVO',
                      accent: palette.primary,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                        child: _CoachMetric(
                          label: 'MENSAGENS',
                          value: '${state.messages.length}',
                          accent: palette.secondary,
                        ),
                      ),
                  const SizedBox(width: 8),
                  Expanded(
                        child: _CoachMetric(
                          label: 'FOCO',
                          value: 'PACE',
                          accent: palette.text,
                        ),
                      ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        _QuickPromptRail(
          prompts: prompts,
          onFillPrompt: onFillPrompt,
          onSendPrompt: onSendPrompt,
        ),
        const SizedBox(height: 12),
        CoachChatInsights(),
      ],
    );
  }
}

class _CoachMetric extends StatelessWidget {
  final String label;
  final String value;
  final Color accent;

  const _CoachMetric({
    required this.label,
    required this.value,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    final palette = context.runninPalette;

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
            label,
            style: TextStyle(
              color: palette.muted,
              fontSize: 9,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.08,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              color: accent,
              fontSize: 20,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _QuickPromptRail extends StatelessWidget {
  final List<QuickPrompt> prompts;
  final ValueChanged<String> onFillPrompt;
  final ValueChanged<String> onSendPrompt;

  const _QuickPromptRail({
    required this.prompts,
    required this.onFillPrompt,
    required this.onSendPrompt,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _MiniSectionTitle(
          title: 'ATALHOS',
          subtitle: 'Prompts guiados para acelerar ajustes.',
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 116,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: prompts.length,
            separatorBuilder: (context, index) => const SizedBox(width: 8),
            itemBuilder: (context, index) {
              final prompt = prompts[index];
              return _PromptCard(
                prompt: prompt,
                onFill: () => onFillPrompt(prompt.prompt),
                onSend: () => onSendPrompt(prompt.prompt),
              };
            },
          ),
        ),
      ],
    );
  }
}

class _PromptCard extends StatelessWidget {
  final QuickPrompt prompt;
  final VoidCallback onFill;
  final VoidCallback onSend;

  const _PromptCard({
    required this.prompt,
    required this.onFill,
    required this.onSend,
  });

  @override
  Widget build(BuildContext context) {
    final palette = context.runninPalette;

    return SizedBox(
      width: 188,
      child: AppPanel(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AppTag(label: 'SUGESTAO', color: palette.secondary),
            const SizedBox(height: 10),
            Text(
              prompt.title.toUpperCase(),
              style: TextStyle(
                color: palette.text,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.02,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              prompt.prompt,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: palette.muted,
                fontSize: 12,
                height: 1.35,
              ),
            ),
            const Spacer(),
            Row(
              children: [
                Expanded(
                  child: InkWell(
                    onTap: onFill,
                    child: Text(
                      'EDITAR',
                      style: TextStyle(
                        color: palette.muted,
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
                InkWell(
                  onTap: onSend,
                  child: Text(
                        'ENVIAR',
                        style: TextStyle(
                          color: palette.primary,
                          fontSize: 11,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class CoachChatInsights extends StatelessWidget {
  const CoachChatInsights({super.key});

  @override
  Widget build(BuildContext context) {
    final palette = context.runninPalette;

    const insights = [
      _CoachInsight(
        title: 'Recuperacao',
        body:
            'Semana pede equilibrio entre volume e descanso para preservar consistencia.',
      ),
      _CoachInsight(
        title: 'Ritmo alvo',
        body:
            'Treinos de qualidade devem priorizar controle de pace, nao agressividade.',
      ),
      _CoachInsight(
        title: 'Wearable',
        body:
            'Quando a integracao estiver pronta, o coach podera ajustar pelo sono e FC.',
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _MiniSectionTitle(
          title: 'INSIGHTS',
          subtitle: 'Resumo acionavel do que o coach esta observando.',
        ),
        const SizedBox(height: 10),
        ...insights.map(
          (insight) => AppPanel(
            margin: const EdgeInsets.only(bottom: 8),
            color: palette.surfaceAlt,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 8,
                  height: 8,
                  margin: const EdgeInsets.only(top: 6),
                  color: palette.secondary,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        insight.title.toUpperCase(),
                        style: TextStyle(
                          color: palette.text,
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.08,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        insight.body,
                        style: TextStyle(
                          color: palette.muted,
                          fontSize: 12,
                          height: 1.45,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _MiniSectionTitle extends StatelessWidget {
  final String title;
  final String subtitle;

  const _MiniSectionTitle({required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    final palette = context.runninPalette;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            color: palette.text,
            fontSize: 12,
            fontWeight: FontWeight.w900,
            letterSpacing: 0.08,
          ),
        ),
        const SizedBox(height: 4),
        Text(subtitle, style: TextStyle(color: palette.muted, fontSize: 12)),
      ],
    );
  }
}

class QuickPrompt {
  final String title;
  final String prompt;

  const QuickPrompt({required this.title, required this.prompt});
}

class _CoachInsight {
  final String title;
  final String body;

  const _CoachInsight({required this.title, required this.body});
}
