import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:geolocator/geolocator.dart' as geo;
import 'package:http/http.dart' as http;
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import '../services/audio_player_service.dart';
import '../services/route_notifier.dart';
import '../models/route_request.dart';
import '../widgets/avatar_caleno.dart';
import '../widgets/bichofue_avatar.dart';
import '../main.dart';
import '../models/map_marker_model.dart';
import '../services/api_service.dart';
import '../services/database_service.dart';
import '../services/database_helper.dart';
import '../services/mapbox_service.dart';
import '../services/preferences_service.dart';
import '../services/notification_service.dart';
import 'attraction_detail_screen.dart';
import 'attractions_list_screen.dart';
import 'camera_screen.dart';
import 'eventos_screen.dart';

/// Constantes de configuración del mapa estilo Pokémon GO
class MapConfig {
  static const double discoveryRadiusMeters = 500.0;
  static const double defaultZoom = 16.0;
  static const double minZoom = 14.0;
  static const double maxZoom = 18.0;
  static const double defaultPitch = 45.0;
  static const double markerTapZoom = 18.0;
  static const double markerTapPitch = 60.0;
}

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  MapboxMap? _mapboxMap;
  PointAnnotationManager? _pointAnnotationManager;
  PolylineAnnotationManager? _polylineAnnotationManager;

  List<MapMarkerModel> _allMarkers = [];
  List<MapMarkerModel> _visibleMarkers = [];

  bool _isLoading = true;
  bool _isOnline = false;
  bool _isSimulationMode = false;
  bool _nightMode = false;
  geo.Position? _currentPosition;
  geo.Position? _simulatedPosition;
  StreamSubscription<geo.Position>? _positionStream;
  
  /// Pasos de navegacion de la ruta actual
  List<Map<String, dynamic>> _routeSteps = [];

  /// Ruta pendiente recibida desde el chat antes de que el mapa esté listo
  RouteRequest? _pendingRoute;

  /// Marcadores activos en modo ruta (solo muestra estos, oculta el resto)
  List<MapMarkerModel>? _routeOnlyMarkers;

  /// Cache de imágenes de marcadores cargadas como bytes (iconos por categoría)
  final Map<String, Uint8List> _markerImages = {};

  /// Cache de fotos descargadas de cada atractivo (key: marker.id)
  final Map<int, Uint8List> _photoCache = {};

  /// Cache de fotos procesadas (circulares con borde, key: marker.id)
  final Map<int, Uint8List> _processedPhotoCache = {};

  /// Zonas WiFi gratuitas cercanas
  List<dynamic> _wifiZones = [];
  bool _showWifiZones = false;

  @override
  void initState() {
    super.initState();
    _loadNightMode();
    _initLocation();

    // Si ya hay URL configurada, cargar marcadores inmediatamente
    if (ApiService.isConfigured) {
      _loadMarkers();
    } else {
      // Esperar a que el backend sea descubierto
      print('[Map] ⏳ Esperando descubrimiento del backend...');
      ApiService.connectionNotifier.addListener(_onBackendConnected);
    }

    // Escuchar rutas emitidas desde el chat
    RouteNotifier.instance.addListener(_onRouteFromChat);
  }

  Future<void> _loadWifiZones() async {
    try {
      final pos = _effectivePosition;
      if (pos == null) return;
      final zones = await ApiService.getWifiZones(pos.latitude, pos.longitude);
      if (mounted) {
        setState(() => _wifiZones = zones);
      }
    } catch (e) {
      print('[Map] Error cargando WiFi: $e');
    }
  }

  void _toggleWifiZones() {
    setState(() {
      _showWifiZones = !_showWifiZones;
    });
    if (_showWifiZones) {
      _loadWifiZones();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Mostrando zonas WiFi gratis'),
          backgroundColor: BichofueColors.verde,
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  void _onRouteFromChat() {
    final route = RouteNotifier.current;
    if (route == null || !mounted) return;

    if (_mapboxMap == null) {
      // Mapa todavía no está listo, guardar para aplicar luego
      print('[Map] ⏳ Ruta recibida pero mapa no está listo, guardando: ${route.name}');
      _pendingRoute = route;
      return;
    }

    print('[Map] 🗺️ Ruta recibida desde chat: ${route.name}');
    _drawMultiStopRoute(route);
  }

  /// Aplica una ruta pendiente cuando el mapa se inicializa
  void _applyPendingRoute() {
    if (_pendingRoute != null && _mapboxMap != null) {
      print('[Map] 🗺️ Aplicando ruta pendiente: ${_pendingRoute!.name}');
      final route = _pendingRoute!;
      _pendingRoute = null;
      _drawMultiStopRoute(route);
    }
  }

  /// Se llama cuando el backend es descubierto/conectado
  void _onBackendConnected() {
    if (ApiService.isConfigured && mounted) {
      print('[Map] 🌐 Backend conectado: ${ApiService.baseUrl}');
      _loadMarkers();
      // Solo escuchamos una vez
      ApiService.connectionNotifier.removeListener(_onBackendConnected);
    }
  }

  @override
  void dispose() {
    _positionStream?.cancel();
    ApiService.connectionNotifier.removeListener(_onBackendConnected);
    RouteNotifier.instance.removeListener(_onRouteFromChat);
    super.dispose();
  }

  /// Carga el estado del modo nocturno
  Future<void> _loadNightMode() async {
    final enabled = await PreferencesService.isNightModeEnabled();
    setState(() => _nightMode = enabled);
    if (enabled) {
      print('[Map] 🌙 Modo nocturno activado');
    }
  }

  /// Heurística para determinar si un lugar está abierto de noche
  /// basado en el campo horario (texto libre)
  bool _isOpenAtNight(MapMarkerModel marker) {
    final horario = marker.horario?.toLowerCase() ?? '';
    
    // Vacío o nulo: horario desconocido, mostrar de todos modos
    if (horario.isEmpty) return true;
    
    // Palabras clave que indican abierto de noche
    final openNightIndicators = [
      '24h', '24 horas', '24hrs', 'todo el día', 'siempre abierto',
      '6pm', '7pm', '8pm', '9pm', '10pm', '11pm', '12am', '1am', '2am', '3am', '4am',
      '18:', '19:', '20:', '21:', '22:', '23:', '00:', '01:', '02:', '03:', '04:',
    ];
    
    for (final indicator in openNightIndicators) {
      if (horario.contains(indicator)) return true;
    }
    
    // Palabras clave que indican CERRADO de noche
    final closedNightIndicators = [
      '6am - 6pm', '7am - 5pm', '8am - 4pm', '9am - 5pm',
      'lunes a viernes 8', 'solo dias', 'solo días',
    ];
    
    for (final indicator in closedNightIndicators) {
      if (horario.contains(indicator)) return false;
    }
    
    // Por defecto: mostrar (horario ambiguo)
    return true;
  }
  
  Future<void> _loadMarkers() async {
    print('[Map] 📍 _loadMarkers iniciado');
    setState(() => _isLoading = true);
    
    List<dynamic> atractivos = [];
    
    try {
      print('[Map] 🌐 Intentando cargar desde API...');
      atractivos = await ApiService.getAtractivos();
      if (atractivos.isNotEmpty) {
        setState(() => _isOnline = true);
        print('[Map] ✅ ${atractivos.length} marcadores cargados desde API (online)');
      } else {
        print('[Map] ⚠️ API respondió vacía');
      }
    } catch (e) {
      print('[Map] ❌ Error API: $e');
    }
    
    if (atractivos.isEmpty) {
      try {
        print('[Map] 💾 Intentando cargar desde base de datos local...');
        final offlineData = await DatabaseService.getAtractivos();
        atractivos = offlineData;
        if (atractivos.isNotEmpty) {
          print('[Map] ✅ ${atractivos.length} marcadores cargados desde DB local (offline)');
        }
      } catch (e) {
        print('[Map] ❌ Error DB local: $e');
      }
    }
    
    _allMarkers = atractivos.map((atr) => MapMarkerModel.fromJson(atr)).toList();
    print('[Map] 📊 Total marcadores en memoria: ${_allMarkers.length}');

    // Log detallado de cada marcador (especialmente imagenUrl)
    for (final m in _allMarkers) {
      final hasImage = m.imagenUrl != null && m.imagenUrl!.isNotEmpty;
      print('[Map]   📍 id=${m.id} "${m.nombre}" | lat=${m.latitude} lon=${m.longitude} | imagenUrl=${m.imagenUrl ?? "(null)"} | hasImage=$hasImage');
    }

    // Filtrar por distancia si tenemos posición (real o simulada)
    if (_effectivePosition != null) {
      print('[Map] 📍 Posición conocida, filtrando por distancia...');
      _updateVisibleMarkers();
    } else {
      print('[Map] 📍 Sin posición aún, mostrando todos los marcadores');
      setState(() {
        _visibleMarkers = _allMarkers;
        _isLoading = false;
      });
    }
  }

  /// Posición efectiva: simulada si está activa, sino la real
  geo.Position? get _effectivePosition => _simulatedPosition ?? _currentPosition;

  void _updateVisibleMarkers() {
    print('[Map] 📍 _updateVisibleMarkers (modo simulación: $_isSimulationMode)');
    if (_effectivePosition == null) {
      print('[Map] 📍 Sin posición, mostrando todos (${_allMarkers.length})');
      setState(() {
        _visibleMarkers = _allMarkers;
        _isLoading = false;
      });
      return;
    }

    var nearby = _allMarkers.where((m) {
      if (m.latitude == null || m.longitude == null) return false;
      final dist = MapboxService.calculateDistance(
        _effectivePosition!.latitude,
        _effectivePosition!.longitude,
        m.latitude!,
        m.longitude!,
      );
      return dist <= MapConfig.discoveryRadiusMeters;
    }).toList();

    // Filtrar por modo nocturno
    if (_nightMode) {
      nearby = nearby.where((m) => _isOpenAtNight(m)).toList();
      print('[Map] 🌙 Modo nocturno: ${nearby.length} lugares abiertos de noche');
    }

    print('[Map] 📍 ${_allMarkers.length} totales, ${nearby.length} dentro de ${MapConfig.discoveryRadiusMeters}m');
    setState(() {
      _visibleMarkers = nearby;
      _isLoading = false;
    });

    // Actualizar marcadores en el mapa
    if (_pointAnnotationManager != null) {
      _addMarkersToMap();
    }
  }

  Future<void> _initLocation() async {
    print('[Map] 🛰️ _initLocation iniciado');
    try {
      bool serviceEnabled = await geo.Geolocator.isLocationServiceEnabled();
      print('[Map] 🛰️ GPS habilitado: $serviceEnabled');
      if (!serviceEnabled) {
        print('[Map] 🛰️ GPS deshabilitado');
        _showGPSDisabledDialog();
        return;
      }

      geo.LocationPermission permission = await geo.Geolocator.checkPermission();
      print('[Map] 🛰️ Permiso inicial: $permission');
      if (permission == geo.LocationPermission.denied) {
        print('[Map] 🛰️ Solicitando permiso...');
        permission = await geo.Geolocator.requestPermission();
        print('[Map] 🛰️ Permiso después de solicitar: $permission');
        if (permission == geo.LocationPermission.denied) return;
      }
      if (permission == geo.LocationPermission.deniedForever) return;

      // Obtener posición actual (solo para filtrar marcadores)
      print('[Map] 🛰️ Obteniendo posición actual...');
      final position = await geo.Geolocator.getCurrentPosition();
      print('[Map] ✅ Posición obtenida: ${position.latitude}, ${position.longitude} (accuracy: ${position.accuracy}m)');
      setState(() => _currentPosition = position);
      _updateVisibleMarkers();

      // Escuchar cambios de posición (filtrar marcadores + seguir cámara)
      print('[Map] 🛰️ Iniciando stream de posición...');
      _positionStream = geo.Geolocator.getPositionStream(
        locationSettings: const geo.LocationSettings(
          accuracy: geo.LocationAccuracy.high,
          distanceFilter: 5,
        ),
      ).listen((geo.Position position) {
        if (_isSimulationMode) {
          print('[Map] 🛰️ GPS real ignorado (modo simulación activo)');
          return;
        }
        print('[Map] 🛰️ Posición actualizada: ${position.latitude}, ${position.longitude} | accuracy: ${position.accuracy}m | heading: ${position.heading}°');
        setState(() => _currentPosition = position);
        _updateVisibleMarkers();
        _easeToPosition(position.latitude, position.longitude, bearing: position.heading);
        _checkGeofencing();
      });
      print('[Map] 🛰️ Stream de posición activo');
    } catch (e) {
      print('[Map] ❌ Error GPS: $e');
    }
  }

  /// Muestra un diálogo amable si el GPS está desactivado
  void _showGPSDisabledDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.location_disabled, color: BichofueColors.cafe),
            const SizedBox(width: 8),
            Flexible(
              child: const Text('GPS desactivado', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
        content: const Text(
          'Para que el mapa funcione correctamente necesitas activar el GPS de tu dispositivo.\n\n'
          'Ve a Configuración > Ubicación y actívalo.',
          style: TextStyle(fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Entendido'),
          ),
        ],
      ),
    );
  }

  void _centerOnUser() async {
    print('[Map] 🎯 Botón "Centrar en mí" presionado');
    if (_mapboxMap == null) return;

    if (_effectivePosition == null) {
      print('[Map] ⚠️ Sin posición actual, intentando obtener...');
      try {
        final pos = await geo.Geolocator.getCurrentPosition();
        print('[Map] ✅ Posición obtenida bajo demanda: ${pos.latitude}, ${pos.longitude}');
        setState(() => _currentPosition = pos);
        _updateVisibleMarkers();
        await _flyToPosition(pos.latitude, pos.longitude, bearing: pos.heading);
      } catch (e) {
        print('[Map] ❌ No se pudo obtener posición: $e');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No se pudo obtener tu ubicación. Verifica el GPS.'),
            backgroundColor: BichofueColors.cafe,
          ),
        );
      }
      return;
    }

    print('[Map] 🎯 Centrando en ${_effectivePosition!.latitude}, ${_effectivePosition!.longitude}');
    await _flyToPosition(
      _effectivePosition!.latitude,
      _effectivePosition!.longitude,
      bearing: _effectivePosition!.heading,
    );
  }

  /// Alterna el modo de simulación GPS
  void _toggleSimulationMode() {
    setState(() {
      _isSimulationMode = !_isSimulationMode;
      if (!_isSimulationMode) {
        // Al desactivar, limpiar posición simulada y volver a GPS real
        _simulatedPosition = null;
        print('[Map] 🎮 Modo simulación DESACTIVADO');
        // Si hay posición real, volver a ella
        if (_currentPosition != null) {
          _updateVisibleMarkers();
          _flyToPosition(_currentPosition!.latitude, _currentPosition!.longitude);
        }
      } else {
        print('[Map] 🎮 Modo simulación ACTIVADO - Toca el mapa para teletransportarte');
      }
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_isSimulationMode
              ? '🎮 Modo simulación activo - Toca el mapa para moverte'
              : '📍 GPS real restaurado'),
          backgroundColor: _isSimulationMode ? BichofueColors.amarillo : BichofueColors.verde,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  /// Se llama cuando se toca el mapa en modo simulación
  void _onMapTapSimulation(ScreenCoordinate coordinate) async {
    if (!_isSimulationMode || _mapboxMap == null) return;

    try {
      final point = await _mapboxMap!.coordinateForPixel(coordinate);
      final lat = point.coordinates.lat.toDouble();
      final lon = point.coordinates.lng.toDouble();

      print('[Map] 🎮 Simulación: tocado en $lat, $lon');

      // Crear una Position simulada (sin accuracy ni heading reales)
      final simulatedPos = geo.Position(
        latitude: lat,
        longitude: lon,
        timestamp: DateTime.now(),
        accuracy: 0,
        altitude: 0,
        heading: 0,
        speed: 0,
        speedAccuracy: 0,
        altitudeAccuracy: 0,
        headingAccuracy: 0,
      );

      setState(() {
        _simulatedPosition = simulatedPos;
      });

      // Actualizar marcadores y centrar cámara
      _updateVisibleMarkers();
      await _flyToPosition(lat, lon);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('🎮 Simulando: ${lat.toStringAsFixed(4)}, ${lon.toStringAsFixed(4)}'),
            backgroundColor: BichofueColors.amarillo,
            duration: const Duration(seconds: 1),
          ),
        );
      }
    } catch (e) {
      print('[Map] ❌ Error en simulación: $e');
    }
  }

  Future<void> _flyToPosition(double lat, double lon, {double? bearing}) async {
    if (_mapboxMap == null) return;
    try {
      print('[Map] 🎥 flyTo: $lat, $lon (bearing: $bearing)');
      await _mapboxMap!.flyTo(
        CameraOptions(
          center: Point(coordinates: Position(lon, lat)),
          zoom: MapConfig.defaultZoom,
          pitch: MapConfig.defaultPitch,
          bearing: bearing,
        ),
        MapAnimationOptions(duration: 1000),
      );
      print('[Map] ✅ flyTo completado');
    } catch (e) {
      print('[Map] ❌ Error en flyTo: $e');
    }
  }

  Future<void> _easeToPosition(double lat, double lon, {double? bearing}) async {
    if (_mapboxMap == null) return;
    try {
      await _mapboxMap!.easeTo(
        CameraOptions(
          center: Point(coordinates: Position(lon, lat)),
          zoom: MapConfig.defaultZoom,
          pitch: MapConfig.defaultPitch,
          bearing: bearing,
        ),
        MapAnimationOptions(duration: 500),
      );
    } catch (e) {
      // Fallback a flyTo si easeTo no está disponible
      await _flyToPosition(lat, lon, bearing: bearing);
    }
  }
  
  void _onMapCreated(MapboxMap mapboxMap) async {
    print('[Map] 🗺️ onMapCreated llamado');
    _mapboxMap = mapboxMap;

    // 1. Límites de zoom
    print('[Map] 🗺️ Configurando límites de zoom: ${MapConfig.minZoom} - ${MapConfig.maxZoom}');
    await mapboxMap.setBounds(CameraBoundsOptions(
      minZoom: MapConfig.minZoom,
      maxZoom: MapConfig.maxZoom,
    ));

    // 2. Habilitar movimiento manual (scroll/pan)
    await mapboxMap.gestures.updateSettings(GesturesSettings(
      scrollEnabled: true,
      pinchPanEnabled: true,
      rotateEnabled: true,
      pitchEnabled: true,
      pinchToZoomEnabled: true,
      doubleTapToZoomInEnabled: true,
      doubleTouchToZoomOutEnabled: true,
    ));

    // 3. Location puck nativo con heading
    print('[Map] 🗺️ Activando location puck nativo');
    print('[Map] 🗺️ Location puck config: pulsingEnabled=true, pulsingMaxRadius=80.0px, showAccuracyRing=true, accuracyRingColor=#29B6F6');
    await mapboxMap.location.updateSettings(LocationComponentSettings(
      enabled: true,
      puckBearing: PuckBearing.HEADING,
      locationPuck: LocationPuck(
        locationPuck2D: DefaultLocationPuck2D(),
      ),
      pulsingEnabled: true,
      pulsingColor: 0xFF29B6F6,
      pulsingMaxRadius: 80.0,
      showAccuracyRing: true,
      accuracyRingColor: 0xFF29B6F6,
      accuracyRingBorderColor: 0xFFFFFFFF,
    ));

    // 4. Edificios 3D nativos (solo con STANDARD) + Tema oscuro personalizado
    print('[Map] 🗺️ Habilitando edificios 3D nativos y tema oscuro');
    try {
      await mapboxMap.style.setStyleImportConfigProperty(
        "basemap", "show3dObjects", true,
      );
      print('[Map] ✅ Edificios 3D activados');
      await _applyDarkTheme(mapboxMap);
    } catch (e) {
      print('[Map] ❌ Error activando edificios 3D: $e');
    }

    // 5. Si ya tenemos posición, mover cámara ahí (evita quedar en Cali)
    if (_currentPosition != null) {
      print('[Map] 🗺️ Posición conocida, moviendo cámara a usuario');
      await _flyToPosition(
        _currentPosition!.latitude,
        _currentPosition!.longitude,
        bearing: _currentPosition!.heading,
      );
    } else {
      print('[Map] 🗺️ Sin posición aún, cámara queda en Cali hasta obtener GPS');
    }

    // 6. Crear manager de anotaciones
    print('[Map] 🗺️ Creando PointAnnotationManager');
    _pointAnnotationManager = await mapboxMap.annotations.createPointAnnotationManager();

    // 7. Precargar imágenes de marcadores como bytes
    print('[Map] 🗺️ Precargando imágenes de marcadores...');
    await _preloadMarkerImages();

    // 8. Agregar marcadores
    if (_visibleMarkers.isNotEmpty) {
      print('[Map] 🗺️ Agregando ${_visibleMarkers.length} marcadores al mapa');
      await _addMarkersToMap();
    } else {
      print('[Map] 🗺️ No hay marcadores visibles para agregar aún');
    }

    // 9. Listener de toque en el mapa para modo simulación
    mapboxMap.setOnMapTapListener((context) {
      if (_isSimulationMode) {
        _onMapTapSimulation(context.touchPosition);
      }
    });

    // 10. Aplicar ruta pendiente recibida desde el chat antes de que el mapa estuviera listo
    _applyPendingRoute();

    print('[Map] ✅ onMapCreated completado');
  }

  Future<void> _preloadMarkerImages() async {
    final markerPaths = {
      'marker_emblematico': 'assets/images/markers/marker_emblematico.png',
      'marker_salsa': 'assets/images/markers/marker_salsa.png',
      'marker_naturaleza': 'assets/images/markers/marker_naturaleza.png',
      'marker_historia': 'assets/images/markers/marker_historia.png',
      'marker_deportivo': 'assets/images/markers/marker_deportivo.png',
      'marker_default': 'assets/images/markers/marker_default.png',
    };

    for (final entry in markerPaths.entries) {
      try {
        final bytes = await rootBundle.load(entry.value);
        _markerImages[entry.key] = bytes.buffer.asUint8List();
        print('[Map] ✅ Imagen cargada: ${entry.key}');
      } catch (e) {
        print('[Map] ❌ Error cargando imagen ${entry.key}: $e');
      }
    }
  }

  /// Aplica un tema oscuro personalizado al estilo STANDARD usando setStyleImportConfigProperty
  Future<void> _applyDarkTheme(MapboxMap mapboxMap) async {
    print('[Map] 🎨 Aplicando tema oscuro personalizado...');
    try {
      final style = mapboxMap.style;

      // Configuraciones del import 'basemap' para look oscuro elegante
      final themeConfig = {
        'lightPreset': 'night',
        'colorBuildings': '#8a8a8a',
        'colorWater': '#1a2332',
        'colorLand': '#0d1117',
        'colorRoads': '#4a5359',
        'colorRoadLabels': '#8b949e',
        'colorGreenspace': '#1e272e',
        'colorPlaceLabels': '#c9d1d9',
        'colorPointOfInterestLabels': '#b2bec3',
        'colorAdminBoundaries': '#30363d',
        'colorMotorways': '#3d5a80',
        'colorTrunks': '#4a4e69',
        'colorCommercial': '#2d3436',
        'colorIndustrial': '#1c2126',
        'colorEducation': '#2d3436',
        'colorMedical': '#2d3436',
      };

      for (final entry in themeConfig.entries) {
        try {
          await style.setStyleImportConfigProperty('basemap', entry.key, entry.value);
          print('[Map]   🎨 $entry.key = ${entry.value}');
        } catch (e) {
          print('[Map]   ⚠️ No se pudo aplicar ${entry.key}: $e');
        }
      }

      print('[Map] ✅ Tema oscuro aplicado correctamente');
    } catch (e) {
      print('[Map] ❌ Error aplicando tema oscuro: $e');
    }
  }

  String _getMarkerIconName(MapMarkerModel marker) {
    if (marker.isEmblematico) return 'marker_emblematico';

    final cat = marker.categoria?.toLowerCase() ?? '';
    if (cat.contains('salsa') || cat.contains('música') || cat.contains('cultura')) {
      return 'marker_salsa';
    } else if (cat.contains('naturaleza') || cat.contains('parque') || cat.contains('ecoturismo')) {
      return 'marker_naturaleza';
    } else if (cat.contains('historia') || cat.contains('patrimonio') || cat.contains('religioso')) {
      return 'marker_historia';
    } else if (cat.contains('deportivo') || cat.contains('estadio')) {
      return 'marker_deportivo';
    }
    return 'marker_default';
  }

  /// Descarga la foto de un marcador desde el backend y la cachea
  Future<Uint8List?> _downloadMarkerImage(MapMarkerModel marker) async {
    print('[Map] 📥 _downloadMarkerImage: id=${marker.id} "${marker.nombre}" | imagenUrl=${marker.imagenUrl ?? "(null)"} | isConfigured=${ApiService.isConfigured} | baseUrl=${ApiService.baseUrl}');

    if (marker.imagenUrl == null || marker.imagenUrl!.isEmpty) {
      print('[Map]   ⚠️ Sin imagenUrl, saltando descarga');
      return null;
    }
    if (!ApiService.isConfigured) {
      print('[Map]   ⚠️ ApiService no configurado, saltando descarga');
      return null;
    }

    // 1. Verificar cache en RAM
    if (_photoCache.containsKey(marker.id)) {
      print('[Map]   💾 Usando cache RAM para ${marker.nombre} (${_photoCache[marker.id]!.length} bytes)');
      return _photoCache[marker.id];
    }
    // 2. Verificar cache en SQLite
    try {
      final cached = await DatabaseHelper().getCachedPhoto(marker.id);
      if (cached != null) {
        _photoCache[marker.id] = cached;
        print('[Map]   🗄️ Usando cache SQLite para ${marker.nombre} (${cached.length} bytes)');
        return cached;
      }
    } catch (e) {
      print('[Map]   ⚠️ Error leyendo cache SQLite para ${marker.nombre}: $e');
    }

    try {
      final imageUrl = '${ApiService.baseUrl}${marker.imagenUrl}';
      print('[Map]   🌐 Descargando: $imageUrl');
      final response = await http
          .get(Uri.parse(imageUrl))
          .timeout(const Duration(seconds: 3));

      print('[Map]   📡 Respuesta: status=${response.statusCode} | contentType=${response.headers['content-type']} | bytes=${response.bodyBytes.length}');

      if (response.statusCode == 200 && response.bodyBytes.isNotEmpty) {
        // Guardar en RAM y en SQLite
        _photoCache[marker.id] = response.bodyBytes;
        try {
          await DatabaseHelper().saveCachedPhoto(marker.id, response.bodyBytes);
        } catch (e) {
          print('[Map]   ⚠️ Error guardando en cache SQLite: $e');
        }
        print('[Map]   ✅ Foto descargada OK: ${marker.nombre} (${response.bodyBytes.length} bytes)');
        return response.bodyBytes;
      } else {
        print('[Map]   ⚠️ Foto no disponible (status=${response.statusCode}, bytes=${response.bodyBytes.length}): ${marker.nombre}');
      }
    } catch (e) {
      print('[Map]   ❌ Error descargando foto de ${marker.nombre}: $e');
    }
    return null;
  }

  /// Procesa una imagen para que sea circular tipo Instagram Story con borde
  Future<Uint8List> _processMarkerImage(Uint8List bytes, bool isEmblematico) async {
    final int size = isEmblematico ? 80 : 64;
    final double borderWidth = isEmblematico ? 3.0 : 2.0;
    final Color borderColor = isEmblematico ? const Color(0xFFFFB300) : Colors.white;

    // 1. Decodificar imagen original
    final codec = await ui.instantiateImageCodec(bytes);
    final frame = await codec.getNextFrame();
    final originalImage = frame.image;

    // 2. Crear canvas del tamaño deseado
    final recorder = ui.PictureRecorder();
    final canvas = ui.Canvas(recorder, ui.Rect.fromLTWH(0, 0, size.toDouble(), size.toDouble()));

    final center = Offset(size / 2, size / 2);
    final outerRadius = size / 2;
    final innerRadius = outerRadius - borderWidth;

    // 3. Dibujar borde circular (fondo)
    final borderPaint = Paint()
      ..color = borderColor
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, outerRadius, borderPaint);

    // 4. Clip circular interno para la foto
    final clipPath = Path()..addOval(Rect.fromCircle(center: center, radius: innerRadius));
    canvas.clipPath(clipPath);

    // 5. Calcular rect src (cover - recortar centro)
    final srcRect = _calculateCoverRect(
      originalImage.width.toDouble(),
      originalImage.height.toDouble(),
      size.toDouble(),
      size.toDouble(),
    );
    final dstRect = ui.Rect.fromLTWH(0, 0, size.toDouble(), size.toDouble());

    // 6. Dibujar imagen redimensionada
    canvas.drawImageRect(originalImage, srcRect, dstRect, Paint());

    // 7. Codificar a PNG
    final picture = recorder.endRecording();
    final img = await picture.toImage(size, size);
    final byteData = await img.toByteData(format: ui.ImageByteFormat.png);

    return byteData!.buffer.asUint8List();
  }

  /// Calcula el rectángulo de source para cover (recortar centro)
  ui.Rect _calculateCoverRect(double srcW, double srcH, double dstW, double dstH) {
    final srcAspect = srcW / srcH;
    final dstAspect = dstW / dstH;

    double w, h, x, y;
    if (srcAspect > dstAspect) {
      // Imagen más ancha que alta: recortar lados
      h = srcH;
      w = srcH * dstAspect;
      x = (srcW - w) / 2;
      y = 0;
    } else {
      // Imagen más alta que ancha: recortar arriba/abajo
      w = srcW;
      h = srcW / dstAspect;
      x = 0;
      y = (srcH - h) / 2;
    }
    return ui.Rect.fromLTWH(x, y, w, h);
  }

  Future<void> _addMarkersToMap() async {
    if (_pointAnnotationManager == null) {
      print('[Map] ⚠️ _addMarkersToMap: PointAnnotationManager es null');
      return;
    }

    try {
      print('[Map] 🗑️ Eliminando marcadores anteriores...');
      await _pointAnnotationManager!.deleteAll();

      final markersToShow = _routeOnlyMarkers ?? _visibleMarkers;

      // Descargar fotos de marcadores visibles en paralelo
      print('[Map] 📥 Descargando fotos de ${markersToShow.length} marcadores...');
      final downloadFutures = markersToShow.map((m) => _downloadMarkerImage(m)).toList();
      await Future.wait(downloadFutures);
      print('[Map] ✅ Descargas completadas');

      final options = <PointAnnotationOptions>[];

      for (int i = 0; i < markersToShow.length; i++) {
        final marker = markersToShow[i];
        if (marker.latitude == null || marker.longitude == null) continue;

        // Prioridad: foto procesada > foto cruda > icono de categoría
        Uint8List? imageBytes;
        String imageSource;

        if (_processedPhotoCache.containsKey(marker.id)) {
          imageBytes = _processedPhotoCache[marker.id];
          imageSource = 'foto procesada (${imageBytes!.length} bytes)';
        } else if (_photoCache.containsKey(marker.id)) {
          // Procesar foto cruda a circular
          try {
            final processed = await _processMarkerImage(_photoCache[marker.id]!, marker.isEmblematico);
            _processedPhotoCache[marker.id] = processed;
            imageBytes = processed;
            imageSource = 'foto procesada (${processed.length} bytes)';
          } catch (e) {
            print('[Map]   ⚠️ Error procesando foto de ${marker.nombre}: $e');
            final iconName = _getMarkerIconName(marker);
            imageBytes = _markerImages[iconName] ?? _markerImages['marker_default'];
            imageSource = 'icono:$iconName (fallback procesamiento)';
          }
        } else {
          final iconName = _getMarkerIconName(marker);
          imageBytes = _markerImages[iconName] ?? _markerImages['marker_default'];
          imageSource = 'icono:$iconName';
        }

        print('[Map]   🖼️ Marcador #${marker.id} "${marker.nombre}" | imagenUrl=${marker.imagenUrl ?? "(null)"} | usa: $imageSource');

        options.add(PointAnnotationOptions(
          geometry: Point(coordinates: Position(marker.longitude!, marker.latitude!)),
          image: imageBytes,
          iconSize: marker.isEmblematico ? 1.4 : 1.0,
          iconAnchor: IconAnchor.BOTTOM,
          textField: marker.nombre,
          textSize: 11.0,
          textColor: Colors.white.value,
          textHaloColor: Colors.black.value,
          textHaloWidth: 2.0,
          textOffset: [0.0, 1.5],
        ));
      }

      print('[Map] ➕ Creando ${options.length} marcadores en el mapa');
      await _pointAnnotationManager!.createMulti(options);
      print('[Map] ✅ Marcadores creados');

      _pointAnnotationManager!.addOnPointAnnotationClickListener(
        _PointClickListener(this),
      );
    } catch (e) {
      print('[Map] ❌ Error agregando marcadores: $e');
    }
  }
  
  void _onMarkerTap(MapMarkerModel marker) async {
    print('[Map] 📌 Marcador tocado: ${marker.nombre}');
    if (_mapboxMap == null) return;

    // Zoom automático al lugar
    await _mapboxMap!.flyTo(
      CameraOptions(
        center: Point(coordinates: Position(marker.longitude!, marker.latitude!)),
        zoom: MapConfig.markerTapZoom,
        pitch: MapConfig.markerTapPitch,
      ),
      MapAnimationOptions(duration: 1000),
    );

    _showMarkerInfo(marker);
  }

  Future<void> _drawRoute(MapMarkerModel marker) async {
    if (_mapboxMap == null || _effectivePosition == null) return;
    print('[Map] 🛣️ Calculando ruta a ${marker.nombre}');

    try {
      // Limpiar ruta anterior
      await _clearRoute();

      final body = {
        'origin': {
          'lat': _effectivePosition!.latitude,
          'lon': _effectivePosition!.longitude,
        },
        'destination': {
          'lat': marker.latitude,
          'lon': marker.longitude,
        },
      };

      final response = await http.post(
        Uri.parse('${ApiService.baseUrl}/api/routes'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(body),
      ).timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true) {
          final coords = data['data']['coordinates'] as List;
          final distance = data['data']['distance_meters'];
          final duration = data['data']['duration_minutes'];
          final method = data['data']['method'];
          final steps = data['data']['steps'] as List? ?? [];
          print('[Map] ✅ Ruta: ${distance}m, ~${duration}min, method=$method');

          // Crear polyline manager si no existe
          if (_polylineAnnotationManager == null) {
            _polylineAnnotationManager = await _mapboxMap!.annotations.createPolylineAnnotationManager();
          }

          final positions = coords.map((c) => Position(c[0] as double, c[1] as double)).toList();
          await _polylineAnnotationManager!.create(PolylineAnnotationOptions(
            geometry: LineString(coordinates: positions),
            lineColor: 0xFF29B6F6,
            lineWidth: 4.0,
            lineOpacity: 0.8,
          ));

          setState(() {
            _routeSteps = steps.cast<Map<String, dynamic>>();
          });

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('🛣️ Ruta: ${distance}m • ~${duration} min${method == 'mapbox_directions' ? ' (por calles)' : ''}'),
                backgroundColor: BichofueColors.verde,
                duration: const Duration(seconds: 3),
                action: SnackBarAction(
                  label: 'Ver pasos',
                  textColor: BichofueColors.blanco,
                  onPressed: () => _showRouteSteps(),
                ),
              ),
            );
          }
        }
      }
    } catch (e) {
      print('[Map] ❌ Error calculando ruta: $e');
    }
  }

  Future<void> _drawMultiStopRoute(RouteRequest route) async {
    if (_mapboxMap == null || _effectivePosition == null) return;
    print('[Map] 🛣️ Dibujando ruta multi-parada: ${route.name}');

    await _clearRoute();

    final stops = route.stops;
    if (stops.isEmpty) return;

    // Construir lista de puntos: origen + todas las paradas
    final points = <Map<String, dynamic>>[
      {
        'lat': _effectivePosition!.latitude,
        'lon': _effectivePosition!.longitude,
        'name': 'Tu ubicación',
      },
      ...stops.map((s) => {'lat': s.lat, 'lon': s.lon, 'name': s.nombre}),
    ];

    double totalDistance = 0;
    double totalDuration = 0;
    final allSteps = <Map<String, dynamic>>[];

    // Crear polyline manager si no existe
    if (_polylineAnnotationManager == null) {
      _polylineAnnotationManager = await _mapboxMap!.annotations.createPolylineAnnotationManager();
    }

    // Dibujar segmento por segmento
    for (int i = 0; i < points.length - 1; i++) {
      final from = points[i];
      final to = points[i + 1];

      try {
        final body = {
          'origin': {'lat': from['lat'], 'lon': from['lon']},
          'destination': {'lat': to['lat'], 'lon': to['lon']},
        };

        final response = await http.post(
          Uri.parse('${ApiService.baseUrl}/api/routes'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode(body),
        ).timeout(const Duration(seconds: 5));

        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          if (data['success'] == true) {
            final coords = data['data']['coordinates'] as List;
            final distance = (data['data']['distance_meters'] as num).toDouble();
            final duration = (data['data']['duration_minutes'] as num).toDouble();
            final steps = data['data']['steps'] as List? ?? [];

            totalDistance += distance;
            totalDuration += duration;
            allSteps.addAll(steps.cast<Map<String, dynamic>>());

            final positions = coords.map((c) => Position(c[0] as double, c[1] as double)).toList();
            await _polylineAnnotationManager!.create(PolylineAnnotationOptions(
              geometry: LineString(coordinates: positions),
              lineColor: 0xFF29B6F6,
              lineWidth: 4.0,
              lineOpacity: 0.8,
            ));
          }
        }
      } catch (e) {
        print('[Map] ❌ Error en segmento $i: $e');
      }
    }

    // Buscar marcadores de las paradas para modo ruta exclusivo
    final routeMarkers = <MapMarkerModel>[];
    for (int i = 1; i < points.length; i++) {
      final targetLat = (points[i]['lat'] as num).toDouble();
      final targetLon = (points[i]['lon'] as num).toDouble();
      // Buscar marcador más cercano en _allMarkers
      MapMarkerModel? closest;
      double closestDist = double.infinity;
      for (final m in _allMarkers) {
        if (m.latitude == null || m.longitude == null) continue;
        final dist = MapboxService.calculateDistance(targetLat, targetLon, m.latitude!, m.longitude!);
        if (dist < closestDist) {
          closestDist = dist;
          closest = m;
        }
      }
      if (closest != null) {
        routeMarkers.add(closest);
      }
    }

    setState(() {
      _routeSteps = allSteps;
      _routeOnlyMarkers = routeMarkers;
    });

    // Refrescar solo marcadores de la ruta
    await _addMarkersToMap();

    // Ajustar cámara a todos los puntos
    final allPositions = points.map((p) => Position(p['lon'] as double, p['lat'] as double)).toList();
    if (allPositions.isNotEmpty) {
      final latitudes = allPositions.map((p) => p.lat);
      final longitudes = allPositions.map((p) => p.lng);
      final bounds = CoordinateBounds(
        southwest: Point(coordinates: Position(longitudes.reduce((a, b) => a < b ? a : b), latitudes.reduce((a, b) => a < b ? a : b))),
        northeast: Point(coordinates: Position(longitudes.reduce((a, b) => a > b ? a : b), latitudes.reduce((a, b) => a > b ? a : b))),
        infiniteBounds: false,
      );
      final camera = await _mapboxMap!.cameraForCoordinateBounds(
        bounds,
        MbxEdgeInsets(top: 100, left: 50, bottom: 100, right: 50),
        null, // bearing
        null, // pitch
        null, // maxZoom
        null, // offset
      );
      await _mapboxMap!.flyTo(camera, MapAnimationOptions(duration: 1000));
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('🛣️ ${route.name}: ${totalDistance.toStringAsFixed(0)}m • ~${totalDuration.toStringAsFixed(0)} min'),
          backgroundColor: BichofueColors.verde,
          duration: const Duration(seconds: 3),
          action: SnackBarAction(
            label: 'Ver pasos',
            textColor: BichofueColors.blanco,
            onPressed: () => _showRouteSteps(),
          ),
        ),
      );
    }
  }

  Future<void> _clearRoute() async {
    if (_polylineAnnotationManager != null) {
      await _polylineAnnotationManager!.deleteAll();
    }
    setState(() => _routeSteps = []);
  }

  /// Sale del modo ruta exclusivo y vuelve a mostrar todos los marcadores normales
  void _exitRouteMode() async {
    setState(() {
      _routeOnlyMarkers = null;
    });
    await _clearRoute();
    await _addMarkersToMap();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('🗺️ Volviendo a exploración normal'),
          backgroundColor: BichofueColors.verde,
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  void _showRouteSteps() {
    if (_routeSteps.isEmpty) return;
    showModalBottomSheet(
      context: context,
      backgroundColor: BichofueColors.blanco,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Instrucciones de ruta',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 12),
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: _routeSteps.length,
                itemBuilder: (ctx, i) {
                  final step = _routeSteps[i];
                  return ListTile(
                    leading: CircleAvatar(
                      backgroundColor: BichofueColors.amarillo.withOpacity(0.2),
                      child: Text('${i + 1}', style: const TextStyle(fontSize: 12, color: BichofueColors.negro)),
                    ),
                    title: Text(step['instruction'] ?? ''),
                    subtitle: Text('${(step['distance'] ?? 0)} m'),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _checkGeofencing() async {
    if (_effectivePosition == null || !ApiService.isConfigured) return;

    try {
      final uri = Uri.parse('${ApiService.baseUrl}/api/events/nearby').replace(
        queryParameters: {
          'lat': _effectivePosition!.latitude.toString(),
          'lon': _effectivePosition!.longitude.toString(),
          'radius': '100',
        },
      );
      final response = await http.get(uri).timeout(const Duration(seconds: 3));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['success'] == true && (data['data'] as List).isNotEmpty) {
          final evento = data['data'][0];
          print('[Map] 🎯 Geofencing: evento cercano "${evento['nombre']}"');
          // Solo mostrar una vez por sesión para no spamear
          if (mounted) {
            NotificationService.showEventNotification(
              title: '🎉 ¡Evento cercano!',
              body: evento['nombre'] ?? 'Hay un evento cerca tuyo',
            );
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('🎉 ¡Evento cercano! ${evento['nombre']}'),
                backgroundColor: BichofueColors.verde,
                duration: const Duration(seconds: 4),
                action: SnackBarAction(
                  label: 'Ver',
                  textColor: BichofueColors.blanco,
                  onPressed: () {
                    // Navegar a eventos
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const EventosScreen()),
                    );
                  },
                ),
              ),
            );
          }
        }
      }
    } catch (e) {
      // Silencioso - geofencing es opcional
    }
  }
  
  void _showMarkerInfo(MapMarkerModel marker) {
    print('[Map] 📋 Mostrando info de: ${marker.nombre}');
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setStateBottomSheet) {
          bool isPlaying = AudioPlayerService.isPlaying &&
              AudioPlayerService.currentUrl?.contains('/api/tts/${marker.id}') == true;

          return Container(
            decoration: const BoxDecoration(
              color: BichofueColors.blanco,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            padding: const EdgeInsets.all(20),
            child: SafeArea(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Avatar caleño + nombre
                  Row(
                    children: [
                       const BichofueAvatar(size: 80),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              marker.nombre,
                              style: Theme.of(context).textTheme.headlineSmall,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              marker.categoria ?? 'Atractivo turístico',
                              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                color: BichofueColors.cafe,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  BurbujaCalena(isPlaying: isPlaying),
                  if (marker.isEmblematico) ...[
                    const SizedBox(height: 12),
                    Chip(
                      label: const Text('⭐ Reconocible por cámara'),
                      backgroundColor: BichofueColors.amarillo.withOpacity(0.2),
                      labelStyle: const TextStyle(color: BichofueColors.cafe),
                    ),
                  ],
                  const SizedBox(height: 16),
                  // Botón Escuchar en caleño
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () async {
                        if (isPlaying) {
                          await AudioPlayerService.stop();
                        } else {
                          await AudioPlayerService.play(marker.id);
                        }
                        setStateBottomSheet(() {});
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: isPlaying
                            ? BichofueColors.cafe
                            : BichofueColors.amarillo,
                        foregroundColor: BichofueColors.negro,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      icon: Icon(isPlaying ? Icons.stop : Icons.play_arrow),
                      label: Text(
                        isPlaying ? 'Detener' : 'Escuchar en caleño 🎙️',
                        style: const TextStyle(fontSize: 16),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () {
                            Navigator.pop(ctx);
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => AttractionDetailScreen(
                                  atraction: marker.toJson(),
                                ),
                              ),
                            );
                          },
                          icon: const Icon(Icons.info_outline),
                          label: const Text('Ver detalle'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Navigator.pop(ctx);
                        _drawRoute(marker);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: BichofueColors.verde,
                        foregroundColor: BichofueColors.blanco,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      icon: const Icon(Icons.directions),
                      label: const Text(
                        'Ir 🛣️',
                        style: TextStyle(fontSize: 16),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextButton.icon(
                    onPressed: () {
                      Navigator.pop(ctx);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const AttractionsListScreen(),
                        ),
                      );
                    },
                    icon: const Icon(Icons.list, color: BichofueColors.cafe),
                    label: const Text(
                      'Ver lista completa',
                      style: TextStyle(color: BichofueColors.cafe),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
  
  void _centerOnCali() async {
    print('[Map] 🏙️ Botón "Centrar en Cali" presionado');
    if (_mapboxMap == null) return;
    try {
      await _mapboxMap!.flyTo(
        CameraOptions(
          center: Point(coordinates: Position(-76.5325, 3.4519)),
          zoom: 15.5,
          pitch: 45.0,
          bearing: -17.6,
        ),
        MapAnimationOptions(duration: 1000),
      );
      print('[Map] ✅ Cámara centrada en Cali');
    } catch (e) {
      print('[Map] ❌ Error centrando en Cali: $e');
    }
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Mapa con cámara estática inicial (Cali) — el seguimiento GPS se activa en onMapCreated
          MapWidget(
            key: const ValueKey("mapWidget"),
            onMapCreated: _onMapCreated,
            styleUri: MapboxService.styleUri,
            cameraOptions: MapboxService.initialCamera,
            onCameraChangeListener: (event) async {
              try {
                if (_mapboxMap == null) return;
                final state = await _mapboxMap!.getCameraState();
                print('[Map] 📷 Zoom: ${state.zoom.toStringAsFixed(1)} | center: ${state.center.coordinates.lat.toStringAsFixed(4)}, ${state.center.coordinates.lng.toStringAsFixed(4)}');
              } catch (e) {
                // Ignorar errores de cámara
              }
            },
          ),
          
          // Indicador de radio de descubrimiento (overlay visual)
          if (_currentPosition != null)
            _buildDiscoveryRadiusOverlay(),
          
          // Indicador de carga
          if (_isLoading)
            Container(
              color: Colors.black87,
              child: const Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                    SizedBox(height: 16),
                    Text(
                      'Cargando lugares...',
                      style: TextStyle(color: Colors.white, fontSize: 16),
                    ),
                  ],
                ),
              ),
            ),
          
          // Contador de lugares cercanos
          Positioned(
            top: MediaQuery.of(context).padding.top + 16,
            left: 16,
            right: 16,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.7),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: Colors.white.withOpacity(0.2)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.radar, color: Colors.blue.shade300, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    '${_visibleMarkers.length} lugares cerca de ti',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (_isSimulationMode) ...[
                    const SizedBox(width: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                      decoration: BoxDecoration(
                        color: Colors.orange,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Text(
                        'SIM',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                  if (_nightMode) ...[
                    const SizedBox(width: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF4C400),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.nights_stay, color: Colors.black, size: 10),
                          SizedBox(width: 2),
                          Text(
                            'NOCTURNO',
                            style: TextStyle(
                              color: Colors.black,
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(width: 8),
                  Text(
                    '(${MapConfig.discoveryRadiusMeters.toInt()}m)',
                    style: TextStyle(
                      color: Colors.grey.shade400,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ),
          
          // Indicador online/offline + simulación
          Positioned(
            top: MediaQuery.of(context).padding.top + 60,
            right: 16,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: _isSimulationMode
                    ? Colors.orange
                    : (_isOnline ? Colors.green : Colors.orange),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    _isSimulationMode
                        ? Icons.videogame_asset
                        : (_isOnline ? Icons.cloud_done : Icons.cloud_off),
                    size: 12,
                    color: Colors.white,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    _isSimulationMode ? 'Sim' : (_isOnline ? 'Online' : 'Offline'),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Botón para activar/desactivar modo simulación
          Positioned(
            left: 16,
            bottom: 220,
            child: FloatingActionButton(
              heroTag: 'simulation',
              onPressed: _toggleSimulationMode,
              backgroundColor: _isSimulationMode ? BichofueColors.cafe : BichofueColors.amarillo,
              foregroundColor: BichofueColors.negro,
              tooltip: _isSimulationMode ? 'Desactivar simulación' : 'Simular GPS',
              mini: true,
              child: Icon(_isSimulationMode ? Icons.videogame_asset : Icons.videogame_asset_outlined),
            ),
          ),

          // Botón para abrir cámara (reconocimiento visual)
          Positioned(
            right: 16,
            bottom: 220,
            child: FloatingActionButton(
              heroTag: 'camera',
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const CameraScreen(),
                  ),
                );
              },
              backgroundColor: BichofueColors.amarillo,
              foregroundColor: BichofueColors.negro,
              tooltip: 'Reconocer monumento',
              mini: true,
              child: const Icon(Icons.camera_alt),
            ),
          ),

          // Botón para centrar en la ubicación del usuario
          Positioned(
            right: 16,
            bottom: 160,
            child: FloatingActionButton(
              heroTag: 'user',
              onPressed: _centerOnUser,
              backgroundColor: BichofueColors.verde,
              foregroundColor: BichofueColors.blanco,
              tooltip: 'Centrar en mi ubicación',
              mini: true,
              child: const Icon(Icons.my_location),
            ),
          ),

          // Botón para centrar en Cali (fallback si GPS falla)
          Positioned(
            right: 16,
            bottom: 100,
            child: FloatingActionButton(
              heroTag: 'cali',
              onPressed: _centerOnCali,
              backgroundColor: BichofueColors.amarillo,
              foregroundColor: BichofueColors.negro,
              tooltip: 'Centrar en Cali',
              mini: true,
              child: const Icon(Icons.location_city),
            ),
          ),

          // Botón para mostrar zonas WiFi gratuitas
          Positioned(
            left: 16,
            bottom: 160,
            child: FloatingActionButton(
              heroTag: 'wifi',
              onPressed: _toggleWifiZones,
              backgroundColor: _showWifiZones ? Colors.blue : BichofueColors.blanco,
              foregroundColor: _showWifiZones ? Colors.white : Colors.blue,
              tooltip: 'Zonas WiFi gratis',
              mini: true,
              child: const Icon(Icons.wifi),
            ),
          ),

          // Botón para salir del modo ruta exclusivo
          if (_routeOnlyMarkers != null)
            Positioned(
              right: 16,
              bottom: 220,
              child: FloatingActionButton(
                heroTag: 'exit_route',
                onPressed: _exitRouteMode,
                backgroundColor: Colors.red.shade600,
                foregroundColor: Colors.white,
                tooltip: 'Salir de la ruta',
                mini: true,
                child: const Icon(Icons.close),
              ),
            ),

          // Overlay offline: sin conexión al backend
          if (_allMarkers.isEmpty && !ApiService.isConfigured && !_isLoading)
            Positioned.fill(
              child: Container(
                color: Colors.black.withValues(alpha: 0.85),
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.wifi_off, color: Colors.white, size: 64),
                      const SizedBox(height: 16),
                      const Text(
                        'Sin conexión al servidor',
                        style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 32),
                        child: Text(
                          'Conectate al WiFi de la laptop para ver el mapa y los lugares de Cali',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.white70, fontSize: 14),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
  
  Widget _buildDiscoveryRadiusOverlay() {
    // El radio visual se maneja con el location puck nativo de Mapbox
    // Este overlay muestra información adicional
    return const SizedBox.shrink();
  }
}

class _PointClickListener extends OnPointAnnotationClickListener {
  final _MapScreenState mapScreen;
  
  _PointClickListener(this.mapScreen);
  
  @override
  void onPointAnnotationClick(PointAnnotation annotation) {
    final textField = annotation.textField;
    if (textField == null || textField.isEmpty) return;
    
    try {
      final marker = mapScreen._visibleMarkers.firstWhere(
        (m) => m.nombre == textField,
      );
      mapScreen._onMarkerTap(marker);
    } catch (_) {
      print('[Map] Marcador no encontrado: $textField');
    }
  }
}
