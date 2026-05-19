/// Modelo de usuario autenticado con datos del perfil completo.
class User {
  final int id;
  final String email;
  final String username;
  final String token;
  final String? nombre;
  final int? edad;
  final String? genero;
  final String? origen;
  final String? hospedaje;
  final String? grupo;
  final String? duracion;
  final String? presupuesto;
  final List<String> intereses;
  final int perfilId;
  final String perfilName;

  User({
    required this.id,
    required this.email,
    required this.username,
    required this.token,
    this.nombre,
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

  factory User.fromJson(Map<String, dynamic> json, String token) {
    return User(
      id: json['id'] ?? 0,
      email: json['email'] ?? '',
      username: json['username'] ?? '',
      token: token,
      nombre: json['nombre'],
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

  Map<String, dynamic> toJson() => {
    'id': id,
    'email': email,
    'username': username,
    'token': token,
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

  bool get hasProfile => nombre != null && nombre!.isNotEmpty;

  @override
  String toString() => 'User(id: $id, username: $username, hasProfile: $hasProfile)';
}
