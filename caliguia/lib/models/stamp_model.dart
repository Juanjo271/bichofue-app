/// Modelo de Estampa Coleccionable
class StampModel {
  final int id;
  final String nombre;
  final String? descripcion;
  final int? atractivoId;
  final String? imagenUrl;
  final String rareza; // comun, rara, epica, legendaria
  final String categoria;
  final String condicion;
  final int puntos;
  final DateTime? unlockedAt;
  final bool unlocked;
  final bool compartida;
  final DateTime? createdAt;

  StampModel({
    required this.id,
    required this.nombre,
    this.descripcion,
    this.atractivoId,
    this.imagenUrl,
    this.rareza = 'comun',
    this.categoria = 'monumento',
    this.condicion = 'identificar',
    this.puntos = 10,
    this.unlockedAt,
    this.unlocked = false,
    this.compartida = false,
    this.createdAt,
  });

  factory StampModel.fromJson(Map<String, dynamic> json) {
    return StampModel(
      id: json['id'] ?? 0,
      nombre: json['nombre'] ?? 'Estampa',
      descripcion: json['descripcion'],
      atractivoId: json['atractivo_id'],
      imagenUrl: json['imagen_url'],
      rareza: json['rareza'] ?? 'comun',
      categoria: json['categoria'] ?? 'monumento',
      condicion: json['condicion'] ?? 'identificar',
      puntos: json['puntos'] ?? 10,
      unlockedAt: json['unlocked_at'] != null
          ? DateTime.tryParse(json['unlocked_at'])
          : null,
      unlocked: json['unlocked'] == true || json['unlocked_at'] != null,
      compartida: json['compartida'] == 1 || json['compartida'] == true,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'])
          : null,
    );
  }

  /// Color según rareza
  String get rarezaColor {
    switch (rareza) {
      case 'legendaria':
        return '#FF6B00'; // Naranja dorado
      case 'epica':
        return '#9C27B0'; // Púrpura
      case 'rara':
        return '#2196F3'; // Azul
      default:
        return '#4CAF50'; // Verde
    }
  }

  /// Icono según categoría
  String get categoriaIcon {
    switch (categoria) {
      case 'gastronomia':
        return '🍽️';
      case 'naturaleza':
        return '🌿';
      case 'evento':
        return '🎉';
      default:
        return '🏛️';
    }
  }
}

/// Modelo de Logro/Insignia
class AchievementModel {
  final int id;
  final String nombre;
  final String? descripcion;
  final String? imagenUrl;
  final String tipo;
  final int meta;
  final int puntos;
  final int progreso;
  final bool unlocked;
  final DateTime? unlockedAt;

  AchievementModel({
    required this.id,
    required this.nombre,
    this.descripcion,
    this.imagenUrl,
    required this.tipo,
    required this.meta,
    required this.puntos,
    this.progreso = 0,
    this.unlocked = false,
    this.unlockedAt,
  });

  factory AchievementModel.fromJson(Map<String, dynamic> json) {
    return AchievementModel(
      id: json['id'] ?? 0,
      nombre: json['nombre'] ?? 'Logro',
      descripcion: json['descripcion'],
      imagenUrl: json['imagen_url'],
      tipo: json['tipo'] ?? 'visitas',
      meta: json['meta'] ?? 1,
      puntos: json['puntos'] ?? 20,
      progreso: json['progreso'] ?? 0,
      unlocked: json['unlocked'] == true || json['unlocked_at'] != null,
      unlockedAt: json['unlocked_at'] != null
          ? DateTime.tryParse(json['unlocked_at'])
          : null,
    );
  }

  double get progresoPorcentaje {
    if (meta <= 0) return 0.0;
    return (progreso / meta).clamp(0.0, 1.0);
  }

  String get tipoLabel {
    switch (tipo) {
      case 'estampas':
        return 'Colección';
      case 'visitas':
        return 'Exploración';
      case 'compartir':
        return 'Social';
      case 'rutas':
        return 'Rutas';
      case 'horario':
        return 'Nocturno';
      default:
        return 'General';
    }
  }
}

/// Resumen de Gamificación
class GamificationSummary {
  final int totalPuntos;
  final int nivel;
  final String titulo;
  final int estampasDesbloqueadas;
  final int totalEstampas;
  final int logrosDesbloqueados;
  final int totalLogros;
  final int puntosParaSiguienteNivel;

  GamificationSummary({
    this.totalPuntos = 0,
    this.nivel = 1,
    this.titulo = 'Turista Curioso',
    this.estampasDesbloqueadas = 0,
    this.totalEstampas = 0,
    this.logrosDesbloqueados = 0,
    this.totalLogros = 0,
    this.puntosParaSiguienteNivel = 50,
  });

  factory GamificationSummary.fromJson(Map<String, dynamic> json) {
    final data = json['data'] ?? json;
    return GamificationSummary(
      totalPuntos: data['total_puntos'] ?? 0,
      nivel: data['nivel'] ?? 1,
      titulo: data['titulo'] ?? 'Turista Curioso',
      estampasDesbloqueadas: data['estampas_desbloqueadas'] ?? 0,
      totalEstampas: data['total_estampas'] ?? 0,
      logrosDesbloqueados: data['logros_desbloqueados'] ?? 0,
      totalLogros: data['total_logros'] ?? 0,
      puntosParaSiguienteNivel: data['puntos_para_siguiente_nivel'] ?? 50,
    );
  }

  double get progresoNivel {
    final niveles = {1: 0, 2: 50, 3: 150, 4: 300, 5: 500};
    final actual = niveles[nivel] ?? 0;
    final siguiente = niveles[nivel + 1] ?? (actual + 200);
    if (siguiente <= actual) return 1.0;
    return ((totalPuntos - actual) / (siguiente - actual)).clamp(0.0, 1.0);
  }
}
