# SKILL: mapbox_maps_flutter v2.23.0
> Fuente: https://pub.dev/documentation/mapbox_maps_flutter/2.23.0/mapbox_maps_flutter/

---

## Cuándo usar este skill
- Mapa con vista 3D / isométrica tipo Pokémon GO
- Seguimiento GPS en tiempo real con puck animado
- Edificios extruidos en 3D
- Estilos visuales profesionales
- Marcadores personalizados con íconos y texto
- Rotación del mapa según orientación del celular
- Modo offline (descarga de tiles)

---

## Instalación

### pubspec.yaml
```yaml
dependencies:
  mapbox_maps_flutter: ^2.23.0
```

### Token Mapbox
- Registro gratuito: https://account.mapbox.com
- Free tier: 50,000 map loads/mes
- Guardar en `.env`: `MAPBOX_TOKEN=pk.xxxx`

### Android — AndroidManifest.xml
```xml
<manifest>
  <uses-permission android:name="android.permission.INTERNET"/>
  <uses-permission android:name="android.permission.ACCESS_FINE_LOCATION"/>
  <uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION"/>

  <application android:usesCleartextTraffic="true">
    <meta-data
      android:name="com.mapbox.token"
      android:value="pk.TU_TOKEN"/>
  </application>
</manifest>
```

### Android — build.gradle
```gradle
android {
    defaultConfig {
        minSdkVersion 21  // requerido por Mapbox
    }
}
```

### main.dart — inicializar token
```dart
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  MapboxOptions.setAccessToken("pk.TU_TOKEN");
  runApp(const MyApp());
}
```

---

## MapWidget — Widget principal

### Constructor completo
```dart
MapWidget({
  Key? key,
  MapOptions? mapOptions,
  CameraOptions? cameraOptions,
  bool? textureView = true,              // solo Android, evita memory leak
  AndroidPlatformViewHostingMode androidHostingMode,
  String styleUri = MapboxStyles.STANDARD,
  Set<Factory<OneSequenceGestureRecognizer>>? gestureRecognizers,
  ViewportState? viewport,               // reemplaza cameraOptions (recomendado)
  MapCreatedCallback? onMapCreated,
  OnStyleLoadedListener? onStyleLoadedListener,
  OnCameraChangeListener? onCameraChangeListener,
  OnMapIdleListener? onMapIdleListener,
  OnMapLoadedListener? onMapLoadedListener,
  OnMapLoadErrorListener? onMapLoadErrorListener,
  OnRenderFrameStartedListener? onRenderFrameStartedListener,
  OnRenderFrameFinishedListener? onRenderFrameFinishedListener,
  OnSourceAddedListener? onSourceAddedListener,
  OnSourceDataLoadedListener? onSourceDataLoadedListener,
  OnSourceRemovedListener? onSourceRemovedListener,
  OnStyleDataLoadedListener? onStyleDataLoadedListener,
  OnStyleImageMissingListener? onStyleImageMissingListener,
  OnStyleImageUnusedListener? onStyleImageUnusedListener,
  OnResourceRequestListener? onResourceRequestListener,
  OnMapScrollListener? onScrollListener,
  OnMapZoomListener? onZoomListener,
})
```

### Uso básico
```dart
MapWidget(
  key: const ValueKey("mapWidget"),
  styleUri: MapboxStyles.STANDARD,
  cameraOptions: CameraOptions(
    center: Point(coordinates: Position(-76.5320, 3.4516)), // ⚠️ lng, lat
    zoom: 14.0,
    pitch: 45.0,
    bearing: 0.0,
  ),
  onMapCreated: _onMapCreated,
  onStyleLoadedListener: (event) => print("Estilo cargado"),
  onMapLoadErrorListener: (event) => print("Error: ${event.message}"),
)
```

### Estilos disponibles (MapboxStyles)
| Constante | Descripción |
|-----------|-------------|
| `MapboxStyles.STANDARD` | Estilo moderno 3D — recomendado |
| `MapboxStyles.SATELLITE` | Solo satélite |
| `MapboxStyles.SATELLITE_STREETS` | Satélite con calles |
| `MapboxStyles.OUTDOORS` | Naturaleza y senderismo |
| `MapboxStyles.DARK` | Modo oscuro |
| `MapboxStyles.LIGHT` | Modo claro minimalista |
| `MapboxStyles.MAPBOX_STREETS` | Calles estándar |

---

