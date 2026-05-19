import 'package:flutter/material.dart';
import '../main.dart';
import '../models/stamp_model.dart';
import '../models/user.dart';
import '../services/auth_service.dart';
import '../services/preferences_service.dart';
import '../services/stamp_service.dart';
import '../widgets/bichofue_avatar.dart';
import 'login_screen.dart';
import 'ajustes_screen.dart';

/// Pantalla de perfil del usuario con gamificación y configuraciones
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  User? _user;
  GamificationSummary? _summary;
  List<AchievementModel> _achievements = [];
  bool _isLoading = true;
  bool _nightMode = false;

  @override
  void initState() {
    super.initState();
    _loadData();
    _loadNightMode();
  }

  Future<void> _loadData() async {
    final user = AuthService.currentUser;
    final summary = await GamificationService.getSummary();
    final achievements = await AchievementService.getUserAchievements();
    setState(() {
      _user = user;
      _summary = summary;
      _achievements = achievements;
      _isLoading = false;
    });
  }

  Future<void> _loadNightMode() async {
    final enabled = await PreferencesService.isNightModeEnabled();
    setState(() => _nightMode = enabled);
  }

  Future<void> _toggleNightMode() async {
    final newValue = await PreferencesService.toggleNightMode();
    setState(() => _nightMode = newValue);
    BichofueApp.themeNotifier.value = newValue ? ThemeMode.dark : ThemeMode.light;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(newValue
            ? '🌙 Modo nocturno activado'
            : '☀️ Modo diurno activado'),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Future<void> _logout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cerrar sesión'),
        content: const Text('¿Seguro que querés salir, parce?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Salir', style: TextStyle(color: BichofueColors.cafe)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await AuthService.logout();
      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const LoginScreen()),
          (route) => false,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: BichofueColors.beige,
      appBar: AppBar(
        title: const Text('Mi Perfil'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const AjustesScreen()),
              );
            },
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadData,
              color: BichofueColors.amarillo,
              backgroundColor: BichofueColors.verde,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header con avatar y nombre
                    _buildProfileHeader(),
                    const SizedBox(height: 24),

                    // Tarjeta de gamificación
                    _buildGamificationCard(),
                    const SizedBox(height: 24),

                    // Logros recientes
                    _buildAchievementsSection(),
                    const SizedBox(height: 24),

                    // Preferencias
                    _buildPreferencesSection(),
                    const SizedBox(height: 24),

                    // Cerrar sesión
                    _buildLogoutButton(),
                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildProfileHeader() {
    return Center(
      child: Column(
        children: [
          const BichofueAvatar(size: 100, state: BichofueAvatarState.idle),
          const SizedBox(height: 16),
          Text(
            _user?.nombre ?? _user?.username ?? 'Explorador',
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  color: BichofueColors.negro,
                ),
          ),
          const SizedBox(height: 4),
          Text(
            _user?.email ?? '',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: BichofueColors.cafe,
                ),
          ),
          if (_summary != null) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              decoration: BoxDecoration(
                color: BichofueColors.amarillo.withOpacity(0.2),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: BichofueColors.amarillo.withOpacity(0.5)),
              ),
              child: Text(
                '${_summary!.titulo} · Nivel ${_summary!.nivel}',
                style: const TextStyle(
                  color: BichofueColors.cafe,
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildGamificationCard() {
    if (_summary == null) return const SizedBox.shrink();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Progreso',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),

            // Barra de nivel
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            '${_summary!.totalPuntos} pts',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 24,
                              color: BichofueColors.negro,
                            ),
                          ),
                          Text(
                            '${_summary!.puntosParaSiguienteNivel} para Nivel ${_summary!.nivel + 1}',
                            style: TextStyle(
                              color: BichofueColors.cafe,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: LinearProgressIndicator(
                          value: _summary!.progresoNivel,
                          backgroundColor: BichofueColors.grisClaro,
                          valueColor: const AlwaysStoppedAnimation<Color>(
                            BichofueColors.amarillo,
                          ),
                          minHeight: 10,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Stats grid
            Row(
              children: [
                Expanded(
                  child: _buildStatItem(
                    icon: Icons.collections_bookmark,
                    value: '${_summary!.estampasDesbloqueadas}/${_summary!.totalEstampas}',
                    label: 'Estampas',
                  ),
                ),
                Expanded(
                  child: _buildStatItem(
                    icon: Icons.emoji_events,
                    value: '${_summary!.logrosDesbloqueados}/${_summary!.totalLogros}',
                    label: 'Logros',
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem({
    required IconData icon,
    required String value,
    required String label,
  }) {
    return Column(
      children: [
        Icon(icon, color: BichofueColors.verde, size: 28),
        const SizedBox(height: 8),
        Text(
          value,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: BichofueColors.negro,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: BichofueColors.cafe,
          ),
        ),
      ],
    );
  }

  Widget _buildAchievementsSection() {
    final unlocked = _achievements.where((a) => a.unlocked).toList();

    if (unlocked.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Center(
            child: Column(
              children: [
                Icon(
                  Icons.emoji_events_outlined,
                  size: 48,
                  color: BichofueColors.gris,
                ),
                const SizedBox(height: 12),
                Text(
                  'Todavía no desbloqueaste logros',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: BichofueColors.cafe,
                      ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Logros Desbloqueados',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 12),
            ...unlocked.take(3).map((a) => _buildAchievementItem(a)),
            if (unlocked.length > 3)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: TextButton(
                  onPressed: () {
                    // TODO: Navegar a pantalla de logros completos
                  },
                  child: Text(
                    'Ver todos (${unlocked.length})',
                    style: const TextStyle(color: BichofueColors.verde),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildAchievementItem(AchievementModel achievement) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: BichofueColors.amarillo.withOpacity(0.2),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.emoji_events,
              color: BichofueColors.amarillo,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  achievement.nombre,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
                Text(
                  achievement.descripcion ?? '',
                  style: TextStyle(
                    fontSize: 12,
                    color: BichofueColors.cafe,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: BichofueColors.verde.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              '+${achievement.puntos}',
              style: const TextStyle(
                color: BichofueColors.verde,
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPreferencesSection() {
    return Card(
      child: Column(
        children: [
          // Modo Nocturno
          ListTile(
            leading: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: _nightMode
                    ? BichofueColors.amarillo.withOpacity(0.2)
                    : BichofueColors.grisClaro,
                shape: BoxShape.circle,
              ),
              child: Icon(
                _nightMode ? Icons.nights_stay : Icons.wb_sunny,
                color: _nightMode ? BichofueColors.amarillo : BichofueColors.cafe,
              ),
            ),
            title: const Text('Modo Nocturno'),
            subtitle: Text(
              _nightMode
                  ? 'Mostrando lugares abiertos de noche'
                  : 'Destaca lugares abiertos en horario nocturno',
              style: TextStyle(fontSize: 12, color: BichofueColors.cafe),
            ),
            trailing: Switch(
              value: _nightMode,
              onChanged: (_) => _toggleNightMode(),
              activeColor: BichofueColors.amarillo,
              activeTrackColor: BichofueColors.verde.withOpacity(0.5),
            ),
          ),
          const Divider(height: 1),
          // Colección
          ListTile(
            leading: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: BichofueColors.verde.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.collections_bookmark,
                color: BichofueColors.verde,
              ),
            ),
            title: const Text('Mi Colección'),
            subtitle: Text(
              '${_summary?.estampasDesbloqueadas ?? 0} estampas obtenidas',
              style: TextStyle(fontSize: 12, color: BichofueColors.cafe),
            ),
            trailing: const Icon(Icons.chevron_right, color: BichofueColors.gris),
            onTap: () {
              // Navegar a colección - la tab ya existe en HomeScreen
              // Podemos navegar usando el bottom nav
            },
          ),
        ],
      ),
    );
  }

  Widget _buildLogoutButton() {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: OutlinedButton.icon(
        onPressed: _logout,
        icon: const Icon(Icons.logout, color: BichofueColors.cafe),
        label: const Text(
          'Cerrar sesión',
          style: TextStyle(color: BichofueColors.cafe),
        ),
        style: OutlinedButton.styleFrom(
          side: const BorderSide(color: BichofueColors.cafe),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        ),
      ),
    );
  }
}
