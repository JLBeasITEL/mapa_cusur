import 'dart:ui' as ui;

import 'package:flutter/foundation.dart' show listEquals;
import 'package:flutter/material.dart';

import '../../data/diccionario_nombres.dart';
import '../../domain/transformacion_geo.dart';
import '../../domain/ubicacion_en_ruta.dart';
import '../../models/grafo_campus.dart';
import '../../models/nodo.dart';
import '../theme/poppins.dart';

/// Dibuja la ruta resaltada, los pines de origen/destino y el marcador de
/// GPS "Estás aquí" -todo lo que cambia con frecuencia-.
///
/// El trazado estático del grafo (aristas y nodos, que casi nunca cambia)
/// vive en su propia capa (`GrafoEstaticoPainter`), separada de esta a
/// propósito: así, una actualización de GPS -que llega constantemente
/// mientras el rastreo está activo- solo repinta esta capa, mucho más
/// barata, sin tocar el grafo completo.
class RoutePainter extends CustomPainter {
  final List<String> ruta;
  final GrafoCampus grafo;

  /// Modelo de transformación geo→píxel activo (Fase 4). `null` mientras
  /// los datos del campus aún no terminan de cargar.
  final TransformacionGeoPixel? transformacion;

  final ui.Image? markerImage;
  final double zoomScale;

  /// Ubicación del usuario ya filtrada, suavizada y proyectada
  /// ortogonalmente sobre la arista más cercana (Fase 3). El marcador
  /// "Estás aquí" se dibuja en esta posición continua, no en la lectura
  /// cruda del GPS ni en un nodo discreto.
  final UbicacionEnGrafo? ubicacionGPS;

  RoutePainter({
    required this.ruta,
    required this.grafo,
    required this.transformacion,
    required this.markerImage,
    required this.zoomScale,
    required this.ubicacionGPS,
  });

  static Offset _transformar(Nodo nodo) {
    final p = pixelesACanvas(nodo.pixelX, nodo.pixelY);
    return Offset(p.x, p.y);
  }

  @override
  void paint(Canvas canvas, Size size) {
    final paintRuta = Paint()
      ..color = Colors.red
      ..strokeWidth = 36.0
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;

    void dibujarPinConEtiquetaTexto(
        String texto, Offset posicion, Color colorFondo) {
      const double imgSize = 180.0;
      const double subirPin = 140.0;

      if (markerImage != null) {
        canvas.save();
        canvas.translate(posicion.dx, posicion.dy);
        final dstRect = Rect.fromLTWH(-imgSize / 2, -subirPin, imgSize, imgSize);
        final srcRect = Rect.fromLTWH(
            0, 0, markerImage!.width.toDouble(), markerImage!.height.toDouble());
        canvas.drawImageRect(markerImage!, srcRect, dstRect, Paint());
        canvas.restore();
      }

      final textStyle = poppins(
          color: Colors.white, fontSize: 50.0, fontWeight: FontWeight.bold);
      final textPainter = TextPainter(
          text: TextSpan(text: texto, style: textStyle),
          textDirection: TextDirection.ltr);
      textPainter.layout();
      final Offset textoPos =
          Offset(posicion.dx, posicion.dy - subirPin - 60);
      final rect = Rect.fromCenter(
          center: textoPos,
          width: textPainter.width + 40,
          height: textPainter.height + 20);

      canvas.drawRRect(RRect.fromRectAndRadius(rect, const Radius.circular(15)),
          Paint()..color = colorFondo.withValues(alpha: 0.9));
      textPainter.paint(canvas,
          Offset(textoPos.dx - textPainter.width / 2, textoPos.dy - textPainter.height / 2));
    }

    if (ruta.isNotEmpty) {
      for (int i = 0; i < ruta.length - 1; i++) {
        final n1 = grafo.nodos[ruta[i]];
        final n2 = grafo.nodos[ruta[i + 1]];
        if (n1 != null && n2 != null) {
          canvas.drawLine(_transformar(n1), _transformar(n2), paintRuta);
        }
      }
      final String origenNombre = ruta.first;
      final String destinoNombre = ruta.last;
      final String aliasOrigen = diccionarioNombres[origenNombre] ?? origenNombre;
      final String aliasDestino = diccionarioNombres[destinoNombre] ?? destinoNombre;

      final nodoOrigenRuta = grafo.nodos[origenNombre];
      final nodoDestinoRuta = grafo.nodos[destinoNombre];

      if (nodoOrigenRuta != null && ubicacionGPS == null) {
        dibujarPinConEtiquetaTexto(
            aliasOrigen, _transformar(nodoOrigenRuta), Colors.green);
      }
      if (nodoDestinoRuta != null) {
        dibujarPinConEtiquetaTexto(
            aliasDestino, _transformar(nodoDestinoRuta), Colors.red);
      }
    }

    if (ubicacionGPS != null && transformacion != null && grafo.nodos.isNotEmpty) {
      final posGeo = geoACanvas(transformacion!,
          lat: ubicacionGPS!.lat, lng: ubicacionGPS!.lng);
      final Offset posicionUsuarioCanvas = Offset(posGeo.x, posGeo.y);

      final paintAura = Paint()
        ..color = Colors.blue.withValues(alpha: 0.3)
        ..style = PaintingStyle.fill;
      final paintDot = Paint()
        ..color = const Color(0xFF2563EB)
        ..style = PaintingStyle.fill;
      final paintBorder = Paint()
        ..color = Colors.white
        ..strokeWidth = 10.0
        ..style = PaintingStyle.stroke;

      canvas.drawCircle(posicionUsuarioCanvas, 80.0, paintAura);
      canvas.drawCircle(posicionUsuarioCanvas, 35.0, paintDot);
      canvas.drawCircle(posicionUsuarioCanvas, 35.0, paintBorder);

      final textStyleGps = poppins(
          color: Colors.white, fontSize: 35.0, fontWeight: FontWeight.bold);
      final textPainterGps = TextPainter(
          text: TextSpan(text: "Estás aquí", style: textStyleGps),
          textDirection: TextDirection.ltr);
      textPainterGps.layout();

      final Offset textoPosGps =
          Offset(posicionUsuarioCanvas.dx, posicionUsuarioCanvas.dy - 110);
      final rectGps = Rect.fromCenter(
          center: textoPosGps,
          width: textPainterGps.width + 40,
          height: textPainterGps.height + 20);

      canvas.drawRRect(
          RRect.fromRectAndRadius(rectGps, const Radius.circular(15)),
          Paint()..color = const Color(0xFF2563EB).withValues(alpha: 0.9));
      textPainterGps.paint(
          canvas,
          Offset(textoPosGps.dx - textPainterGps.width / 2,
              textoPosGps.dy - textPainterGps.height / 2));
    }
  }

  @override
  bool shouldRepaint(covariant RoutePainter oldDelegate) {
    // Antes comparaba `ruta` por identidad (`!=` en una List es identidad
    // salvo que la lista sobrecargue `==`), así que casi siempre daba
    // `true` -incluso cuando el contenido era exactamente el mismo, por
    // ejemplo tras un rebuild que reconstruye la misma lista de nodos-.
    // `listEquals` compara elemento por elemento.
    return oldDelegate.zoomScale != zoomScale ||
        !listEquals(oldDelegate.ruta, ruta) ||
        oldDelegate.ubicacionGPS != ubicacionGPS;
  }
}
