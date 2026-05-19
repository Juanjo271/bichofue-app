import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:confetti/confetti.dart';
import 'package:share_plus/share_plus.dart';
import '../main.dart';
import '../models/stamp_model.dart';
import '../services/api_service.dart';
import '../services/audio_player_service.dart';
import '../services/stamp_service.dart';
import '../widgets/bichofue_avatar.dart';
import 'attraction_detail_screen.dart';
import 'home_screen.dart';

/// Pantalla de celebración al identificar un monumento y desbloquear estampa
/// Experiencia tipo B: pantalla completa con confetti, animación 3D, sonido y avatar
class CelebrationScreen extends StatefulWidget {
  final String monumentoNombre;
  final String? monumentoDescripcion;
  final dynamic atractivo;
  final StampModel? stamp;
  final bool alreadyClaimed;
  final bool experimental;
  final String? detectionMethod;

  const CelebrationScreen({
    super.key,
    required this.monumentoNombre,
    this.monumentoDescripcion,
    this.atractivo,
    this.stamp,
    this.alreadyClaimed = false,
    this.experimental = false,
    this.detectionMethod,
  });

  @override
  State<CelebrationScreen> createState() => _CelebrationScreenState();
}

class _CelebrationScreenState extends State<CelebrationScreen>
    with TickerProviderStateMixin {
  late ConfettiController _confettiController;
  late AnimationController _stampController;
  late AnimationController _textController;
  late Animation<double> _stampScaleAnim;
  late Animation<double> _stampRotationAnim;
  late Animation<double> _stampOpacityAnim;
  late Animation<double> _textFadeAnim;
  bool _showButtons = false;
  bool _isSharing = false;

  @override
  void initState() {
    super.initState();

    // Confetti
    _confettiController = ConfettiController(
      duration: const Duration(seconds: 5),
    );

    // Animación de la estampa
    _stampController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );

    _stampScaleAnim = Tween<double>(begin: 0.3, end: 1.0).animate(
      CurvedAnimation(
        parent: _stampController,
        curve: const Interval(0.0, 0.7, curve: Curves.elasticOut),
      ),
    );

    _stampRotationAnim = Tween<double>(begin: -0.5, end: 0.0).animate(
      CurvedAnimation(
        parent: _stampController,
        curve: const Interval(0.0, 0.6, curve: Curves.easeOutBack),
      ),
    );

    _stampOpacityAnim = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _stampController,
        curve: const Interval(0.0, 0.5, curve: Curves.easeOut),
      ),
    );

    // Fade del texto
    _textController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );

    _textFadeAnim = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _textController, curve: Curves.easeOut),
    );

    _startCelebration();
  }

  void _startCelebration() async {
    // Sonido de campana/logro (placeholder - usar sistema de audio existente)
    // TODO: Agregar asset de sonido de logro

    // Iniciar confetti
    _confettiController.play();

    // Animar estampa después de un delay
    await Future.delayed(const Duration(milliseconds: 400));
    _stampController.forward();

    // Mostrar texto
    await Future.delayed(const Duration(milliseconds: 1200));
    _textController.forward();

    // Mostrar botones
    await Future.delayed(const Duration(milliseconds: 2000));
    setState(() => _showButtons = true);
  }

  @override
  void dispose() {
    _confettiController.dispose();
    _stampController.dispose();
    _textController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isClaimed = widget.stamp != null && !widget.alreadyClaimed;

    return Scaffold(
      backgroundColor: BichofueColors.negro.withOpacity(0.95),
      body: Stack(
        children: [
          // Confetti
          Align(
            alignment: Alignment.topCenter,
            child: ConfettiWidget(
              confettiController: _confettiController,
              blastDirectionality: BlastDirectionality.explosive,
              particleDrag: 0.05,
              emissionFrequency: 0.05,
              numberOfParticles: 50,
              gravity: 0.2,
              shouldLoop: false,
              colors: const [
                Color(0xFFF4C400), // Amarillo
                Color(0xFF2F7D32), // Verde
                Color(0xFF7A4A1E), // Café
                Color(0xFFFFFFFF), // Blanco
                Color(0xFFFFD54F), // Dorado
              ],
            ),
          ),

          // Contenido principal
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Avatar Bichofué celebrando
                    const BichofueAvatar(
                      size: 80,
                      state: BichofueAvatarState.speaking,
                    ),
                    const SizedBox(height: 24),

                    // Texto celebratorio
                    AnimatedBuilder(
                      animation: _textFadeAnim,
                      builder: (context, child) {
                        return Opacity(
                          opacity: _textFadeAnim.value,
                          child: Column(
                            children: [
                              Text(
                                isClaimed
                                    ? '¡Uy, ve! ¡Descubriste el'
                                    : '¡Ya conocías el',
                                style: Theme.of(context)
                                    .textTheme
                                    .headlineSmall
                                    ?.copyWith(
                                      color: BichofueColors.beige,
                                      fontSize: 22,
                                    ),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 8),
                              Text(
                                widget.monumentoNombre,
                                style: Theme.of(context)
                                    .textTheme
                                    .headlineLarge
                                    ?.copyWith(
                                      color: BichofueColors.amarillo,
                                      fontSize: 28,
                                    ),
                                textAlign: TextAlign.center,
                              ),
                              if (widget.experimental) ...[
                                const SizedBox(height: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.orange.withOpacity(0.2),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: Colors.orange.withOpacity(0.5),
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.science,
                                        size: 14,
                                        color: Colors.orange[300],
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        'Reconocimiento experimental',
                                        style: TextStyle(
                                          color: Colors.orange[300],
                                          fontSize: 12,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                              if (isClaimed) ...[
                                const SizedBox(height: 16),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 8,
                                  ),
                                  decoration: BoxDecoration(
                                    color: BichofueColors.amarillo.withOpacity(0.2),
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(
                                      color: BichofueColors.amarillo.withOpacity(0.5),
                                    ),
                                  ),
                                  child: Text(
                                    '¡Estampa desbloqueada!',
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodyLarge
                                        ?.copyWith(
                                          color: BichofueColors.amarillo,
                                          fontWeight: FontWeight.bold,
                                        ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        );
                      },
                    ),

                    const SizedBox(height: 32),

                    // Animación de la estampa
                    if (widget.stamp != null)
                      AnimatedBuilder(
                        animation: _stampController,
                        builder: (context, child) {
                          return Transform.scale(
                            scale: _stampScaleAnim.value,
                            child: Transform.rotate(
                              angle: _stampRotationAnim.value,
                              child: Opacity(
                                opacity: _stampOpacityAnim.value,
                                child: _buildStampCard(widget.stamp!),
                              ),
                            ),
                          );
                        },
                      )
                    else
                      // Sin estampa: mostrar icono de monumento
                      AnimatedBuilder(
                        animation: _stampController,
                        builder: (context, child) {
                          return Transform.scale(
                            scale: _stampScaleAnim.value,
                            child: Opacity(
                              opacity: _stampOpacityAnim.value,
                              child: Container(
                                width: 180,
                                height: 180,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: BichofueColors.verde.withOpacity(0.3),
                                  border: Border.all(
                                    color: BichofueColors.verde,
                                    width: 3,
                                  ),
                                ),
                                child: const Icon(
                                  Icons.camera_alt,
                                  size: 80,
                                  color: BichofueColors.verde,
                                ),
                              ),
                            ),
                          );
                        },
                      ),

                    const SizedBox(height: 40),

                    // Botones de acción
                    AnimatedOpacity(
                      opacity: _showButtons ? 1.0 : 0.0,
                      duration: const Duration(milliseconds: 500),
                      child: Column(
                        children: [
                          // Ver historia
                          SizedBox(
                            width: double.infinity,
                            height: 52,
                            child: ElevatedButton.icon(
                              onPressed: () {
                                if (widget.atractivo != null) {
                                  Navigator.of(context).pushReplacement(
                                    MaterialPageRoute(
                                      builder: (_) => AttractionDetailScreen(
                                        atraction: widget.atractivo,
                                      ),
                                    ),
                                  );
                                }
                              },
                              icon: const Icon(Icons.history_edu),
                              label: const Text('Ver historia'),
                            ),
                          ),
                          const SizedBox(height: 12),

                          // Compartir
                          if (isClaimed && widget.stamp != null)
                            SizedBox(
                              width: double.infinity,
                              height: 52,
                              child: OutlinedButton.icon(
                                onPressed: _isSharing ? null : _shareStamp,
                                icon: _isSharing
                                    ? const SizedBox(
                                        width: 20,
                                        height: 20,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: BichofueColors.verde,
                                        ),
                                      )
                                    : const Icon(Icons.share),
                                label: Text(_isSharing ? 'Compartiendo...' : 'Compartir'),
                              ),
                            ),
                          if (isClaimed) const SizedBox(height: 12),

                          // Seguir explorando
                          TextButton.icon(
                            onPressed: () {
                              Navigator.of(context).pushAndRemoveUntil(
                                MaterialPageRoute(
                                  builder: (_) => const HomeScreen(),
                                ),
                                (route) => false,
                              );
                            },
                            icon: const Icon(Icons.map, color: BichofueColors.beige),
                            label: Text(
                              'Seguir explorando',
                              style: TextStyle(color: BichofueColors.beige.withOpacity(0.8)),
                            ),
                          ),
                        ],
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

  Widget _buildStampCard(StampModel stamp) {
    return Container(
      width: 220,
      height: 280,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF2F7D32), Color(0xFF1B5E20)],
        ),
        boxShadow: [
          BoxShadow(
            color: BichofueColors.amarillo.withOpacity(0.3),
            blurRadius: 30,
            spreadRadius: 5,
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Rareza badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: BichofueColors.amarillo.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              stamp.rareza.toUpperCase(),
              style: const TextStyle(
                color: BichofueColors.amarillo,
                fontSize: 10,
                fontWeight: FontWeight.bold,
                letterSpacing: 1,
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Imagen o icono
          Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: BichofueColors.blanco.withOpacity(0.1),
              border: Border.all(
                color: BichofueColors.amarillo.withOpacity(0.5),
                width: 2,
              ),
            ),
            child: stamp.imagenUrl != null
                ? ClipOval(
                    child: Image.network(
                      '${ApiService.baseUrl}${stamp.imagenUrl}',
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => const Icon(
                        Icons.location_on,
                        size: 50,
                        color: BichofueColors.amarillo,
                      ),
                    ),
                  )
                : const Icon(
                    Icons.location_on,
                    size: 50,
                    color: BichofueColors.amarillo,
                  ),
          ),
          const SizedBox(height: 16),

          // Nombre
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              stamp.nombre,
              style: const TextStyle(
                color: BichofueColors.blanco,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(height: 8),

          // Puntos
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.star,
                size: 16,
                color: BichofueColors.amarillo,
              ),
              const SizedBox(width: 4),
              Text(
                '+${stamp.puntos} pts',
                style: const TextStyle(
                  color: BichofueColors.amarillo,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _shareStamp() async {
    if (widget.stamp == null) return;
    setState(() => _isSharing = true);
    try {
      final monumento = widget.monumentoNombre;
      final mensaje = '''🐦 ¡Acabo de descubrir $monumento con Bichofué, mi guía caleño!

📍 Cali, Valle del Cauca
🏆 Estampa desbloqueada: ${widget.stamp!.nombre}
✨ +${widget.stamp!.puntos} pts

¿Querés conocer Cali como un local? Descargá Bichofué y dejá que el pajarito te guíe.

#Bichofue #Cali #TurismoCali #${monumento.replaceAll(' ', '')}''';      
      await Share.share(mensaje, subject: '¡Descubrí $monumento con Bichofué!');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('¡Listo pa\' compartir, parce! 🐦'),
            backgroundColor: BichofueColors.verde,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSharing = false);
    }
  }
}
