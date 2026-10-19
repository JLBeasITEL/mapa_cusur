/// Utilidades de texto para la búsqueda de ubicaciones. Son funciones puras
/// (sin Flutter) para poder probarlas solas; los nombres se siguen
/// mostrando tal como están en los datos, esto solo sirve para comparar.
library;

/// Letras con diacríticos (ya en minúscula) y su letra base. Incluye la ñ:
/// para buscar, "pequena" y "pequeña" son lo mismo.
const Map<String, String> _sinDiacritico = {
  'á': 'a', 'à': 'a', 'â': 'a', 'ä': 'a', 'ã': 'a', 'å': 'a',
  'é': 'e', 'è': 'e', 'ê': 'e', 'ë': 'e',
  'í': 'i', 'ì': 'i', 'î': 'i', 'ï': 'i',
  'ó': 'o', 'ò': 'o', 'ô': 'o', 'ö': 'o', 'õ': 'o',
  'ú': 'u', 'ù': 'u', 'û': 'u', 'ü': 'u',
  'ñ': 'n', 'ç': 'c', 'ý': 'y', 'ÿ': 'y',
};

/// Marcas diacríticas combinantes (U+0300-U+036F): la forma descompuesta
/// de "á" es "a" + U+0301, como la escriben algunos teclados.
final RegExp _marcasCombinantes = RegExp('[̀-ͯ]');

final RegExp _letraConDiacritico =
    RegExp('[${_sinDiacritico.keys.join()}]');

/// Cualquier carácter que no sea letra ni dígito (de cualquier alfabeto).
final RegExp _noLetraNiDigito = RegExp(r'[^\p{L}\p{N}]+', unicode: true);

/// Siglas escritas con puntos: dos o más letras sueltas separadas por
/// puntos, con o sin punto final ("C.A.S.A.", "C.M.I.D", "a.b").
final RegExp _siglasConPuntos = RegExp(
    r'(?<![\p{L}\p{N}])\p{L}(?:\.\p{L})+\.?(?![\p{L}\p{N}])',
    unicode: true);

/// La forma de [s] con la que se compara al buscar:
///
/// 1. Minúsculas.
/// 2. Sin diacríticos (á→a, ü→u...) y con ñ→n.
/// 3. Todo lo que no sea letra o dígito (puntos, guiones, paréntesis,
///    comas, diagonales...) se vuelve espacio.
/// 4. Espacios múltiples colapsados en uno, sin espacios en las orillas.
///
/// `normalizarParaBusqueda('  C.A.S.A. (Biblioteca) ')` → `'c a s a biblioteca'`.
String normalizarParaBusqueda(String s) => s
    .toLowerCase()
    .replaceAll(_marcasCombinantes, '')
    .replaceAllMapped(_letraConDiacritico, (m) => _sinDiacritico[m[0]!]!)
    .replaceAll(_noLetraNiDigito, ' ')
    .trim();

/// [s] con cada sigla escrita con puntos unida en una sola palabra:
/// `'Auditorio C.A.S.A.'` → `'Auditorio CASA'`. El resto queda igual.
String compactarSiglas(String s) => s.replaceAllMapped(
    _siglasConPuntos, (m) => m[0]!.replaceAll('.', ''));

/// Las formas normalizadas con las que se puede encontrar [texto]: la
/// normal y, si [texto] tiene siglas con puntos, también la compacta.
/// `'C.M.I.D.'` → `['c m i d', 'cmid']`. Sin repetidos; vacía si [texto]
/// no tiene letras ni dígitos.
List<String> formasBuscables(String texto) {
  final formas = <String>{
    normalizarParaBusqueda(texto),
    normalizarParaBusqueda(compactarSiglas(texto)),
  }..remove('');
  return formas.toList();
}

/// Distancia de Levenshtein entre [a] y [b]: cuántas letras hay que
/// insertar, borrar o cambiar para pasar de una a otra.
///
/// Con [maximo], deja de calcular en cuanto sabe que la distancia lo
/// rebasa y devuelve `maximo + 1`: así comparar contra muchas palabras es
/// rápido aunque casi ninguna se parezca.
int distanciaLevenshtein(String a, String b, {int? maximo}) =>
    _distanciaEdicion(a, b, maximo: maximo, contraPrefijo: false);

/// La menor distancia de Levenshtein entre [consulta] y algún inicio
/// (prefijo) de [palabra], incluida la palabra completa:
/// `distanciaAPrefijo('bibloteca', 'biblioteca')` es 1, igual que
/// `distanciaAPrefijo('biblot', 'biblioteca')` ("bibliot"). Sirve para
/// buscar mientras se escribe, cuando la palabra todavía va a la mitad.
/// [maximo] funciona como en [distanciaLevenshtein].
int distanciaAPrefijo(String consulta, String palabra, {int? maximo}) =>
    _distanciaEdicion(consulta, palabra, maximo: maximo, contraPrefijo: true);

/// Programación dinámica por renglones (uno por letra de [a]): el renglón
/// i guarda la distancia entre las primeras i letras de [a] y cada inicio
/// de [b]. El mínimo de un renglón nunca baja en los siguientes, así que si
/// ya rebasa [maximo] se puede parar.
int _distanciaEdicion(String a, String b,
    {required int? maximo, required bool contraPrefijo}) {
  final x = a.runes.toList();
  final y = b.runes.toList();
  if (maximo != null && !contraPrefijo && (x.length - y.length).abs() > maximo) {
    return maximo + 1;
  }

  var anterior = List<int>.generate(y.length + 1, (j) => j);
  var actual = List<int>.filled(y.length + 1, 0);
  for (var i = 1; i <= x.length; i++) {
    actual[0] = i;
    var minimoDelRenglon = i;
    for (var j = 1; j <= y.length; j++) {
      final cambio = anterior[j - 1] + (x[i - 1] == y[j - 1] ? 0 : 1);
      final borrar = anterior[j] + 1;
      final insertar = actual[j - 1] + 1;
      var d = cambio < borrar ? cambio : borrar;
      if (insertar < d) d = insertar;
      actual[j] = d;
      if (d < minimoDelRenglon) minimoDelRenglon = d;
    }
    if (maximo != null && minimoDelRenglon > maximo) return maximo + 1;
    final t = anterior;
    anterior = actual;
    actual = t;
  }

  var distancia = anterior[y.length];
  if (contraPrefijo) {
    for (final d in anterior) {
      if (d < distancia) distancia = d;
    }
  }
  if (maximo != null && distancia > maximo) return maximo + 1;
  return distancia;
}
