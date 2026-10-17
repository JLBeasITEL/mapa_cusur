import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mapa_cusur/data/mapa_vectorial_parser.dart';
import 'package:mapa_cusur/domain/proyeccion_local.dart';
import 'package:mapa_cusur/models/mapa_vectorial.dart';
import 'package:mapa_cusur/ui/painters/etiquetas_mapa_painter.dart';

/// Poppins real (la de la app): con la fuente de pruebas por omisión los
/// textos tendrían otro ancho y las colisiones no serían las del teléfono.
Future<void> _cargarPoppins() async {
  final cargador = FontLoader('Poppins');
  for (final peso in ['Regular', 'Medium', 'SemiBold', 'Bold']) {
    final bytes = File('assets/fonts/Poppins-$peso.ttf').readAsBytesSync();
    cargador.addFont(Future.value(ByteData.sublistView(bytes)));
  }
  await cargador.load();
}

/// Si [a] y [b] son líneas de un mismo bloque de texto (un lugar de varias
/// líneas o un subtítulo).
bool _mismoBloque(String a, String b) {
  final mapa = parsearMapaVectorial(
      json.decode(File('assets/campus_vector.json').readAsStringSync()));
  final bloques = [
    for (final l in mapa.lugares) l.lineas,
    for (final e in mapa.edificios)
      if (e.subtitulo != null) e.subtitulo!,
  ];
  return bloques.any((lineas) => lineas.contains(a) && lineas.contains(b));
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final MapaVectorial mapa = parsearMapaVectorial(
      json.decode(File('assets/campus_vector.json').readAsStringSync()));
  final proyeccion = ProyeccionLocal(mapa.meta);
  final tamano = proyeccion.tamanoLienzo;

  // Panel del mapa de 412 × 360 (ancho de un teléfono y 40 % de su alto):
  // escala del FittedBox, píxeles de pantalla por unidad de lienzo.
  final double ajusteTelefono =
      math.min(412 / tamano.width, 360 / tamano.height);

  late EtiquetasMapaVectorial etiquetas;
  setUpAll(() async {
    await _cargarPoppins();
    etiquetas = EtiquetasMapaVectorial(mapa);
  });
  tearDownAll(() => etiquetas.dispose());

  ColocacionEtiquetas colocar(double zoom, {bool mostrarIconos = true}) =>
      etiquetas.colocar(
        proyeccion: proyeccion,
        pantallaPorLienzo: ajusteTelefono * zoom,
        zoom: zoom,
        mostrarIconos: mostrarIconos,
      );

  test(
      'con 412 × 360 y zoom ×1, "Calle Universidad de Guadalajara" no se '
      'superpone con "Entrada Sur" ni con "Entrada Principal"', () {
    final colocacion = colocar(1);
    final entradas = colocacion.ocupados
        .where((o) => o.nombre == 'Entrada Sur' || o.nombre == 'Entrada Principal')
        .toList();
    // El texto y la insignia de cada una.
    expect(entradas, hasLength(4));

    final calle = colocacion.calles
        .where((c) => c.texto == 'Calle Universidad de Guadalajara');
    for (final c in calle) {
      for (final e in entradas) {
        expect(c.rect.overlaps(e.rect), isFalse,
            reason: 'choca con ${e.nombre}');
      }
    }
  });

  for (final zoom in [1.0, 2.0, 4.0, 8.0]) {
    for (final mostrarIconos in [true, false]) {
      test(
          'con zoom $zoom${mostrarIconos ? '' : ' y sin íconos'}, ningún '
          'nombre de calle choca con otra etiqueta', () {
        final colocacion = colocar(zoom, mostrarIconos: mostrarIconos);
        for (final c in colocacion.calles) {
          final otros = colocacion.ocupados.where((o) => o.nombre != c.texto);
          for (final o in otros) {
            expect(c.rect.overlaps(o.rect), isFalse,
                reason: '${c.texto} choca con ${o.nombre}');
          }
        }
      });
    }
  }

  group('nombres largos', () {
    for (final zoom in [1.0, 2.0, 4.0, 6.0, 8.0]) {
      for (final mostrarIconos in [true, false]) {
        test(
            'con zoom $zoom${mostrarIconos ? '' : ' y sin íconos'}, ningún '
            'nombre largo dibujado se encima con otro texto', () {
          final colocacion = colocar(zoom, mostrarIconos: mostrarIconos);
          final textos =
              colocacion.ocupados.where((o) => o.tipo != 'insignia').toList();
          for (final largo in textos.where((o) => o.tipo == 'largo')) {
            for (final otro in textos) {
              if (identical(otro, largo)) continue;
              // Las líneas de un mismo bloque se tocan por el margen.
              if (otro.tipo == 'largo' &&
                  _mismoBloque(largo.nombre, otro.nombre)) {
                continue;
              }
              expect(largo.rect.overlaps(otro.rect), isFalse,
                  reason: '${largo.nombre} choca con ${otro.nombre}');
            }
          }
        });
      }
    }

    test('a ×4 se ocultan los que chocan y el resto se dibuja', () {
      final colocacion = colocar(4);
      final dibujados = colocacion.ocupados
          .where((o) => o.tipo == 'largo')
          .map((o) => o.nombre)
          .toList();

      expect(colocacion.largosOcultos, isNotEmpty);
      // "Laboratorio de" es la primera línea de varios lugares: puede estar
      // oculta en uno y dibujada en otro.
      for (final oculto in colocacion.largosOcultos) {
        if (oculto == 'Laboratorio de') continue;
        expect(dibujados, isNot(contains(oculto)));
      }
    });

    test('un texto no se oculta por chocar con su propia insignia', () {
      final dibujados = colocar(8)
          .ocupados
          .where((o) => o.tipo == 'largo')
          .map((o) => o.nombre)
          .toSet();

      expect(
          dibujados,
          containsAll(
              ['Cafetería Principal', 'Estacionamiento 1', 'Clínica Escuela']));
    });

    test('las líneas de un bloque se dibujan todas o ninguna', () {
      for (final zoom in [4.0, 6.0, 8.0]) {
        final colocacion = colocar(zoom);
        final ocultos = colocacion.largosOcultos;
        for (final lugar in mapa.lugares.where((l) => l.lineas.length > 1)) {
          // La última línea es única de cada lugar ("Periodismo"...); la
          // primera puede repetirse ("Laboratorio de").
          if (ocultos.contains(lugar.lineas.last)) {
            expect(ocultos, containsAll(lugar.lineas),
                reason: '${lugar.nombre} con zoom $zoom');
          }
        }
      }
    });
  });

  group('subtítulo del Edificio C', () {
    ColocacionEtiquetas conVista(double zoom) => etiquetas.colocar(
          proyeccion: proyeccion,
          pantallaPorLienzo: ajusteTelefono * zoom,
          zoom: zoom,
          mostrarIconos: true,
          vista: const Size(412, 360),
        );

    Set<String> largosDibujados(ColocacionEtiquetas c) => c.ocupados
        .where((o) => o.tipo == 'largo')
        .map((o) => o.nombre)
        .toSet();

    test('no aparece con ×8 (el edificio cubre el 61 % del ancho)', () {
      expect(largosDibujados(conVista(8)),
          isNot(contains('Coordinación de tecnologías')));
    });

    test('aparece con ×10 y ×12, sin chocar con su letra ni con nada más',
        () {
      for (final zoom in [10.0, 12.0]) {
        final colocacion = conVista(zoom);
        expect(largosDibujados(colocacion),
            containsAll(['Coordinación de tecnologías', 'para el aprendizaje']),
            reason: 'zoom $zoom');
        expect(colocacion.largosOcultos,
            isNot(contains('Coordinación de tecnologías')));
      }
    });
  });

  test('la colocación no se recalcula si no cambian la escala ni el zoom', () {
    expect(identical(colocar(2), colocar(2)), isTrue);
    expect(identical(colocar(2), colocar(2.5)), isFalse);
    expect(identical(colocar(2), colocar(2, mostrarIconos: false)), isFalse);
  });

  test('a cada nombre de calle le toca a lo más una posición', () {
    for (final zoom in [1.0, 4.0]) {
      final textos = colocar(zoom).calles.map((c) => c.texto).toList();
      expect(textos.toSet(), hasLength(textos.length));
    }
  });
}
