// Mide el tiempo de 1000 ejecuciones de Dijkstra sobre el grafo real del
// campus (interpolado, ~1008 nodos) con la cola de prioridad anterior
// (lista ordenada, O(n log n) por inserción) y con la actual (montículo
// binario, O(log n) por inserción), sobre exactamente los mismos 1000
// pares origen-destino para que la comparación sea justa.
//
// No falla por umbral -el rendimiento de la máquina que corre la prueba
// varía-, solo mide y reporta. La cifra que imprime es la que se cita en
// la tesis (Fase 2).
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:mapa_cusur/data/campus_json_parser.dart';
import 'package:mapa_cusur/data/diccionario_nombres.dart';
import 'package:mapa_cusur/domain/dijkstra.dart';
import 'package:mapa_cusur/domain/interpolacion_nodos.dart';
import 'package:mapa_cusur/models/grafo_campus.dart';
import 'package:mapa_cusur/models/ruta.dart';

/// Copia de la cola de prioridad que usaba la app antes de esta fase:
/// ordena la lista completa en cada `add`, extrae con `removeAt(0)`. Vive
/// solo aquí, para el benchmark A/B; no se usa en producción.
class _PriorityQueueListaOrdenada<T> {
  final List<T> _items = [];
  final int Function(T, T) compare;
  _PriorityQueueListaOrdenada(this.compare);
  bool get isNotEmpty => _items.isNotEmpty;
  void add(T item) {
    _items.add(item);
    _items.sort(compare);
  }

  T removeFirst() => _items.removeAt(0);
}

/// Copia del cuerpo de Dijkstra tal como era antes de la Fase 2 (sin
/// descarte de entradas obsoletas ni desempate determinista), pero usando
/// [_PriorityQueueListaOrdenada]. Solo para medir el "antes" del benchmark.
Ruta _calcularRutaConListaOrdenada(
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
  final pq = _PriorityQueueListaOrdenada<MapEntry<String, double>>(
      (a, b) => a.value.compareTo(b.value));

  for (final nodo in conexiones.keys) {
    distancias[nodo] = double.infinity;
    padres[nodo] = null;
  }
  distancias[idInicio] = 0;
  pq.add(MapEntry(idInicio, 0));

  while (pq.isNotEmpty) {
    final actual = pq.removeFirst().key;
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

void main() {
  test('Dijkstra: 1000 ejecuciones, cola de lista ordenada vs. montículo binario',
      () async {
    final Map<String, dynamic> data =
        json.decode(File('assets/campus_data.json').readAsStringSync());
    final grafo = interpolarGrafo(parsearGrafoCampus(data));

    final idsConNombre = diccionarioNombres.keys
        .where((id) => grafo.conexiones.containsKey(id))
        .toList();

    final random = Random(7); // semilla fija: benchmark reproducible
    final pares = List.generate(1000, (_) {
      String origen, destino;
      do {
        origen = idsConNombre[random.nextInt(idsConNombre.length)];
        destino = idsConNombre[random.nextInt(idsConNombre.length)];
      } while (origen == destino);
      return (origen, destino);
    });

    // Un par de corridas de calentamiento (JIT) fuera de la medición, para
    // que ninguna de las dos implementaciones cargue con el costo de
    // compilación en caliente.
    for (final (o, d) in pares.take(20)) {
      _calcularRutaConListaOrdenada(grafo, o, d);
    }

    final swAntes = Stopwatch()..start();
    for (final (o, d) in pares) {
      _calcularRutaConListaOrdenada(grafo, o, d);
    }
    swAntes.stop();

    final swDespues = Stopwatch()..start();
    for (final (o, d) in pares) {
      calcularRutaMasCorta(grafo, o, d);
    }
    swDespues.stop();

    final msAntes = swAntes.elapsedMicroseconds / 1000.0;
    final msDespues = swDespues.elapsedMicroseconds / 1000.0;

    // ignore: avoid_print
    print('--- Fase 2: rendimiento de Dijkstra (1000 ejecuciones, mismos '
        '1000 pares, grafo interpolado de ${grafo.nodos.length} nodos) ---');
    // ignore: avoid_print
    print('Antes  (lista ordenada, O(n log n) por inserción): '
        '${msAntes.toStringAsFixed(2)} ms total, '
        '${(msAntes / pares.length).toStringAsFixed(4)} ms/ejecución');
    // ignore: avoid_print
    print('Después (montículo binario, O(log n) por inserción): '
        '${msDespues.toStringAsFixed(2)} ms total, '
        '${(msDespues / pares.length).toStringAsFixed(4)} ms/ejecución');
    // ignore: avoid_print
    print('Mejora: ${(msAntes / msDespues).toStringAsFixed(2)}x');

    // No se falla por umbral: el propósito es medir y reportar, no
    // establecer un requisito de rendimiento.
    expect(msAntes, greaterThanOrEqualTo(0));
    expect(msDespues, greaterThanOrEqualTo(0));
  });
}
