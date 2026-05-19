import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// Servicio de notificaciones push nativas para Bichofué.
/// Gestiona notificaciones locales cuando el usuario está cerca de eventos
/// o cuando ocurren acciones importantes durante su recorrido.
class NotificationService {
  static final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  static bool _initialized = false;

  /// Inicializa el plugin de notificaciones locales.
  /// Debe llamarse una vez al inicio de la app (p. ej., en main.dart).
  static Future<void> initialize() async {
    if (_initialized) return;

    const AndroidInitializationSettings androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const InitializationSettings initSettings = InitializationSettings(
      android: androidSettings,
    );

    await _plugin.initialize(initSettings);
    _initialized = true;
  }

  /// Muestra una notificación local con el título y cuerpo dados.
  static Future<void> showEventNotification({
    required String title,
    required String body,
    String? payload,
  }) async {
    if (!_initialized) {
      await initialize();
    }

    const AndroidNotificationDetails androidDetails =
        AndroidNotificationDetails(
      'bichofue_eventos_channel',
      'Eventos Bichofué',
      channelDescription: 'Notificaciones de eventos cercanos y recomendaciones',
      importance: Importance.high,
      priority: Priority.high,
      icon: '@mipmap/ic_launcher',
    );

    const NotificationDetails details = NotificationDetails(
      android: androidDetails,
    );

    await _plugin.show(
      DateTime.now().millisecondsSinceEpoch % 2147483647,
      title,
      body,
      details,
      payload: payload,
    );
  }

  /// Verifica si el usuario otorgó permiso de notificaciones (Android 13+).
  static Future<bool> requestPermission() async {
    // Para Android 13+ se requiere POST_NOTIFICATIONS.
    // En dispositivos con API < 33 el permiso se otorga implícitamente.
    final AndroidFlutterLocalNotificationsPlugin? androidPlugin =
        _plugin.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
    if (androidPlugin != null) {
      final granted = await androidPlugin.requestNotificationsPermission();
      return granted ?? false;
    }
    return true;
  }
}
