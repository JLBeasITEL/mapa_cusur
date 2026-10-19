import 'package:flutter_test/flutter_test.dart';
import 'package:mapa_cusur/main.dart';

void main() {
  testWidgets('la app carga y muestra el panel de planificación de ruta',
      (WidgetTester tester) async {
    await tester.pumpWidget(const CampusNavigationApp());
    await tester.pump();

    expect(find.text('Tu Ruta'), findsOneWidget);
    expect(find.text('¿Dónde estás?'), findsOneWidget);
    expect(find.text('¿A dónde vas?'), findsOneWidget);
  });
}
