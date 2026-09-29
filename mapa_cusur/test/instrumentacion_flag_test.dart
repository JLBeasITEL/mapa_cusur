// Verifica que la instrumentación de campo (Fase 5) solo aparece con
// --dart-define=INSTRUMENTACION=true. Este archivo lee el mismo flag de
// compilación que `campus_map_screen.dart`, así que correrlo dos veces -sin
// la bandera y con `flutter test --dart-define=INSTRUMENTACION=true`-
// verifica ambos casos: sin la bandera, no debe encontrarse el botón; con
// ella, sí.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mapa_cusur/main.dart';

const bool _instrumentacionActiva = bool.fromEnvironment('INSTRUMENTACION');

void main() {
  testWidgets(
      'el botón de instrumentación aparece solo con '
      '--dart-define=INSTRUMENTACION=true (bandera actual: '
      '$_instrumentacionActiva)', (WidgetTester tester) async {
    await tester.pumpWidget(const CampusNavigationApp());
    await tester.pump();

    final botonInstrumentacion = find.byIcon(Icons.science);

    if (_instrumentacionActiva) {
      expect(botonInstrumentacion, findsOneWidget);
    } else {
      expect(botonInstrumentacion, findsNothing);
    }

    // Sin la bandera, la app debe verse exactamente como antes de la
    // Fase 5: solo la UI normal del panel de planificación.
    if (!_instrumentacionActiva) {
      expect(find.text('Tu Ruta'), findsOneWidget);
      expect(find.text('¿Dónde estás?'), findsOneWidget);
      expect(find.text('¿A dónde vas?'), findsOneWidget);
    }
  });
}
