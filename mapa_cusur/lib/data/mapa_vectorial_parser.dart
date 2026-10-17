import 'dart:ui' show Offset;

import '../models/mapa_vectorial.dart';

/// Traduce el JSON decodificado de `assets/campus_vector.json` a un
/// [MapaVectorial].
///
/// Es el único lugar que conoce el formato de ese JSON, igual que
/// data/campus_json_parser.dart lo es para `campus_data.json`. A diferencia
/// de aquel, no es Dart puro: los puntos son [Offset] de `dart:ui`, así que
/// no puede usarse desde un script de `dart run`.
///
/// Lanza [FormatException] si un `tipo` no es uno de los conocidos, en vez
/// de adivinar cómo dibujarlo.
MapaVectorial parsearMapaVectorial(Map<String, dynamic> data) {
  return MapaVectorial(
    version: data['version'] as int,
    meta: _meta(data['meta']),
    campus: _polilinea(data['campus']),
    areasVerdes: _lista(data['areas_verdes'], _polilinea),
    zonasDeportivas: _lista(data['zonas_deportivas'], _zonaDeportiva),
    canchasFutbol: _lista(data['canchas_futbol'], _canchaFutbol),
    canchas: _lista(data['canchas'], _cancha),
    vialidades: _lista(data['vialidades'], _vialidad),
    etiquetasCalles: _lista(data['etiquetas_calles'], _etiquetaCalle),
    edificios: _lista(data['edificios'], _edificio),
    lugares: _lista(data['lugares'], _lugar),
    entradas: _lista(data['entradas'], _puntoMapa),
    estacionamientos: _lista(data['estacionamientos'], _puntoMapa),
  );
}

MetaMapaVectorial _meta(Map<String, dynamic> m) {
  final Map<String, dynamic> origen = m['origen'];
  final Map<String, dynamic> factores = m['metros_por_grado'];
  final Map<String, dynamic> limites = m['limites'];
  return MetaMapaVectorial(
    origenLat: _num(origen['lat']),
    origenLng: _num(origen['lng']),
    metrosPorGradoLat: _num(factores['lat']),
    metrosPorGradoLng: _num(factores['lng']),
    minX: _num(limites['min_x']),
    minY: _num(limites['min_y']),
    maxX: _num(limites['max_x']),
    maxY: _num(limites['max_y']),
    atribucion: m['atribucion'] as String,
    licencia: m['licencia'] as String,
  );
}

ZonaDeportiva _zonaDeportiva(dynamic z) => ZonaDeportiva(
      nombre: z['nombre'] as String,
      poligono: _polilinea(z['poligono']),
      etiqueta: _punto(z['etiqueta']),
    );

CanchaFutbol _canchaFutbol(dynamic c) => CanchaFutbol(
      nombre: c['nombre'] as String?,
      poligono: _polilinea(c['poligono']),
      lineaMedia: _polilinea(c['linea_media']),
      circuloCentral: _circulo(c['circulo_central']),
      icono: c['icono'] as String?,
      iconoPos: _puntoOpcional(c['icono_pos']),
    );

Cancha _cancha(dynamic c) => Cancha(
      tipo: _enum(c['tipo'], const {
        'tenis_verde': TipoCancha.tenisVerde,
        'tenis_azul': TipoCancha.tenisAzul,
        'baloncesto': TipoCancha.baloncesto,
      }),
      poligono: _polilinea(c['poligono']),
      lineas: _lista(c['lineas'], _polilinea),
      circulos: _lista(c['circulos'], _circulo),
      semicirculos: _lista(c['semicirculos'], _polilinea),
      icono: c['icono'] as String?,
      iconoPos: _puntoOpcional(c['icono_pos']),
    );

Vialidad _vialidad(dynamic v) => Vialidad(
      tipo: _enum(v['tipo'], const {
        'calle': TipoVialidad.calle,
        'servicio': TipoVialidad.servicio,
      }),
      nombre: v['nombre'] as String?,
      linea: _polilinea(v['linea']),
      ancho: _num(v['ancho']),
    );

EtiquetaCalle _etiquetaCalle(dynamic e) => EtiquetaCalle(
      texto: e['texto'] as String,
      pos: _punto(e['pos']),
      anguloGrados: _num(e['angulo_grados']),
    );

Edificio _edificio(dynamic e) => Edificio(
      nombre: e['nombre'] as String?,
      letra: e['letra'] as String?,
      texto: e['texto'] as String?,
      tipo: _enum(e['tipo'], const {
        'normal': TipoEdificio.normal,
        'techada': TipoEdificio.techada,
        'techo': TipoEdificio.techo,
      }),
      anillos: _lista(e['anillos'], _polilinea),
      etiqueta: _punto(e['etiqueta']),
      icono: e['icono'] as String?,
      subtitulo: e['subtitulo'] == null ? null : _textos(e['subtitulo']),
      nodos: _textos(e['nodos']),
      origen: e['origen'] as String,
    );

Lugar _lugar(dynamic l) => Lugar(
      nombre: l['nombre'] as String,
      lineas: _textos(l['lineas']),
      icono: l['icono'] as String,
      pos: _punto(l['pos']),
      enAreaVerde: l['en_area_verde'] as bool,
    );

PuntoMapa _puntoMapa(dynamic p) => PuntoMapa(
      nombre: p['nombre'] as String,
      nodo: p['nodo'] as String,
      pos: _punto(p['pos']),
    );

Circulo _circulo(dynamic c) =>
    Circulo(centro: _punto(c['centro']), radio: _num(c['radio']));

// En el JSON los números enteros vienen sin decimales (`"pos": [80, 55]`),
// así que siempre se leen como `num`.
double _num(dynamic valor) => (valor as num).toDouble();

Offset _punto(dynamic xy) {
  final List par = xy;
  return Offset(_num(par[0]), _num(par[1]));
}

Offset? _puntoOpcional(dynamic xy) => xy == null ? null : _punto(xy);

List<Offset> _polilinea(dynamic puntos) => _lista(puntos, _punto);

List<String> _textos(dynamic lista) =>
    List.unmodifiable((lista as List).cast<String>());

List<T> _lista<T>(dynamic lista, T Function(dynamic) convertir) =>
    List.unmodifiable((lista as List).map(convertir));

T _enum<T>(dynamic valor, Map<String, T> opciones) {
  final T? resultado = opciones[valor];
  if (resultado == null) {
    throw FormatException(
        'Tipo desconocido en campus_vector.json: "$valor" '
        '(se esperaba uno de ${opciones.keys.join(', ')})');
  }
  return resultado;
}
