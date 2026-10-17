import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../domain/proyeccion_local.dart';
import '../../models/mapa_vectorial.dart';
import '../mapa/colores_mapa_vectorial.dart';
import '../theme/poppins.dart';

/// Íconos de Material (variante *rounded*) por el nombre que usa
/// `campus_vector.json`. Es un mapa `const` para que el tree-shaking de
/// íconos siga funcionando: solo se empaquetan los que aparecen aquí.
///
/// `door_front` no existe en Flutter con ese nombre: su ícono es
/// `door_front_door` (el mismo trazo que usa la referencia HTML).
const Map<String, IconData> kIconosMapa = {
  'local_library': Icons.local_library_rounded,
  'local_cafe': Icons.local_cafe_rounded,
  'sports_soccer': Icons.sports_soccer_rounded,
  'pool': Icons.pool_rounded,
  'theater_comedy': Icons.theater_comedy_rounded,
  'pets': Icons.pets_rounded,
  'account_balance': Icons.account_balance_rounded,
  'science': Icons.science_rounded,
  'engineering': Icons.engineering_rounded,
  'gavel': Icons.gavel_rounded,
  'cell_tower': Icons.cell_tower_rounded,
  'medical_services': Icons.medical_services_rounded,
  'newspaper': Icons.newspaper_rounded,
  'code': Icons.code_rounded,
  'memory': Icons.memory_rounded,
  'school': Icons.school_rounded,
  'fitness_center': Icons.fitness_center_rounded,
  'park': Icons.park_rounded,
  'sports_tennis': Icons.sports_tennis_rounded,
  'sports_basketball': Icons.sports_basketball_rounded,
  'door_front': Icons.door_front_door_rounded,
  'directions_car': Icons.directions_car_rounded,
};

/// Zoom del `InteractiveViewer` (1 = mapa completo) desde el que se ven
/// los textos largos: nombres, subtítulos, lugares, estacionamientos y
/// zonas deportivas.
const double kZoomDetalle = 1.8;

/// Radio en pantalla de una insignia con zoom ×1; crece en proporción al
/// zoom, como si fuera parte del mapa (11 px con ×2).
const double kRadioInsigniaZoom1 = 5.5;

/// Tope del radio en pantalla, para que con zoom alto (×5 a ×8) las
/// insignias no se vuelvan enormes.
const double kRadioInsigniaMaximo = 22;

/// Separación en pantalla entre el borde de una insignia y el centro del
/// texto que va debajo de ella.
const double kSeparacionTextoInsignia = 8;

/// Radio en pantalla de una insignia con [zoom]. [tamano] es 1.25 en las
/// entradas, que conservan esa proporción sobre las demás (también por
/// encima del tope).
double radioInsignia(double zoom, {double tamano = 1}) =>
    math.min(kRadioInsigniaZoom1 * zoom, kRadioInsigniaMaximo) * tamano;

/// Radio con el que se maquetan las insignias (el de zoom ×2); al
/// dibujarlas se escalan a [radioInsignia].
const double _radioMaquetado = 11;

/// Una insignia: círculo con un ícono que crece con el zoom hasta un tope.
class _Insignia {
  final Offset ancla; // metros
  final double tamano; // 1 normal; 1.25 en las entradas
  final Color fondo;
  final Color borde;
  final TextPainter icono;
  final bool soloDetalle;

  /// Si el botón de íconos la oculta: todas menos las de las entradas.
  final bool ocultable;

  _Insignia({
    required this.ancla,
    required this.tamano,
    required this.fondo,
    required this.borde,
    required this.icono,
    required this.soloDetalle,
    required this.ocultable,
  });
}

/// Una línea de texto centrada en `ancla + (0, dy)`, de tamaño constante
/// en pantalla, con halo opcional.
class _Texto {
  final Offset ancla; // metros
  final double dy; // píxeles de pantalla hacia abajo (si no hay insignia)
  final double anguloGrados;
  final TextPainter relleno;
  final TextPainter? halo;
  final bool soloDetalle;

  /// La insignia bajo la que va el texto, si la hay: entonces su
  /// separación depende del radio actual de la insignia, no de [dy].
  final _Insignia? insignia;

  /// Número de línea (desde 0) de un texto de [lineas] líneas y la
  /// distancia en pantalla entre líneas.
  final int linea;
  final int lineas;
  final double interlineado;

  _Texto({
    required this.ancla,
    required this.dy,
    required this.relleno,
    required this.halo,
    required this.soloDetalle,
    this.anguloGrados = 0,
    this.insignia,
    this.linea = 0,
    this.lineas = 1,
    this.interlineado = 0,
  });

