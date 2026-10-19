import 'dart:math';

import '../models/grafo_campus.dart';
import '../models/nodo.dart';
import '../utils/geodesia.dart';

/// Factor de escala entre el sistema de coordenadas en píxeles del grafo
/// (`coordenadas_pix` en el JSON, digitalizado sobre una versión reducida
/// del mapa) y el lienzo (`Canvas`) donde se dibuja `assets/mapa_CUSur.png`
/// a su resolución real. Es la razón entre la distancia en píxeles de dos
/// puntos de control y la distancia real (también en píxeles del lienzo)
/// entre esos mismos dos puntos sobre la imagen a tamaño completo.
///
/// No se elimina ni se reinterpreta con el modelo afín (Fase 4): sigue
/// siendo un paso universal que se aplica igual sin importar qué modelo
/// -[TransformacionDosPuntos] o [TransformacionAfin]- calculó los píxeles.
/// La única diferencia entre ambos modelos es cómo se llega a esos píxeles
/// (en el mismo espacio y con la misma convención de ejes que
/// `coordenadas_pix`); qué se hace después con ellos -el intercambio X/Y y
/// este factor- es idéntico en los dos casos.
const double kFactorEscalaMapa = 6.0;

/// Convierte un punto en el sistema de coordenadas en píxeles del grafo
/// (el mismo espacio y convención de `coordenadas_pix`) a coordenadas del
/// lienzo.
///
/// Aplica el factor de escala [kFactorEscalaMapa] y un intercambio de ejes
/// (X<->Y): el eje X del lienzo corresponde al eje Y del grafo y viceversa,
/// porque el mapa fue digitalizado con una orientación distinta a la de la
/// imagen final. Es el mismo cálculo que antes vivía duplicado en
/// `_manejarToqueEnMapa` y en `RoutePainter.paint`, y se aplica igual sin
/// importar qué [TransformacionGeoPixel] produjo el punto.
({double x, double y}) pixelesACanvas(double pixelX, double pixelY) {
  return (x: pixelY * kFactorEscalaMapa, y: pixelX * kFactorEscalaMapa);
}

/// Un modelo que ubica una coordenada geográfica (lat/lng) en el sistema de
/// píxeles del grafo -el mismo espacio y convención de ejes que
/// `coordenadas_pix` en el JSON-. Lo que pasa después con ese píxel
/// ([pixelesACanvas]) es siempre igual, sin importar qué implementación se
/// use.
abstract class TransformacionGeoPixel {
  ({double x, double y}) aPixeles(double lat, double lng);
}

/// Composición de [TransformacionGeoPixel.aPixeles] y [pixelesACanvas]:
/// ubica una coordenada geográfica directamente en el lienzo. Es lo que usan
/// tanto la cámara (`_moverCamara`) como el marcador "Estás aquí" del
/// `RoutePainter`, con cualquiera de los dos modelos.
({double x, double y}) geoACanvas(
  TransformacionGeoPixel transformacion, {
  required double lat,
  required double lng,
}) {
  final pixel = transformacion.aPixeles(lat, lng);
  return pixelesACanvas(pixel.x, pixel.y);
}

/// Modelo de transformación geo→píxel de dos puntos de control: dados dos
/// nodos de referencia con coordenadas geográficas y en píxeles conocidas
/// ([controlA], [controlB]), ubica proporcionalmente cualquier coordenada
/// geográfica en el mismo sistema de píxeles del grafo.
///
/// Es el modelo original de la app -no se elimina, está documentado y
/// justificado en la tesis, y es el que se usa por defecto
/// (`--dart-define=TRANSFORMACION=dospuntos`, o si no se pasa la bandera)-.
/// Encapsula tal cual el cálculo que antes vivía duplicado en
/// `_moverCamara` y en `RoutePainter.paint`, incluyendo la detección de
/// orientación dominante de la imagen.
class TransformacionDosPuntos implements TransformacionGeoPixel {
  final Nodo controlA;
  final Nodo controlB;

  const TransformacionDosPuntos({required this.controlA, required this.controlB});

