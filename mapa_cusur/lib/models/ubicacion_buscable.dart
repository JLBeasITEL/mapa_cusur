/// Un lugar que se puede encontrar con la barra de búsqueda: el ID estable
/// del nodo, el nombre que se muestra y otros nombres con los que también
/// se encuentra (alias), que nunca se muestran como nombre del lugar.
/// [lat]/[lng] son las coordenadas de su nodo (`null` si no se conocen),
/// para la distancia aproximada a cada resultado.
class UbicacionBuscable {
  final String id;
  final String nombre;
  final List<String> alias;
  final double? lat;
  final double? lng;

  const UbicacionBuscable({
    required this.id,
    required this.nombre,
    this.alias = const [],
    this.lat,
    this.lng,
  });
}