  /// Desplazamiento vertical en pantalla del centro del texto con [zoom].
  /// Si su insignia está oculta, el texto (todas sus líneas juntas) queda
  /// centrado donde estaba la insignia.
  double dyCon(double zoom, {required bool mostrarIconos}) {
    final i = insignia;
    if (i == null) return dy;
    if (!mostrarIconos && i.ocultable) {
      return (linea - (lineas - 1) / 2) * interlineado;
    }
    return radioInsignia(zoom, tamano: i.tamano) +
        kSeparacionTextoInsignia +
        linea * interlineado;
  }
}

/// Las insignias y los textos del mapa vectorial, ya maquetados en píxeles
/// de pantalla. Se construyen una sola vez al cargar los datos: al hacer
/// zoom solo cambia la escala con que se dibujan, no su maquetación.
class EtiquetasMapaVectorial {
  final MetaMapaVectorial meta;
  final List<_Insignia> _insignias;
  final List<_Texto> _textos;

  EtiquetasMapaVectorial._(this.meta, this._insignias, this._textos);

  int get totalInsignias => _insignias.length;
  int get totalTextos => _textos.length;

  /// Cuántas insignias y textos se dibujan con [zoom].
  ({int insignias, int textos}) visiblesCon(double zoom) => (
        insignias: _insignias.where((i) => _visible(i.soloDetalle, zoom)).length,
        textos: _textos.where((t) => _visible(t.soloDetalle, zoom)).length,
      );

  /// Textos (sin repetir) que se dibujan con [zoom].
  Set<String> textosCon(double zoom) => {
        for (final t in _textos)
          if (_visible(t.soloDetalle, zoom)) t.relleno.plainText,
      };

  static bool _visible(bool soloDetalle, double zoom) =>
      !soloDetalle || zoom >= kZoomDetalle;

  /// Desplazamiento vertical en pantalla del primer texto igual a
  /// [contenido] con [zoom]; `null` si no existe.
  @visibleForTesting
  double? desplazamientoDe(String contenido,
      {required double zoom, bool mostrarIconos = true}) {
    for (final t in _textos) {
      if (t.relleno.plainText == contenido) {
        return t.dyCon(zoom, mostrarIconos: mostrarIconos);
      }
    }
    return null;
  }

