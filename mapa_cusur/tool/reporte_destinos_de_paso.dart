// Fase 6c: cuántas rutas de la línea base pasan a través de cada nodo con
// nombre (sin empezar ni terminar en él), con el código de producción
// (interpolarGrafo + calcularRutaMasCorta). No modifica nada: escribe
// build/fase6c/destinos_de_paso.json, que lee
// tool/graficar_destinos_de_paso.py para decidir qué destinos están dentro
// de su edificio.
//
// Uso: dart run tool/reporte_destinos_de_paso.dart
import 'dart:convert';
import 'dart:io';

import 'package:mapa_cusur/data/campus_json_parser.dart';
import 'package:mapa_cusur/data/diccionario_nombres.dart';
import 'package:mapa_cusur/domain/dijkstra.dart';
import 'package:mapa_cusur/domain/interpolacion_nodos.dart';

void main() {
  final base = parsearGrafoCampus(json.decode(
      File('assets/campus_data.json').readAsStringSync()) as Map<String, dynamic>);
  final grafo = interpolarGrafo(base);
  final ids = base.nodos.keys.where(diccionarioNombres.containsKey).toList()
    ..sort();

  final pasos = {for (final id in ids) id: 0};
  final transiciones = {for (final id in ids) id: <String, int>{}};
  final ejemplos = {for (final id in ids) id: <String>[]};
  var pares = 0;
  for (final a in ids) {
    for (final b in ids) {
      if (a == b) continue;
      pares++;
      final ruta = [
        for (final n in calcularRutaMasCorta(grafo, a, b).nodos)
          if (base.nodos.containsKey(n)) n,
      ];
      for (var i = 1; i < ruta.length - 1; i++) {
        final n = ruta[i];
        if (!pasos.containsKey(n)) continue;
        pasos[n] = pasos[n]! + 1;
        final t = '${ruta[i - 1]} → $n → ${ruta[i + 1]}';
        transiciones[n]![t] = (transiciones[n]![t] ?? 0) + 1;
        if (ejemplos[n]!.length < 3) {
          ejemplos[n]!.add('${diccionarioNombres[a]} → ${diccionarioNombres[b]}');
        }
      }
    }
  }

  final vecinos = <String, Set<String>>{};
  base.conexiones.forEach((o, vs) {
    for (final d in vs.keys) {
      (vecinos[o] ??= {}).add(d);
      (vecinos[d] ??= {}).add(o);
    }
  });
  final salida = {
    'pares': pares,
    'nodos': {
      for (final id in ids)
        id: {
          'nombre': diccionarioNombres[id],
          'vecinos': {
            for (final v in (vecinos[id] ?? <String>{}).toList()..sort())
              v: {
                'ida': base.conexiones[id]?[v],
                'vuelta': base.conexiones[v]?[id],
              },
          },
          'pares_que_pasan': pasos[id],
          'transiciones': Map.fromEntries(transiciones[id]!.entries.toList()
            ..sort((x, y) => y.value.compareTo(x.value))),
          'ejemplos': ejemplos[id],
        },
    },
  };
  final archivo = File('build/fase6c/destinos_de_paso.json')
    ..createSync(recursive: true)
    ..writeAsStringSync(const JsonEncoder.withIndent('  ').convert(salida));
  stdout.writeln('$pares pares, ${ids.length} nodos con nombre -> ${archivo.path}');
}
