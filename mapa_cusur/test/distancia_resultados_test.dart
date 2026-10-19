import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mapa_cusur/data/campus_json_parser.dart';
import 'package:mapa_cusur/data/diccionario_nombres.dart';
import 'package:mapa_cusur/data/mapa_vectorial_parser.dart';
import 'package:mapa_cusur/data/ubicaciones_buscables.dart';
import 'package:mapa_cusur/domain/area_mapa.dart';
import 'package:mapa_cusur/domain/buscador_ubicaciones.dart';
import 'package:mapa_cusur/models/ubicacion_buscable.dart';
import 'package:mapa_cusur/ui/widgets/autocomplete_input_field.dart';
import 'package:mapa_cusur/utils/formato_distancia.dart';
import 'package:mapa_cusur/utils/geodesia.dart';

List<String> _nombres(List<ResultadoBusqueda> r) =>
    [for (final x in r) x.nombre];

/// Lugares genéricos (no son datos del campus) sobre un mismo meridiano:
/// cada 0.001° de latitud son ~111 m.
UbicacionBuscable _lugar(String nombre, double lat) =>
    UbicacionBuscable(id: nombre, nombre: nombre, lat: lat, lng: -103.5);

const PosicionGeo _enCero = (lat: 0.0, lng: -103.5);

