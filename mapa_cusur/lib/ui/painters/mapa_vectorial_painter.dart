import 'package:flutter/material.dart';

import '../../models/mapa_vectorial.dart';
import '../mapa/colores_mapa_vectorial.dart';

/// Los `Path` de la capa estática del mapa vectorial, en metros. Se
/// construyen una sola vez al cargar `campus_vector.json`, no en cada
/// `paint`.
class GeometriaMapaVectorial {
  final MapaVectorial mapa;

  final Path campus;
  final Path areasVerdes;

  /// Zonas deportivas y canchas de fútbol (el césped).
  final Path cespedDeportivo;

  /// Líneas medias y círculos centrales de las canchas de fútbol.
  final Path lineasFutbol;

  /// Vialidades agrupadas por ancho (las de un mismo ancho se dibujan con
  /// un solo trazo; así las calles que se tocan se ven unidas).
  final Map<double, Path> vialidadesPorAncho;
  final Map<double, Path> callesPorAncho;
  final Map<double, Path> serviciosPorAncho;

  final List<({Path relleno, Path borde})> techadas;
  final List<({Path contorno, Path sombra, bool esTecho})> edificios;
  final List<({Path poligono, TipoCancha tipo})> canchas;
  final Path lineasCanchas;

  /// Círculos y semicírculos rojos de las canchas.
  final Path marcasCanchas;

  GeometriaMapaVectorial._({
    required this.mapa,
    required this.campus,
    required this.areasVerdes,
    required this.cespedDeportivo,
    required this.lineasFutbol,
    required this.vialidadesPorAncho,
    required this.callesPorAncho,
    required this.serviciosPorAncho,
    required this.techadas,
    required this.edificios,
    required this.canchas,
    required this.lineasCanchas,
    required this.marcasCanchas,
  });

  /// Desplazamiento de la sombra de los edificios, en metros.
  static const Offset _desfaseSombra = Offset(1.4, 1.4);

  factory GeometriaMapaVectorial(MapaVectorial mapa) {
    final cespedDeportivo = Path();
    final lineasFutbol = Path();
    for (final zona in mapa.zonasDeportivas) {
      cespedDeportivo.addPath(_poligono(zona.poligono), Offset.zero);
    }
    for (final cancha in mapa.canchasFutbol) {
      cespedDeportivo.addPath(_poligono(cancha.poligono), Offset.zero);
      lineasFutbol
        ..addPath(_polilinea(cancha.lineaMedia), Offset.zero)
        ..addOval(Rect.fromCircle(
            center: cancha.circuloCentral.centro,
            radius: cancha.circuloCentral.radio));
    }

    final vialidadesPorAncho = <double, Path>{};
    final callesPorAncho = <double, Path>{};
    final serviciosPorAncho = <double, Path>{};
    for (final v in mapa.vialidades) {
      final linea = _polilinea(v.linea);
      vialidadesPorAncho.putIfAbsent(v.ancho, Path.new).addPath(linea, Offset.zero);
      final relleno =
          v.tipo == TipoVialidad.calle ? callesPorAncho : serviciosPorAncho;
      relleno.putIfAbsent(v.ancho, Path.new).addPath(linea, Offset.zero);
    }

    final techadas = <({Path relleno, Path borde})>[];
    final edificios = <({Path contorno, Path sombra, bool esTecho})>[];
    for (final e in mapa.edificios) {
      final contorno = _anillos(e.anillos);
      if (e.tipo == TipoEdificio.techada) {
        techadas.add((relleno: contorno, borde: _discontinua(contorno, 3, 2)));
      } else {
        edificios.add((
          contorno: contorno,
          sombra: contorno.shift(_desfaseSombra),
          esTecho: e.tipo == TipoEdificio.techo,
        ));
      }
    }

    final canchas = <({Path poligono, TipoCancha tipo})>[];
    final lineasCanchas = Path();
    final marcasCanchas = Path();
    for (final c in mapa.canchas) {
      canchas.add((poligono: _poligono(c.poligono), tipo: c.tipo));
      for (final linea in c.lineas) {
        lineasCanchas.addPath(_polilinea(linea), Offset.zero);
      }
      for (final circulo in c.circulos) {
        marcasCanchas.addOval(
            Rect.fromCircle(center: circulo.centro, radius: circulo.radio));
      }
      for (final arco in c.semicirculos) {
        // El arco viene abierto; se cierra para rellenarlo, como el
        // `polygon` del HTML.
        marcasCanchas.addPath(_poligono(arco), Offset.zero);
      }
    }

    return GeometriaMapaVectorial._(
      mapa: mapa,
      campus: _poligono(mapa.campus),
      areasVerdes: mapa.areasVerdes.fold(
          Path(), (path, p) => path..addPath(_poligono(p), Offset.zero)),
      cespedDeportivo: cespedDeportivo,
      lineasFutbol: lineasFutbol,
      vialidadesPorAncho: vialidadesPorAncho,
      callesPorAncho: callesPorAncho,
      serviciosPorAncho: serviciosPorAncho,
      techadas: techadas,
      edificios: edificios,
      canchas: canchas,
      lineasCanchas: lineasCanchas,
      marcasCanchas: marcasCanchas,
    );
  }

  static Path _polilinea(List<Offset> puntos) {
    final path = Path();
    if (puntos.isEmpty) return path;
    path.moveTo(puntos.first.dx, puntos.first.dy);
    for (final p in puntos.skip(1)) {
      path.lineTo(p.dx, p.dy);
    }
    return path;
  }

  static Path _poligono(List<Offset> puntos) => _polilinea(puntos)..close();