  @override
  ({double x, double y}) aPixeles(double lat, double lng) {
    final double deltaPxX = (controlB.pixelX - controlA.pixelX).abs();
    final double deltaPxY = (controlB.pixelY - controlA.pixelY).abs();

    // La comparación original era (deltaPxX/deltaLat) > (deltaPxY/deltaLat):
    // ambos lados se dividen entre lo mismo (deltaLat), así que equivale a
    // comparar directamente las magnitudes en píxeles. Determina si la
    // latitud domina el eje X de la imagen o el eje Y -es decir, la
    // orientación/rotación real del mapa respecto a los ejes geográficos.
    final bool latControlaX = deltaPxX > deltaPxY;

    double nuevoPixelX;
    double nuevoPixelY;

    if (latControlaX) {
      final double pctLat = (lat - controlA.lat) / (controlB.lat - controlA.lat);
      final double pctLng = (lng - controlA.lng) / (controlB.lng - controlA.lng);
      nuevoPixelX =
          controlA.pixelX + (pctLat * (controlB.pixelX - controlA.pixelX));
      nuevoPixelY =
          controlA.pixelY + (pctLng * (controlB.pixelY - controlA.pixelY));
    } else {
      final double pctLng = (lng - controlA.lng) / (controlB.lng - controlA.lng);
      final double pctLat = (lat - controlA.lat) / (controlB.lat - controlA.lat);
      nuevoPixelX =
          controlA.pixelX + (pctLng * (controlB.pixelX - controlA.pixelX));
      nuevoPixelY =
          controlA.pixelY + (pctLat * (controlB.pixelY - controlA.pixelY));
    }

    return (x: nuevoPixelX, y: nuevoPixelY);
  }
}

/// Modelo de transformación geo→píxel afín, ajustado por mínimos cuadrados
/// sobre un conjunto de puntos de control:
///
/// ```
/// pixelX = a·xLocal + b·yLocal + c
/// pixelY = d·xLocal + e·yLocal + f
/// ```
///
/// donde (xLocal, yLocal) es la coordenada geográfica del punto convertida a
/// un plano local en metros ([aPlanoLocalMetros]) respecto al centroide de
/// los puntos de control -para evitar el mal condicionamiento numérico de
/// ajustar directamente sobre grados de latitud/longitud, que son casi
/// idénticos entre todos los nodos del campus-.
///
/// Devuelve píxeles en el mismo espacio y convención de ejes que
/// `coordenadas_pix`: el modelo afín absorbe de forma natural la rotación y
/// orientación del mapa dentro de sus 6 coeficientes (a diferencia del
/// modelo de dos puntos, no necesita decidir explícitamente qué eje
/// domina), pero el intercambio X/Y de [pixelesACanvas] sigue aplicándose
/// después, igual que con [TransformacionDosPuntos] -no se duplica ni se
/// elimina, es un paso universal posterior a cualquiera de los dos modelos.
class TransformacionAfin implements TransformacionGeoPixel {
  final double _a, _b, _c, _d, _e, _f;
  final double _latCentroide, _lngCentroide;
  final List<double> _residualesPx;

  TransformacionAfin._({
    required double a,
    required double b,
    required double c,
    required double d,
    required double e,
    required double f,
    required double latCentroide,
    required double lngCentroide,
    required List<double> residualesPx,
  })  : _a = a,
        _b = b,
        _c = c,
        _d = d,
        _e = e,
        _f = f,
        _latCentroide = latCentroide,
        _lngCentroide = lngCentroide,
        _residualesPx = residualesPx;