## MapboxMap — Controlador

Se obtiene en el callback `onMapCreated`. Extiende `ChangeNotifier`.

### Propiedades principales
| Propiedad | Tipo | Descripción |
|-----------|------|-------------|
| `annotations` | `AnnotationManager` | Crea marcadores, líneas, polígonos |
| `location` | `LocationSettings` | Controla el puck de ubicación |
| `gestures` | `GesturesSettingsInterface` | Configura gestos táctiles |
| `style` | `StyleManager` | Gestiona el estilo del mapa |
| `compass` | `CompassSettingsInterface` | Configura la brújula |
| `scaleBar` | `ScaleBarSettingsInterface` | Configura la barra de escala |
| `logo` | `LogoSettingsInterface` | Configura el logo de Mapbox |
| `attribution` | `AttributionSettingsInterface` | Configura la atribución |
| `projection` | `Projection` | Proyección del mapa |
| `recorder` | `MapRecorder` | Graba y reproduce sesiones del mapa |
| `indoorSelector` | `IndoorSelectorSettingsInterface` | Selector de pisos en interiores |

### Métodos de cámara

#### setCamera — sin animación
```dart
await mapboxMap.setCamera(CameraOptions(
  center: Point(coordinates: Position(-76.5320, 3.4516)),
  zoom: 15.0,
  pitch: 45.0,
  bearing: 30.0,
));
```

#### easeTo — animación suave
```dart
await mapboxMap.easeTo(
  CameraOptions(center: Point(coordinates: Position(-76.5320, 3.4516)), zoom: 16.0),
  MapAnimationOptions(duration: 1000),
);
```

#### flyTo — animación de vuelo
```dart
await mapboxMap.flyTo(
  CameraOptions(
    center: Point(coordinates: Position(-76.5320, 3.4516)),
    zoom: 16.0,
    pitch: 50.0,
  ),
  MapAnimationOptions(duration: 2000),
);
```

#### moveBy — mover por coordenadas de pantalla
```dart
await mapboxMap.moveBy(
  ScreenCoordinate(x: 100, y: 0),
  MapAnimationOptions(duration: 500),
);
```

#### pitchBy — inclinar
```dart
await mapboxMap.pitchBy(10.0, MapAnimationOptions(duration: 300));
```

#### rotateBy — rotar
```dart
await mapboxMap.rotateBy(
  ScreenCoordinate(x: 0, y: 0),
  ScreenCoordinate(x: 100, y: 0),
  MapAnimationOptions(duration: 300),
);
```

#### scaleBy — escalar zoom
```dart
await mapboxMap.scaleBy(2.0, null, MapAnimationOptions(duration: 300));
```

#### cancelCameraAnimation
```dart
await mapboxMap.cancelCameraAnimation();
```

### Métodos de consulta de cámara
```dart
final CameraState state = await mapboxMap.getCameraState();
print(state.zoom);
print(state.pitch);
print(state.bearing);
print(state.center);

final CameraBounds bounds = await mapboxMap.getBounds();

final CameraOptions cam = await mapboxMap.cameraForCoordinateBounds(
  CoordinateBounds(
    southwest: Point(coordinates: Position(-76.58, 3.40)),
    northeast: Point(coordinates: Position(-76.50, 3.50)),
    infiniteBounds: false,
  ),
  MbxEdgeInsets(top: 50, left: 50, bottom: 50, right: 50),
  null, null, null, null,
);

// También disponible:
// cameraForCoordinates() — a partir de una lista de puntos
// cameraForCoordinatesCameraOptions() — ajusta camera options
// cameraForCoordinatesPadding() — con padding personalizado
// cameraForGeometry() — a partir de una geometría
// coordinateBoundsForCamera() — bounds para una cámara
// coordinateBoundsZoomForCamera() — bounds + zoom para una cámara
```

### Métodos de conversión coordenadas
```dart
final ScreenCoordinate pixel = await mapboxMap.pixelForCoordinate(
  Point(coordinates: Position(-76.5320, 3.4516))
);

final Point coord = await mapboxMap.coordinateForPixel(
  ScreenCoordinate(x: 200, y: 300)
);

// También:
// pixelsForCoordinates() — lista de puntos
// coordinatesForPixels() — lista de pixels
```

### Métodos de estilo
```dart
await mapboxMap.loadStyleURI(MapboxStyles.DARK);
await mapboxMap.loadStyleJson('{ "version": 8, ... }');

// Activar edificios 3D (solo con STANDARD)
await mapboxMap.style.setStyleImportConfigProperty(
  "basemap", "show3dObjects", true
);
```

