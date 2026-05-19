import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user_preferences.dart';

/// Servicio de gestion del perfil de usuario con preferencias completas.
class UserService {
  static const String _preferencesKey = 'user_preferences_v2';
  static const String _onboardingCompleteKey = 'onboarding_complete_v2';

  /// Guarda las preferencias completas del usuario
  static Future<void> setPreferences(UserPreferences prefs) async {
    final sp = await SharedPreferences.getInstance();
    await sp.setString(_preferencesKey, jsonEncode(prefs.toJson()));
    await sp.setBool(_onboardingCompleteKey, true);
  }

  /// Obtiene las preferencias completas del usuario
  static Future<UserPreferences> getPreferences() async {
    final sp = await SharedPreferences.getInstance();
    final jsonStr = sp.getString(_preferencesKey);
    if (jsonStr != null) {
      try {
        return UserPreferences.fromJson(jsonDecode(jsonStr));
      } catch (_) {}
    }
    return UserPreferences();
  }

  /// Verifica si el onboarding ya fue completado
  static Future<bool> isOnboardingComplete() async {
    final sp = await SharedPreferences.getInstance();
    return sp.getBool(_onboardingCompleteKey) ?? false;
  }

  /// Limpia todos los datos de usuario (para testing)
  static Future<void> clear() async {
    final sp = await SharedPreferences.getInstance();
    await sp.remove(_preferencesKey);
    await sp.remove(_onboardingCompleteKey);
  }

  /// Obtiene un mapa con toda la info del usuario (compatibilidad)
  static Future<Map<String, dynamic>> getUserInfo() async {
    final prefs = await getPreferences();
    return {
      'profileId': prefs.perfilId,
      'profileName': prefs.perfilName,
      'userName': prefs.nombre,
      'onboardingComplete': await isOnboardingComplete(),
    };
  }

  /// Obtiene el ID del perfil seleccionado (compatibilidad)
  static Future<int?> getProfileId() async {
    final prefs = await getPreferences();
    return prefs.perfilId == 0 ? null : prefs.perfilId;
  }

  /// Obtiene el nombre del perfil seleccionado (compatibilidad)
  static Future<String?> getProfileName() async {
    final prefs = await getPreferences();
    return prefs.perfilName.isEmpty ? null : prefs.perfilName;
  }
}
