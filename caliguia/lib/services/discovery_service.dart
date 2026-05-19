import 'dart:async';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

/// Servicio de descubrimiento del backend en la red local WiFi.
/// Intenta encontrar automaticamente la laptop donde corre Flask.
class DiscoveryService {
  static const String _prefsKey = 'backend_url';
  static const int _defaultPort = 5000;
  static const Duration _timeout = Duration(milliseconds: 800);

  /// Intenta descubrir el backend automaticamente.
  /// 1. Primero prueba la URL guardada en SharedPreferences
  /// 2. Si no funciona, escanea la subred local comun (192.168.1.x o 192.168.0.x)
  /// 3. Retorna la primera IP que responde correctamente
  static Future<String?> discoverBackend() async {
    final prefs = await SharedPreferences.getInstance();
    final savedUrl = prefs.getString(_prefsKey);

    // Paso 1: Probar URL guardada
    if (savedUrl != null && await _testUrl(savedUrl)) {
      return savedUrl;
    }

    // Paso 2: Escanear subredes comunes (incluyendo hotspots Windows: 172.16.x.x)
    final subnets = ['192.168.1', '192.168.0', '10.0.0', '172.16'];
    
    for (final subnet in subnets) {
      final found = await _scanSubnet(subnet);
      if (found != null) {
        await prefs.setString(_prefsKey, found);
        return found;
      }
    }

    return null;
  }

  /// Prueba una URL especifica
  static Future<bool> _testUrl(String url) async {
    try {
      final response = await http
          .get(Uri.parse('$url/api/discover'))
          .timeout(_timeout);
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  /// Escanea una subred completa (1-254) buscando el puerto 5000
  static Future<String?> _scanSubnet(String subnet) async {
    // Para no saturar, escaneamos rangos comunes primero
    final ranges = [
      List.generate(50, (i) => i + 1),   // 1-50
      List.generate(50, (i) => i + 51),  // 51-100
      List.generate(50, (i) => i + 101), // 101-150
      List.generate(50, (i) => i + 151), // 151-200
      List.generate(54, (i) => i + 201), // 201-254
    ];

    for (final range in ranges) {
      final futures = range.map((i) => _testIp('$subnet.$i')).toList();
      final results = await Future.wait(futures);
      
      for (int i = 0; i < results.length; i++) {
        if (results[i] != null) {
          return results[i];
        }
      }
    }
    return null;
  }

  /// Prueba una IP individual
  static Future<String?> _testIp(String ip) async {
    try {
      final url = 'http://$ip:$_defaultPort';
      final response = await http
          .get(Uri.parse('$url/api/discover'))
          .timeout(_timeout);
      if (response.statusCode == 200) {
        return url;
      }
    } catch (_) {}
    return null;
  }

  /// Guarda manualmente la URL del backend (si el usuario la ingresa)
  static Future<void> saveBackendUrl(String url) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsKey, url);
  }

  /// Obtiene la URL guardada sin probarla
  static Future<String?> getSavedUrl() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_prefsKey);
  }
}