void main() {
  group('formatearDistanciaAproximada', () {
    test('menos de 1,000 m: redondeo a decenas', () {
      expect(formatearDistanciaAproximada(184), '≈ 180 m');
      expect(formatearDistanciaAproximada(185), '≈ 190 m');
      expect(formatearDistanciaAproximada(5), '≈ 10 m');
      expect(formatearDistanciaAproximada(4), '≈ 0 m');
      expect(formatearDistanciaAproximada(0), '≈ 0 m');
      expect(formatearDistanciaAproximada(994), '≈ 990 m');
    });

    test('1,000 m o más: km con un decimal', () {
      expect(formatearDistanciaAproximada(1000), '≈ 1.0 km');
      expect(formatearDistanciaAproximada(1234), '≈ 1.2 km');
      expect(formatearDistanciaAproximada(2049), '≈ 2.0 km');
      expect(formatearDistanciaAproximada(12345), '≈ 12.3 km');
    });

    test('lo que redondea a 1,000 m ya se muestra en km', () {
      expect(formatearDistanciaAproximada(995), '≈ 1.0 km');
      expect(formatearDistanciaAproximada(999.9), '≈ 1.0 km');
    });
  });

  group('estaDentroDelAreaDelMapa (meta.limites de campus_vector.json)', () {
    final meta = parsearMapaVectorial(json.decode(
            File('assets/campus_vector.json').readAsStringSync())
        as Map<String, dynamic>)
        .meta;

    /// Metros locales (x al este, y al sur) → geográficas.
    PosicionGeo geo(double x, double y) => (
          lat: meta.origenLat - y / meta.metrosPorGradoLat,
          lng: meta.origenLng + x / meta.metrosPorGradoLng,
        );

    bool dentro(PosicionGeo p, {double margen = kMargenAreaMapaMetros}) =>
        estaDentroDelAreaDelMapa(meta, p.lat, p.lng, margenMetros: margen);

    test('el margen empieza en 0', () {
      expect(kMargenAreaMapaMetros, 0);
    });

    test('el origen y los lugares del campus están dentro', () {
      expect(dentro(geo(0, 0)), isTrue);
      final grafo = parsearGrafoCampus(json.decode(
              File('assets/campus_data.json').readAsStringSync())
          as Map<String, dynamic>);
      for (final id in diccionarioNombres.keys) {
        final n = grafo.nodos[id]!;
        expect(dentro((lat: n.lat, lng: n.lng)), isTrue, reason: id);
      }
    });

    test('las orillas cuentan como dentro; un paso afuera, no', () {
      expect(dentro(geo(meta.maxX - 0.01, meta.minY + 0.01)), isTrue);
      expect(dentro(geo(meta.maxX + 1, 0)), isFalse);
      expect(dentro(geo(meta.minX - 1, 0)), isFalse);
      expect(dentro(geo(0, meta.maxY + 1)), isFalse);
      expect(dentro(geo(0, meta.minY - 1)), isFalse);
      expect(dentro(geo(1000, 1000)), isFalse);
    });

    test('el margen amplía la caja por cada lado', () {
      final afuera10m = geo(meta.maxX + 10, 0);
      expect(dentro(afuera10m), isFalse);
      expect(dentro(afuera10m, margen: 20), isTrue);
      expect(dentro(geo(0, meta.minY - 10), margen: 20), isTrue);
    });
  });

  group('distancia en el buscador', () {
    test('sin posición no hay distancia', () {
      final b = BuscadorUbicaciones([_lugar('Alfa', 0.001)]);
      expect(b.buscar('alfa').single.distanciaMetros, isNull);
    });

    test('con posición: la de Haversine en utils/geodesia.dart', () {
      final b = BuscadorUbicaciones([_lugar('Alfa', 0.001)]);
      final r = b.buscar('alfa', posicion: _enCero).single;
      expect(r.distanciaMetros,
          distanciaHaversineMetros(0, -103.5, 0.001, -103.5));
      expect(r.distanciaMetros, closeTo(111.2, 0.1));
    });

    test('dentro de un nivel, el más cercano primero', () {
      final b = BuscadorUbicaciones(
          [_lugar('Alfa Norte', 0.005), _lugar('Alfa Sur', 0.001)]);
      expect(_nombres(b.buscar('alfa')), ['Alfa Norte', 'Alfa Sur']);
      expect(_nombres(b.buscar('alfa', posicion: _enCero)),
          ['Alfa Sur', 'Alfa Norte']);
    });

    test('a igual distancia, alfabético', () {
      final b = BuscadorUbicaciones([
        _lugar('Alfa Zeta', 0.001),
        UbicacionBuscable(
            id: 'b', nombre: 'Alfa Beta', lat: -0.001, lng: -103.5),
      ]);
      expect(_nombres(b.buscar('alfa', posicion: _enCero)),
          ['Alfa Beta', 'Alfa Zeta']);
    });

    test('la distancia nunca sube un resultado sobre uno de mejor nivel', () {
      final b = BuscadorUbicaciones([
        _lugar('Alfa', 0.05), // exacta, a ~5.6 km
        _lugar('Alfa Cerca', 0.0001), // empieza con, a ~11 m
        _lugar('Gamma Alfa', 0.0), // palabras, a 0 m
      ]);
      expect(_nombres(b.buscar('alfa', posicion: _enCero)),
          ['Alfa', 'Alfa Cerca', 'Gamma Alfa']);
    });

    test('sin coordenadas, después de los que sí tienen', () {
      final b = BuscadorUbicaciones([
        const UbicacionBuscable(id: 'a', nombre: 'Alfa Ancla'),
        _lugar('Alfa Zona', 0.003),
      ]);
      final r = b.buscar('alfa', posicion: _enCero);
      expect(_nombres(r), ['Alfa Zona', 'Alfa Ancla']);
      expect(r.last.distanciaMetros, isNull);
    });

    test('aproximados: después de la distancia de edición, la cercanía', () {
      final b = BuscadorUbicaciones([
        _lugar('Paralelo Norte', 0.005),
        _lugar('Paralelo Sur', 0.001),
        _lugar('Paralel Cerca', 0.0),
      ]);
      final r = b.buscarAproximado('paralelox', posicion: _enCero);
      expect(_nombres(r), ['Paralelo Sur', 'Paralelo Norte', 'Paralel Cerca']);
      expect([for (final x in r) x.distanciaEdicion], [1, 1, 2]);
    });

    test('consultar pasa la posición; la sugerencia no la usa', () {
      final b = BuscadorUbicaciones([_lugar('Alfa', 0.001)]);
      expect(b.consultar('alfa', posicion: _enCero).resultados.single
          .distanciaMetros, isNotNull);
      expect(b.consultar('alfx', posicion: _enCero).sugerencia!
          .distanciaMetros, isNull);
    });
  });

  group('en el campus', () {
    final grafo = parsearGrafoCampus(
        json.decode(File('assets/campus_data.json').readAsStringSync())
            as Map<String, dynamic>);
    final buscador = BuscadorUbicaciones(
        ubicacionesBuscables(diccionarioNombres.keys, nodos: grafo.nodos));
    final entradaB = grafo.nodos['EntradaB']!;
    final enEntradaPrincipal = (lat: entradaB.lat, lng: entradaB.lng);

    test('cada lugar trae las coordenadas de su nodo', () {
      final rectoria = buscador.ubicacion('Rectoria')!;
      expect(rectoria.lat, grafo.nodos['Rectoria']!.lat);
      expect(rectoria.lng, grafo.nodos['Rectoria']!.lng);
    });

    test('parado en la Entrada Principal, es la entrada más cercana', () {
      final r = buscador.buscar('entrada', posicion: enEntradaPrincipal);
      expect(r.first.nombre, 'Entrada Principal');
      expect(r.first.distanciaMetros, 0);
      expect(r, hasLength(3));
      expect(r[1].distanciaMetros!, lessThanOrEqualTo(r[2].distanciaMetros!));
    });

    Future<void> escribir(
        WidgetTester tester, PosicionGeo? posicion, String texto) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: AutocompleteInputField(
            iconColor: Colors.red,
            title: 'Destino',
            placeholder: '¿A dónde vas?',
            suggestions: const [],
            buscador: buscador,
            posicion: posicion,
            onSelected: (_) {},
          ),
        ),
      ));
      await tester.enterText(find.byType(TextField), texto);
      await tester.pumpAndSettle();
    }

    testWidgets('con posición, cada resultado muestra "≈"',
        (WidgetTester tester) async {
      await escribir(tester, enEntradaPrincipal, 'entrada');
      expect(find.text('≈ 0 m'), findsOneWidget);
      expect(find.textContaining('≈'), findsNWidgets(3));
    });

    testWidgets('sin posición no se muestra distancia',
        (WidgetTester tester) async {
      await escribir(tester, null, 'entrada');
      expect(find.text('Entrada Principal'), findsOneWidget);
      expect(find.textContaining('≈'), findsNothing);
    });
  });
}
