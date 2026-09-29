import 'package:flutter_test/flutter_test.dart';
import 'package:mapa_cusur/utils/cronometro.dart';

void main() {
  group('Cronometro', () {
    test('medir() devuelve el resultado de la acción sin modificarlo', () {
      final cronometro = Cronometro();
      final resultado = cronometro.medir('etiqueta', () => 2 + 2);
      expect(resultado, 4);
    });

    test('acumula mediciones por etiqueta y calcula el resumen', () {
      final cronometro = Cronometro();
      cronometro.medir('trabajo', () {
        int suma = 0;
        for (int i = 0; i < 1000; i++) {
          suma += i;
        }
        return suma;
      });
      cronometro.medir('trabajo', () => 0);
      cronometro.medir('trabajo', () => 0);

      final resumen = cronometro.resumenDe('trabajo');
      expect(resumen.n, 3);
      expect(resumen.promedioMicros, greaterThanOrEqualTo(0));
      expect(resumen.minMicros, lessThanOrEqualTo(resumen.maxMicros));
    });

    test('etiquetas sin mediciones devuelven un resumen vacío', () {
      final cronometro = Cronometro();
      final resumen = cronometro.resumenDe('nunca-medida');
      expect(resumen.n, 0);
      expect(resumen.promedioMicros, 0);
    });

    test('etiquetas distintas se acumulan por separado', () {
      final cronometro = Cronometro();
      cronometro.medir('a', () => 1);
      cronometro.medir('a', () => 1);
      cronometro.medir('b', () => 1);

      expect(cronometro.resumenDe('a').n, 2);
      expect(cronometro.resumenDe('b').n, 1);
      expect(cronometro.etiquetas.toSet(), {'a', 'b'});
    });

    test('limpiar() borra todo el historial', () {
      final cronometro = Cronometro();
      cronometro.medir('a', () => 1);
      cronometro.limpiar();
      expect(cronometro.resumenDe('a').n, 0);
      expect(cronometro.etiquetas, isEmpty);
    });

    test('medirAsync() mide operaciones asíncronas', () async {
      final cronometro = Cronometro();
      final resultado = await cronometro.medirAsync('async', () async {
        await Future<void>.delayed(const Duration(milliseconds: 1));
        return 'listo';
      });
      expect(resultado, 'listo');
      expect(cronometro.resumenDe('async').n, 1);
    });
  });
}
