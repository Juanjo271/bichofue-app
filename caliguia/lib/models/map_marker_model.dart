/// Modelo de datos para marcadores en el mapa
class MapMarkerModel {
  final int id;
  final String nombre;
  final String? descripcion;
  final String? categoria;
  final double? latitude;
  final double? longitude;
  final bool isEmblematico;
  final String? imagenUrl;
  final String? horario;
  
  MapMarkerModel({
    required this.id,
    required this.nombre,
    this.descripcion,
    this.categoria,
    this.latitude,
    this.longitude,
    this.isEmblematico = false,
    this.imagenUrl,
    this.horario,
  });
  
  factory MapMarkerModel.fromJson(Map<String, dynamic> json) {
    return MapMarkerModel(
      id: json['id'] ?? 0,
      nombre: json['nombre'] ?? 'Sin nombre',
      descripcion: json['descripcion'] ?? json['descripcion_caleña'],
      categoria: json['componente'] ?? json['grupo'] ?? json['patrimonio'],
      latitude: json['latitud'] != null ? (json['latitud'] as num).toDouble() : null,
      longitude: json['longitud'] != null ? (json['longitud'] as num).toDouble() : null,
      isEmblematico: json['es_emblematico'] == 1 || json['es_emblematico'] == true,
      imagenUrl: json['url_imagen_local'],
      horario: json['horario'],
    );
  }
  
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'nombre': nombre,
      'descripcion': descripcion,
      'componente': categoria,
      'latitud': latitude,
      'longitud': longitude,
      'es_emblematico': isEmblematico ? 1 : 0,
      'url_imagen_local': imagenUrl,
      'horario': horario,
    };
  }
  
  @override
  String toString() => 'MapMarkerModel($nombre: $latitude, $longitude)';
}
