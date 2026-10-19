import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mapa_cusur/data/campus_json_parser.dart';
import 'package:mapa_cusur/data/mapa_vectorial_parser.dart';
import 'package:mapa_cusur/domain/proyeccion_local.dart';
import 'package:mapa_cusur/models/grafo_campus.dart';
import 'package:mapa_cusur/models/mapa_vectorial.dart';

Map<String, dynamic> _leer(String ruta) =>
    json.decode(File(ruta).readAsStringSync()) as Map<String, dynamic>;

void main() {
  final MapaVectorial mapa =
      parsearMapaVectorial(_leer('assets/campus_vector.json'));
  final GrafoCampus grafo =
      parsearGrafoCampus(_leer('assets/campus_data.json'));
  final proyeccion = ProyeccionLocal(mapa.meta);

  group('geoALocal', () {
    test('el origen de meta queda en (0, 0)', () {
      final local =
          proyeccion.geoALocal(mapa.meta.origenLat, mapa.meta.origenLng);

      expect(local.x, 0.0);
      expect(local.y, 0.0);
    });

    test('EntradaA (19.72384, −103.46214) → (−67.1, 150.4) m', () {
      final local = proyeccion.geoALocal(19.72384, -103.46214);

      expect(local.x, closeTo(-67.1, 0.1));
      expect(local.y, closeTo(150.4, 0.1));
    });

    // entradas[].pos y estacionamientos[].pos se generaron con esta misma
    // fórmula a partir de campus_data.json: si no coinciden, la proyección
    // de la app y la del JSON no son la misma.
    for (final (seccion, puntos) in [
      ('entradas', mapa.entradas),
      ('estacionamientos', mapa.estacionamientos),
    ]) {
      test('las posiciones de $seccion coinciden con sus nodos del grafo', () {
        expect(puntos, isNotEmpty);
        for (final punto in puntos) {
          final nodo = grafo.nodos[punto.nodo];
          expect(nodo, isNotNull,
              reason: '${punto.nodo} no existe en campus_data.json');

          final local = proyeccion.geoALocal(nodo!.lat, nodo.lng);

          expect(local.x, closeTo(punto.pos.dx, 0.1), reason: punto.nodo);
          expect(local.y, closeTo(punto.pos.dy, 0.1), reason: punto.nodo);
        }
      });
    }
  });

  group('lienzo', () {
    test('la esquina (min_x, min_y) de los límites es el origen del lienzo',
        () {
      final esquina =
          proyeccion.localALienzo(mapa.meta.minX, mapa.meta.minY);

      expect(esquina.dx, 0.0);
      expect(esquina.dy, 0.0);
    });

    test('el tamaño del lienzo cubre los límites a kEscalaVectorial', () {
      final tamano = proyeccion.tamanoLienzo;
      final meta = mapa.meta;

      expect(tamano.width, closeTo((meta.maxX - meta.minX) * 11.0, 1e-9));
      expect(tamano.height, closeTo((meta.maxY - meta.minY) * 11.0, 1e-9));
      expect(proyeccion.localALienzo(meta.maxX, meta.maxY).dx,
          closeTo(tamano.width, 1e-9));
      expect(proyeccion.localALienzo(meta.maxX, meta.maxY).dy,
          closeTo(tamano.height, 1e-9));
    });

    test('ida y vuelta local → lienzo → local con error menor a 1e-9', () {
      for (final nodo in grafo.nodos.values) {
        final local = proyeccion.geoALocal(nodo.lat, nodo.lng);
        final lienzo = proyeccion.localALienzo(local.x, local.y);
        final deVuelta = proyeccion.lienzoALocal(lienzo);

        expect((deVuelta.x - local.x).abs(), lessThan(1e-9), reason: nodo.id);
        expect((deVuelta.y - local.y).abs(), lessThan(1e-9), reason: nodo.id);
      }
    });

    test('ida y vuelta lienzo → local → lienzo con error menor a 1e-9', () {
      final tamano = proyeccion.tamanoLienzo;
      for (var i = 0; i <= 10; i++) {
        for (var j = 0; j <= 10; j++) {
          final lienzo = Offset(tamano.width * i / 10, tamano.height * j / 10);
          final local = proyeccion.lienzoALocal(lienzo);
          final deVuelta = proyeccion.localALienzo(local.x, local.y);

          expect((deVuelta.dx - lienzo.dx).abs(), lessThan(1e-9));
          expect((deVuelta.dy - lienzo.dy).abs(), lessThan(1e-9));
        }
      }
    });

    test('geoALienzo es la composición de geoALocal y localALienzo', () {
      final nodo = grafo.nodos['Edificio_M']!;
      final local = proyeccion.geoALocal(nodo.lat, nodo.lng);

      expect(proyeccion.geoALienzo(nodo.lat, nodo.lng),
          proyeccion.localALienzo(local.x, local.y));
    });
  });
}
