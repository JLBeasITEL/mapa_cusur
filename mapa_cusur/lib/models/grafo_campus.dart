import 'arista.dart';
import 'nodo.dart';

/// El grafo del campus: nodos con coordenadas y una lista de adyacencia de
/// conexiones dirigidas con peso en minutos.
class GrafoCampus {
  final Map<String, Nodo> nodos;
  final Map<String, Map<String, double>> conexiones;

  const GrafoCampus({required this.nodos, required this.conexiones});

  /// Todas las aristas dirigidas del grafo, aplanadas desde [conexiones].
  /// Usado por domain/validador_grafo.dart (Fase 6) para recorrer el grafo
  /// arista por arista.
  Iterable<Arista> get aristas sync* {
    for (final origen in conexiones.keys) {
      for (final entry in conexiones[origen]!.entries) {
        yield Arista(
          origen: origen,
          destino: entry.key,
          pesoMinutos: entry.value,
        );
      }
    }
  }
}
