import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mapa_cusur/data/diccionario_nombres.dart';
import 'package:mapa_cusur/ui/widgets/autocomplete_input_field.dart';

const _laboratorio = 'Laboratorio de técnicas deportivas y de rescate';

void main() {
  group('Gimnasio = Laboratorio de técnicas deportivas y de rescate', () {
    test('el nodo Gimnasio se muestra con el nombre del laboratorio', () {
      expect(diccionarioNombres['Gimnasio'], _laboratorio);
      expect(diccionarioNombres.values, isNot(contains('Gimnasio')));
    });

    test('el lugar se encuentra por ambos nombres', () {
      expect(idDeNombre(_laboratorio), 'Gimnasio');
      expect(idDeNombre('Gimnasio'), 'Gimnasio');
      expect(alternativosDe(_laboratorio), ['Gimnasio']);
    });

    test('un nombre desconocido no corresponde a ningún lugar', () {
      expect(idDeNombre('Alberca olímpica'), isNull);
      expect(alternativosDe('Biblioteca'), isEmpty);
    });

    test('ningún nombre alternativo choca con un nombre que se muestra', () {
      for (final alternativos in nombresAlternativos.values) {
        for (final nombre in alternativos) {
          expect(diccionarioNombres.values, isNot(contains(nombre)));
        }
      }
      for (final id in nombresAlternativos.keys) {
        expect(diccionarioNombres, contains(id));
      }
    });
  });

  testWidgets(
      'en el buscador, escribir "gimn" sugiere el laboratorio con su nombre '
      'visible', (WidgetTester tester) async {
    String? elegido;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: AutocompleteInputField(
          iconColor: Colors.red,
          title: 'Destino',
          placeholder: '¿A dónde vas?',
          suggestions: const [_laboratorio, 'Biblioteca'],
          onSelected: (v) => elegido = v,
        ),
      ),
    ));

    await tester.enterText(find.byType(TextField), 'gimn');
    await tester.pumpAndSettle();

    final opcion = find.descendant(
        of: find.byType(ListView), matching: find.text(_laboratorio));
    expect(opcion, findsOneWidget);
    expect(find.text('Biblioteca'), findsNothing);

    await tester.tap(opcion);
    await tester.pumpAndSettle();
    expect(elegido, _laboratorio);
  });
}
