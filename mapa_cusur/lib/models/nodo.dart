/// Un punto del grafo del campus: un lugar con nombre (edificio, entrada,
/// estacionamiento) o un nodo estructural/fantasma generado por la
/// interpolación (ver domain/interpolacion_nodos.dart).
class Nodo {
  final String id;
  final double lat;
  final double lng;
  final double pixelX;
  final double pixelY;

  const Nodo({
    required this.id,
    required this.lat,
    required this.lng,
    required this.pixelX,
    required this.pixelY,
  });
}