  /// El primer anillo es el contorno y los demás son huecos: con
  /// `evenOdd`, los huecos quedan sin relleno sin importar su sentido.
  static Path _anillos(List<List<Offset>> anillos) {
    final path = Path()..fillType = PathFillType.evenOdd;
    for (final anillo in anillos) {
      path.addPath(_poligono(anillo), Offset.zero);
    }
    return path;
  }

  /// [path] como trazo discontinuo de [trazo] metros con huecos de [hueco]
  /// metros (`stroke-dasharray` del HTML; el patrón empieza de nuevo en
  /// cada contorno, como en SVG).
  static Path _discontinua(Path path, double trazo, double hueco) {
    final resultado = Path();
    for (final metrica in path.computeMetrics()) {
      for (var d = 0.0; d < metrica.length; d += trazo + hueco) {
        resultado.addPath(
            metrica.extractPath(d, d + trazo), Offset.zero);
      }
    }
    return resultado;
  }
}

/// Dibuja la capa estática del mapa vectorial (terreno, áreas verdes,
/// canchas, calles y edificios) con el orden de capas y los colores de
/// `docs/mapa_vectorial/mapa-vectorial-referencia.html`.
///
/// Todo se dibuja en metros (`canvas.scale(escala)` y luego el origen en
/// la esquina de `meta.limites`), así que los grosores son los del HTML.
/// No depende del zoom: solo se repinta si cambian los datos, y va dentro
/// de un `RepaintBoundary`.
class MapaVectorialPainter extends CustomPainter {
  final GeometriaMapaVectorial geometria;

  /// Unidades de lienzo por metro (`kEscalaVectorial`).
  final double escala;

  MapaVectorialPainter({required this.geometria, required this.escala});

  static Paint _relleno(Color color) => Paint()..color = color;

  static Paint _trazo(Color color, double ancho) => Paint()
    ..color = color
    ..style = PaintingStyle.stroke
    ..strokeWidth = ancho;

  static Paint _trazoRedondo(Color color, double ancho) =>
      _trazo(color, ancho)
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round;

  @override
  void paint(Canvas canvas, Size size) {
    final g = geometria;
    final meta = g.mapa.meta;

    canvas.save();
    canvas.scale(escala);
    canvas.translate(-meta.minX, -meta.minY);

    // 1. Terreno del campus.
    canvas.drawPath(g.campus, _relleno(ColoresMapaVectorial.campus));
    canvas.drawPath(g.campus, _trazo(ColoresMapaVectorial.bordeCampus, 1));

    // 2. Áreas verdes.
    canvas.drawPath(g.areasVerdes, _relleno(ColoresMapaVectorial.areaVerde));

    // 3. Zonas deportivas y canchas de fútbol.
    canvas.drawPath(g.cespedDeportivo, _relleno(ColoresMapaVectorial.cesped));
    final lineaCesped = _trazo(ColoresMapaVectorial.lineaCesped, 1.2);
    canvas.drawPath(g.cespedDeportivo, lineaCesped);
    canvas.drawPath(g.lineasFutbol, lineaCesped);

    // 4 y 5. Vialidades en dos pasadas: primero todos los bordes y luego
    // todos los rellenos, para que las calles se vean unidas.
    g.vialidadesPorAncho.forEach((ancho, path) => canvas.drawPath(
        path, _trazoRedondo(ColoresMapaVectorial.bordeVialidad, ancho + 2)));
    g.serviciosPorAncho.forEach((ancho, path) => canvas.drawPath(
        path, _trazoRedondo(ColoresMapaVectorial.servicio, ancho)));
    g.callesPorAncho.forEach((ancho, path) => canvas.drawPath(
        path, _trazoRedondo(ColoresMapaVectorial.calle, ancho)));

    // 6. Zonas techadas.
    for (final t in g.techadas) {
      canvas.drawPath(t.relleno, _relleno(ColoresMapaVectorial.cesped));
      canvas.drawPath(t.borde, _trazo(ColoresMapaVectorial.bordeEdificio, 1));
    }

    // 7. Edificios y techos, cada uno con su sombra.
    for (final e in g.edificios) {
      canvas.drawPath(
          e.sombra,
          _relleno(ColoresMapaVectorial.bordeEdificio
              .withValues(alpha: e.esTecho ? 0.25 : 0.55)));
      final double opacidad = e.esTecho ? 0.55 : 1.0;
      canvas.drawPath(
          e.contorno,
          _relleno(
              ColoresMapaVectorial.edificio.withValues(alpha: opacidad)));
      canvas.drawPath(
          e.contorno,
          _trazo(ColoresMapaVectorial.bordeEdificio.withValues(alpha: opacidad),
              0.6));
    }

    // 8. Canchas.
    final bordeCancha = _trazo(ColoresMapaVectorial.lineaCancha, 0.6);
    for (final c in g.canchas) {
      canvas.drawPath(c.poligono, _relleno(_colorCancha(c.tipo)));
      canvas.drawPath(c.poligono, bordeCancha);
    }
    canvas.drawPath(
        g.lineasCanchas, _trazo(ColoresMapaVectorial.lineaCancha, 0.5));
    canvas.drawPath(
        g.marcasCanchas, _relleno(ColoresMapaVectorial.marcaCancha));
    canvas.drawPath(
        g.marcasCanchas, _trazo(ColoresMapaVectorial.lineaCancha, 0.4));

    canvas.restore();
  }

  static Color _colorCancha(TipoCancha tipo) => switch (tipo) {
        TipoCancha.tenisVerde => ColoresMapaVectorial.tenisVerde,
        TipoCancha.tenisAzul => ColoresMapaVectorial.tenisAzul,
        TipoCancha.baloncesto => ColoresMapaVectorial.baloncesto,
      };

  @override
  bool shouldRepaint(covariant MapaVectorialPainter oldDelegate) =>
      !identical(oldDelegate.geometria, geometria) ||
      oldDelegate.escala != escala;
}
