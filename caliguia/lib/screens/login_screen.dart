import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../main.dart';
import '../services/auth_service.dart';
import '../widgets/bichofue_avatar.dart';
import 'register_screen.dart';
import 'home_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _usernameCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  bool _isLoading = false;
  bool _obscurePassword = true;
  String? _errorMessage;

  Future<void> _login() async {
    final username = _usernameCtrl.text.trim();
    final password = _passwordCtrl.text;

    setState(() => _errorMessage = null);
    if (username.isEmpty || password.isEmpty) {
      setState(() => _errorMessage = 'Ingresa username y contraseña, parce');
      return;
    }

    setState(() => _isLoading = true);

    try {
      final user = await AuthService.login(username: username, password: password);
      if (user != null && mounted) {
        HapticFeedback.mediumImpact();
        Navigator.of(context).pushReplacement(
          PageRouteBuilder(
            pageBuilder: (_, animation, __) => const HomeScreen(),
            transitionsBuilder: (_, animation, __, child) {
              return FadeTransition(opacity: animation, child: child);
            },
            transitionDuration: const Duration(milliseconds: 500),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _errorMessage = e.toString().replaceFirst('Exception: ', ''));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: BichofueColors.beige,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const SizedBox(height: 32),
                // Logo
                const BichofueAvatar(size: 120, state: BichofueAvatarState.idle),
                const SizedBox(height: 24),
                // Saludo caleño
                Text(
                  '¡Oís, ve!',
                  style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                        fontSize: 32,
                        color: BichofueColors.negro,
                      ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Ingresá pa\' descubrir Cali',
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: BichofueColors.cafe,
                      ),
                ),
                const SizedBox(height: 40),
                // Username
                TextField(
                  controller: _usernameCtrl,
                  textInputAction: TextInputAction.next,
                  style: Theme.of(context).textTheme.bodyMedium,
                  decoration: InputDecoration(
                    labelText: 'Username',
                    hintText: 'Tu nombre de usuario',
                    prefixIcon: const Icon(Icons.person_outline, color: BichofueColors.cafe),
                    errorText: _errorMessage != null &&
                            (_errorMessage!.contains('usuario') || _errorMessage!.contains('encontrado'))
                        ? _errorMessage
                        : null,
                  ),
                ),
                const SizedBox(height: 16),
                // Password
                TextField(
                  controller: _passwordCtrl,
                  obscureText: _obscurePassword,
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) => _login(),
                  style: Theme.of(context).textTheme.bodyMedium,
                  decoration: InputDecoration(
                    labelText: 'Contraseña',
                    hintText: 'Tu contraseña',
                    prefixIcon: const Icon(Icons.lock_outline, color: BichofueColors.cafe),
                    errorText: _errorMessage != null &&
                            (_errorMessage!.contains('Contraseña') || _errorMessage!.contains('incorrecta'))
                        ? _errorMessage
                        : null,
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscurePassword ? Icons.visibility_off : Icons.visibility,
                        color: BichofueColors.gris,
                      ),
                      onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                // Error general
                if (_errorMessage != null &&
                    !_errorMessage!.contains('usuario') &&
                    !_errorMessage!.contains('encontrado') &&
                    !_errorMessage!.contains('Contraseña') &&
                    !_errorMessage!.contains('incorrecta'))
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Text(
                      _errorMessage!,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: BichofueColors.cafe,
                            fontWeight: FontWeight.w600,
                          ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                const SizedBox(height: 24),
                // Botón login
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _login,
                    child: _isLoading
                        ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: BichofueColors.negro,
                            ),
                          )
                        : const Text('Ingresar'),
                  ),
                ),
                const SizedBox(height: 20),
                // Link a registro
                TextButton(
                  onPressed: () {
                    Navigator.of(context).push(
                      PageRouteBuilder(
                        pageBuilder: (_, animation, __) => const RegisterScreen(),
                        transitionsBuilder: (_, animation, __, child) {
                          return SlideTransition(
                            position: Tween<Offset>(
                              begin: const Offset(1, 0),
                              end: Offset.zero,
                            ).animate(CurvedAnimation(
                              parent: animation,
                              curve: Curves.easeInOut,
                            )),
                            child: child,
                          );
                        },
                      ),
                    );
                  },
                  child: RichText(
                    text: TextSpan(
                      text: '¿No tenés cuenta? ',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: BichofueColors.cafe,
                          ),
                      children: [
                        TextSpan(
                          text: 'Registrate acá',
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                color: BichofueColors.verde,
                                fontWeight: FontWeight.bold,
                              ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
