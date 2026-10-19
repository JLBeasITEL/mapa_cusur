// Prueba de regresión de rutas (Fase 0, endurecida en Fase 1).
//
// Recalcula, con el código de producción real (lib/domain/interpolacion_nodos.dart
// + lib/domain/dijkstra.dart), los 1980 pares origen-destino entre los 45
// nodos con nombre amigable y los compara contra la línea base generada por
// tool/generar_linea_base.dart. Si esta prueba falla en cualquier fase
// posterior, la fase se revierte -salvo que el prompt haya autorizado
// explícitamente el cambio de comportamiento, en cuyo caso se regenera la
// línea base documentando por qué (ver MEJORAS.md y REPORTE_DATOS.md).
//
// Tolerancia: ±0.001 minutos y hash de ruta idéntico.
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mapa_cusur/data/campus_json_parser.dart';
import 'package:mapa_cusur/data/diccionario_nombres.dart';
import 'package:mapa_cusur/domain/dijkstra.dart';
import 'package:mapa_cusur/domain/interpolacion_nodos.dart';
import 'package:mapa_cusur/models/grafo_campus.dart';

import '../tool/hash_ruta.dart';

const double _tolerancia = 0.001;

class _FilaBase {
  final String origen;
  final String destino;
  final double? minutos; // null cuando la línea base marca "inalcanzable"
  final int numNodosRuta;
  final String hashRuta;
  _FilaBase(this.origen, this.destino, this.minutos, this.numNodosRuta,
      this.hashRuta);
}

List<String> _parsearLineaCsv(String linea) {
  final campos = <String>[];
  final actual = StringBuffer();
  bool dentroComillas = false;
  for (int i = 0; i < linea.length; i++) {
    final c = linea[i];
    if (dentroComillas) {
      if (c == '"') {
        if (i + 1 < linea.length && linea[i + 1] == '"') {
          actual.write('"');
          i++;
        } else {
          dentroComillas = false;
        }
      } else {
        actual.write(c);
      }
    } else {
      if (c == '"') {
        dentroComillas = true;
      } else if (c == ',') {
        campos.add(actual.toString());
        actual.clear();
      } else {
        actual.write(c);
      }
    }
  }
  campos.add(actual.toString());
  return campos;
}

List<_FilaBase> _cargarLineaBase(String contenidoCsv) {
  final lineas = const LineSplitter().convert(contenidoCsv);
  final filas = <_FilaBase>[];
  for (final linea in lineas.skip(1)) {
    if (linea.trim().isEmpty) continue;
    final campos = _parsearLineaCsv(linea);
    final origen = campos[0];
    final destino = campos[1];
    final minutosTexto = campos[2];
    final numNodos = int.parse(campos[3]);
    final hash = campos[4];
    final minutos = minutosTexto == 'inf' ? null : double.parse(minutosTexto);
    filas.add(_FilaBase(origen, destino, minutos, numNodos, hash));
  }
  return filas;
}

void main() {
  final fixturesDir = Directory('test/fixtures');
  final csvFile = File('test/fixtures/linea_base_rutas.csv');
  final grafoFile = File('test/fixtures/linea_base_grafo.json');

  if (!csvFile.existsSync() || !grafoFile.existsSync()) {
    test(
        'línea base presente (ejecuta dart run tool/generar_linea_base.dart primero)',
        () {
      fail('Faltan fixtures de línea base en ${fixturesDir.path}. '
          'Ejecuta: dart run tool/generar_linea_base.dart');
    });
    return;
  }

  final Map<String, dynamic> resumenBase =
      json.decode(grafoFile.readAsStringSync());
  final List<_FilaBase> filasBase = _cargarLineaBase(csvFile.readAsStringSync());

  final Map<String, String> nombreAId = {
    for (final entry in diccionarioNombres.entries) entry.value: entry.key,
  };

  group('Regresión de rutas contra la línea base', () {
    late GrafoCampus grafoBase;
    late GrafoCampus grafo;

    setUpAll(() {
      final Map<String, dynamic> data =
          json.decode(File('assets/campus_data.json').readAsStringSync());
      grafoBase = parsearGrafoCampus(data);
      grafo = interpolarGrafo(grafoBase);
    });

    test('cifras del grafo antes de interpolar coinciden con la línea base', () {
      int aristasAntes = 0;
      double pesoTotalAntes = 0;
      for (final arista in grafoBase.aristas) {
        aristasAntes++;
        pesoTotalAntes += arista.pesoMinutos;
      }

      expect(grafoBase.nodos.length, resumenBase['nodos_antes_interpolar']);
      expect(aristasAntes, resumenBase['aristas_antes_interpolar_dirigidas']);
      expect(pesoTotalAntes,
          closeTo((resumenBase['peso_total_antes'] as num).toDouble(), 1e-6));
    });

    test('cifras del grafo después de interpolar coinciden con la línea base',
        () {
      int aristasDespues = 0;
      double pesoTotalDespues = 0;
      for (final arista in grafo.aristas) {
        aristasDespues++;
        pesoTotalDespues += arista.pesoMinutos;
      }

      expect(grafo.nodos.length, resumenBase['nodos_despues_interpolar']);
      expect(
          aristasDespues, resumenBase['aristas_despues_interpolar_dirigidas']);
      expect(
          pesoTotalDespues,
          closeTo(
              (resumenBase['peso_total_despues'] as num).toDouble(), 1e-6));
    });

    test(
        'las ${filasBase.length} rutas entre nodos con nombre amigable no cambiaron',
        () {
      final fallos = <String>[];

      for (final fila in filasBase) {
        final idOrigen = nombreAId[fila.origen]!;
        final idDestino = nombreAId[fila.destino]!;
        final resultado = calcularRutaMasCorta(grafo, idOrigen, idDestino);

        if (fila.minutos == null) {
          if (!resultado.esVacia) {
            fallos.add('${fila.origen} -> ${fila.destino}: '
                'era inalcanzable y ahora existe ruta');
          }
          continue;
        }

        if (resultado.esVacia) {
          fallos.add('${fila.origen} -> ${fila.destino}: '
              'ahora es inalcanzable (antes ${fila.minutos} min)');
          continue;
        }

        if ((resultado.minutos - fila.minutos!).abs() > _tolerancia) {
          fallos.add('${fila.origen} -> ${fila.destino}: '
              '${fila.minutos} min -> ${resultado.minutos} min');
        }

        final hashActual = hashRuta(resultado.nodos);
        if (hashActual != fila.hashRuta) {
          fallos.add('${fila.origen} -> ${fila.destino}: '
              'hash de ruta cambió (${fila.hashRuta} -> $hashActual), '
              'num_nodos ${fila.numNodosRuta} -> ${resultado.nodos.length}');
        }
      }

      if (fallos.isNotEmpty) {
        fail('${fallos.length} rutas cambiaron respecto a la línea base:\n'
            '${fallos.take(30).join('\n')}'
            '${fallos.length > 30 ? '\n... (${fallos.length - 30} más)' : ''}');
      }
    });
  });
}
