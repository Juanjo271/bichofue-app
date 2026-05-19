/// Modelo para solicitud de ruta (usado por RouteNotifier)
class RouteRequest {
  final String type; // 'specific' o 'circuit'
  final String name;
  final List<RouteStop> stops;

  RouteRequest({
    required this.type,
    required this.name,
    required this.stops,
  });

  bool get isSpecific => type == 'specific';
  bool get isCircuit => type == 'circuit';

  Map<String, dynamic> toJson() => {
    'type': type,
    'name': name,
    'stops': stops.map((s) => s.toJson()).toList(),
  };

  factory RouteRequest.fromJson(Map<String, dynamic> json) {
    return RouteRequest(
      type: json['type'] ?? 'specific',
      name: json['name'] ?? '',
      stops: (json['stops'] as List? ?? [])
          .map((s) => RouteStop.fromJson(s))
          .toList(),
    );
  }
}

class RouteStop {
  final String nombre;
  final double lat;
  final double lon;
  final String? descripcion;

  RouteStop({
    required this.nombre,
    required this.lat,
    required this.lon,
    this.descripcion,
  });

  Map<String, dynamic> toJson() => {
    'nombre': nombre,
    'lat': lat,
    'lon': lon,
    'descripcion': descripcion,
  };

  factory RouteStop.fromJson(Map<String, dynamic> json) {
    return RouteStop(
      nombre: json['nombre'] ?? '',
      lat: (json['lat'] ?? 0).toDouble(),
      lon: (json['lon'] ?? 0).toDouble(),
      descripcion: json['descripcion'],
    );
  }
}
