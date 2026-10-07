import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mapa_cusur/ui/widgets/autocomplete_input_field.dart';
import 'package:mapa_cusur/ui/widgets/planning_panel.dart';

Widget _envolver(Widget hijo) => MaterialApp(home: Scaffold(body: hijo));

PlanningPanel _panel({
  String origen = "",
  String destino = "",
  bool rastreando = false,
  VoidCallback? onLimpiar,
}) {
  return PlanningPanel(
    ubicaciones: const ['Biblioteca', 'Cafetería'],
    onCalcular: () {},
    onGpsPressed: () {},
    isTracking: rastreando,
    tiempoEstimado: "",
    origenValue: origen,
    destinoValue: destino,
    mapTapKey: 0,
    onOrigenChanged: (_) {},
    onDestinoChanged: (_) {},
    onLimpiar: onLimpiar ?? () {},
  );
}

void main() {
  group('AutocompleteInputField', () {
    testWidgets('el ícono de borrar aparece solo cuando hay texto',
        (WidgetTester tester) async {
      await tester.pumpWidget(_envolver(AutocompleteInputField(
        iconColor: Colors.red,
        title: 'Destino',
        placeholder: '¿A dónde vas?',
        suggestions: const ['Biblioteca'],
        onSelected: (_) {},
      )));

      expect(find.byIcon(Icons.cancel), findsNothing);

      await tester.enterText(find.byType(TextField), 'Bib');
      await tester.pump();
      expect(find.byIcon(Icons.cancel), findsOneWidget);
    });

    testWidgets('tocar el ícono vacía el campo y notifica ""',
        (WidgetTester tester) async {
      final valores = <String>[];
      await tester.pumpWidget(_envolver(AutocompleteInputField(
        iconColor: Colors.red,
        title: 'Destino',
        placeholder: '¿A dónde vas?',
        suggestions: const ['Biblioteca'],
        initialValue: 'Biblioteca',
        onSelected: valores.add,
      )));

      await tester.tap(find.byIcon(Icons.cancel));
      await tester.pump();

      expect(valores, [""]);
      expect(find.byIcon(Icons.cancel), findsNothing);
      final campo = tester.widget<TextField>(find.byType(TextField));
      expect(campo.controller!.text, isEmpty);
      expect(campo.focusNode!.hasFocus, isFalse);
    });
  });

  group('PlanningPanel — Limpiar', () {
    testWidgets('no aparece si no hay nada que limpiar',
        (WidgetTester tester) async {
      await tester.pumpWidget(_envolver(_panel()));
      expect(find.text('Limpiar'), findsNothing);
    });

    testWidgets('aparece con origen, con destino o con GPS activo',
        (WidgetTester tester) async {
      for (final panel in [
        _panel(origen: 'Biblioteca'),
        _panel(destino: 'Cafetería'),
        _panel(rastreando: true),
      ]) {
        await tester.pumpWidget(_envolver(panel));
        expect(find.text('Limpiar'), findsOneWidget);
      }
    });

    testWidgets('tocarlo llama a onLimpiar', (WidgetTester tester) async {
      var llamadas = 0;
      await tester.pumpWidget(
          _envolver(_panel(destino: 'Cafetería', onLimpiar: () => llamadas++)));
      await tester.tap(find.text('Limpiar'));
      expect(llamadas, 1);
    });
  });
}
