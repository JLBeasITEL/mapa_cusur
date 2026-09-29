import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../domain/transformacion_geo.dart';
import '../../models/grafo_campus.dart';
import '../../models/nodo.dart';

/// Dibuja el trazado estático del grafo: las aristas (líneas) y los nodos
/// reales -sin los fantasma, que se ven pero no se marcan- del grafo ya
/// interpolado (~2318 aristas, ~1008 nodos).
///
/// Vive en su propia capa (su propio `CustomPaint`), separada del marcador
/// de GPS y de la ruta resaltada (`RoutePainter`): así, actualizar la
/// posición del usuario -algo que pasa constantemente mientras el GPS está
/// activo- no obliga a redibujar el grafo completo en cada frame. Flutter
/// solo vuelve a llamar a `paint()` en una capa cuando el `shouldRepaint`
/// de *esa* capa dice que hace falta.
///
/// Además cachea el `Path` resultante: antes, `RoutePainter.paint`
/// reconstruía las líneas de todas las aristas y los círculos de todos los
/// nodos desde cero en cada repintado, incluso cuando ni el grafo ni el
/// zoom habían cambiado. El caché se invalida solo si cambia el grafo (por
/// identidad: es la misma instancia mientras la app no recargue datos) o
/// la escala de zoom (de la que depende el radio de los círculos).
class GrafoEstaticoPainter extends CustomPainter {
  final GrafoCampus grafo;
  final double zoomScale;

  GrafoEstaticoPainter({required this.grafo, required this.zoomScale});

  static GrafoCampus? _grafoCacheado;
  static double? _zoomCacheado;
  static ui.Path? _pathAristasCacheado;
  static ui.Path? _pathNodosCacheado;

  static Offset _transformar(Nodo nodo) {
    final p = pixelesACanvas(nodo.pixelX, nodo.pixelY);
    return Offset(p.x, p.y);
  }

  ({ui.Path aristas, ui.Path nodos}) _trazadoEstatico() {
    if (identical(_grafoCacheado, grafo) && _zoomCacheado == zoomScale) {
      return (aristas: _pathAristasCacheado!, nodos: _pathNodosCacheado!);
    }

    final pathAristas = ui.Path();
    final pathNodos = ui.Path();
    final double radioNodo = 8.0 / zoomScale;

    for (final origen in grafo.conexiones.keys) {
      final nodoOrigen = grafo.nodos[origen];
      if (nodoOrigen == null) continue;
      final punto1 = _transformar(nodoOrigen);

      // Ocultamos los puntos fantasmas visualmente, pero dejamos que la
      // línea pase por ellos.
      if (!origen.contains('_inter_')) {
        pathNodos.addOval(Rect.fromCircle(center: punto1, radius: radioNodo));
      }

      for (final destino in grafo.conexiones[origen]!.keys) {
        final nodoDestino = grafo.nodos[destino];
        if (nodoDestino == null) continue;
        final punto2 = _transformar(nodoDestino);
        pathAristas
          ..moveTo(punto1.dx, punto1.dy)
          ..lineTo(punto2.dx, punto2.dy);
      }
    }

    _grafoCacheado = grafo;
    _zoomCacheado = zoomScale;
    _pathAristasCacheado = pathAristas;
    _pathNodosCacheado = pathNodos;
    return (aristas: pathAristas, nodos: pathNodos);
  }

  @override
  void paint(Canvas canvas, Size size) {
    final trazado = _trazadoEstatico();

    final paintGrafo = Paint()
      ..color = Colors.blueAccent.withValues(alpha: 0.4)
      ..strokeWidth = 4.0 / zoomScale
      ..style = PaintingStyle.stroke;
    final paintNodo = Paint()
      ..color = Colors.blueAccent.withValues(alpha: 0.6)
      ..style = PaintingStyle.fill;

    canvas.drawPath(trazado.aristas, paintGrafo);
    canvas.drawPath(trazado.nodos, paintNodo);
  }

  @override
  bool shouldRepaint(covariant GrafoEstaticoPainter oldDelegate) {
    return !identical(oldDelegate.grafo, grafo) ||
        oldDelegate.zoomScale != zoomScale;
  }
}
