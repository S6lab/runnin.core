import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:runnin/features/coach/data/datasources/coach_remote_datasource.dart';
import 'package:runnin/features/coach/domain/entities/chat_message.dart';

class CoachChatState {
  final List<ChatMessage> messages;
  final bool sending;
  final String? error;

  const CoachChatState({
    this.messages = const [],
    this.sending = false,
    this.error,
  });

  CoachChatState copyWith({
    List<ChatMessage>? messages,
    bool? sending,
    String? error,
  }) => CoachChatState(
    messages: messages ?? this.messages,
    sending: sending ?? this.sending,
    error: error,
  );
}

class CoachChatCubit extends Cubit<CoachChatState> {
  final CoachRemoteDatasource _ds;

  CoachChatCubit()
    : _ds = CoachRemoteDatasource(),
      super(
        CoachChatState(
          messages: [
            ChatMessage(
              content:
                  'Oi! Sou seu coach. Me diz como você está hoje e eu ajusto o treino com você.',
              sender: MessageSender.coach,
            ),
          ],
        ),
      );

  Future<void> sendMessage(String text) async {
    if (text.trim().isEmpty || state.sending) return;

    final userMsg = ChatMessage(
      content: text.trim(),
      sender: MessageSender.user,
    );
    emit(
      state.copyWith(
        messages: [...state.messages, userMsg],
        sending: true,
        error: null,
      ),
    );

    try {
      final reply = await _ds.sendMessage(text.trim());
      final coachMsg = ChatMessage(content: reply, sender: MessageSender.coach);
      emit(
        state.copyWith(messages: [...state.messages, coachMsg], sending: false),
      );
    } catch (_) {
      emit(
        state.copyWith(
          sending: false,
          error: 'Falha ao enviar mensagem. Tente novamente.',
        ),
      );
    }
  }

  void clearError() => emit(state.copyWith(error: null));
}
