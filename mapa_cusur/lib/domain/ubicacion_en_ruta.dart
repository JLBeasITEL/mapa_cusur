import 'dart:math';

import '../models/grafo_campus.dart';
import '../utils/geodesia.dart';

/// El resultado de proyectar ortogonalmente una posición GPS sobre la
/// arista (segmento del grafo) más cercana.
///
/// [t] es la posición a lo largo del segmento `aristaA -> aristaB`: 0 en
/// `aristaA`, 1 en `aristaB`. [lat]/[lng] son la coordenada geográfica del
/// punto proyectado (recortado a los extremos del segmento).
class UbicacionEnGrafo {
  final String aristaA;
  final String aristaB;
  final double t;
  final double distanciaAlCaminoMetros;
  final double lat;
  final double lng;

  const UbicacionEnGrafo({
    required this.aristaA,
    required this.aristaB,
    required this.t,
    required this.distanciaAlCaminoMetros,
    required this.lat,
    required this.lng,
  });

  /// El nodo extremo más cercano a lo largo del segmento -el que Dijkstra
  /// usa como punto de partida, ya que solo conoce nodos discretos-.
  String get nodoMasCercanoEnLaArista => t <= 0.5 ? aristaA : aristaB;
}

/// Proyecta ([lat], [lng]) ortogonalmente sobre la arista más cercana de
/// [grafo]. Para el segmento A-B y el punto P:
///
/// ```
/// t = clamp(((P-A)·(B-A)) / |B-A|², 0, 1)
/// proyección = A + t·(B-A)
/// ```
///
/// Trabaja en un plano local en metros ([aPlanoLocalMetros], sobre el mismo
/// [kRadioTierraMetros] que el resto del proyecto -no en grados, donde un
/// grado de longitud vale menos metros que uno de latitud fuera del
/// ecuador, lo que distorsionaría la proyección.
///
/// Devuelve `null` si [grafo] no tiene aristas.
///
/// No sustituye a los nodos fantasma: esta proyección se calcula sobre las
/// mismas aristas -incluidas las generadas por la interpolación- así que
/// gracias a su densidad (cada ≤8 m) el error entre "dónde cae la
/// proyección" y "qué arista es la correcta" ya es pequeño de por sí. Lo
/// que cambia es que ahora, dentro de esa arista, la posición ya no se
/// redondea al nodo discreto más cercano.
UbicacionEnGrafo? proyectarSobreArista(GrafoCampus grafo, double lat, double lng) {
  UbicacionEnGrafo? mejor;
  double distanciaMinima = double.infinity;
  final procesadas = <String>{};

  for (final origen in grafo.conexiones.keys) {
    final nodoA = grafo.nodos[origen];
    if (nodoA == null) continue;

    for (final destino in grafo.conexiones[origen]!.keys) {
      final String aristaId = origen.compareTo(destino) < 0
          ? '${origen}_$destino'
          : '${destino}_$origen';
      if (!procesadas.add(aristaId)) continue; // ya vista en sentido inverso

      final nodoB = grafo.nodos[destino];
      if (nodoB == null) continue;

      final p = aPlanoLocalMetros(
          lat: lat, lng: lng, latReferencia: nodoA.lat, lngReferencia: nodoA.lng);
      final b = aPlanoLocalMetros(
          lat: nodoB.lat,
          lng: nodoB.lng,
          latReferencia: nodoA.lat,
          lngReferencia: nodoA.lng);

      final double largoAlCuadrado = b.x * b.x + b.y * b.y;
      final double t = largoAlCuadrado == 0
          ? 0.0
          : ((p.x * b.x + p.y * b.y) / largoAlCuadrado).clamp(0.0, 1.0);

      final double dx = p.x - t * b.x;
      final double dy = p.y - t * b.y;
      final double distancia = sqrt(dx * dx + dy * dy);

      if (distancia < distanciaMinima) {
        distanciaMinima = distancia;
        mejor = UbicacionEnGrafo(
          aristaA: origen,
          aristaB: destino,
          t: t,
          distanciaAlCaminoMetros: distancia,
          lat: nodoA.lat + t * (nodoB.lat - nodoA.lat),
          lng: nodoA.lng + t * (nodoB.lng - nodoA.lng),
        );
      }
    }
  }

  return mejor;
}

