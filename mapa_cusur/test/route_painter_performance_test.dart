// Mide cuánto tarda pintar el grafo completo (~2318 aristas, ~1008 nodos
// interpolados del campus real) antes y después de la Fase 7: antes,
// `RoutePainter.paint` reconstruía las líneas y los círculos desde cero en
// cada llamada; después, `GrafoEstaticoPainter` cachea ese trazado y solo
// lo reconstruye si cambia el grafo o el zoom.
//
// Llama a `paint()` directamente sobre un Canvas de un PictureRecorder -sin
// pasar por el árbol de widgets- para medir el costo puro del cómputo
// geométrico, que es exactamente lo que cambió. No falla por umbral: mide y
// reporta, igual que test/rendimiento_test.dart en la Fase 2. La cifra que
// imprime es la que se cita en la tesis.
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mapa_cusur/data/campus_json_parser.dart';
import 'package:mapa_cusur/domain/interpolacion_nodos.dart';
import 'package:mapa_cusur/domain/transformacion_geo.dart';
import 'package:mapa_cusur/models/grafo_campus.dart';
import 'package:mapa_cusur/models/nodo.dart';
import 'package:mapa_cusur/ui/painters/grafo_estatico_painter.dart';

/// Copia del `RoutePainter.paint` de antes de la Fase 7: sin caché, sin
/// separar la capa estática de la dinámica. Solo la parte que dibuja el
/// grafo -la que de verdad domina el costo, con miles de aristas/nodos-,
/// para que el benchmark compare como corresponde: lo que cambió contra lo
/// que cambió.
class _PainterMonoliticoAntiguo extends CustomPainter {
  final GrafoCampus grafo;
  final double zoomScale;

  _PainterMonoliticoAntiguo({required this.grafo, required this.zoomScale});

  static Offset _transformar(Nodo nodo) {
    final p = pixelesACanvas(nodo.pixelX, nodo.pixelY);
    return Offset(p.x, p.y);
  }

  @override
  void paint(Canvas canvas, Size size) {
    final paintGrafo = Paint()
      ..color = Colors.blueAccent.withValues(alpha: 0.4)
      ..strokeWidth = 4.0 / zoomScale
      ..style = PaintingStyle.stroke;
    final paintNodo = Paint()
      ..color = Colors.blueAccent.withValues(alpha: 0.6)
      ..style = PaintingStyle.fill;

    for (final origen in grafo.conexiones.keys) {
      final nodoOrigen = grafo.nodos[origen];
      if (nodoOrigen == null) continue;
      final punto1 = _transformar(nodoOrigen);

      if (!origen.contains('_inter_')) {
        canvas.drawCircle(punto1, 8.0 / zoomScale, paintNodo);
      }

      for (final destino in grafo.conexiones[origen]!.keys) {
        final nodoDestino = grafo.nodos[destino];
        if (nodoDestino != null) {
          canvas.drawLine(punto1, _transformar(nodoDestino), paintGrafo);
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant _PainterMonoliticoAntiguo oldDelegate) => true;
}

void main() {
  test('trazado del grafo: sin caché (antes) vs. con caché (después), '
      '${300} repintados simulados', () {
    final Map<String, dynamic> data =
        json.decode(File('assets/campus_data.json').readAsStringSync());
    final grafo = interpolarGrafo(parsearGrafoCampus(data));

    const int repintados = 300;
    const Size size = Size(1000, 1000);
    const double zoom = 2.0; // constante entre llamadas: el caso común -el
    // zoom no cambia en cada actualización de GPS, solo la posición-.

    // Calentamiento (JIT) fuera de la medición.
    for (int i = 0; i < 10; i++) {
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);
      _PainterMonoliticoAntiguo(grafo: grafo, zoomScale: zoom)
          .paint(canvas, size);
      recorder.endRecording().dispose();
    }

    final swAntes = Stopwatch()..start();
    for (int i = 0; i < repintados; i++) {
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);
      _PainterMonoliticoAntiguo(grafo: grafo, zoomScale: zoom)
          .paint(canvas, size);
      recorder.endRecording().dispose();
    }
    swAntes.stop();

    final swDespues = Stopwatch()..start();
    for (int i = 0; i < repintados; i++) {
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);
      // Una instancia nueva en cada iteración -como pasa de verdad en la
      // app, un RoutePainter/GrafoEstaticoPainter nuevo por cada build-,
      // pero el caché vive en campos `static`, así que sigue
      // aprovechándose entre instancias.
      GrafoEstaticoPainter(grafo: grafo, zoomScale: zoom).paint(canvas, size);
      recorder.endRecording().dispose();
    }
    swDespues.stop();

    final double msAntes = swAntes.elapsedMicroseconds / 1000.0;
    final double msDespues = swDespues.elapsedMicroseconds / 1000.0;
    final double msPorFrameAntes = msAntes / repintados;
    final double msPorFrameDespues = msDespues / repintados;
    // "FPS teóricos": el máximo posible SI el costo de paint() en Dart
    // fuera el único cuello de botella del frame -no lo es: falta la
    // rasterización en la GPU y el techo real del refresco de la
    // pantalla (60-120 Hz)-. Sirve para comparar el ANTES contra el
    // DESPUÉS, no como una cifra de FPS real medida en un dispositivo.
    final double fpsTeoricosAntes = 1000.0 / msPorFrameAntes;
    final double fpsTeoricosDespues = 1000.0 / msPorFrameDespues;

    // ignore: avoid_print
    print('--- Fase 7: rendimiento del painter ($repintados repintados, '
        'grafo interpolado de ${grafo.nodos.length} nodos, zoom constante) ---');
    // ignore: avoid_print
    print('Antes  (sin caché, reconstruye cada frame): '
        '${msAntes.toStringAsFixed(2)} ms total, '
        '${msPorFrameAntes.toStringAsFixed(4)} ms/frame '
        '(tope teórico ~${fpsTeoricosAntes.toStringAsFixed(0)} FPS solo por '
        'este costo, sin contar rasterización ni el límite de la pantalla)');
    // ignore: avoid_print
    print('Después (con caché, zoom constante): '
        '${msDespues.toStringAsFixed(2)} ms total, '
        '${msPorFrameDespues.toStringAsFixed(4)} ms/frame '
        '(tope teórico ~${fpsTeoricosDespues.toStringAsFixed(0)} FPS)');
    // ignore: avoid_print
    print('Mejora en el costo de paint(): '
        '${(msAntes / msDespues).toStringAsFixed(1)}x');
    // ignore: avoid_print
    print('(Este número mide solo el costo de paint() en Dart, no FPS '
        'reales de un dispositivo -para eso hace falta perfilar la app '
        'corriendo, con el profiler de Flutter DevTools-. En la app real '
        'hay además una segunda mejora que este micro-benchmark no '
        'captura: con la capa estática separada y su propio shouldRepaint, '
        'Flutter ni siquiera llama a paint() en la mayoría de los frames '
        '-antes, un RoutePainter con shouldRepaint por identidad de lista '
        'garantizaba un repintado completo en casi todos-.)');

    // No se falla por umbral: el propósito es medir y reportar.
    expect(msAntes, greaterThanOrEqualTo(0));
    expect(msDespues, greaterThanOrEqualTo(0));
  });
}
