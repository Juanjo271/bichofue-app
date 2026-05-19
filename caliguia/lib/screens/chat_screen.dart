import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import '../models/chat_message.dart';
import '../models/route_request.dart';
import '../models/user_preferences.dart';
import '../services/api_service.dart';
import '../services/audio_player_service.dart';
import '../services/database_helper.dart';
import '../services/route_notifier.dart';
import '../services/user_service.dart';
import '../widgets/bichofue_avatar.dart';
import '../main.dart';
import 'package:geolocator/geolocator.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _controller = TextEditingController();
  final List<ChatMessage> _messages = [];
  final ScrollController _scrollController = ScrollController();
  bool _isTyping = false;
  String? _currentAudioUrl;
  Timer? _debounceTimer;
  UserPreferences _userPrefs = UserPreferences();

  @override
  void initState() {
    super.initState();
    _loadPreferences();
    _loadChatHistory();
  }

  Future<void> _loadChatHistory() async {
    try {
      final rows = await DatabaseHelper().getChatHistory(limit: 200);
      if (rows.isEmpty) {
        _addBotMessage(
          '¡Oís, ve! Soy tu guía caleño. ¿Qué querés saber de Cali, parce?',
        );
        return;
      }
      final msgs = rows.map((r) => ChatMessage(
        id: r['id'].toString(),
        isBot: r['is_bot'] == 1,
        text: r['text'] as String,
        audioUrl: r['audio_url'] as String?,
        routeMeta: r['route_meta'] != null
            ? jsonDecode(r['route_meta'] as String)
            : null,
      )).toList();
      setState(() => _messages.addAll(msgs));
      _scrollToBottom();
    } catch (e) {
      print('[Chat] Error cargando historial: $e');
      _addBotMessage(
        '¡Oís, ve! Soy tu guía caleño. ¿Qué querés saber de Cali, parce?',
      );
    }
  }

  Future<void> _loadPreferences() async {
    final prefs = await UserService.getPreferences();
    setState(() => _userPrefs = prefs);
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _scrollController.dispose();
    _controller.dispose();
    super.dispose();
  }

  void _addBotMessage(String text, {String? audioUrl}) {
    final msg = ChatMessage(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      isBot: true,
      text: text,
      audioUrl: audioUrl,
    );
    setState(() => _messages.add(msg));
    _scrollToBottom();
    if (audioUrl != null) {
      _playAudio(audioUrl);
    }
    // Persistir
    DatabaseHelper().saveChatMessage(
      isBot: true,
      text: text,
      audioUrl: audioUrl,
    );
  }

  void _addUserMessage(String text) {
    final msg = ChatMessage.user(text);
    setState(() => _messages.add(msg));
    _scrollToBottom();
    // Persistir
    DatabaseHelper().saveChatMessage(
      isBot: false,
      text: text,
    );
  }

  Future<void> _playAudio(String audioUrl) async {
    if (!ApiService.isConfigured) return;
    final fullUrl = audioUrl.startsWith('http')
        ? audioUrl
        : '${ApiService.baseUrl}$audioUrl';

    setState(() => _currentAudioUrl = fullUrl);

    try {
      await AudioPlayerService.stop();
      await AudioPlayerService.playUrl(fullUrl);
    } catch (e) {
      print('[Chat] Error reproduciendo audio: $e');
    }
  }

  void _showRouteOnMap(Map<String, dynamic> routeMeta) {
    final route = routeMeta['route'] as Map<String, dynamic>?;
    final circuit = routeMeta['circuit'] as Map<String, dynamic>?;

    if (route != null) {
      // Ruta especifica: origen (GPS) → destino
      RouteNotifier.setRoute(RouteRequest(
        type: 'specific',
        name: route['destination_name'] ?? 'Destino',
        stops: [
          RouteStop(
            nombre: route['destination_name'] ?? 'Destino',
            lat: (route['destination_lat'] ?? 0).toDouble(),
            lon: (route['destination_lon'] ?? 0).toDouble(),
            descripcion: route['destination_desc'],
          ),
        ],
      ));
    } else if (circuit != null) {
      // Circuito multi-parada
      final stops = (circuit['stops'] as List? ?? []).map((s) {
        return RouteStop(
          nombre: s['nombre'] ?? '',
          lat: (s['lat'] ?? 0).toDouble(),
          lon: (s['lon'] ?? 0).toDouble(),
          descripcion: s['desc'],
        );
      }).toList();

      RouteNotifier.setRoute(RouteRequest(
        type: 'circuit',
        name: circuit['name'] ?? 'Circuito',
        stops: stops,
      ));
    }
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _debounceTimer?.cancel();
      _debounceTimer = Timer(const Duration(milliseconds: 100), () {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      });
    }
  }

  Future<void> _sendMessage() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;

    _controller.clear();
    _addUserMessage(text);

    // Crear mensaje vacío del bot en modo streaming
    final botMessage = ChatMessage.botStreaming();
    setState(() {
      _messages.add(botMessage);
      _isTyping = true;
    });
    _scrollToBottom();

    // Obtener ubicación
    double? lat, lon;
    try {
      final pos = await Geolocator.getLastKnownPosition();
      if (pos != null) {
        lat = pos.latitude;
        lon = pos.longitude;
      }
    } catch (_) {}

    // Escuchar stream con preferencias del usuario
    print('[Chat] Enviando mensaje: "$text" | prefs=${_userPrefs.toJson()}');
    final stream = ApiService.sendChatStream(
      text,
      lat: lat,
      lon: lon,
      preferences: _userPrefs.toJson(),
    );

    Map<String, dynamic>? finalRouteMeta;

    await for (final chunk in stream) {
      final delta = chunk['delta'] as String? ?? '';
      final done = chunk['done'] as bool? ?? false;
      final audioUrl = chunk['audio_url'] as String?;
      final error = chunk['error'] as String?;

      if (error != null && error.isNotEmpty) {
        print('[Chat] Error del stream: $error');
      }

      // Guardar metadatos de ruta del chunk final
      if (done) {
        final route = chunk['route'] as Map<String, dynamic>?;
        final circuit = chunk['circuit'] as Map<String, dynamic>?;
        if (route != null || circuit != null) {
          finalRouteMeta = {'route': route, 'circuit': circuit};
          print('[Chat] RouteMeta recibido: route=${route != null}, circuit=${circuit != null}');
        } else {
          print('[Chat] RouteMeta: null (sin ruta ni circuito)');
        }
      }

      if (delta.isNotEmpty) {
        setState(() {
          botMessage.appendText(delta);
        });
        _scrollToBottom();
      }

      if (done) {
        setState(() {
          botMessage.finishStreaming(
            audioUrl: audioUrl,
            routeMeta: finalRouteMeta,
          );
          _isTyping = false;
        });
        _scrollToBottom();
        // Persistir respuesta completa del bot
        DatabaseHelper().saveChatMessage(
          isBot: true,
          text: botMessage.text,
          audioUrl: audioUrl,
          routeMeta: finalRouteMeta != null ? jsonEncode(finalRouteMeta) : null,
        );
        break;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: BichofueColors.beige,
      appBar: AppBar(
        title: const Row(
          children: [
            BichofueAvatar(size: 44),
            SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Guía Bichofué', style: TextStyle(fontSize: 16)),
                Text('Siempre online pa\' ti', style: TextStyle(fontSize: 12)),
              ],
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_outline),
            tooltip: 'Limpiar conversación',
            onPressed: () async {
              final confirm = await showDialog<bool>(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text('¿Borrar historial?'),
                  content: const Text('Se eliminará todo el historial de chat.'),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
                    TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Borrar')),
                  ],
                ),
              );
              if (confirm == true) {
                await DatabaseHelper().clearChatHistory();
                setState(() => _messages.clear());
                _addBotMessage('¡Oís, ve! Conversación limpiada. ¿Qué querés saber?');
              }
            },
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.all(12),
              itemCount: _messages.length,
              itemBuilder: (ctx, index) {
                final msg = _messages[index];
                return _buildMessageBubble(msg);
              },
            ),
          ),
          if (_isTyping)
            const Padding(
              padding: EdgeInsets.all(8.0),
              child: Row(
                children: [
                  BichofueAvatar(size: 36),
                  SizedBox(width: 8),
                  _TypingIndicator(),
                ],
              ),
            ),
          _buildInputBar(),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(ChatMessage msg) {
    final isBot = msg.isBot;

    return Align(
      alignment: isBot ? Alignment.centerLeft : Alignment.centerRight,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.75,
        ),
        child: Column(
          crossAxisAlignment:
              isBot ? CrossAxisAlignment.start : CrossAxisAlignment.end,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: isBot ? BichofueColors.blanco : BichofueColors.verde,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(16),
                  topRight: const Radius.circular(16),
                  bottomLeft: Radius.circular(isBot ? 4 : 16),
                  bottomRight: Radius.circular(isBot ? 16 : 4),
                ),
                boxShadow: isBot
                    ? [
                        BoxShadow(
                          color: BichofueColors.negro.withOpacity(0.05),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ]
                    : null,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    msg.text,
                    style: TextStyle(
                      color: isBot ? BichofueColors.negro : BichofueColors.blanco,
                      fontSize: 15,
                    ),
                  ),
                  if (isBot && msg.isStreaming && msg.text.isNotEmpty)
                    const _BlinkingCursor(),
                ],
              ),
            ),
            if (isBot && !msg.isStreaming && msg.audioUrl != null) ...[
              const SizedBox(height: 4),
              GestureDetector(
                onTap: () => _playAudio(msg.audioUrl!),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: BichofueColors.amarillo,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        _currentAudioUrl == msg.audioUrl
                            ? Icons.volume_up
                            : Icons.play_circle_outline,
                        size: 16,
                        color: BichofueColors.negro,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Escuchar',
                        style: TextStyle(
                          fontSize: 12,
                          color: BichofueColors.negro,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
            if (isBot && !msg.isStreaming && msg.hasRoute) ...[
              const SizedBox(height: 4),
              GestureDetector(
                onTap: () => _showRouteOnMap(msg.routeMeta!),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: BichofueColors.blanco,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: BichofueColors.verde),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.map,
                        size: 16,
                        color: BichofueColors.verde,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Ver ruta en mapa',
                        style: TextStyle(
                          fontSize: 12,
                          color: BichofueColors.verde,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildInputBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _controller,
                enabled: !_isTyping,
                decoration: InputDecoration(
                  hintText: 'Escribile al guía caleño...',
                  filled: true,
                  fillColor: Colors.grey.shade100,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: BorderSide.none,
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: BorderSide.none,
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: BorderSide(
                      color: Theme.of(context).colorScheme.primary,
                      width: 2,
                    ),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 14,
                  ),
                ),
                onSubmitted: (_) => _sendMessage(),
              ),
            ),
            const SizedBox(width: 8),
            Material(
              color: _isTyping
                  ? BichofueColors.gris
                  : BichofueColors.amarillo,
              shape: const CircleBorder(),
              child: InkWell(
                customBorder: const CircleBorder(),
                onTap: _isTyping ? null : _sendMessage,
                child: const SizedBox(
                  width: 48,
                  height: 48,
                  child: Icon(Icons.send, color: BichofueColors.negro, size: 20),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Cursor parpadeante que indica que el bot sigue escribiendo
class _BlinkingCursor extends StatefulWidget {
  const _BlinkingCursor();

  @override
  State<_BlinkingCursor> createState() => _BlinkingCursorState();
}

class _BlinkingCursorState extends State<_BlinkingCursor>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _controller,
      child: const Text(
        '|',
        style: TextStyle(
          color: Colors.grey,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}

/// Indicador de "escribiendo" con 3 puntos animados
class _TypingIndicator extends StatefulWidget {
  const _TypingIndicator();

  @override
  State<_TypingIndicator> createState() => _TypingIndicatorState();
}

class _TypingIndicatorState extends State<_TypingIndicator>
    with TickerProviderStateMixin {
  late final List<AnimationController> _controllers;

  @override
  void initState() {
    super.initState();
    _controllers = List.generate(3, (i) {
      return AnimationController(
        duration: const Duration(milliseconds: 600),
        vsync: this,
      )..repeat(
          period: Duration(milliseconds: 1200 + i * 200),
        );
    });
  }

  @override
  void dispose() {
    for (final c in _controllers) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: List.generate(3, (i) {
        return AnimatedBuilder(
          animation: _controllers[i],
          builder: (context, child) {
            return Container(
              margin: const EdgeInsets.symmetric(horizontal: 2),
              width: 6,
              height: 6,
              decoration: BoxDecoration(
                color: BichofueColors.amarillo.withOpacity(
                  0.5 + 0.5 * _controllers[i].value,
                ),
                shape: BoxShape.circle,
              ),
            );
          },
        );
      }),
    );
  }
}
