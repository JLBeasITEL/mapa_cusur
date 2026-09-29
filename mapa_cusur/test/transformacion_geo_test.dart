import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:mapa_cusur/data/campus_json_parser.dart';
import 'package:mapa_cusur/domain/transformacion_geo.dart';
import 'package:mapa_cusur/models/nodo.dart';
import 'package:mapa_cusur/utils/geodesia.dart';

/// Un punto de control sintético cuya `lat`/`lng` corresponde exactamente a
/// un desplazamiento ([xLocal], [yLocal]) en metros respecto a
/// ([latRef], [lngRef]), y cuyo `pixelX`/`pixelY` es el que produce
/// [transformacionConocida] para ese mismo desplazamiento. Sirve para
/// verificar que `TransformacionAfin.ajustar` recupera una transformación
/// afín conocida de antemano.
Nodo _nodoSintetico(
  String id,
  double latRef,
  double lngRef,
  double xLocal,
  double yLocal, {
  ({double x, double y}) Function(double, double)? transformacion,
  double ruidoX = 0,
  double ruidoY = 0,
}) {
  final double metrosPorGradoLat = kRadioTierraMetros * pi / 180;
  final double metrosPorGradoLng =
      kRadioTierraMetros * cos(latRef * pi / 180) * pi / 180;
  final double lat = latRef + yLocal / metrosPorGradoLat;
  final double lng = lngRef + xLocal / metrosPorGradoLng;
  final pix = (transformacion ?? transformacionConocida)(xLocal, yLocal);
  return Nodo(
      id: id, lat: lat, lng: lng, pixelX: pix.x + ruidoX, pixelY: pix.y + ruidoY);
}

/// Una transformación afín arbitraria (no degenerada) usada como "verdad
/// conocida" en las pruebas de ajuste.
({double x, double y}) transformacionConocida(double xLocal, double yLocal) {
  return (x: 2.0 * xLocal - 0.5 * yLocal + 100.0, y: 0.3 * xLocal + 1.8 * yLocal + 50.0);
}

/// Réplica independiente -no reutiliza `TransformacionDosPuntos`- del
/// cálculo tal como vivía en `lib/main.dart` antes de la Fase 1
/// (`_moverCamara`, líneas ~374-403): oráculo para comprobar que el modo
/// "dos puntos" no cambió con la refactorización.
({double x, double y}) _oraculoDosPuntos({
  required double lat,
  required double lng,
  required Nodo controlA,
  required Nodo controlB,
}) {
  final double lat1 = controlA.lat, lng1 = controlA.lng;
  final double p1x = controlA.pixelX, p1y = controlA.pixelY;
  final double lat2 = controlB.lat, lng2 = controlB.lng;
  final double p2x = controlB.pixelX, p2y = controlB.pixelY;

  final double deltaPxX = (p2x - p1x).abs();
  final double deltaPxY = (p2y - p1y).abs();
  final bool latControlaX = deltaPxX > deltaPxY;

  double newPxX = 0, newPxY = 0;
  if (latControlaX) {
    final double pctLat = (lat - lat1) / (lat2 - lat1);
    final double pctLng = (lng - lng1) / (lng2 - lng1);
    newPxX = p1x + (pctLat * (p2x - p1x));
    newPxY = p1y + (pctLng * (p2y - p1y));
  } else {
    final double pctLng = (lng - lng1) / (lng2 - lng1);
    final double pctLat = (lat - lat1) / (lat2 - lat1);
    newPxX = p1x + (pctLng * (p2x - p1x));
    newPxY = p1y + (pctLat * (p2y - p1y));
  }
  return (x: newPxX, y: newPxY);
}

