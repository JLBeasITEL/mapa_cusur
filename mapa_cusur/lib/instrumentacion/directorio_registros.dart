import 'dart:io';

import 'package:path_provider/path_provider.dart';

/// Subcarpeta, dentro del directorio base elegido, donde se guardan los
/// CSV de las sesiones de campo.
const String kSubcarpetaRegistros = 'registros_campo';

/// Decide en qué carpeta se guardan los CSV de campo.
///
/// En Android se prefiere `getExternalStorageDirectory()`, que apunta a
/// `Android/data/<applicationId>/files/`: esa carpeta se puede abrir por USB
/// desde una computadora sin permisos adicionales. El directorio de
/// documentos de la app (`getApplicationDocumentsDirectory()`) es privado
/// -en una build de release no hay forma de sacar los archivos de ahí-, así
/// que solo se usa como respaldo cuando el externo no existe (devuelve
/// `null`) o no está soportado (lanza, como en iOS).
///
/// Las dos fuentes se reciben como funciones para poder probar la decisión
/// sin simular el canal de plataforma de `path_provider`; por defecto son
/// las de `path_provider`.
Future<Directory> resolverDirectorioRegistros({
  Future<Directory?> Function() obtenerExterno = getExternalStorageDirectory,
  Future<Directory> Function() obtenerDocumentos =
      getApplicationDocumentsDirectory,
}) async {
  Directory? base;
  try {
    base = await obtenerExterno();
  } catch (_) {
    base = null;
  }
  base ??= await obtenerDocumentos();
  return Directory('${base.path}/$kSubcarpetaRegistros');
}
