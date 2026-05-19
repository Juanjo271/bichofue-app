import '../models/stamp_model.dart';
import 'api_service.dart';

/// Servicio para gestionar estampas, logros y gamificación
class StampService {
  /// Obtiene todas las estampas disponibles
  static Future<List<StampModel>> getAllStamps() async {
    try {
      final response = await ApiService.getStamps();
      if (response != null && response['success'] == true) {
        final data = response['data'] as List<dynamic>?;
        return data?.map((e) => StampModel.fromJson(e)).toList() ?? [];
      }
    } catch (e) {
      print('[StampService] Error cargando estampas: $e');
    }
    return [];
  }

  /// Obtiene las estampas del usuario (con estado unlocked)
  static Future<List<StampModel>> getUserStamps() async {
    try {
      final response = await ApiService.getUserStamps();
      if (response != null && response['success'] == true) {
        final data = response['data'] as List<dynamic>?;
        return data?.map((e) => StampModel.fromJson(e)).toList() ?? [];
      }
    } catch (e) {
      print('[StampService] Error cargando estampas del usuario: $e');
    }
    return [];
  }

  /// Reclamar una estampa al identificar un monumento
  static Future<Map<String, dynamic>?> claimStamp({
    required int atractivoId,
    int? estampaId,
  }) async {
    try {
      return await ApiService.claimStamp(
        atractivoId: atractivoId,
        estampaId: estampaId,
      );
    } catch (e) {
      print('[StampService] Error reclamando estampa: $e');
      return null;
    }
  }

  /// Marcar estampa como compartida
  static Future<bool> shareStamp(int estampaId) async {
    try {
      final response = await ApiService.shareStamp(estampaId);
      return response != null && response['success'] == true;
    } catch (e) {
      print('[StampService] Error compartiendo estampa: $e');
      return false;
    }
  }
}

/// Servicio de logros
class AchievementService {
  /// Obtiene todos los logros disponibles
  static Future<List<AchievementModel>> getAllAchievements() async {
    try {
      final response = await ApiService.getAchievements();
      if (response != null && response['success'] == true) {
        final data = response['data'] as List<dynamic>?;
        return data?.map((e) => AchievementModel.fromJson(e)).toList() ?? [];
      }
    } catch (e) {
      print('[AchievementService] Error cargando logros: $e');
    }
    return [];
  }

  /// Obtiene los logros del usuario con progreso
  static Future<List<AchievementModel>> getUserAchievements() async {
    try {
      final response = await ApiService.getUserAchievements();
      if (response != null && response['success'] == true) {
        final data = response['data'] as List<dynamic>?;
        return data?.map((e) => AchievementModel.fromJson(e)).toList() ?? [];
      }
    } catch (e) {
      print('[AchievementService] Error cargando logros del usuario: $e');
    }
    return [];
  }
}

/// Servicio de gamificación (resumen)
class GamificationService {
  static GamificationSummary? _cachedSummary;

  /// Obtiene el resumen de gamificación del usuario
  static Future<GamificationSummary> getSummary() async {
    try {
      final response = await ApiService.getGamificationSummary();
      if (response != null && response['success'] == true) {
        _cachedSummary = GamificationSummary.fromJson(response);
        return _cachedSummary!;
      }
    } catch (e) {
      print('[GamificationService] Error cargando resumen: $e');
    }
    return GamificationSummary();
  }

  /// Resumen cacheado
  static GamificationSummary? get cachedSummary => _cachedSummary;

  /// Invalida el cache
  static void invalidateCache() {
    _cachedSummary = null;
  }
}
