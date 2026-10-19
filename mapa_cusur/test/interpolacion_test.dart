import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:mapa_cusur/domain/interpolacion_nodos.dart';
import 'package:mapa_cusur/models/grafo_campus.dart';
import 'package:mapa_cusur/models/nodo.dart';
import 'package:mapa_cusur/utils/geodesia.dart';

/// Nodo sintético a exactamente [metros] al norte de [base] (mismo
/// meridiano), calculado con el mismo radio terrestre que usa
/// `distanciaHaversineMetros`, para poder predecir de antemano cuántos
/// nodos fantasma generará una arista.
Nodo _nodoADistancia(String id, Nodo base, double metros) {
  final double dLatGrados = (metros / kRadioTierraMetros) * 180 / pi;
  return Nodo(
    id: id,
    lat: base.lat + dLatGrados,
    lng: base.lng,
    pixelX: base.pixelX + metros,
    pixelY: base.pixelY,
  );
}

void main() {
  const origen = Nodo(id: 'A', lat: 19.7, lng: -103.46, pixelX: 0, pixelY: 0);

  group('interpolarGrafo', () {
    test('una arista de 24 m se subdivide en el número esperado de tramos', () {
      final destino = _nodoADistancia('B', origen, 24.0);
      final grafoBase = GrafoCampus(
        nodos: {'A': origen, 'B': destino},
        conexiones: {
          'A': {'B': 6.0},
          'B': {'A': 6.0},
        },
      );

      final resultado = interpolarGrafo(grafoBase);

      // floor(24/8) = 3 nodos fantasma -> 4 tramos.
      final idsFantasma =
          resultado.nodos.keys.where((id) => id.contains('_inter_')).toList();
      expect(idsFantasma.length, 3);
      expect(resultado.nodos.length, grafoBase.nodos.length + 3);

      // La arista directa original ya no existe: la reemplazó la cadena.
      expect(resultado.conexiones['A']!.containsKey('B'), isFalse);
      expect(resultado.conexiones['B']!.containsKey('A'), isFalse);
    });

    test('una arista de 5 m no se toca', () {
      final destino = _nodoADistancia('B', origen, 5.0);
      final grafoBase = GrafoCampus(
        nodos: {'A': origen, 'B': destino},
        conexiones: {
          'A': {'B': 1.5},
          'B': {'A': 1.5},
        },
      );

      final resultado = interpolarGrafo(grafoBase);

      expect(resultado.nodos.length, 2);
      expect(resultado.conexiones['A']!['B'], 1.5);
      expect(resultado.conexiones['B']!['A'], 1.5);
    });

    test('la suma de los pesos de los sub-tramos es igual al peso original', () {
      final destino = _nodoADistancia('B', origen, 37.0); // floor(37/8)=4 -> 5 tramos
      const pesoOriginal = 9.25;
      final grafoBase = GrafoCampus(
        nodos: {'A': origen, 'B': destino},
        conexiones: {
          'A': {'B': pesoOriginal},
          'B': {'A': pesoOriginal},
        },
      );

      final resultado = interpolarGrafo(grafoBase);

      // Recorre la cadena A -> ... -> B sumando el peso de cada tramo.
      double sumaPesos = 0;
      String actual = 'A';
      String? anterior;
      while (actual != 'B') {
        final vecinos = resultado.conexiones[actual]!;
        final siguiente = vecinos.entries.firstWhere((e) => e.key != anterior);
        sumaPesos += siguiente.value;
        anterior = actual;
        actual = siguiente.key;
      }

      expect(sumaPesos, closeTo(pesoOriginal, 1e-9));
    });
  });
}
