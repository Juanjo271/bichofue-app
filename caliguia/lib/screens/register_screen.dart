import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../main.dart';
import '../services/auth_service.dart';
import '../widgets/bichofue_avatar.dart';
import 'onboarding_screen.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _emailCtrl = TextEditingController();
  final _usernameCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _obscureConfirm = true;
  String? _errorMessage;

  Future<void> _register() async {
    final email = _emailCtrl.text.trim();
    final username = _usernameCtrl.text.trim();
    final password = _passwordCtrl.text;
    final confirm = _confirmCtrl.text;

    setState(() => _errorMessage = null);
    if (email.isEmpty || username.isEmpty || password.isEmpty) {
      setState(() => _errorMessage = 'Completá todos los campos, parce');
      return;
    }
    if (!email.contains('@')) {
      setState(() => _errorMessage = 'Ingresa un email válido');
      return;
    }
    if (password.length < 4) {
      setState(() => _errorMessage = 'La contraseña debe tener al menos 4 caracteres');
      return;
    }
    if (password != confirm) {
      setState(() => _errorMessage = 'Las contraseñas no coinciden');
      return;
    }

    setState(() => _isLoading = true);

    try {
      final user = await AuthService.register(
        email: email,
        username: username,
        password: password,
      );
      if (user != null && mounted) {
        HapticFeedback.mediumImpact();
        Navigator.of(context).pushAndRemoveUntil(
          PageRouteBuilder(
            pageBuilder: (_, animation, __) => const OnboardingScreen(),
            transitionsBuilder: (_, animation, __, child) {
              return FadeTransition(opacity: animation, child: child);
            },
            transitionDuration: const Duration(milliseconds: 500),
          ),
          (route) => false,
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
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: BichofueColors.negro),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 16),
              // Logo
              const Center(child: BichofueAvatar(size: 90, state: BichofueAvatarState.idle)),
              const SizedBox(height: 24),
              Text(
                'Unite a Bichofué',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      color: BichofueColors.negro,
                    ),
              ),
              const SizedBox(height: 8),
              Text(
                'Creá tu cuenta pa\' descubrir la sucursal del cielo',
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: BichofueColors.cafe,
                    ),
              ),
              const SizedBox(height: 32),
              // Email
              TextField(
                controller: _emailCtrl,
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.next,
                style: Theme.of(context).textTheme.bodyMedium,
                decoration: InputDecoration(
                  labelText: 'Email',
                  hintText: 'tu@email.com',
                  prefixIcon: const Icon(Icons.email_outlined, color: BichofueColors.cafe),
                  errorText: _errorMessage?.contains('email') == true ? _errorMessage : null,
                ),
              ),
              const SizedBox(height: 16),
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
                          (_errorMessage!.contains('username') || _errorMessage!.contains('usuario'))
                      ? _errorMessage
                      : null,
                ),
              ),
              const SizedBox(height: 16),
              // Password
              TextField(
                controller: _passwordCtrl,
                obscureText: _obscurePassword,
                textInputAction: TextInputAction.next,
                style: Theme.of(context).textTheme.bodyMedium,
                decoration: InputDecoration(
                  labelText: 'Contraseña',
                  hintText: 'Mínimo 4 caracteres',
                  prefixIcon: const Icon(Icons.lock_outline, color: BichofueColors.cafe),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscurePassword ? Icons.visibility_off : Icons.visibility,
                      color: BichofueColors.gris,
                    ),
                    onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                    splashRadius: 24,
                  ),
                  errorText: _errorMessage != null && _errorMessage!.contains('contraseña')
                      ? _errorMessage
                      : null,
                ),
              ),
              const SizedBox(height: 16),
              // Confirm password
              TextField(
                controller: _confirmCtrl,
                obscureText: _obscureConfirm,
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => _register(),
                style: Theme.of(context).textTheme.bodyMedium,
                decoration: InputDecoration(
                  labelText: 'Confirmar contraseña',
                  prefixIcon: const Icon(Icons.lock_outline, color: BichofueColors.cafe),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscureConfirm ? Icons.visibility_off : Icons.visibility,
                      color: BichofueColors.gris,
                    ),
                    onPressed: () => setState(() => _obscureConfirm = !_obscureConfirm),
                    splashRadius: 24,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              // Error general
              if (_errorMessage != null &&
                  !_errorMessage!.contains('email') &&
                  !_errorMessage!.contains('username') &&
                  !_errorMessage!.contains('usuario') &&
                  !_errorMessage!.contains('contraseña'))
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(
                    _errorMessage!,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: BichofueColors.cafe,
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                ),
              const SizedBox(height: 24),
              // Botón
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _register,
                  child: _isLoading
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: BichofueColors.negro,
                          ),
                        )
                      : const Text('Crear cuenta'),
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}
