import 'package:flutter/material.dart';

/// Avatar de Bichofué usando el logo real con efecto 3D (reflejo/sombra)
/// El logo ocupa el 85% del círculo para que se vea grande y legible
/// Mantiene las animaciones: respiración (idle), canto (speaking), escucha (listening)
class BichofueAvatar extends StatefulWidget {
  final double size;
  final BichofueAvatarState state;
  final VoidCallback? onTap;

  const BichofueAvatar({
    super.key,
    this.size = 48,
    this.state = BichofueAvatarState.idle,
    this.onTap,
  });

  @override
  State<BichofueAvatar> createState() => _BichofueAvatarState();
}

enum BichofueAvatarState { idle, speaking, listening }

class _BichofueAvatarState extends State<BichofueAvatar>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );
    _updateAnimation();
  }

  @override
  void didUpdateWidget(BichofueAvatar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.state != oldWidget.state) {
      _updateAnimation();
    }
  }

  void _updateAnimation() {
    _controller.reset();
    switch (widget.state) {
      case BichofueAvatarState.idle:
        _controller.duration = const Duration(milliseconds: 2000);
        _controller.repeat(reverse: true);
        break;
      case BichofueAvatarState.speaking:
        _controller.duration = const Duration(milliseconds: 400);
        _controller.repeat();
        break;
      case BichofueAvatarState.listening:
        _controller.duration = const Duration(milliseconds: 1800);
        _controller.repeat(reverse: true);
        break;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          double scale = 1.0;
          double rotation = 0.0;
          double verticalOffset = 0.0;

          switch (widget.state) {
            case BichofueAvatarState.idle:
              scale = 1.0 + (_controller.value * 0.03);
              verticalOffset = _controller.value * 2.0;
              break;
            case BichofueAvatarState.speaking:
              scale = 1.0 + (_controller.value * 0.06);
              rotation = (_controller.value - 0.5) * 0.08;
              break;
            case BichofueAvatarState.listening:
              rotation = (_controller.value - 0.5) * 0.1;
              scale = 1.0 + ((_controller.value - 0.5).abs() * 0.02);
              break;
          }

          // El logo ocupa el 85% del círculo para que se vea grande
          final logoSize = widget.size * 0.85;
          final padding = (widget.size - logoSize) / 2;

          return Transform.translate(
            offset: Offset(0, -verticalOffset),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Logo con animación
                Transform.scale(
                  scale: scale,
                  child: Transform.rotate(
                    angle: rotation,
                    child: Container(
                      width: widget.size,
                      height: widget.size,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        boxShadow: [
                          // Sombra principal suave
                          BoxShadow(
                            color: const Color(0xFF111111).withValues(alpha: 0.15),
                            blurRadius: widget.size * 0.15,
                            spreadRadius: widget.size * 0.02,
                            offset: Offset(0, widget.size * 0.05),
                          ),
                          // Glow amarillo sutil alrededor
                          BoxShadow(
                            color: const Color(0xFFF4C400).withValues(
                              alpha: widget.state == BichofueAvatarState.speaking
                                  ? 0.3 + (_controller.value * 0.2)
                                  : 0.1,
                            ),
                            blurRadius: widget.size * 0.2,
                            spreadRadius: widget.size * 0.01,
                          ),
                        ],
                      ),
                      child: ClipOval(
                        child: Container(
                          width: widget.size,
                          height: widget.size,
                          color: const Color(0xFFF5F5F5), // Fondo claro para que el logo resalte
                          padding: EdgeInsets.all(padding),
                          child: Image.asset(
                            'assets/images/logo-sin-fondo.png',
                            width: logoSize,
                            height: logoSize,
                            fit: BoxFit.contain,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                // Reflejo 3D debajo del logo
                Transform.scale(
                  scaleY: -0.25,
                  child: Transform.translate(
                    offset: Offset(0, widget.size * 0.15),
                    child: Opacity(
                      opacity: 0.15 + (_controller.value * 0.05),
                      child: Container(
                        width: widget.size * 0.7,
                        height: widget.size * 0.15,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(100),
                          gradient: RadialGradient(
                            colors: [
                              const Color(0xFF111111).withValues(alpha: 0.4),
                              const Color(0xFF111111).withValues(alpha: 0.0),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
