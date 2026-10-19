import '../models/ubicacion_buscable.dart';
import 'diccionario_nombres.dart';

/// Los lugares que se pueden buscar entre [idsDelGrafo]: los que tienen
/// nombre amigable en [diccionarioNombres], con sus [nombresAlternativos]
/// como alias.
List<UbicacionBuscable> ubicacionesBuscables(Iterable<String> idsDelGrafo) => [
      for (final id in idsDelGrafo)
        if (diccionarioNombres[id] case final nombre?)
          UbicacionBuscable(
            id: id,
            nombre: nombre,
            alias: nombresAlternativos[id] ?? const [],
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
