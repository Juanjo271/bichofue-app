/// Modelo de mensaje para el chat con streaming
class ChatMessage {
  final String id;
  final bool isBot;
  String text;
  bool isStreaming;
  String? audioUrl;
  final DateTime time;
  Map<String, dynamic>? routeMeta; // Metadatos de ruta/circuito

  ChatMessage({
    required this.id,
    required this.isBot,
    this.text = '',
    this.isStreaming = false,
    this.audioUrl,
    this.routeMeta,
    DateTime? time,
  }) : time = time ?? DateTime.now();

  /// Crea un mensaje vacío del bot en estado de streaming
  factory ChatMessage.botStreaming() {
    return ChatMessage(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      isBot: true,
      text: '',
      isStreaming: true,
    );
  }

  /// Crea un mensaje del usuario
  factory ChatMessage.user(String text) {
    return ChatMessage(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      isBot: false,
      text: text,
      isStreaming: false,
    );
  }

  /// Agrega texto al mensaje (usado durante streaming)
  void appendText(String delta) {
    text += delta;
  }

  /// Finaliza el streaming
  void finishStreaming({String? audioUrl, Map<String, dynamic>? routeMeta}) {
    isStreaming = false;
    this.audioUrl = audioUrl;
    this.routeMeta = routeMeta;
  }

  bool get hasRoute => routeMeta != null && (routeMeta!['route'] != null || routeMeta!['circuit'] != null);

  @override
  String toString() => 'ChatMessage(isBot: $isBot, streaming: $isStreaming, text: ${text.length} chars, hasRoute: $hasRoute)';
}
