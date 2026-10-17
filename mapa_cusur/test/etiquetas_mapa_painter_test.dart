import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mapa_cusur/data/mapa_vectorial_parser.dart';
import 'package:mapa_cusur/domain/proyeccion_local.dart';
import 'package:mapa_cusur/models/mapa_vectorial.dart';
import 'package:mapa_cusur/ui/painters/etiquetas_mapa_painter.dart';

void main() {
  final MapaVectorial mapa = parsearMapaVectorial(
      json.decode(File('assets/campus_vector.json').readAsStringSync()));
  final proyeccion = ProyeccionLocal(mapa.meta);

  test('kIconosMapa tiene todos los íconos que usa campus_vector.json', () {
    final usados = {
      for (final e in mapa.edificios)
        if (e.icono != null) e.icono!,
      for (final c in mapa.canchasFutbol)
        if (c.icono != null) c.icono!,
      for (final c in mapa.canchas)
        if (c.icono != null) c.icono!,
      for (final l in mapa.lugares) l.icono,
      'door_front',
      'directions_car',
    };

    expect(kIconosMapa.keys, containsAll(usados));
  });

  test('los íconos son de la variante rounded de Material', () {
    for (final icono in kIconosMapa.values) {
      expect(icono.fontFamily, 'MaterialIcons');
    }
    expect(kIconosMapa['door_front'], Icons.door_front_door_rounded);
  });

  group('EtiquetasMapaVectorial: visibilidad por zoom', () {
    final etiquetas = EtiquetasMapaVectorial(mapa);
    tearDownAll(etiquetas.dispose);

    test('con zoom 1 se ven letras, entradas y calles, pero no nombres', () {
      final visibles = etiquetas.textosCon(1.0);

      expect(visibles, containsAll(['Z', 'C', 'M']));
      expect(visibles,
          containsAll(['Entrada Sur', 'Entrada Principal', 'Entrada Este']));
      expect(visibles, contains('Prolongación Colón'));
      expect(visibles, isNot(contains('Cafetería Principal')));
      expect(visibles, isNot(contains('Estacionamiento 1')));
      expect(visibles, isNot(contains('Coordinación de tecnologías')));
      expect(visibles, isNot(contains('Cancha de fútbol')));
    });

    test('desde zoom 1.8 se ven también los textos largos', () {
      final visibles = etiquetas.textosCon(kZoomDetalle);

      expect(
          visibles,
          containsAll([
            'Cafetería Principal',
            'Estacionamiento 1',
            'Coordinación de tecnologías',
            'para el aprendizaje',
            'Cancha de fútbol',
            'Laboratorio de',
            'Periodismo',
          ]));
      expect(etiquetas.visiblesCon(kZoomDetalle).textos, etiquetas.totalTextos);
    });

    test('las insignias de los lugares solo se ven desde zoom 1.8', () {
      expect(etiquetas.visiblesCon(1.0).insignias,
          etiquetas.totalInsignias - mapa.lugares.length);
      expect(etiquetas.visiblesCon(kZoomDetalle).insignias,
          etiquetas.totalInsignias);
    });

    test('el nombre de una zona fuera de meta.limites no se dibuja', () {
      // La Unidad Deportiva está del otro lado de Prolongación Colón.
      expect(etiquetas.textosCon(8.0),
          isNot(contains('Unidad Deportiva Venustiano Carranza')));
    });
  });

  group('EtiquetasMapaPainter', () {
    final etiquetas = EtiquetasMapaVectorial(mapa);
    tearDownAll(etiquetas.dispose);

    EtiquetasMapaPainter painter(double zoom) => EtiquetasMapaPainter(
          etiquetas: etiquetas,
          proyeccion: proyeccion,
          pantallaPorLienzo: 0.08 * zoom,
          zoom: zoom,
        );

    for (final zoom in [1.0, kZoomDetalle, 8.0]) {
      test('pinta sin excepciones con zoom $zoom', () {
        final recorder = ui.PictureRecorder();

        painter(zoom).paint(Canvas(recorder), proyeccion.tamanoLienzo);

        recorder.endRecording().dispose();
      });
    }

    test('se repinta al cambiar el zoom, y solo entonces', () {
      expect(painter(1.0).shouldRepaint(painter(1.0)), isFalse);
      expect(painter(1.0).shouldRepaint(painter(1.2)), isTrue);
    });
  });
}
