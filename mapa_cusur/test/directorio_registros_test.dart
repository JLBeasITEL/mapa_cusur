import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mapa_cusur/instrumentacion/directorio_registros.dart';

void main() {
  final externo = Directory('/storage/emulated/0/Android/data/app/files');
  final documentos = Directory('/data/user/0/app/app_flutter');

  test('usa el almacenamiento externo cuando está disponible', () async {
    final dir = await resolverDirectorioRegistros(
      obtenerExterno: () async => externo,
      obtenerDocumentos: () async => documentos,
    );
    expect(dir.path, '${externo.path}/$kSubcarpetaRegistros');
  });

  test('cae en documentos cuando el externo devuelve null', () async {
    final dir = await resolverDirectorioRegistros(
      obtenerExterno: () async => null,
      obtenerDocumentos: () async => documentos,
    );
    expect(dir.path, '${documentos.path}/$kSubcarpetaRegistros');
  });

  test('cae en documentos cuando el externo no está soportado (iOS)',
      () async {
    final dir = await resolverDirectorioRegistros(
      obtenerExterno: () async => throw UnsupportedError('iOS'),
      obtenerDocumentos: () async => documentos,
    );
    expect(dir.path, '${documentos.path}/$kSubcarpetaRegistros');
  });
}
