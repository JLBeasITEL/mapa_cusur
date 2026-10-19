import '../models/mapa_vectorial.dart';
import 'proyeccion_local.dart';

/// Margen, en metros, que se agrega alrededor de `meta.limites` de
/// `assets/campus_vector.json` para considerar que una posición está dentro
/// del área del mapa.
// TODO(JuanLuis): ajustar después de probar en campo (valor inicial 0).
const double kMargenAreaMapaMetros = 0;

/// Si ([lat], [lng]) cae dentro de la caja `meta.limites` del mapa
/// vectorial, ampliada [margenMetros] por cada lado. Usa la misma
/// proyección local del mapa ([ProyeccionLocal.geoALocal]).
bool estaDentroDelAreaDelMapa(
  MetaMapaVectorial meta,
  double lat,
  double lng, {
  double margenMetros = kMargenAreaMapaMetros,
}) {
  final local = ProyeccionLocal(meta).geoALocal(lat, lng);
  return local.x >= meta.minX - margenMetros &&
      local.x <= meta.maxX + margenMetros &&
      local.y >= meta.minY - margenMetros &&
      local.y <= meta.maxY + margenMetros;
}
