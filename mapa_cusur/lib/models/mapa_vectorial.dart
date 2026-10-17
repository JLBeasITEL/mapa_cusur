import 'dart:ui' show Offset;

/// El mapa vectorial del campus, leído de `assets/campus_vector.json` por
/// data/mapa_vectorial_parser.dart.
///
/// Todas las coordenadas están en metros: `x` hacia el este y `y` hacia el
/// sur desde [MetaMapaVectorial.origenLat]/[MetaMapaVectorial.origenLng]
/// (la `y` crece hacia abajo, como en el Canvas). Los polígonos repiten el
/// primer punto al final. Las clases son inmutables: el parser entrega
/// todas las listas como no modificables.
class MapaVectorial {
  final int version;
  final MetaMapaVectorial meta;

  /// Polígono del terreno del campus.
  final List<Offset> campus;
  final List<List<Offset>> areasVerdes;
  final List<ZonaDeportiva> zonasDeportivas;
  final List<CanchaFutbol> canchasFutbol;
  final List<Cancha> canchas;
  final List<Vialidad> vialidades;
  final List<EtiquetaCalle> etiquetasCalles;
  final List<Edificio> edificios;
  final List<Lugar> lugares;
  final List<PuntoMapa> entradas;
  final List<PuntoMapa> estacionamientos;

  const MapaVectorial({
    required this.version,
    required this.meta,
    required this.campus,
    required this.areasVerdes,
    required this.zonasDeportivas,
    required this.canchasFutbol,
    required this.canchas,
    required this.vialidades,
    required this.etiquetasCalles,
    required this.edificios,
    required this.lugares,
    required this.entradas,
    required this.estacionamientos,
  });
}

/// Sección `meta`: el origen y los factores de la proyección local
/// (`x = (lng − lng0)·mlng`, `y = −(lat − lat0)·mlat`), los límites del
/// dibujo en metros y la atribución que exige la ODbL.
class MetaMapaVectorial {
  final double origenLat;
  final double origenLng;
  final double metrosPorGradoLat;
  final double metrosPorGradoLng;
  final double minX;
  final double minY;
  final double maxX;
  final double maxY;

  /// "© colaboradores de OpenStreetMap": debe mostrarse en pantalla.
  final String atribucion;
  final String licencia;

  const MetaMapaVectorial({
    required this.origenLat,
    required this.origenLng,
    required this.metrosPorGradoLat,
    required this.metrosPorGradoLng,
    required this.minX,
    required this.minY,
    required this.maxX,
    required this.maxY,
    required this.atribucion,
    required this.licencia,
  });
}

class Circulo {
  final Offset centro;
  final double radio;

  const Circulo({required this.centro, required this.radio});
}

/// Zona deportiva grande sin líneas de cancha (p. ej. la Unidad Deportiva).
class ZonaDeportiva {
  final String nombre;
  final List<Offset> poligono;
  final Offset etiqueta;

  const ZonaDeportiva({
    required this.nombre,
    required this.poligono,
    required this.etiqueta,
  });
}

class CanchaFutbol {
  final String? nombre;
  final List<Offset> poligono;

  /// Los dos extremos [A, B] de la línea media.
  final List<Offset> lineaMedia;
  final Circulo circuloCentral;
  final String? icono;
  final Offset? iconoPos;

  const CanchaFutbol({
    required this.nombre,
    required this.poligono,
    required this.lineaMedia,
    required this.circuloCentral,
    required this.icono,
    required this.iconoPos,
  });
}

enum TipoCancha { tenisVerde, tenisAzul, baloncesto }

class Cancha {
  final TipoCancha tipo;
  final List<Offset> poligono;

  /// Polilíneas de las líneas de la cancha.
  final List<List<Offset>> lineas;
  final List<Circulo> circulos;

  /// Polilíneas abiertas (los arcos de las áreas de baloncesto).
  final List<List<Offset>> semicirculos;
  final String? icono;
  final Offset? iconoPos;

  const Cancha({
    required this.tipo,
    required this.poligono,
    required this.lineas,
    required this.circulos,
    required this.semicirculos,
    required this.icono,
    required this.iconoPos,
  });
}

enum TipoVialidad { calle, servicio }

class Vialidad {
  final TipoVialidad tipo;
  final String? nombre;
  final List<Offset> linea;

  /// Ancho de la vialidad en metros.
  final double ancho;

  const Vialidad({
    required this.tipo,
    required this.nombre,
    required this.linea,
    required this.ancho,
  });
}

class EtiquetaCalle {
  final String texto;
  final Offset pos;
  final double anguloGrados;

  const EtiquetaCalle({
    required this.texto,
    required this.pos,
    required this.anguloGrados,
  });
}

enum TipoEdificio { normal, techada, techo }

class Edificio {
  final String? nombre;
  final String? letra;
  final String? texto;
  final TipoEdificio tipo;

  /// El primer anillo es el contorno; los demás son huecos.
  final List<List<Offset>> anillos;
  final Offset etiqueta;
  final String? icono;
  final List<String>? subtitulo;

  /// Nombres (tal como se muestran en la app) de los lugares del grafo que
  /// están en este edificio.
  final List<String> nodos;

  /// "OpenStreetMap" o "trazo propio".
  final String origen;

  const Edificio({
    required this.nombre,
    required this.letra,
    required this.texto,
    required this.tipo,
    required this.anillos,
    required this.etiqueta,
    required this.icono,
    required this.subtitulo,
    required this.nodos,
    required this.origen,
  });
}

class Lugar {
  final String nombre;

  /// El nombre partido en las líneas con que se dibuja.
  final List<String> lineas;
  final String icono;
  final Offset pos;
  final bool enAreaVerde;

  const Lugar({
    required this.nombre,
    required this.lineas,
    required this.icono,
    required this.pos,
    required this.enAreaVerde,
  });
}

/// Una entrada o un estacionamiento: un punto con nombre ligado a un nodo
/// del grafo (`nodo` es el ID en `campus_data.json`).
class PuntoMapa {
  final String nombre;
  final String nodo;
  final Offset pos;

  const PuntoMapa({required this.nombre, required this.nodo, required this.pos});
}
