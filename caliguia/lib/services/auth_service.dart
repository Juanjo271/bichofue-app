import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user.dart';
import '../models/user_preferences.dart';
import 'api_service.dart';

/// Servicio de autenticación: registro, login, token, perfil.
class AuthService {
  static const String _tokenKey = 'auth_token';
  static const String _userKey = 'auth_user';

  static User? _currentUser;

  /// Usuario actualmente logueado (cache en memoria)
  static User? get currentUser => _currentUser;

  /// Verifica si hay un token guardado
  static Future<bool> hasToken() async {
    final sp = await SharedPreferences.getInstance();
    return sp.getString(_tokenKey) != null;
  }

  /// Obtiene el token guardado
  static Future<String?> getToken() async {
    final sp = await SharedPreferences.getInstance();
    return sp.getString(_tokenKey);
  }

  /// Guarda token y usuario en SharedPreferences
  static Future<void> _saveSession(User user) async {
    final sp = await SharedPreferences.getInstance();
    await sp.setString(_tokenKey, user.token);
    await sp.setString(_userKey, jsonEncode(user.toJson()));
    _currentUser = user;
  }

  /// Carga usuario desde SharedPreferences (sin validar con backend)
  static Future<User?> loadUserFromCache() async {
    final sp = await SharedPreferences.getInstance();
    final userJson = sp.getString(_userKey);
    final token = sp.getString(_tokenKey);
    if (userJson != null && token != null) {
      try {
        final data = jsonDecode(userJson) as Map<String, dynamic>;
        _currentUser = User.fromJson(data, token);
        return _currentUser;
      } catch (_) {}
    }
    return null;
  }

  /// Valida el token con el backend y carga el perfil actualizado
  static Future<User?> validateSession() async {
    final token = await getToken();
    if (token == null) return null;

    try {
      final response = await http.get(
        Uri.parse('${ApiService.baseUrl}/api/auth/me'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      ).timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        final body = jsonDecode(response.body);
        if (body['success'] == true) {
          final user = User.fromJson(body['data'], token);
          await _saveSession(user);
          return user;
        }
      }
    } catch (e) {
      print('[Auth] Error validando sesión: $e');
    }

    // Token inválido o error de red
    await logout();
    return null;
  }

  /// Registro de nuevo usuario
  static Future<User?> register({
    required String email,
    required String username,
    required String password,
  }) async {
    final response = await http.post(
      Uri.parse('${ApiService.baseUrl}/api/auth/register'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'email': email.trim().toLowerCase(),
        'username': username.trim().toLowerCase(),
        'password': password,
      }),
    ).timeout(const Duration(seconds: 8));

    final body = jsonDecode(response.body);
    if (response.statusCode == 200 && body['success'] == true) {
      final data = body['data'];
      final user = User(
        id: data['user_id'],
        email: email.trim().toLowerCase(),
        username: data['username'],
        token: data['token'],
      );
      await _saveSession(user);
      return user;
    }

    throw Exception(body['error'] ?? 'Error en el registro');
  }

  /// Login de usuario existente
  static Future<User?> login({
    required String username,
    required String password,
  }) async {
    final response = await http.post(
      Uri.parse('${ApiService.baseUrl}/api/auth/login'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'username': username.trim().toLowerCase(),
        'password': password,
      }),
    ).timeout(const Duration(seconds: 8));

    final body = jsonDecode(response.body);
    if (response.statusCode == 200 && body['success'] == true) {
      final data = body['data'];
      final token = data['token'];

      // Cargar perfil completo desde /me
      final meResponse = await http.get(
        Uri.parse('${ApiService.baseUrl}/api/auth/me'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      ).timeout(const Duration(seconds: 5));

      if (meResponse.statusCode == 200) {
        final meBody = jsonDecode(meResponse.body);
        if (meBody['success'] == true) {
          final user = User.fromJson(meBody['data'], token);
          await _saveSession(user);
          return user;
        }
      }

      // Fallback: crear usuario básico si /me falla
      final user = User(
        id: data['user_id'],
        email: '',
        username: data['username'],
        token: token,
      );
      await _saveSession(user);
      return user;
    }

    throw Exception(body['error'] ?? 'Error en el login');
  }

  /// Cierra sesión y limpia todo
  static Future<void> logout() async {
    final sp = await SharedPreferences.getInstance();
    await sp.remove(_tokenKey);
    await sp.remove(_userKey);
    _currentUser = null;
  }

  /// Actualiza el perfil del usuario en el backend
  static Future<void> updateProfile(UserPreferences prefs) async {
    final token = await getToken();
    if (token == null) throw Exception('No hay sesión activa');

    final response = await http.put(
      Uri.parse('${ApiService.baseUrl}/api/auth/profile'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({
        'nombre': prefs.nombre,
        'edad': prefs.edad,
        'genero': prefs.genero,
        'origen': prefs.origen,
        'hospedaje': prefs.hospedaje,
        'grupo': prefs.grupo,
        'duracion': prefs.duracion,
        'presupuesto': prefs.presupuesto,
        'intereses': prefs.intereses,
        'perfil_id': prefs.perfilId,
        'perfil_name': prefs.perfilName,
      }),
    ).timeout(const Duration(seconds: 8));

    final body = jsonDecode(response.body);
    if (response.statusCode != 200 || body['success'] != true) {
      throw Exception(body['error'] ?? 'Error actualizando perfil');
    }

    // Actualizar cache local
    final me = await validateSession();
    if (me == null) {
      throw Exception('No se pudo refrescar el perfil');
    }
  }

  /// Convierte UserPreferences a User (para compatibilidad)
  static User? preferencesToUser(UserPreferences prefs, String token) {
    if (prefs.nombre.isEmpty) return null;
    return User(
      id: _currentUser?.id ?? 0,
      email: _currentUser?.email ?? '',
      username: _currentUser?.username ?? '',
      token: token,
      nombre: prefs.nombre,
      edad: prefs.edad,
      genero: prefs.genero,
      origen: prefs.origen,
      hospedaje: prefs.hospedaje,
      grupo: prefs.grupo,
      duracion: prefs.duracion,
      presupuesto: prefs.presupuesto,
      intereses: prefs.intereses,
      perfilId: prefs.perfilId,
      perfilName: prefs.perfilName,
    );
  }
}
