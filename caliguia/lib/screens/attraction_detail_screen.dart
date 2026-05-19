import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../services/audio_player_service.dart';
import '../widgets/avatar_caleno.dart';
import '../widgets/bichofue_avatar.dart';
import '../main.dart';
import 'camera_screen.dart';
import 'chat_screen.dart';
import 'home_screen.dart';

class AttractionDetailScreen extends StatefulWidget {
  final dynamic atraction;
  final bool experimental;
  final String? detectionMethod;

  const AttractionDetailScreen({
    super.key,
    required this.atraction,
    this.experimental = false,
    this.detectionMethod,
  });

  @override
  State<AttractionDetailScreen> createState() => _AttractionDetailScreenState();
}

class _AttractionDetailScreenState extends State<AttractionDetailScreen> {
  bool _isPlaying = false;
  int? _currentAtractionId;

  @override
  void initState() {
    super.initState();
    AudioPlayerService.setOnStateChanged((isPlaying) {
      if (mounted) {
        setState(() => _isPlaying = isPlaying);
      }
    });
  }

  Future<void> _playAudio() async {
    print('[Detail] _playAudio() llamado');
    final id = widget.atraction['id'] as int?;
    print('[Detail] id=$id');
    if (id == null) {
      print('[Detail] ❌ id es null');
      return;
    }

    if (_isPlaying && _currentAtractionId == id) {
      print('[Detail] Deteniendo audio actual...');
      await AudioPlayerService.stop();
      setState(() => _currentAtractionId = null);
    } else {
      print('[Detail] Iniciando audio para atractivo $id...');
      setState(() => _currentAtractionId = id);
      await AudioPlayerService.play(id);
      print('[Detail] AudioPlayerService.play() completado');
    }
  }

  @override
  Widget build(BuildContext context) {
    final nombre = widget.atraction['nombre'] ?? 'Sin nombre';
    final descripcion = widget.atraction['descripcion'] ?? 'Sin descripción disponible';
    final descripcionCalena = widget.atraction['descripcion_caleña'] ?? descripcion;
    final direccion = widget.atraction['direccion'] ?? '';
    final latitud = widget.atraction['latitud'];
    final longitud = widget.atraction['longitud'];
    final esEmblematico = widget.atraction['es_emblematico'] == 1;
    final id = widget.atraction['id'] as int?;

    return Scaffold(
      appBar: AppBar(
        title: Text(nombre),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Avatar caleño + burbuja
            Center(
              child: Column(
                children: [
                  const AvatarCaleno(size: 100),
                  const SizedBox(height: 8),
                  BurbujaCalena(isPlaying: _isPlaying && _currentAtractionId == id),
                  const SizedBox(height: 12),
                  if (esEmblematico)
                    GestureDetector(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const CameraScreen(),
                          ),
                        );
                      },
                      child: Chip(
                        label: const Text('Reconocible por cámara 📷'),
                        backgroundColor: Colors.amber.shade100,
                        avatar: const Icon(Icons.camera_alt, size: 18),
                      ),
                    ),
                  if (widget.experimental)
                    Container(
                      margin: const EdgeInsets.only(top: 8),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.orange.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: Colors.orange.withOpacity(0.4),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.science,
                            size: 14,
                            color: Colors.orange[400],
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'Detectado con IA experimental',
                            style: TextStyle(
                              color: Colors.orange[400],
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Descripción caleña (si existe)
            if (descripcionCalena.isNotEmpty && descripcionCalena != descripcion) ...[
              Row(
                children: [
                  const BichofueAvatar(size: 40),
                  const SizedBox(width: 8),
                  Text(
                    'Narración caleña',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: BichofueColors.cafe,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: BichofueColors.beige,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: BichofueColors.amarillo.withOpacity(0.3)),
                ),
                child: Text(
                  descripcionCalena,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    fontStyle: FontStyle.italic,
                    color: BichofueColors.negro,
                    height: 1.5,
                  ),
                ),
              ),
              const SizedBox(height: 24),
            ],

            // Descripción normal
            Text(
              'Descripción',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              descripcion,
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            const SizedBox(height: 24),

            // Narrativa del barrio (contexto cultural)
            if (widget.atraction['barrio_narrativa'] != null && widget.atraction['barrio_narrativa'].toString().isNotEmpty) ...[
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [BichofueColors.verde.withOpacity(0.1), BichofueColors.amarillo.withOpacity(0.1)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: BichofueColors.verde.withOpacity(0.3)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.location_city, color: BichofueColors.verde, size: 20),
                        const SizedBox(width: 8),
                        Text(
                          'Historia del barrio',
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            color: BichofueColors.verde,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      widget.atraction['barrio_narrativa'].toString(),
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: BichofueColors.negro.withOpacity(0.8),
                        height: 1.6,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
            ],

            // Dirección
            if (direccion.isNotEmpty) ...[
              Text(
                'Dirección',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(Icons.location_on, color: BichofueColors.cafe),
                  const SizedBox(width: 8),
                  Expanded(child: Text(direccion)),
                ],
              ),
              const SizedBox(height: 24),
            ],

            // Coordenadas
            if (latitud != null && longitud != null) ...[
              Text(
                'Ubicación',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              Card(
                child: ListTile(
                  leading: const Icon(Icons.map),
                  title: Text('$latitud, $longitud'),
                  subtitle: const Text('Latitud, Longitud'),
                ),
              ),
              const SizedBox(height: 24),
            ],

            // Botón de audio TTS
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _playAudio,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _isPlaying && _currentAtractionId == id
                      ? BichofueColors.cafe
                      : BichofueColors.amarillo,
                  foregroundColor: BichofueColors.negro,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(24),
                  ),
                ),
                icon: Icon(
                  _isPlaying && _currentAtractionId == id
                      ? Icons.stop
                      : Icons.play_arrow,
                ),
                label: Text(
                  _isPlaying && _currentAtractionId == id
                      ? 'Detener narración'
                      : 'Escuchar en caleño 🎙️',
                  style: const TextStyle(fontSize: 16),
                ),
              ),
            ),
            const SizedBox(height: 12),

            // Botón Ver ruta
            if (latitud != null && longitud != null)
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () {
                    Navigator.pushAndRemoveUntil(
                      context,
                      MaterialPageRoute(builder: (_) => const HomeScreen()),
                      (route) => false,
                    );
                  },
                  icon: const Icon(Icons.map),
                  label: const Text('Ver en mapa'),
                ),
              ),
            if (latitud != null && longitud != null)
              const SizedBox(height: 12),

            // Botón de chat
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const ChatScreen()),
                  );
                },
                icon: const Icon(Icons.chat),
                label: const Text('Preguntar al guía Bichofué'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    if (_isPlaying) {
      AudioPlayerService.stop();
    }
    super.dispose();
  }
}
