enum MessageSender { user, coach }

class ChatMessage {
  final String content;
  final MessageSender sender;
  final DateTime sentAt;

  ChatMessage({
    required this.content,
    required this.sender,
    DateTime? sentAt,
  }) : sentAt = sentAt ?? DateTime.now();
}
