import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mapa_cusur/data/campus_json_parser.dart';
import 'package:mapa_cusur/domain/validador_grafo.dart';
import 'package:mapa_cusur/models/grafo_campus.dart';
import 'package:mapa_cusur/models/nodo.dart';

GrafoCampus _grafo(
  Map<String, Map<String, double>> conexiones, {
  Map<String, (double, double)> pixeles = const {},
}) {
  final nodos = {
    for (final id in conexiones.keys)
      id: Nodo(
        id: id,
        lat: 0,
        lng: 0,
        pixelX: pixeles[id]?.$1 ?? conexiones.keys.toList().indexOf(id).toDouble(),
        pixelY: pixeles[id]?.$2 ?? 0,
      ),
  };
  return GrafoCampus(nodos: nodos, conexiones: conexiones);
}

void main() {
  group('validarGrafo — casos sintéticos (verifican que el validador '
      'detecta cada problema correctamente)', () {
    test('un grafo simétrico y bien formado no tiene problemas', () {
      final grafo = _grafo({
        'A': {'B': 1.0},
        'B': {'A': 1.0, 'C': 2.0},
        'C': {'B': 2.0},
      });

      final resultado = validarGrafo(grafo);

      expect(resultado.esValido, isTrue, reason: resultado.reporte());
    });

    test('detecta una arista sin su inversa', () {
      final grafo = _grafo({
        'A': {'B': 1.0},
        'B': {},
      });

      final resultado = validarGrafo(grafo);

      expect(resultado.aristasAsimetricas, hasLength(1));
      expect(resultado.esValido, isFalse);
    });

    test('detecta una arista cuya inversa tiene un peso distinto '
        '(cuenta las dos direcciones, igual que el criterio verificado '
        'contra los datos reales: ver REPORTE_DATOS.md)', () {
      final grafo = _grafo({
        'A': {'B': 1.0},
        'B': {'A': 0.5},
      });

      final resultado = validarGrafo(grafo);

      expect(resultado.aristasAsimetricas, hasLength(2));
    });

    test('detecta pesos no positivos', () {
      final grafo = _grafo({
        'A': {'B': 0.0},
        'B': {'A': -1.0},
      });

      final resultado = validarGrafo(grafo);

      expect(resultado.pesosNoPositivos, hasLength(2));
    });

    test('detecta pesos no finitos', () {
      final grafo = _grafo({
        'A': {'B': double.nan},
        'B': {'A': double.infinity},
      });

      final resultado = validarGrafo(grafo);

      expect(resultado.pesosNoFinitos, hasLength(2));
    });

    test('detecta un autolazo', () {
      final grafo = _grafo({
        'A': {'A': 0.0},
      });

      final resultado = validarGrafo(grafo);

      expect(resultado.autolazos, hasLength(1));
    });

    test('detecta componentes desconectadas', () {
      final grafo = _grafo({
        'A': {'B': 1.0},
        'B': {'A': 1.0},
        'X': {'Y': 1.0},
        'Y': {'X': 1.0},
      });

      final resultado = validarGrafo(grafo);

      expect(resultado.componentesDesconectadas, hasLength(1));
      expect(resultado.componentesDesconectadas.first.toString(), contains('2 nodo'));
    });

    test('detecta un ID inexistente referenciado desde una arista', () {
      final grafo = _grafo({
        'A': {'FantasmaQueNoExiste': 1.0},
      });

      final resultado = validarGrafo(grafo);

      expect(resultado.idsInexistentes, isNotEmpty);
    });

    test('detecta píxeles duplicados entre dos nodos distintos', () {
      final grafo = _grafo({
        'A': {'B': 1.0},
        'B': {'A': 1.0},
      }, pixeles: {
        'A': (10, 20),
        'B': (10, 20),
      });

      final resultado = validarGrafo(grafo);

      expect(resultado.pixelesDuplicados, hasLength(1));
    });

    test('reporte() lista los problemas encontrados de forma legible', () {
      final grafo = _grafo({
        'A': {'A': 0.0},
      });

      final resultado = validarGrafo(grafo);

      expect(resultado.reporte(), contains('Autolazos'));
      expect(resultado.reporte(), contains('A→A'));
    });
  });

  group('validarGrafo — assets/campus_data.json real', () {
    test(
        'el grafo real del campus NO pasa la validación de integridad hoy '
        '(reporte detallado de lo que falta corregir; ver REPORTE_DATOS.md '
        'para el análisis completo y el impacto en rutas de cada hallazgo)',
        () {
      final Map<String, dynamic> data =
          json.decode(File('assets/campus_data.json').readAsStringSync());
      final grafo = parsearGrafoCampus(data);

      final resultado = validarGrafo(grafo);

      // Se espera que esto falle hoy: es la constancia, dentro de la
      // suite de pruebas, de que el JSON real tiene problemas de
      // integridad sin resolver (regla de no regresión #8: no se corrigen
      // solos, es decisión humana). No bloquea el resto de la suite -cada
      // archivo de prueba corre independientemente-. Cuando se decida qué
      // corregir, este test debe volver a pasar solo.
      expect(resultado.esValido, isTrue,
          reason: 'El grafo real tiene ${resultado.totalProblemas} '
              'problemas de integridad sin resolver:\n${resultado.reporte()}');
    });

    test('cifras exactas de los problemas conocidos (para detectar si el '
        'inventario de REPORTE_DATOS.md queda desactualizado)', () {
      final Map<String, dynamic> data =
          json.decode(File('assets/campus_data.json').readAsStringSync());
      final grafo = parsearGrafoCampus(data);

      final resultado = validarGrafo(grafo);

      // Estas cifras están verificadas y documentadas en REPORTE_DATOS.md.
      // Bajaron de 50/2/1 a 38/0/0 tras la corrección autorizada de las 7
      // aristas de Estacionamiento1/B1 y la eliminación del autolazo R4→R4
      // (ver REPORTE_DATOS.md, sección "Correcciones aplicadas"). Si este
      // test empieza a fallar de nuevo, algo más cambió en
      // assets/campus_data.json sin que nadie lo haya decidido
      // explícitamente, y hay que actualizar ese documento.
      expect(resultado.aristasAsimetricas, hasLength(38));
      expect(resultado.pesosNoPositivos, isEmpty);
      expect(resultado.autolazos, isEmpty);
      expect(resultado.idsInexistentes, isEmpty);
      expect(resultado.componentesDesconectadas, isEmpty); // grafo conexo
      expect(resultado.pixelesDuplicados, isEmpty);
    });
  });
}
