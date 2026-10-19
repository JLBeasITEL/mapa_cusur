import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mapa_cusur/data/diccionario_nombres.dart';
import 'package:mapa_cusur/data/ubicaciones_buscables.dart';
import 'package:mapa_cusur/domain/buscador_ubicaciones.dart';
import 'package:mapa_cusur/models/ubicacion_buscable.dart';
import 'package:mapa_cusur/ui/widgets/autocomplete_input_field.dart';
import 'package:mapa_cusur/ui/widgets/opciones_busqueda.dart';
import 'package:mapa_cusur/utils/texto.dart';

const _laboratorio = 'Laboratorio de técnicas deportivas y de rescate';
const _biblioteca = 'C.A.S.A. (Biblioteca)';

/// Buscador con lugares genéricos (no son datos del campus).
BuscadorUbicaciones _generico(List<String> nombres) => BuscadorUbicaciones(
    [for (final n in nombres) UbicacionBuscable(id: n, nombre: n)]);

List<String> _nombres(List<ResultadoBusqueda> r) =>
    [for (final x in r) x.nombre];

void main() {
  final campus =
      BuscadorUbicaciones(ubicacionesBuscables(diccionarioNombres.keys));

  group('distanciaDeEdicion', () {
    test('casos clásicos', () {
      expect(distanciaDeEdicion('kitten', 'sitting'), 3);
      expect(distanciaDeEdicion('flaw', 'lawn'), 2);
      expect(distanciaDeEdicion('biblioteca', 'bibloteca'), 1);
      expect(distanciaDeEdicion('rectoria', 'rectoria'), 0);
    });

    test('cadenas vacías', () {
      expect(distanciaDeEdicion('', ''), 0);
      expect(distanciaDeEdicion('abc', ''), 3);
      expect(distanciaDeEdicion('', 'abc'), 3);
    });

    test('es simétrica', () {
      for (final (a, b) in [('kitten', 'sitting'), ('ab', 'ba'), ('', 'x')]) {
        expect(distanciaDeEdicion(a, b), distanciaDeEdicion(b, a));
      }
    });

    test('intercambiar dos letras contiguas cuesta 1 (Damerau, OSA)', () {
      expect(distanciaDeEdicion('zinser', 'zisner'), 1);
      expect(distanciaDeEdicion('ab', 'ba'), 1);
      expect(distanciaDeEdicion('auditoiro', 'auditorio'), 1);
      expect(distanciaAPrefijo('bilbio', 'biblioteca'), 1);
    });

    test('variante OSA: cada tramo se edita una sola vez', () {
      // Con Damerau sin restricción sería 2 ("ca" → "ac" → "abc").
      expect(distanciaDeEdicion('ca', 'abc'), 3);
    });

    test('con máximo, la salida temprana respeta los intercambios', () {
      expect(distanciaDeEdicion('zisner', 'zinser', maximo: 1), 1);
      expect(distanciaDeEdicion('rcetorai', 'rectoria', maximo: 1), 2);
      expect(distanciaDeEdicion('rcetorai', 'rectoria', maximo: 2), 2);
    });

    test('compara letras, no unidades de código', () {
      expect(distanciaDeEdicion('añ', 'an'), 1);
      expect(distanciaDeEdicion('😀a', 'a'), 1);
    });

    test('con máximo: sale temprano con máximo + 1 si lo rebasa', () {
      expect(distanciaDeEdicion('kitten', 'sitting', maximo: 3), 3);
      expect(distanciaDeEdicion('kitten', 'sitting', maximo: 2), 3);
      expect(distanciaDeEdicion('kitten', 'sitting', maximo: 0), 1);
      // Por diferencia de largo, sin calcular la tabla.
      expect(distanciaDeEdicion('a', 'abcdef', maximo: 1), 2);
      expect(distanciaDeEdicion('rectoria', 'rektoria', maximo: 1), 1);
    });
  });

  group('distanciaAPrefijo', () {
    test('compara contra el inicio más parecido de la palabra', () {
      expect(distanciaAPrefijo('bibloteca', 'biblioteca'), 1);
      expect(distanciaAPrefijo('biblot', 'biblioteca'), 1);
      expect(distanciaAPrefijo('bib', 'biblioteca'), 0);
      expect(distanciaAPrefijo('progrma', 'programacion'), 1);
      expect(distanciaAPrefijo('', 'abc'), 0);
      expect(distanciaAPrefijo('abc', ''), 3);
    });

    test('con máximo: sale temprano con máximo + 1 si lo rebasa', () {
      expect(distanciaAPrefijo('xyzw', 'biblioteca', maximo: 1), 2);
      expect(distanciaAPrefijo('biblot', 'biblioteca', maximo: 1), 1);
    });
  });

  group('toleranciaDeErrores', () {
    test('0 con menos de 5 letras, 1 de 5 a 7, 2 con 8 o más', () {
      expect([for (var n = 0; n <= 12; n++) toleranciaDeErrores(n)],
          [0, 0, 0, 0, 0, 1, 1, 1, 2, 2, 2, 2, 2]);
    });
  });

  group('umbrales de la búsqueda aproximada', () {
    test('menos de 5 letras: sin tolerancia', () {
      // "rekt" (4 letras) no se parece lo suficiente para ser resultado.
      expect(campus.buscarAproximado('rekt'), isEmpty);
    });

    test('de 5 a 7 letras: hasta 1 error', () {
      final buscador = _generico(['Kappa']);
      expect(buscador.buscarAproximado('kapoa').single.distanciaEdicion, 1);
      expect(buscador.buscarAproximado('kxpoa'), isEmpty);
      expect(campus.buscarAproximado('progrma').single.nombre,
          'Laboratorio de Programación');
    });

    test('8 letras o más: hasta 2 errores', () {
      final r = campus.buscarAproximado('rektorya');
      expect(r.single.nombre, 'Rectoría');
      expect(r.single.distanciaEdicion, 2);
      expect(campus.buscarAproximado('rektoryo'), isEmpty);
    });

    test('cada palabra de la consulta usa su propio umbral', () {
      // "nrte" tiene 4 letras: no se le tolera el error aunque "futbol"
      // esté bien.
      expect(campus.buscarAproximado('cancha futbol nrte'), isEmpty);
      expect(_nombres(campus.buscarAproximado('cafeteria pricipal')),
          ['Cafetería Principal']);
    });

    test('ordena por distancia total y luego alfabéticamente', () {
      final buscador = _generico(
          ['Zeta Paralelo', 'Beta Paralel', 'Gamma Parale', 'Alfa Paralelo']);
      final r = buscador.buscarAproximado('paralelox');
      expect(_nombres(r), ['Alfa Paralelo', 'Zeta Paralelo', 'Beta Paralel']);
      expect([for (final x in r) x.distanciaEdicion], [1, 1, 2]);
      expect(r.every((x) => x.nivel == NivelCoincidencia.aproximada), isTrue);
    });

    test('un intercambio de letras es un solo error', () {
      final r = campus.buscarAproximado('zisner');
      expect(_nombres(r), ['Auditorio Adolfo Aguilar Zínser']);
      expect(r.single.distanciaEdicion, 1);
      expect(_nombres(campus.buscarAproximado('auditoiro')), [
        'Auditorio Adolfo Aguilar Zínser',
        'Auditorio Antonio González Ochoa',
        'Auditorio C.A.S.A.',
      ]);
      expect(campus.buscarAproximado('bilbioteka').single.nombre, _biblioteca);
    });

    test('también por alias, mostrando el nombre oficial', () {
      final r = campus.buscarAproximado('gimnacio');
      expect(r.single.nombre, _laboratorio);
      expect(r.single.aliasCoincidente, 'Gimnasio');
    });
  });

  group('sugerir', () {
    test('la más cercana con distancia de a lo más 3', () {
      final s = campus.sugerir('vivlioteka')!;
      expect(s.nombre, _biblioteca);
      expect(s.distanciaEdicion, 3);
      expect(campus.sugerir('rekt')!.nombre, 'Rectoría');
    });

    test('nada si ninguna se parece lo suficiente', () {
      expect(campus.sugerir('xyz'), isNull);
      expect(campus.sugerir('qwerty'), isNull);
      // Menos de la mitad de las letras pueden estar mal: "xb" no es "b".
      expect(campus.sugerir('xb'), isNull);
    });

    test('empate: la primera en orden alfabético', () {
      final buscador = _generico(['Beta Kappa', 'Alfa Kappa']);
      expect(buscador.buscarAproximado('kxppx'), isEmpty);
      expect(buscador.sugerir('kxppx')!.nombre, 'Alfa Kappa');
    });

    test('por alias sugiere el nombre oficial', () {
      final s = campus.sugerir('gymnazyo')!;
      expect(s.nombre, _laboratorio);
      expect(s.aliasCoincidente, 'Gimnasio');
    });
  });

  group('consultar: los tres escenarios', () {
    test('con coincidencias normales no busca aproximado', () {
      final r = campus.consultar('rectoria');
      expect(r.sonAproximados, isFalse);
      expect(r.resultados.first.nivel, NivelCoincidencia.exacta);
      expect(r.sugerencia, isNull);
    });

    test('sin coincidencias normales: resultados aproximados', () {
      final r = campus.consultar('bibloteca');
      expect(r.sonAproximados, isTrue);
      expect(_nombres(r.resultados), [_biblioteca]);
      expect(r.sugerencia, isNull);
    });

    test('sin aproximados: "¿Quisiste decir...?"', () {
      final r = campus.consultar('  vivlioteka ');
      expect(r.resultados, isEmpty);
      expect(r.consulta, 'vivlioteka');
      expect(r.sugerencia!.nombre, _biblioteca);
    });

    test('sin nada: ni resultados ni sugerencia', () {
      final r = campus.consultar('qwerty');
      expect(r.resultados, isEmpty);
      expect(r.sugerencia, isNull);
      expect(r.consultaVacia, isFalse);
    });

    test('consulta vacía: no se busca', () {
      for (final q in ['', '  ', '.-']) {
        final r = campus.consultar(q);
        expect(r.consultaVacia, isTrue, reason: q);
        expect(r.resultados, isEmpty);
        expect(r.sugerencia, isNull);
        expect(OpcionBusqueda.de(r), isEmpty);
      }
    });
  });

  group('la barra', () {
    String? avisado;

    Future<void> escribir(WidgetTester tester, String texto) async {
      avisado = null;
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: AutocompleteInputField(
            iconColor: Colors.red,
            title: 'Destino',
            placeholder: '¿A dónde vas?',
            suggestions: const [],
            buscador: campus,
            onSelected: (v) => avisado = v,
          ),
        ),
      ));
      await tester.enterText(find.byType(TextField), texto);
      await tester.pumpAndSettle();
    }

    testWidgets('muestra los aproximados bajo su encabezado',
        (WidgetTester tester) async {
      await escribir(tester, 'bibloteca');
      expect(find.text('Resultados aproximados'), findsOneWidget);
      expect(
          find.descendant(
              of: find.byType(ListView), matching: find.text(_biblioteca)),
          findsOneWidget);
    });

    testWidgets('sin encabezado si los resultados no son aproximados',
        (WidgetTester tester) async {
      await escribir(tester, 'biblioteca');
      expect(find.text('Resultados aproximados'), findsNothing);
      expect(find.text(_biblioteca), findsOneWidget);
    });

    testWidgets('"¿Quisiste decir...?" reemplaza la consulta por el nombre',
        (WidgetTester tester) async {
      await escribir(tester, 'vivlioteka');
      expect(find.text('No encontramos «vivlioteka»'), findsOneWidget);
      final sugerencia =
          find.textContaining('¿Quisiste decir', findRichText: true);
      expect(sugerencia, findsOneWidget);
      expect(find.textContaining(_biblioteca, findRichText: true),
          findsOneWidget);

      await tester.tap(sugerencia);
      await tester.pumpAndSettle();

      expect(find.widgetWithText(TextField, _biblioteca), findsOneWidget);
      expect(avisado, _biblioteca);
      expect(find.textContaining('No encontramos'), findsNothing);
      // Se muestran sus resultados.
      expect(
          find.descendant(
              of: find.byType(ListView), matching: find.text(_biblioteca)),
          findsOneWidget);
    });

    testWidgets('sin sugerencia: solo el mensaje y la ayuda',
        (WidgetTester tester) async {
      await escribir(tester, 'qwerty');
      expect(find.text('No encontramos «qwerty»'), findsOneWidget);
      expect(find.text(kAyudaSinResultados), findsOneWidget);
      expect(find.textContaining('¿Quisiste decir', findRichText: true),
          findsNothing);
    });
  });
}
