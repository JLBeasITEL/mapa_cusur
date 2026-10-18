// Fase 6c: reporte de las aristas del grafo cuyo segmento atraviesa el
// polígono de un edificio de assets/campus_vector.json, ordenadas por la
// longitud del tramo dentro del edificio. No modifica nada: solo escribe un
// CSV para que Juan Luis marque cuáles son pasillos reales y cuáles son
// cortes de esquina que necesitan un nodo intermedio.
//
// No corre con `flutter test` normal. Para generarlo:
//   REPORTE_ARISTAS=1 flutter test test/reporte_aristas_edificios_test.dart
// (o REPORTE_ARISTAS=<ruta del csv>). Por omisión escribe
// build/reporte_aristas_edificios.csv.
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mapa_cusur/data/campus_json_parser.dart';
import 'package:mapa_cusur/data/diccionario_nombres.dart';
import 'package:mapa_cusur/data/mapa_vectorial_parser.dart';
import 'package:mapa_cusur/domain/proyeccion_local.dart';
import 'package:mapa_cusur/models/mapa_vectorial.dart';

/// Un cruce: el tramo de la arista a-b dentro de un edificio.
typedef Cruce = ({
  String a,
  String b,
  double largoArista,
  double largoDentro,
  String edificio,
  String tipo,
  bool aDentro,
  bool bDentro,
});

bool _dentro(Offset p, List<List<Offset>> anillos) {
  var dentro = false;
  for (final anillo in anillos) {
    for (var i = 0, j = anillo.length - 1; i < anillo.length; j = i++) {
      final a = anillo[i], b = anillo[j];
      if ((a.dy > p.dy) != (b.dy > p.dy) &&
          p.dx < (b.dx - a.dx) * (p.dy - a.dy) / (b.dy - a.dy) + a.dx) {
        dentro = !dentro;
      }
    }
  }
  return dentro;
}

/// Longitud exacta del tramo del segmento p-q dentro de [anillos]: corta el
/// segmento en cada intersección con los bordes y suma los tramos cuyo
/// punto medio queda dentro.
double largoDentro(Offset p, Offset q, List<List<Offset>> anillos) {
  final d = q - p;
  final ts = <double>[0, 1];
  for (final anillo in anillos) {
    for (var i = 0; i < anillo.length - 1; i++) {
      final a = anillo[i], e = anillo[i + 1] - anillo[i];
      final den = d.dx * e.dy - d.dy * e.dx;
      if (den.abs() < 1e-12) continue; // paralelos
      final w = a - p;
      final t = (w.dx * e.dy - w.dy * e.dx) / den;
      final u = (w.dx * d.dy - w.dy * d.dx) / den;
      if (t > 0 && t < 1 && u >= 0 && u <= 1) ts.add(t);
    }
  }
  ts.sort();
  var total = 0.0;
  for (var i = 0; i < ts.length - 1; i++) {
    final medio = p + d * ((ts[i] + ts[i + 1]) / 2);
    if (_dentro(medio, anillos)) total += (ts[i + 1] - ts[i]) * d.distance;
  }
  return total;
}

/// Todos los cruces de aristas (sin repetir pares) con edificios.
List<Cruce> cruces(Map<String, dynamic> datosGrafo, MapaVectorial mapa) {
  final grafo = parsearGrafoCampus(datosGrafo);
  final proyeccion = ProyeccionLocal(mapa.meta);
  Offset local(String id) {
    final n = grafo.nodos[id]!;
    final p = proyeccion.geoALocal(n.lat, n.lng);
    return Offset(p.x, p.y);
  }

  final vistos = <String>{};
  final resultado = <Cruce>[];
  for (final arista in grafo.aristas) {
    final par = ([arista.origen, arista.destino]..sort()).join('|');
    if (arista.origen == arista.destino || !vistos.add(par)) continue;
    final a = par.split('|')[0], b = par.split('|')[1];
    final p = local(a), q = local(b);
    for (final e in mapa.edificios) {
      final dentro = largoDentro(p, q, e.anillos);
      if (dentro < 0.05) continue; // roces numéricos
      resultado.add((
        a: a,
        b: b,
        largoArista: (q - p).distance,
        largoDentro: dentro,
        edificio: e.nombre ?? (e.letra != null ? 'Edificio ${e.letra}' : '(sin nombre)'),
        tipo: e.tipo.name,
        aDentro: _dentro(p, e.anillos),
        bDentro: _dentro(q, e.anillos),
      ));
    }
  }
  resultado.sort((x, y) => y.largoDentro.compareTo(x.largoDentro));
  return resultado;
}

