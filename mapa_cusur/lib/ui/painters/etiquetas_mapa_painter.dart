import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../domain/polo_inaccesibilidad.dart';
import '../../domain/proyeccion_local.dart';
import '../../models/mapa_vectorial.dart';
import '../mapa/colores_mapa_vectorial.dart';
import '../theme/poppins.dart';
import 'mapa_vectorial_painter.dart';

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

/// Píxeles de pantalla por metro desde los que se ven los textos largos
/// (nombres, subtítulos, lugares, estacionamientos y zonas deportivas) y
/// las insignias de los lugares. Es lo que daba el zoom ×1.8 en la caja de
/// la referencia HTML; medido así, y no como zoom, aparecen con el mismo
/// detalle en cualquier tamaño de pantalla (en un panel de 412 × 360,
/// desde ×4).
const double kDetallePxPorMetro = 3.1;

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

/// Tamaño máximo en pantalla de la letra de un edificio.
const double kTamanoLetra = 15;

/// La letra mide a lo más este factor por el radio (en pantalla) del
/// círculo más grande que cabe en su edificio...
const double kFactorRadioLetra = 1.3;

/// ...y si así queda por debajo de este tamaño, no se dibuja a ese zoom.
const double kTamanoMinimoLetra = 7;

/// Margen en pantalla alrededor de cada etiqueta para la detección de
/// colisiones.
const double kMargenColision = 4;

/// Fracciones de la longitud de la calle donde se prueba su nombre si no
/// cabe en la posición del JSON, en este orden.
const List<double> kFraccionesAlternativasCalle = [0.3, 0.7, 0.2, 0.8];

/// Prioridad de un texto en la detección de colisiones (de mayor a menor:
/// entradas, letras de edificio, insignias, nombres largos y, al final,
/// nombres de calles).
enum _Clase { entrada, letra, largo }

/// Una insignia: círculo con un ícono que crece con el zoom hasta un tope.
class _Insignia {
  final String nombre; // para depurar y para las pruebas
  final Offset ancla; // metros
  final double tamano; // 1 normal; 1.25 en las entradas
  final Color fondo;
  final Color borde;
  final TextPainter icono;
  final bool soloDetalle;

  /// Si el botón de íconos la oculta: todas menos las de las entradas.
  final bool ocultable;

  _Insignia({
    required this.nombre,
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
  final _Clase clase;

  /// Solo en las letras de edificio: radio en metros del círculo más
  /// grande que cabe en el edificio (con centro en [ancla]), del que
  /// depende el tamaño de la letra.
  final double? radioPolo;

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
    required this.clase,
    this.radioPolo,
    this.anguloGrados = 0,
    this.insignia,
    this.linea = 0,
    this.lineas = 1,
    this.interlineado = 0,
  });

  /// Factor por el que se escala el texto maquetado con
  /// [pantallaPorMetro] píxeles de pantalla por metro: 1 salvo en las
  /// letras de edificio, que miden min(15 px, 1.3 × radio del círculo en
  /// pantalla). 0 si la letra quedaría por debajo de 7 px (no se dibuja).
  double factorDeTamano(double pantallaPorMetro) {
    final radio = radioPolo;
    if (radio == null) return 1;
    final tamano =
        math.min(kTamanoLetra, kFactorRadioLetra * radio * pantallaPorMetro);
    return tamano < kTamanoMinimoLetra ? 0 : tamano / kTamanoLetra;
  }

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

/// Una posición posible para el nombre de una calle.
class _PosicionCalle {
  final Offset ancla; // metros
  final double anguloGrados;

  const _PosicionCalle(this.ancla, this.anguloGrados);
}

/// El nombre de una calle y las posiciones donde puede ir: primero la del
/// JSON y luego puntos sobre la propia calle
/// ([kFraccionesAlternativasCalle]).
class _Calle {
  final TextPainter relleno;
  final List<_PosicionCalle> posiciones;