void main() {
  group('TransformacionAfin.ajustar', () {
    // Seis puntos no colineales alrededor de una referencia cualquiera.
    const double latRef = 19.7, lngRef = -103.46;
    final puntosBase = [
      (0.0, 0.0),
      (100.0, 0.0),
      (0.0, 100.0),
      (100.0, 100.0),
      (50.0, 150.0),
      (-80.0, 40.0),
    ];

    test('recupera una transformación afín conocida con error despreciable',
        () {
      final nodos = [
        for (int i = 0; i < puntosBase.length; i++)
          _nodoSintetico('P$i', latRef, lngRef, puntosBase[i].$1, puntosBase[i].$2),
      ];

      final afin = TransformacionAfin.ajustar(nodos);

      for (final nodo in nodos) {
        final predicho = afin.aPixeles(nodo.lat, nodo.lng);
        expect(predicho.x, closeTo(nodo.pixelX, 1e-6));
        expect(predicho.y, closeTo(nodo.pixelY, 1e-6));
      }
      expect(afin.rmse(), lessThan(1e-6));

      // También para un punto que no participó del ajuste.
      final nodoNuevo = _nodoSintetico('nuevo', latRef, lngRef, 30.0, -60.0);
      final predichoNuevo = afin.aPixeles(nodoNuevo.lat, nodoNuevo.lng);
      expect(predichoNuevo.x, closeTo(nodoNuevo.pixelX, 1e-6));
      expect(predichoNuevo.y, closeTo(nodoNuevo.pixelY, 1e-6));
    });

    test('el RMSE crece de forma esperada al inyectar ruido', () {
      final random = Random(123); // reproducible

      List<Nodo> generarConRuido(double amplitud) {
        return [
          for (int i = 0; i < puntosBase.length; i++)
            _nodoSintetico(
              'P$i',
              latRef,
              lngRef,
              puntosBase[i].$1,
              puntosBase[i].$2,
              ruidoX: (random.nextDouble() * 2 - 1) * amplitud,
              ruidoY: (random.nextDouble() * 2 - 1) * amplitud,
            ),
        ];
      }

      final sinRuido = TransformacionAfin.ajustar(generarConRuido(0.0));
      final ruidoPequeno = TransformacionAfin.ajustar(generarConRuido(2.0));
      final ruidoGrande = TransformacionAfin.ajustar(generarConRuido(10.0));

      expect(sinRuido.rmse(), lessThan(1e-6));
      expect(ruidoPequeno.rmse(), greaterThan(sinRuido.rmse()));
      expect(ruidoGrande.rmse(), greaterThan(ruidoPequeno.rmse()));
    });

    test('lanza una excepción clara con menos de 3 puntos', () {
      final nodos = [
        _nodoSintetico('P0', latRef, lngRef, 0, 0),
        _nodoSintetico('P1', latRef, lngRef, 100, 0),
      ];
      expect(() => TransformacionAfin.ajustar(nodos), throwsArgumentError);
    });

    test('lanza una excepción clara con puntos casi colineales', () {
      final nodos = [
        _nodoSintetico('P0', latRef, lngRef, 0, 0),
        _nodoSintetico('P1', latRef, lngRef, 50, 0),
        _nodoSintetico('P2', latRef, lngRef, 100, 1e-9),
      ];
      expect(() => TransformacionAfin.ajustar(nodos), throwsArgumentError);
    });
  });

  group('TransformacionDosPuntos', () {
    test('produce exactamente los mismos píxeles que el código original '
        '(oráculo independiente pre-Fase-1)', () {
      const controlA = Nodo(id: 'EntradaA', lat: 19.72384, lng: -103.46214, pixelX: 177, pixelY: 102);
      const controlB = Nodo(id: 'Edificio_M', lat: 19.726020262, lng: -103.4616538, pixelX: 265, pixelY: 585);

      final transformacion = TransformacionDosPuntos(controlA: controlA, controlB: controlB);

      final puntosDePrueba = [
        (19.7245, -103.4618),
        (19.7200, -103.4650),
        (19.7280, -103.4600),
        (19.72384, -103.46214), // coincide con controlA
        (19.726020262, -103.4616538), // coincide con controlB
      ];

      for (final (lat, lng) in puntosDePrueba) {
        final esperado = _oraculoDosPuntos(lat: lat, lng: lng, controlA: controlA, controlB: controlB);
        final obtenido = transformacion.aPixeles(lat, lng);
        expect(obtenido.x, esperado.x);
        expect(obtenido.y, esperado.y);
      }
    });
  });

  group('Verificación contra los datos reales del campus', () {
    test(
        'en modo afín, transformar las coordenadas geo de los 144 nodos '
        'produce píxeles cercanos a coordenadas_pix (RMSE ~12.5 px / ~7.3 m)',
        () {
      final Map<String, dynamic> data =
          json.decode(File('assets/campus_data.json').readAsStringSync());
      final grafo = parsearGrafoCampus(data);
      final idsControl = parsearPuntosControl(data);

      expect(idsControl, isNotEmpty,
          reason: 'assets/campus_data.json debe tener la sección '
              '"puntos_control"');

      final puntosControl = idsControl.map((id) => grafo.nodos[id]!).toList();
      final afin = TransformacionAfin.ajustar(puntosControl);
      final pxPorMetro = calcularEscalaPxPorMetro(grafo);

      final resultado =
          evaluarTransformacion(afin, grafo.nodos.values, pxPorMetro: pxPorMetro);

      // ignore: avoid_print
      print('Escala empírica: ${pxPorMetro.toStringAsFixed(3)} px/m');
      // ignore: avoid_print
      print('TransformacionAfin sobre los ${grafo.nodos.length} nodos base: '
          'RMSE = ${resultado.rmsePx.toStringAsFixed(2)} px '
          '(${resultado.rmseMetros.toStringAsFixed(2)} m)');

      // Criterio de aceptación del prompt: 7.3 ± 0.5 m equivalentes.
      expect(resultado.rmseMetros, closeTo(7.3, 0.5));
      // Y el mismo umbral expresado en píxeles, para que un factor de
      // conversión mal aplicado (px vs. m) se note de inmediato: a
      // ~1.71-1.8 px/m, 7.3 ± 0.5 m es aproximadamente 11.6-14.0 px.
      expect(resultado.rmsePx, inInclusiveRange(10.0, 15.0));
    });

    test('el modelo de dos puntos, evaluado igual, da un RMSE mayor que el '
        'afín (consistente con la tabla de cifras: ~18.2 m vs. ~7.3 m)', () {
      final Map<String, dynamic> data =
          json.decode(File('assets/campus_data.json').readAsStringSync());
      final grafo = parsearGrafoCampus(data);

      final dosPuntos = TransformacionDosPuntos(
        controlA: grafo.nodos['EntradaA']!,
        controlB: grafo.nodos['Edificio_M']!,
      );
      final pxPorMetro = calcularEscalaPxPorMetro(grafo);
      final resultado = evaluarTransformacion(dosPuntos, grafo.nodos.values,
          pxPorMetro: pxPorMetro);

      // ignore: avoid_print
      print('TransformacionDosPuntos sobre los ${grafo.nodos.length} nodos '
          'base: RMSE = ${resultado.rmsePx.toStringAsFixed(2)} px '
          '(${resultado.rmseMetros.toStringAsFixed(2)} m)');

      expect(resultado.rmseMetros, greaterThan(15.0));
    });
  });
}
