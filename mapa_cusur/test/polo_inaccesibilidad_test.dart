import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:mapa_cusur/data/mapa_vectorial_parser.dart';
import 'package:mapa_cusur/domain/polo_inaccesibilidad.dart';
import 'package:mapa_cusur/models/mapa_vectorial.dart';
import 'package:mapa_cusur/ui/painters/mapa_vectorial_painter.dart';

List<Offset> _rectangulo(double x0, double y0, double x1, double y1) => [
      Offset(x0, y0),
      Offset(x1, y0),
      Offset(x1, y1),
      Offset(x0, y1),
      Offset(x0, y0),
    ];

/// Par/impar con todos los anillos: dentro del contorno y fuera de los
/// huecos (independiente de la implementación de polylabel).
bool _dentro(Offset p, List<List<Offset>> anillos) {
  var dentro = false;
  for (final anillo in anillos) {
    for (var i = 0, j = anillo.length - 1; i < anillo.length; j = i++) {
      final a = anillo[i], b = anillo[j];
      if ((a.dy > p.dy) != (b.dy > p.dy) &&
          p.dx < (b.dx - a.dx) * (p.dy - a.dy) / (b.dy - a.dy) + a.dx) {
        dentro = !dentro;
      }
    }
  }
  return dentro;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('poloDeInaccesibilidad (polígonos sintéticos)', () {
    test('cuadrado de 10 m: el centro, con radio 5', () {
      final polo = poloDeInaccesibilidad([_rectangulo(0, 0, 10, 10)]);

      expect(polo.centro.dx, closeTo(5, 0.5));
      expect(polo.centro.dy, closeTo(5, 0.5));
      expect(polo.radio, closeTo(5, 0.5));
    });

    test('rectángulo de 40 × 10 m: radio 5, a media altura', () {
      final polo = poloDeInaccesibilidad([_rectangulo(0, 0, 40, 10)]);

      expect(polo.radio, closeTo(5, 0.5));
      expect(polo.centro.dy, closeTo(5, 0.5));
    });

    test('con un hueco en medio, el centro no cae en el hueco', () {
      final anillos = [
        _rectangulo(0, 0, 30, 30),
        _rectangulo(10, 10, 20, 20),
      ];
      final polo = poloDeInaccesibilidad(anillos);

      // El círculo más grande está en una esquina: tangente a los dos
      // bordes exteriores y tocando la esquina del hueco,
      // r = 10·√2 / (1 + √2) ≈ 5.86.
      expect(_dentro(polo.centro, anillos), isTrue);
      expect(polo.radio, closeTo(10 * math.sqrt2 / (1 + math.sqrt2), 0.5));
    });

    test('en forma de L, el centro cae dentro de la L', () {
      final ele = [
        const Offset(0, 0),
        const Offset(10, 0),
        const Offset(10, 30),
        const Offset(30, 30),
        const Offset(30, 40),
        const Offset(0, 40),
        const Offset(0, 0),
      ];
      final polo = poloDeInaccesibilidad([ele]);

      // Junto a la esquina interior cabe un círculo algo mayor que el
      // ancho de los brazos: r = 10·√2 / (1 + √2) ≈ 5.86.
      expect(_dentro(polo.centro, [ele]), isTrue);
      expect(polo.radio, closeTo(10 * math.sqrt2 / (1 + math.sqrt2), 0.5));
    });
  });

  group('edificios reales de campus_vector.json', () {
    final MapaVectorial mapa = parsearMapaVectorial(
        json.decode(File('assets/campus_vector.json').readAsStringSync()));
    final polos = GeometriaMapaVectorial.polosDeEdificios(mapa);
    final conLetra = mapa.edificios.where((e) => e.letra != null).toList();

    test('hay un polo por cada edificio con letra', () {
      expect(conLetra, isNotEmpty);
      expect(polos.keys, unorderedEquals(conLetra));
    });

    test('el centro de cada edificio con letra cae dentro de su polígono', () {
      for (final e in conLetra) {
        final polo = polos[e]!;
        expect(_dentro(polo.centro, e.anillos), isTrue, reason: e.letra);
        expect(polo.radio, greaterThan(0), reason: e.letra);
      }
    });
  });
}
