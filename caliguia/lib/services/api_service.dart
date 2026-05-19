import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'auth_service.dart';

/// Servicio de API REST para comunicarse con el backend de la laptop.
/// Usa HTTP para todas las operaciones CRUD.
class ApiService {
  static String _baseUrl = '';
  static Duration timeout = const Duration(seconds: 5);

  /// Notifica a todas las pantallas cuando la URL del backend cambia
  static final ValueNotifier<String?> connectionNotifier = ValueNotifier<String?>(null);

  /// Notifica cuando la sesión expira (401) para redirigir al login
  static final ValueNotifier<bool> sessionExpiredNotifier = ValueNotifier<bool>(false);

  /// URL base actual del backend. Vacía si no se ha configurado.
  static String get baseUrl => _baseUrl;

  /// Indica si ya se ha configurado una URL base
  static bool get isConfigured => _baseUrl.isNotEmpty;

  /// Actualiza la URL base cuando se descubre el backend y notifica a los listeners
  static void setBaseUrl(String url) {
    _baseUrl = url.endsWith('/') ? url.substring(0, url.length - 1) : url;
    connectionNotifier.value = _baseUrl;
    print('[ApiService] URL actualizada: $_baseUrl');
  }

  /// Maneja respuestas 401 notificando a las pantallas
  static void _handle401(int statusCode) {
    if (statusCode == 401) {
      print('[ApiService] ⚠️ Sesión expirada (401)');
      AuthService.logout();
      sessionExpiredNotifier.value = true;
    }
  }

  /// Headers con autenticación si hay sesión activa
  static Future<Map<String, String>> _authHeaders() async {
    final headers = {'Content-Type': 'application/json'};
    final token = await AuthService.getToken();
    if (token != null && token.isNotEmpty) {
      headers['Authorization'] = 'Bearer $token';
    }
    return headers;
  }

  /// Verifica si el backend está disponible
  static Future<bool> isOnline() async {
    try {
      final response = await http
          .get(Uri.parse('$baseUrl/api/discover'))
          .timeout(timeout);
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  /// Descubre info del servidor
  static Future<Map<String, dynamic>?> discover() async {
    try {
      final response = await http
          .get(Uri.parse('$baseUrl/api/discover'))
          .timeout(timeout);
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
    } catch (_) {}
    return null;
  }

  /// Lista todos los atractivos
  static Future<List<dynamic>> getAtractivos() async {
    try {
      final response = await http
          .get(Uri.parse('$baseUrl/api/attractions'), headers: await _authHeaders())
          .timeout(timeout);
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['data'] ?? [];
      }
      _handle401(response.statusCode);
    } catch (_) {}
    return [];
  }

  /// Detalle de un atractivo
  static Future<Map<String, dynamic>?> getAtractivo(int id) async {
    try {
      final response = await http
          .get(Uri.parse('$baseUrl/api/attractions/$id'), headers: await _authHeaders())
          .timeout(timeout);
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['data'];
      }
      _handle401(response.statusCode);
    } catch (_) {}
    return null;
  }

