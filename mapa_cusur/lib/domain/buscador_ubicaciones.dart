import '../models/ubicacion_buscable.dart';
import '../utils/texto.dart';

/// Qué tan bien coincide un lugar con la consulta, de mejor a peor (el
/// orden de los valores es el orden de relevancia).
enum NivelCoincidencia {
  /// El nombre completo es la consulta.
  exacta,

  /// El nombre empieza con la consulta completa.
  empiezaCon,

  /// Cada palabra de la consulta es el inicio de alguna palabra del nombre,
  /// en cualquier orden.
  palabras,

  /// Cada palabra de la consulta aparece dentro de alguna palabra del
  /// nombre, aunque sea a la mitad. Las palabras de menos de
  /// [kMinLetrasContiene] letras tienen que seguir siendo el inicio de una
  /// palabra del nombre.
  contiene,

  /// Coincide solo tolerando errores de dedo (ver
  /// [BuscadorUbicaciones.buscarAproximado]). Solo se busca así cuando
  /// ningún lugar coincide de las otras formas.
  aproximada,
}

/// Letras mínimas de una palabra de la consulta para que cuente aunque
/// aparezca a la mitad de una palabra del nombre ([NivelCoincidencia.contiene]).
/// Con menos, "b" o "de" coincidirían con casi todo.
const int kMinLetrasContiene = 3;

/// Cuántos errores de dedo (distancia de Levenshtein) se le toleran a una
/// palabra de la consulta de [letras] letras en la búsqueda aproximada:
/// ninguno con menos de 5, uno de 5 a 7 y dos con 8 o más.
int toleranciaDeErrores(int letras) => letras < 5
    ? 0
    : letras < 8
        ? 1
        : 2;

/// Distancia total máxima para sugerir un lugar con "¿Quisiste decir...?".
const int kDistanciaMaximaSugerencia = 3;

/// Un lugar encontrado: siempre con su nombre oficial ([nombre]). Si
/// coincidió por un alias y no por el nombre, [aliasCoincidente] es ese
/// alias tal como está escrito en los datos. [distanciaEdicion] es la suma
/// de los errores tolerados en las palabras de la consulta (0 salvo en
/// [NivelCoincidencia.aproximada] y en las sugerencias).
class ResultadoBusqueda {
  final String id;
  final String nombre;
  final NivelCoincidencia nivel;
  final String? aliasCoincidente;
  final int distanciaEdicion;

  const ResultadoBusqueda({
    required this.id,
    required this.nombre,
    required this.nivel,
    this.aliasCoincidente,
    this.distanciaEdicion = 0,
  });

  @override
  String toString() => 'ResultadoBusqueda($id, $nivel'
      '${distanciaEdicion == 0 ? '' : ', distancia: $distanciaEdicion'}'
      '${aliasCoincidente == null ? '' : ', alias: $aliasCoincidente'})';
}

/// Lo que la barra muestra para una consulta (ver
/// [BuscadorUbicaciones.consultar]).
class RespuestaBusqueda {
  /// La consulta tal como se escribió, sin espacios en las orillas.
  final String consulta;

  /// Los lugares encontrados, del más al menos relevante. Si son
  /// aproximados, todos son de [NivelCoincidencia.aproximada].
  final List<ResultadoBusqueda> resultados;

  /// Solo si [resultados] está vacía: el lugar más parecido para
  /// "¿Quisiste decir...?", o `null` si ninguno se parece lo suficiente.
  final ResultadoBusqueda? sugerencia;

  const RespuestaBusqueda({
    required this.consulta,
    this.resultados = const [],
    this.sugerencia,
  });

  /// La consulta no tiene letras ni dígitos: no se busca nada.
  bool get consultaVacia => normalizarParaBusqueda(consulta).isEmpty;

  bool get sonAproximados =>
      resultados.isNotEmpty &&
      resultados.first.nivel == NivelCoincidencia.aproximada;
}

/// Palabras que no se toman en cuenta al buscar, salvo que la consulta no
/// tenga otras ("de" sola sí se busca).
const Set<String> kPalabrasVacias = {'de', 'del', 'la', 'el', 'los', 'las', 'y'};

/// Las palabras de una consulta ya normalizada con las que se compara: sin
/// [kPalabrasVacias] si quedan otras.
List<String> palabrasDeConsulta(String consultaNormalizada) {
  final palabras = consultaNormalizada.split(' ')..remove('');
  final sinVacias =
      palabras.where((p) => !kPalabrasVacias.contains(p)).toList();
  return sinVacias.isEmpty ? palabras : sinVacias;
}