### Métodos de feature state
```dart
await mapboxMap.setFeatureState("source-id", "layer-id", "feature-id", '{"selected": true}');
final String state = await mapboxMap.getFeatureState("source-id", "layer-id", "feature-id");
await mapboxMap.removeFeatureState("source-id", "layer-id", "feature-id", null);
```

### Métodos de GeoJSON cluster
```dart
// Hijos de un cluster
final FeatureExtensionValue children = await mapboxMap.getGeoJsonClusterChildren("source", cluster);
// Zoom de expansión del cluster
final FeatureExtensionValue zoom = await mapboxMap.getGeoJsonClusterExpansionZoom("source", cluster);
// Hojas (puntos originales) del cluster
final FeatureExtensionValue leaves = await mapboxMap.getGeoJsonClusterLeaves("source", cluster, 10, 0);
```

### Otros métodos útiles
```dart
final Uint8List snapshot = await mapboxMap.snapshot();
await mapboxMap.reduceMemoryUse();
await mapboxMap.clearData();
final Size size = await mapboxMap.getSize();       // no disponible iOS
final bool gestureInProgress = await mapboxMap.isGestureInProgress();
final bool animationInProgress = await mapboxMap.isUserAnimationInProgress();
final MapOptions options = await mapboxMap.getMapOptions();
await mapboxMap.setConstrainMode(ConstrainMode.HEIGHT_ONLY);
await mapboxMap.setNorthOrientation(NorthOrientation.UPWARDS);
await mapboxMap.setViewportMode(ViewportMode.DEFAULT);
await mapboxMap.triggerRepaint();
await mapboxMap.setPrefetchZoomDelta(4);
await mapboxMap.setTileCacheBudget(TileCacheBudgetInMegabytes(size: 50), null);
await mapboxMap.setCustomHeaders({"X-Custom-Header": "value"});
await mapboxMap.setStyleGlyphURL("https://my-glyphs-url/{fontstack}/{range}.pbf");

// Establecer límites de cámara
await mapboxMap.setBounds(CameraBoundsOptions(
  bounds: CoordinateBounds(
    southwest: Point(coordinates: Position(-76.60, 3.35)),
    northeast: Point(coordinates: Position(-76.45, 3.55)),
    infiniteBounds: false,
  ),
  minZoom: 10,
  maxZoom: 20,
));
```

### Interacciones con features del mapa Standard
```dart
mapboxMap.addInteraction(
  TapInteraction(StandardPOIs(), (feature, context) {
    print('POI: ${feature.name}');
  }),
  interactionID: "poi-tap",
);

mapboxMap.addInteraction(
  TapInteraction(StandardBuildings(), (feature, context) {
    print('Edificio tocado');
  }),
);

mapboxMap.addInteraction(
  LongTapInteraction(StandardPOIs(), (feature, context) {
    print('Long tap en POI');
  }),
);

mapboxMap.removeInteraction("poi-tap");
```

### Query de features renderizados
```dart
final List<QueriedRenderedFeature?> features = await mapboxMap.queryRenderedFeatures(
  RenderedQueryGeometry.fromScreenCoordinate(ScreenCoordinate(x: 200.0, y: 300.0)),
  RenderedQueryOptions(layerIds: ["poi-label"]),
);

final List<QueriedRenderedFeature?> featuresInBox = await mapboxMap.queryRenderedFeatures(
  RenderedQueryGeometry.fromScreenBox(
    ScreenBox(min: ScreenCoordinate(x: 0, y: 0), max: ScreenCoordinate(x: 300, y: 300)),
  ),
  RenderedQueryOptions(),
);

// Query en featureset
final List<FeaturesetFeature> poisFeatures = await mapboxMap.queryRenderedFeaturesForFeatureset(
  featureset: StandardPOIs(),
  geometry: RenderedQueryGeometry.fromScreenCoordinate(ScreenCoordinate(x: 200, y: 300)),
);

// Query en source
final List<QueriedSourceFeature?> sourceFeatures = await mapboxMap.querySourceFeatures(
  "my-source",
  SourceQueryOptions(filter: '["==", ["get", "categoria"], "monumento"]'),
);
```

