/// Un lugar que se puede encontrar con la barra de búsqueda: el ID estable
/// del nodo, el nombre que se muestra y otros nombres con los que también
/// se encuentra (alias), que nunca se muestran como nombre del lugar.
class UbicacionBuscable {
  final String id;
  final String nombre;
  final List<String> alias;

  const UbicacionBuscable({
    required this.id,
    required this.nombre,
    this.alias = const [],
  });
}