  factory EtiquetasMapaVectorial(MapaVectorial mapa) {
    final insignias = <_Insignia>[];
    final textos = <_Texto>[];
    // La insignia de cada edificio, lugar, entrada y estacionamiento, para
    // colgar de ella el texto que va debajo.
    final insigniaDe = Map<Object, _Insignia>.identity();

    void insignia(Object elemento, Offset ancla, String nombreIcono,
        {bool soloDetalle = false, bool esEntrada = false}) {
      final icono = kIconosMapa[nombreIcono];
      if (icono == null) {
        debugPrint('Ícono desconocido en campus_vector.json: $nombreIcono');
        return;
      }
      final tamano = esEntrada ? 1.25 : 1.0;
      insignias.add(insigniaDe[elemento] = _Insignia(
        ancla: ancla,
        tamano: tamano,
        fondo: esEntrada
            ? ColoresMapaVectorial.entrada
            : ColoresMapaVectorial.insignia,
        borde: esEntrada
            ? ColoresMapaVectorial.halo
            : ColoresMapaVectorial.bordeEdificio,
        icono: _icono(
            icono,
            16 * tamano,
            esEntrada
                ? ColoresMapaVectorial.iconoEntrada
                : ColoresMapaVectorial.iconoInsignia),
        soloDetalle: soloDetalle,
        ocultable: !esEntrada,
      ));
    }

    void texto(
      Offset ancla,
      String contenido, {
      required double tamano,
      required FontWeight peso,
      required Color color,
      double dy = 0,
      Color? colorHalo,
      double anchoHalo = 3,
      bool soloDetalle = false,
      double anguloGrados = 0,
      Object? debajoDe,
      int linea = 0,
      int lineas = 1,
      double interlineado = 0,
    }) {
      TextPainter maquetar(TextStyle estilo) => TextPainter(
            text: TextSpan(text: contenido, style: estilo),
            textDirection: TextDirection.ltr,
          )..layout();

      textos.add(_Texto(
        ancla: ancla,
        dy: dy,
        anguloGrados: anguloGrados,
        relleno: maquetar(
            poppins(fontSize: tamano, fontWeight: peso, color: color)),
        halo: colorHalo == null
            ? null
            : maquetar(poppins(fontSize: tamano, fontWeight: peso).copyWith(
                foreground: Paint()
                  ..style = PaintingStyle.stroke
                  ..strokeWidth = anchoHalo
                  ..strokeJoin = StrokeJoin.round
                  ..color = colorHalo)),
        soloDetalle: soloDetalle,
        insignia: debajoDe == null ? null : insigniaDe[debajoDe],
        linea: linea,
        lineas: lineas,
        interlineado: interlineado,
      ));
    }

    // --- Insignias (todas debajo de los textos, como en la referencia) ---
    for (final e in mapa.edificios) {
      if (e.icono != null) insignia(e, e.etiqueta, e.icono!);
    }
    for (final c in mapa.canchasFutbol) {
      if (c.icono != null && c.iconoPos != null) {
        insignia(c, c.iconoPos!, c.icono!);
      }
    }
    for (final c in mapa.canchas) {
      if (c.icono != null && c.iconoPos != null) {
        insignia(c, c.iconoPos!, c.icono!);
      }
    }
    for (final l in mapa.lugares) {
      insignia(l, l.pos, l.icono, soloDetalle: true);
    }
    for (final e in mapa.entradas) {
      insignia(e, e.pos, 'door_front', esEntrada: true);
    }
    for (final e in mapa.estacionamientos) {
      insignia(e, e.pos, 'directions_car');
    }

    // --- Textos ---
    for (final e in mapa.edificios) {
      if (e.letra != null) {
        texto(e.etiqueta, e.letra!,
            tamano: 15,
            peso: FontWeight.w600,
            color: ColoresMapaVectorial.textoEdificio);
      }
      if (e.texto != null) {
        final techada = e.tipo == TipoEdificio.techada;
        texto(e.etiqueta, e.texto!,
            tamano: 11.5,
            peso: FontWeight.w500,
            color: techada
                ? ColoresMapaVectorial.tinta
                : ColoresMapaVectorial.textoEdificio,
            colorHalo: techada ? ColoresMapaVectorial.halo : null,
            // Debajo de la letra, o de la insignia si tiene ícono.
            dy: e.letra != null ? 14 : 0,
            debajoDe: e.letra == null && e.icono != null ? e : null,
            soloDetalle: true);
      }
      final subtitulo = e.subtitulo ?? const <String>[];
      for (var k = 0; k < subtitulo.length; k++) {
        texto(e.etiqueta, subtitulo[k],
            tamano: 9.5,
            peso: FontWeight.w500,
            color: ColoresMapaVectorial.textoEdificio,
            dy: 13.0 + 11 * k,
            soloDetalle: true);
      }
    }
    for (final l in mapa.lugares) {
      for (var k = 0; k < l.lineas.length; k++) {
        texto(l.pos, l.lineas[k],
            tamano: 10.5,
            peso: l.enAreaVerde ? FontWeight.w600 : FontWeight.w500,
            color: l.enAreaVerde
                ? ColoresMapaVectorial.tinta
                : ColoresMapaVectorial.textoEdificio,
            colorHalo: l.enAreaVerde
                ? ColoresMapaVectorial.halo
                : ColoresMapaVectorial.edificio,
            debajoDe: l,
            linea: k,
            lineas: l.lineas.length,
            interlineado: 1.15 * 10.5,
            soloDetalle: true);
      }
    }
    for (final e in mapa.entradas) {
      texto(e.pos, e.nombre,
          tamano: 12.5,
          peso: FontWeight.w600,
          color: ColoresMapaVectorial.entrada,
          colorHalo: ColoresMapaVectorial.halo,
          anchoHalo: 3.5,
          debajoDe: e);
    }
    for (final e in mapa.estacionamientos) {
      texto(e.pos, e.nombre,
          tamano: 11.5,
          peso: FontWeight.w500,
          color: ColoresMapaVectorial.tinta,
          colorHalo: ColoresMapaVectorial.halo,
          debajoDe: e,
          soloDetalle: true);
    }
    void nombreDeZona(String? nombre, Offset posicion) {
      // Una zona fuera de meta.limites (la Unidad Deportiva, del otro
      // lado de Prolongación Colón) es solo contexto en la orilla del
      // mapa: su nombre no se dibuja.
      if (nombre == null || !_dentroDeLimites(mapa.meta, posicion)) return;
      texto(posicion, nombre,
          tamano: 11.5,
          peso: FontWeight.w500,
          color: ColoresMapaVectorial.tinta,
          soloDetalle: true);
    }

    for (final z in mapa.zonasDeportivas) {
      nombreDeZona(z.nombre, z.etiqueta);
    }
    for (final c in mapa.canchasFutbol) {
      nombreDeZona(c.nombre, _centro(c.poligono));
    }
    for (final c in mapa.etiquetasCalles) {
      texto(c.pos, c.texto,
          tamano: 11,
          peso: FontWeight.w400,
          color: ColoresMapaVectorial.tenue,
          anguloGrados: c.anguloGrados);
    }

    return EtiquetasMapaVectorial._(mapa.meta, insignias, textos);
  }

