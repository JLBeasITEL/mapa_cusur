import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:mapa_cusur/domain/ubicacion_en_ruta.dart';
import 'package:mapa_cusur/instrumentacion/registro_csv_campo.dart';
import 'package:mapa_cusur/instrumentacion/sesion_campo.dart';

Position _posicionDePrueba({
  double lat = 19.7250,
  double lng = -103.4620,
  double accuracy = 8.0,
  double speed = 1.2,
  double heading = 45.0,
  double headingAccuracy = 5.0,
  bool isMocked = false,
}) {
  return Position(
    latitude: lat,
    longitude: lng,
    timestamp: DateTime.utc(2026, 8, 17, 12, 0, 0),
    accuracy: accuracy,
    altitude: 0,
    altitudeAccuracy: 0,
    heading: heading,
    headingAccuracy: headingAccuracy,
    speed: speed,
    speedAccuracy: 0.5,
    isMocked: isMocked,
  );
}

List<List<String>> _leerFilasCsv(String contenido) {
  return const LineSplitter()
      .convert(contenido)
      .where((l) => l.trim().isNotEmpty)
      .map((l) => l.split(','))
      .toList();
}

void main() {
  late Directory dirTemporal;

  setUp(() async {
    dirTemporal = await Directory.systemTemp.createTemp('registro_campo_test_');
  });

  tearDown(() async {
    if (await dirTemporal.exists()) {
      await dirTemporal.delete(recursive: true);
    }
  });

  SesionCampo sesionDePrueba() => SesionCampo(
      dispositivo: 'Dispositivo de prueba',
      recorrido: 2,
      repeticion: 3,
      iniciadaEn: DateTime.utc(2026, 8, 17, 10, 30));

  test('el nombre de archivo incluye dispositivo, recorrido, repetición y '
      'marca de tiempo', () {
    final sesion = sesionDePrueba();
    expect(sesion.nombreArchivo, contains('Dispositivo_de_prueba'));
    expect(sesion.nombreArchivo, contains('recorrido2'));
    expect(sesion.nombreArchivo, contains('rep3'));
    expect(sesion.nombreArchivo, contains('2026-08-17'));
    expect(sesion.nombreArchivo, endsWith('.csv'));
  });

  test('registrarLecturaGps escribe encabezado y fila con todas las '
      'columnas crudas', () async {
    final sesion = sesionDePrueba();
    final registro = RegistroCsvCampo(sesion: sesion, directorio: dirTemporal);

    await registro.registrarLecturaGps(
      position: _posicionDePrueba(),
      lecturaAceptada: true,
    );

    final archivo = File('${dirTemporal.path}/${sesion.nombreArchivo}');
    expect(await archivo.exists(), isTrue);

    final filas = _leerFilasCsv(await archivo.readAsString());
    expect(filas.length, 2); // encabezado + 1 fila
    expect(filas[0], RegistroCsvCampo.columnas);

    final fila = Map.fromIterables(filas[0], filas[1]);
    expect(fila['tipo_evento'], 'lectura_gps');
    expect(double.parse(fila['lat']!), closeTo(19.7250, 1e-9));
    expect(double.parse(fila['lng']!), closeTo(-103.4620, 1e-9));
    expect(double.parse(fila['accuracy_m']!), 8.0);
    expect(double.parse(fila['speed_mps']!), 1.2);
    expect(double.parse(fila['heading_deg']!), 45.0);
    expect(fila['is_mocked'], 'false');
    expect(fila['dispositivo'], 'Dispositivo de prueba');
    expect(fila['recorrido'], '2');
    expect(fila['repeticion'], '3');
    expect(fila['recorrido_id'], 'recorrido2_rep3');
    // Sin ubicación proyectada: las columnas derivadas quedan vacías, no
    // ausentes -la fila sigue siendo rectangular-.
    expect(fila['proyeccion_lat'], '');
    expect(fila['arista_a'], '');
    // Las columnas propias del punto de verificación también quedan vacías.
    expect(fila['nodo_lat'], '');
    expect(fila['nodo_lng'], '');
    expect(fila['error_gps_m'], '');
  });

  test('columnas derivadas se llenan cuando hay una ubicación proyectada',
      () async {
    final sesion = sesionDePrueba();
    final registro = RegistroCsvCampo(sesion: sesion, directorio: dirTemporal);

    const ubicacion = UbicacionEnGrafo(
      aristaA: 'A1',
      aristaB: 'B2',
      t: 0.35,
      distanciaAlCaminoMetros: 2.7,
      lat: 19.7251,
      lng: -103.4621,
    );

    await registro.registrarLecturaGps(
      position: _posicionDePrueba(),
      lecturaAceptada: true,
      ubicacion: ubicacion,
      nodoMetodoAnterior: 'B2',
      seRecalculoRuta: true,
    );

    final archivo = File('${dirTemporal.path}/${sesion.nombreArchivo}');
    final filas = _leerFilasCsv(await archivo.readAsString());
    final fila = Map.fromIterables(filas[0], filas[1]);

    expect(fila['arista_a'], 'A1');
    expect(fila['arista_b'], 'B2');
    expect(double.parse(fila['t_en_arista']!), 0.35);
    expect(double.parse(fila['distancia_al_camino_m']!), 2.7);
    expect(fila['nodo_mas_cercano_metodo_anterior'], 'B2');
    expect(fila['se_recalculo_ruta'], 'true');
    // Las columnas crudas siguen presentes: no se sustituyen por las
    // derivadas.
    expect(double.parse(fila['lat']!), closeTo(19.7250, 1e-9));
  });

  test('heading se omite (columna vacía) cuando no está disponible', () async {
    final sesion = sesionDePrueba();
    final registro = RegistroCsvCampo(sesion: sesion, directorio: dirTemporal);

    await registro.registrarLecturaGps(
      position: _posicionDePrueba(headingAccuracy: -1),
      lecturaAceptada: true,
    );

    final archivo = File('${dirTemporal.path}/${sesion.nombreArchivo}');
    final filas = _leerFilasCsv(await archivo.readAsString());
    final fila = Map.fromIterables(filas[0], filas[1]);

    expect(fila['heading_deg'], '');
    expect(fila['heading_accuracy_deg'], '');
  });

  test('registrarPuntoVerificacion incluye el error de ambos modelos sin '
      'perder las columnas crudas', () async {
    final sesion = sesionDePrueba();
    final registro = RegistroCsvCampo(sesion: sesion, directorio: dirTemporal);

    await registro.registrarPuntoVerificacion(
      position: _posicionDePrueba(),
      nodoVerificado: 'Edificio_F',
      nodoLat: 19.72503,
      nodoLng: -103.46204,
      errorGpsM: 5.3,
      pixelDosPuntos: (x: 100.0, y: 200.0),
      errorPxDosPuntos: 15.0,
      errorMDosPuntos: 8.5,
      pixelAfin: (x: 98.0, y: 199.0),
      errorPxAfin: 3.0,
      errorMAfin: 1.7,
    );

    final archivo = File('${dirTemporal.path}/${sesion.nombreArchivo}');
    final filas = _leerFilasCsv(await archivo.readAsString());
    final fila = Map.fromIterables(filas[0], filas[1]);

    expect(fila['tipo_evento'], 'punto_verificacion');
    expect(fila['nodo_verificado_manualmente'], 'Edificio_F');
    expect(double.parse(fila['error_px_dospuntos']!), 15.0);
    expect(double.parse(fila['error_m_dospuntos']!), 8.5);
    expect(double.parse(fila['error_px_afin']!), 3.0);
    expect(double.parse(fila['error_m_afin']!), 1.7);
    // Error del GPS solo, con las coordenadas del nodo contra las que se
    // midió.
    expect(double.parse(fila['nodo_lat']!), closeTo(19.72503, 1e-9));
    expect(double.parse(fila['nodo_lng']!), closeTo(-103.46204, 1e-9));
    expect(double.parse(fila['error_gps_m']!), 5.3);
    // Los datos crudos de la lectura siguen ahí.
    expect(double.parse(fila['lat']!), closeTo(19.7250, 1e-9));
    expect(double.parse(fila['accuracy_m']!), 8.0);
  });

  test('las columnas del error del GPS van al final, sin mover las '
      'existentes', () {
    const columnas = RegistroCsvCampo.columnas;
    expect(columnas.sublist(columnas.length - 3),
        ['nodo_lat', 'nodo_lng', 'error_gps_m']);
    expect(columnas[columnas.length - 4], 'error_m_afin');
  });

  test('varias filas se anexan al mismo archivo con un solo encabezado',
      () async {
    final sesion = sesionDePrueba();
    final registro = RegistroCsvCampo(sesion: sesion, directorio: dirTemporal);

    await registro.registrarLecturaGps(
        position: _posicionDePrueba(), lecturaAceptada: true);
    await registro.registrarLecturaGps(
        position: _posicionDePrueba(lat: 19.7260), lecturaAceptada: true);
    await registro.registrarPuntoVerificacion(
      position: _posicionDePrueba(),
      nodoVerificado: 'Edificio_F',
      nodoLat: 1.0,
      nodoLng: 1.0,
      errorGpsM: 1.0,
      pixelDosPuntos: (x: 1.0, y: 1.0),
      errorPxDosPuntos: 1.0,
      errorMDosPuntos: 1.0,
      pixelAfin: (x: 1.0, y: 1.0),
      errorPxAfin: 1.0,
      errorMAfin: 1.0,
    );

    final archivo = File('${dirTemporal.path}/${sesion.nombreArchivo}');
    final filas = _leerFilasCsv(await archivo.readAsString());

    expect(filas.length, 4); // 1 encabezado + 3 filas
    expect(filas[0], RegistroCsvCampo.columnas);
    // Todas las filas son rectangulares: mismo número de columnas.
    for (final fila in filas) {
      expect(fila.length, RegistroCsvCampo.columnas.length);
    }
  });
}
