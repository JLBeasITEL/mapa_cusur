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

  for (final zoom in [1.0, kZoomDetalle, 3.0, 8.0]) {
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
