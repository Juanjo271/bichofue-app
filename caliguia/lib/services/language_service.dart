import 'dart:io';
import 'package:shared_preferences/shared_preferences.dart';

/// Servicio para detectar y gestionar el idioma de la app.
class LanguageService {
  static const String _key = 'app_language';
  static String _currentLanguage = 'es';

  /// Detecta el idioma del sistema y lo guarda.
  static Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_key);
    if (saved != null) {
      _currentLanguage = saved;
    } else {
      // Detectar del sistema
      final locale = Platform.localeName;
      if (locale.startsWith('en')) {
        _currentLanguage = 'en';
      } else if (locale.startsWith('pt')) {
        _currentLanguage = 'pt';
      } else {
        _currentLanguage = 'es';
      }
      await prefs.setString(_key, _currentLanguage);
    }
    print('[Language] Idioma detectado: $_currentLanguage');
  }

  static String get currentLanguage => _currentLanguage;
  static bool get isSpanish => _currentLanguage == 'es';
  static bool get isEnglish => _currentLanguage == 'en';
  static bool get isPortuguese => _currentLanguage == 'pt';

  static Future<void> setLanguage(String lang) async {
    _currentLanguage = lang;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, lang);
  }
}