String _csv(String s) =>
    s.contains(',') || s.contains('"') ? '"${s.replaceAll('"', '""')}"' : s;

void main() {
  final destino = Platform.environment['REPORTE_ARISTAS'];

  test('largoDentro mide el tramo dentro de un cuadrado con hueco', () {
    final cuadrado = [
      const Offset(0, 0),
      const Offset(10, 0),
      const Offset(10, 10),
      const Offset(0, 10),
      const Offset(0, 0),
    ];
    final hueco = [
      const Offset(4, 4),
      const Offset(6, 4),
      const Offset(6, 6),
      const Offset(4, 6),
      const Offset(4, 4),
    ];
    // De lado a lado, por la mitad: 10 m menos 2 m de hueco.
    expect(largoDentro(const Offset(-5, 5), const Offset(15, 5),
        [cuadrado, hueco]), closeTo(8, 1e-9));
    // Empieza dentro: solo cuenta lo que queda dentro.
    expect(largoDentro(const Offset(8, 1), const Offset(20, 1), [cuadrado]),
        closeTo(2, 1e-9));
    // No lo toca.
    expect(largoDentro(const Offset(-5, -5), const Offset(-1, -1), [cuadrado]),
        0);
  });

  test('genera el reporte de aristas que cruzan edificios', () {
    final datos = json.decode(File('assets/campus_data.json').readAsStringSync())
        as Map<String, dynamic>;
    final mapa = parsearMapaVectorial(
        json.decode(File('assets/campus_vector.json').readAsStringSync()));
    final lista = cruces(datos, mapa);

    final ruta = (destino == null || destino == '1')
        ? 'build/reporte_aristas_edificios.csv'
        : destino;
    final filas = [
      'n,nodo_a,nombre_a,nodo_b,nombre_b,edificio,tipo_edificio,'
          'metros_dentro,metros_arista,porcentaje_dentro,'
          'a_dentro_del_edificio,b_dentro_del_edificio,clasificacion',
      for (final (i, c) in lista.indexed)
        [
          i + 1,
          c.a,
          _csv(diccionarioNombres[c.a] ?? ''),
          c.b,
          _csv(diccionarioNombres[c.b] ?? ''),
          _csv(c.edificio),
          c.tipo,
          c.largoDentro.toStringAsFixed(1),
          c.largoArista.toStringAsFixed(1),
          (100 * c.largoDentro / c.largoArista).toStringAsFixed(0),
          c.aDentro ? 'si' : 'no',
          c.bDentro ? 'si' : 'no',
          '', // para que Juan Luis marque: pasillo real / corte de esquina
        ].join(','),
    ];
    File(ruta)
      ..createSync(recursive: true)
      ..writeAsStringSync('${filas.join('\n')}\n');
    // ignore: avoid_print
    print('${lista.length} cruces de ${lista.map((c) => '${c.a}|${c.b}').toSet().length} '
        'aristas con ${lista.map((c) => c.edificio).toSet().length} edificios '
        '-> $ruta');
  },
      skip: destino == null
          ? 'Reporte bajo demanda: REPORTE_ARISTAS=1 flutter test '
              'test/reporte_aristas_edificios_test.dart'
          : false);
}
