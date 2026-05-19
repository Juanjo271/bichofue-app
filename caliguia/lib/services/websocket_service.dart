import 'dart:async';
import 'package:socket_io_client/socket_io_client.dart' as io;
import 'api_service.dart';

/// Servicio WebSocket para comunicacion en tiempo real con el backend.
/// Maneja conexion, reconexion automatica, y eventos push.
class WebSocketService {
  static io.Socket? _socket;
  static final StreamController<Map<String, dynamic>> _eventController = 
      StreamController<Map<String, dynamic>>.broadcast();
  
  /// Stream de eventos recibidos del backend (nearby_alert, event_push, etc.)
  static Stream<Map<String, dynamic>> get eventStream => _eventController.stream;

  static bool get isConnected => _socket != null && _socket!.connected;

  /// Conecta al backend via WebSocket
  static Future<bool> connect({String? url}) async {
    try {
      final serverUrl = url ?? ApiService.baseUrl;
      
      _socket = io.io(serverUrl, <String, dynamic>{
        'transports': ['websocket', 'polling'],
        'autoConnect': true,
        'reconnection': true,
        'reconnectionAttempts': 10,
        'reconnectionDelay': 2000,
      });

      _socket!.on('connect', (_) {
        print('[WebSocket] Conectado a $serverUrl');
      });

      _socket!.on('disconnect', (_) {
        print('[WebSocket] Desconectado');
      });

      _socket!.on('connect_error', (data) {
        print('[WebSocket] Error de conexion: $data');
      });

      _socket!.on('connected', (data) {
        _eventController.add({'type': 'connected', 'data': data});
      });

      _socket!.on('nearby_alert', (data) {
        _eventController.add({'type': 'nearby_alert', 'data': data});
      });

      _socket!.on('event_push', (data) {
        _eventController.add({'type': 'event_push', 'data': data});
      });

      _socket!.on('location_confirmed', (data) {
        _eventController.add({'type': 'location_confirmed', 'data': data});
      });

      _socket!.on('error', (data) {
        _eventController.add({'type': 'error', 'data': data});
      });

      // Esperar un momento para que la conexion se establezca
      await Future.delayed(const Duration(milliseconds: 1000));
      return isConnected;
    } catch (e) {
      print('[WebSocket] Error iniciando: $e');
      return false;
    }
  }

  /// Desconecta el WebSocket
  static void disconnect() {
    _socket?.disconnect();
    _socket = null;
  }

  /// Registra el dispositivo con un perfil
  static void registerDevice({required int profileId, String deviceName = 'CaliGuia'}) {
    if (!isConnected) return;
    _socket!.emit('register_device', {
      'profile_id': profileId,
      'device_name': deviceName,
    });
  }

  /// Envia actualizacion de ubicacion GPS
  static void sendLocation(double lat, double lon) {
    if (!isConnected) return;
    _socket!.emit('location_update', {
      'lat': lat,
      'lon': lon,
      'device_id': 'bichofue_mobile',
    });
  }

  /// Libera recursos
  static void dispose() {
    disconnect();
    _eventController.close();
  }
}
