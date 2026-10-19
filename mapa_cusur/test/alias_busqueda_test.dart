import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mapa_cusur/data/alias_busqueda_parser.dart';
import 'package:mapa_cusur/data/diccionario_nombres.dart';
import 'package:mapa_cusur/data/ubicaciones_buscables.dart';
import 'package:mapa_cusur/domain/buscador_ubicaciones.dart';
import 'package:mapa_cusur/ui/widgets/autocomplete_input_field.dart';

const _laboratorio = 'Laboratorio de técnicas deportivas y de rescate';

/// Alias ficticios: solo existen en esta prueba, no se distribuyen.
final String _fixture =
    File('test/fixtures/alias_busqueda_prueba.json').readAsStringSync();

final Set<String> _idsBuscables = diccionarioNombres.keys.toSet();

void main() {
  group('parsearAliasBusqueda', () {
    test('lee los alias válidos e ignora el resto avisando', () {
      final avisos = <String>[];
      final alias = parsearAliasBusqueda(_fixture,
          idsValidos: _idsBuscables, advertir: avisos.add);

      expect(alias, {
        'CASA': ['bibli', 'La Biblio'],
        'Rectoria': ['rectoría central', 'Rectoria Central'],
        'Gimnasio': ['gimnasio', 'gym'],
        'Edificio_B': ['Bede'],
      });
      expect(avisos, hasLength(5));
      expect(avisos.where((a) => a.contains('"NoExiste"')), hasLength(1));
      expect(avisos.where((a) => a.contains('"R4"')), hasLength(1),
          reason: 'R4 es un nodo del grafo, pero no un lugar buscable');
      expect(avisos.where((a) => a.contains('"Edificio_M"')), hasLength(1));
      expect(avisos.where((a) => a.contains('"Edificio_B"')), hasLength(2));
    });

    test('archivo ausente, vacío o en blanco: sin alias y sin avisos', () {
      for (final contenido in [null, '', '   \n']) {
        final avisos = <String>[];
        expect(
            parsearAliasBusqueda(contenido,
                idsValidos: _idsBuscables, advertir: avisos.add),
            isEmpty);
        expect(avisos, isEmpty);
      }
    });

    test('JSON inválido o que no es un objeto: sin alias, con aviso', () {
      for (final contenido in ['{"CASA": [', '["bibli"]', '42', '{}']) {
        final avisos = <String>[];
        expect(
            parsearAliasBusqueda(contenido,
                idsValidos: _idsBuscables, advertir: avisos.add),
            isEmpty,
            reason: contenido);
        expect(avisos, hasLength(contenido == '{}' ? 0 : 1), reason: contenido);
      }
    });

    test('sin función de aviso tampoco falla', () {
      expect(parsearAliasBusqueda(_fixture, idsValidos: _idsBuscables),
          hasLength(4));
    });
  });

  group('assets/alias_busqueda.json real', () {
    final contenido =
        File('assets/alias_busqueda.json').readAsStringSync();

    test('tiene exactamente los IDs de diccionarioNombres, en orden', () {
      final data = json.decode(contenido) as Map<String, dynamic>;
      expect(data.keys.toList(), diccionarioNombres.keys.toList());
    });

    test('es válido: cada valor es una lista de textos, sin avisos', () {
      final avisos = <String>[];
      parsearAliasBusqueda(contenido,
          idsValidos: _idsBuscables, advertir: avisos.add);
      expect(avisos, isEmpty);
    });
  });

  group('ubicacionesBuscables con alias del JSON', () {
    final alias =
        parsearAliasBusqueda(_fixture, idsValidos: _idsBuscables);
    final lugares =
        ubicacionesBuscables(diccionarioNombres.keys, aliasExtra: alias);
    final buscador = BuscadorUbicaciones(lugares);

    test('combina nombresAlternativos y el JSON; un repetido cuenta una vez',
        () {
      final gimnasio = lugares.singleWhere((u) => u.id == 'Gimnasio');
      expect(gimnasio.alias, ['Gimnasio', 'gym']);
      final rectoria = lugares.singleWhere((u) => u.id == 'Rectoria');
      expect(rectoria.alias, ['rectoría central']);
    });

    test('un alias encuentra el lugar con su nombre oficial', () {
      final r = buscador.buscar('gym');
      expect(r.single.nombre, _laboratorio);
      expect(r.single.aliasCoincidente, 'gym');
      expect(r.single.nivel, NivelCoincidencia.exacta);
    });

    test('el alias se compara normalizado', () {
      final r = buscador.buscar('LA BIBLIO');
      expect(r.first.nombre, 'C.A.S.A. (Biblioteca)');
      expect(r.first.aliasCoincidente, 'La Biblio');
    });

    test('coincidencia por nombre y por alias: una sola vez, el mejor nivel',
        () {
      // "rectoria" es exacta por el nombre y "empieza con" por el alias.
      final r = buscador.buscar('rectoria');
      expect(r.single.nombre, 'Rectoría');
      expect(r.single.nivel, NivelCoincidencia.exacta);
      expect(r.single.aliasCoincidente, isNull);
      // "rectoria central" solo es exacta por el alias.
      final central = buscador.buscar('rectoria central');
      expect(central.single.aliasCoincidente, 'rectoría central');
    });

    test('un alias con mejor nivel que el nombre decide el nivel', () {
      // "bibli": por el nombre sería "palabras" (biblioteca); por el alias
      // es exacta.
      final r = buscador.buscar('bibli');
      expect(r.single.nombre, 'C.A.S.A. (Biblioteca)');
      expect(r.single.nivel, NivelCoincidencia.exacta);
    });
  });

  group('la barra muestra con qué alias coincidió', () {
    Future<void> escribir(WidgetTester tester, String texto) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: AutocompleteInputField(
            iconColor: Colors.red,
            title: 'Destino',
            placeholder: '¿A dónde vas?',
            suggestions: const [],
            buscador: BuscadorUbicaciones(
                ubicacionesBuscables(diccionarioNombres.keys)),
            onSelected: (_) {},
          ),
        ),
      ));
      await tester.enterText(find.byType(TextField), texto);
      await tester.pumpAndSettle();
    }

    testWidgets('por alias: nombre oficial y "coincide con"',
        (WidgetTester tester) async {
      await escribir(tester, 'gimn');
      expect(find.text(_laboratorio), findsOneWidget);
      expect(find.text('coincide con: Gimnasio'), findsOneWidget);
    });

    testWidgets('por nombre: sin "coincide con"', (WidgetTester tester) async {
      await escribir(tester, 'tecnicas');
      expect(find.text(_laboratorio), findsOneWidget);
      expect(find.textContaining('coincide con'), findsNothing);
    });
  });
}
