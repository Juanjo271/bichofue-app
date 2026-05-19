import 'dart:io';
import 'package:audioplayers/audioplayers.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'api_service.dart';

/// Servicio para reproducir audio TTS del backend.
/// Guarda el audio en archivo temporal y lo reproduce (más confiable que bytes en memoria).
class AudioPlayerService {
  static final AudioPlayer _player = AudioPlayer();
  static bool _isPlaying = false;
  static String? _currentUrl;
  static Function(bool)? _onStateChanged;
  static bool _initialized = false;

  static bool get isPlaying => _isPlaying;
  static String? get currentUrl => _currentUrl;

  static void initialize() {
    if (_initialized) return;
    
    _player.onPlayerStateChanged.listen((state) {
      print('[AudioPlayer] Estado cambiado: $state');
      _isPlaying = state == PlayerState.playing;
      _onStateChanged?.call(_isPlaying);
    });

    _player.onPlayerComplete.listen((_) {
      print('[AudioPlayer] Reproducción completada');
      _isPlaying = false;
      _currentUrl = null;
      _onStateChanged?.call(false);
    });

    _initialized = true;
    print('[AudioPlayer] ✅ Inicializado');
  }

  static void setOnStateChanged(Function(bool isPlaying) callback) {
    _onStateChanged = callback;
    if (!_initialized) initialize();
  }

  /// Reproduce el audio TTS de un atractivo
  static Future<void> play(int atractivoId) async {
    print('[AudioPlayer] play() id=$atractivoId');
    if (!ApiService.isConfigured) {
      print('[AudioPlayer] ❌ ERROR: ApiService no configurado. baseUrl=${ApiService.baseUrl}');
      return;
    }
    final url = '${ApiService.baseUrl}/api/tts/$atractivoId';
    print('[AudioPlayer] URL: $url');
    await _downloadAndPlay(url);
  }

  static Future<void> playUrl(String url) async {
    print('[AudioPlayer] playUrl(): $url');
    await _downloadAndPlay(url);
  }

  static Future<void> _downloadAndPlay(String url) async {
    print('[AudioPlayer] === INICIO REPRODUCCIÓN ===');
    
    if (!_initialized) initialize();
    
    // Si ya está reproduciendo la misma URL, detener
    if (_isPlaying && _currentUrl == url) {
      print('[AudioPlayer] Misma URL, deteniendo...');
      await stop();
      return;
    }
    
    try {
      _currentUrl = url;
      
      // PASO 1: Obtener directorio temporal
      print('[AudioPlayer] Paso 1: Obteniendo directorio temporal...');
      final tempDir = await getTemporaryDirectory();
      final fileName = 'tts_${url.hashCode}.mp3';
      final filePath = '${tempDir.path}/$fileName';
      print('[AudioPlayer]   Archivo temporal: $filePath');
      
      // PASO 2: Descargar audio
      print('[AudioPlayer] Paso 2: Descargando desde $url...');
      final response = await http.get(Uri.parse(url));
      print('[AudioPlayer]   Response status: ${response.statusCode}');
      print('[AudioPlayer]   Response size: ${response.bodyBytes.length} bytes');
      
      if (response.statusCode != 200) {
        throw Exception('HTTP ${response.statusCode}: ${response.body.substring(0, response.body.length > 200 ? 200 : response.body.length)}');
      }
      
      if (response.bodyBytes.isEmpty) {
        throw Exception('Respuesta vacía (0 bytes)');
      }
      
      // PASO 3: Guardar en archivo temporal
      print('[AudioPlayer] Paso 3: Guardando archivo temporal...');
      final file = File(filePath);
      await file.writeAsBytes(response.bodyBytes);
      print('[AudioPlayer]   Archivo guardado: ${file.lengthSync()} bytes');
      
      // Verificar que existe
      if (!await file.exists()) {
        throw Exception('El archivo no se guardó correctamente');
      }
      
      // PASO 4: Detener reproducción anterior
      print('[AudioPlayer] Paso 4: Deteniendo reproducción anterior...');
      await _player.stop();
      
      // PASO 5: Cargar y reproducir
      print('[AudioPlayer] Paso 5: Cargando source desde archivo...');
      await _player.setSource(DeviceFileSource(filePath));
      print('[AudioPlayer]   Source cargado');
      
      print('[AudioPlayer] Paso 6: Iniciando reproducción...');
      await _player.resume();
      print('[AudioPlayer]   resume() ejecutado');
      
      _isPlaying = true;
      _onStateChanged?.call(true);
      print('[AudioPlayer] ✅ REPRODUCIENDO');
      
    } catch (e, stackTrace) {
      print('[AudioPlayer] ❌ ERROR COMPLETO:');
      print('[AudioPlayer]   $e');
      print('[AudioPlayer]   Stack: $stackTrace');
      _isPlaying = false;
      _currentUrl = null;
      _onStateChanged?.call(false);
    }
    
    print('[AudioPlayer] === FIN REPRODUCCIÓN ===');
  }

  static Future<void> stop() async {
    print('[AudioPlayer] stop()');
    await _player.stop();
    _isPlaying = false;
    _currentUrl = null;
    _onStateChanged?.call(false);
  }

  static Future<void> dispose() async {
    await _player.dispose();
  }
}
