import '../models/ubicacion_buscable.dart';
import '../utils/texto.dart';
import 'diccionario_nombres.dart';

/// Los lugares que se pueden buscar entre [idsDelGrafo]: los que tienen
/// nombre amigable en [diccionarioNombres]. Sus alias son los de
/// [nombresAlternativos] más los de [aliasExtra] (los de
/// `assets/alias_busqueda.json`); un alias repetido -sin importar acentos
/// ni mayúsculas- cuenta una sola vez.
List<UbicacionBuscable> ubicacionesBuscables(
  Iterable<String> idsDelGrafo, {
  Map<String, List<String>> aliasExtra = const {},
}) =>
    [
      for (final id in idsDelGrafo)
        if (diccionarioNombres[id] case final nombre?)
          UbicacionBuscable(
            id: id,
            nombre: nombre,
            alias: _sinRepetidos([
              ...?nombresAlternativos[id],
              ...?aliasExtra[id],
            ]),
          ),
    ];

/// Lo mismo, a partir de nombres amigables (como los recibe la barra de
/// búsqueda cuando no le pasan un buscador ya armado). Un nombre que no
/// está en [diccionarioNombres] se usa como su propio ID.
List<UbicacionBuscable> ubicacionesDesdeNombres(Iterable<String> nombres) => [
      for (final nombre in nombres)
        UbicacionBuscable(
          id: idDeNombre(nombre) ?? nombre,
          nombre: nombre,
          alias: alternativosDe(nombre),
        ),
    ];

/// [alias] sin los que normalizados son iguales a uno anterior.
List<String> _sinRepetidos(List<String> alias) {
  final vistos = <String>{};
  return [
    for (final a in alias)
      if (vistos.add(normalizarParaBusqueda(a))) a,
  ];
}
