import 'package:flutter/foundation.dart';
import '../models/route_request.dart';

/// Notificador global para compartir solicitudes de ruta entre pantallas.
/// Cuando el chat genera una ruta, emite un [RouteRequest] que el mapa escucha.
class RouteNotifier {
  static final ValueNotifier<RouteRequest?> _notifier = ValueNotifier<RouteRequest?>(null);

  static ValueNotifier<RouteRequest?> get instance => _notifier;

  static void setRoute(RouteRequest route) {
    _notifier.value = route;
  }

  static void clear() {
    _notifier.value = null;
  }

  static RouteRequest? get current => _notifier.value;
}