  _Calle(this.relleno, this.posiciones);
}

/// Dónde quedan las etiquetas en pantalla para una escala, un zoom y el
/// estado del botón de íconos: el rectángulo de cada elemento dibujado
/// (con su margen) y la posición elegida para cada nombre de calle que
/// cabe. Las coordenadas son de lienzo multiplicadas por la escala de
/// pantalla, así que la distancia entre dos elementos es la de la
/// pantalla (desplazar el mapa no cambia nada).
class ColocacionEtiquetas {
  final List<({String nombre, Rect rect})> ocupados;
  final List<({String texto, Offset ancla, double anguloGrados, Rect rect})>
      calles;

  const ColocacionEtiquetas(this.ocupados, this.calles);
}

/// Las insignias y los textos del mapa vectorial, ya maquetados en píxeles
/// de pantalla. Se construyen una sola vez al cargar los datos: al hacer
/// zoom solo cambia la escala con que se dibujan, no su maquetación.
class EtiquetasMapaVectorial {
  final MetaMapaVectorial meta;
  final List<_Insignia> _insignias;
  final List<_Texto> _textos;
  final List<_Calle> _calles;

  EtiquetasMapaVectorial._(
      this.meta, this._insignias, this._textos, this._calles);

  int get totalInsignias => _insignias.length;
  int get totalTextos => _textos.length;

  /// Tamaño en pantalla con que se dibuja la letra [letra] con
  /// [pantallaPorMetro] píxeles por metro; `null` si no se dibuja.
  @visibleForTesting
  Size? tamanoDeLetraEnPantalla(String letra,
      {required double pantallaPorMetro}) {
    for (final t in _textos) {
      if (t.clase != _Clase.letra || t.relleno.plainText != letra) continue;
      final f = t.factorDeTamano(pantallaPorMetro);
      return f == 0 ? null : t.relleno.size * f;
    }
    return null;
  }

  /// Cuántas insignias y textos se dibujan con [pantallaPorMetro]
  /// píxeles de pantalla por metro.
  ({int insignias, int textos}) visiblesCon(double pantallaPorMetro) => (
        insignias: _insignias
            .where((i) => _visible(i.soloDetalle, pantallaPorMetro))
            .length,
        textos: _textos
            .where((t) => _visible(t.soloDetalle, pantallaPorMetro))
            .length,
      );

  /// Textos (sin repetir) que se dibujan con [pantallaPorMetro] píxeles
  /// de pantalla por metro. Los nombres de
  /// calles siempre están en la lista, pero además solo se dibujan si caben
  /// ([colocar]).
  Set<String> textosCon(double pantallaPorMetro) => {
        for (final t in _textos)
          if (_visible(t.soloDetalle, pantallaPorMetro)) t.relleno.plainText,
        for (final c in _calles) c.relleno.plainText,
      };

  static bool _visible(bool soloDetalle, double pantallaPorMetro) =>
      !soloDetalle || pantallaPorMetro >= kDetallePxPorMetro;

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