/// Precisión máxima (en metros, el campo `accuracy` de `Position`) que
/// acepta una lectura de GPS. Lecturas menos precisas que esto se
/// descartan por completo: alimentarlas a la proyección o al suavizado solo
/// introduciría ruido.
const double kPrecisionMaximaMetros = 15.0;

bool lecturaGpsEsAceptable(
  double accuracyMetros, {
  double precisionMaximaMetros = kPrecisionMaximaMetros,
}) {
  return accuracyMetros <= precisionMaximaMetros;
}

/// Suaviza una secuencia de posiciones geográficas para atenuar el ruido
/// del GPS. Es una interfaz -no una clase concreta- para poder sustituir
/// [FiltroMediaMovil] por un filtro de Kalman más adelante sin tocar
/// ningún llamador.
abstract class FiltroPosicion {
  /// Registra una nueva lectura aceptada y devuelve la posición filtrada.
  ({double lat, double lng}) filtrar(double lat, double lng);

  /// Olvida el historial acumulado (usar al iniciar una nueva sesión de
  /// rastreo, para no mezclar posiciones de una sesión anterior).
  void reiniciar();
}

/// Tamaño por defecto de la ventana de la media móvil: cuántas de las
/// últimas lecturas aceptadas se promedian.
const int kTamanoVentanaMediaMovil = 3;

/// Media móvil simple sobre las últimas [n] posiciones aceptadas.
class FiltroMediaMovil implements FiltroPosicion {
  final int n;
  final List<({double lat, double lng})> _historial = [];

  FiltroMediaMovil({this.n = kTamanoVentanaMediaMovil});

  @override
  ({double lat, double lng}) filtrar(double lat, double lng) {
    _historial.add((lat: lat, lng: lng));
    if (_historial.length > n) _historial.removeAt(0);

    double sumaLat = 0;
    double sumaLng = 0;
    for (final p in _historial) {
      sumaLat += p.lat;
      sumaLng += p.lng;
    }
    return (lat: sumaLat / _historial.length, lng: sumaLng / _historial.length);
  }

  @override
  void reiniciar() => _historial.clear();
}

/// Distancia mínima, en metros, que el usuario debe alejarse de la última
/// ubicación usada para calcular la ruta -o cambiar de arista- antes de
/// recalcularla. Antes la ruta se recalculaba en cada actualización de GPS
/// (que llega cada metro); con este umbral, una caminata en línea recta
/// sobre la ruta ya trazada no dispara un recálculo en cada paso.
const double kUmbralRecalculoMetros = 20.0;

/// Decide si, al pasar de [ultimaUbicacionUsada] a [ubicacionActual], debe
/// recalcularse la ruta: si aún no había una ubicación previa, si el
/// usuario cambió de arista, o si se alejó más de [umbralMetros] de donde
/// estaba cuando se calculó la ruta vigente.
bool debeRecalcularRuta({
  required UbicacionEnGrafo? ultimaUbicacionUsada,
  required UbicacionEnGrafo ubicacionActual,
  double umbralMetros = kUmbralRecalculoMetros,
}) {
  final anterior = ultimaUbicacionUsada;
  if (anterior == null) return true;

  final bool mismaArista =
      (anterior.aristaA == ubicacionActual.aristaA &&
              anterior.aristaB == ubicacionActual.aristaB) ||
          (anterior.aristaA == ubicacionActual.aristaB &&
              anterior.aristaB == ubicacionActual.aristaA);
  if (!mismaArista) return true;

  final double distanciaRecorrida = distanciaHaversineMetros(
      anterior.lat, anterior.lng, ubicacionActual.lat, ubicacionActual.lng);
  return distanciaRecorrida > umbralMetros;
}