### Performance statistics
```dart
mapboxMap.startPerformanceStatisticsCollection(
  PerformanceStatisticsOptions(samplerOptions: [PerformanceSamplerOptions.RENDERING]),
  PerformanceStatisticsListener(onPerformanceStatisticsCollected: (stats) {
    print('FPS: ${stats.perFrameRenderingStatistics?.cpuRenderingDurationStatistics}');
  }),
);
mapboxMap.stopPerformanceStatisticsCollection();
```

---

## CameraOptions — Opciones de cámara

```dart
CameraOptions({
  Point? center,              // coordenada central ⚠️ Position(lng, lat)
  MbxEdgeInsets? padding,     // padding interior
  ScreenCoordinate? anchor,   // punto de referencia para zoom/bearing
  double? zoom,               // nivel de zoom (0-22)
  double? bearing,            // rotación en grados (0-360)
  double? pitch,              // inclinación hacia horizonte en grados (0-60)
})
```

### Valores recomendados para Cali Guía
```dart
// Vista normal
CameraOptions(center: Point(coordinates: Position(-76.5320, 3.4516)), zoom: 14.0)

// Vista tipo Pokémon GO
CameraOptions(
  center: Point(coordinates: Position(-76.5320, 3.4516)),
  zoom: 17.0, pitch: 45.0, bearing: 0.0,
)

// Vista panorámica de Cali
CameraOptions(
  center: Point(coordinates: Position(-76.5200, 3.4400)),
  zoom: 12.0, pitch: 30.0,
)
```

⚠️ **IMPORTANTE:** `Position(longitude, latitude)` — orden `lng, lat`, al revés de `flutter_map`.

---

## FollowPuckViewportState — Seguir usuario

```dart
FollowPuckViewportState({
  double? zoom = 16.35,
  FollowPuckViewportStateBearing? bearing = FollowPuckViewportStateBearingHeading(),
  double? pitch = 45,
  MbxEdgeInsets? padding,
})
```

### Modos de bearing
```dart
FollowPuckViewportStateBearingCourse()     // dirección de movimiento
FollowPuckViewportStateBearingHeading()    // orientación del dispositivo (brújula)
FollowPuckViewportStateBearingConstant(bearing: 0.0)  // fijo
```

### Activar seguimiento
```dart
await mapboxMap.viewport.transitionTo(
  FollowPuckViewportState(
    zoom: 17.0, pitch: 45.0,
    bearing: FollowPuckViewportStateBearingHeading(),
  ),
  transition: DefaultViewportTransition(), // SIEMPRE usar Default con FollowPuck
);
```

### Otros ViewportStates
```dart
// Vista general de geometría
await mapboxMap.viewport.transitionTo(
  OverviewViewportState(
    geometry: Point(coordinates: Position(-76.5320, 3.4516)),
    padding: MbxEdgeInsets(top: 100, left: 100, bottom: 100, right: 100),
  ),
  transition: DefaultViewportTransition(),
);

// Cámara fija manual
await mapboxMap.viewport.transitionTo(
  CameraViewportState(
    center: Point(coordinates: Position(-76.5320, 3.4516)),
    zoom: 15.0, pitch: 30.0, bearing: 0.0,
  ),
  transition: DefaultViewportTransition(),
);

// Default del estilo
await mapboxMap.viewport.transitionTo(
  StyleDefaultViewportState(),
  transition: DefaultViewportTransition(),
);
```

### Transiciones disponibles
```dart
DefaultViewportTransition()                         // suave, recomendado
EasingViewportTransition(duration: 1000)            // con easing (no usar con FollowPuck)
FlyViewportTransition(duration: 2000)               // vuelo animado (no usar con FollowPuck)
```

---

## LocationComponentSettings — Puck de ubicación

```dart
await mapboxMap.location.updateSettings(LocationComponentSettings(
  enabled: true,
  puckBearing: PuckBearing.HEADING,    // HEADING o COURSE
  locationPuck: LocationPuck(
    locationPuck2D: DefaultLocationPuck2D(),
  ),
  pulsingEnabled: true,
  pulsingColor: 0xFF1D9E75,
  pulsingMaxRadius: 50.0,
  showAccuracyRing: true,
  accuracyRingColor: 0x201D9E75,
));
```

---

## PointAnnotationManager — Marcadores

### Crear manager
```dart
final PointAnnotationManager manager = await mapboxMap.annotations
    .createPointAnnotationManager();
```

