import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/user_service.dart';
import '../services/auth_service.dart';
import '../models/user_preferences.dart';
import '../main.dart';
import 'home_screen.dart';

/// Datos de los 6 perfiles turísticos disponibles
final List<Map<String, dynamic>> perfiles = [
  {
    'id': 1,
    'nombre': 'Turismo Cultural & Salsa',
    'descripcion': 'Pa los que le mueven el alma a la música y el baile',
    'icono': Icons.music_note,
    'color': Color(0xFF7A4A1E), // Café Natural
  },
  {
    'id': 2,
    'nombre': 'Naturaleza & Ecoturismo',
    'descripcion': 'Pa los que disfrutan el aire puro y los paisajes',
    'icono': Icons.forest,
    'color': Color(0xFF2F7D32), // Verde Tropical
  },
  {
    'id': 3,
    'nombre': 'Turismo Comunitario',
    'descripcion': 'Pa conocer la fuerza de los barrios y su gente',
    'icono': Icons.people,
    'color': Color(0xFFF4C400), // Amarillo Bichofué
  },
  {
    'id': 4,
    'nombre': 'Turismo Deportivo',
    'descripcion': 'Pa los que no paran quietos ni un momento',
    'icono': Icons.sports,
    'color': Color(0xFF111111), // Negro Profundo
  },
  {
    'id': 5,
    'nombre': 'Turismo Médico y Bienestar',
    'descripcion': 'Pa relajarse y recuperarse con calidad',
    'icono': Icons.spa,
    'color': Color(0xFFF6E7D8), // Beige Cálido
  },
  {
    'id': 6,
    'nombre': 'Turismo de Compras',
    'descripcion': 'Pa los que les gusta llevarse recuerdos y regalos',
    'icono': Icons.shopping_bag,
    'color': Color(0xFF4CAF50), // Verde claro
  },
];

