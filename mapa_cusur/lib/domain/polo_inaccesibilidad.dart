import 'dart:math' as math;
import 'dart:ui' show Offset;

import '../utils/priority_queue.dart';

/// El polo de inaccesibilidad de un polígono: el centro del círculo más
/// grande que cabe dentro de él, y su radio (en las mismas unidades que
/// el polígono).
class PoloDeInaccesibilidad {
  final Offset centro;
  final double radio;

  const PoloDeInaccesibilidad(this.centro, this.radio);
}

/// Calcula el polo de inaccesibilidad de un polígono con huecos con el
/// algoritmo polylabel de Mapbox (github.com/mapbox/polylabel, licencia
/// ISC): cubre el polígono con celdas cuadradas y las va subdividiendo,
/// empezando por la que podría contener el círculo más grande, hasta que
/// ninguna celda pueda mejorar el resultado en más de [precision].
///
/// [anillos]: el primero es el contorno y los demás son huecos, que
/// cuentan como fuera del polígono. [exclusiones]: círculos que también
/// cuentan como fuera (por ejemplo, las insignias dibujadas sobre un
/// edificio): el resultado es el círculo libre más grande que cabe en el
/// polígono sin tocarlos.
PoloDeInaccesibilidad poloDeInaccesibilidad(
  List<List<Offset>> anillos, {
  double precision = 0.5,
  List<CirculoExcluido> exclusiones = const [],
}) {
  final zona = _Zona(anillos, exclusiones);
  final contorno = anillos.first;
  var minX = double.infinity, minY = double.infinity;
  var maxX = double.negativeInfinity, maxY = double.negativeInfinity;
  for (final p in contorno) {
    minX = math.min(minX, p.dx);
    minY = math.min(minY, p.dy);
    maxX = math.max(maxX, p.dx);
    maxY = math.max(maxY, p.dy);
  }
  final ancho = maxX - minX;
  final alto = maxY - minY;
  final tamanoCelda = math.min(ancho, alto);
  if (tamanoCelda == 0) return PoloDeInaccesibilidad(Offset(minX, minY), 0);

  // Primero la celda con el mayor radio posible.
  final cola = PriorityQueue<_Celda>((a, b) => b.maximo.compareTo(a.maximo));
  final mitad = tamanoCelda / 2;
  for (var x = minX; x < maxX; x += tamanoCelda) {
    for (var y = minY; y < maxY; y += tamanoCelda) {
      cola.add(_Celda(Offset(x + mitad, y + mitad), mitad, zona));
    }
  }

  // Primeros candidatos: el centroide y el centro de la caja.
  var mejor = _celdaCentroide(zona);
  final celdaCaja =
      _Celda(Offset(minX + ancho / 2, minY + alto / 2), 0, zona);
  if (celdaCaja.distancia > mejor.distancia) mejor = celdaCaja;

  while (cola.isNotEmpty) {
    final celda = cola.removeFirst();
    if (celda.distancia > mejor.distancia) mejor = celda;
    // Esta celda ya no puede dar un círculo mejor por más de la precisión.
    if (celda.maximo - mejor.distancia <= precision) continue;

    final h = celda.mitad / 2;
    final c = celda.centro;
    cola
      ..add(_Celda(c + Offset(-h, -h), h, zona))
      ..add(_Celda(c + Offset(h, -h), h, zona))
      ..add(_Celda(c + Offset(-h, h), h, zona))
      ..add(_Celda(c + Offset(h, h), h, zona));
  }

  return PoloDeInaccesibilidad(mejor.centro, mejor.distancia);
}

/// Un círculo que [poloDeInaccesibilidad] trata como fuera del polígono.
typedef CirculoExcluido = ({Offset centro, double radio});

/// El polígono y sus círculos excluidos.
class _Zona {
  final List<List<Offset>> anillos;
  final List<CirculoExcluido> exclusiones;

  const _Zona(this.anillos, this.exclusiones);
}

/// Distancia de [p] al borde de la zona libre de [poloDeInaccesibilidad]
/// (positiva dentro del polígono y fuera de los círculos excluidos;
/// negativa fuera). Sirve para medir el círculo libre alrededor de un
/// punto dado.
double distanciaLibre(Offset p, List<List<Offset>> anillos,
        {List<CirculoExcluido> exclusiones = const []}) =>
    _distanciaConSigno(p, _Zona(anillos, exclusiones));

class _Celda {
  final Offset centro;

  /// Mitad del lado de la celda.
  final double mitad;

  /// Distancia del centro al borde del polígono (negativa si está fuera).
  final double distancia;

  /// Radio máximo que podría tener un círculo con centro en esta celda.
  final double maximo;

  _Celda._(this.centro, this.mitad, this.distancia)
      : maximo = distancia + mitad * math.sqrt2;

  factory _Celda(Offset centro, double mitad, _Zona zona) =>
      _Celda._(centro, mitad, _distanciaConSigno(centro, zona));
}

/// Distancia de [p] al borde más cercano de la [zona]: positiva dentro del
/// polígono (fuera de los huecos y de los círculos excluidos) y negativa
/// fuera.
double _distanciaConSigno(Offset p, _Zona zona) {
  final anillos = zona.anillos;
  var dentro = false;
  var minimaAlCuadrado = double.infinity;
  for (final anillo in anillos) {
    for (var i = 0, j = anillo.length - 1; i < anillo.length; j = i++) {
      final a = anillo[i];
      final b = anillo[j];
      if ((a.dy > p.dy) != (b.dy > p.dy) &&
          p.dx < (b.dx - a.dx) * (p.dy - a.dy) / (b.dy - a.dy) + a.dx) {
        dentro = !dentro;
      }
      minimaAlCuadrado =
          math.min(minimaAlCuadrado, _distanciaAlSegmentoAlCuadrado(p, a, b));
    }
  }
  final distancia = math.sqrt(minimaAlCuadrado);
  var resultado = dentro ? distancia : -distancia;
  // Cada círculo excluido resta: dentro de él la distancia es negativa.
  for (final c in zona.exclusiones) {
    resultado = math.min(resultado, (p - c.centro).distance - c.radio);
  }
  return resultado;
}

double _distanciaAlSegmentoAlCuadrado(Offset p, Offset a, Offset b) {
  final ab = b - a;
  final largoAlCuadrado = ab.distanceSquared;
  var proyeccion = a;
  if (largoAlCuadrado > 0) {
    final t = (((p - a).dx * ab.dx + (p - a).dy * ab.dy) / largoAlCuadrado)
        .clamp(0.0, 1.0);
    proyeccion = a + ab * t;
  }
  return (p - proyeccion).distanceSquared;
}

/// Celda en el centroide del contorno (por área).
_Celda _celdaCentroide(_Zona zona) {
  final contorno = zona.anillos.first;
  var area = 0.0, x = 0.0, y = 0.0;
  for (var i = 0, j = contorno.length - 1; i < contorno.length; j = i++) {
    final a = contorno[i];
    final b = contorno[j];
    final f = a.dx * b.dy - b.dx * a.dy;
    x += (a.dx + b.dx) * f;
    y += (a.dy + b.dy) * f;
    area += f * 3;
  }
  if (area == 0) return _Celda(contorno.first, 0, zona);
  return _Celda(Offset(x / area, y / area), 0, zona);
}
