import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mapa_cusur/data/mapa_vectorial_parser.dart';
import 'package:mapa_cusur/domain/proyeccion_local.dart';
import 'package:mapa_cusur/models/mapa_vectorial.dart';
import 'package:mapa_cusur/ui/painters/mapa_vectorial_painter.dart';

void main() {
  final MapaVectorial mapa = parsearMapaVectorial(
      json.decode(File('assets/campus_vector.json').readAsStringSync()));
  final Size tamano = ProyeccionLocal(mapa.meta).tamanoLienzo;

  group('GeometriaMapaVectorial', () {
    final geometria = GeometriaMapaVectorial(mapa);

    test('separa las zonas techadas de los edificios y techos', () {
      expect(geometria.techadas, hasLength(1)); // Cancha múltiple
      expect(geometria.edificios, hasLength(35));
      expect(geometria.edificios.where((e) => e.esTecho), hasLength(1));
      expect(geometria.canchas, hasLength(7));
    });

    test('agrupa las vialidades por ancho', () {
      expect(geometria.vialidadesPorAncho.keys, unorderedEquals([9.0, 3.2]));
      expect(geometria.callesPorAncho.keys, [9.0]);
      expect(geometria.serviciosPorAncho.keys, [3.2]);
    });

    test('los edificios rellenan con evenOdd (para los huecos)', () {
      for (final e in geometria.edificios) {
        expect(e.contorno.fillType, PathFillType.evenOdd);
      }
    });

    test('la sombra es el contorno desplazado 1.4 m', () {
      // Los límites de un Path son de 32 bits: se compara con tolerancia.
      for (final e in geometria.edificios) {
        final desfase =
            e.sombra.getBounds().topLeft - e.contorno.getBounds().topLeft;
        expect(desfase.dx, closeTo(1.4, 1e-4));
        expect(desfase.dy, closeTo(1.4, 1e-4));
      }
    });

    test('el borde de la zona techada es discontinuo', () {
      final borde = geometria.techadas.single.borde;
      final relleno = geometria.techadas.single.relleno;

      // 3 m de trazo por cada 5 m de perímetro.
      final perimetro =
          relleno.computeMetrics().fold(0.0, (s, m) => s + m.length);
      final trazado = borde.computeMetrics().fold(0.0, (s, m) => s + m.length);
      expect(trazado / perimetro, closeTo(0.6, 0.05));
    });
  });

  group('MapaVectorialPainter', () {
    test('pinta el mapa real sin excepciones', () {
      final painter = MapaVectorialPainter(
          geometria: GeometriaMapaVectorial(mapa), escala: kEscalaVectorial);
      final recorder = ui.PictureRecorder();

      painter.paint(Canvas(recorder), tamano);

      final picture = recorder.endRecording();
      expect(picture.approximateBytesUsed, greaterThan(0));
      picture.dispose();
    });

    test('solo se repinta si cambian los datos', () {
      final geometria = GeometriaMapaVectorial(mapa);
      final painter =
          MapaVectorialPainter(geometria: geometria, escala: kEscalaVectorial);

      expect(
          painter.shouldRepaint(MapaVectorialPainter(
              geometria: geometria, escala: kEscalaVectorial)),
          isFalse);
      expect(
          painter.shouldRepaint(MapaVectorialPainter(
              geometria: GeometriaMapaVectorial(mapa),
              escala: kEscalaVectorial)),
          isTrue);
    });
  });
}
