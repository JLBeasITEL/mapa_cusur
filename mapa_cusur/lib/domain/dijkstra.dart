import '../models/grafo_campus.dart';
import '../models/ruta.dart';
import '../utils/priority_queue.dart';

/// Calcula la ruta más corta (en minutos) entre [idInicio] y [idDestino]
/// sobre [grafo] con el algoritmo de Dijkstra.
///
/// Devuelve [Ruta.vacia] si alguno de los dos IDs no es un nodo del grafo,
/// o si no existe camino entre ellos.
///
/// El desempate entre caminos igualmente óptimos es determinista (por ID de
/// nodo, ver más abajo), así que el resultado es reproducible: el mismo
/// grafo siempre produce la misma ruta, sin importar el orden interno de
/// extracción de la cola de prioridad. Es una propiedad deseable para
/// reportar en la tesis -sin ella, cambiar la implementación de la cola
/// (como se hizo en esta misma fase, de lista ordenada a montículo binario)
/// podría reconstruir un camino distinto -con el mismo tiempo total- para
/// pares con más de una ruta óptima.
Ruta calcularRutaMasCorta(
  GrafoCampus grafo,
  String idInicio,
  String idDestino,
) {
  final conexiones = grafo.conexiones;
  if (!conexiones.containsKey(idInicio) || !conexiones.containsKey(idDestino)) {
    return Ruta.vacia;
  }

  final distancias = <String, double>{};
  final padres = <String, String?>{};

  // Se inicializa sobre la unión de claves y vecinos, no solo
  // `conexiones.keys`: si un nodo solo apareciera como vecino (nunca como
  // origen, es decir, sin entrada propia en `conexiones`), el acceso
  // `distancias[vecino]!` de más abajo lanzaría un null-check error.
  for (final nodo in conexiones.keys) {
    distancias[nodo] = double.infinity;
    padres[nodo] = null;
  }
  for (final vecinos in conexiones.values) {
    for (final vecino in vecinos.keys) {
      distancias.putIfAbsent(vecino, () => double.infinity);
      padres.putIfAbsent(vecino, () => null);
    }
  }

  final pq = PriorityQueue<MapEntry<String, double>>((a, b) {
    final int porDistancia = a.value.compareTo(b.value);
    return porDistancia != 0 ? porDistancia : a.key.compareTo(b.key);
  });

  distancias[idInicio] = 0;
  pq.add(MapEntry(idInicio, 0));

  while (pq.isNotEmpty) {
    final extraido = pq.removeFirst();
    final String actual = extraido.key;

    // Descarta entradas obsoletas: para cuando esta entrada llega a
    // extraerse, ya se pudo haber encontrado -y encolado- un camino más
    // corto hacia `actual`. Ignorarla es válido porque, con pesos no
    // negativos, la primera vez que un nodo se extrae de la cola su
    // distancia ya es la definitiva.
    if (extraido.value > distancias[actual]!) continue;

    if (actual == idDestino) break;
    final vecinos = conexiones[actual] ?? {};
    vecinos.forEach((vecino, peso) {
      final double nuevaDist = distancias[actual]! + peso;
      if (nuevaDist < distancias[vecino]!) {
        distancias[vecino] = nuevaDist;
        padres[vecino] = actual;
        pq.add(MapEntry(vecino, nuevaDist));
      }
    });
  }

  final double tiempoFinal = distancias[idDestino] ?? double.infinity;
  if (tiempoFinal == double.infinity) return Ruta.vacia;

  final ruta = <String>[];
  String? actual = idDestino;
  while (actual != null) {
    ruta.insert(0, actual);
    actual = padres[actual];
  }

  return Ruta(nodos: ruta, minutos: tiempoFinal);
}
