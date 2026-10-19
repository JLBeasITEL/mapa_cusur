import 'package:flutter_test/flutter_test.dart';
import 'package:mapa_cusur/utils/texto.dart';

void main() {
  group('normalizarParaBusqueda', () {
    test('convierte a minúsculas', () {
      expect(normalizarParaBusqueda('RECTORIA'), 'rectoria');
      expect(normalizarParaBusqueda('Edificio B'), 'edificio b');
    });

    test('quita acentos en minúsculas y mayúsculas', () {
      expect(normalizarParaBusqueda('áéíóú'), 'aeiou');
      expect(normalizarParaBusqueda('ÁÉÍÓÚ'), 'aeiou');
      expect(normalizarParaBusqueda('Rectoría'), 'rectoria');
      expect(normalizarParaBusqueda('Auditorio Adolfo Aguilar Zínser'),
          'auditorio adolfo aguilar zinser');
    });

    test('quita la diéresis', () {
      expect(normalizarParaBusqueda('ü'), 'u');
      expect(normalizarParaBusqueda('Ü'), 'u');
      expect(normalizarParaBusqueda('pingüino'), 'pinguino');
    });

    test('trata la ñ como n', () {
      expect(normalizarParaBusqueda('ñ'), 'n');
      expect(normalizarParaBusqueda('Ñ'), 'n');
      expect(normalizarParaBusqueda('Cafetería Pequeña'), 'cafeteria pequena');
    });

    test('acepta acentos escritos como marca combinante', () {
      // "i" + U+0301 (acento agudo combinante), como lo escriben algunos
      // teclados, es lo mismo que "í".
      expect(normalizarParaBusqueda('Rectoría'), 'rectoria');
      expect(normalizarParaBusqueda('Cafetería'), 'cafeteria');
    });

    test('los ejemplos del objetivo encuentran lo mismo que "Cómputo"', () {
      final esperado = normalizarParaBusqueda('Cómputo');
      expect(esperado, 'computo');
      for (final consulta in ['computo', 'CÓMPUTO', 'Computo']) {
        expect(normalizarParaBusqueda(consulta), esperado, reason: consulta);
      }
    });

    test('todo lo que no es letra ni dígito se vuelve espacio', () {
      expect(normalizarParaBusqueda('a-b'), 'a b');
      expect(normalizarParaBusqueda('a_b'), 'a b');
      expect(normalizarParaBusqueda('a.b'), 'a b');
      expect(normalizarParaBusqueda('a,b'), 'a b');
      expect(normalizarParaBusqueda('a/b'), 'a b');
      expect(normalizarParaBusqueda('a(b)'), 'a b');
      expect(normalizarParaBusqueda('a;b:c!d?e¿f¡g"h\'i'), 'a b c d e f g h i');
      expect(normalizarParaBusqueda('C.A.S.A. (Biblioteca)'),
          'c a s a biblioteca');
      expect(normalizarParaBusqueda('C.M.I.D.'), 'c m i d');
    });

    test('conserva los dígitos', () {
      expect(normalizarParaBusqueda('Estacionamiento 1'), 'estacionamiento 1');
      expect(normalizarParaBusqueda('Estacionamiento-5'), 'estacionamiento 5');
    });

    test('colapsa espacios múltiples y recorta las orillas', () {
      expect(normalizarParaBusqueda('  biblioteca  '), 'biblioteca');
      expect(normalizarParaBusqueda('  biblioteca  '),
          normalizarParaBusqueda('biblioteca'));
      expect(normalizarParaBusqueda('Edificio    B'), 'edificio b');
      expect(normalizarParaBusqueda('\tEdificio\n B '), 'edificio b');
      expect(normalizarParaBusqueda('a - . - b'), 'a b');
    });

    test('cadena vacía, solo espacios o solo puntuación dan cadena vacía', () {
      expect(normalizarParaBusqueda(''), '');
      expect(normalizarParaBusqueda('   '), '');
      expect(normalizarParaBusqueda(' \t\n '), '');
      expect(normalizarParaBusqueda('.-_,()'), '');
    });

    test('es idempotente', () {
      for (final s in [
        'C.A.S.A. (Biblioteca)',
        'Cafetería Pequeña',
        '  Auditorio   C.A.S.A. ',
      ]) {
        final una = normalizarParaBusqueda(s);
        expect(normalizarParaBusqueda(una), una, reason: s);
      }
    });
  });

  group('compactarSiglas', () {
    test('une las siglas escritas con puntos', () {
      expect(compactarSiglas('C.A.S.A. (Biblioteca)'), 'CASA (Biblioteca)');
      expect(compactarSiglas('Auditorio C.A.S.A.'), 'Auditorio CASA');
      expect(compactarSiglas('C.M.I.D.'), 'CMID');
      expect(compactarSiglas('C.M.I.D'), 'CMID');
    });

    test('no toca puntos que no separan letras sueltas', () {
      expect(compactarSiglas('Edificio B.'), 'Edificio B.');
      expect(compactarSiglas('fin. Otra'), 'fin. Otra');
      expect(compactarSiglas('Rectoría'), 'Rectoría');
      expect(compactarSiglas('1.5'), '1.5');
    });
  });

  group('formasBuscables', () {
    test('las siglas con puntos dan la forma con espacios y la compacta', () {
      expect(formasBuscables('C.A.S.A. (Biblioteca)'),
          ['c a s a biblioteca', 'casa biblioteca']);
      expect(formasBuscables('Auditorio C.A.S.A.'),
          ['auditorio c a s a', 'auditorio casa']);
      expect(formasBuscables('C.M.I.D.'), ['c m i d', 'cmid']);
    });

    test('un nombre sin siglas da una sola forma', () {
      expect(formasBuscables('Cafetería Principal'), ['cafeteria principal']);
    });

    test('un texto sin letras ni dígitos no da ninguna forma', () {
      expect(formasBuscables(''), isEmpty);
      expect(formasBuscables(' . '), isEmpty);
    });
  });
}
