import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mapa_cusur/data/diccionario_nombres.dart';
import 'package:mapa_cusur/data/ubicaciones_buscables.dart';
import 'package:mapa_cusur/domain/buscador_ubicaciones.dart';
import 'package:mapa_cusur/domain/historial_recientes.dart';
import 'package:mapa_cusur/ui/widgets/autocomplete_input_field.dart';

const _validos = {'A', 'B', 'C', 'D', 'E', 'F', 'G'};

void main() {
  group('conReciente', () {
    test('pone el ID al principio', () {
      expect(conReciente(['A', 'B'], 'C'), ['C', 'A', 'B']);
      expect(conReciente([], 'A'), ['A']);
    });

    test('un repetido sube al primer lugar sin duplicarse', () {
      expect(conReciente(['A', 'B', 'C'], 'C'), ['C', 'A', 'B']);
      expect(conReciente(['A', 'B'], 'A'), ['A', 'B']);
    });

    test('se queda con los kMaxRecientes más recientes', () {
      expect(kMaxRecientes, 5);
      expect(conReciente(['A', 'B', 'C', 'D', 'E'], 'F'),
          ['F', 'A', 'B', 'C', 'D']);
    });
  });

  group('HistorialRecientes', () {
    test('agregar: del más al menos reciente, y lo guarda', () async {
      final almacen = AlmacenRecientesEnMemoria();
      final historial = HistorialRecientes(almacen);
      await historial.agregar('A');
      await historial.agregar('B');
      await historial.agregar('C');
      expect(historial.ids, ['C', 'B', 'A']);
      expect(almacen.ids, ['C', 'B', 'A']);
    });

    test('límite de 5', () async {
      final historial = HistorialRecientes(AlmacenRecientesEnMemoria());
      for (final id in ['A', 'B', 'C', 'D', 'E', 'F', 'G']) {
        await historial.agregar(id);
      }
      expect(historial.ids, ['G', 'F', 'E', 'D', 'C']);
    });

    test('sin duplicados: el repetido sube al primer lugar', () async {
      final historial = HistorialRecientes(AlmacenRecientesEnMemoria());
      for (final id in ['A', 'B', 'C', 'A']) {
        await historial.agregar(id);
      }
      expect(historial.ids, ['A', 'C', 'B']);
    });

    test('cargar descarta en silencio los IDs que ya no existen', () async {
      final almacen =
          AlmacenRecientesEnMemoria(['A', 'YaNoExiste', 'B', 'Otro']);
      final historial = HistorialRecientes(almacen);
      await historial.cargar(idsValidos: _validos);
      expect(historial.ids, ['A', 'B']);
    });

    test('cargar limpia repetidos y el exceso de un almacén corrupto',
        () async {
      final historial = HistorialRecientes(AlmacenRecientesEnMemoria(
          ['A', 'B', 'A', 'C', 'D', 'E', 'F', 'G']));
      await historial.cargar(idsValidos: _validos);
      expect(historial.ids, ['A', 'B', 'C', 'D', 'E']);
    });

    test('agregar justo después de empezar a cargar no se pierde', () async {
      final historial =
          HistorialRecientes(AlmacenRecientesEnMemoria(['A', 'B']));
      final carga = historial.cargar(idsValidos: _validos);
      final agregado = historial.agregar('C');
      await Future.wait([carga, agregado]);
      expect(historial.ids, ['C', 'A', 'B']);
    });

    test('borrar vacía el historial y lo guarda', () async {
      final almacen = AlmacenRecientesEnMemoria(['A', 'B']);
      final historial = HistorialRecientes(almacen);
      await historial.cargar(idsValidos: _validos);
      await historial.borrar();
      expect(historial.ids, isEmpty);
      expect(almacen.ids, isEmpty);
    });

    test('avisa a sus oyentes en cada cambio', () async {
      final historial = HistorialRecientes(AlmacenRecientesEnMemoria(['A']));
      var avisos = 0;
      historial.addListener(() => avisos++);
      await historial.cargar(idsValidos: _validos);
      await historial.agregar('B');
      await historial.borrar();
      expect(avisos, 3);
    });

    test('una carga que termina después de dispose no falla', () async {
      final historial = HistorialRecientes(AlmacenRecientesEnMemoria(['A']));
      final carga = historial.cargar(idsValidos: _validos);
      historial.dispose();
      await carga;
    });
  });

  group('la barra con recientes', () {
    final buscador =
        BuscadorUbicaciones(ubicacionesBuscables(diccionarioNombres.keys));
    late HistorialRecientes historial;
    late List<String> avisados;

    Widget campo(String titulo) => AutocompleteInputField(
          iconColor: Colors.red,
          title: titulo,
          placeholder: '¿A dónde vas?',
          suggestions: const [],
          buscador: buscador,
          historial: historial,
          onSelected: avisados.add,
        );

    Future<void> montar(WidgetTester tester, List<String> recientes) async {
      historial = HistorialRecientes(AlmacenRecientesEnMemoria(recientes));
      avisados = [];
      await historial.cargar(idsValidos: buscador.ids);
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: Column(children: [campo('Origen'), campo('Destino')]),
        ),
      ));
    }

    Finder textField(int i) => find.byType(TextField).at(i);

    testWidgets('al enfocar la barra vacía muestra los recientes',
        (WidgetTester tester) async {
      await montar(tester, ['Rectoria', 'CASA']);
      expect(find.text('Recientes'), findsNothing);

      await tester.tap(textField(1));
      await tester.pumpAndSettle();

      expect(find.text('Recientes'), findsOneWidget);
      expect(find.text('Borrar historial'), findsOneWidget);
      final rectoria = tester.getTopLeft(find.text('Rectoría'));
      final casa = tester.getTopLeft(find.text('C.A.S.A. (Biblioteca)'));
      expect(rectoria.dy, lessThan(casa.dy));
    });

    testWidgets('sin recientes no muestra la sección',
        (WidgetTester tester) async {
      await montar(tester, []);
      await tester.tap(textField(1));
      await tester.pumpAndSettle();
      expect(find.text('Recientes'), findsNothing);
    });

    testWidgets('elegir un reciente lo pone en el campo y lo sube',
        (WidgetTester tester) async {
      await montar(tester, ['Rectoria', 'CASA']);
      await tester.tap(textField(1));
      await tester.pumpAndSettle();

      await tester.tap(find.text('C.A.S.A. (Biblioteca)'));
      await tester.pumpAndSettle();

      expect(find.widgetWithText(TextField, 'C.A.S.A. (Biblioteca)'),
          findsOneWidget);
      expect(avisados, ['C.A.S.A. (Biblioteca)']);
      expect(historial.ids, ['CASA', 'Rectoria']);
    });

    testWidgets('elegir de los resultados lo guarda como reciente',
        (WidgetTester tester) async {
      await montar(tester, []);
      await tester.enterText(textField(1), 'rectoria');
      await tester.pumpAndSettle();
      await tester.tap(find.descendant(
          of: find.byType(ListView), matching: find.text('Rectoría')));
      await tester.pumpAndSettle();

      expect(historial.ids, ['Rectoria']);
    });

    testWidgets('lo escrito a mano no cuenta como reciente',
        (WidgetTester tester) async {
      await montar(tester, []);
      // El nombre exacto llega a la pantalla por onChanged, pero no se
      // eligió de la lista.
      await tester.enterText(textField(1), 'Rectoría');
      await tester.pumpAndSettle();
      expect(avisados.last, 'Rectoría');
      expect(historial.ids, isEmpty);
    });

    testWidgets('tocar "¿Quisiste decir...?" no cuenta como reciente',
        (WidgetTester tester) async {
      await montar(tester, []);
      await tester.enterText(textField(1), 'vivlioteka');
      await tester.pumpAndSettle();
      await tester.tap(
          find.textContaining('¿Quisiste decir', findRichText: true));
      await tester.pumpAndSettle();
      expect(avisados.last, 'C.A.S.A. (Biblioteca)');
      expect(historial.ids, isEmpty);
    });

    testWidgets('origen y destino comparten el historial',
        (WidgetTester tester) async {
      await montar(tester, []);
      await tester.enterText(textField(1), 'rectoria');
      await tester.pumpAndSettle();
      await tester.tap(find.descendant(
          of: find.byType(ListView), matching: find.text('Rectoría')));
      await tester.pumpAndSettle();

      await tester.tap(textField(0));
      await tester.pumpAndSettle();
      expect(find.text('Recientes'), findsOneWidget);
      expect(
          find.descendant(
              of: find.byType(ListView), matching: find.text('Rectoría')),
          findsOneWidget);
    });

    testWidgets('"Borrar historial" lo vacía y la sección desaparece',
        (WidgetTester tester) async {
      await montar(tester, ['Rectoria', 'CASA']);
      await tester.tap(textField(1));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Borrar historial'));
      await tester.pumpAndSettle();

      expect(historial.ids, isEmpty);
      expect(find.text('Recientes'), findsNothing);
      expect(find.text('Rectoría'), findsNothing);
    });

    testWidgets('un ID que ya no es un lugar no se muestra',
        (WidgetTester tester) async {
      await montar(tester, ['Rectoria']);
      // Agregado después de cargar (p. ej. con otra versión de los datos).
      await historial.agregar('YaNoExiste');
      await tester.tap(textField(1));
      await tester.pumpAndSettle();
      expect(find.text('Rectoría'), findsOneWidget);
      expect(find.text('YaNoExiste'), findsNothing);
    });
  });
}
