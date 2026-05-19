import 'package:flutter/material.dart';
import '../services/audio_player_service.dart';
import 'bichofue_avatar.dart';

/// Avatar caleño animado que se muestra cuando se reproduce audio TTS.
/// Ahora envuelve BichofueAvatar para mantener la identidad de marca.
class AvatarCaleno extends StatefulWidget {
  final double size;

  const AvatarCaleno({super.key, this.size = 120});

  @override
  State<AvatarCaleno> createState() => _AvatarCalenoState();
}

class _AvatarCalenoState extends State<AvatarCaleno> {
  bool _isPlaying = false;

  @override
  void initState() {
    super.initState();
    AudioPlayerService.setOnStateChanged((isPlaying) {
      if (mounted) {
        setState(() => _isPlaying = isPlaying);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return BichofueAvatar(
      size: widget.size,
      state: _isPlaying ? BichofueAvatarState.speaking : BichofueAvatarState.idle,
    );
  }
}

/// Burbuja de diálogo caleña que aparece junto al avatar
class BurbujaCalena extends StatelessWidget {
  final bool isPlaying;

  const BurbujaCalena({super.key, required this.isPlaying});

  @override
  Widget build(BuildContext context) {
    if (!isPlaying) return const SizedBox.shrink();

    final frases = [
      '¡Oís, ve!',
      '¡Qué chévere, parce!',
      '¡La sucursal del cielo!',
      '¡Vamos pal\' centro!',
      '¡Esto está bacano!',
    ];

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Text(
        frases[DateTime.now().second % frases.length],
        style: const TextStyle(
          color: Color(0xFF5D4037),
          fontSize: 14,
          fontWeight: FontWeight.bold,
          fontStyle: FontStyle.italic,
        ),
      ),
    );
  }
}