/// Las 7 categorías de interés del diagrama
final List<Map<String, String>> categoriasInteres = [
  {'key': 'baile', 'label': 'Baile, ambiente nocturno y bares'},
  {'key': 'gastronomia', 'label': 'Gastronomía'},
  {'key': 'naturaleza', 'label': 'Senderismo, birdwatching, ríos, biodiversidad'},
  {'key': 'comunitario', 'label': 'Turismo comunitario'},
  {'key': 'eventos', 'label': 'Eventos próximos o en curso'},
  {'key': 'cultura', 'label': 'Museos, sitios históricos, iglesias, librerías'},
  {'key': 'sancocho', 'label': '¡Hazme un buen sancocho valluno!'},
];

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen>
    with SingleTickerProviderStateMixin {
  late final PageController _pageController;
  late final AnimationController _animController;
  int _currentPage = 0;
  bool _isLoading = false;

  // Paso 1: Datos personales
  final _nombreCtrl = TextEditingController();
  final _edadCtrl = TextEditingController();
  String? _genero;
  final _origenCtrl = TextEditingController();
  final _hospedajeCtrl = TextEditingController();

  // Paso 2: Grupo
  String? _grupo;

  // Paso 3: Duración
  String? _duracion;

  // Paso 4: Presupuesto
  String? _presupuesto;

  // Paso 5: Intereses (key -> ranking 1-7, null si no asignado)
  final Map<String, int?> _intereses = {};

  // Paso 6: Perfil
  int? _perfilIndex;

  final List<String> _generos = ['Masculino', 'Femenino', 'Otro', 'Prefiero no decir'];
  final List<String> _grupos = ['Familia', 'Pareja', 'Parche de amigos', 'Solo'];
  final List<String> _duraciones = ['1 día', '2-3 días', '4-7 días', 'Más de 7 días'];
  final List<String> _presupuestos = ['Económico', 'Medio', 'Alto', 'VIP'];

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    _animController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _animController.forward();
    for (final c in categoriasInteres) {
      _intereses[c['key']!] = null;
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    _animController.dispose();
    _nombreCtrl.dispose();
    _edadCtrl.dispose();
    _origenCtrl.dispose();
    _hospedajeCtrl.dispose();
    super.dispose();
  }

  void _nextPage() {
    if (_validateCurrentPage()) {
      HapticFeedback.lightImpact();
      _pageController.nextPage(
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOut,
      );
    }
  }

  void _prevPage() {
    HapticFeedback.lightImpact();
    _pageController.previousPage(
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeInOut,
    );
  }

  bool _validateCurrentPage() {
    switch (_currentPage) {
      case 0:
        if (_nombreCtrl.text.trim().isEmpty) {
          _showError('Ingresa tu nombre, parce');
          return false;
        }
        if (_edadCtrl.text.trim().isEmpty || int.tryParse(_edadCtrl.text) == null) {
          _showError('Ingresa una edad válida');
          return false;
        }
        if (_genero == null) {
          _showError('Selecciona tu género');
          return false;
        }
        if (_origenCtrl.text.trim().isEmpty) {
          _showError('¿De dónde venís?');
          return false;
        }
        if (_hospedajeCtrl.text.trim().isEmpty) {
          _showError('¿Dónde te vas a hospedar?');
          return false;
        }
        return true;
      case 1:
        if (_grupo == null) {
          _showError('Selecciona con quién venís');
          return false;
        }
        return true;
      case 2:
        if (_duracion == null) {
          _showError('¿Cuánto tiempo durará tu borondo?');
          return false;
        }
        return true;
      case 3:
        if (_presupuesto == null) {
          _showError('¿Con cuántas lukas contás?');
          return false;
        }
        return true;
      case 4:
        final rankings = _intereses.values.whereType<int>().toList();
        if (rankings.length < 3) {
          _showError('Ordena al menos 3 categorías porfa');
          return false;
        }
        final unique = rankings.toSet();
        if (unique.length != rankings.length) {
          _showError('No repitas números en el ranking');
          return false;
        }
        return true;
      case 5:
        if (_perfilIndex == null) {
          _showError('Selecciona un perfil turístico');
          return false;
        }
        return true;
      default:
        return true;
    }
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: BichofueColors.verde,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  Future<void> _finish() async {
    setState(() => _isLoading = true);
    HapticFeedback.mediumImpact();

    // Ordenar intereses por ranking
    final sortedEntries = _intereses.entries
        .where((e) => e.value != null)
        .toList()
      ..sort((a, b) => a.value!.compareTo(b.value!));
    final interesesOrdenados = sortedEntries.map((e) => e.key).toList();

    final perfil = perfiles[_perfilIndex!];

    final prefs = UserPreferences(
      nombre: _nombreCtrl.text.trim(),
      edad: int.tryParse(_edadCtrl.text),
      genero: _genero,
      origen: _origenCtrl.text.trim(),
      hospedaje: _hospedajeCtrl.text.trim(),
      grupo: _grupo,
      duracion: _duracion,
      presupuesto: _presupuesto,
      intereses: interesesOrdenados,
      perfilId: perfil['id'],
      perfilName: perfil['nombre'],
    );

    // Guardar localmente
    await UserService.setPreferences(prefs);

    // Sincronizar con backend (si hay sesión activa)
    try {
      await AuthService.updateProfile(prefs);
    } catch (e) {
      print('[Onboarding] Error sync con backend: $e');
      // No bloquear el flujo si falla el backend
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Perfil guardado localmente. Se sincronizará cuando haya conexión.'),
            backgroundColor: Colors.orange,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }

    await Future.delayed(const Duration(milliseconds: 500));

    if (mounted) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const HomeScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      body: SafeArea(
        child: Column(
          children: [
            // Barra de progreso
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
              child: Row(
                children: List.generate(7, (index) {
                  return Expanded(
                    child: Container(
                      height: 4,
                      margin: const EdgeInsets.symmetric(horizontal: 2),
                      decoration: BoxDecoration(
                        color: index <= _currentPage
                            ? BichofueColors.verde
                            : Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  );
                }),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Paso ${_currentPage + 1} de 7',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade600,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            // Contenido
            Expanded(
              child: PageView(
                controller: _pageController,
                physics: const NeverScrollableScrollPhysics(),
                onPageChanged: (index) {
                  setState(() => _currentPage = index);
                  _animController.forward(from: 0);
                },
                children: [
                  _buildStep1(),
                  _buildStep2(),
                  _buildStep3(),
                  _buildStep4(),
                  _buildStep5(),
                  _buildStep6(),
                  _buildStep7(),
                ],
              ),
            ),
            // Botones de navegación
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
              child: Row(
                children: [
                  if (_currentPage > 0)
                    TextButton.icon(
                      onPressed: _prevPage,
                      icon: const Icon(Icons.arrow_back),
                      label: const Text('Atrás'),
                    )
                  else
                    const SizedBox(width: 80),
                  const Spacer(),
                  if (_currentPage < 6)
                    ElevatedButton.icon(
                      onPressed: _nextPage,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: BichofueColors.verde,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                        minimumSize: const Size(120, 48),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      icon: const Icon(Icons.arrow_forward),
                      label: const Text('Siguiente'),
                    )
                  else
                    ElevatedButton.icon(
                      onPressed: _isLoading ? null : _finish,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: BichofueColors.verde,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      icon: _isLoading
                          ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : const Icon(Icons.check),
                      label: const Text('¡Vamos!'),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ========== PASO 1: BIENVENIDA + DATOS PERSONALES ==========
  Widget _buildStep1() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 20),
          FadeTransition(
            opacity: Tween<double>(begin: 0, end: 1).animate(
              CurvedAnimation(parent: _animController, curve: Curves.easeOut),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '¡Oís, ve!',
                  style: TextStyle(
                    fontSize: 36,
                    fontWeight: FontWeight.bold,
                    color: BichofueColors.verde,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Bienvenido a Cali, la sucursal del cielo. Soy tu compañero de borondo. Primero, contame de vos:',
                  style: TextStyle(fontSize: 16, color: Colors.black87, height: 1.4),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          _buildTextField(_nombreCtrl, 'Nombre', Icons.person, '¿Cómo te dicen, parce?'),
          const SizedBox(height: 12),
          _buildTextField(_edadCtrl, 'Edad', Icons.cake, '¿Cuántos años tenés?', keyboardType: TextInputType.number),
          const SizedBox(height: 12),
          _buildDropdown('Género', _generos, _genero, (v) => setState(() => _genero = v)),
          const SizedBox(height: 12),
          _buildTextField(_origenCtrl, 'Región / País', Icons.public, '¿De dónde venís?'),
          const SizedBox(height: 12),
          _buildTextField(_hospedajeCtrl, '¿Dónde te hospedás?', Icons.hotel, 'Barrio o zona'),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  // ========== PASO 2: PLAN DE VIAJE ==========
  Widget _buildStep2() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 20),
          Text(
            '¿Con quién venís a Cali?',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: BichofueColors.verde),
          ),
          const SizedBox(height: 8),
          const Text(
            'Pa organizar el parche ideal:',
            style: TextStyle(fontSize: 16, color: Colors.black87),
          ),
          const SizedBox(height: 24),
          ..._grupos.map((g) {
            final isSelected = _grupo == g;
            final icons = {
              'Familia': Icons.family_restroom,
              'Pareja': Icons.favorite,
              'Parche de amigos': Icons.group,
              'Solo': Icons.person,
            };
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: InkWell(
                onTap: () => setState(() => _grupo = g),
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: isSelected ? BichofueColors.verde.withValues(alpha: 0.1) : Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isSelected ? BichofueColors.verde : Colors.grey.shade300,
                      width: isSelected ? 2 : 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(icons[g], color: isSelected ? BichofueColors.verde : Colors.grey.shade600),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Text(
                          g,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                            color: isSelected ? BichofueColors.verde : Colors.black87,
                          ),
                        ),
                      ),
                      if (isSelected) Icon(Icons.check_circle, color: BichofueColors.verde),
                    ],
                  ),
                ),
              ),
            );
          }),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  // ========== PASO 3: DURACIÓN ==========
  Widget _buildStep3() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 20),
          Text(
            '¿Cuánto tiempo durará tu borondo por Cali?',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: BichofueColors.verde),
          ),
          const SizedBox(height: 8),
          const Text(
            'Así te armo el plan perfecto:',
            style: TextStyle(fontSize: 16, color: Colors.black87),
          ),
          const SizedBox(height: 24),
          ..._duraciones.map((d) {
            final isSelected = _duracion == d;
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: InkWell(
                onTap: () => setState(() => _duracion = d),
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: isSelected ? BichofueColors.verde.withValues(alpha: 0.1) : Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isSelected ? BichofueColors.verde : Colors.grey.shade300,
                      width: isSelected ? 2 : 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.calendar_today,
                        color: isSelected ? BichofueColors.verde : Colors.grey.shade600,
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Text(
                          d,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                            color: isSelected ? BichofueColors.verde : Colors.black87,
                          ),
                        ),
                      ),
                      if (isSelected) Icon(Icons.check_circle, color: BichofueColors.verde),
                    ],
                  ),
                ),
              ),
            );
          }),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  // ========== PASO 4: PRESUPUESTO ==========
  Widget _buildStep4() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 20),
          Text(
            '¿Con cuántas lukas contás?',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: BichofueColors.verde),
          ),
          const SizedBox(height: 8),
          const Text(
            'Pa recomendarte lo mejor según tu bolsillo:',
            style: TextStyle(fontSize: 16, color: Colors.black87),
          ),
          const SizedBox(height: 24),
          ..._presupuestos.map((p) {
            final isSelected = _presupuesto == p;
            final colors = {
              'Económico': Colors.green,
              'Medio': Colors.blue,
              'Alto': Colors.orange,
              'VIP': Colors.purple,
            };
            final color = colors[p]!;
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: InkWell(
                onTap: () => setState(() => _presupuesto = p),
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: isSelected ? color.withValues(alpha: 0.1) : Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isSelected ? color : Colors.grey.shade300,
                      width: isSelected ? 2 : 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.account_balance_wallet,
                        color: isSelected ? color : Colors.grey.shade600,
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Text(
                          p,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                            color: isSelected ? color : Colors.black87,
                          ),
                        ),
                      ),
                      if (isSelected) Icon(Icons.check_circle, color: color),
                    ],
                  ),
                ),
              ),
            );
          }),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  // ========== PASO 5: RANKING DE INTERESES ==========
  Widget _buildStep5() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 20),
          Text(
            '¿En qué te gustaría darte un roce por Cali?',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: BichofueColors.verde),
          ),
          const SizedBox(height: 8),
          const Text(
            'Ordenalos de 1 (más importante) a 7 (menos importante). Dejá en blanco los que no te interesen:',
            style: TextStyle(fontSize: 15, color: Colors.black87, height: 1.4),
          ),
          const SizedBox(height: 24),
          // Detectar números repetidos en tiempo real
          ...() {
            final usedNumbers = <int>[];
            final duplicates = <int>[];
            for (final entry in _intereses.entries) {
              final val = entry.value;
              if (val != null) {
                if (usedNumbers.contains(val)) {
                  duplicates.add(val);
                } else {
                  usedNumbers.add(val);
                }
              }
            }
            return categoriasInteres.map((cat) {
              final key = cat['key']!;
              final label = cat['label']!;
              final currentVal = _intereses[key];
              // Números usados por otros intereses (no por este)
              final usedByOthers = _intereses.entries
                  .where((e) => e.key != key && e.value != null)
                  .map((e) => e.value as int)
                  .toSet();
              final hasDuplicate = currentVal != null && duplicates.contains(currentVal);
              return Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: hasDuplicate ? BichofueColors.cafe : Colors.grey.shade300,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              label,
                              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                            ),
                          ),
                          const SizedBox(width: 8),
                          DropdownButton<int?>(
                            value: currentVal,
                            hint: const Text('—', style: TextStyle(fontSize: 14)),
                            underline: const SizedBox.shrink(),
                            items: [
                              const DropdownMenuItem(value: null, child: Text('—')),
                              ...List.generate(7, (i) => i + 1).map((n) {
                                final isUsed = usedByOthers.contains(n);
                                return DropdownMenuItem(
                                  value: n,
                                  enabled: !isUsed,
                                  child: Text(
                                    n.toString(),
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: currentVal == n ? FontWeight.bold : FontWeight.normal,
                                      color: isUsed
                                          ? Colors.grey.shade400
                                          : (n <= 3 ? BichofueColors.verde : Colors.black87),
                                    ),
                                  ),
                                );
                              }),
                            ],
                            onChanged: (v) => setState(() => _intereses[key] = v),
                          ),
                        ],
                      ),
                      if (hasDuplicate)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            '⚠️ El número $currentVal ya está asignado a otro interés',
                            style: TextStyle(fontSize: 12, color: BichofueColors.verde),
                          ),
                        ),
                    ],
                  ),
                ),
              );
            }).toList();
          }(),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  // ========== PASO 6: PERFIL TURÍSTICO ==========
  Widget _buildStep6() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 20),
          Text(
            '¿Qué te mueve el corazón, parce?',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: BichofueColors.verde),
          ),
          const SizedBox(height: 8),
          const Text(
            'Selecciona tu perfil turístico principal:',
            style: TextStyle(fontSize: 16, color: Colors.black87),
          ),
          const SizedBox(height: 24),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 0.9,
            ),
            itemCount: perfiles.length,
            itemBuilder: (ctx, index) {
              final perfil = perfiles[index];
              final isSelected = _perfilIndex == index;
              final color = perfil['color'] as Color;

              return InkWell(
                onTap: () => setState(() => _perfilIndex = index),
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: isSelected ? color.withValues(alpha: 0.12) : Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isSelected ? color : Colors.grey.shade300,
                      width: isSelected ? 2.5 : 1,
                    ),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: 0.15),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          perfil['icono'] as IconData,
                          color: color,
                          size: 24,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        perfil['nombre'] as String,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                          color: isSelected ? color : Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        perfil['descripcion'] as String,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey.shade600,
                        ),
                      ),
                      if (isSelected) ...[
                        const SizedBox(height: 8),
                        Icon(Icons.check_circle, color: color, size: 20),
                      ],
                    ],
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  // ========== PASO 7: RESUMEN Y BIENVENIDA ==========
  Widget _buildStep7() {
    final interesesOrdenados = _intereses.entries
        .where((e) => e.value != null)
        .toList()
      ..sort((a, b) => a.value!.compareTo(b.value!));

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 20),
          Center(
            child: Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: BichofueColors.verde.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.celebration, size: 40, color: BichofueColors.verde),
            ),
          ),
          const SizedBox(height: 20),
          Center(
            child: Text(
              '¡Listo, ${_nombreCtrl.text.trim()}!',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: BichofueColors.verde),
            ),
          ),
          const SizedBox(height: 8),
          const Center(
            child: Text(
              'Ya te tengo perfilado, parce. Así va tu borondo:',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16, color: Colors.black87),
            ),
          ),
          const SizedBox(height: 24),
          _buildResumenCard('Nombre', _nombreCtrl.text.trim(), Icons.person),
          _buildResumenCard('Origen', _origenCtrl.text.trim(), Icons.public),
          _buildResumenCard('Hospedaje', _hospedajeCtrl.text.trim(), Icons.hotel),
          _buildResumenCard('Grupo', _grupo ?? '', Icons.group),
          _buildResumenCard('Duración', _duracion ?? '', Icons.calendar_today),
          _buildResumenCard('Presupuesto', _presupuesto ?? '', Icons.account_balance_wallet),
          if (interesesOrdenados.isNotEmpty)
            _buildResumenCard(
              'Top intereses',
              interesesOrdenados.take(3).map((e) {
                final label = categoriasInteres.firstWhere((c) => c['key'] == e.key)['label'];
                return '${e.value}. $label';
              }).join('\n'),
              Icons.star,
            ),
          if (_perfilIndex != null)
            _buildResumenCard(
              'Perfil',
              perfiles[_perfilIndex!]['nombre'],
              perfiles[_perfilIndex!]['icono'] as IconData,
            ),
          const SizedBox(height: 24),
          Center(
            child: Text(
              'Zaperoco, Borondo, Bienteveo, Bichofué, Buziraco, Sotavento...\n¡Te esperan!',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                fontStyle: FontStyle.italic,
                color: Colors.grey.shade700,
                height: 1.5,
              ),
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildTextField(
    TextEditingController controller,
    String label,
    IconData icon,
    String hint, {
    TextInputType keyboardType = TextInputType.text,
  }) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: Icon(icon, color: BichofueColors.verde),
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: BichofueColors.verde, width: 2),
        ),
      ),
    );
  }

  Widget _buildDropdown(
    String label,
    List<String> items,
    String? value,
    ValueChanged<String?> onChanged,
  ) {
    return InputDecorator(
      decoration: InputDecoration(
        labelText: label,
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.shade300),
        ),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          isDense: true,
          isExpanded: true,
          hint: const Text('Selecciona...'),
          items: items.map((item) {
            return DropdownMenuItem(value: item, child: Text(item));
          }).toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }

  Widget _buildResumenCard(String label, String value, IconData icon) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          Icon(icon, size: 20, color: BichofueColors.verde),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                Text(value, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
