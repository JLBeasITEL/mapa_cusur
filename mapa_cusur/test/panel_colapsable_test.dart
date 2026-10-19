import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mapa_cusur/ui/widgets/opciones_busqueda.dart';
import 'package:mapa_cusur/ui/widgets/panel_colapsable.dart';
import 'package:mapa_cusur/ui/widgets/planning_panel.dart';

const double _altoPantalla = 600;
const double _altoExpandido = 300;

const Key _claveCuerpo = Key('cuerpo');

Widget _envolver(Widget panel,
        {double alturaExpandida = _altoExpandido,
        double? alturaDisponible,
        double alto = _altoPantalla}) =>
    MaterialApp(
      home: Scaffold(
        body: Align(
          alignment: Alignment.topCenter,
          child: SizedBox(
            width: 400,
            height: alto,
            child: PanelColapsable(
              alturaExpandida: alturaExpandida,
              alturaDisponible: alturaDisponible,
              cuerpo: Container(key: _claveCuerpo, color: Colors.green),
              panel: panel,
            ),
          ),
        ),
      ),
    );

Widget _lista() => ListView(
      children: [
        for (int i = 0; i < 30; i++)
          SizedBox(height: 40, child: Text('fila $i')),
      ],
    );

final Finder _asaExpandida = find.bySemanticsLabel('Minimizar panel');
final Finder _asaColapsada = find.bySemanticsLabel('Mostrar panel');

double _altoCuerpo(WidgetTester tester) =>
    tester.getSize(find.byKey(_claveCuerpo)).height;

