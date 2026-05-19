import 'package:flutter/material.dart';
import '../main.dart';
import '../services/api_service.dart';
import '../services/discovery_service.dart';
import '../services/websocket_service.dart';
import '../services/notification_service.dart';
import '../services/route_notifier.dart';
import 'map_screen.dart';
import 'attractions_list_screen.dart';
import 'chat_screen.dart';
import 'eventos_screen.dart';
import 'collection_screen.dart';
import 'profile_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _isOnline = false;
  String _backendUrl = '';
  int _selectedIndex = 0;
  Map<String, dynamic>? _activeEvent;

  @override
  void initState() {
    super.initState();
    _discoverAndConnect();
    RouteNotifier.instance.addListener(_onRouteRequested);
    _checkActiveEvents();
  }

  Future<void> _checkActiveEvents() async {
    try {
      final eventos = await ApiService.getEventosMasivosActivos();
      if (eventos.isNotEmpty && mounted) {
        final evento = eventos.first;
        setState(() => _activeEvent = evento);
        // Notificación nativa del evento principal
        await NotificationService.showEventNotification(
          title: '🎉 Hay un evento masivo en Cali',
          body: evento['nombre'] ?? 'Consulta rutas alternativas',
        );
      }
    } catch (_) {}
  }

  void _onRouteRequested() {
    final route = RouteNotifier.current;
    if (route != null && mounted) {
      setState(() => _selectedIndex = 0); // Cambiar al tab del mapa
    }
  }

  @override
  void dispose() {
    RouteNotifier.instance.removeListener(_onRouteRequested);
    WebSocketService.disconnect();
    super.dispose();
  }

  Future<void> _discoverAndConnect() async {
    final url = await DiscoveryService.discoverBackend();
    if (url != null) {
      ApiService.setBaseUrl(url);
      final online = await ApiService.isOnline();
      if (online) {
        await WebSocketService.connect(url: url);
        if (mounted) {
          setState(() {
            _isOnline = true;
            _backendUrl = url;
          });
        }
        return;
      }
    }

    // Fallback: auto-descubrimiento falló, mostrar diálogo
    if (mounted) {
      await _showConnectionFallback();
    }
  }

  /// Obtiene el texto inicial para el campo de IP (última guardada o placeholder)
  Future<String> _getInitialIpText() async {
    final saved = await DiscoveryService.getSavedUrl();
    if (saved != null) {
      // Extraer IP:puerto de http://IP:puerto
      return saved.replaceFirst('http://', '');
    }
    return '';
  }

  Future<void> _showConnectionFallback() async {
    final initialText = await _getInitialIpText();
    final controller = TextEditingController(text: initialText);

    final result = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        icon: const Icon(Icons.wifi_find, size: 48, color: Colors.orange),
        title: const Text('No se encontró el backend'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'No pudimos encontrar tu laptop en la red WiFi automáticamente.',
            ),
            const SizedBox(height: 8),
            const Text(
              'Ingresa la IP de tu laptop (se muestra al iniciar el servidor):',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: 'IP:Puerto',
                hintText: 'ej: 192.168.1.9:5000',
                prefixIcon: Icon(Icons.computer),
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Omitir'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, controller.text),
            child: const Text('Conectar'),
          ),
        ],
      ),
    );

    if (result != null && result.isNotEmpty) {
      await _tryConnect(result);
    }
  }

  Future<void> _tryConnect(String ipPort) async {
    final url = ipPort.startsWith('http') ? ipPort : 'http://$ipPort';
    ApiService.setBaseUrl(url);
    final online = await ApiService.isOnline();
    if (online) {
      await DiscoveryService.saveBackendUrl(url);
      await WebSocketService.connect(url: url);
      if (mounted) {
        setState(() {
          _isOnline = true;
          _backendUrl = url;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Conectado a $url')),
        );
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No se pudo conectar. Verifica que el servidor esté corriendo y que estén en la misma WiFi.'),
            backgroundColor: BichofueColors.cafe,
          ),
        );
      }
    }
  }

  Future<void> _manualConnect() async {
    final initialText = await _getInitialIpText();
    final controller = TextEditingController(text: initialText);
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Conectar al Backend'),
        content: TextField(
          controller: controller,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(
            labelText: 'IP:Puerto del backend',
            hintText: 'ej: 192.168.1.9:5000',
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, controller.text),
            child: const Text('Conectar'),
          ),
        ],
      ),
    );

    if (result != null && result.isNotEmpty) {
      await _tryConnect(result);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: BichofueColors.beige,
      body: Column(
        children: [
          // Banner de evento masivo activo
          if (_activeEvent != null)
            GestureDetector(
              onTap: () {
                setState(() => _selectedIndex = 1); // Ir a Eventos
              },
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFFF6B35), Color(0xFFF4C400)],
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: SafeArea(
                  bottom: false,
                  child: Row(
                    children: [
                      const Icon(Icons.festival, color: Colors.white, size: 24),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _activeEvent!['nombre'] ?? 'Evento activo',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                            Text(
                              'Tocá para ver rutas alternativas',
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.9),
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Icon(Icons.chevron_right, color: Colors.white),
                    ],
                  ),
                ),
              ),
            ),
          Expanded(
            child: IndexedStack(
              index: _selectedIndex,
              children: [
                const MapScreen(),
                const EventosScreen(),
                const ChatScreen(),
                const CollectionScreen(),
                const ProfileScreen(),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: (i) => setState(() => _selectedIndex = i),
        selectedItemColor: BichofueColors.verde,
        unselectedItemColor: BichofueColors.gris,
        type: BottomNavigationBarType.fixed,
        backgroundColor: BichofueColors.blanco,
        selectedLabelStyle: const TextStyle(fontWeight: FontWeight.bold),
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.map),
            label: 'Mapa',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.event),
            label: 'Eventos',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.chat),
            label: 'Chat',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.collections_bookmark),
            label: 'Colección',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person),
            label: 'Perfil',
          ),
        ],
      ),
    );
  }
}
