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
import 'package:mapa_cusur/ui/widgets/boton_reset_zoom.dart';
import 'package:mapa_cusur/ui/widgets/map_image_area.dart';
import 'package:mapa_cusur/ui/widgets/panel_colapsable.dart';

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

  Widget mapaDe(
          {required ModoMapa modo,
          MapaVectorial? datos,
          UbicacionEnGrafo? gps = ubicacion,
          int disparadorZoom = 0}) =>
      MapImageArea(
        ruta: const ['EntradaA', 'Edificio_M'],
        grafo: grafo,
        transformacion: null,
        markerImage: null,
        onNodoSeleccionado: (_, _) {},
        ubicacionGPS: gps,
        disparadorZoom: disparadorZoom,
        disparadorReinicioCamara: 0,
        modo: modo,
        mapaVectorial: datos,
      );

  Widget area(
          {required ModoMapa modo,
          MapaVectorial? datos,
          double alto = 340,
          UbicacionEnGrafo? gps = ubicacion,
          int disparadorZoom = 0}) =>
      MaterialApp(
        home: Scaffold(
          body: Align(
            alignment: Alignment.topLeft,
            child: SizedBox(
              width: 400,
              height: alto,
              child: mapaDe(
                  modo: modo,
                  datos: datos,
                  gps: gps,
                  disparadorZoom: disparadorZoom),
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

      for (final zoom in [1.5, 1.8, 4.0, 8.0]) {
        controller.value = Matrix4.identity()
          ..scaleByDouble(zoom, zoom, zoom, 1);
        await tester.pump();
        expect(tester.takeException(), isNull, reason: 'zoom $zoom');
      }
    });

    testWidgets(
        'la atribución va arriba a la izquierda, en 9 px y sin capturar '
        'toques', (WidgetTester tester) async {
      await tester.pumpWidget(area(modo: ModoMapa.vectorial, datos: mapa));

      final texto = find.text('© colaboradores de OpenStreetMap');
      final mapaRect = tester.getRect(find.byType(MapImageArea));
      final caja = tester.getRect(find
          .ancestor(of: texto, matching: find.byType(Container))
          .first);
      expect(caja.topLeft - mapaRect.topLeft, const Offset(8, 8));
      expect(tester.widget<Text>(texto).style!.fontSize, 9);
      expect(
          find.ancestor(of: texto, matching: find.byType(IgnorePointer)),
          findsWidgets);
      expect(
          find.ancestor(of: texto, matching: find.byType(InteractiveViewer)),
          findsNothing);
    });

    testWidgets('el zoom máximo es ×12 en modo vectorial y ×8 en modo imagen',
        (WidgetTester tester) async {
      await tester.pumpWidget(area(modo: ModoMapa.vectorial, datos: mapa));
      expect(
          tester
              .widget<InteractiveViewer>(find.byType(InteractiveViewer))
              .maxScale,
          12);

      await tester.pumpWidget(area(modo: ModoMapa.imagen, datos: mapa));
      expect(
          tester
              .widget<InteractiveViewer>(find.byType(InteractiveViewer))
              .maxScale,
          8);
    });

    testWidgets('la capa de etiquetas recibe el tamaño del área del mapa',
        (WidgetTester tester) async {
      await tester.pumpWidget(area(modo: ModoMapa.vectorial, datos: mapa));

      final capa = tester
          .widgetList<CustomPaint>(find.byType(CustomPaint))
          .map((c) => c.painter)
          .whereType<EtiquetasMapaPainter>()
          .single;
      expect(capa.vista, const Size(400, 340));
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

  TransformationController controlador(WidgetTester tester) => tester
      .widget<InteractiveViewer>(find.byType(InteractiveViewer))
      .transformationController!;

  /// Escala de [zoom] alrededor del punto [foco] del área del mapa.
  Matrix4 zoomEn(double zoom, Offset foco) => Matrix4.identity()
    ..translateByDouble(foco.dx * (1 - zoom), foco.dy * (1 - zoom), 0, 1)
    ..scaleByDouble(zoom, zoom, zoom, 1);

  final Finder botonReset = find.byTooltip('Restablecer vista');

  group('botón de restablecer vista', () {
    testWidgets('no existe con la escala de la vista inicial',
        (WidgetTester tester) async {
      await tester.pumpWidget(area(modo: ModoMapa.vectorial, datos: mapa));
      await tester.pumpAndSettle();

      expect(botonReset, findsNothing);
      expect(find.byIcon(Icons.zoom_out), findsNothing);
    });

    testWidgets('no aparece por debajo del umbral (×$kUmbralEscalaConZoom)',
        (WidgetTester tester) async {
      await tester.pumpWidget(area(modo: ModoMapa.vectorial, datos: mapa));
      controlador(tester).value = zoomEn(1.01, const Offset(200, 170));
      await tester.pumpAndSettle();

      expect(botonReset, findsNothing);
    });

    testWidgets(
        'aparece tras hacer zoom con dos dedos, abajo a la izquierda del mapa',
        (WidgetTester tester) async {
      await tester.pumpWidget(area(modo: ModoMapa.vectorial, datos: mapa));
      final centro = tester.getCenter(find.byType(InteractiveViewer));

      final dedo1 = await tester.startGesture(centro - const Offset(20, 0));
      final dedo2 =
          await tester.startGesture(centro + const Offset(20, 0), pointer: 2);
      await tester.pump();
      for (int i = 0; i < 6; i++) {
        await dedo1.moveBy(const Offset(-10, 0));
        await dedo2.moveBy(const Offset(10, 0));
        await tester.pump(const Duration(milliseconds: 16));
      }
      await dedo1.up();
      await dedo2.up();
      await tester.pumpAndSettle();

      expect(controlador(tester).value.getMaxScaleOnAxis(),
          greaterThan(kUmbralEscalaConZoom));
      expect(botonReset, findsOneWidget);
      expect(find.bySemanticsLabel('Restablecer vista'), findsOneWidget);
      expect(find.byIcon(Icons.zoom_out), findsOneWidget);

      final boton = tester.getRect(find.byIcon(Icons.zoom_out));
      final mapaRect = tester.getRect(find.byType(MapImageArea));
      expect(boton.left - mapaRect.left, lessThan(30));
      expect(mapaRect.bottom - boton.bottom, lessThan(30));
    });

    testWidgets(
        'al pulsarlo anima de vuelta a la vista inicial (escala y posición) y '
        'desaparece', (WidgetTester tester) async {
      await tester.pumpWidget(area(modo: ModoMapa.vectorial, datos: mapa));
      controlador(tester).value = zoomEn(4, const Offset(300, 80));
      await tester.pumpAndSettle();
      expect(botonReset, findsOneWidget);

      await tester.tap(botonReset);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
      // A medio camino: ni un salto ni todavía en la identidad.
      final double aMitad = controlador(tester).value.getMaxScaleOnAxis();
      expect(aMitad, greaterThan(1.1));
      expect(aMitad, lessThan(4));

      await tester.pumpAndSettle();
      final m = controlador(tester).value;
      expect(m.getMaxScaleOnAxis(), moreOrLessEquals(1));
      expect(m.getTranslation().x, moreOrLessEquals(0));
      expect(m.getTranslation().y, moreOrLessEquals(0));
      expect(botonReset, findsNothing);
      // El toque fue del botón, no del mapa: no se abre el menú de nodo.
      expect(find.text('¿Qué deseas hacer con este punto?'), findsNothing);
    });

    testWidgets(
        'deja de seguir al GPS: una lectura nueva ya no mueve la cámara',
        (WidgetTester tester) async {
      await tester.pumpWidget(area(modo: ModoMapa.vectorial, datos: mapa));
      await tester.pumpWidget(
          area(modo: ModoMapa.vectorial, datos: mapa, disparadorZoom: 1));
      await tester.pumpAndSettle();
      expect(controlador(tester).value.getMaxScaleOnAxis(),
          moreOrLessEquals(3));

      // Con la cámara siguiendo al usuario, una lectura nueva la mueve.
      const otra = UbicacionEnGrafo(
        aristaA: 'EntradaA',
        aristaB: 'EntradaA',
        t: 0,
        distanciaAlCaminoMetros: 0,
        lat: 19.72420,
        lng: -103.46180,
      );
      final antes = controlador(tester).value.clone();
      await tester.pumpWidget(area(
          modo: ModoMapa.vectorial, datos: mapa, disparadorZoom: 1, gps: otra));
      await tester.pumpAndSettle();
      expect(controlador(tester).value, isNot(antes));

      await tester.tap(botonReset);
      await tester.pumpAndSettle();
      expect(controlador(tester).value.getMaxScaleOnAxis(),
          moreOrLessEquals(1));

      await tester.pumpWidget(
          area(modo: ModoMapa.vectorial, datos: mapa, disparadorZoom: 1));
      await tester.pumpAndSettle();
      expect(controlador(tester).value.getMaxScaleOnAxis(),
          moreOrLessEquals(1));
      expect(botonReset, findsNothing);

      // "Comenzar Ruta" (disparadorZoom) la vuelve a fijar en el usuario.
      await tester.pumpWidget(
          area(modo: ModoMapa.vectorial, datos: mapa, disparadorZoom: 2));
      await tester.pumpAndSettle();
      expect(controlador(tester).value.getMaxScaleOnAxis(),
          moreOrLessEquals(3));
    });

    testWidgets('en modo imagen no hay botón, aunque haya zoom',
        (WidgetTester tester) async {
      await tester.pumpWidget(area(modo: ModoMapa.imagen, datos: mapa));
      controlador(tester).value = zoomEn(4, const Offset(200, 170));
      await tester.pumpAndSettle();

      expect(botonReset, findsNothing);
    });
  });

  group('compensación al cambiar el tamaño del área con zoom', () {
    RenderBox lienzoRender(WidgetTester tester) => tester.renderObject(find
        .byWidgetPredicate(
            (w) => w is CustomPaint && w.painter is MapaVectorialPainter));

    /// Unidades de lienzo → píxeles de pantalla (el zoom efectivo).
    double pantallaPorLienzo(WidgetTester tester) {
      final caja = lienzoRender(tester);
      return (caja.localToGlobal(const Offset(100, 0)) -
                  caja.localToGlobal(Offset.zero))
              .dx /
          100;
    }

    /// El rectángulo del hijo del InteractiveViewer en pantalla: con la
    /// traslación dentro de los bordes, siempre cubre el área del mapa.
    Rect hijoEnPantalla(WidgetTester tester) {
      final RenderBox caja = tester.renderObject(find.byType(FittedBox));
      return Rect.fromPoints(caja.localToGlobal(Offset.zero),
          caja.localToGlobal(caja.size.bottomRight(Offset.zero)));
    }

    void verificarLimites(WidgetTester tester, {required String motivo}) {
      final mapaRect = tester.getRect(find.byType(MapImageArea));
      final hijo = hijoEnPantalla(tester);
      expect(controlador(tester).value.getMaxScaleOnAxis(),
          greaterThanOrEqualTo(1 - 1e-9),
          reason: motivo);
      expect(hijo.left, lessThanOrEqualTo(mapaRect.left + 1e-6),
          reason: motivo);
      expect(hijo.top, lessThanOrEqualTo(mapaRect.top + 1e-6), reason: motivo);
      expect(hijo.right, greaterThanOrEqualTo(mapaRect.right - 1e-6),
          reason: motivo);
      expect(hijo.bottom, greaterThanOrEqualTo(mapaRect.bottom - 1e-6),
          reason: motivo);
    }

    testWidgets(
        'conserva el punto del centro y el zoom efectivo en cada paso de un '
        'cambio de tamaño', (WidgetTester tester) async {
      await tester.pumpWidget(area(modo: ModoMapa.vectorial, datos: mapa));
      controlador(tester).value = zoomEn(3, const Offset(200, 170));
      await tester.pump();

      Offset centro() => tester.getRect(find.byType(MapImageArea)).center;
      final Offset punto = lienzoRender(tester).globalToLocal(centro());
      final double zoomEfectivo = pantallaPorLienzo(tester);

      // Como los frames de la animación del panel: crece y luego se encoge.
      for (final alto in [360.0, 420.0, 500.0, 560.0, 480.0, 340.0]) {
        await tester.pumpWidget(
            area(modo: ModoMapa.vectorial, datos: mapa, alto: alto));
        expect(tester.takeException(), isNull);
        final String motivo = 'alto $alto';
        expect(lienzoRender(tester).localToGlobal(punto).dx,
            moreOrLessEquals(centro().dx, epsilon: 1e-6),
            reason: motivo);
        expect(lienzoRender(tester).localToGlobal(punto).dy,
            moreOrLessEquals(centro().dy, epsilon: 1e-6),
            reason: motivo);
        expect(pantallaPorLienzo(tester),
            moreOrLessEquals(zoomEfectivo, epsilon: 1e-9),
            reason: motivo);
        verificarLimites(tester, motivo: motivo);
      }
    });

    testWidgets('sin zoom no toca la matriz: la identidad ya encuadra todo',
        (WidgetTester tester) async {
      await tester.pumpWidget(area(modo: ModoMapa.vectorial, datos: mapa));
      await tester.pumpWidget(
          area(modo: ModoMapa.vectorial, datos: mapa, alto: 560));

      expect(controlador(tester).value, Matrix4.identity());
      final mapaRect = tester.getRect(find.byType(MapImageArea));
      final lienzo = tester.getRect(find.byWidgetPredicate(
          (w) => w is CustomPaint && w.painter is MapaVectorialPainter));
      // Todo el mapa cabe en el área nueva y la llena a lo ancho o a lo alto.
      expect(mapaRect.contains(lienzo.topLeft), isTrue);
      expect(mapaRect.contains(lienzo.bottomRight - const Offset(1e-6, 1e-6)),
          isTrue);
      expect(
          lienzo.width == mapaRect.width || lienzo.height == mapaRect.height,
          isTrue);
    });

    testWidgets(
        'no baja de la escala 1: un zoom pequeño que ya no hace falta en el '
        'área grande vuelve a la vista inicial', (WidgetTester tester) async {
      await tester.pumpWidget(area(modo: ModoMapa.vectorial, datos: mapa));
      controlador(tester).value = zoomEn(1.1, const Offset(200, 170));
      await tester.pumpAndSettle();
      expect(botonReset, findsOneWidget);

      await tester.pumpWidget(
          area(modo: ModoMapa.vectorial, datos: mapa, alto: 700));
      await tester.pumpAndSettle();

      final m = controlador(tester).value;
      expect(m.getMaxScaleOnAxis(), 1);
      expect(m.getTranslation().x, 0);
      expect(m.getTranslation().y, 0);
      expect(botonReset, findsNothing);
    });

    testWidgets('con zoom en una esquina, la traslación no sale de los bordes',
        (WidgetTester tester) async {
      await tester.pumpWidget(area(modo: ModoMapa.vectorial, datos: mapa));
      controlador(tester).value = zoomEn(3, Offset.zero);
      await tester.pump();

      for (final alto in [420.0, 560.0, 380.0, 300.0]) {
        await tester.pumpWidget(
            area(modo: ModoMapa.vectorial, datos: mapa, alto: alto));
        verificarLimites(tester, motivo: 'esquina superior, alto $alto');
      }

      final double altoActual =
          tester.getSize(find.byType(MapImageArea)).height;
      controlador(tester).value = zoomEn(3, Offset(400, altoActual));
      await tester.pump();
      for (final alto in [420.0, 560.0, 380.0, 340.0]) {
        await tester.pumpWidget(
            area(modo: ModoMapa.vectorial, datos: mapa, alto: alto));
        verificarLimites(tester, motivo: 'esquina inferior, alto $alto');
      }
    });

    testWidgets(
        'dentro de PanelColapsable: el centro no brinca en ningún frame de la '
        'animación, y el botón sigue al panel', (WidgetTester tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: Align(
            alignment: Alignment.topLeft,
            child: SizedBox(
              width: 400,
              height: 600,
              child: PanelColapsable(
                alturaExpandida: 300,
                cuerpo: mapaDe(modo: ModoMapa.vectorial, datos: mapa),
                panel: const SizedBox.expand(),
              ),
            ),
          ),
        ),
      ));
      controlador(tester).value = zoomEn(3, const Offset(200, 150));
      await tester.pumpAndSettle();

      Offset centro() => tester.getRect(find.byType(MapImageArea)).center;
      final Offset punto = lienzoRender(tester).globalToLocal(centro());
      final double zoomEfectivo = pantallaPorLienzo(tester);

      Future<void> animarYVerificar(String asa) async {
        await tester.tap(find.bySemanticsLabel(asa));
        int frames = 0;
        do {
          await tester.pump(const Duration(milliseconds: 16));
          frames++;
          final String motivo = '$asa, frame $frames';
          final mapaRect = tester.getRect(find.byType(MapImageArea));
          expect(lienzoRender(tester).localToGlobal(punto).dx,
              moreOrLessEquals(centro().dx, epsilon: 1e-6),
              reason: motivo);
          expect(lienzoRender(tester).localToGlobal(punto).dy,
              moreOrLessEquals(centro().dy, epsilon: 1e-6),
              reason: motivo);
          expect(pantallaPorLienzo(tester),
              moreOrLessEquals(zoomEfectivo, epsilon: 1e-9),
              reason: motivo);
          verificarLimites(tester, motivo: motivo);
          // El botón siempre queda dentro del mapa, arriba del panel.
          final boton = tester.getRect(botonReset);
          expect(mapaRect.bottom - boton.bottom, moreOrLessEquals(14),
              reason: motivo);
        } while (tester.binding.hasScheduledFrame);
        expect(frames, greaterThan(5));
      }

      await animarYVerificar('Minimizar panel');
      expect(tester.getSize(find.byType(MapImageArea)).height,
          600 - kAlturaPanelColapsado);
      await animarYVerificar('Mostrar panel');
      expect(tester.getSize(find.byType(MapImageArea)).height, 600 - 300);
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