### Crear un marcador
```dart
final ByteData bytes = await rootBundle.load('assets/icons/marker.png');
final Uint8List imageData = bytes.buffer.asUint8List();

await manager.create(PointAnnotationOptions(
  geometry: Point(coordinates: Position(-76.5320, 3.4516)),
  image: imageData,
  iconSize: 1.5,
  iconAnchor: IconAnchor.BOTTOM,
  iconOpacity: 1.0,
  iconRotate: 0.0,
  iconOffset: [0.0, 0.0],
  iconPadding: 2.0,
  iconHaloColor: Colors.white.value,
  iconHaloWidth: 2.0,
  iconHaloBlur: 1.0,
  textField: "El Gato del Río",
  textOffset: [0.0, 2.0],
  textSize: 12.0,
  textColor: Colors.white.value,
  textHaloColor: Colors.black.value,
  textHaloWidth: 1.5,
  textOpacity: 1.0,
));
```

### Crear múltiples (más eficiente)
```dart
await manager.createMulti(lugares.map((l) => PointAnnotationOptions(
  geometry: Point(coordinates: Position(l.lng, l.lat)),
  image: imageData,
  iconSize: 1.2,
  textField: l.nombre,
  textOffset: [0.0, 2.5],
  textSize: 11.0,
  textColor: Colors.white.value,
  textHaloColor: Colors.black.value,
  textHaloWidth: 1.5,
)).toList());
```

### CRUD de marcadores
```dart
await manager.update(annotation);             // actualizar uno
await manager.delete(annotation);             // borrar uno
await manager.deleteMulti([a1, a2]);          // borrar varios
await manager.deleteAll();                    // borrar todos
final List<PointAnnotation> all = await manager.getAnnotations();
```

### Eventos
```dart
// Tap (recomendado)
final Cancelable c = manager.tapEvents(onTap: (a) => print(a.textField));

// Long press
final Cancelable c = manager.longPressEvents(onLongPress: (a) => print('Long press'));

// Drag
final Cancelable c = manager.dragEvents(
  onBegin: (a) => print('Inicio drag'),
  onChanged: (a) => print('Moviendo'),
  onEnd: (a) => print('Fin drag: ${a.geometry}'),
);

// Para cancelar cualquier evento:
c.cancel();

// Método alternativo con listener
manager.addOnPointAnnotationClickListener(_Listener());
class _Listener extends OnPointAnnotationClickListener {
  @override
  void onPointAnnotationClick(PointAnnotation annotation) {}
}
```

### Propiedades globales del manager (afectan todos los marcadores)

#### Ícono
```dart
await manager.setIconAllowOverlap(true);
await manager.setIconIgnorePlacement(false);
await manager.setIconOptional(false);
await manager.setIconSize(1.5);
await manager.setIconSizeScaleRange([0.8, 2.0]);
await manager.setIconOpacity(1.0);
await manager.setIconRotate(0.0);
await manager.setIconRotationAlignment(IconRotationAlignment.AUTO);
await manager.setIconPitchAlignment(IconPitchAlignment.AUTO);
await manager.setIconAnchor(IconAnchor.CENTER);
await manager.setIconOffset([0.0, 0.0]);
await manager.setIconPadding(2.0);
await manager.setIconKeepUpright(false);
await manager.setIconColor(Colors.white.value);
await manager.setIconHaloColor(Colors.black.value);
await manager.setIconHaloWidth(2.0);
await manager.setIconHaloBlur(1.0);
await manager.setIconTranslate([0.0, 0.0]);
await manager.setIconTranslateAnchor(IconTranslateAnchor.MAP);
await manager.setIconEmissiveStrength(1.0);
await manager.setIconColorBrightnessMax(1.0);
await manager.setIconColorBrightnessMin(0.0);
await manager.setIconColorContrast(0.0);
await manager.setIconColorSaturation(0.0);
await manager.setIconOcclusionOpacity(0.0);
await manager.setIconTextFit(IconTextFit.NONE);
await manager.setIconTextFitPadding([0.0, 0.0, 0.0, 0.0]);
await manager.setIconImageCrossFade(0.0);
```

