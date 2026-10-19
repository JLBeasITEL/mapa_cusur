import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mapa_cusur/data/campus_json_parser.dart';
import 'package:mapa_cusur/data/campus_repository.dart';
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
      // Sobre la calibración congelada (copia exacta del campus_data.json de
      // v-pruebas-campo): es el dato de la versión documentada. El grafo
      // actual tiene su propia prueba abajo.
      final Map<String, dynamic> data =
          json.decode(File(kRutaCalibracion).readAsStringSync());
      final grafo = parsearGrafoCampus(data);

      final resultado = validarGrafo(grafo);

      // Estas cifras están verificadas y documentadas en REPORTE_DATOS.md.
      // Bajaron de 50/2/1 a 38/0/0 tras la corrección autorizada de las 7
      // aristas de Estacionamiento1/B1 y la eliminación del autolazo R4→R4
      // (ver REPORTE_DATOS.md, sección "Correcciones aplicadas").
      expect(resultado.aristasAsimetricas, hasLength(38));
      expect(resultado.pesosNoPositivos, isEmpty);
      expect(resultado.autolazos, isEmpty);
      expect(resultado.idsInexistentes, isEmpty);
      expect(resultado.componentesDesconectadas, isEmpty); // grafo conexo
      expect(resultado.pixelesDuplicados, isEmpty);
    });

    test('cifras exactas del grafo actual (assets/campus_data.json)', () {
      final Map<String, dynamic> data =
          json.decode(File('assets/campus_data.json').readAsStringSync());
      final grafo = parsearGrafoCampus(data);

      final resultado = validarGrafo(grafo);

      // 25: las 38 de la versión documentada menos trece que la Fase 6c
      // quitó: SP1→Cafeteria y SP3→Cafeteria (Bloque 1, la Cafetería
      // Pequeña pasó a destino sin paso), B3→M8 (Bloque 2, cruzaba el
      // Edificio B), R2→R4 (Bloque 3, cruzaba el Edificio R a lo largo), el
      // par X1→Edificio_X = 0.27 / Edificio_X→X1 = 0.40, de pesos distintos
      // (Bloque 4b, la diagonal no sigue el pasillo del Edificio X), L4→B2
      // (Bloque 5, se partió en LE7 y quedó en ambos sentidos) y, en el
      // Bloque 6 (revisión final de cruces), el par B1→Edificio_B = 0.22 /
      // Edificio_B→B1 = 0.63 (ahora rodea la esquina por B6), S2→S4 (va
      // por SN1), XV→Y4 (duplicaba el pasillo de X), Y3→Z4 y
      // Edificio_Y→Z2 (rodean Z por ZN2 y ZN1). Si este test empieza a
      // fallar, algo cambió en assets/campus_data.json sin que nadie lo
      // haya decidido explícitamente.
      expect(resultado.aristasAsimetricas, hasLength(25));
      final descripciones =
          resultado.aristasAsimetricas.map((p) => p.descripcion).join('\n');
      expect(descripciones, isNot(contains('Cafeteria')));
      expect(descripciones, isNot(contains('B3→M8')));
      expect(descripciones, isNot(contains('R2→R4')));
      expect(descripciones, isNot(contains('X1→Edificio_X')));
      expect(descripciones, isNot(contains('L4→B2')));
      for (final quitada in ['S2→S4', 'XV→Y4', 'Y3→Z4', 'Edificio_Y→Z2', 'B1→Edificio_B']) {
        expect(descripciones, isNot(contains(quitada)));
      }
      expect(resultado.pesosNoPositivos, isEmpty);
      expect(resultado.autolazos, isEmpty);
      expect(resultado.idsInexistentes, isEmpty);
      expect(resultado.componentesDesconectadas, isEmpty); // grafo conexo
      expect(resultado.pixelesDuplicados, isEmpty);
    });
  });
}