  static TextPainter _icono(IconData icono, double tamano, Color color) =>
      TextPainter(
        text: TextSpan(
          text: String.fromCharCode(icono.codePoint),
          style: TextStyle(
            fontFamily: icono.fontFamily,
            package: icono.fontPackage,
            fontFamilyFallback: icono.fontFamilyFallback,
            fontSize: tamano,
            height: 1,
            color: color,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();

  /// Promedio de los vértices, sin contar el punto que cierra el polígono.
  static Offset _centro(List<Offset> poligono) {
    final vertices = poligono.length > 1 && poligono.first == poligono.last
        ? poligono.sublist(0, poligono.length - 1)
        : poligono;
    return vertices.fold(Offset.zero, (s, p) => s + p) / vertices.length.toDouble();
  }

  static bool _dentroDeLimites(MetaMapaVectorial meta, Offset p) =>
      p.dx >= meta.minX &&
      p.dx <= meta.maxX &&
      p.dy >= meta.minY &&
      p.dy <= meta.maxY;

  void dispose() {
    for (final i in _insignias) {
      i.icono.dispose();
    }
    for (final t in _textos) {
      t.relleno.dispose();
      t.halo?.dispose();
    }
  }
}

/// Dibuja las insignias y los textos del mapa vectorial. Los textos tienen
/// tamaño constante en pantalla: tamaño en lienzo = tamaño en pantalla ÷
/// [pantallaPorLienzo] (la escala del `FittedBox` por la del
/// `InteractiveViewer`). Las insignias crecen con el zoom hasta un tope
/// ([radioInsignia]). Por eso, a diferencia de la capa estática, se
/// repinta con el zoom.
class EtiquetasMapaPainter extends CustomPainter {
  final EtiquetasMapaVectorial etiquetas;
  final ProyeccionLocal proyeccion;

  /// Píxeles de pantalla por unidad de lienzo.
  final double pantallaPorLienzo;

  /// Escala del `InteractiveViewer` (1 = mapa completo); decide qué
  /// textos se ven ([kZoomDetalle]).
  final double zoom;

  /// Con `false` no se dibujan las insignias de edificios, canchas,
  /// lugares y estacionamientos (las de las entradas, sí), y sus textos
  /// quedan centrados donde estaba la insignia.
  final bool mostrarIconos;

  EtiquetasMapaPainter({
    required this.etiquetas,
    required this.proyeccion,
    required this.pantallaPorLienzo,
    required this.zoom,
    this.mostrarIconos = true,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (pantallaPorLienzo <= 0) return;
    final double k = 1 / pantallaPorLienzo;

    final fondo = Paint();
    final borde = Paint()..style = PaintingStyle.stroke;

    for (final i in etiquetas._insignias) {
      if (!EtiquetasMapaVectorial._visible(i.soloDetalle, zoom)) continue;
      if (!mostrarIconos && i.ocultable) continue;
      final ancla = _aLienzo(i.ancla);
      canvas.save();
      canvas.translate(ancla.dx, ancla.dy);
      // La insignia está maquetada con radio 11 (16 px de ícono, 1 px de
      // borde); se escala entera, borde incluido, al radio de este zoom.
      canvas.scale(k * radioInsignia(zoom) / _radioMaquetado);
      final double radio = _radioMaquetado * i.tamano;
      canvas.drawCircle(Offset.zero, radio, fondo..color = i.fondo);
      canvas.drawCircle(
          Offset.zero,
          radio,
          borde
            ..color = i.borde
            ..strokeWidth = 1 * i.tamano);
      i.icono.paint(
          canvas, Offset(-i.icono.width / 2, -i.icono.height / 2));
      canvas.restore();
    }

    for (final t in etiquetas._textos) {
      if (!EtiquetasMapaVectorial._visible(t.soloDetalle, zoom)) continue;
      final ancla = _aLienzo(t.ancla);
      canvas.save();
      canvas.translate(ancla.dx, ancla.dy);
      canvas.scale(k);
      if (t.anguloGrados != 0) canvas.rotate(t.anguloGrados * math.pi / 180);
      final esquina =
          Offset(-t.relleno.width / 2,
              t.dyCon(zoom, mostrarIconos: mostrarIconos) -
                  t.relleno.height / 2);
      t.halo?.paint(canvas, esquina);
      t.relleno.paint(canvas, esquina);
      canvas.restore();
    }
  }

  Offset _aLienzo(Offset metros) =>
      proyeccion.localALienzo(metros.dx, metros.dy);

  @override
  bool shouldRepaint(covariant EtiquetasMapaPainter oldDelegate) =>
      !identical(oldDelegate.etiquetas, etiquetas) ||
      oldDelegate.pantallaPorLienzo != pantallaPorLienzo ||
      oldDelegate.zoom != zoom ||
      oldDelegate.mostrarIconos != mostrarIconos ||
      oldDelegate.proyeccion.escala != proyeccion.escala;
}
