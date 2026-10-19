import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:mapa_cusur/data/campus_json_parser.dart';
import 'package:mapa_cusur/domain/interpolacion_nodos.dart';
import 'package:mapa_cusur/models/grafo_campus.dart';
import 'package:mapa_cusur/models/nodo.dart';
import 'package:mapa_cusur/utils/geodesia.dart';
import 'package:mapa_cusur/utils/indice_espacial.dart';

/// Búsqueda por fuerza bruta, usada como oráculo: recorre todos los nodos y
/// se queda con el de menor distancia Haversine. Es deliberadamente una
/// implementación independiente de [IndiceEspacial] (no la reutiliza) para
/// que la comparación sea una verificación real.
String? _masCercanoPorFuerzaBruta(
    Map<String, Nodo> nodos, double lat, double lng) {
  String? ganador;
  double distanciaMinima = double.infinity;
  for (final nodo in nodos.values) {
    final double distancia = distanciaHaversineMetros(lat, lng, nodo.lat, nodo.lng);
    if (distancia < distanciaMinima) {
      distanciaMinima = distancia;
      ganador = nodo.id;
    }
  }
  return ganador;
}

void main() {
  late GrafoCampus grafo;

  setUpAll(() {
    final Map<String, dynamic> data =
        json.decode(File('assets/campus_data.json').readAsStringSync());
    grafo = interpolarGrafo(parsearGrafoCampus(data));
  });

  group('IndiceEspacial.masCercano coincide con la fuerza bruta', () {
    test('sobre las coordenadas exactas de cada uno de los ~1000 nodos del '
        'grafo interpolado del campus real', () {
      final indice = IndiceEspacial(grafo.nodos);

      for (final nodo in grafo.nodos.values) {
        final esperado = _masCercanoPorFuerzaBruta(grafo.nodos, nodo.lat, nodo.lng);
        final obtenido = indice.masCercano(nodo.lat, nodo.lng);
        expect(obtenido, esperado,
            reason: 'consultando en la posición exacta de ${nodo.id}');
      }
    });

    test('sobre 2000 puntos aleatorios dentro y alrededor del campus', () {
      final indice = IndiceEspacial(grafo.nodos);
      final random = Random(42); // semilla fija: prueba reproducible

      final lats = grafo.nodos.values.map((n) => n.lat).toList();
      final lngs = grafo.nodos.values.map((n) => n.lng).toList();
      final double latMin = lats.reduce(min);
      final double latMax = lats.reduce(max);
      final double lngMin = lngs.reduce(min);
      final double lngMax = lngs.reduce(max);
      // Margen del 20% de la extensión del campus para incluir también
      // puntos ligeramente fuera del área cubierta por nodos.
      final double margenLat = (latMax - latMin) * 0.2;
      final double margenLng = (lngMax - lngMin) * 0.2;

      for (int i = 0; i < 2000; i++) {
        final double lat = latMin -
            margenLat +
            random.nextDouble() * (latMax - latMin + 2 * margenLat);
        final double lng = lngMin -
            margenLng +
            random.nextDouble() * (lngMax - lngMin + 2 * margenLng);

        final esperado = _masCercanoPorFuerzaBruta(grafo.nodos, lat, lng);
        final obtenido = indice.masCercano(lat, lng);
        expect(obtenido, esperado, reason: 'consultando en ($lat, $lng)');
      }
    });

    test('índice vacío devuelve null', () {
      final indice = IndiceEspacial(<String, Nodo>{});
      expect(indice.masCercano(19.7, -103.46), isNull);
    });
  });
}
