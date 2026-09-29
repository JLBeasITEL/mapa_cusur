import '../models/grafo_campus.dart';
import '../models/nodo.dart';

/// Traduce el JSON decodificado de `assets/campus_data.json`
/// (`coordenadas_geo`, `coordenadas_pix`, `conexiones`) a un [GrafoCampus].
///
/// Es el único lugar que conoce el formato del JSON. Es Dart puro (sin
/// Flutter) a propósito: así lo puede reutilizar tanto
/// `data/campus_repository.dart` (que sí depende de Flutter para leer el
/// asset) como `tool/generar_linea_base.dart`, que corre con `dart run` y no
/// puede importar `package:flutter`.
GrafoCampus parsearGrafoCampus(Map<String, dynamic> data) {
  final Map<String, dynamic> geo = data['coordenadas_geo'];
  final Map<String, dynamic> pix = data['coordenadas_pix'];
  final Map<String, dynamic> con = data['conexiones'];

  final nodos = <String, Nodo>{};
  for (final id in geo.keys) {
    final List coordsGeo = geo[id];
    final List? coordsPix = pix[id];
    nodos[id] = Nodo(
      id: id,
      lat: (coordsGeo[0] as num).toDouble(),
      lng: (coordsGeo[1] as num).toDouble(),
      pixelX: coordsPix != null ? (coordsPix[0] as num).toDouble() : 0.0,
      pixelY: coordsPix != null ? (coordsPix[1] as num).toDouble() : 0.0,
    );
  }

  final conexiones = <String, Map<String, double>>{};
  con.forEach((origen, vecinos) {
    conexiones[origen] = {
      for (final entry in (vecinos as Map<String, dynamic>).entries)
        entry.key: (entry.value as num).toDouble(),
    };
  });

  return GrafoCampus(nodos: nodos, conexiones: conexiones);
}

/// Lee la sección `puntos_control` de `assets/campus_data.json`: los IDs de
/// los nodos usados para calibrar `TransformacionAfin` (Fase 4). Devuelve
/// una lista vacía si la sección no existe (JSON de una versión anterior).
List<String> parsearPuntosControl(Map<String, dynamic> data) {
  final List<dynamic>? lista = data['puntos_control'];
  if (lista == null) return const [];
  return lista.map((id) => id as String).toList();
}