#### Texto
```dart
await manager.setTextAllowOverlap(false);
await manager.setTextIgnorePlacement(false);
await manager.setTextOptional(false);
await manager.setTextField("");
await manager.setTextSize(16.0);
await manager.setTextSizeScaleRange([0.8, 2.0]);
await manager.setTextOpacity(1.0);
await manager.setTextColor(Colors.black.value);
await manager.setTextHaloColor(Colors.transparent.value);
await manager.setTextHaloWidth(0.0);
await manager.setTextHaloBlur(0.0);
await manager.setTextAnchor(TextAnchor.CENTER);
await manager.setTextOffset([0.0, 0.0]);
await manager.setTextJustify(TextJustify.CENTER);
await manager.setTextPitchAlignment(TextPitchAlignment.AUTO);
await manager.setTextRotationAlignment(TextRotationAlignment.AUTO);
await manager.setTextRotate(0.0);
await manager.setTextMaxWidth(10.0);
await manager.setTextLineHeight(1.2);
await manager.setTextLetterSpacing(0.0);
await manager.setTextMaxAngle(45.0);
await manager.setTextTransform(TextTransform.NONE);
await manager.setTextPadding(2.0);
await manager.setTextKeepUpright(true);
await manager.setTextTranslate([0.0, 0.0]);
await manager.setTextTranslateAnchor(TextTranslateAnchor.MAP);
await manager.setTextEmissiveStrength(1.0);
await manager.setTextRadialOffset(0.0);
await manager.setTextOcclusionOpacity(0.0);
```

#### Símbolo
```dart
await manager.setSymbolPlacement(SymbolPlacement.POINT);
await manager.setSymbolSpacing(250.0);
await manager.setSymbolAvoidEdges(false);
await manager.setSymbolSortKey(0.0);
await manager.setSymbolZOrder(SymbolZOrder.AUTO);
await manager.setSymbolZElevate(false);         // elevar sobre edificios 3D
await manager.setSymbolZOffset(0.0);            // elevación en metros
await manager.setSymbolElevationReference(SymbolElevationReference.GROUND);
await manager.setOcclusionOpacityMode(OcclusionOpacityMode.ANCHOR);
```

---

## Otros AnnotationManagers

### CircleAnnotationManager
```dart
final CircleAnnotationManager circleManager = await mapboxMap.annotations
    .createCircleAnnotationManager();

await circleManager.create(CircleAnnotationOptions(
  geometry: Point(coordinates: Position(-76.5320, 3.4516)),
  circleRadius: 50.0,
  circleColor: Colors.blue.value,
  circleOpacity: 0.3,
  circleStrokeColor: Colors.blue.value,
  circleStrokeWidth: 2.0,
  circleStrokeOpacity: 0.8,
));
```

### PolylineAnnotationManager — Rutas
```dart
final PolylineAnnotationManager polylineManager = await mapboxMap.annotations
    .createPolylineAnnotationManager();

await polylineManager.create(PolylineAnnotationOptions(
  geometry: LineString(coordinates: [
    Position(-76.5320, 3.4516),
    Position(-76.5400, 3.4600),
  ]),
  lineColor: Colors.green.value,
  lineWidth: 4.0,
  lineOpacity: 0.8,
  lineCap: LineCap.ROUND,
  lineJoin: LineJoin.ROUND,
));
```

### PolygonAnnotationManager — Áreas
```dart
final PolygonAnnotationManager polygonManager = await mapboxMap.annotations
    .createPolygonAnnotationManager();

await polygonManager.create(PolygonAnnotationOptions(
  geometry: Polygon(coordinates: [[
    Position(-76.54, 3.45),
    Position(-76.52, 3.45),
    Position(-76.52, 3.47),
    Position(-76.54, 3.47),
    Position(-76.54, 3.45), // cerrar polígono
  ]]),
  fillColor: Colors.green.value,
  fillOpacity: 0.3,
  fillOutlineColor: Colors.green.value,
));
```

---

## GesturesSettings

```dart
await mapboxMap.gestures.updateSettings(GesturesSettings(
  scrollEnabled: true,
  rotateEnabled: true,
  pinchToZoomEnabled: true,
  pitchEnabled: true,
  doubleTapToZoomInEnabled: true,
  doubleTouchToZoomOutEnabled: true,
  quickZoomEnabled: true,
  scrollMode: ScrollMode.HORIZONTAL_AND_VERTICAL,
));

// Listeners de gestos
mapboxMap.setOnMapTapListener((context) => print('Tap en mapa'));
mapboxMap.setOnMapLongTapListener((context) => print('Long tap'));
mapboxMap.setOnMapMoveListener((context) => print('Moviendo'));
mapboxMap.setOnMapZoomListener((context) => print('Zoom'));
```

---

