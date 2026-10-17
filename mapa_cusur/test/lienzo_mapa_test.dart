import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mapa_cusur/data/campus_json_parser.dart';
import 'package:mapa_cusur/data/mapa_vectorial_parser.dart';
import 'package:mapa_cusur/domain/interpolacion_nodos.dart';
import 'package:mapa_cusur/domain/proyeccion_local.dart';
import 'package:mapa_cusur/domain/transformacion_geo.dart';
import 'package:mapa_cusur/domain/ubicacion_en_ruta.dart';
import 'package:mapa_cusur/models/grafo_campus.dart';
import 'package:mapa_cusur/models/mapa_vectorial.dart';
import 'package:mapa_cusur/ui/mapa/lienzo_mapa.dart';
import 'package:mapa_cusur/ui/widgets/map_image_area.dart';

Map<String, dynamic> _leer(String ruta) =>
    json.decode(File(ruta).readAsStringSync()) as Map<String, dynamic>;

void main() {
  final GrafoCampus grafoBase =
      parsearGrafoCampus(_leer('assets/campus_data.json'));
  final GrafoCampus grafo = interpolarGrafo(grafoBase);
  final MapaVectorial mapa =
      parsearMapaVectorial(_leer('assets/campus_vector.json'));
  final dosPuntos = TransformacionDosPuntos(
    controlA: grafoBase.nodos['EntradaA']!,
    controlB: grafoBase.nodos['Edificio_M']!,
  );

  group('LienzoImagen (debe reproducir exactamente el cálculo de siempre)', () {
    test('nodoALienzo es pixelesACanvas para todos los nodos', () {
      const lienzo = LienzoImagen(null);
      for (final nodo in grafo.nodos.values) {
        final esperado = pixelesACanvas(nodo.pixelX, nodo.pixelY);

        expect(lienzo.nodoALienzo(nodo), Offset(esperado.x, esperado.y),
            reason: nodo.id);
      }
    });

    test('geoALienzo es null sin modelo de transformación', () {
      expect(const LienzoImagen(null).geoALienzo(19.7245, -103.4618), isNull);
    });

    test('geoALienzo es geoACanvas con el modelo activo', () {
      final lienzo = LienzoImagen(dosPuntos);
      for (final (lat, lng) in [
        (19.7245, -103.4618),
        (19.72384, -103.46214),
        (19.72584, -103.46008),
      ]) {
        final esperado = geoACanvas(dosPuntos, lat: lat, lng: lng);

        expect(lienzo.geoALienzo(lat, lng), Offset(esperado.x, esperado.y));
      }
    });

    test('tamano coincide con las dimensiones de assets/mapa_CUSur.png', () {
      // Ancho y alto del encabezado IHDR del PNG (bytes 16–23, big-endian).
      final bytes = File('assets/mapa_CUSur.png').readAsBytesSync();
      final datos = ByteData.sublistView(bytes);

      expect(const LienzoImagen(null).tamano,
          Size(datos.getUint32(16).toDouble(), datos.getUint32(20).toDouble()));
    });

    test('dos lienzos con el mismo modelo son iguales', () {
      expect(LienzoImagen(dosPuntos), LienzoImagen(dosPuntos));
      expect(LienzoImagen(dosPuntos), isNot(const LienzoImagen(null)));
    });
  });

  group('LienzoVectorial', () {
    final proyeccion = ProyeccionLocal(mapa.meta);
    final lienzo = LienzoVectorial(proyeccion);

    test('nodoALienzo usa lat/lng (también en los nodos interpolados)', () {
      for (final nodo in grafo.nodos.values) {
        expect(lienzo.nodoALienzo(nodo),
            proyeccion.geoALienzo(nodo.lat, nodo.lng),
            reason: nodo.id);
      }
    });

    test('geoALienzo siempre ubica la posición, sin transformación', () {
      expect(lienzo.geoALienzo(19.72384, -103.46214),
          proyeccion.geoALienzo(19.72384, -103.46214));
    });

    test('tamano es el del lienzo de la proyección', () {
      expect(lienzo.tamano, proyeccion.tamanoLienzo);
    });

    test('todos los nodos del grafo caen dentro del lienzo', () {
      final area = Offset.zero & lienzo.tamano;
      for (final nodo in grafo.nodos.values) {
        expect(area.contains(lienzo.nodoALienzo(nodo)), isTrue,
            reason: nodo.id);
      }
    });

    test('dos lienzos con el mismo meta son iguales', () {
      expect(LienzoVectorial(ProyeccionLocal(mapa.meta)), lienzo);
      expect(lienzo, isNot(const LienzoImagen(null)));
    });
  });

  group('MapImageArea en modo vectorial', () {
    Widget mapaVectorial({
      required MapaVectorial? datos,
      UbicacionEnGrafo? ubicacion,
      int disparadorZoom = 0,
      void Function(String, bool)? onNodoSeleccionado,
    }) =>
        MaterialApp(
          home: Scaffold(
            body: MapImageArea(
              ruta: const ['EntradaA', 'Edificio_M'],
              grafo: grafo,
              transformacion: null,
              markerImage: null,
              onNodoSeleccionado: onNodoSeleccionado ?? (_, _) {},
              ubicacionGPS: ubicacion,
              disparadorZoom: disparadorZoom,
              disparadorReinicioCamara: 0,
              modo: ModoMapa.vectorial,
              mapaVectorial: datos,
            ),
          ),
        );

    Finder lienzoDelMapa() => find.descendant(
        of: find.byType(GestureDetector), matching: find.byType(Stack));

    testWidgets('mientras no carga campus_vector.json no dibuja nada',
        (WidgetTester tester) async {
      await tester.pumpWidget(mapaVectorial(datos: null));

      expect(find.byType(InteractiveViewer), findsOneWidget);
      expect(lienzoDelMapa(), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('el lienzo toma el tamaño de LienzoVectorial',
        (WidgetTester tester) async {
      await tester.pumpWidget(mapaVectorial(datos: mapa));

      expect(tester.getSize(lienzoDelMapa().first),
          ProyeccionLocal(mapa.meta).tamanoLienzo);
      expect(tester.takeException(), isNull);
    });

    testWidgets('la cámara sigue al GPS aunque no haya transformación',
        (WidgetTester tester) async {
      const ubicacion = UbicacionEnGrafo(
        aristaA: 'EntradaA',
        aristaB: 'EntradaA',
        t: 0,
        distanciaAlCaminoMetros: 0,
        lat: 19.72384,
        lng: -103.46214,
      );
      await tester.pumpWidget(mapaVectorial(datos: mapa, ubicacion: ubicacion));
      final controller = tester
          .widget<InteractiveViewer>(find.byType(InteractiveViewer))
          .transformationController!;
      expect(controller.value, Matrix4.identity());

      await tester.pumpWidget(
          mapaVectorial(datos: mapa, ubicacion: ubicacion, disparadorZoom: 1));
      await tester.pumpAndSettle();

      expect(controller.value.getMaxScaleOnAxis(), closeTo(3.0, 1e-9));
    });

    testWidgets('el toque elige el nodo con nombre más cercano en el lienzo',
        (WidgetTester tester) async {
      String? elegido;
      await tester.pumpWidget(mapaVectorial(
        datos: mapa,
        onNodoSeleccionado: (nombre, _) => elegido = nombre,
      ));

      final lienzo = LienzoVectorial(ProyeccionLocal(mapa.meta));
      final RenderBox caja = tester.renderObject(lienzoDelMapa().first);
      await tester.tapAt(
          caja.localToGlobal(lienzo.nodoALienzo(grafo.nodos['EntradaA']!)));
      await tester.pumpAndSettle();

      expect(find.text('📍 Entrada Sur'), findsOneWidget);
      await tester.tap(find.text('Definir Origen'));
      await tester.pumpAndSettle();
      expect(elegido, 'Entrada Sur');
    });
  });
}
