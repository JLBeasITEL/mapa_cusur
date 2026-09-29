import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:mapa_cusur/domain/ubicacion_en_ruta.dart';
import 'package:mapa_cusur/models/grafo_campus.dart';
import 'package:mapa_cusur/models/nodo.dart';
import 'package:mapa_cusur/utils/geodesia.dart';

/// Nodo sintético desplazado ([metrosEste], [metrosNorte]) respecto a
/// [base], calculado con las mismas fórmulas que `aPlanoLocalMetros` (para
/// que las pruebas puedan predecir con exactitud dónde cae la proyección).
Nodo _nodoDesplazado(
  String id,
  Nodo base, {
  double metrosEste = 0,
  double metrosNorte = 0,
}) {
  final double metrosPorGradoLat = kRadioTierraMetros * pi / 180;
  final double metrosPorGradoLng =
      kRadioTierraMetros * cos(base.lat * pi / 180) * pi / 180;
  return Nodo(
    id: id,
    lat: base.lat + metrosNorte / metrosPorGradoLat,
    lng: base.lng + metrosEste / metrosPorGradoLng,
    pixelX: base.pixelX,
    pixelY: base.pixelY,
  );
}

GrafoCampus _grafoDeAristas(Map<String, Nodo> nodos, List<(String, String)> aristas) {
  final conexiones = <String, Map<String, double>>{};
  for (final (a, b) in aristas) {
    (conexiones[a] ??= {})[b] = 1.0;
    (conexiones[b] ??= {})[a] = 1.0;
  }
  return GrafoCampus(nodos: nodos, conexiones: conexiones);
}

