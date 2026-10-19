/// Distancia en línea recta para mostrar junto a un resultado de búsqueda,
/// con "≈" para dejar claro que no es la distancia caminando por la ruta:
/// menos de 1,000 m redondeada a decenas ("≈ 180 m"); desde 1,000 m, en km
/// con un decimal ("≈ 1.2 km").
///
/// El corte se aplica después de redondear, para que 996 m no salga como
/// "≈ 1000 m" sino como "≈ 1.0 km".
String formatearDistanciaAproximada(double metros) {
  final decenas = (metros / 10).round() * 10;
  if (decenas < 1000) return '≈ $decenas m';
  return '≈ ${(metros / 1000).toStringAsFixed(1)} km';
}
