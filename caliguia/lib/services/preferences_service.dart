import 'package:shared_preferences/shared_preferences.dart';

/// Servicio para manejar preferencias de usuario (modo nocturno, etc.)
class PreferencesService {
  static const String _nightModeKey = 'night_mode_enabled';

  /// Obtener estado del modo nocturno
  static Future<bool> isNightModeEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_nightModeKey) ?? false;
  }

  /// Guardar estado del modo nocturno
  static Future<void> setNightModeEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_nightModeKey, enabled);
  }

  /// Toggle modo nocturno
  static Future<bool> toggleNightMode() async {
    final current = await isNightModeEnabled();
    final newValue = !current;
    await setNightModeEnabled(newValue);
    return newValue;
  }
}