/// Una forma normalizada del nombre o de un alias de un lugar.
class _Forma {
  final String texto;
  final List<String> palabras;

  /// El alias de donde salió; `null` si salió del nombre.
  final String? alias;

  _Forma(this.texto, this.alias) : palabras = texto.split(' ');
}

class _Entrada {
  final UbicacionBuscable ubicacion;

  /// Para el desempate alfabético: el nombre normalizado, para que una
  /// letra acentuada o una mayúscula no muevan un nombre de lugar (en orden
  /// de código, "á" va después de "z" y "Z" antes de "a").
  final String claveOrden;
  final List<_Forma> formas;

  _Entrada(this.ubicacion)
      : claveOrden = normalizarParaBusqueda(ubicacion.nombre),
        formas = [
          for (final f in formasBuscables(ubicacion.nombre)) _Forma(f, null),
          for (final alias in ubicacion.alias)
            for (final f in formasBuscables(alias)) _Forma(f, alias),
        ];
}

/// Una coincidencia antes de ordenar.
typedef _Candidato = ({_Entrada entrada, ResultadoBusqueda resultado});

/// Busca lugares por nombre o alias sin importar acentos, mayúsculas,
/// puntuación, espacios de más ni el orden de las palabras, y tolera
/// errores de dedo cuando no hay otra coincidencia. Es Dart puro: las
/// formas normalizadas se calculan una sola vez, al construirlo, y no en
/// cada tecla.
class BuscadorUbicaciones {
  final List<_Entrada> _entradas;

  BuscadorUbicaciones(Iterable<UbicacionBuscable> ubicaciones)
      : _entradas = [for (final u in ubicaciones) _Entrada(u)];

  /// Lo que la barra muestra para [consulta]:
  ///
  /// 1. Los resultados de [buscar].
  /// 2. Si no hay, los de [buscarAproximado].
  /// 3. Si tampoco hay, ningún resultado y, si existe, la [sugerir].
  RespuestaBusqueda consultar(String consulta) {
    final escrita = consulta.trim();
    final exactos = buscar(escrita);
    if (exactos.isNotEmpty) {
      return RespuestaBusqueda(consulta: escrita, resultados: exactos);
    }
    final aproximados = buscarAproximado(escrita);
    if (aproximados.isNotEmpty) {
      return RespuestaBusqueda(consulta: escrita, resultados: aproximados);
    }
    return RespuestaBusqueda(consulta: escrita, sugerencia: sugerir(escrita));
  }

  /// Los lugares que coinciden con [consulta], del más al menos relevante
  /// (ver [NivelCoincidencia]); dentro de un mismo nivel, en orden
  /// alfabético. Vacía si [consulta] no tiene letras ni dígitos.
  List<ResultadoBusqueda> buscar(String consulta) {
    final normalizada = normalizarParaBusqueda(consulta);
    if (normalizada.isEmpty) return const [];
    final palabras = palabrasDeConsulta(normalizada);

    final encontrados = <_Candidato>[];
    for (final entrada in _entradas) {
      final resultado = _comparar(entrada, normalizada, palabras);
      if (resultado != null) {
        encontrados.add((entrada: entrada, resultado: resultado));
      }
    }
    return _ordenados(encontrados);
  }

  /// Los lugares que coinciden con [consulta] tolerando errores de dedo,
  /// palabra por palabra: cada palabra de la consulta tiene que parecerse
  /// al inicio de alguna palabra del nombre (o de un alias) con a lo más
  /// [toleranciaDeErrores] letras distintas. Ordenados por la suma de esas
  /// distancias (menor primero) y luego alfabéticamente.
  List<ResultadoBusqueda> buscarAproximado(String consulta) =>
      _ordenados(_aproximados(consulta, toleranciaDeErrores));

  /// El lugar más parecido a [consulta] para "¿Quisiste decir...?": la
  /// suma de las distancias de sus palabras es a lo más
  /// [kDistanciaMaximaSugerencia] y en cada palabra de la consulta están mal
  /// menos de la mitad de las letras (si no, "xyz" "se parecería" a
  /// cualquier palabra de una letra). Si hay empate, el primero en orden
  /// alfabético; `null` si ninguno se parece lo suficiente.
  ResultadoBusqueda? sugerir(String consulta) {
    final candidatos = _ordenados(_aproximados(consulta, (letras) {
      final menosDeLaMitad = (letras - 1) ~/ 2;
      return menosDeLaMitad < kDistanciaMaximaSugerencia
          ? menosDeLaMitad
          : kDistanciaMaximaSugerencia;
    }));
    for (final c in candidatos) {
      if (c.distanciaEdicion <= kDistanciaMaximaSugerencia) return c;
    }
    return null;
  }

