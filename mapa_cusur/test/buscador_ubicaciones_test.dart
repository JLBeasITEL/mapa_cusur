import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mapa_cusur/data/diccionario_nombres.dart';
import 'package:mapa_cusur/data/ubicaciones_buscables.dart';
import 'package:mapa_cusur/domain/buscador_ubicaciones.dart';
import 'package:mapa_cusur/models/ubicacion_buscable.dart';
import 'package:mapa_cusur/ui/widgets/autocomplete_input_field.dart';

const _laboratorio = 'Laboratorio de técnicas deportivas y de rescate';

/// Buscador con lugares genéricos (no son datos del campus).
BuscadorUbicaciones _generico(List<String> nombres) => BuscadorUbicaciones(
    [for (final n in nombres) UbicacionBuscable(id: n, nombre: n)]);

List<String> _nombres(List<ResultadoBusqueda> r) =>
    [for (final x in r) x.nombre];

void main() {
  // Los 52 lugares reales con sus nombres alternativos.
  final campus =
      BuscadorUbicaciones(ubicacionesBuscables(diccionarioNombres.keys));

  group('ubicacionesBuscables', () {
    test('toma los lugares con nombre amigable, con sus alternativos', () {
      final lugares = ubicacionesBuscables(diccionarioNombres.keys);
      expect(lugares, hasLength(diccionarioNombres.length));
      final gimnasio = lugares.singleWhere((u) => u.id == 'Gimnasio');
      expect(gimnasio.nombre, _laboratorio);
      expect(gimnasio.alias, ['Gimnasio']);
    });

    test('ignora los nodos sin nombre amigable', () {
      final lugares = ubicacionesBuscables(['Rectoria', 'R4', 'SP6']);
      expect([for (final u in lugares) u.id], ['Rectoria']);
    });
  });

  group('palabrasDeConsulta', () {
    test('quita las palabras vacías si hay otras', () {
      expect(palabrasDeConsulta('cancha de futbol'), ['cancha', 'futbol']);
      expect(palabrasDeConsulta('la y el los las del de rectoria'),
          ['rectoria']);
    });

    test('las conserva si la consulta no tiene otras', () {
      expect(palabrasDeConsulta('de'), ['de']);
      expect(palabrasDeConsulta('de la'), ['de', 'la']);
    });
  });

  group('ejemplos del objetivo', () {
    test('acentos y mayúsculas no importan', () {
      for (final consulta in ['rectoria', 'RECTORÍA', 'Rectoria', 'rectoría']) {
        final r = campus.buscar(consulta);
        expect(r.first.nombre, 'Rectoría', reason: consulta);
        expect(r.first.nivel, NivelCoincidencia.exacta, reason: consulta);
      }
      expect(_nombres(campus.buscar('cafeteria pequena')),
          ['Cafetería Pequeña']);
    });

    test('espacios de más no importan', () {
      expect(_nombres(campus.buscar('  biblioteca  ')),
          _nombres(campus.buscar('biblioteca')));
      expect(_nombres(campus.buscar('biblioteca')), ['C.A.S.A. (Biblioteca)']);
      expect(_nombres(campus.buscar('edificio    m')), ['Edificio M']);
    });

    test('palabras que empiezan igual, en cualquier orden', () {
      for (final consulta in ['lab prog', 'prog lab', 'PROG  Lab']) {
        expect(_nombres(campus.buscar(consulta)),
            ['Laboratorio de Programación'],
            reason: consulta);
      }
      expect(campus.buscar('prog lab').single.nivel,
          NivelCoincidencia.palabras);
    });

    test('cada palabra de la consulta tiene que coincidir', () {
      expect(campus.buscar('lab futbol'), isEmpty);
      expect(campus.buscar('edificio 9'), isEmpty);
    });

    test('las palabras vacías se ignoran si hay otras', () {
      expect(_nombres(campus.buscar('cancha de futbol')),
          ['Cancha de fútbol central', 'Cancha de fútbol norte']);
      expect(_nombres(campus.buscar('la cancha central')),
          ['Cancha de fútbol central']);
    });

    test('una palabra vacía sola sí se busca', () {
      // "de" es el inicio de "deportivas".
      expect(_nombres(campus.buscar('de')), contains(_laboratorio));
    });

    test('consulta vacía o sin letras ni dígitos no da resultados', () {
      expect(campus.buscar(''), isEmpty);
      expect(campus.buscar('   '), isEmpty);
      expect(campus.buscar('.-'), isEmpty);
    });
  });

  group('siglas con puntos', () {
    test('"casa" encuentra C.A.S.A. (Biblioteca) y Auditorio C.A.S.A.', () {
      final r = campus.buscar('casa');
      expect(_nombres(r), ['C.A.S.A. (Biblioteca)', 'Auditorio C.A.S.A.']);
      expect(r[0].nivel, NivelCoincidencia.empiezaCon);
      expect(r[1].nivel, NivelCoincidencia.palabras);
    });

    test('también con puntos o con espacios', () {
      for (final consulta in ['c.a.s.a.', 'C.A.S.A', 'c a s a']) {
        expect(_nombres(campus.buscar(consulta)).take(2),
            ['C.A.S.A. (Biblioteca)', 'Auditorio C.A.S.A.'],
            reason: consulta);
      }
    });

    test('"cmid" encuentra C.M.I.D. como coincidencia exacta', () {
      for (final consulta in ['cmid', 'CMID', 'c.m.i.d.', 'c m i d']) {
        final r = campus.buscar(consulta);
        expect(r.first.nombre, 'C.M.I.D.', reason: consulta);
        expect(r.first.nivel, NivelCoincidencia.exacta, reason: consulta);
      }
    });

    test('"auditorio casa" encuentra el Auditorio C.A.S.A.', () {
      final r = campus.buscar('auditorio casa');
      expect(r.first.nombre, 'Auditorio C.A.S.A.');
      expect(r.first.nivel, NivelCoincidencia.exacta);
    });
  });

  group('ranking', () {
    test('exacta > empieza con > palabras > contiene', () {
      final buscador = _generico(
          ['Omegalfa', 'Gamma Alfa', 'Alfa Beta', 'Alfa', 'Delta']);
      final r = buscador.buscar('alfa');
      expect(_nombres(r), ['Alfa', 'Alfa Beta', 'Gamma Alfa', 'Omegalfa']);
      expect([for (final x in r) x.nivel], [
        NivelCoincidencia.exacta,
        NivelCoincidencia.empiezaCon,
        NivelCoincidencia.palabras,
        NivelCoincidencia.contiene,
      ]);
    });

    test('"contiene" exige cada palabra dentro de alguna palabra', () {
      final buscador = _generico(['Omegalfa Zetabeta', 'Omegalfa']);
      expect(_nombres(buscador.buscar('alfa beta')), ['Omegalfa Zetabeta']);
    });

    test('dentro de un nivel, alfabético sin importar acentos ni mayúsculas',
        () {
      final buscador =
          _generico(['Bosque Norte', 'Ánfora Norte', 'zona Norte']);
      expect(_nombres(buscador.buscar('norte')),
          ['Ánfora Norte', 'Bosque Norte', 'zona Norte']);
    });

    test('los edificios salen en orden alfabético', () {
      final r = campus.buscar('edificio');
      expect(r.every((x) => x.nivel == NivelCoincidencia.empiezaCon), isTrue);
      final nombres = _nombres(r);
      expect(nombres.first, 'Edificio B');
      expect(nombres.last, 'Edificio Z');
      expect(nombres, [...nombres]..sort());
    });

    test('la coincidencia exacta va antes que las demás', () {
      expect(_nombres(campus.buscar('cafeteria principal')).first,
          'Cafetería Principal');
      expect(_nombres(campus.buscar('estacionamiento 3')),
          ['Estacionamiento 3']);
    });
  });

  group('nombres alternativos', () {
    test('"gimn" encuentra el laboratorio con su nombre oficial', () {
      final r = campus.buscar('gimn');
      expect(r.single.nombre, _laboratorio);
      expect(r.single.id, 'Gimnasio');
      expect(r.single.aliasCoincidente, 'Gimnasio');
      expect(r.single.nivel, NivelCoincidencia.empiezaCon);
    });

    test('si coincide por el nombre, no se reporta alias', () {
      final r = campus.buscar('tecnicas deportivas');
      expect(r.single.nombre, _laboratorio);
      expect(r.single.aliasCoincidente, isNull);
    });

    test('a igual nivel gana el nombre; un alias mejor sube el nivel', () {
      final buscador = BuscadorUbicaciones(const [
        UbicacionBuscable(id: 'a', nombre: 'Alfa Uno', alias: ['Alfa Dos']),
        UbicacionBuscable(id: 'b', nombre: 'Beta Alfa', alias: ['Alfa']),
      ]);
      final r = buscador.buscar('alfa');
      expect(r, hasLength(2), reason: 'cada lugar aparece una sola vez');
      expect(r[0].id, 'b');
      expect(r[0].nivel, NivelCoincidencia.exacta);
      expect(r[0].aliasCoincidente, 'Alfa');
      expect(r[1].id, 'a');
      expect(r[1].nivel, NivelCoincidencia.empiezaCon);
      expect(r[1].aliasCoincidente, isNull);
    });
  });

  group('AutocompleteInputField con el buscador', () {
    Future<void> montar(WidgetTester tester, void Function(String) onSelected) =>
        tester.pumpWidget(MaterialApp(
          home: Scaffold(
            body: AutocompleteInputField(
              iconColor: Colors.red,
              title: 'Destino',
              placeholder: '¿A dónde vas?',
              suggestions: const [],
              buscador: campus,
              onSelected: onSelected,
            ),
          ),
        ));

    testWidgets('sin acentos ni orden encuentra el lugar y lo elige',
        (WidgetTester tester) async {
      String? elegido;
      await montar(tester, (v) => elegido = v);

      await tester.enterText(find.byType(TextField), 'prog lab');
      await tester.pumpAndSettle();

      final opcion = find.descendant(
          of: find.byType(ListView),
          matching: find.text('Laboratorio de Programación'));
      expect(opcion, findsOneWidget);

      await tester.tap(opcion);
      await tester.pumpAndSettle();
      expect(elegido, 'Laboratorio de Programación');
      expect(find.widgetWithText(TextField, 'Laboratorio de Programación'),
          findsOneWidget);
    });

    testWidgets('las opciones salen en orden de relevancia',
        (WidgetTester tester) async {
      await montar(tester, (_) {});

      await tester.enterText(find.byType(TextField), 'casa');
      await tester.pumpAndSettle();

      final biblioteca = tester.getTopLeft(find.descendant(
          of: find.byType(ListView),
          matching: find.text('C.A.S.A. (Biblioteca)')));
      final auditorio = tester.getTopLeft(find.descendant(
          of: find.byType(ListView), matching: find.text('Auditorio C.A.S.A.')));
      expect(biblioteca.dy, lessThan(auditorio.dy));
    });
  });
}
