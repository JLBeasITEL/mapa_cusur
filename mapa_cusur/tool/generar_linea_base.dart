// Genera la línea base de rutas contra la que se compara cada fase del
// refactor (Fase 0, regla de no regresión #3).
//
// A partir de la Fase 1 usa directamente el código de producción
// (lib/data/campus_json_parser.dart, lib/domain/interpolacion_nodos.dart,
// lib/domain/dijkstra.dart, lib/data/diccionario_nombres.dart) en vez de una
// copia mantenida a mano: así la línea base nunca puede desincronizarse del
// comportamiento real de la app. Todos esos módulos son Dart puro (sin
// `package:flutter`), así que este script corre con `dart run` sin
// necesitar el binding de Flutter.
//
// Carga assets/campus_data.json, aplica la interpolación y ejecuta Dijkstra
// para todos los pares posibles entre los 45 nodos con nombre amigable
// (1980 pares), escribiendo:
//   - test/fixtures/linea_base_rutas.csv
//   - test/fixtures/linea_base_grafo.json
//
// Uso: dart run tool/generar_linea_base.dart
import 'dart:convert';
import 'dart:io';

import 'package:mapa_cusur/data/campus_json_parser.dart';
import 'package:mapa_cusur/data/diccionario_nombres.dart';
import 'package:mapa_cusur/domain/dijkstra.dart';
import 'package:mapa_cusur/domain/interpolacion_nodos.dart';
import 'package:mapa_cusur/models/grafo_campus.dart';

import 'hash_ruta.dart';

String csvEscape(String s) {
  if (s.contains(',') || s.contains('"') || s.contains('\n')) {
    return '"${s.replaceAll('"', '""')}"';
  }
  return s;
}

void main() {
  final jsonFile = File('assets/campus_data.json');
  final Map<String, dynamic> data = json.decode(jsonFile.readAsStringSync());

  final GrafoCampus grafoBase = parsearGrafoCampus(data);

  final int nodosAntes = grafoBase.nodos.length;
  int aristasAntes = 0;
  double pesoTotalAntes = 0;
  for (final arista in grafoBase.aristas) {
    aristasAntes++;
    pesoTotalAntes += arista.pesoMinutos;
  }

  final GrafoCampus grafo = interpolarGrafo(grafoBase);

  final int nodosDespues = grafo.nodos.length;
  int aristasDespues = 0;
  double pesoTotalDespues = 0;
  for (final arista in grafo.aristas) {
    aristasDespues++;
    pesoTotalDespues += arista.pesoMinutos;
  }

  stdout.writeln('Nodos antes de interpolar : $nodosAntes');
  stdout.writeln('Aristas antes de interpolar (dirigidas) : $aristasAntes');
  stdout.writeln('Peso total antes: ${pesoTotalAntes.toStringAsFixed(4)}');
  stdout.writeln('Nodos después de interpolar : $nodosDespues');
  stdout.writeln('Aristas después de interpolar (dirigidas): $aristasDespues');
  stdout.writeln('Peso total después: ${pesoTotalDespues.toStringAsFixed(4)}');

  final List<String> idsConNombre = grafoBase.nodos.keys
      .where((id) => diccionarioNombres.containsKey(id))
      .toList()
    ..sort();

  stdout.writeln('Nodos con nombre amigable: ${idsConNombre.length}');

  final buffer = StringBuffer();
  buffer.writeln('origen,destino,minutos,num_nodos_ruta,hash_ruta');

  int pares = 0;
  int inalcanzables = 0;
  final stopwatch = Stopwatch()..start();

  for (final idOrigen in idsConNombre) {
    for (final idDestino in idsConNombre) {
      if (idOrigen == idDestino) continue;
      pares++;
      final resultado = calcularRutaMasCorta(grafo, idOrigen, idDestino);
      final nombreOrigen = diccionarioNombres[idOrigen]!;
      final nombreDestino = diccionarioNombres[idDestino]!;
      if (resultado.esVacia) {
        inalcanzables++;
        buffer.writeln('${csvEscape(nombreOrigen)},${csvEscape(nombreDestino)}'
            ',inf,0,inalcanzable');
        continue;
      }
      buffer.writeln(
          '${csvEscape(nombreOrigen)},${csvEscape(nombreDestino)},'
          '${resultado.minutos.toStringAsFixed(6)},${resultado.nodos.length},'
          '${hashRuta(resultado.nodos)}');
    }
  }
  stopwatch.stop();

  stdout.writeln('Pares calculados: $pares (inalcanzables: $inalcanzables) '
      'en ${stopwatch.elapsedMilliseconds} ms');

  final fixturesDir = Directory('test/fixtures');
  if (!fixturesDir.existsSync()) fixturesDir.createSync(recursive: true);

  File('test/fixtures/linea_base_rutas.csv')
      .writeAsStringSync(buffer.toString());

  final resumenGrafo = {
    'nodos_antes_interpolar': nodosAntes,
    'aristas_antes_interpolar_dirigidas': aristasAntes,
    'peso_total_antes': pesoTotalAntes,
    'nodos_despues_interpolar': nodosDespues,
    'aristas_despues_interpolar_dirigidas': aristasDespues,
    'peso_total_despues': pesoTotalDespues,
    'nodos_con_nombre_amigable': idsConNombre.length,
    'pares_calculados': pares,
    'pares_inalcanzables': inalcanzables,
  };
  File('test/fixtures/linea_base_grafo.json').writeAsStringSync(
      const JsonEncoder.withIndent('  ').convert(resumenGrafo));

  stdout.writeln('Escrito test/fixtures/linea_base_rutas.csv');
  stdout.writeln('Escrito test/fixtures/linea_base_grafo.json');
}