void main() {
  testWidgets('arranca expandido y el cuerpo ocupa el resto',
      (WidgetTester tester) async {
    await tester.pumpWidget(_envolver(_lista()));

    expect(_asaExpandida, findsOneWidget);
    expect(_altoCuerpo(tester), _altoPantalla - _altoExpandido);
  });

  testWidgets(
      'deslizar el handle hacia abajo lo minimiza y el cuerpo crece; hacia '
      'arriba lo restaura', (WidgetTester tester) async {
    await tester.pumpWidget(_envolver(_lista()));

    await tester.drag(_asaExpandida, const Offset(0, 300));
    await tester.pumpAndSettle();

    expect(_asaColapsada, findsOneWidget);
    expect(_altoCuerpo(tester), _altoPantalla - kAlturaPanelColapsado);
    // La franja con el handle sigue visible, pegada al borde inferior.
    final asa = tester.getRect(_asaColapsada);
    expect(asa.top, _altoPantalla - kAlturaPanelColapsado);

    await tester.drag(_asaColapsada, const Offset(0, -300));
    await tester.pumpAndSettle();

    expect(_asaExpandida, findsOneWidget);
    expect(_altoCuerpo(tester), _altoPantalla - _altoExpandido);
  });

  testWidgets('el panel sigue al dedo mientras se arrastra',
      (WidgetTester tester) async {
    await tester.pumpWidget(_envolver(_lista()));

    final gesto =
        await tester.startGesture(tester.getCenter(_asaExpandida));
    await gesto.moveBy(const Offset(0, 30)); // supera el slop
    await gesto.moveBy(const Offset(0, 60));
    await tester.pump();

    final double alto = _altoCuerpo(tester);
    expect(alto, greaterThan(_altoPantalla - _altoExpandido + 40));
    expect(alto, lessThan(_altoPantalla - kAlturaPanelColapsado));
    await gesto.up();
    await tester.pumpAndSettle();
  });

  testWidgets(
      'un arrastre corto y lento regresa a donde estaba; uno corto y rápido '
      'cambia de estado', (WidgetTester tester) async {
    await tester.pumpWidget(_envolver(_lista()));

    await tester.timedDrag(
        _asaExpandida, const Offset(0, 80), const Duration(seconds: 1));
    await tester.pumpAndSettle();
    expect(_asaExpandida, findsOneWidget);
    expect(_altoCuerpo(tester), _altoPantalla - _altoExpandido);

    await tester.fling(_asaExpandida, const Offset(0, 60), 1500);
    await tester.pumpAndSettle();
    expect(_asaColapsada, findsOneWidget);
    expect(_altoCuerpo(tester), _altoPantalla - kAlturaPanelColapsado);
  });

  testWidgets('la animación dura menos de 300 ms', (WidgetTester tester) async {
    await tester.pumpWidget(_envolver(_lista()));

    await tester.tap(_asaExpandida);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 140));
    final double aMitad = _altoCuerpo(tester);
    expect(aMitad, greaterThan(_altoPantalla - _altoExpandido));
    expect(aMitad, lessThan(_altoPantalla - kAlturaPanelColapsado));

    await tester.pump(const Duration(milliseconds: 160));
    expect(_altoCuerpo(tester), _altoPantalla - kAlturaPanelColapsado);
  });

  testWidgets('un tap en el handle alterna entre los dos estados',
      (WidgetTester tester) async {
    await tester.pumpWidget(_envolver(_lista()));

    await tester.tap(_asaExpandida);
    await tester.pumpAndSettle();
    expect(_asaColapsada, findsOneWidget);
    expect(_altoCuerpo(tester), _altoPantalla - kAlturaPanelColapsado);

    await tester.tap(_asaColapsada);
    await tester.pumpAndSettle();
    expect(_asaExpandida, findsOneWidget);
    expect(_altoCuerpo(tester), _altoPantalla - _altoExpandido);
  });

  testWidgets('al minimizar se quita el foco del campo de texto',
      (WidgetTester tester) async {
    final nodo = FocusNode();
    addTearDown(nodo.dispose);
    await tester.pumpWidget(_envolver(TextField(focusNode: nodo)));

    await tester.tap(find.byType(TextField));
    await tester.pump();
    expect(nodo.hasFocus, isTrue);

    await tester.drag(_asaExpandida, const Offset(0, 300));
    await tester.pumpAndSettle();
    expect(nodo.hasFocus, isFalse);
  });

  testWidgets(
      'arrastrar sobre el cuerpo o hacer scroll dentro del panel no lo mueve',
      (WidgetTester tester) async {
    await tester.pumpWidget(_envolver(_lista()));

    await tester.drag(find.byKey(_claveCuerpo), const Offset(0, 200));
    await tester.pumpAndSettle();
    expect(_asaExpandida, findsOneWidget);
    expect(_altoCuerpo(tester), _altoPantalla - _altoExpandido);

    await tester.drag(find.text('fila 2'), const Offset(0, -150));
    await tester.pumpAndSettle();
    expect(_asaExpandida, findsOneWidget);
    expect(_altoCuerpo(tester), _altoPantalla - _altoExpandido);
    // El scroll sí ocurrió.
    expect(find.text('fila 0'), findsNothing);

    await tester.drag(find.text('fila 6'), const Offset(0, 300));
    await tester.pumpAndSettle();
    expect(_asaExpandida, findsOneWidget);
  });

  testWidgets(
      'con alturaDisponible, el cuerpo no se encoge cuando el padre sí '
      '(teclado abierto): el panel lo tapa', (WidgetTester tester) async {
    // 600 sin teclado, 400 con él.
    await tester.pumpWidget(
        _envolver(_lista(), alturaDisponible: _altoPantalla, alto: 400));

    expect(_altoCuerpo(tester), _altoPantalla - _altoExpandido);
    final panel = tester.getRect(find.byType(ListView));
    expect(panel.bottom, 400);
  });

  testWidgets(
      'las sugerencias del autocompletado siguen pegadas al campo después de '
      'minimizar y restaurar', (WidgetTester tester) async {
    await tester.pumpWidget(_envolver(
      PlanningPanel(
        ubicaciones: const ['Biblioteca', 'Cafetería'],
        onCalcular: () {},
        onDetener: () {},
        navegando: false,
        onGpsPressed: () {},
        isTracking: false,
        tiempoEstimado: "",
        origenValue: "",
        destinoValue: "",
        mapTapKey: 0,
        onOrigenChanged: (_) {},
        onDestinoChanged: (_) {},
        onLimpiar: () {},
      ),
      alturaExpandida: 450,
    ));

    final Finder destino = find.byType(TextField).last;
    Future<Rect> abrirSugerencias(String texto) async {
      await tester.enterText(destino, texto);
      await tester.pumpAndSettle();
      expect(find.byType(OpcionesBusqueda), findsOneWidget);
      return tester.getRect(find.byType(OpcionesBusqueda));
    }

    final Rect antes = await abrirSugerencias('Bib');
    final Rect campoAntes = tester.getRect(destino);
    expect(antes.top, moreOrLessEquals(campoAntes.bottom, epsilon: 1));

    await tester.tap(_asaExpandida);
    await tester.pumpAndSettle();
    expect(find.byType(OpcionesBusqueda), findsNothing);

    await tester.tap(_asaColapsada);
    await tester.pumpAndSettle();

    final Rect despues = await abrirSugerencias('Bibl');
    expect(tester.getRect(destino), campoAntes);
    expect(despues.topLeft, antes.topLeft);
  });
}
