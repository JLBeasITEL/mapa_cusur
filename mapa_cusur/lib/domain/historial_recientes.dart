import 'package:flutter/foundation.dart' show ChangeNotifier;

/// Cuántos lugares recuerda el historial de búsqueda.
const int kMaxRecientes = 5;

/// Dónde se guardan los IDs del historial. Es una interfaz para poder
/// probar el historial sin `shared_preferences` (ver
/// [AlmacenRecientesEnMemoria]).
abstract interface class AlmacenRecientes {
  /// Los IDs guardados, del más al menos reciente (vacía si no hay).
  Future<List<String>> leer();

  Future<void> guardar(List<String> ids);
}

/// [AlmacenRecientes] que solo vive en memoria (para pruebas).
class AlmacenRecientesEnMemoria implements AlmacenRecientes {
  List<String> ids;

  AlmacenRecientesEnMemoria([List<String> ids = const []]) : ids = [...ids];

  @override
  Future<List<String>> leer() async => [...ids];

  @override
  Future<void> guardar(List<String> ids) async => this.ids = [...ids];
}

/// [ids] con [id] al principio, sin repetidos y con a lo más [maximo]
/// elementos.
List<String> conReciente(List<String> ids, String id,
        {int maximo = kMaxRecientes}) =>
    [id, ...ids.where((x) => x != id)].take(maximo).toList();

/// Los IDs de los últimos lugares elegidos desde la lista de la barra de
/// búsqueda (no lo escrito a mano), del más al menos reciente. Origen y
/// destino comparten el mismo historial.
class HistorialRecientes extends ChangeNotifier {
  final AlmacenRecientes _almacen;
  List<String> _ids = const [];
  Future<void>? _carga;
  bool _desechado = false;

  HistorialRecientes(this._almacen);

  List<String> get ids => _ids;

  /// Lee el historial guardado. Descarta en silencio los IDs que no están
  /// en [idsValidos] (lugares que ya no existen en los datos), los
  /// repetidos y lo que pase de [kMaxRecientes].
  Future<void> cargar({required Set<String> idsValidos}) =>
      _carga ??= _leer(idsValidos);

  Future<void> _leer(Set<String> idsValidos) async {
    final guardados = await _almacen.leer();
    var limpios = <String>[];
    for (final id in guardados.reversed) {
      if (idsValidos.contains(id)) limpios = conReciente(limpios, id);
    }
    _ids = limpios;
    _avisar();
  }

  /// Pone [id] como el más reciente.
  Future<void> agregar(String id) async {
    await _carga;
    _ids = conReciente(_ids, id);
    _avisar();
    await _almacen.guardar(_ids);
  }

  Future<void> borrar() async {
    await _carga;
    _ids = const [];
    _avisar();
    await _almacen.guardar(_ids);
  }

  // La carga es asíncrona: puede terminar después de desechar el historial
  // (p. ej. si se cierra la pantalla mientras lee).
  void _avisar() {
    if (!_desechado) notifyListeners();
  }

  @override
  void dispose() {
    _desechado = true;
    super.dispose();
  }
}