  /// [polos]: los de `GeometriaMapaVectorial`, para no calcularlos dos
  /// veces; si no se dan, se calculan aquí.
  factory EtiquetasMapaVectorial(MapaVectorial mapa,
      {Map<Edificio, PoloDeInaccesibilidad>? polos}) {
    polos ??= GeometriaMapaVectorial.polosDeEdificios(mapa);
    final insignias = <_Insignia>[];
    final textos = <_Texto>[];
    // La insignia de cada edificio, lugar, entrada y estacionamiento, para
    // colgar de ella el texto que va debajo.
    final insigniaDe = Map<Object, _Insignia>.identity();

    void insignia(Object elemento, String nombre, Offset ancla,
        String nombreIcono,
        {bool soloDetalle = false, bool esEntrada = false}) {
      final icono = kIconosMapa[nombreIcono];
      if (icono == null) {
        debugPrint('Ícono desconocido en campus_vector.json: $nombreIcono');
        return;
      }
      final tamano = esEntrada ? 1.25 : 1.0;
      insignias.add(insigniaDe[elemento] = _Insignia(
        nombre: nombre,
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
      _Clase clase = _Clase.largo,
      double? radioPolo,
      double? altoDeLinea,
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
        relleno: maquetar(poppins(
                fontSize: tamano, fontWeight: peso, color: color)
            .copyWith(height: altoDeLinea)),
        halo: colorHalo == null
            ? null
            : maquetar(poppins(fontSize: tamano, fontWeight: peso).copyWith(
                foreground: Paint()
                  ..style = PaintingStyle.stroke
                  ..strokeWidth = anchoHalo
                  ..strokeJoin = StrokeJoin.round
                  ..color = colorHalo)),
        soloDetalle: soloDetalle,
        clase: clase,
        radioPolo: radioPolo,
        insignia: debajoDe == null ? null : insigniaDe[debajoDe],
        linea: linea,
        lineas: lineas,
        interlineado: interlineado,
      ));
    }

    // --- Insignias (todas debajo de los textos, como en la referencia) ---
    for (final e in mapa.edificios) {
      if (e.icono != null) {
        insignia(e, e.nombre ?? e.icono!, e.etiqueta, e.icono!);
      }
    }
    for (final c in mapa.canchasFutbol) {
      if (c.icono != null && c.iconoPos != null) {
        insignia(c, c.nombre ?? c.icono!, c.iconoPos!, c.icono!);
      }
    }
    for (final c in mapa.canchas) {
      if (c.icono != null && c.iconoPos != null) {
        insignia(c, c.icono!, c.iconoPos!, c.icono!);
      }
    }
    for (final l in mapa.lugares) {
      insignia(l, l.nombre, l.pos, l.icono, soloDetalle: true);
    }
    for (final e in mapa.entradas) {
      insignia(e, e.nombre, e.pos, 'door_front', esEntrada: true);
    }
    for (final e in mapa.estacionamientos) {
      insignia(e, e.nombre, e.pos, 'directions_car');
    }

    // --- Textos ---
    for (final e in mapa.edificios) {
      final polo = polos[e];
      if (e.letra != null && polo != null) {
        // En el centro del círculo más grande que cabe en el edificio (no
        // en `etiqueta`), con la caja de línea del alto de la letra para
        // que su rectángulo sea el de la letra.
        texto(polo.centro, e.letra!,
            tamano: kTamanoLetra,
            peso: FontWeight.w600,
            color: ColoresMapaVectorial.textoEdificio,
            clase: _Clase.letra,
            radioPolo: polo.radio,
            altoDeLinea: 1);
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
          debajoDe: e,
          clase: _Clase.entrada);
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
    final calles = [
      for (final c in mapa.etiquetasCalles)
        _Calle(
          TextPainter(
            text: TextSpan(
                text: c.texto,
                style: poppins(
                    fontSize: 11,
                    fontWeight: FontWeight.w400,
                    color: ColoresMapaVectorial.tenue)),
            textDirection: TextDirection.ltr,
          )..layout(),
          [
            _PosicionCalle(c.pos, c.anguloGrados),
            ..._posicionesSobreLaCalle(mapa, c.texto),
          ],
        ),
    ];

    return EtiquetasMapaVectorial._(mapa.meta, insignias, textos, calles);
  }

  /// Puntos a [kFraccionesAlternativasCalle] de la longitud de la vialidad
  /// más larga que se llama [nombre], con el ángulo del tramo en cada
  /// punto (llevado a (−90°, 90°] para que el texto no quede de cabeza).
  static List<_PosicionCalle> _posicionesSobreLaCalle(
      MapaVectorial mapa, String nombre) {
    List<Offset>? linea;
    double longitud = 0;
    for (final v in mapa.vialidades) {
      if (v.nombre != nombre) continue;
      final l = _longitud(v.linea);
      if (l > longitud) {
        longitud = l;
        linea = v.linea;
      }
    }
    if (linea == null || longitud == 0) return const [];

    return [
      for (final fraccion in kFraccionesAlternativasCalle)
        _puntoALo(linea, fraccion * longitud),
    ];
  }

  static double _longitud(List<Offset> linea) {
    var total = 0.0;
    for (var i = 1; i < linea.length; i++) {
      total += (linea[i] - linea[i - 1]).distance;
    }
    return total;
  }

  /// El punto a [distancia] metros del inicio de [linea] y el ángulo del
  /// tramo donde cae.
  static _PosicionCalle _puntoALo(List<Offset> linea, double distancia) {
    var recorrido = 0.0;
    for (var i = 1; i < linea.length; i++) {
      final tramo = linea[i] - linea[i - 1];
      final largo = tramo.distance;
      if (largo == 0) continue;
      if (recorrido + largo >= distancia || i == linea.length - 1) {
        final t = ((distancia - recorrido) / largo).clamp(0.0, 1.0);
        var angulo = math.atan2(tramo.dy, tramo.dx) * 180 / math.pi;
        if (angulo > 90) angulo -= 180;
        if (angulo <= -90) angulo += 180;
        return _PosicionCalle(linea[i - 1] + tramo * t, angulo);
      }
      recorrido += largo;
    }
    return _PosicionCalle(linea.first, 0);
  }

  // Última colocación calculada y con qué se calculó: mientras no cambien
  // la escala, el zoom ni el botón de íconos (por ejemplo, al desplazar el
  // mapa o con cada lectura de GPS), no se vuelve a calcular.
  ColocacionEtiquetas? _colocacion;
  (double, double, bool, double)? _claveColocacion;

  /// Coloca las etiquetas en pantalla (ver [ColocacionEtiquetas]). Las
  /// entradas, las letras, las insignias y los nombres largos se registran
  /// tal como se dibujan; cada nombre de calle va en la primera de sus
  /// posiciones que no choque con nada de lo ya registrado, o no se
  /// dibuja.
  ColocacionEtiquetas colocar({
    required ProyeccionLocal proyeccion,
    required double pantallaPorLienzo,
    required double zoom,
    required bool mostrarIconos,
  }) {
    final clave = (pantallaPorLienzo, zoom, mostrarIconos, proyeccion.escala);
    final previa = _colocacion;
    if (previa != null && _claveColocacion == clave) return previa;

    Offset enPantalla(Offset metros) =>
        proyeccion.localALienzo(metros.dx, metros.dy) * pantallaPorLienzo;
    final pantallaPorMetro = proyeccion.escala * pantallaPorLienzo;

    final ocupados = <({String nombre, Rect rect})>[];
    void registrar(String nombre, Rect rect) =>
        ocupados.add((nombre: nombre, rect: rect.inflate(kMargenColision)));

    void registrarInsignias(bool Function(_Insignia) cuales) {
      for (final i in _insignias) {
        if (!cuales(i) ||
            !_insigniaVisible(i, pantallaPorMetro, mostrarIconos)) {
          continue;
        }
        registrar(
            i.nombre,
            Rect.fromCircle(
                center: enPantalla(i.ancla),
                radius: radioInsignia(zoom, tamano: i.tamano)));
      }
    }

    void registrarTextos(_Clase clase) {
      for (final t in _textos) {
        if (t.clase != clase || !_visible(t.soloDetalle, pantallaPorMetro)) {
          continue;
        }
        final f = t.factorDeTamano(pantallaPorMetro);
        if (f == 0) continue;
        registrar(
            t.relleno.plainText,
            _rectanguloDeTexto(
                enPantalla(t.ancla) +
                    Offset(0, t.dyCon(zoom, mostrarIconos: mostrarIconos)),
                t.relleno.size * f,
                t.anguloGrados));
      }
    }

    // Por prioridad: entradas, letras, insignias y nombres largos.
    registrarInsignias((i) => !i.ocultable);
    registrarTextos(_Clase.entrada);
    registrarTextos(_Clase.letra);
    registrarInsignias((i) => i.ocultable);
    registrarTextos(_Clase.largo);

    // Al final, los nombres de calles.
    final limites = Rect.fromPoints(enPantalla(Offset(meta.minX, meta.minY)),
        enPantalla(Offset(meta.maxX, meta.maxY)));
    final calles =
        <({String texto, Offset ancla, double anguloGrados, Rect rect})>[];
    for (final c in _calles) {
      for (final posicion in c.posiciones) {
        final centro = enPantalla(posicion.ancla);
        if (!limites.contains(centro)) continue;
        final rect = _rectanguloDeTexto(
                centro, c.relleno.size, posicion.anguloGrados)
            .inflate(kMargenColision);
        if (ocupados.any((o) => o.rect.overlaps(rect))) continue;
        calles.add((
          texto: c.relleno.plainText,
          ancla: posicion.ancla,
          anguloGrados: posicion.anguloGrados,
          rect: rect,
        ));
        ocupados.add((nombre: c.relleno.plainText, rect: rect));
        break;
      }
    }

    _claveColocacion = clave;
    return _colocacion = ColocacionEtiquetas(ocupados, calles);
  }

  static bool _insigniaVisible(
          _Insignia i, double pantallaPorMetro, bool mostrarIconos) =>
      _visible(i.soloDetalle, pantallaPorMetro) &&
      (mostrarIconos || !i.ocultable);

  /// Rectángulo (alineado a los ejes) que envuelve un texto de [tamano]
  /// centrado en [centro] y girado [anguloGrados].
  static Rect _rectanguloDeTexto(
      Offset centro, Size tamano, double anguloGrados) {
    final a = anguloGrados * math.pi / 180;
    final c = math.cos(a).abs(), s = math.sin(a).abs();
    return Rect.fromCenter(
      center: centro,
      width: tamano.width * c + tamano.height * s,
      height: tamano.width * s + tamano.height * c,
    );
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
    for (final c in _calles) {
      c.relleno.dispose();
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

  /// Escala del `InteractiveViewer` (1 = mapa completo); decide el
  /// tamaño de las insignias ([radioInsignia]).
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
    final pantallaPorMetro = proyeccion.escala * pantallaPorLienzo;

    for (final i in etiquetas._insignias) {
      if (!EtiquetasMapaVectorial._insigniaVisible(
          i, pantallaPorMetro, mostrarIconos)) {
        continue;
      }
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
      if (!EtiquetasMapaVectorial._visible(t.soloDetalle, pantallaPorMetro)) {
        continue;
      }
      final f = t.factorDeTamano(pantallaPorMetro);
      if (f == 0) continue;
      final ancla = _aLienzo(t.ancla);
      canvas.save();
      canvas.translate(ancla.dx, ancla.dy);
      canvas.scale(k * f);
      if (t.anguloGrados != 0) canvas.rotate(t.anguloGrados * math.pi / 180);
      final esquina =
          Offset(-t.relleno.width / 2,
              t.dyCon(zoom, mostrarIconos: mostrarIconos) -
                  t.relleno.height / 2);
      t.halo?.paint(canvas, esquina);
      t.relleno.paint(canvas, esquina);
      canvas.restore();
    }

    // Los nombres de calles, solo donde caben sin chocar con lo demás.
    final colocacion = etiquetas.colocar(
      proyeccion: proyeccion,
      pantallaPorLienzo: pantallaPorLienzo,
      zoom: zoom,
      mostrarIconos: mostrarIconos,
    );
    for (final calle in colocacion.calles) {
      final relleno = etiquetas._calles
          .firstWhere((c) => c.relleno.plainText == calle.texto)
          .relleno;
      final ancla = _aLienzo(calle.ancla);
      canvas.save();
      canvas.translate(ancla.dx, ancla.dy);
      canvas.scale(k);
      canvas.rotate(calle.anguloGrados * math.pi / 180);
      relleno.paint(canvas, Offset(-relleno.width / 2, -relleno.height / 2));
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
