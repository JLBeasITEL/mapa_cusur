import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mapa_cusur/data/campus_repository.dart';
import 'package:mapa_cusur/data/mapa_vectorial_parser.dart';
import 'package:mapa_cusur/models/mapa_vectorial.dart';

/// Un JSON mínimo con un elemento de cada sección, para comprobar campo por
/// campo cómo se traduce cada clave.
Map<String, dynamic> _jsonMinimo() => {
      'version': 1,
      'meta': {
        'origen': {'lat': 19.7252, 'lng': -103.4615},
        'metros_por_grado': {'lat': 110574.0, 'lng': 104787.986},
        'limites': {'min_x': -10, 'min_y': -20.5, 'max_x': 30, 'max_y': 40},
        'atribucion': '© colaboradores de OpenStreetMap',
        'licencia': 'ODbL 1.0',
      },
      'campus': [
        [0, 0],
        [10, 0],
        [10, 10],
        [0, 0],
      ],
      'areas_verdes': [
        [
          [1, 1],
          [2, 1],
          [2, 2],
          [1, 1],
        ],
      ],
      'zonas_deportivas': [
        {
          'nombre': 'Unidad',
          'poligono': [
            [0, 0],
            [1, 0],
            [0, 0],
          ],
          'etiqueta': [0.5, 0.2],
        },
      ],
      'canchas_futbol': [
        {
          'nombre': null,
          'poligono': [
            [0, 0],
            [1, 0],
            [0, 0],
          ],
          'linea_media': [
            [0, 5],
            [10, 5],
          ],
          'circulo_central': {
            'centro': [5, 5],
            'radio': 9.15,
          },
          'icono': 'sports_soccer',
          'icono_pos': [5, 5],
        },
      ],
      'canchas': [
        {
          'tipo': 'baloncesto',
          'poligono': [
            [0, 0],
            [1, 0],
            [0, 0],
          ],
          'lineas': [
            [
              [0, 1],
              [1, 1],
            ],
          ],
          'circulos': [
            {
              'centro': [0.5, 0.5],
              'radio': 1.8,
            },
          ],
          'semicirculos': [
            [
              [0, 0],
              [0.5, 0.3],
              [1, 0],
            ],
          ],
          'icono': null,
          'icono_pos': null,
        },
      ],
      'vialidades': [
        {
          'tipo': 'servicio',
          'nombre': null,
          'linea': [
            [0, 0],
            [5, 5],
          ],
          'ancho': 4,
        },
      ],
      'etiquetas_calles': [
        {
          'texto': 'Calle',
          'pos': [1, 2],
          'angulo_grados': -88.7,
        },
      ],
      'edificios': [
        {
          'nombre': null,
          'letra': null,
          'texto': null,
          'tipo': 'techo',
          'anillos': [
            [
              [0, 0],
              [4, 0],
              [4, 4],
              [0, 0],
            ],
            [
              [1, 1],
              [2, 1],
              [2, 2],
              [1, 1],
            ],
          ],
          'etiqueta': [2, 2],
          'icono': 'pool',
          'subtitulo': ['Línea 1', 'Línea 2'],
          'nodos': ['Alberca'],
          'origen': 'trazo propio',
        },
      ],
      'lugares': [
        {
          'nombre': 'Laboratorio de Periodismo',
          'lineas': ['Laboratorio de', 'Periodismo'],
          'icono': 'newspaper',
          'pos': [-31, -22],
          'en_area_verde': true,
        },
      ],
      'entradas': [
        {
          'nombre': 'Entrada Sur',
          'nodo': 'EntradaA',
          'pos': [-67.1, 150.4],
        },
      ],
      'estacionamientos': [
        {
          'nombre': 'Estacionamiento 1',
          'nodo': 'Estacionamiento1',
          'pos': [110.3, -153.6],
        },
      ],
    };

MapaVectorial _cargarAssetReal() => parsearMapaVectorial(
    json.decode(File('assets/campus_vector.json').readAsStringSync()));

