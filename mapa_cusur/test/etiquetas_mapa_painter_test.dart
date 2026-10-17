import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mapa_cusur/data/mapa_vectorial_parser.dart';
import 'package:mapa_cusur/domain/proyeccion_local.dart';
import 'package:mapa_cusur/models/mapa_vectorial.dart';
import 'package:mapa_cusur/ui/mapa/colores_mapa_vectorial.dart';
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

  group('tamaño de las insignias', () {
    test('el radio crece con el zoom hasta un tope de 22 px', () {
      expect(radioInsignia(1), 5.5);
      expect(radioInsignia(2), 11);
      expect(radioInsignia(4), 22);
      expect(radioInsignia(8), 22);
    });

    test('las entradas conservan su factor de 1.25', () {
      expect(radioInsignia(2, tamano: 1.25), 13.75);
      expect(radioInsignia(8, tamano: 1.25), 27.5);
    });

    final etiquetas = EtiquetasMapaVectorial(mapa);
    tearDownAll(etiquetas.dispose);

    test('el texto debajo de un ícono queda a radio + 8 px', () {
      for (final zoom in [1.0, 2.0, 4.0, 8.0]) {
        final r = radioInsignia(zoom);
        expect(etiquetas.desplazamientoDe('Estacionamiento 1', zoom: zoom),
            r + 8);
        expect(etiquetas.desplazamientoDe('Cafetería Principal', zoom: zoom),
            r + 8);
        expect(etiquetas.desplazamientoDe('Entrada Sur', zoom: zoom),
            radioInsignia(zoom, tamano: 1.25) + 8);
        // La segunda línea de un lugar va una línea más abajo (y su
        // insignia es del 80 %).
        expect(etiquetas.desplazamientoDe('Periodismo', zoom: zoom),
            closeTo(radioInsignia(zoom, tamano: 0.8) + 8 + 1.15 * 10.5, 1e-9));
      }
    });

    test('los textos que no van debajo de un ícono no se mueven', () {
      for (final zoom in [1.0, 2.0, 8.0]) {
        expect(etiquetas.desplazamientoDe('Z', zoom: zoom), 0);
        expect(etiquetas.desplazamientoDe('Coordinación de tecnologías',
            zoom: zoom), 13);
        expect(etiquetas.desplazamientoDe('Sala de Gobierno', zoom: zoom), 0);
      }
    });
  });

  group('EtiquetasMapaVectorial: visibilidad por píxeles por metro', () {
    final etiquetas = EtiquetasMapaVectorial(mapa);
    tearDownAll(etiquetas.dispose);

    test('lejos (1 px/m) se ven letras, entradas y calles, pero no nombres',
        () {
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

    test('desde 3.1 px/m se ven también los textos largos', () {
      expect(kDetallePxPorMetro, 3.1);
      expect(etiquetas.textosCon(kDetallePxPorMetro - 0.01),
          isNot(contains('Cafetería Principal')));

      final visibles = etiquetas.textosCon(kDetallePxPorMetro);

      expect(
          visibles,
          containsAll([
            'Cafetería Principal',
            'Estacionamiento 1',
            'Cancha de fútbol',
            'Laboratorio de',
            'Periodismo',
          ]));
      // Todos menos las dos líneas del subtítulo del Edificio C, que
      // dependen de cuánto cubre el edificio la pantalla.
      expect(etiquetas.visiblesCon(kDetallePxPorMetro).textos,
          etiquetas.totalTextos - 2);
    });

    test('el subtítulo solo se ve cuando el edificio cubre el 75 % de la vista',
        () {
      const vista = Size(412, 360);
      final c = mapa.edificios.singleWhere((e) => e.subtitulo != null);
      final xs = c.anillos.first.map((p) => p.dx);
      final ancho = xs.reduce(math.max) - xs.reduce(math.min);
      // Px por metro con los que el ancho del edificio llena el 75 %.
      final umbral = kCoberturaSubtitulo * vista.width / ancho;

      expect(
          etiquetas.textosCon(umbral * 0.98, vista: vista),
          isNot(contains('Coordinación de tecnologías')));
      expect(etiquetas.textosCon(umbral * 1.02, vista: vista),
          containsAll(['Coordinación de tecnologías', 'para el aprendizaje']));
      // Sin vista no hay forma de saber cuánto cubre: no se dibuja.
      expect(etiquetas.textosCon(100),
          isNot(contains('Coordinación de tecnologías')));
    });

    test('todas las insignias, también las de lugares, se ven a cualquier '
        'distancia; los nombres de los lugares, solo desde 3.1 px/m', () {
      expect(etiquetas.visiblesCon(0.5).insignias, etiquetas.totalInsignias);
      expect(etiquetas.textosCon(kDetallePxPorMetro - 0.01),
          isNot(contains('Periodismo')));
      expect(etiquetas.textosCon(kDetallePxPorMetro), contains('Periodismo'));
    });

    test('lugares y canchas usan insignias al 80 % de las de edificio', () {
      expect(etiquetas.tamanoDeInsignia('Laboratorio de Periodismo'), 0.8);
      expect(etiquetas.tamanoDeInsignia('Parque de las ardillas'), 0.8);
      expect(etiquetas.tamanoDeInsignia('sports_tennis'), 0.8);
      expect(etiquetas.tamanoDeInsignia('sports_basketball'), 0.8);
      expect(etiquetas.tamanoDeInsignia('Cancha de fútbol'), 0.8);
      expect(etiquetas.tamanoDeInsignia('Cafetería Principal'), 1.0);
      expect(etiquetas.tamanoDeInsignia('Entrada Sur'), 1.25);
      // Misma regla con el zoom y mismo tope, a escala.
      expect(radioInsignia(1, tamano: 0.8), closeTo(4.4, 1e-9));
      expect(radioInsignia(8, tamano: 0.8), closeTo(17.6, 1e-9));
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

    for (final zoom in [1.0, 4.0, 8.0]) {
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

  group('íconos ocultos', () {
    final etiquetas = EtiquetasMapaVectorial(mapa);
    tearDownAll(etiquetas.dispose);

    // El relleno de cada insignia dibujada (una por insignia: el borde
    // es un trazo).
    List<Color> rellenosDeInsignias({required bool mostrarIconos}) {
      final canvas = _CanvasEspia();
      EtiquetasMapaPainter(
        etiquetas: etiquetas,
        proyeccion: proyeccion,
        pantallaPorLienzo: 0.08 * 8,
        zoom: 8, // con zoom alto se ven todas, también las de los lugares
        mostrarIconos: mostrarIconos,
      ).paint(canvas, proyeccion.tamanoLienzo);
      return canvas.rellenosDeCirculos;
    }

    test('con los íconos visibles se dibujan todas las insignias', () {
      expect(rellenosDeInsignias(mostrarIconos: true),
          hasLength(etiquetas.totalInsignias));
    });

    test('con los íconos ocultos solo se dibujan las de las entradas', () {
      final rellenos = rellenosDeInsignias(mostrarIconos: false);

      // Se compara el ARGB: Paint.color no devuelve el mismo tipo de Color.
      expect(rellenos, hasLength(mapa.entradas.length));
      expect(rellenos.map((c) => c.toARGB32()),
          everyElement(ColoresMapaVectorial.entrada.toARGB32()));
    });

    test('sus textos quedan centrados donde estaba la insignia', () {
      const interlineado = 1.15 * 10.5;
      for (final zoom in [1.8, 4.0]) {
        expect(
            etiquetas.desplazamientoDe('Estacionamiento 1',
                zoom: zoom, mostrarIconos: false),
            0);
        expect(
            etiquetas.desplazamientoDe('Cafetería Principal',
                zoom: zoom, mostrarIconos: false),
            0);
        // Un lugar de dos líneas: el bloque centrado en la insignia.
        expect(
            etiquetas.desplazamientoDe('Laboratorio de',
                zoom: zoom, mostrarIconos: false),
            closeTo(-interlineado / 2, 1e-9));
        expect(
            etiquetas.desplazamientoDe('Periodismo',
                zoom: zoom, mostrarIconos: false),
            closeTo(interlineado / 2, 1e-9));
      }
    });

    test('las entradas, las letras y la visibilidad de los textos no cambian',
        () {
      expect(
          etiquetas.desplazamientoDe('Entrada Sur',
              zoom: 2, mostrarIconos: false),
          radioInsignia(2, tamano: 1.25) + 8);
      expect(etiquetas.desplazamientoDe('Z', zoom: 2, mostrarIconos: false),
          0);
    });

    test('cambiar el botón repinta la capa', () {
      EtiquetasMapaPainter con(bool mostrar) => EtiquetasMapaPainter(
            etiquetas: etiquetas,
            proyeccion: proyeccion,
            pantallaPorLienzo: 0.08,
            zoom: 1,
            mostrarIconos: mostrar,
          );

      expect(con(true).shouldRepaint(con(false)), isTrue);
      expect(con(false).shouldRepaint(con(false)), isFalse);
    });
  });
}

/// Registra el color de cada círculo relleno que se dibuja; todo lo demás
/// lo ignora.
class _CanvasEspia implements Canvas {
  final List<Color> rellenosDeCirculos = [];

  @override
  void drawCircle(Offset c, double radius, Paint paint) {
    if (paint.style == PaintingStyle.fill) rellenosDeCirculos.add(paint.color);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}
