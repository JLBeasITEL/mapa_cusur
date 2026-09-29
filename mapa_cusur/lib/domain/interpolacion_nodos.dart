import '../models/grafo_campus.dart';
import '../models/nodo.dart';
import '../utils/geodesia.dart';

/// Distancia máxima, en metros, que puede tener una arista del grafo base
/// antes de subdividirse en nodos "fantasma" intermedios.
///
/// Es el cuarto objetivo específico de la tesis, el requerimiento RNF5 y la
/// aportación técnica declarada: no se elimina ni se cambia de valor. El
/// valor (8 m) es intermedio dentro del rango de error típico de un GPS de
/// smartphone en exteriores (~3-15 m): lo bastante pequeño para que el nodo
/// fantasma más cercano quede dentro de ese margen de error, y lo bastante
/// grande para no generar más nodos de los necesarios.
const double kUmbralInterpolacionMetros = 8.0;

/// Genera los nodos fantasma: subdivide cada arista más larga que
/// [umbralMetros] en tramos iguales (en línea recta, tanto en coordenadas
/// geográficas como en píxeles) para que el usuario pueda "engancharse" al
/// camino más peatonal más cercano en vez de solo a los ~144 nodos base.
///
/// El peso original de la arista se reparte en partes iguales entre los
/// tramos generados, de modo que el tiempo total de recorrer la arista
/// completa (la suma de todos sus tramos) sea idéntico al peso original -la
/// interpolación reparte el tiempo, no lo altera.
///
/// Devuelve un [GrafoCampus] nuevo; no modifica [grafoBase].
GrafoCampus interpolarGrafo(
  GrafoCampus grafoBase, {
  double umbralMetros = kUmbralInterpolacionMetros,
}) {
  final nodos = Map<String, Nodo>.from(grafoBase.nodos);
  final conexiones = <String, Map<String, double>>{
    for (final entry in grafoBase.conexiones.entries)
      entry.key: Map<String, double>.from(entry.value),
  };

  final aristasProcesadas = <String>{};
  final nodosOriginales = grafoBase.conexiones.keys.toList();

  for (final origen in nodosOriginales) {
    final vecinos =
        Map<String, double>.from(grafoBase.conexiones[origen] ?? {});

    for (final destino in vecinos.keys) {
      final nodoOrigen = grafoBase.nodos[origen];
      final nodoDestino = grafoBase.nodos[destino];
      if (nodoOrigen == null || nodoDestino == null) continue;

      final String aristaId = origen.compareTo(destino) < 0
          ? '${origen}_$destino'
          : '${destino}_$origen';
      if (aristasProcesadas.contains(aristaId)) continue;
      aristasProcesadas.add(aristaId);

      final double distancia = distanciaHaversineMetros(
        nodoOrigen.lat,
        nodoOrigen.lng,
        nodoDestino.lat,
        nodoDestino.lng,
      );
      if (distancia <= umbralMetros) continue;

      final int numPuntos = (distancia / umbralMetros).floor();
      final double pesoOriginal = vecinos[destino]!;
      final double tiempoPorTramo = pesoOriginal / (numPuntos + 1);

      conexiones[origen]?.remove(destino);
      conexiones[destino]?.remove(origen);

      String nodoAnterior = origen;
      for (int i = 1; i <= numPuntos; i++) {
        final double fraccion = i / (numPuntos + 1);
        final String nuevoId = '${aristaId}_inter_$i';

        nodos[nuevoId] = Nodo(
          id: nuevoId,
          lat: nodoOrigen.lat + (nodoDestino.lat - nodoOrigen.lat) * fraccion,
          lng: nodoOrigen.lng + (nodoDestino.lng - nodoOrigen.lng) * fraccion,
          pixelX: nodoOrigen.pixelX +
              (nodoDestino.pixelX - nodoOrigen.pixelX) * fraccion,
          pixelY: nodoOrigen.pixelY +
              (nodoDestino.pixelY - nodoOrigen.pixelY) * fraccion,
        );

        (conexiones[nodoAnterior] ??= {})[nuevoId] = tiempoPorTramo;
        (conexiones[nuevoId] ??= {})[nodoAnterior] = tiempoPorTramo;

        nodoAnterior = nuevoId;
      }

      (conexiones[nodoAnterior] ??= {})[destino] = tiempoPorTramo;
      (conexiones[destino] ??= {})[nodoAnterior] = tiempoPorTramo;
    }
  }

  return GrafoCampus(nodos: nodos, conexiones: conexiones);
}
