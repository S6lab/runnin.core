import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:runnin/core/theme/app_palette.dart';
import 'package:runnin/features/coach/domain/entities/chat_message.dart';
import 'package:runnin/features/coach/presentation/cubit/coach_chat_cubit.dart';
import 'package:runnin/shared/widgets/app_panel.dart';
import 'package:runnin/shared/widgets/app_tag.dart';
import 'package:runnin/shared/widgets/figma/figma_top_nav.dart';

class CoachChatPage extends StatelessWidget {
  const CoachChatPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => CoachChatCubit(),
      child: const _CoachChatView(),
    );
  }
}

class _CoachChatView extends StatefulWidget {
  const _CoachChatView();

  @override
  State<_CoachChatView> createState() => _CoachChatViewState();
}

class _CoachChatViewState extends State<_CoachChatView> {
  final _controller = TextEditingController();
  final _scrollController = ScrollController();

  static const _quickPrompts = [
    _QuickPrompt(
      title: 'Pace de hoje',
      prompt: 'Qual pace devo buscar no treino de hoje?',
    ),
    _QuickPrompt(
      title: 'Ajustar volume',
      prompt: 'Ajuste meu volume semanal para eu recuperar melhor.',
    ),
    _QuickPrompt(
      title: 'Dor leve',
      prompt: 'Estou com dor leve na canela. Como adapto meu treino?',
    ),
    _QuickPrompt(
      title: 'Sono ruim',
      prompt: 'Dormi mal. Vale manter o treino planejado?',
    ),
  ];

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _submit(CoachChatCubit cubit, {String? text}) {
    final message = (text ?? _controller.text).trim();
    if (message.isEmpty) return;
    _controller.clear();
    cubit.sendMessage(message);
    _scrollToBottom();
  }

