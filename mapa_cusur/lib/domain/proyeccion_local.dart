import 'dart:ui' show Offset, Size;

import '../models/mapa_vectorial.dart';

/// Unidades de lienzo por metro del mapa vectorial.
///
/// Es aproximadamente la escala del lienzo de `assets/mapa_CUSur.png` en el
/// modo imagen (`pixelesACanvas` sobre `coordenadas_pix`), que no es
/// uniforme: medida con la distancia en el lienzo de la imagen entre la
/// distancia en metros de la proyección local, da 11.96 para
/// EntradaA–Edificio_M, 10.39 para EntradaB–EntradaC y 10.99 para
/// EntradaA–EntradaC. Con 11 los grosores y tamaños que ya usa
/// `RoutePainter` (la línea de la ruta de 36, los pines, el marcador GPS)
/// se ven prácticamente igual en los dos modos, sin tocar su estilo.
///
/// Es solo un paso de renderizado: no interviene en ningún cálculo de
/// distancias ni de errores de la instrumentación.
const double kEscalaVectorial = 11.0;

/// Proyección local del mapa vectorial: geográficas (lat/lng) → metros
/// (x al este, y al sur desde el origen de `meta`) → lienzo.
///
/// El origen y los factores de metros por grado salen de
/// `assets/campus_vector.json` ([MetaMapaVectorial]) y no se duplican como
/// constantes: el JSON se generó con esta misma fórmula, así que sus
/// posiciones y las que calcula esta clase son consistentes por
/// construcción.
class ProyeccionLocal {
  final MetaMapaVectorial meta;

  /// Unidades de lienzo por metro. Solo las pruebas usan otro valor.
  final double escala;

  const ProyeccionLocal(this.meta, {this.escala = kEscalaVectorial});

  /// `x = (lng − lng0)·mlng`, `y = −(lat − lat0)·mlat` (`meta.formula`).
  ({double x, double y}) geoALocal(double lat, double lng) {
    return (
      x: (lng - meta.origenLng) * meta.metrosPorGradoLng,
      y: -(lat - meta.origenLat) * meta.metrosPorGradoLat,
    );
  }

  /// Metros → lienzo: `((x − min_x)·k, (y − min_y)·k)`, con el lienzo
  /// empezando en la esquina superior izquierda de `meta.limites`.
  Offset localALienzo(double x, double y) {
    return Offset((x - meta.minX) * escala, (y - meta.minY) * escala);
  }

  /// Inversa de [localALienzo].
  ({double x, double y}) lienzoALocal(Offset punto) {
    return (
      x: punto.dx / escala + meta.minX,
      y: punto.dy / escala + meta.minY,
    );
  }

  /// Composición de [geoALocal] y [localALienzo].
  Offset geoALienzo(double lat, double lng) {
    final local = geoALocal(lat, lng);
    return localALienzo(local.x, local.y);
  }

  /// Tamaño del lienzo que cubre `meta.limites`.
  Size get tamanoLienzo => Size(
        (meta.maxX - meta.minX) * escala,
        (meta.maxY - meta.minY) * escala,
      );
}