## CompassSettings
```dart
await mapboxMap.compass.updateSettings(CompassSettings(
  enabled: true,
  position: OrnamentPosition.TOP_RIGHT,
  marginTop: 10.0,
  marginRight: 10.0,
  fadeWhenFacingNorth: true,
));
```

## ScaleBarSettings
```dart
await mapboxMap.scaleBar.updateSettings(ScaleBarSettings(
  enabled: true,
  position: OrnamentPosition.BOTTOM_LEFT,
  marginLeft: 10.0,
  marginBottom: 10.0,
));
```

## LogoSettings — obligatorio mostrar
```dart
await mapboxMap.logo.updateSettings(LogoSettings(
  position: OrnamentPosition.BOTTOM_LEFT,
  marginLeft: 10.0,
  marginBottom: 10.0,
));
```

## AttributionSettings
```dart
await mapboxMap.attribution.updateSettings(AttributionSettings(
  position: OrnamentPosition.BOTTOM_RIGHT,
  marginRight: 10.0,
  marginBottom: 10.0,
));
```

---

## OfflineManager — Mapas offline
```dart
final OfflineManager offlineManager = OfflineManager();

await offlineManager.loadStylePack(
  MapboxStyles.STANDARD,
  StylePackLoadOptions(
    glyphsRasterizationMode: GlyphsRasterizationMode.IDEOGRAPHS_RASTERIZED_LOCALLY,
    metadata: {"region": "cali"},
  ),
  (progress) {
    final pct = progress.completedResourceCount / progress.requiredResourceCount;
    print('Descargando: ${(pct * 100).toInt()}%');
  },
);
```

---

## MapboxStyles — Constantes de estilos
```dart
MapboxStyles.STANDARD           // "mapbox://styles/mapbox/standard"
MapboxStyles.SATELLITE          // "mapbox://styles/mapbox/satellite-v9"
MapboxStyles.SATELLITE_STREETS  // "mapbox://styles/mapbox/satellite-streets-v12"
MapboxStyles.OUTDOORS           // "mapbox://styles/mapbox/outdoors-v12"
MapboxStyles.DARK               // "mapbox://styles/mapbox/dark-v11"
MapboxStyles.LIGHT              // "mapbox://styles/mapbox/light-v11"
MapboxStyles.MAPBOX_STREETS     // "mapbox://styles/mapbox/streets-v12"
```

---

## Clases geométricas importantes

```dart
// Punto — coordenada geográfica
Point(coordinates: Position(longitude, latitude))
Point(coordinates: Position(-76.5320, 3.4516))   // Cali

// Línea
LineString(coordinates: [Position(lng1, lat1), Position(lng2, lat2)])

// Polígono
Polygon(coordinates: [[Position(lng1, lat1), ..., Position(lng1, lat1)]])

// Multi-geometrías
MultiPoint(coordinates: [...])
MultiLineString(coordinates: [[...]])
MultiPolygon(coordinates: [[[...]]])

// Bounds
CoordinateBounds(
  southwest: Point(coordinates: Position(-76.60, 3.35)),
  northeast: Point(coordinates: Position(-76.45, 3.55)),
  infiniteBounds: false,
)

// Edge insets (padding)
MbxEdgeInsets(top: 50, left: 50, bottom: 50, right: 50)

// Coordenada de pantalla
ScreenCoordinate(x: 200.0, y: 300.0)

// Box en pantalla
ScreenBox(min: ScreenCoordinate(x: 0, y: 0), max: ScreenCoordinate(x: 300, y: 300))
```

---

## Migración desde flutter_map

| flutter_map | mapbox_maps_flutter | Nota |
|-------------|---------------------|------|
| `FlutterMap` | `MapWidget` | |
| `TileLayer` | automático con `styleUri` | No se necesita |
| `MarkerLayer` | `PointAnnotationManager` | Más potente |
| `MapController` | `MapboxMap` (en `onMapCreated`) | |
| `LatLng(lat, lng)` | `Point(coordinates: Position(lng, lat))` | ⚠️ orden invertido |
| `MapOptions(center:)` | `CameraOptions(center:)` | |
| `MapController.move()` | `mapboxMap.flyTo()` o `setCamera()` | |
| Sin pitch | `pitch: 45.0` | Vista 3D |
| Sin 3D | `setStyleImportConfigProperty("basemap", "show3dObjects", true)` | Edificios 3D |
| Sin seguimiento | `FollowPuckViewportState` | Modo Pokémon GO |

