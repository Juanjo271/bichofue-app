import 'package:flutter/material.dart';
import '../main.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import '../services/discovery_service.dart';
import '../services/websocket_service.dart';
import '../widgets/bichofue_avatar.dart';
import 'login_screen.dart';
import 'home_screen.dart';

/// Splash screen de Bichofué
/// Muestra el ave animado con tagline mientras descubre el backend
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  late Animation<double> _fadeAnim;
  late Animation<double> _scaleAnim;
  String _status = 'Buscando servidor...';

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    );

    _fadeAnim = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animController,
        curve: const Interval(0.0, 0.6, curve: Curves.easeOut),
      ),
    );

    _scaleAnim = Tween<double>(begin: 0.6, end: 1.0).animate(
      CurvedAnimation(
        parent: _animController,
        curve: const Interval(0.0, 0.7, curve: Curves.elasticOut),
      ),
    );

    _animController.forward();
    _initApp();
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  Future<void> _initApp() async {
    setState(() => _status = 'Buscando servidor en la red...');
    var url = await DiscoveryService.discoverBackend();

    // Si auto-descubrimiento falló, intentar última URL guardada
    if (url == null) {
      final saved = await DiscoveryService.getSavedUrl();
      if (saved != null) {
        ApiService.setBaseUrl(saved);
        if (await ApiService.isOnline()) {
          url = saved;
        }
      }
    }

    // Si aún no hay URL, mostrar diálogo de fallback
    if (url == null && mounted) {
      url = await _showConnectionFallback();
    }

    if (url != null) {
      ApiService.setBaseUrl(url);
      await WebSocketService.connect(url: url);
    }

    await Future.delayed(const Duration(milliseconds: 1500));
    if (!mounted) return;

    setState(() => _status = 'Verificando sesión...');
    final hasToken = await AuthService.hasToken();

    if (!hasToken) {
      _goTo(const LoginScreen());
      return;
    }

    final user = await AuthService.validateSession();
    if (!mounted) return;

    if (user != null) {
      _goTo(const HomeScreen());
    } else {
      _goTo(const LoginScreen());
    }
  }

  /// Muestra diálogo para ingresar IP:puerto manualmente si el auto-descubrimiento falló
  Future<String?> _showConnectionFallback() async {
    final controller = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        icon: const Icon(Icons.wifi_find, size: 48, color: Colors.orange),
        title: const Text('No se encontró el backend'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('No pudimos encontrar tu laptop en la red WiFi automáticamente.'),
            const SizedBox(height: 8),
            const Text('Ingresa la IP de tu laptop (se muestra al iniciar el servidor):', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: 'IP:Puerto',
                hintText: 'ej: 172.16.211.66:5000',
                prefixIcon: Icon(Icons.computer),
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Omitir'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, controller.text),
            child: const Text('Conectar'),
          ),
        ],
      ),
    );

    if (result != null && result.isNotEmpty) {
      final fixedUrl = result.startsWith('http') ? result : 'http://$result';
      ApiService.setBaseUrl(fixedUrl);
      final online = await ApiService.isOnline();
      if (online) {
        await DiscoveryService.saveBackendUrl(fixedUrl);
        return fixedUrl;
      }
    }
    return null;
  }

  void _goTo(Widget screen) {
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (_, animation, __) => screen,
        transitionsBuilder: (_, animation, __, child) {
          return FadeTransition(opacity: animation, child: child);
        },
        transitionDuration: const Duration(milliseconds: 800),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: BichofueColors.splashGradient,
        ),
        child: Center(
          child: AnimatedBuilder(
            animation: _animController,
            builder: (context, child) {
              return Opacity(
                opacity: _fadeAnim.value,
                child: Transform.scale(
                  scale: _scaleAnim.value,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Logo del Bichofué
                      const BichofueAvatar(size: 180, state: BichofueAvatarState.idle),
                      const SizedBox(height: 32),
                      // Nombre
                      Text(
                        'Bichofué',
                        style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                              color: BichofueColors.blanco,
                              fontSize: 40,
                              letterSpacing: 1,
                            ),
                      ),
                      const SizedBox(height: 8),
                      // Tagline
                      Text(
                        'Descubre Cali a tu manera',
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                              color: BichofueColors.beige,
                              fontSize: 16,
                            ),
                      ),
                      const SizedBox(height: 48),
                      // Loading
                      SizedBox(
                        width: 36,
                        height: 36,
                        child: CircularProgressIndicator(
                          strokeWidth: 3,
                          valueColor: const AlwaysStoppedAnimation<Color>(
                            BichofueColors.amarillo,
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      // Status
                      Text(
                        _status,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: BichofueColors.beige.withOpacity(0.7),
                            ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
