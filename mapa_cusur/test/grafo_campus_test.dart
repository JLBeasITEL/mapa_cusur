import 'package:flutter_test/flutter_test.dart';
import 'package:mapa_cusur/models/grafo_campus.dart';
import 'package:mapa_cusur/models/nodo.dart';

Nodo _nodo(String id) =>
    Nodo(id: id, lat: 0, lng: 0, pixelX: 0, pixelY: 0);

void main() {
  final grafo = GrafoCampus(
    nodos: {for (final id in ['A', 'B', 'C']) id: _nodo(id)},
    conexiones: {
      'A': {'B': 1.0, 'C': 2.0},
      'B': {'A': 1.0},
      'C': {'A': 2.0},
    },
  );

  test('sinNodos quita los nodos y todas sus aristas', () {
    final sinC = grafo.sinNodos(['C']);

    expect(sinC.nodos.keys, ['A', 'B']);
    expect(sinC.conexiones, {
      'A': {'B': 1.0},
      'B': {'A': 1.0},
    });
  });

  test('sinNodos sin ids devuelve el mismo grafo', () {
    expect(identical(grafo.sinNodos(const []), grafo), isTrue);
  });
}
