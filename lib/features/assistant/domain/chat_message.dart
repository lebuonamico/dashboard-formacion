class ChatMessage {
  final String text;
  final bool isUser;
  final String context;

  const ChatMessage({
    required this.text,
    required this.isUser,
    required this.context,
  });
}

class ChatState {
  final bool open;
  final bool sending;
  final List<ChatMessage> messages;
  final String? error;
  final bool canRetry;

  const ChatState({
    this.open = false,
    this.sending = false,
    this.messages = const [],
    this.error,
    this.canRetry = false,
  });

  ChatState copyWith({
    bool? open,
    bool? sending,
    List<ChatMessage>? messages,
    String? error,
    bool? canRetry,
  }) => ChatState(
    open: open ?? this.open,
    sending: sending ?? this.sending,
    messages: messages ?? this.messages,
    error: error,
    canRetry: canRetry ?? this.canRetry,
  );
}
