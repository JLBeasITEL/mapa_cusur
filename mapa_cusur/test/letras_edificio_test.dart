import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mapa_cusur/data/mapa_vectorial_parser.dart';
import 'package:mapa_cusur/domain/proyeccion_local.dart';
import 'package:mapa_cusur/models/mapa_vectorial.dart';
import 'package:mapa_cusur/ui/painters/etiquetas_mapa_painter.dart';

/// Poppins real: con la fuente de pruebas por omisión las letras tendrían
/// otro ancho.
Future<void> _cargarPoppins() async {
  final cargador = FontLoader('Poppins');
  for (final peso in ['Regular', 'Medium', 'SemiBold', 'Bold']) {
    final bytes = File('assets/fonts/Poppins-$peso.ttf').readAsBytesSync();
    cargador.addFont(Future.value(ByteData.sublistView(bytes)));
  }
  await cargador.load();
}

/// Par/impar con todos los anillos: dentro del contorno, fuera de huecos.
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

/// Puntos cada 5 cm sobre el borde de [r].
Iterable<Offset> _borde(Rect r) sync* {
  for (final (a, b) in [
    (r.topLeft, r.topRight),
    (r.topRight, r.bottomRight),
    (r.bottomRight, r.bottomLeft),
    (r.bottomLeft, r.topLeft),
  ]) {
    final n = math.max(1, ((b - a).distance / 0.05).ceil());
    for (var k = 0; k < n; k++) {
      yield a + (b - a) * (k / n);
    }
  }
}

/// Distancia de [p] al rectángulo [r] (0 si está dentro).
double _distanciaARect(Offset p, Rect r) {
  final dx = math.max(math.max(r.left - p.dx, 0.0), p.dx - r.right);
  final dy = math.max(math.max(r.top - p.dy, 0.0), p.dy - r.bottom);
  return math.sqrt(dx * dx + dy * dy);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final MapaVectorial mapa = parsearMapaVectorial(
      json.decode(File('assets/campus_vector.json').readAsStringSync()));
  final proyeccion = ProyeccionLocal(mapa.meta);
  final tamano = proyeccion.tamanoLienzo;
  // Panel de 412 × 360: píxeles de pantalla por metro con zoom ×1.
  final double pantallaPorMetroZoom1 =
      proyeccion.escala * math.min(412 / tamano.width, 360 / tamano.height);
  final conLetra = mapa.edificios.where((e) => e.letra != null).toList();

  // Todas las insignias del mapa: (centro en metros, tamaño relativo).
  final insignias = <(String, Offset, double)>[
    for (final e in mapa.edificios)
      if (e.icono != null) (e.nombre ?? e.icono!, e.etiqueta, 1.0),
    for (final c in mapa.canchasFutbol)
      if (c.iconoPos != null) ('fútbol', c.iconoPos!, 0.8),
    for (final c in mapa.canchas)
      if (c.iconoPos != null) (c.icono!, c.iconoPos!, 0.8),
    for (final l in mapa.lugares) (l.nombre, l.pos, 0.8),
    for (final e in mapa.entradas) (e.nombre, e.pos, 1.25),
    for (final e in mapa.estacionamientos) (e.nombre, e.pos, 1.0),
  ];

  late EtiquetasMapaVectorial etiquetas;
  setUpAll(() async {
    await _cargarPoppins();
    etiquetas = EtiquetasMapaVectorial(mapa);
  });
  tearDownAll(() => etiquetas.dispose());

  test('hay letra para todos los edificios que la tienen, incluidas '
      'H, J, N, W, M, P y L', () {
    expect(conLetra.map((e) => e.letra),
        containsAll(['H', 'J', 'N', 'W', 'M', 'P', 'L']));
  });

  for (final zoom in [1.0, 2.0, 4.0]) {
    group('con 412 × 360 y zoom ×$zoom', () {
      final pantallaPorMetro = pantallaPorMetroZoom1 * zoom;

      Rect cajaEnMetros(Edificio e) {
        final letra = etiquetas.letraEnPantalla(e.letra!,
            pantallaPorMetroZoom1: pantallaPorMetroZoom1, zoom: zoom)!;
        return Rect.fromCenter(
          center: letra.centro,
          width: letra.caja.width / pantallaPorMetro,
          height: letra.caja.height / pantallaPorMetro,
        );
      }

      test('cada letra se dibuja', () {
        for (final e in conLetra) {
          final letra = etiquetas.letraEnPantalla(e.letra!,
              pantallaPorMetroZoom1: pantallaPorMetroZoom1, zoom: zoom);
          expect(letra, isNotNull, reason: e.letra);
          expect(letra!.caja.width, greaterThan(0), reason: e.letra);
          expect(letra.caja.height, greaterThan(0), reason: e.letra);
        }
      });

      test('la caja de cada letra queda dentro de su polígono', () {
        for (final e in conLetra) {
          final caja = cajaEnMetros(e);
          for (final p in _borde(caja)) {
            expect(_dentro(p, e.anillos), isTrue,
                reason: '${e.letra}: el punto $p de su caja sale del edificio');
          }
        }
      });

      test('la caja de cada letra no se sobrepone con ninguna insignia', () {
        for (final e in conLetra) {
          final caja = cajaEnMetros(e);
          for (final (nombre, centro, tam) in insignias) {
            final radio = radioInsignia(zoom, tamano: tam) / pantallaPorMetro;
            expect(_distanciaARect(centro, caja), greaterThan(radio),
                reason: '${e.letra} toca la insignia de $nombre');
          }
        }
      });
    });
  }

  test('la ubicación se recalcula si cambia el viewport', () {
    final a = etiquetas.letraEnPantalla('P',
        pantallaPorMetroZoom1: pantallaPorMetroZoom1, zoom: 1)!;
    final b = etiquetas.letraEnPantalla('P',
        pantallaPorMetroZoom1: pantallaPorMetroZoom1 * 3, zoom: 1)!;
    // Con más px por metro, las insignias miden menos metros: el círculo
    // libre puede crecer, nunca achicarse.
    expect(b.radioLibre, greaterThanOrEqualTo(a.radioLibre - 0.5));
  });
}
