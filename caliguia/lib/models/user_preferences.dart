/// Modelo de preferencias del usuario (onboarding completo)
class UserPreferences {
  final String nombre;
  final int? edad;
  final String? genero;
  final String? origen;
  final String? hospedaje;
  final String? grupo; // familia, pareja, amigos, solo
  final String? duracion; // dias
  final String? presupuesto; // economico, medio, alto, vip
  final List<String> intereses;
  final int perfilId;
  final String perfilName;

  UserPreferences({
    this.nombre = '',
    this.edad,
    this.genero,
    this.origen,
    this.hospedaje,
    this.grupo,
    this.duracion,
    this.presupuesto,
    this.intereses = const [],
    this.perfilId = 0,
    this.perfilName = '',
  });

  Map<String, dynamic> toJson() => {
    'nombre': nombre,
    'edad': edad,
    'genero': genero,
    'origen': origen,
    'hospedaje': hospedaje,
    'grupo': grupo,
    'duracion': duracion,
    'presupuesto': presupuesto,
    'intereses': intereses,
    'perfil_id': perfilId,
    'perfil_name': perfilName,
  };

  factory UserPreferences.fromJson(Map<String, dynamic> json) {
    return UserPreferences(
      nombre: json['nombre'] ?? '',
      edad: json['edad'],
      genero: json['genero'],
      origen: json['origen'],
      hospedaje: json['hospedaje'],
      grupo: json['grupo'],
      duracion: json['duracion'],
      presupuesto: json['presupuesto'],
      intereses: List<String>.from(json['intereses'] ?? []),
      perfilId: json['perfil_id'] ?? 0,
      perfilName: json['perfil_name'] ?? '',
    );
  }

  bool get isEmpty => nombre.isEmpty && perfilId == 0;
}