  void _fillPrompt(String prompt) {
    _controller
      ..text = prompt
      ..selection = TextSelection.collapsed(offset: prompt.length);
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.runninPalette;

    return Scaffold(
      backgroundColor: palette.background,
      body: SafeArea(
        child: Column(
          children: [
            const FigmaTopNav(
              breadcrumb: 'Coach',
              showBackButton: true,
            ),
            const SizedBox(height: 20),
            Expanded(
              child: BlocConsumer<CoachChatCubit, CoachChatState>(
                listenWhen: (prev, curr) =>
                    curr.messages.length > prev.messages.length,
                listener: (context, state) => _scrollToBottom(),
                builder: (context, state) {
                  return CustomScrollView(
                    controller: _scrollController,
                    slivers: [
                      SliverPadding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        sliver: SliverList(
                          delegate: SliverChildListDelegate([
                            _CoachOverview(state: state),
                            const SizedBox(height: 12),
                            _QuickPromptRail(
                              prompts: _quickPrompts,
                              onFillPrompt: _fillPrompt,
                              onSendPrompt: (prompt) => _submit(
                                context.read<CoachChatCubit>(),
                                text: prompt,
                              ),
                            ),
                            const SizedBox(height: 12),
                            _InsightsPanel(),
                            const SizedBox(height: 16),
                            _ConversationHeader(
                              messageCount: state.messages.length,
                            ),
                            const SizedBox(height: 12),
                          ]),
                        ),
                      ),
                      SliverPadding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        sliver: SliverList.builder(
                          itemCount:
                              state.messages.length + (state.sending ? 1 : 0),
                          itemBuilder: (context, index) {
                            if (index == state.messages.length &&
                                state.sending) {
                              return const _TypingIndicator();
                            }
                            return _MessageBubble(
                              message: state.messages[index],
                            );
                          },
                        ),
                      ),
                      const SliverToBoxAdapter(child: SizedBox(height: 20)),
                    ],
                  );
                },
              ),
            ),
            BlocBuilder<CoachChatCubit, CoachChatState>(
              buildWhen: (prev, curr) =>
                  prev.premiumRequired != curr.premiumRequired,
              builder: (context, state) {
                if (!state.premiumRequired) return const SizedBox.shrink();
                return Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                  child: AppPanel(
                    color: palette.primary.withValues(alpha: 0.08),
                    borderColor: palette.primary.withValues(alpha: 0.35),
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'COACH AI É PREMIUM',
                          style: TextStyle(
                            color: palette.primary,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1.0,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Conversar com o coach AI faz parte do plano Pro. Faça o upgrade pra ter chat, plano personalizado e voz ao vivo.',
                          style: TextStyle(
                            color: palette.text.withValues(alpha: 0.85),
                            fontSize: 12,
                            height: 1.5,
                          ),
                        ),
                        const SizedBox(height: 10),
                        InkWell(
                          onTap: () => context.push('/paywall?next=/coach'),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 10,
                            ),
                            color: palette.primary,
                            child: Text(
                              'VER PLANOS  ↗',
                              style: TextStyle(
                                color: palette.background,
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 1.0,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
            BlocBuilder<CoachChatCubit, CoachChatState>(
              buildWhen: (prev, curr) => prev.error != curr.error,
              builder: (context, state) {
                if (state.error == null) return const SizedBox.shrink();
                return Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                  child: AppPanel(
                    color: palette.error.withValues(alpha: 0.08),
                    borderColor: palette.error.withValues(alpha: 0.35),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            state.error!,
                            style: TextStyle(
                              color: palette.error,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        InkWell(
                          onTap: () =>
                              context.read<CoachChatCubit>().clearError(),
                          child: Icon(
                            Icons.close,
                            size: 14,
                            color: palette.error,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
            _CoachComposer(
              controller: _controller,
              onSubmit: () => _submit(context.read<CoachChatCubit>()),
            ),
          ],
        ),
      ),
    );
  }
}

class _CoachOverview extends StatelessWidget {
  final CoachChatState state;

  const _CoachOverview({required this.state});

  @override
  Widget build(BuildContext context) {
    final palette = context.runninPalette;

    return AppPanel(
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
  final List<_QuickPrompt> prompts;
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
              );
            },
          ),
        ),
      ],
    );
  }
}

class _PromptCard extends StatelessWidget {
  final _QuickPrompt prompt;
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

class _InsightsPanel extends StatelessWidget {
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

class _ConversationHeader extends StatelessWidget {
  final int messageCount;

  const _ConversationHeader({required this.messageCount});

  @override
  Widget build(BuildContext context) {
    final palette = context.runninPalette;

    return Row(
      children: [
        Expanded(
          child: Text(
            'CONVERSA',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
          ),
        ),
        AppTag(label: '$messageCount MSG', color: palette.primary),
      ],
    );
  }
}

class _MessageBubble extends StatelessWidget {
  final ChatMessage message;

  const _MessageBubble({required this.message});

  @override
  Widget build(BuildContext context) {
    final palette = context.runninPalette;
    final isUser = message.sender == MessageSender.user;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: isUser
            ? MainAxisAlignment.end
            : MainAxisAlignment.start,
        children: [
          if (!isUser) ...[
            Container(
              width: 30,
              height: 30,
              alignment: Alignment.center,
              color: palette.secondary,
              child: Text(
                'C',
                style: TextStyle(
                  color: palette.background,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            const SizedBox(width: 10),
          ],
          Flexible(
            child: AppPanel(
              color: isUser
                  ? palette.primary.withValues(alpha: 0.12)
                  : palette.surface,
              borderColor: isUser
                  ? palette.primary.withValues(alpha: 0.3)
                  : palette.border,
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isUser ? 'VOCE' : 'COACH.AI',
                    style: TextStyle(
                      color: isUser ? palette.primary : palette.secondary,
                      fontSize: 9,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.08,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    message.content,
                    style: TextStyle(
                      color: palette.text.withValues(alpha: 0.9),
                      fontSize: 13,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _formatTime(message.sentAt),
                    style: TextStyle(color: palette.muted, fontSize: 11),
                  ),
                ],
              ),
            ),
          ),
          if (isUser) const SizedBox(width: 40),
        ],
      ),
    );
  }

  String _formatTime(DateTime time) {
    final hh = time.hour.toString().padLeft(2, '0');
    final mm = time.minute.toString().padLeft(2, '0');
    return '$hh:$mm';
  }
}

class _TypingIndicator extends StatelessWidget {
  const _TypingIndicator();

  @override
  Widget build(BuildContext context) {
    final palette = context.runninPalette;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 30,
            height: 30,
            alignment: Alignment.center,
            color: palette.secondary,
            child: Text(
              'C',
              style: TextStyle(
                color: palette.background,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          const SizedBox(width: 10),
          AppPanel(
            color: palette.surfaceAlt,
            borderColor: palette.secondary.withValues(alpha: 0.25),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: List.generate(
                3,
                (index) => Container(
                  width: 6,
                  height: 6,
                  margin: EdgeInsets.only(right: index == 2 ? 0 : 6),
                  decoration: BoxDecoration(
                    color: palette.secondary.withValues(
                      alpha: 0.7 - (index * 0.15),
                    ),
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CoachComposer extends StatelessWidget {
  final TextEditingController controller;
  final VoidCallback onSubmit;

  const _CoachComposer({required this.controller, required this.onSubmit});

  @override
  Widget build(BuildContext context) {
    final palette = context.runninPalette;

    return BlocBuilder<CoachChatCubit, CoachChatState>(
      buildWhen: (prev, curr) => prev.sending != curr.sending,
      builder: (context, state) {
        return Container(
          decoration: BoxDecoration(
            color: palette.surface,
            border: Border(top: BorderSide(color: palette.border)),
          ),
          padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: TextField(
                  controller: controller,
                  enabled: !state.sending,
                  style: TextStyle(color: palette.text, fontSize: 14),
                  decoration: InputDecoration(
                    hintText: 'Pergunte algo ao seu coach...',
                    hintStyle: TextStyle(color: palette.muted, fontSize: 14),
                    border: InputBorder.none,
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(vertical: 10),
                  ),
                  textInputAction: TextInputAction.send,
                  onSubmitted: (_) => onSubmit(),
                  maxLines: null,
                ),
              ),
              const SizedBox(width: 8),
              InkWell(
                onTap: state.sending ? null : onSubmit,
                child: Container(
                  width: 42,
                  height: 42,
                  alignment: Alignment.center,
                  color: state.sending ? palette.border : palette.primary,
                  child: state.sending
                      ? SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: palette.background,
                          ),
                        )
                      : Icon(
                          Icons.arrow_upward,
                          size: 18,
                          color: palette.background,
                        ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _QuickPrompt {
  final String title;
  final String prompt;

  const _QuickPrompt({required this.title, required this.prompt});
}

class _CoachInsight {
  final String title;
  final String body;

  const _CoachInsight({required this.title, required this.body});
}