  /// Para cada lugar, la forma (nombre o alias) cuyas palabras se parecen
  /// a las de [consulta] con la menor distancia total, sin rebasar
  /// [tolerancia] en ninguna palabra. A igual distancia gana el nombre.
  List<_Candidato> _aproximados(
      String consulta, int Function(int letras) tolerancia) {
    final normalizada = normalizarParaBusqueda(consulta);
    if (normalizada.isEmpty) return const [];
    final palabras = palabrasDeConsulta(normalizada);
    final maximos = [for (final p in palabras) tolerancia(p.runes.length)];

    final encontrados = <_Candidato>[];
    for (final entrada in _entradas) {
      int? mejor;
      _Forma? formaMejor;
      for (final forma in entrada.formas) {
        final total = _distanciaTotal(forma, palabras, maximos);
        if (total != null && (mejor == null || total < mejor)) {
          mejor = total;
          formaMejor = forma;
        }
      }
      if (mejor == null) continue;
      encontrados.add((
        entrada: entrada,
        resultado: ResultadoBusqueda(
          id: entrada.ubicacion.id,
          nombre: entrada.ubicacion.nombre,
          nivel: NivelCoincidencia.aproximada,
          aliasCoincidente: formaMejor!.alias,
          distanciaEdicion: mejor,
        ),
      ));
    }
    return encontrados;
  }

  /// La suma, sobre las [palabras] de la consulta, de la menor distancia
  /// de cada una al inicio de alguna palabra de [forma]; `null` si alguna
  /// rebasa su máximo en [maximos].
  static int? _distanciaTotal(
      _Forma forma, List<String> palabras, List<int> maximos) {
    var total = 0;
    for (var i = 0; i < palabras.length; i++) {
      final maximo = maximos[i];
      var mejor = maximo + 1;
      for (final w in forma.palabras) {
        final d = distanciaAPrefijo(palabras[i], w, maximo: maximo);
        if (d < mejor) mejor = d;
        if (mejor == 0) break;
      }
      if (mejor > maximo) return null;
      total += mejor;
    }
    return total;
  }

  /// Ordenados por nivel, luego por distancia de edición y luego
  /// alfabéticamente.
  static List<ResultadoBusqueda> _ordenados(List<_Candidato> candidatos) {
    final lista = [...candidatos]..sort((a, b) {
        final porNivel =
            a.resultado.nivel.index.compareTo(b.resultado.nivel.index);
        if (porNivel != 0) return porNivel;
        final porDistancia = a.resultado.distanciaEdicion
            .compareTo(b.resultado.distanciaEdicion);
        if (porDistancia != 0) return porDistancia;
        final porClave = a.entrada.claveOrden.compareTo(b.entrada.claveOrden);
        if (porClave != 0) return porClave;
        return a.resultado.nombre.compareTo(b.resultado.nombre);
      });
    return [for (final c in lista) c.resultado];
  }

  /// El mejor nivel con el que alguna forma de [entrada] coincide. A igual
  /// nivel gana el nombre sobre un alias (las formas del nombre van
  /// primero y solo se reemplazan por una estrictamente mejor).
  ResultadoBusqueda? _comparar(
      _Entrada entrada, String consulta, List<String> palabras) {
    NivelCoincidencia? mejor;
    _Forma? formaMejor;
    for (final forma in entrada.formas) {
      final nivel = _nivel(forma, consulta, palabras);
      if (nivel != null && (mejor == null || nivel.index < mejor.index)) {
        mejor = nivel;
        formaMejor = forma;
      }
    }
    if (mejor == null) return null;
    return ResultadoBusqueda(
      id: entrada.ubicacion.id,
      nombre: entrada.ubicacion.nombre,
      nivel: mejor,
      aliasCoincidente: formaMejor!.alias,
    );
  }

  static NivelCoincidencia? _nivel(
      _Forma forma, String consulta, List<String> palabras) {
    if (forma.texto == consulta) return NivelCoincidencia.exacta;
    if (forma.texto.startsWith(consulta)) return NivelCoincidencia.empiezaCon;
    if (palabras.every((p) => forma.palabras.any((w) => w.startsWith(p)))) {
      return NivelCoincidencia.palabras;
    }
    if (palabras.every((p) => forma.palabras.any((w) =>
        p.length >= kMinLetrasContiene ? w.contains(p) : w.startsWith(p)))) {
      return NivelCoincidencia.contiene;
    }
    return null;
  }
}
