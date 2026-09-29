import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mapa_cusur/ui/widgets/panel_instrumentacion.dart';
import 'package:mapa_cusur/utils/cronometro.dart';

void main() {
  testWidgets('"Reiniciar cronómetro" borra las mediciones y refresca el panel',
      (WidgetTester tester) async {
    final cronometro = Cronometro();
    cronometro.medir('dijkstra', () => 0);
    cronometro.medir('dijkstra', () => 0);

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: PanelInstrumentacion(
          cronometro: cronometro,
          sesionActiva: null,
          rutaArchivoActivo: null,
          modoVerificacion: false,
          onIniciarSesion: () {},
          onDetenerSesion: () {},
          onCambiarModoVerificacion: (_) {},
        ),
      ),
    ));

    // El resumen de cada etiqueta incluye el número de mediciones.
    expect(find.textContaining('dijkstra — n=2'), findsOneWidget);

    await tester.tap(find.text('Reiniciar cronómetro'));
    await tester.pump();

    expect(cronometro.etiquetas, isEmpty);
    expect(find.textContaining('dijkstra'), findsNothing);
    expect(find.text('Sin mediciones todavía.'), findsOneWidget);
  });
}
