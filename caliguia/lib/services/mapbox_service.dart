import 'dart:math';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';

/// Servicio para gestionar el mapa de Mapbox.
/// Inicializa el mapa, configura el estilo oscuro, y gestiona la cámara.
class MapboxService {
  // TODO: Reemplazar con tu token de Mapbox real antes de compilar
  static const String _mapboxAccessToken = 
      'TU_MAPBOX_ACCESS_TOKEN_AQUI';
  
  /// Token de acceso para Mapbox
  static String get accessToken => _mapboxAccessToken;
  
  /// Estilo Standard de Mapbox (requerido para edificios 3D nativos)
  static const String styleUri = MapboxStyles.STANDARD;
  
  /// Posición inicial: Cali, Colombia
  static final CameraOptions initialCamera = CameraOptions(
    center: Point(coordinates: Position(-76.5325, 3.4519)),
    zoom: 15.5,
    pitch: 45.0,
    bearing: -17.6,
  );
  
  /// Configuración de cámara para vista general de Cali
  static final CameraOptions overviewCamera = CameraOptions(
    center: Point(coordinates: Position(-76.5325, 3.4519)),
    zoom: 12.0,
    pitch: 0.0,
    bearing: 0.0,
  );
  
  /// Configuración de cámara para ver edificios 3D
  static final CameraOptions buildingsCamera = CameraOptions(
    center: Point(coordinates: Position(-76.5325, 3.4519)),
    zoom: 15.5,
    pitch: 60.0,
    bearing: -17.6,
  );
  
  /// Inicializa el token de Mapbox
  static void initialize() {
    MapboxOptions.setAccessToken(_mapboxAccessToken);
  }
  
  /// Obtiene opciones de cámara centrada en una posición específica
  static CameraOptions cameraAtPosition(double lat, double lon, {double zoom = 14.0}) {
    return CameraOptions(
      center: Point(coordinates: Position(lon, lat)),
      zoom: zoom,
      pitch: 45.0,
    );
  }
  
  /// Habilita capa de edificios 3D en el estilo del mapa
  static Future<void> enableBuildings3D(MapboxMap mapboxMap) async {
    try {
      final style = mapboxMap.style;
      
      // Verificar si la capa ya existe
      final layers = await style.getStyleLayers();
      bool has3DBuildings = false;
      for (final layer in layers) {
        if (layer?.id == '3d-buildings') {
          has3DBuildings = true;
          break;
        }
      }
      
        if (!has3DBuildings) {
        // Crear capa de edificios 3D
        final source = await style.getSource('composite');
        if (source != null) {
          final fillExtrusionLayer = FillExtrusionLayer(
            id: '3d-buildings',
            sourceId: 'composite',
            sourceLayer: 'building',
            filter: ['==', ['get', 'extrude'], 'true'],
            minZoom: 15.0,
            fillExtrusionColor: 0xFF424242,
            fillExtrusionOpacity: 0.6,
          );
          
          await style.addLayer(fillExtrusionLayer);
        }
      }
    } catch (e) {
      print('[MapboxService] Error habilitando edificios 3D: $e');
    }
  }
  
  /// Colores para categorías de atractivos
  static int getMarkerColor(String? categoria, bool isEmblematico) {
    if (isEmblematico) {
      return 0xFFFFB300; // Dorado
    }
    
    final cat = categoria?.toLowerCase() ?? '';
    
    if (cat.contains('salsa') || cat.contains('música') || cat.contains('cultura')) {
      return 0xFFD32F2F; // Rojo
    } else if (cat.contains('naturaleza') || cat.contains('parque') || cat.contains('ecoturismo')) {
      return 0xFF2E7D32; // Verde
    } else if (cat.contains('historia') || cat.contains('patrimonio') || cat.contains('religioso')) {
      return 0xFF5D4037; // Café
    } else if (cat.contains('deportivo') || cat.contains('estadio')) {
      return 0xFF1565C0; // Azul
    } else if (cat.contains('gastronomía') || cat.contains('comida')) {
      return 0xFFE65100; // Naranja oscuro
    }
    
    return 0xFF757575; // Gris por defecto
  }
  
  /// Tamaño del marcador según importancia
  static double getMarkerSize(bool isEmblematico) {
    return isEmblematico ? 1.5 : 1.0;
  }

  /// Calcula distancia Haversine entre dos coordenadas (en metros)
  static double calculateDistance(double lat1, double lon1, double lat2, double lon2) {
    const R = 6371000; // Radio de la Tierra en metros
    final phi1 = lat1 * pi / 180;
    final phi2 = lat2 * pi / 180;
    final dphi = (lat2 - lat1) * pi / 180;
    final dlambda = (lon2 - lon1) * pi / 180;

    final a = sin(dphi / 2) * sin(dphi / 2) +
        cos(phi1) * cos(phi2) * sin(dlambda / 2) * sin(dlambda / 2);
    final c = 2 * atan2(sqrt(a), sqrt(1 - a));

    return R * c;
  }
}
