import 'dart:math';

/// Radio medio de la Tierra en metros.
///
/// Es la elección estándar para la fórmula de Haversine: Haversine ya asume
/// una Tierra esférica, así que usar el radio ecuatorial WGS84 (6378137 m,
/// el que usa `Geolocator.distanceBetween`) sería incoherente con esa
/// misma suposición. Además es el radio con el que `exportar_rutas.py`
/// calculó los pesos (minutos) que hoy tiene `assets/campus_data.json`, así
/// que usarlo aquí también unifica el criterio de distancia en todo el
/// proyecto en vez de tener dos radios distintos conviviendo.
///
/// Antes de este cambio la app usaba `Geolocator.distanceBetween` (radio
/// WGS84). La diferencia entre ambos radios es de solo 0.11%, insignificante
/// en general, pero bastaba para que una arista del grafo muy cercana a un
/// múltiplo entero de 8 m (Edificio_R-R1) se subdividiera en 5 tramos en vez
/// de 4, generando un nodo fantasma de más (865 en vez de 864; 1009 nodos
/// totales tras interpolar en vez de 1008). Ver REPORTE_DATOS.md.
const double kRadioTierraMetros = 6371000.0;

double _aRadianes(double grados) => grados * pi / 180;

/// Distancia entre dos coordenadas geográficas, en metros, usando la
/// fórmula de Haversine (ver https://en.wikipedia.org/wiki/Haversine_formula).
double distanciaHaversineMetros(
  double lat1,
  double lng1,
  double lat2,
  double lng2,
) {
  final double dLat = _aRadianes(lat2 - lat1);
  final double dLng = _aRadianes(lng2 - lng1);

  final double a = sin(dLat / 2) * sin(dLat / 2) +
      cos(_aRadianes(lat1)) *
          cos(_aRadianes(lat2)) *
          sin(dLng / 2) *
          sin(dLng / 2);
  final double c = 2 * atan2(sqrt(a), sqrt(1 - a));

  return kRadioTierraMetros * c;
}

/// Proyecta ([lat], [lng]) a un plano local en metros (aproximación
/// equirrectangular) centrado en ([latReferencia], [lngReferencia]): el eje
/// X crece hacia el este, el eje Y hacia el norte, y el punto de referencia
/// queda en el origen (0, 0).
///
/// Usa el mismo [kRadioTierraMetros] que [distanciaHaversineMetros] -no un
/// radio ni una constante de conversión nueva- para que no convivan dos
/// criterios de distancia distintos en el proyecto. Es una aproximación
/// válida a la escala del campus (unos pocos cientos de metros): a esa
/// escala, la distancia euclidiana en este plano coincide, hasta una
/// fracción de milímetro, con la distancia de Haversine entre los mismos
/// dos puntos.
({double x, double y}) aPlanoLocalMetros({
  required double lat,
  required double lng,
  required double latReferencia,
  required double lngReferencia,
}) {
  final double metrosPorGradoLat = kRadioTierraMetros * pi / 180;
  final double metrosPorGradoLng =
      kRadioTierraMetros * cos(_aRadianes(latReferencia)) * pi / 180;

  return (
    x: (lng - lngReferencia) * metrosPorGradoLng,
    y: (lat - latReferencia) * metrosPorGradoLat,
  );
}
