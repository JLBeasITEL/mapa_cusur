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