  /// Ajusta el modelo por mínimos cuadrados sobre [puntosControl] (al menos
  /// 3, no casi colineales). Cada punto aporta su coordenada geográfica
  /// (lat/lng) como entrada y su `pixelX`/`pixelY` -tal como están en
  /// `coordenadas_pix`- como objetivo del ajuste.
  factory TransformacionAfin.ajustar(List<Nodo> puntosControl) {
    if (puntosControl.length < 3) {
      throw ArgumentError(
          'Se necesitan al menos 3 puntos de control para ajustar una '
          'transformación afín (se recibieron ${puntosControl.length}).');
    }

    final int n = puntosControl.length;
    final double latCentroide =
        puntosControl.map((p) => p.lat).reduce((a, b) => a + b) / n;
    final double lngCentroide =
        puntosControl.map((p) => p.lng).reduce((a, b) => a + b) / n;

    final puntosLocales = puntosControl
        .map((p) => aPlanoLocalMetros(
            lat: p.lat,
            lng: p.lng,
            latReferencia: latCentroide,
            lngReferencia: lngCentroide))
        .toList();

    // Ecuaciones normales de mínimos cuadrados: la matriz de coeficientes
    // (S) es la misma para las dos regresiones (pixelX y pixelY), ya que
    // depende solo de las posiciones de entrada (xLocal, yLocal), no del
    // objetivo. Solo cambia el lado derecho del sistema.
    double s11 = 0, s12 = 0, s13 = 0, s22 = 0, s23 = 0;
    double rhsX1 = 0, rhsX2 = 0, rhsX3 = 0;
    double rhsY1 = 0, rhsY2 = 0, rhsY3 = 0;

    for (int i = 0; i < n; i++) {
      final double x = puntosLocales[i].x;
      final double y = puntosLocales[i].y;
      final double px = puntosControl[i].pixelX;
      final double py = puntosControl[i].pixelY;

      s11 += x * x;
      s12 += x * y;
      s13 += x;
      s22 += y * y;
      s23 += y;

      rhsX1 += x * px;
      rhsX2 += y * px;
      rhsX3 += px;

      rhsY1 += x * py;
      rhsY2 += y * py;
      rhsY3 += py;
    }

    final s = [
      [s11, s12, s13],
      [s12, s22, s23],
      [s13, s23, n.toDouble()],
    ];

    final List<double> betaX = _resolverSistema3x3(s, [rhsX1, rhsX2, rhsX3]);
    final List<double> betaY = _resolverSistema3x3(s, [rhsY1, rhsY2, rhsY3]);

    final transformacionSinResiduales = TransformacionAfin._(
      a: betaX[0],
      b: betaX[1],
      c: betaX[2],
      d: betaY[0],
      e: betaY[1],
      f: betaY[2],
      latCentroide: latCentroide,
      lngCentroide: lngCentroide,
      residualesPx: const [],
    );

    final List<double> residuales = puntosControl.map((p) {
      final predicho = transformacionSinResiduales.aPixeles(p.lat, p.lng);
      final double dx = predicho.x - p.pixelX;
      final double dy = predicho.y - p.pixelY;
      return sqrt(dx * dx + dy * dy);
    }).toList();

    return TransformacionAfin._(
      a: betaX[0],
      b: betaX[1],
      c: betaX[2],
      d: betaY[0],
      e: betaY[1],
      f: betaY[2],
      latCentroide: latCentroide,
      lngCentroide: lngCentroide,
      residualesPx: residuales,
    );
  }

  @override
  ({double x, double y}) aPixeles(double lat, double lng) {
    final local = aPlanoLocalMetros(
        lat: lat, lng: lng, latReferencia: _latCentroide, lngReferencia: _lngCentroide);
    return (
      x: _a * local.x + _b * local.y + _c,
      y: _d * local.x + _e * local.y + _f,
    );
  }

  /// Error de ajuste (en píxeles) de cada punto de control, en el mismo
  /// orden en que se pasaron a [TransformacionAfin.ajustar].
  List<double> residuales() => List.unmodifiable(_residualesPx);

  /// Raíz del error cuadrático medio (en píxeles) sobre los puntos de
  /// control usados para el ajuste.
  double rmse() {
    if (_residualesPx.isEmpty) return 0.0;
    final double sumaCuadrados =
        _residualesPx.fold(0.0, (acc, r) => acc + r * r);
    return sqrt(sumaCuadrados / _residualesPx.length);
  }
}

double _determinante3x3(List<List<double>> m) {
  return m[0][0] * (m[1][1] * m[2][2] - m[1][2] * m[2][1]) -
      m[0][1] * (m[1][0] * m[2][2] - m[1][2] * m[2][0]) +
      m[0][2] * (m[1][0] * m[2][1] - m[1][1] * m[2][0]);
}

