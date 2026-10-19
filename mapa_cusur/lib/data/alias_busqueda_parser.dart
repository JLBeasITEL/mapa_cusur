import 'dart:convert';

/// Traduce el contenido de `assets/alias_busqueda.json` (un objeto
/// `{ID: [alias, ...]}`, ver `assets/README_alias_busqueda.md`) a un mapa
/// de ID a alias.
///
/// Nunca falla: si [contenido] es `null`, está vacío o no es JSON válido,
/// devuelve un mapa vacío. Se ignoran, avisando con [advertir], las
/// entradas cuyo ID no está en [idsValidos], las que no son una lista y los
/// alias que no son texto o están vacíos. Es Dart puro, como
/// `campus_json_parser.dart`.
Map<String, List<String>> parsearAliasBusqueda(
  String? contenido, {
  required Set<String> idsValidos,
  void Function(String mensaje)? advertir,
}) {
  void avisar(String mensaje) => advertir?.call(mensaje);

  if (contenido == null || contenido.trim().isEmpty) return const {};

  final Object? data;
  try {
    data = json.decode(contenido);
  } on FormatException catch (e) {
    avisar('no es JSON válido (${e.message}); se ignora.');
    return const {};
  }
  if (data is! Map<String, dynamic>) {
    avisar('se esperaba un objeto {ID: [alias]}; se ignora.');
    return const {};
  }

  final alias = <String, List<String>>{};
  data.forEach((id, valor) {
    if (!idsValidos.contains(id)) {
      avisar('el ID "$id" no es un lugar buscable; se ignora.');
      return;
    }
    if (valor is! List) {
      avisar('los alias de "$id" no son una lista; se ignoran.');
      return;
    }
    final deEsteId = <String>[];
    for (final a in valor) {
      if (a is String && a.trim().isNotEmpty) {
        deEsteId.add(a.trim());
      } else {
        avisar('alias inválido en "$id": ${json.encode(a)}; se ignora.');
      }
    }
    if (deEsteId.isNotEmpty) alias[id] = deEsteId;
  });
  return alias;
}
