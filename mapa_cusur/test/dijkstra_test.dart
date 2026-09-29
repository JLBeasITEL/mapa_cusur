import 'package:flutter_test/flutter_test.dart';
import 'package:mapa_cusur/domain/dijkstra.dart';
import 'package:mapa_cusur/models/grafo_campus.dart';
import 'package:mapa_cusur/models/nodo.dart';

GrafoCampus _grafo(Map<String, Map<String, double>> conexiones) {
  final nodos = {
    for (final id in conexiones.keys)
      id: Nodo(id: id, lat: 0, lng: 0, pixelX: 0, pixelY: 0),
  };
  return GrafoCampus(nodos: nodos, conexiones: conexiones);
}

void main() {
  group('calcularRutaMasCorta', () {
    test('grafo de 3 nodos en línea', () {
      final grafo = _grafo({
        'A': {'B': 1.0},
        'B': {'A': 1.0, 'C': 2.0},
        'C': {'B': 2.0},
      });

      final resultado = calcularRutaMasCorta(grafo, 'A', 'C');

      expect(resultado.nodos, ['A', 'B', 'C']);
      expect(resultado.minutos, 3.0);
    });

    test('grafo desconectado: no hay ruta entre las dos componentes', () {
      final grafo = _grafo({
        'A': {'B': 1.0},
        'B': {'A': 1.0},
        'X': {'Y': 1.0},
        'Y': {'X': 1.0},
      });

      final resultado = calcularRutaMasCorta(grafo, 'A', 'X');

      expect(resultado.esVacia, isTrue);
      expect(resultado.minutos, 0.0);
    });

    test('origen == destino: ruta de un solo nodo y 0 minutos', () {
      final grafo = _grafo({
        'A': {'B': 1.0},
        'B': {'A': 1.0},
      });

      final resultado = calcularRutaMasCorta(grafo, 'A', 'A');

      expect(resultado.nodos, ['A']);
      expect(resultado.minutos, 0.0);
    });

    test(
        'el camino con menos saltos no siempre es el más corto en minutos',
        () {
      // A-B-D es 1 salto menos que A-C-E-D, pero pesa más:
      // A->B->D = 10 + 10 = 20 min
      // A->C->E->D = 1 + 1 + 1 = 3 min
      final grafo = _grafo({
        'A': {'B': 10.0, 'C': 1.0},
        'B': {'A': 10.0, 'D': 10.0},
        'C': {'A': 1.0, 'E': 1.0},
        'E': {'C': 1.0, 'D': 1.0},
        'D': {'B': 10.0, 'E': 1.0},
      });

      final resultado = calcularRutaMasCorta(grafo, 'A', 'D');

      expect(resultado.nodos, ['A', 'C', 'E', 'D']);
      expect(resultado.minutos, 3.0);
    });

    test('ID inexistente devuelve ruta vacía', () {
      final grafo = _grafo({
        'A': {'B': 1.0},
        'B': {'A': 1.0},
      });

      expect(calcularRutaMasCorta(grafo, 'A', 'Z').esVacia, isTrue);
      expect(calcularRutaMasCorta(grafo, 'Z', 'A').esVacia, isTrue);
    });

    test(
        'con dos caminos igualmente óptimos, el desempate es determinista '
        'por ID de nodo', () {
      // A-X-D y A-Z-D cuestan lo mismo (5.0). El desempate debe preferir
      // siempre X (X < Z), sin importar el orden en que las aristas
      // aparezcan en el mapa de conexiones.
      final grafo = _grafo({
        'A': {'Z': 2.0, 'X': 2.0}, // Z insertada antes que X a propósito
        'X': {'A': 2.0, 'D': 3.0},
        'Z': {'A': 2.0, 'D': 3.0},
        'D': {'X': 3.0, 'Z': 3.0},
      });

      final resultado = calcularRutaMasCorta(grafo, 'A', 'D');

      expect(resultado.nodos, ['A', 'X', 'D']);
      expect(resultado.minutos, 5.0);

      // Repetible: correrlo varias veces siempre da el mismo resultado.
      for (int i = 0; i < 5; i++) {
        expect(calcularRutaMasCorta(grafo, 'A', 'D').nodos, ['A', 'X', 'D']);
      }
    });
  });
}