  /// Atractivos cercanos por GPS
  static Future<List<dynamic>> getNearby(double lat, double lon, {double radius = 2000}) async {
    try {
      final uri = Uri.parse('$baseUrl/api/attractions/nearby')
          .replace(queryParameters: {
        'lat': lat.toString(),
        'lon': lon.toString(),
        'radius': radius.toString(),
      });
      final response = await http.get(uri, headers: await _authHeaders()).timeout(timeout);
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['data'] ?? [];
      }
      _handle401(response.statusCode);
    } catch (_) {}
    return [];
  }

  /// Lista perfiles
  static Future<List<dynamic>> getPerfiles() async {
    try {
      final response = await http
          .get(Uri.parse('$baseUrl/api/profiles'), headers: await _authHeaders())
          .timeout(timeout);
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['data'] ?? [];
      }
    } catch (_) {}
    return [];
  }

  /// Lista eventos
  static Future<List<dynamic>> getEventos() async {
    try {
      final response = await http
          .get(Uri.parse('$baseUrl/api/events'), headers: await _authHeaders())
          .timeout(timeout);
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['data'] ?? [];
      }
    } catch (_) {}
    return [];
  }

  /// Eventos actuales
  static Future<List<dynamic>> getEventosActuales() async {
    try {
      final response = await http
          .get(Uri.parse('$baseUrl/api/events/current'), headers: await _authHeaders())
          .timeout(timeout);
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['data'] ?? [];
      }
    } catch (_) {}
    return [];
  }

  /// Eventos masivos activos (Feria, Petronio, etc)
  static Future<List<dynamic>> getEventosMasivosActivos() async {
    try {
      final response = await http
          .get(Uri.parse('$baseUrl/api/events/massive/active'), headers: await _authHeaders())
          .timeout(timeout);
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['data'] ?? [];
      }
    } catch (_) {}
    return [];
  }

  /// Eventos masivos cercanos
  static Future<List<dynamic>> getEventosMasivosCercanos(double lat, double lon) async {
    try {
      final uri = Uri.parse('$baseUrl/api/events/massive/nearby').replace(queryParameters: {
        'lat': lat.toString(),
        'lon': lon.toString(),
      });
      final response = await http.get(uri, headers: await _authHeaders()).timeout(timeout);
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['data'] ?? [];
      }
    } catch (_) {}
    return [];
  }

  /// Zonas WiFi gratuitas cercanas
  static Future<List<dynamic>> getWifiZones(double lat, double lon) async {
    try {
      final uri = Uri.parse('$baseUrl/api/wifi/zones').replace(queryParameters: {
        'lat': lat.toString(),
        'lon': lon.toString(),
      });
      final response = await http.get(uri, headers: await _authHeaders()).timeout(timeout);
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['data'] ?? [];
      }
    } catch (_) {}
    return [];
  }

  /// Chatbot caleño inteligente con IA
  static Future<Map<String, dynamic>?> sendChat(String message, {double? lat, double? lon}) async {
    try {
      final Map<String, dynamic> body = {'message': message};
      if (lat != null) body['lat'] = lat;
      if (lon != null) body['lon'] = lon;

      final response = await http
          .post(
            Uri.parse('$baseUrl/api/chat'),
            headers: await _authHeaders(),
            body: jsonEncode(body),
          )
          .timeout(const Duration(seconds: 15));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['data'];
      }
      _handle401(response.statusCode);
    } catch (_) {}
    return null;
  }

  /// Enviar imagen para reconocimiento visual
  static Future<Map<String, dynamic>?> recognizeImage(File imageFile, {double? lat, double? lon}) async {
    try {
      final request = http.MultipartRequest(
        'POST',
        Uri.parse('$baseUrl/api/recognize'),
      );
      request.files.add(await http.MultipartFile.fromPath('image', imageFile.path));
      if (lat != null) request.fields['lat'] = lat.toString();
      if (lon != null) request.fields['lon'] = lon.toString();

      // Añadir token si existe
      final token = await AuthService.getToken();
      if (token != null) {
        request.headers['Authorization'] = 'Bearer $token';
      }

      final streamedResponse = await request.send().timeout(const Duration(seconds: 10));
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
      _handle401(response.statusCode);
    } catch (_) {}
    return null;
  }

  /// Chatbot con streaming SSE.
  /// Devuelve un Stream de chunks que la UI consume letra por letra.
  static Stream<Map<String, dynamic>> sendChatStream(
    String message, {
    double? lat,
    double? lon,
    Map<String, dynamic>? preferences,
  }) async* {
    if (!isConfigured) {
      yield {'delta': 'No conectado al servidor, ve.', 'done': true, 'error': 'No configurado'};
      return;
    }

    try {
      final Map<String, dynamic> body = {
        'message': message,
        if (lat != null) 'lat': lat,
        if (lon != null) 'lon': lon,
        if (preferences != null) 'preferences': preferences,
        'language': 'es', // TODO: usar LanguageService.currentLanguage
      };

      final request = http.Request(
        'POST',
        Uri.parse('$baseUrl/api/chat/stream'),
      );
      request.headers.addAll(await _authHeaders());
      request.body = jsonEncode(body);

      final streamedResponse = await request.send();

      if (streamedResponse.statusCode != 200) {
        _handle401(streamedResponse.statusCode);
        yield {
          'delta': '',
          'done': true,
          'error': streamedResponse.statusCode == 401
              ? 'Sesión expirada. Iniciá sesión de nuevo, parce.'
              : 'Error del servidor: ${streamedResponse.statusCode}',
        };
        return;
      }

      await for (final chunk in streamedResponse.stream
          .transform(utf8.decoder)
          .transform(const LineSplitter())) {
        if (chunk.startsWith('data: ')) {
          final dataStr = chunk.substring(6);
          try {
            final data = jsonDecode(dataStr) as Map<String, dynamic>;
            yield data;
            if (data['done'] == true) break;
          } catch (_) {
            continue;
          }
        }
      }
    } catch (e) {
      print('[ApiService] Error en stream: $e');
      yield {'delta': '', 'done': true, 'error': e.toString()};
    }
  }

  // =============================================================================
  // API ESTAMPAS & GAMIFICACION
  // =============================================================================

  static Future<Map<String, dynamic>?> getStamps() async {
    try {
      final response = await http
          .get(Uri.parse('$baseUrl/api/stamps'), headers: await _authHeaders())
          .timeout(timeout);
      if (response.statusCode == 200) return jsonDecode(response.body);
      _handle401(response.statusCode);
    } catch (_) {}
    return null;
  }

  static Future<Map<String, dynamic>?> getUserStamps() async {
    try {
      final response = await http
          .get(Uri.parse('$baseUrl/api/user/stamps'), headers: await _authHeaders())
          .timeout(timeout);
      if (response.statusCode == 200) return jsonDecode(response.body);
      _handle401(response.statusCode);
    } catch (_) {}
    return null;
  }

  static Future<Map<String, dynamic>?> claimStamp({
    required int atractivoId,
    int? estampaId,
  }) async {
    try {
      final body = {
        'atractivo_id': atractivoId,
        if (estampaId != null) 'estampa_id': estampaId,
      };
      final response = await http
          .post(
            Uri.parse('$baseUrl/api/stamps/claim'),
            headers: await _authHeaders(),
            body: jsonEncode(body),
          )
          .timeout(const Duration(seconds: 10));
      if (response.statusCode == 200) return jsonDecode(response.body);
      if (response.statusCode == 409) return jsonDecode(response.body); // Already claimed
      _handle401(response.statusCode);
    } catch (_) {}
    return null;
  }

  static Future<Map<String, dynamic>?> shareStamp(int estampaId) async {
    try {
      final response = await http
          .post(
            Uri.parse('$baseUrl/api/stamps/share'),
            headers: await _authHeaders(),
            body: jsonEncode({'estampa_id': estampaId}),
          )
          .timeout(timeout);
      if (response.statusCode == 200) return jsonDecode(response.body);
      _handle401(response.statusCode);
    } catch (_) {}
    return null;
  }

  static Future<Map<String, dynamic>?> getAchievements() async {
    try {
      final response = await http
          .get(Uri.parse('$baseUrl/api/achievements'), headers: await _authHeaders())
          .timeout(timeout);
      if (response.statusCode == 200) return jsonDecode(response.body);
      _handle401(response.statusCode);
    } catch (_) {}
    return null;
  }

  static Future<Map<String, dynamic>?> getUserAchievements() async {
    try {
      final response = await http
          .get(Uri.parse('$baseUrl/api/user/achievements'), headers: await _authHeaders())
          .timeout(timeout);
      if (response.statusCode == 200) return jsonDecode(response.body);
      _handle401(response.statusCode);
    } catch (_) {}
    return null;
  }

  static Future<Map<String, dynamic>?> getGamificationSummary() async {
    try {
      final response = await http
          .get(Uri.parse('$baseUrl/api/user/gamification'), headers: await _authHeaders())
          .timeout(timeout);
      if (response.statusCode == 200) return jsonDecode(response.body);
      _handle401(response.statusCode);
    } catch (_) {}
    return null;
  }
}
