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
  /// nombre, aunque sea a la mitad.
  contiene,
}

/// Un lugar encontrado: siempre con su nombre oficial ([nombre]). Si
/// coincidió por un alias y no por el nombre, [aliasCoincidente] es ese
/// alias tal como está escrito en los datos.
class ResultadoBusqueda {
  final String id;
  final String nombre;
  final NivelCoincidencia nivel;
  final String? aliasCoincidente;

  const ResultadoBusqueda({
    required this.id,
    required this.nombre,
    required this.nivel,
    this.aliasCoincidente,
  });

  @override
  String toString() => 'ResultadoBusqueda($id, $nivel'
      '${aliasCoincidente == null ? '' : ', alias: $aliasCoincidente'})';
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

/// Busca lugares por nombre o alias sin importar acentos, mayúsculas,
/// puntuación, espacios de más ni el orden de las palabras. Es Dart puro:
/// las formas normalizadas se calculan una sola vez, al construirlo, y no
/// en cada tecla.
class BuscadorUbicaciones {
  final List<_Entrada> _entradas;

  BuscadorUbicaciones(Iterable<UbicacionBuscable> ubicaciones)
      : _entradas = [for (final u in ubicaciones) _Entrada(u)];

  /// Los lugares que coinciden con [consulta], del más al menos relevante
  /// (ver [NivelCoincidencia]); dentro de un mismo nivel, en orden
  /// alfabético. Vacía si [consulta] no tiene letras ni dígitos.
  List<ResultadoBusqueda> buscar(String consulta) {
    final normalizada = normalizarParaBusqueda(consulta);
    if (normalizada.isEmpty) return const [];
    final palabras = palabrasDeConsulta(normalizada);

    final encontrados = <(_Entrada, ResultadoBusqueda)>[];
    for (final entrada in _entradas) {
      final resultado = _comparar(entrada, normalizada, palabras);
      if (resultado != null) encontrados.add((entrada, resultado));
    }
    encontrados.sort((a, b) {
      final porNivel = a.$2.nivel.index.compareTo(b.$2.nivel.index);
      if (porNivel != 0) return porNivel;
      final porClave = a.$1.claveOrden.compareTo(b.$1.claveOrden);
      if (porClave != 0) return porClave;
      return a.$2.nombre.compareTo(b.$2.nombre);
    });
    return [for (final (_, resultado) in encontrados) resultado];
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
    if (palabras.every((p) => forma.palabras.any((w) => w.contains(p)))) {
      return NivelCoincidencia.contiene;
    }
    return null;
  }
}
