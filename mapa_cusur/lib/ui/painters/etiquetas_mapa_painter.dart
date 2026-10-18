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

/// Tamaño de las insignias de lugares y canchas respecto a las de
/// edificio (misma regla de crecimiento con el zoom y mismo tope, a escala).
const double kTamanoInsigniaSecundaria = 0.8;

/// Radio con el que se maquetan las insignias (el de zoom ×2); al
/// dibujarlas se escalan a [radioInsignia].
const double _radioMaquetado = 11;

/// Fracción de la pantalla que debe cubrir un edificio (a lo ancho o a lo
/// alto) para que se vea su subtítulo: solo cuando casi lo llena.
const double kCoberturaSubtitulo = 0.75;

/// Tamaño máximo en pantalla de la letra de un edificio.
const double kTamanoLetra = 15;

/// La diagonal de la caja de la letra ocupa a lo más esta fracción del
/// diámetro del círculo libre de su edificio (ver [_ubicarLetras]).
const double kFraccionDiametroLetra = 0.9;

/// Margen en metros alrededor de cada insignia que la letra debe evitar.
const double kMargenInsigniaLetra = 1;

/// Separación en pantalla entre el borde de la insignia de una entrada y
/// su texto cuando el texto va a un lado (a la derecha o a la izquierda).
const double kSeparacionLateralEntrada = 4;

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

  /// El elemento del mapa al que pertenece (edificio, lugar, entrada...).
  final Object dueno;
  final Offset ancla; // metros
  final double tamano; // 1 edificios; 1.25 entradas; 0.8 lugares y canchas
  final Color fondo;
  final Color borde;
  final TextPainter icono;
  final bool soloDetalle;

  /// Si el botón de íconos la oculta: todas menos las de las entradas.
  final bool ocultable;

  _Insignia({
    required this.nombre,
    required this.dueno,
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

  /// El elemento del mapa al que pertenece: un texto no choca con la
  /// insignia ni con la letra de su mismo elemento.
  final Object? dueno;

  /// Las líneas de un mismo bloque (un lugar de dos líneas, un subtítulo)
  /// comparten grupo: se dibujan todas o ninguna.
  final Object? grupo;

  /// Solo en los subtítulos: ancho y alto en metros del edificio, del que
  /// depende si se ven ([kCoberturaSubtitulo]).
  final Size? cajaEdificio;

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
    this.dueno,
    this.grupo,
    this.cajaEdificio,
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

/// La letra de un edificio, maquetada a [kTamanoLetra] con caja de línea
/// del alto de la letra (así su rectángulo es el de la letra). Dónde va y
/// de qué tamaño dependen del viewport ([_ubicarLetras]).
class _Letra {
  final Edificio edificio;
  final TextPainter relleno;

  _Letra(this.edificio, this.relleno);

  /// Diagonal de la caja de la letra por cada píxel de tamaño de fuente.
  double get diagonalPorPx =>
      math.sqrt(relleno.width * relleno.width +
          relleno.height * relleno.height) /
      kTamanoLetra;

  /// Factor (tamaño en pantalla ÷ [kTamanoLetra]) para que la diagonal
  /// quepa en [kFraccionDiametroLetra] del diámetro de un círculo libre de
  /// [radioMetros] con [pantallaPorMetro]. Sin mínimo: siempre se dibuja.
  double factor(double radioMetros, double pantallaPorMetro) {
    final tamano = math.min(
        kTamanoLetra,
        kFraccionDiametroLetra * 2 * radioMetros * pantallaPorMetro /
            diagonalPorPx);
    return tamano / kTamanoLetra;
  }
}

/// Posiciones fijadas a mano para la letra de algunos edificios, en
/// metros, cuando el cálculo automático no basta. Vacío: por ahora todas
/// las letras salen de [_ubicarLetras].
const Map<String, Offset> kPosicionLetraManual = {};

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
  /// [tipo]: `insignia`, `entrada`, `letra`, `largo` o `calle`.
  final List<({String nombre, String tipo, Rect rect})> ocupados;
  final List<({String texto, Offset ancla, double anguloGrados, Rect rect})>
      calles;

  /// Nombres largos visibles por su umbral que no se dibujan porque
  /// chocan con algo de mayor prioridad.
  final List<String> largosOcultos;

  /// Dónde quedó el texto de cada entrada respecto a su insignia:
  /// `abajo`, `derecha`, `izquierda`, `arriba` o, de respaldo, una
  /// diagonal (`abajo-derecha`...); con `(+1)` o `(+2)` si tuvo que
  /// alejarse una o dos alturas de texto.
  final Map<String, String> ladoEntradas;

  // Los mismos, por identidad, para el painter.
  final Set<Object> _ocultos;

  // Centro elegido (en píxeles, desde el ancla) del texto de cada entrada.
  final Map<Object, Offset> _centrosEntradas;

  const ColocacionEtiquetas(this.ocupados, this.calles, this.largosOcultos,
      this.ladoEntradas, this._ocultos, this._centrosEntradas);
}

/// Las insignias y los textos del mapa vectorial, ya maquetados en píxeles
/// de pantalla. Se construyen una sola vez al cargar los datos: al hacer
/// zoom solo cambia la escala con que se dibujan, no su maquetación.
class EtiquetasMapaVectorial {
  final MetaMapaVectorial meta;
  final List<_Insignia> _insignias;
  final List<_Texto> _textos;
  final List<_Calle> _calles;
  final List<_Letra> _letras;

  EtiquetasMapaVectorial._(this.meta, this._insignias, this._textos,
      this._calles, this._letras);

  int get totalInsignias => _insignias.length;

  /// Tamaño relativo (1 = edificio) de la primera insignia llamada
  /// [nombre]; `null` si no existe.
  @visibleForTesting
  double? tamanoDeInsignia(String nombre) {
    for (final i in _insignias) {
      if (i.nombre == nombre) return i.tamano;
    }
    return null;
  }
  int get totalTextos => _textos.length;

  /// Dónde y de qué tamaño se dibuja la letra [letra]: su centro y el
  /// radio de su círculo libre en metros, y el tamaño de su caja en
  /// pantalla con [zoom], en un viewport con [pantallaPorMetroZoom1]
  /// píxeles por metro con zoom ×1. `null` si no hay esa letra.
  @visibleForTesting
  ({Offset centro, double radioLibre, Size caja})? letraEnPantalla(
      String letra,
      {required double pantallaPorMetroZoom1,
      required double zoom}) {
    final ubicacion = _ubicarLetras(pantallaPorMetroZoom1);
    for (final l in _letras) {
      if (l.relleno.plainText != letra) continue;
      final polo = ubicacion[l]!;
      final f = l.factor(polo.radio, pantallaPorMetroZoom1 * zoom);
      return (centro: polo.centro, radioLibre: polo.radio,
          caja: l.relleno.size * f);
    }
    return null;
  }

  // Última ubicación de las letras y los px/m (×1) con que se calculó.
  Map<_Letra, PoloDeInaccesibilidad>? _ubicacionLetras;
  double? _clavePantallaPorMetroZoom1;

  /// Centro y radio (en metros) del círculo libre de cada letra: el más
  /// grande que cabe en su edificio sin tocar las insignias que caen sobre
  /// él (las de lugares y la del propio edificio), cada una con su radio
  /// en metros más [kMargenInsigniaLetra]. Ese radio en metros es el de
  /// zoom ×1, que no cambia al acercar hasta el tope de la insignia, así
  /// que solo se recalcula si cambia el viewport
  /// ([pantallaPorMetroZoom1]).
  Map<_Letra, PoloDeInaccesibilidad> _ubicarLetras(
      double pantallaPorMetroZoom1) {
    final previa = _ubicacionLetras;
    if (previa != null && _clavePantallaPorMetroZoom1 == pantallaPorMetroZoom1) {
      return previa;
    }
    final ubicacion = Map<_Letra, PoloDeInaccesibilidad>.identity();
    for (final l in _letras) {
      final e = l.edificio;
      final exclusiones = <CirculoExcluido>[
        if (pantallaPorMetroZoom1 > 0)
          for (final i in _insignias)
            if (i.dueno is Lugar || identical(i.dueno, e))
              (
                centro: i.ancla,
                radio: radioInsignia(1, tamano: i.tamano) /
                        pantallaPorMetroZoom1 +
                    kMargenInsigniaLetra,
              ),
      ]
          .where((c) => distanciaLibre(c.centro, e.anillos) > -c.radio)
          .toList();
      final manual = kPosicionLetraManual[e.nombre];
      ubicacion[l] = manual != null
          ? PoloDeInaccesibilidad(manual,
              distanciaLibre(manual, e.anillos, exclusiones: exclusiones))
          : poloDeInaccesibilidad(e.anillos,
              precision: 0.5, exclusiones: exclusiones);
    }
    _clavePantallaPorMetroZoom1 = pantallaPorMetroZoom1;
    return _ubicacionLetras = ubicacion;
  }

  /// Cuántas insignias y textos se dibujan con [pantallaPorMetro]
  /// píxeles de pantalla por metro en una [vista] de ese tamaño (sin
  /// [vista], ningún subtítulo).
  ({int insignias, int textos}) visiblesCon(double pantallaPorMetro,
          {Size? vista}) =>
      (
        insignias: _insignias
            .where((i) => _visible(i.soloDetalle, pantallaPorMetro))
            .length,
        textos: _textos
            .where((t) => _textoVisible(t, pantallaPorMetro, vista))
            .length,
      );

  /// Textos (sin repetir) que se dibujan con [pantallaPorMetro] píxeles
  /// de pantalla por metro. Los nombres de
  /// calles siempre están en la lista, pero además solo se dibujan si caben
  /// ([colocar]).
  Set<String> textosCon(double pantallaPorMetro, {Size? vista}) => {
        for (final l in _letras) l.relleno.plainText,
        for (final t in _textos)
          if (_textoVisible(t, pantallaPorMetro, vista)) t.relleno.plainText,
        for (final c in _calles) c.relleno.plainText,
      };

  static bool _visible(bool soloDetalle, double pantallaPorMetro) =>
      !soloDetalle || pantallaPorMetro >= kDetallePxPorMetro;

  /// Como [_visible], pero un subtítulo además solo se ve cuando su
  /// edificio cubre al menos [kCoberturaSubtitulo] de la [vista].
  static bool _textoVisible(_Texto t, double pantallaPorMetro, Size? vista) {
    final caja = t.cajaEdificio;
    if (caja == null) return _visible(t.soloDetalle, pantallaPorMetro);
    if (vista == null || vista.isEmpty) return false;
    final cobertura = math.max(caja.width * pantallaPorMetro / vista.width,
        caja.height * pantallaPorMetro / vista.height);
    return cobertura >= kCoberturaSubtitulo;
  }

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
        {bool soloDetalle = false,
        bool esEntrada = false,
        bool secundaria = false}) {
      final icono = kIconosMapa[nombreIcono];
      if (icono == null) {
        debugPrint('Ícono desconocido en campus_vector.json: $nombreIcono');
        return;
      }
      final tamano =
          esEntrada ? 1.25 : (secundaria ? kTamanoInsigniaSecundaria : 1.0);
      insignias.add(insigniaDe[elemento] = _Insignia(
        nombre: nombre,
        dueno: elemento,
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
      Object? dueno,
      Object? grupo,
      Size? cajaEdificio,
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
        dueno: dueno,
        grupo: grupo,
        cajaEdificio: cajaEdificio,
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
        insignia(c, c.nombre ?? c.icono!, c.iconoPos!, c.icono!,
            secundaria: true);
      }
    }
    for (final c in mapa.canchas) {
      if (c.icono != null && c.iconoPos != null) {
        insignia(c, c.icono!, c.iconoPos!, c.icono!, secundaria: true);
      }
    }
    for (final l in mapa.lugares) {
      // Siempre visible (su nombre, en cambio, solo desde el umbral).
      insignia(l, l.nombre, l.pos, l.icono, secundaria: true);
    }
    for (final e in mapa.entradas) {
      insignia(e, e.nombre, e.pos, 'door_front', esEntrada: true);
    }
    for (final e in mapa.estacionamientos) {
      insignia(e, e.nombre, e.pos, 'directions_car');
    }

    // --- Letras (su lugar se calcula por viewport, ver _ubicarLetras) ---
    final letras = [
      for (final e in mapa.edificios)
        if (e.letra != null)
          _Letra(
            e,
            TextPainter(
              text: TextSpan(
                  text: e.letra,
                  style: poppins(
                          fontSize: kTamanoLetra,
                          fontWeight: FontWeight.w600,
                          color: ColoresMapaVectorial.textoEdificio)
                      .copyWith(height: 1)),
              textDirection: TextDirection.ltr,
            )..layout(),
          ),
    ];

    // --- Textos ---
    for (final e in mapa.edificios) {
      final polo = polos[e];
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
            dueno: e,
            soloDetalle: true);
      }
      final subtitulo = e.subtitulo ?? const <String>[];
      final bloqueSubtitulo = Object();
      for (var k = 0; k < subtitulo.length; k++) {
        // Debajo de la letra (13 y 24 px), donde ahora está la letra: en el
        // polo del edificio si lo tiene.
        texto(polo?.centro ?? e.etiqueta, subtitulo[k],
            tamano: 9.5,
            peso: FontWeight.w500,
            color: ColoresMapaVectorial.textoEdificio,
            dy: 13.0 + 11 * k,
            dueno: e,
            grupo: bloqueSubtitulo,
            cajaEdificio: _caja(e.anillos.first),
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
            dueno: l,
            grupo: l,
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
          dueno: e,
          clase: _Clase.entrada);
    }
    for (final e in mapa.estacionamientos) {
      texto(e.pos, e.nombre,
          tamano: 11.5,
          peso: FontWeight.w500,
          color: ColoresMapaVectorial.tinta,
          colorHalo: ColoresMapaVectorial.halo,
          debajoDe: e,
          dueno: e,
          soloDetalle: true);
    }
    void nombreDeZona(Object zona, String? nombre, Offset posicion) {
      // Una zona fuera de meta.limites (la Unidad Deportiva, del otro
      // lado de Prolongación Colón) es solo contexto en la orilla del
      // mapa: su nombre no se dibuja.
      if (nombre == null || !_dentroDeLimites(mapa.meta, posicion)) return;
      texto(posicion, nombre,
          tamano: 11.5,
          peso: FontWeight.w500,
          color: ColoresMapaVectorial.tinta,
          dueno: zona,
          soloDetalle: true);
    }

    for (final z in mapa.zonasDeportivas) {
      nombreDeZona(z, z.nombre, z.etiqueta);
    }
    for (final c in mapa.canchasFutbol) {
      nombreDeZona(c, c.nombre, _centro(c.poligono));
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

    return EtiquetasMapaVectorial._(
        mapa.meta, insignias, textos, calles, letras);
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
  (double, double, bool, double, Size?)? _claveColocacion;

  /// Coloca las etiquetas en pantalla (ver [ColocacionEtiquetas]). Las
  /// entradas, las letras y las insignias se registran tal como se
  /// dibujan. Cada nombre largo (o bloque de líneas) se dibuja solo si no
  /// choca con nada de lo ya registrado, salvo su propia insignia o letra. Cada nombre de
  /// calle va en la primera de sus posiciones que no choque con nada, o
  /// no se dibuja.
  ColocacionEtiquetas colocar({
    required ProyeccionLocal proyeccion,
    required double pantallaPorLienzo,
    required double zoom,
    required bool mostrarIconos,
    Size? vista,
  }) {
    final clave =
        (pantallaPorLienzo, zoom, mostrarIconos, proyeccion.escala, vista);
    final previa = _colocacion;
    if (previa != null && _claveColocacion == clave) return previa;

    Offset enPantalla(Offset metros) =>
        proyeccion.localALienzo(metros.dx, metros.dy) * pantallaPorLienzo;
    final pantallaPorMetro = proyeccion.escala * pantallaPorLienzo;

    final ocupados =
        <({String nombre, String tipo, Rect rect, Object? dueno})>[];
    void registrar(String nombre, String tipo, Rect rect, Object? dueno) =>
        ocupados.add((
          nombre: nombre,
          tipo: tipo,
          rect: rect.inflate(kMargenColision),
          dueno: dueno,
        ));
    // Choca con algo ya registrado, sin contar la insignia o la letra de
    // su mismo elemento (el texto va justo debajo de ellas, a propósito).
    bool choca(Rect rect, Object? dueno) => ocupados.any((o) =>
        (dueno == null || !identical(o.dueno, dueno)) &&
        o.rect.overlaps(rect));

    void registrarInsignias(bool Function(_Insignia) cuales) {
      for (final i in _insignias) {
        if (!cuales(i) ||
            !_insigniaVisible(i, pantallaPorMetro, mostrarIconos)) {
          continue;
        }
        registrar(
            i.nombre,
            'insignia',
            Rect.fromCircle(
                center: enPantalla(i.ancla),
                radius: radioInsignia(zoom, tamano: i.tamano)),
            i.dueno);
      }
    }

    Rect? rectangulo(_Texto t) {
      if (!_textoVisible(t, pantallaPorMetro, vista)) return null;
      return _rectanguloDeTexto(
          enPantalla(t.ancla) +
              Offset(0, t.dyCon(zoom, mostrarIconos: mostrarIconos)),
          t.relleno.size,
          t.anguloGrados);
    }

    // El área del mapa en pantalla: lo que se dibuje fuera se corta.
    final limites = Rect.fromPoints(enPantalla(Offset(meta.minX, meta.minY)),
        enPantalla(Offset(meta.maxX, meta.maxY)));

    // Rectángulos de las letras (siempre se dibujan).
    final ubicacion = _ubicarLetras(pantallaPorMetro / zoom);
    final letras = [
      for (final l in _letras)
        (
          letra: l,
          rect: Rect.fromCenter(
              center: enPantalla(ubicacion[l]!.centro),
              width: l.relleno.width *
                  l.factor(ubicacion[l]!.radio, pantallaPorMetro),
              height: l.relleno.height *
                  l.factor(ubicacion[l]!.radio, pantallaPorMetro)),
        ),
    ];

    // El texto de cada entrada va en el primer lado (abajo, derecha,
    // izquierda, arriba y, de respaldo, las cuatro diagonales; primero
    // pegado a la insignia y luego un poco más lejos) que cabe completo en
    // el mapa y no se sobrepone con una letra ni con otra insignia
    // visible. Si ninguno sirve, en el primero que no toque letras; si
    // tampoco, abajo.
    final obstaculos = [
      for (final x in letras)
        (dueno: null, esLetra: true, rect: x.rect.inflate(kMargenColision)),
      for (final i in _insignias)
        if (_insigniaVisible(i, pantallaPorMetro, mostrarIconos))
          (
            dueno: i.dueno,
            esLetra: false,
            rect: Rect.fromCircle(
                    center: enPantalla(i.ancla),
                    radius: radioInsignia(zoom, tamano: i.tamano))
                .inflate(kMargenColision),
          ),
    ];
    final centrosEntradas = Map<Object, Offset>.identity();
    final ladoEntradas = <String, String>{};
    for (final t in _textos.where((t) => t.clase == _Clase.entrada)) {
      final r = radioInsignia(zoom, tamano: t.insignia?.tamano ?? 1);
      final mitad = t.relleno.width / 2;
      final alto = t.relleno.height;
      // Primero pegado a la insignia; si nada cabe, alejándose una y dos
      // alturas de texto (anillos 1 y 2), con el mismo orden de lados.
      final lados = <String, Offset>{};
      for (final anillo in const [0, 1, 2]) {
        final extra = anillo * alto;
        final sufijo = anillo == 0 ? '' : ' (+$anillo)';
        // Diagonales: la esquina del texto junto a la de la insignia.
        final dx = r * math.sqrt1_2 + kSeparacionLateralEntrada + mitad + extra;
        final dy =
            r * math.sqrt1_2 + kSeparacionLateralEntrada + alto / 2 + extra;
        lados.addAll({
          'abajo$sufijo': Offset(
              0, t.dyCon(zoom, mostrarIconos: mostrarIconos) + extra),
          'derecha$sufijo':
              Offset(r + kSeparacionLateralEntrada + mitad + extra, 0),
          'izquierda$sufijo':
              Offset(-(r + kSeparacionLateralEntrada + mitad + extra), 0),
          'arriba$sufijo': Offset(0, -(r + kSeparacionTextoInsignia + extra)),
          'abajo-derecha$sufijo': Offset(dx, dy),
          'abajo-izquierda$sufijo': Offset(-dx, dy),
          'arriba-derecha$sufijo': Offset(dx, -dy),
          'arriba-izquierda$sufijo': Offset(-dx, -dy),
        });
      }
      final ancla = enPantalla(t.ancla);
      bool choca(Offset centro, {required bool soloLetras}) {
        final texto = Rect.fromCenter(
            center: ancla + centro,
            width: t.relleno.width,
            height: t.relleno.height);
        if (!limites.contains(texto.topLeft) ||
            !limites.contains(texto.bottomRight)) {
          return true;
        }
        final rect = texto.inflate(kMargenColision);
        return obstaculos.any((o) =>
            (o.esLetra || !soloLetras) &&
            !identical(o.dueno, t.dueno) &&
            o.rect.overlaps(rect));
      }

      final elegido = lados.keys.firstWhere(
          (lado) => !choca(lados[lado]!, soloLetras: false),
          orElse: () => lados.keys.firstWhere(
              (lado) => !choca(lados[lado]!, soloLetras: true),
              orElse: () => 'abajo'));
      centrosEntradas[t] = lados[elegido]!;
      ladoEntradas[t.relleno.plainText] = elegido;
    }

    // Por prioridad: entradas, letras e insignias.
    registrarInsignias((i) => !i.ocultable);
    for (final t in _textos.where((t) => t.clase == _Clase.entrada)) {
      registrar(
          t.relleno.plainText,
          _Clase.entrada.name,
          Rect.fromCenter(
              center: enPantalla(t.ancla) + centrosEntradas[t]!,
              width: t.relleno.width,
              height: t.relleno.height),
          null);
    }
    // Las letras registran su dueño: el subtítulo de su edificio va justo
    // debajo de ella, a propósito.
    for (final x in letras) {
      registrar(x.letra.relleno.plainText, _Clase.letra.name, x.rect,
          x.letra.edificio);
    }
    registrarInsignias((i) => i.ocultable);

    // Los nombres largos, en orden y por bloques: un bloque que choca con
    // algo de otro elemento no se dibuja.
    final ocultos = Set<Object>.identity();
    final largosOcultos = <String>[];
    final largos = _textos.where((t) => t.clase == _Clase.largo).toList();
    for (var i = 0; i < largos.length;) {
      final grupo = largos[i].grupo;
      var fin = i + 1;
      while (grupo != null &&
          fin < largos.length &&
          identical(largos[fin].grupo, grupo)) {
        fin++;
      }
      final bloque = largos.sublist(i, fin);
      i = fin;

      final rects = [
        for (final t in bloque)
          (t: t, rect: rectangulo(t)?.inflate(kMargenColision)),
      ].where((x) => x.rect != null).toList();
      if (rects.isEmpty) continue;
      if (rects.any((x) => choca(x.rect!, x.t.dueno))) {
        for (final x in rects) {
          ocultos.add(x.t);
          largosOcultos.add(x.t.relleno.plainText);
        }
        continue;
      }
      for (final x in rects) {
        ocupados.add((
          nombre: x.t.relleno.plainText,
          tipo: 'largo',
          rect: x.rect!,
          dueno: null,
        ));
      }
    }

    // Al final, los nombres de calles.
    final calles =
        <({String texto, Offset ancla, double anguloGrados, Rect rect})>[];
    for (final c in _calles) {
      for (final posicion in c.posiciones) {
        final centro = enPantalla(posicion.ancla);
        if (!limites.contains(centro)) continue;
        final rect = _rectanguloDeTexto(
                centro, c.relleno.size, posicion.anguloGrados)
            .inflate(kMargenColision);
        if (choca(rect, null)) continue;
        calles.add((
          texto: c.relleno.plainText,
          ancla: posicion.ancla,
          anguloGrados: posicion.anguloGrados,
          rect: rect,
        ));
        ocupados.add((
          nombre: c.relleno.plainText,
          tipo: 'calle',
          rect: rect,
          dueno: null,
        ));
        break;
      }
    }

    _claveColocacion = clave;
    return _colocacion = ColocacionEtiquetas(
      [
        for (final o in ocupados)
          (nombre: o.nombre, tipo: o.tipo, rect: o.rect),
      ],
      calles,
      largosOcultos,
      ladoEntradas,
      ocultos,
      centrosEntradas,
    );
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

  /// Ancho y alto de la caja que envuelve [poligono].
  static Size _caja(List<Offset> poligono) {
    final xs = poligono.map((p) => p.dx);
    final ys = poligono.map((p) => p.dy);
    return Size(xs.reduce(math.max) - xs.reduce(math.min),
        ys.reduce(math.max) - ys.reduce(math.min));
  }

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
    for (final l in _letras) {
      l.relleno.dispose();
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

  /// Tamaño en pantalla del área del mapa: decide si se ven los
  /// subtítulos ([kCoberturaSubtitulo]). Sin él no se dibuja ninguno.
  final Size? vista;

  EtiquetasMapaPainter({
    required this.etiquetas,
    required this.proyeccion,
    required this.pantallaPorLienzo,
    required this.zoom,
    this.mostrarIconos = true,
    this.vista,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (pantallaPorLienzo <= 0) return;
    final double k = 1 / pantallaPorLienzo;

    final fondo = Paint();
    final borde = Paint()..style = PaintingStyle.stroke;
    final pantallaPorMetro = proyeccion.escala * pantallaPorLienzo;
    // Qué nombres largos chocan y dónde van las calles (se recalcula solo
    // si cambian la escala, el zoom o el botón de íconos).
    final colocacion = etiquetas.colocar(
      proyeccion: proyeccion,
      pantallaPorLienzo: pantallaPorLienzo,
      zoom: zoom,
      mostrarIconos: mostrarIconos,
      vista: vista,
    );

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

    // Las letras de edificio, siempre, en su círculo libre.
    final ubicacion = etiquetas._ubicarLetras(pantallaPorMetro / zoom);
    for (final l in etiquetas._letras) {
      final polo = ubicacion[l]!;
      final ancla = _aLienzo(polo.centro);
      canvas.save();
      canvas.translate(ancla.dx, ancla.dy);
      canvas.scale(k * l.factor(polo.radio, pantallaPorMetro));
      l.relleno
          .paint(canvas, Offset(-l.relleno.width / 2, -l.relleno.height / 2));
      canvas.restore();
    }

    for (final t in etiquetas._textos) {
      if (!EtiquetasMapaVectorial._textoVisible(t, pantallaPorMetro, vista) ||
          colocacion._ocultos.contains(t)) {
        continue;
      }
      final ancla = _aLienzo(t.ancla);
      canvas.save();
      canvas.translate(ancla.dx, ancla.dy);
      canvas.scale(k);
      if (t.anguloGrados != 0) canvas.rotate(t.anguloGrados * math.pi / 180);
      // El texto de una entrada va en el lado que eligió la colocación.
      final centro = colocacion._centrosEntradas[t] ??
          Offset(0, t.dyCon(zoom, mostrarIconos: mostrarIconos));
      final esquina =
          centro - Offset(t.relleno.width / 2, t.relleno.height / 2);
      t.halo?.paint(canvas, esquina);
      t.relleno.paint(canvas, esquina);
      canvas.restore();
    }

    // Los nombres de calles, solo donde caben sin chocar con lo demás.
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
      oldDelegate.vista != vista ||
      oldDelegate.proyeccion.escala != proyeccion.escala;
}
