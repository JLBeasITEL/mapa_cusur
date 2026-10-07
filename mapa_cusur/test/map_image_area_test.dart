import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mapa_cusur/ui/widgets/map_image_area.dart';

Widget _mapa({required int disparadorReinicioCamara}) => MaterialApp(
      home: Scaffold(
        body: MapImageArea(
          ruta: const [],
          grafo: null,
          transformacion: null,
          markerImage: null,
          onNodoSeleccionado: (_, _) {},
          ubicacionGPS: null,
          disparadorZoom: 0,
          disparadorReinicioCamara: disparadorReinicioCamara,
        ),
      ),
    );

void main() {
  testWidgets(
      'al aumentar disparadorReinicioCamara la cámara regresa a la identidad',
      (WidgetTester tester) async {
    await tester.pumpWidget(_mapa(disparadorReinicioCamara: 0));

    final controller = tester
        .widget<InteractiveViewer>(find.byType(InteractiveViewer))
        .transformationController!;
    // Simula una cámara con zoom y desplazada, como al seguir al usuario.
    controller.value = Matrix4.identity()
      ..translateByDouble(-250, -400, 0, 1)
      ..scaleByDouble(3, 3, 3, 1);
    expect(controller.value, isNot(Matrix4.identity()));

    await tester.pumpWidget(_mapa(disparadorReinicioCamara: 1));
    await tester.pumpAndSettle();

    expect(controller.value, Matrix4.identity());
  });
}
