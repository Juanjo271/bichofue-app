import 'dart:io';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import '../services/api_service.dart';
import '../widgets/avatar_caleno.dart';
import '../widgets/bichofue_avatar.dart';
import '../main.dart';
import '../models/stamp_model.dart';
import 'attraction_detail_screen.dart';
import 'celebration_screen.dart';

class CameraScreen extends StatefulWidget {
  const CameraScreen({super.key});

  @override
  State<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen> {
  CameraController? _controller;
  bool _isInitializing = true;
  bool _isAnalyzing = false;
  String _statusText = 'Apunta al monumento y toca el boton';

  @override
  void initState() {
    super.initState();
    _initCamera();
  }

  Future<void> _initCamera() async {
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        setState(() {
          _isInitializing = false;
          _statusText = 'No hay camaras disponibles';
        });
        return;
      }

      _controller = CameraController(
        cameras.firstWhere(
          (c) => c.lensDirection == CameraLensDirection.back,
          orElse: () => cameras.first,
        ),
        ResolutionPreset.medium,
        enableAudio: false,
      );

      await _controller!.initialize();
      if (mounted) {
        setState(() => _isInitializing = false);
      }
    } catch (e) {
      print('[Camera] Error inicializando: $e');
      if (mounted) {
        setState(() {
          _isInitializing = false;
          _statusText = 'Error: $e';
        });
      }
    }
  }

  Future<void> _takePicture() async {
    if (_controller == null || !_controller!.value.isInitialized) return;
    if (_isAnalyzing) return;

    setState(() {
      _isAnalyzing = true;
      _statusText = 'Capturando...';
    });

    try {
      final image = await _controller!.takePicture();
      print('[Camera] Foto capturada: ${image.path}');

      setState(() {
        _statusText = 'Analizando con IA...';
      });

      // Simular delay de IA (2 segundos)
      await Future.delayed(const Duration(seconds: 2));

      // Obtener GPS actual
      double? lat, lon;
      try {
        final pos = await Geolocator.getLastKnownPosition();
        if (pos != null) {
          lat = pos.latitude;
          lon = pos.longitude;
        }
      } catch (e) {
        print('[Camera] No se pudo obtener GPS: $e');
      }

      // Enviar al backend con coordenadas
      final result = await ApiService.recognizeImage(
        File(image.path),
        lat: lat,
        lon: lon,
      );

      print('[Camera] Resultado reconocimiento: $result');

      if (result != null && result['success'] == true) {
        final data = result['data'];
        if (data != null && data['atraction'] != null && mounted) {
          final atractivo = data['atraction'];
          final stampData = data['stamp'];
          final alreadyClaimed = result['already_claimed'] == true;
          final isExperimental = result['experimental'] == true;
          final method = result['method']?.toString() ?? 'unknown';

          // Si hay estampa, mostrar celebración primero
          if (stampData != null) {
            final stamp = StampModel.fromJson(stampData);
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (_) => CelebrationScreen(
                  monumentoNombre: atractivo['nombre'] ?? 'Monumento',
                  monumentoDescripcion: atractivo['descripcion'],
                  atractivo: atractivo,
                  stamp: stamp,
                  alreadyClaimed: alreadyClaimed,
                  experimental: isExperimental,
                  detectionMethod: method,
                ),
              ),
            );
          } else {
            // Sin estampa: ir directo al detalle
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (_) => AttractionDetailScreen(
                  atraction: atractivo,
                  experimental: isExperimental,
                  detectionMethod: method,
                ),
              ),
            );
          }
          return;
        }
      }

      // Si no reconoció, mostrar mensaje
      if (mounted) {
        setState(() {
          _isAnalyzing = false;
          _statusText = 'No se reconocio. Intenta de nuevo o acercate mas.';
        });
      }
    } catch (e) {
      print('[Camera] Error: $e');
      if (mounted) {
        setState(() {
          _isAnalyzing = false;
          _statusText = 'Error: $e';
        });
      }
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Preview de camara
          if (_controller != null && _controller!.value.isInitialized)
            CameraPreview(_controller!)
          else
            Container(
              color: Colors.black,
              child: Center(
                child: _isInitializing
                    ? const CircularProgressIndicator(color: Colors.white)
                    : Text(
                        _statusText,
                        style: const TextStyle(color: Colors.white),
                        textAlign: TextAlign.center,
                      ),
              ),
            ),

          // Overlay superior - titulo
          Positioned(
            top: MediaQuery.of(context).padding.top + 16,
            left: 16,
            right: 16,
            child: Row(
              children: [
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close, color: Colors.white, size: 28),
                ),
                const Expanded(
                  child: Text(
                    'Reconocer Monumento',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
                const SizedBox(width: 48),
              ],
            ),
          ),

          // Overlay inferior - estado + boton
          Positioned(
            bottom: 40,
            left: 16,
            right: 16,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Avatar + burbuja mientras analiza
                if (_isAnalyzing) ...[
                  const BichofueAvatar(size: 100),
                  const SizedBox(height: 8),
                  const BurbujaCalena(isPlaying: true),
                  const SizedBox(height: 16),
                ],

                // Texto de estado
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.7),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    _statusText,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
                const SizedBox(height: 16),

                // Boton de captura
                if (!_isAnalyzing)
                  GestureDetector(
                    onTap: _takePicture,
                    child: Container(
                      width: 72,
                      height: 72,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 4),
                        color: Colors.transparent,
                      ),
                      child: Center(
                        child: Container(
                          width: 56,
                          height: 56,
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            color: BichofueColors.amarillo,
                          ),
                        ),
                      ),
                    ),
                  )
                else
                  const SizedBox(
                    width: 72,
                    height: 72,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 4,
                    ),
                  ),
              ],
            ),
          ),

          // Overlay de guia visual (marco del monumento)
          if (!_isAnalyzing)
            Center(
              child: Container(
                width: 250,
                height: 350,
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.white.withOpacity(0.5), width: 2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Center(
                  child: Icon(
                    Icons.center_focus_strong,
                    color: Colors.white54,
                    size: 48,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
