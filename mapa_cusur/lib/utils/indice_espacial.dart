import '../models/nodo.dart';
import 'geodesia.dart';

/// Índice espacial simple (rejilla de celdas uniforme en grados) para
/// encontrar el nodo más cercano a una coordenada geográfica sin recorrer
/// por fuerza bruta los ~1000 nodos del grafo interpolado en cada consulta
/// -antes, cada actualización de GPS (que llega cada metro) hacía
/// exactamente ese recorrido completo.
///
/// Construir el índice es O(n). Cada consulta [masCercano] examina primero
/// solo la celda de la coordenada consultada y sus vecinas, expandiendo el
/// anillo de búsqueda en espiral hasta tener la certeza matemática (una
/// cota inferior conservadora de distancia) de que ningún nodo fuera de las
/// celdas ya examinadas puede estar más cerca que el mejor candidato
/// encontrado hasta ese momento. El resultado es exactamente el mismo que
/// el de una búsqueda por fuerza bruta sobre todos los nodos -se verifica
/// exhaustivamente en test/indice_espacial_test.dart contra el grafo real
/// del campus- solo que más rápida.
class IndiceEspacial {
  final Map<String, Nodo> _nodos;
  final double _tamanoCeldaGrados;
  final Map<(int, int), List<String>> _celdas = {};
  final double _metrosPorGradoMinimo;

  /// Límite de anillos a expandir antes de rendirse (evita un bucle
  /// infinito ante coordenadas patológicas; nunca se alcanza con datos
  /// reales del campus, cuya extensión cabe en unas pocas decenas de
  /// celdas con el tamaño de celda por defecto).
  static const int _radioMaximoSeguridad = 1000;

  IndiceEspacial(Map<String, Nodo> nodos, {double tamanoCeldaGrados = 0.00005})
      : _nodos = nodos,
        _tamanoCeldaGrados = tamanoCeldaGrados,
        _metrosPorGradoMinimo =
            _calcularMetrosPorGradoMinimo(nodos, tamanoCeldaGrados) {
    for (final nodo in nodos.values) {
      _celdas
          .putIfAbsent(_claveCelda(nodo.lat, nodo.lng), () => [])
          .add(nodo.id);
    }
  }

  static double _calcularMetrosPorGradoMinimo(
      Map<String, Nodo> nodos, double tamanoCeldaGrados) {
    if (nodos.isEmpty) return 100000.0;
    final Nodo referencia = nodos.values.first;
    final double metrosPorGradoLat = distanciaHaversineMetros(
            referencia.lat, referencia.lng,
            referencia.lat + tamanoCeldaGrados, referencia.lng) /
        tamanoCeldaGrados;
    final double metrosPorGradoLng = distanciaHaversineMetros(
            referencia.lat, referencia.lng,
            referencia.lat, referencia.lng + tamanoCeldaGrados) /
        tamanoCeldaGrados;
    final double menor =
        metrosPorGradoLat < metrosPorGradoLng ? metrosPorGradoLat : metrosPorGradoLng;
    // Margen de seguridad del 10%: la conversión grados->metros no es
    // perfectamente uniforme en toda la extensión del campus, así que nos
    // quedamos deliberadamente por debajo para que la cota siga siendo
    // conservadora (nunca corta la búsqueda antes de tiempo).
    return menor * 0.9;
  }

  (int, int) _claveCelda(double lat, double lng) => (
        (lat / _tamanoCeldaGrados).floor(),
        (lng / _tamanoCeldaGrados).floor(),
      );

  /// Devuelve el ID del nodo más cercano a ([lat], [lng]), o `null` si el
  /// índice está vacío.
  String? masCercano(double lat, double lng) {
    if (_nodos.isEmpty) return null;

    final (int, int) centro = _claveCelda(lat, lng);
    String? ganador;
    double distanciaMinima = double.infinity;
    int radio = 0;

    while (true) {
      for (int dx = -radio; dx <= radio; dx++) {
        for (int dy = -radio; dy <= radio; dy++) {
          // En radios > 0 basta con el anillo exterior: el interior ya se
          // examinó en iteraciones anteriores.
          if (radio > 0 && dx.abs() != radio && dy.abs() != radio) continue;
          final ids = _celdas[(centro.$1 + dx, centro.$2 + dy)];
          if (ids == null) continue;
          for (final id in ids) {
            final Nodo nodo = _nodos[id]!;
            final double distancia =
                distanciaHaversineMetros(lat, lng, nodo.lat, nodo.lng);
            if (distancia < distanciaMinima) {
              distanciaMinima = distancia;
              ganador = id;
            }
          }
        }
      }

      // Cota inferior conservadora de distancia a cualquier nodo fuera de
      // las celdas ya examinadas (bloque de radio `radio` en torno al
      // centro). Si ya supera al mejor candidato encontrado, ningún nodo
      // más lejano puede mejorarlo: se puede parar.
      final double cotaInferiorFuera =
          radio * _tamanoCeldaGrados * _metrosPorGradoMinimo;
      if (ganador != null && cotaInferiorFuera >= distanciaMinima) break;

      radio++;
      if (radio > _radioMaximoSeguridad) break;
    }

    return ganador;
  }
}
