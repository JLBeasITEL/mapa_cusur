import 'dart:ui' show Offset, Size;

import '../../domain/proyeccion_local.dart';
import '../../domain/transformacion_geo.dart';
import '../../models/nodo.dart';

/// Cómo se dibuja el mapa: sobre la imagen `assets/mapa_CUSur.png` (la
/// versión documentada en la tesis) o como mapa vectorial a partir de
/// `assets/campus_vector.json`.
enum ModoMapa { imagen, vectorial }

/// Modo activo de la app. Cambiar a [ModoMapa.imagen] para la versión
/// documentada en la tesis: con él, la app se comporta exactamente igual
/// que antes del mapa vectorial.
const ModoMapa kModoMapa = ModoMapa.vectorial;

/// El espacio del lienzo donde se dibujan la ruta, los pines y el marcador
/// GPS, y la conversión de nodos y posiciones geográficas a ese espacio.
///
/// Es el único punto donde los dos modos difieren al ubicar algo en el
/// mapa; los painters y `MapImageArea` no saben en qué modo están.
abstract class LienzoMapa {
  /// Tamaño del lienzo en unidades de lienzo.
  Size get tamano;

  Offset nodoALienzo(Nodo nodo);

  /// `null` si la posición no se puede ubicar en este lienzo.
  Offset? geoALienzo(double lat, double lng);
}

/// El lienzo de `assets/mapa_CUSur.png`: envuelve sin cambios el cálculo
/// de siempre ([pixelesACanvas] para los nodos y [geoACanvas] con el modelo
/// de transformación activo para el GPS).
class LienzoImagen implements LienzoMapa {
  /// Tamaño en píxeles de `assets/mapa_CUSur.png`, que `Image.asset` dibuja
  /// a escala 1. El modo imagen no lo usa para dimensionar nada (el tamaño
  /// lo sigue dando la imagen misma); una prueba verifica que coincida con
  /// el archivo.
  static const Size tamanoImagen = Size(4680, 3786);

  /// Modelo de transformación geo→píxel activo. `null` mientras los datos
  /// del campus aún no terminan de cargar.
  final TransformacionGeoPixel? transformacion;

  const LienzoImagen(this.transformacion);

  @override
  Size get tamano => tamanoImagen;

  @override
  Offset nodoALienzo(Nodo nodo) {
    final p = pixelesACanvas(nodo.pixelX, nodo.pixelY);
    return Offset(p.x, p.y);
  }

  @override
  Offset? geoALienzo(double lat, double lng) {
    final t = transformacion;
    if (t == null) return null;
    final p = geoACanvas(t, lat: lat, lng: lng);
    return Offset(p.x, p.y);
  }

  @override
  bool operator ==(Object other) =>
      other is LienzoImagen && identical(other.transformacion, transformacion);

  @override
  int get hashCode => identityHashCode(transformacion);
}

/// El lienzo del mapa vectorial: todo se ubica por lat/lng con la
/// [ProyeccionLocal] de `campus_vector.json`, sin `coordenadas_pix` ni
/// modelo de transformación. Por eso siempre puede ubicar el GPS.
class LienzoVectorial implements LienzoMapa {
  final ProyeccionLocal proyeccion;

  const LienzoVectorial(this.proyeccion);

  @override
  Size get tamano => proyeccion.tamanoLienzo;

  @override
  Offset nodoALienzo(Nodo nodo) => proyeccion.geoALienzo(nodo.lat, nodo.lng);

  @override
  Offset geoALienzo(double lat, double lng) =>
      proyeccion.geoALienzo(lat, lng);

  @override
  bool operator ==(Object other) =>
      other is LienzoVectorial &&
      identical(other.proyeccion.meta, proyeccion.meta) &&
      other.proyeccion.escala == proyeccion.escala;

  @override
  int get hashCode =>
      Object.hash(identityHashCode(proyeccion.meta), proyeccion.escala);
}
