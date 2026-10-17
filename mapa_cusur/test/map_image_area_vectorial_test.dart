import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mapa_cusur/data/campus_json_parser.dart';
import 'package:mapa_cusur/data/mapa_vectorial_parser.dart';
import 'package:mapa_cusur/domain/interpolacion_nodos.dart';
import 'package:mapa_cusur/domain/ubicacion_en_ruta.dart';
import 'package:mapa_cusur/models/grafo_campus.dart';
import 'package:mapa_cusur/models/mapa_vectorial.dart';
import 'package:mapa_cusur/ui/mapa/colores_mapa_vectorial.dart';
import 'package:mapa_cusur/ui/mapa/lienzo_mapa.dart';
import 'package:mapa_cusur/ui/painters/etiquetas_mapa_painter.dart';
import 'package:mapa_cusur/ui/painters/mapa_vectorial_painter.dart';
import 'package:mapa_cusur/ui/painters/route_painter.dart';
import 'package:mapa_cusur/ui/widgets/map_image_area.dart';

Map<String, dynamic> _leer(String ruta) =>
    json.decode(File(ruta).readAsStringSync()) as Map<String, dynamic>;

void main() {
  final GrafoCampus grafo =
      interpolarGrafo(parsearGrafoCampus(_leer('assets/campus_data.json')));
  final MapaVectorial mapa =
      parsearMapaVectorial(_leer('assets/campus_vector.json'));

  const ubicacion = UbicacionEnGrafo(
    aristaA: 'EntradaA',
    aristaB: 'EntradaA',
    t: 0,
    distanciaAlCaminoMetros: 0,
    lat: 19.72384,
    lng: -103.46214,
  );

  Widget area({required ModoMapa modo, MapaVectorial? datos}) => MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 400,
            height: 340,
            child: MapImageArea(
              ruta: const ['EntradaA', 'Edificio_M'],
              grafo: grafo,
              transformacion: null,
              markerImage: null,
              onNodoSeleccionado: (_, _) {},
              ubicacionGPS: ubicacion,
              disparadorZoom: 0,
              disparadorReinicioCamara: 0,
              modo: modo,
              mapaVectorial: datos,
            ),
          ),
        ),
      );

  bool pintaCon<T extends CustomPainter>(WidgetTester tester) => tester
      .widgetList<CustomPaint>(find.byType(CustomPaint))
      .any((c) => c.painter is T);

  group('MapImageArea en modo vectorial con los datos reales', () {
    testWidgets('pinta las tres capas y la atribución sin excepciones',
        (WidgetTester tester) async {
      await tester.pumpWidget(area(modo: ModoMapa.vectorial, datos: mapa));

      expect(tester.takeException(), isNull);
      expect(pintaCon<MapaVectorialPainter>(tester), isTrue);
      expect(pintaCon<EtiquetasMapaPainter>(tester), isTrue);
      expect(pintaCon<RoutePainter>(tester), isTrue);
      expect(find.text('© colaboradores de OpenStreetMap'), findsOneWidget);
      expect(
          tester
              .widget<Container>(find
                  .ancestor(
                      of: find.byType(LayoutBuilder),
                      matching: find.byType(Container))
                  .first)
              .color,
          ColoresMapaVectorial.fondo);
    });

    testWidgets('la capa estática va dentro de un RepaintBoundary',
        (WidgetTester tester) async {
      await tester.pumpWidget(area(modo: ModoMapa.vectorial, datos: mapa));

      final capaEstatica = find.byWidgetPredicate(
          (w) => w is CustomPaint && w.painter is MapaVectorialPainter);
      expect(
          find.ancestor(
              of: capaEstatica, matching: find.byType(RepaintBoundary)),
          findsWidgets);
    });

    testWidgets('sigue pintando sin excepciones al hacer zoom',
        (WidgetTester tester) async {
      await tester.pumpWidget(area(modo: ModoMapa.vectorial, datos: mapa));
      final controller = tester
          .widget<InteractiveViewer>(find.byType(InteractiveViewer))
          .transformationController!;

      for (final zoom in [1.5, kZoomDetalle, 4.0, 8.0]) {
        controller.value = Matrix4.identity()
          ..scaleByDouble(zoom, zoom, zoom, 1);
        await tester.pump();
        expect(tester.takeException(), isNull, reason: 'zoom $zoom');
      }
    });

    testWidgets('la atribución no aparece mientras no hay datos',
        (WidgetTester tester) async {
      await tester.pumpWidget(area(modo: ModoMapa.vectorial, datos: null));

      expect(tester.takeException(), isNull);
      expect(find.text('© colaboradores de OpenStreetMap'), findsNothing);
    });
  });

  group('botón de íconos', () {
    EtiquetasMapaPainter capaDeEtiquetas(WidgetTester tester) => tester
        .widgetList<CustomPaint>(find.byType(CustomPaint))
        .map((c) => c.painter)
        .whereType<EtiquetasMapaPainter>()
        .single;

    testWidgets('por defecto muestra los íconos y al tocarlo los oculta',
        (WidgetTester tester) async {
      await tester.pumpWidget(area(modo: ModoMapa.vectorial, datos: mapa));

      expect(find.byIcon(Icons.layers_rounded), findsOneWidget);
      expect(find.byTooltip('Ocultar íconos'), findsOneWidget);
      expect(find.bySemanticsLabel('Ocultar íconos'), findsOneWidget);
      expect(capaDeEtiquetas(tester).mostrarIconos, isTrue);

      await tester.tap(find.byIcon(Icons.layers_rounded));
      await tester.pump();

      expect(find.byTooltip('Mostrar íconos'), findsOneWidget);
      expect(find.bySemanticsLabel('Mostrar íconos'), findsOneWidget);
      expect(capaDeEtiquetas(tester).mostrarIconos, isFalse);

      await tester.tap(find.byIcon(Icons.layers_rounded));
      await tester.pump();

      expect(find.byTooltip('Ocultar íconos'), findsOneWidget);
      expect(capaDeEtiquetas(tester).mostrarIconos, isTrue);
    });

    testWidgets('va en la esquina superior derecha del mapa',
        (WidgetTester tester) async {
      await tester.pumpWidget(area(modo: ModoMapa.vectorial, datos: mapa));

      final boton = tester.getRect(find.byIcon(Icons.layers_rounded));
      final mapaRect = tester.getRect(find.byType(MapImageArea));
      expect(mapaRect.right - boton.right, lessThan(30));
      expect(boton.top - mapaRect.top, lessThan(30));
    });
  });

  testWidgets('en modo imagen no hay capas vectoriales ni atribución',
      (WidgetTester tester) async {
    await tester.pumpWidget(area(modo: ModoMapa.imagen, datos: mapa));

    expect(tester.takeException(), isNull);
    expect(pintaCon<MapaVectorialPainter>(tester), isFalse);
    expect(pintaCon<EtiquetasMapaPainter>(tester), isFalse);
    expect(find.text('© colaboradores de OpenStreetMap'), findsNothing);
    expect(find.byIcon(Icons.layers_rounded), findsNothing);
    expect(find.image(const AssetImage('assets/mapa_CUSur.png')),
        findsOneWidget);
  });
}