void main() {
  group('parsearMapaVectorial — JSON sintético', () {
    test('traduce meta y convierte los enteros a double', () {
      final meta = parsearMapaVectorial(_jsonMinimo()).meta;

      expect(meta.origenLat, 19.7252);
      expect(meta.origenLng, -103.4615);
      expect(meta.metrosPorGradoLat, 110574.0);
      expect(meta.metrosPorGradoLng, 104787.986);
      expect(meta.minX, -10.0);
      expect(meta.minY, -20.5);
      expect(meta.maxX, 30.0);
      expect(meta.maxY, 40.0);
      expect(meta.atribucion, '© colaboradores de OpenStreetMap');
      expect(meta.licencia, 'ODbL 1.0');
    });

    test('traduce cada sección con sus campos opcionales', () {
      final mapa = parsearMapaVectorial(_jsonMinimo());

      expect(mapa.version, 1);
      expect(mapa.campus, hasLength(4));
      expect(mapa.campus[1], const Offset(10, 0));
      expect(mapa.areasVerdes.single.first, const Offset(1, 1));

      final zona = mapa.zonasDeportivas.single;
      expect(zona.nombre, 'Unidad');
      expect(zona.etiqueta, const Offset(0.5, 0.2));

      final futbol = mapa.canchasFutbol.single;
      expect(futbol.nombre, isNull);
      expect(futbol.lineaMedia, [const Offset(0, 5), const Offset(10, 5)]);
      expect(futbol.circuloCentral.centro, const Offset(5, 5));
      expect(futbol.circuloCentral.radio, 9.15);
      expect(futbol.icono, 'sports_soccer');
      expect(futbol.iconoPos, const Offset(5, 5));

      final cancha = mapa.canchas.single;
      expect(cancha.tipo, TipoCancha.baloncesto);
      expect(cancha.lineas.single, [const Offset(0, 1), const Offset(1, 1)]);
      expect(cancha.circulos.single.radio, 1.8);
      expect(cancha.semicirculos.single, hasLength(3));
      expect(cancha.icono, isNull);
      expect(cancha.iconoPos, isNull);

      final vialidad = mapa.vialidades.single;
      expect(vialidad.tipo, TipoVialidad.servicio);
      expect(vialidad.nombre, isNull);
      expect(vialidad.ancho, 4.0);
      expect(vialidad.linea.last, const Offset(5, 5));

      final etiqueta = mapa.etiquetasCalles.single;
      expect(etiqueta.texto, 'Calle');
      expect(etiqueta.pos, const Offset(1, 2));
      expect(etiqueta.anguloGrados, -88.7);

      final edificio = mapa.edificios.single;
      expect(edificio.nombre, isNull);
      expect(edificio.letra, isNull);
      expect(edificio.texto, isNull);
      expect(edificio.tipo, TipoEdificio.techo);
      expect(edificio.anillos, hasLength(2)); // contorno + un hueco
      expect(edificio.etiqueta, const Offset(2, 2));
      expect(edificio.icono, 'pool');
      expect(edificio.subtitulo, ['Línea 1', 'Línea 2']);
      expect(edificio.nodos, ['Alberca']);
      expect(edificio.origen, 'trazo propio');

      final lugar = mapa.lugares.single;
      expect(lugar.lineas, ['Laboratorio de', 'Periodismo']);
      expect(lugar.icono, 'newspaper');
      expect(lugar.pos, const Offset(-31, -22));
      expect(lugar.enAreaVerde, isTrue);

      expect(mapa.entradas.single.nodo, 'EntradaA');
      expect(mapa.entradas.single.pos, const Offset(-67.1, 150.4));
      expect(mapa.estacionamientos.single.nombre, 'Estacionamiento 1');
    });

    test('un subtítulo ausente queda en null', () {
      final data = _jsonMinimo();
      (data['edificios'] as List).first['subtitulo'] = null;

      expect(parsearMapaVectorial(data).edificios.single.subtitulo, isNull);
    });

    test('las listas que entrega no se pueden modificar', () {
      final mapa = parsearMapaVectorial(_jsonMinimo());

      expect(() => mapa.edificios.clear(), throwsUnsupportedError);
      expect(() => mapa.campus.add(Offset.zero), throwsUnsupportedError);
      expect(() => mapa.edificios.single.anillos.first.clear(),
          throwsUnsupportedError);
    });

    test('un tipo desconocido lanza FormatException en vez de adivinar', () {
      final data = _jsonMinimo();
      (data['canchas'] as List).first['tipo'] = 'voleibol';

      expect(() => parsearMapaVectorial(data), throwsFormatException);
    });
  });

  group('parsearMapaVectorial — assets/campus_vector.json real', () {
    test('tiene los conteos del archivo entregado', () {
      final mapa = _cargarAssetReal();

      expect(mapa.edificios, hasLength(36));
      expect(mapa.areasVerdes, hasLength(57));
      expect(mapa.canchasFutbol, hasLength(2));
      expect(mapa.canchas, hasLength(7));
      expect(mapa.vialidades, hasLength(40));
      expect(mapa.etiquetasCalles, hasLength(3));
      expect(mapa.lugares, hasLength(9));
      expect(mapa.entradas, hasLength(3));
      expect(mapa.estacionamientos, hasLength(5));
    });

    test('meta.atribucion no está vacía (la exige la ODbL)', () {
      expect(_cargarAssetReal().meta.atribucion.trim(), isNotEmpty);
    });
  });

  group('CampusRepository.cargarMapaVectorial', () {
    TestWidgetsFlutterBinding.ensureInitialized();

    test('lee el asset empaquetado', () async {
      final mapa = await const CampusRepository().cargarMapaVectorial();

      expect(mapa.edificios, hasLength(36));
      expect(mapa.meta.atribucion, '© colaboradores de OpenStreetMap');
    });
  });
}