void main() {
  const origen = Nodo(id: 'ref', lat: 19.7, lng: -103.46, pixelX: 0, pixelY: 0);

  group('proyectarSobreArista', () {
    test('proyección interior: cae dentro del segmento (0 < t < 1)', () {
      final a = _nodoDesplazado('A', origen);
      final b = _nodoDesplazado('B', origen, metrosEste: 100);
      final grafo = _grafoDeAristas({'A': a, 'B': b}, [('A', 'B')]);

      // 10 m al norte del punto medio del segmento A-B.
      final p = _nodoDesplazado('_', origen, metrosEste: 50, metrosNorte: 10);

      final resultado = proyectarSobreArista(grafo, p.lat, p.lng)!;

      expect(resultado.t, closeTo(0.5, 1e-6));
      expect(resultado.distanciaAlCaminoMetros, closeTo(10.0, 1e-6));
      expect({resultado.aristaA, resultado.aristaB}, {'A', 'B'});
    });

    test('proyección más allá de A: t se recorta a 0', () {
      final a = _nodoDesplazado('A', origen);
      final b = _nodoDesplazado('B', origen, metrosEste: 100);
      final grafo = _grafoDeAristas({'A': a, 'B': b}, [('A', 'B')]);

      // 30 m "antes" de A y 5 m al norte.
      final p = _nodoDesplazado('_', origen, metrosEste: -30, metrosNorte: 5);

      final resultado = proyectarSobreArista(grafo, p.lat, p.lng)!;

      expect(resultado.t, 0.0);
      expect(resultado.distanciaAlCaminoMetros, closeTo(sqrt(30 * 30 + 5 * 5), 1e-6));
      expect(resultado.nodoMasCercanoEnLaArista, 'A');
    });

    test('proyección más allá de B: t se recorta a 1', () {
      final a = _nodoDesplazado('A', origen);
      final b = _nodoDesplazado('B', origen, metrosEste: 100);
      final grafo = _grafoDeAristas({'A': a, 'B': b}, [('A', 'B')]);

      // 30 m "después" de B y 5 m al norte.
      final p = _nodoDesplazado('_', origen, metrosEste: 130, metrosNorte: 5);

      final resultado = proyectarSobreArista(grafo, p.lat, p.lng)!;

      expect(resultado.t, 1.0);
      expect(resultado.distanciaAlCaminoMetros, closeTo(sqrt(30 * 30 + 5 * 5), 1e-6));
      expect(resultado.nodoMasCercanoEnLaArista, 'B');
    });

    test('punto equidistante entre dos aristas: elige una válida con la '
        'distancia correcta', () {
      // Dos segmentos horizontales paralelos, a 50 m al norte y 50 m al sur
      // de un punto de consulta sobre el eje este-oeste que pasa por ambos.
      final c = _nodoDesplazado('C', origen, metrosNorte: 50);
      final d = _nodoDesplazado('D', origen, metrosEste: 100, metrosNorte: 50);
      final e = _nodoDesplazado('E', origen, metrosNorte: -50);
      final f = _nodoDesplazado('F', origen, metrosEste: 100, metrosNorte: -50);
      final grafo = _grafoDeAristas(
          {'C': c, 'D': d, 'E': e, 'F': f}, [('C', 'D'), ('E', 'F')]);

      final p = _nodoDesplazado('_', origen, metrosEste: 50);

      final resultado = proyectarSobreArista(grafo, p.lat, p.lng)!;

      expect(resultado.distanciaAlCaminoMetros, closeTo(50.0, 1e-6));
      final arista = {resultado.aristaA, resultado.aristaB};
      final bool esCD = arista.contains('C') && arista.contains('D');
      final bool esEF = arista.contains('E') && arista.contains('F');
      expect(esCD || esEF, isTrue,
          reason: 'debe elegir una de las dos aristas igualmente cercanas, '
              'no otra cosa (arista devuelta: $arista)');
    });

    test('grafo sin aristas devuelve null', () {
      final grafo = GrafoCampus(nodos: {}, conexiones: {});
      expect(proyectarSobreArista(grafo, 19.7, -103.46), isNull);
    });
  });

  group('lecturaGpsEsAceptable', () {
    test('acepta lecturas con accuracy <= 15 m (umbral por defecto)', () {
      expect(lecturaGpsEsAceptable(5.0), isTrue);
      expect(lecturaGpsEsAceptable(15.0), isTrue);
    });

    test('descarta lecturas con accuracy > 15 m (umbral por defecto)', () {
      expect(lecturaGpsEsAceptable(15.1), isFalse);
      expect(lecturaGpsEsAceptable(40.0), isFalse);
    });

    test('el umbral es configurable', () {
      expect(lecturaGpsEsAceptable(20.0, precisionMaximaMetros: 25.0), isTrue);
      expect(lecturaGpsEsAceptable(20.0, precisionMaximaMetros: 10.0), isFalse);
    });
  });

  group('FiltroMediaMovil', () {
    test('promedia las últimas N lecturas aceptadas', () {
      final filtro = FiltroMediaMovil(n: 3);

      expect(filtro.filtrar(10.0, 20.0), (lat: 10.0, lng: 20.0));
      expect(filtro.filtrar(20.0, 20.0), (lat: 15.0, lng: 20.0));
      final tercera = filtro.filtrar(30.0, 20.0);
      expect(tercera.lat, closeTo(20.0, 1e-9));

      // La cuarta lectura empuja fuera de la ventana a la primera (10.0):
      // promedio de (20, 30, 40) = 30.
      final cuarta = filtro.filtrar(40.0, 20.0);
      expect(cuarta.lat, closeTo(30.0, 1e-9));
    });

    test('reiniciar() olvida el historial', () {
      final filtro = FiltroMediaMovil(n: 3);
      filtro.filtrar(100.0, 100.0);
      filtro.filtrar(100.0, 100.0);
      filtro.reiniciar();

      final resultado = filtro.filtrar(5.0, 5.0);
      expect(resultado, (lat: 5.0, lng: 5.0));
    });
  });

  group('debeRecalcularRuta', () {
    UbicacionEnGrafo ubicacion({required String a, required String b, required double t}) {
      return UbicacionEnGrafo(
          aristaA: a, aristaB: b, t: t, distanciaAlCaminoMetros: 0, lat: 19.7, lng: -103.46);
    }

    test('sin ubicación previa: siempre recalcula', () {
      expect(
          debeRecalcularRuta(
              ultimaUbicacionUsada: null,
              ubicacionActual: ubicacion(a: 'A', b: 'B', t: 0.5)),
          isTrue);
    });

    test('cambió de arista: recalcula sin importar la distancia', () {
      expect(
          debeRecalcularRuta(
              ultimaUbicacionUsada: ubicacion(a: 'A', b: 'B', t: 0.5),
              ubicacionActual: ubicacion(a: 'C', b: 'D', t: 0.5)),
          isTrue);
    });

    test('misma arista, movimiento menor al umbral: no recalcula', () {
      final a = _nodoDesplazado('A', origen);
      final anterior = UbicacionEnGrafo(
          aristaA: 'A', aristaB: 'B', t: 0.5, distanciaAlCaminoMetros: 0,
          lat: a.lat, lng: a.lng);

      // Construimos un punto a 10 m de `anterior` en la misma arista.
      final cerca = _nodoDesplazado('cerca', origen, metrosEste: 10);
      final actualCerca = UbicacionEnGrafo(
          aristaA: 'A', aristaB: 'B', t: 0.1, distanciaAlCaminoMetros: 0,
          lat: cerca.lat, lng: cerca.lng);

      expect(
          debeRecalcularRuta(ultimaUbicacionUsada: anterior, ubicacionActual: actualCerca),
          isFalse);
    });

    test('misma arista, movimiento mayor al umbral: recalcula', () {
      final a = _nodoDesplazado('A', origen);
      final anterior = UbicacionEnGrafo(
          aristaA: 'A', aristaB: 'B', t: 0.0, distanciaAlCaminoMetros: 0,
          lat: a.lat, lng: a.lng);

      final lejos = _nodoDesplazado('lejos', origen, metrosEste: 25);
      final actualLejos = UbicacionEnGrafo(
          aristaA: 'A', aristaB: 'B', t: 0.25, distanciaAlCaminoMetros: 0,
          lat: lejos.lat, lng: lejos.lng);

      expect(
          debeRecalcularRuta(ultimaUbicacionUsada: anterior, ubicacionActual: actualLejos),
          isTrue);
    });
  });
}