/// Resuelve `s · beta = rhs` (sistema 3×3) por la regla de Cramer, sin
/// depender de una librería de álgebra lineal. Lanza [ArgumentError] si el
/// determinante de [s] es ~0: los puntos de control usados para construirlo
/// están casi colineales y no determinan un plano.
List<double> _resolverSistema3x3(List<List<double>> s, List<double> rhs) {
  final double det = _determinante3x3(s);
  if (det.abs() < 1e-9) {
    throw ArgumentError(
        'Los puntos de control están casi colineales: el sistema de '
        'ecuaciones normales no tiene una solución única (determinante '
        '≈ 0). Elige puntos de control más dispersos.');
  }

  final beta = <double>[];
  for (int columna = 0; columna < 3; columna++) {
    final m = [
      [s[0][0], s[0][1], s[0][2]],
      [s[1][0], s[1][1], s[1][2]],
      [s[2][0], s[2][1], s[2][2]],
    ];
    for (int fila = 0; fila < 3; fila++) {
      m[fila][columna] = rhs[fila];
    }
    beta.add(_determinante3x3(m) / det);
  }
  return beta;
}

/// Escala del mapa: cuántos píxeles del sistema de `coordenadas_pix`
/// (antes de aplicar [kFactorEscalaMapa], que es un paso de renderizado
/// posterior y no tiene relación con esto) corresponden a un metro real.
///
/// Se calcula empíricamente como la mediana de la razón (distancia en
/// píxeles / distancia de Haversine en metros) sobre todas las aristas del
/// grafo base -robusta a una o dos aristas mal digitalizadas- en vez de
/// usar un valor fijo, para que se mantenga consistente si cambian los
/// datos del campus. Sirve únicamente para reportar el error de los
/// modelos de transformación en metros además de en píxeles.
double calcularEscalaPxPorMetro(GrafoCampus grafoBase) {
  final razones = <double>[];
  final procesadas = <String>{};

  for (final origen in grafoBase.conexiones.keys) {
    final nodoA = grafoBase.nodos[origen];
    if (nodoA == null) continue;
    for (final destino in grafoBase.conexiones[origen]!.keys) {
      final String aristaId = origen.compareTo(destino) < 0
          ? '${origen}_$destino'
          : '${destino}_$origen';
      if (!procesadas.add(aristaId)) continue;

      final nodoB = grafoBase.nodos[destino];
      if (nodoB == null) continue;

      final double dx = nodoB.pixelX - nodoA.pixelX;
      final double dy = nodoB.pixelY - nodoA.pixelY;
      final double distanciaPx = sqrt(dx * dx + dy * dy);
      final double distanciaM = distanciaHaversineMetros(
          nodoA.lat, nodoA.lng, nodoB.lat, nodoB.lng);

      if (distanciaM > 0) razones.add(distanciaPx / distanciaM);
    }
  }

  if (razones.isEmpty) return 0.0;
  razones.sort();
  return razones[razones.length ~/ 2];
}

/// Evalúa un [TransformacionGeoPixel] contra un conjunto de nodos con
/// coordenadas geográficas y en píxeles conocidas (típicamente los 144
/// nodos base del campus, no solo los puntos de control usados para
/// ajustar): compara el píxel predicho contra `pixelX`/`pixelY` de cada
/// nodo y devuelve el error cuadrático medio en píxeles y en metros (con
/// [pxPorMetro] de [calcularEscalaPxPorMetro]).
({double rmsePx, double rmseMetros}) evaluarTransformacion(
  TransformacionGeoPixel transformacion,
  Iterable<Nodo> nodos, {
  required double pxPorMetro,
}) {
  final errores = nodos.map((nodo) {
    final predicho = transformacion.aPixeles(nodo.lat, nodo.lng);
    final double dx = predicho.x - nodo.pixelX;
    final double dy = predicho.y - nodo.pixelY;
    return dx * dx + dy * dy;
  }).toList();

  if (errores.isEmpty) return (rmsePx: 0.0, rmseMetros: 0.0);

  final double rmsePx =
      sqrt(errores.reduce((a, b) => a + b) / errores.length);
  final double rmseMetros = pxPorMetro > 0 ? rmsePx / pxPorMetro : 0.0;
  return (rmsePx: rmsePx, rmseMetros: rmseMetros);
}