---

## Ejemplo completo: Mapa Cali Guía estilo Pokémon GO

```dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';

class MapaScreen extends StatefulWidget {
  const MapaScreen({super.key});
  @override
  State<MapaScreen> createState() => _MapaScreenState();
}

class _MapaScreenState extends State<MapaScreen> {
  MapboxMap? _mapboxMap;
  PointAnnotationManager? _annotationManager;

  void _onMapCreated(MapboxMap mapboxMap) async {
    _mapboxMap = mapboxMap;

    // Activar edificios 3D
    await mapboxMap.style.setStyleImportConfigProperty(
        "basemap", "show3dObjects", true);

    // Activar puck con pulso
    await mapboxMap.location.updateSettings(LocationComponentSettings(
      enabled: true,
      puckBearing: PuckBearing.HEADING,
      locationPuck: LocationPuck(locationPuck2D: DefaultLocationPuck2D()),
      pulsingEnabled: true,
      pulsingColor: 0xFF1D9E75,
      pulsingMaxRadius: 60.0,
    ));

    // Modo Pokémon GO
    await mapboxMap.viewport.transitionTo(
      FollowPuckViewportState(
        zoom: 17.0, pitch: 45.0,
        bearing: FollowPuckViewportStateBearingHeading(),
      ),
      transition: DefaultViewportTransition(),
    );

    // Gestos
    await mapboxMap.gestures.updateSettings(GesturesSettings(
      pitchEnabled: true, rotateEnabled: true,
    ));

    // Manager de marcadores
    _annotationManager = await mapboxMap.annotations.createPointAnnotationManager();
    _annotationManager!.tapEvents(onTap: (a) => _mostrarInfo(a));

    await _cargarMarcadores();
  }

  Future<void> _cargarMarcadores() async {
    final ByteData bytes = await rootBundle.load('assets/icons/marker.png');
    final Uint8List img = bytes.buffer.asUint8List();

    await _annotationManager!.createMulti([
      PointAnnotationOptions(
        geometry: Point(coordinates: Position(-76.5320, 3.4516)),
        image: img, iconSize: 1.2,
        textField: "El Gato del Río",
        textOffset: [0.0, 2.5], textSize: 11.0,
        textColor: Colors.white.value,
        textHaloColor: Colors.black.value, textHaloWidth: 1.5,
      ),
    ]);
  }

  void _mostrarInfo(PointAnnotation a) {
    showModalBottomSheet(
      context: context,
      builder: (_) => Padding(
        padding: const EdgeInsets.all(16),
        child: Text(a.textField ?? '', style: const TextStyle(fontSize: 18)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mapa de Cali'),
        backgroundColor: const Color(0xFF1D9E75),
        foregroundColor: Colors.white,
      ),
      body: MapWidget(
        key: const ValueKey("mapWidget"),
        onMapCreated: _onMapCreated,
        styleUri: MapboxStyles.STANDARD,
        cameraOptions: CameraOptions(
          center: Point(coordinates: Position(-76.5320, 3.4516)),
          zoom: 14.0, pitch: 45.0,
        ),
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: const Color(0xFF1D9E75),
        onPressed: () => _mapboxMap?.viewport.transitionTo(
          FollowPuckViewportState(zoom: 17.0, pitch: 45.0,
            bearing: FollowPuckViewportStateBearingHeading()),
          transition: DefaultViewportTransition(),
        ),
        child: const Icon(Icons.my_location, color: Colors.white),
      ),
    );
  }
}
```

---

## Notas importantes

- ⚠️ `Position(longitude, latitude)` — orden `lng, lat`, al revés de `flutter_map`
- ⚠️ `minSdkVersion 21` requerido en Android
- ⚠️ Solo usar `DefaultViewportTransition` con `FollowPuckViewportState`
- ⚠️ `show3dObjects` solo funciona con `MapboxStyles.STANDARD`
- ✅ El token de Mapbox debe inicializarse antes del `runApp`
- ✅ `textureView: true` (default) evita memory leak en Android con Flutter 3.x
- ✅ Free tier: 50,000 map loads/mes — suficiente para desarrollo y hackathon
- ✅ Para offline: usar `OfflineManager.loadStylePack()` antes de necesitarlo
- ✅ El logo de Mapbox es obligatorio mostrarlo según los términos de uso
- ✅ `getSize()` no está disponible en iOS
