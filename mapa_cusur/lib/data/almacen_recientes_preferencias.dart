import 'package:flutter/foundation.dart' show debugPrint, kDebugMode;
import 'package:shared_preferences/shared_preferences.dart';

import '../domain/historial_recientes.dart';

/// Clave de `shared_preferences` donde se guardan los IDs recientes.
const String kClaveRecientes = 'busqueda.recientes';

/// [AlmacenRecientes] en el dispositivo, con `shared_preferences`. Nunca
/// falla: si el almacenamiento no está disponible, el historial funciona
/// solo en memoria y se avisa en la consola en modo debug.
class AlmacenRecientesPreferencias implements AlmacenRecientes {
  // Se crea al usarse: el constructor falla si la plataforma no tiene
  // shared_preferences (p. ej. en `flutter test`).
  SharedPreferencesAsync? _preferencias;

  SharedPreferencesAsync get _prefs => _preferencias ??= SharedPreferencesAsync();

  @override
  Future<List<String>> leer() async {
    try {
      return await _prefs.getStringList(kClaveRecientes) ?? const [];
    } catch (e) {
      _advertir('no se pudo leer el historial ($e)');
      return const [];
    }
  }

  @override
  Future<void> guardar(List<String> ids) async {
    try {
      await _prefs.setStringList(kClaveRecientes, ids);
    } catch (e) {
      _advertir('no se pudo guardar el historial ($e)');
    }
  }

  void _advertir(String mensaje) {
    if (kDebugMode) debugPrint('⚠️ Recientes: $mensaje');
  }
}
