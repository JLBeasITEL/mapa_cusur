// Fase 6c: aplica a assets/campus_data.json un bloque de cambios del grafo
// (nodos nuevos o movidos, aristas que se quitan o se agregan) descrito en
// un JSON, y reporta su efecto con el código de producción:
//
//   - pesos: round(km de Haversine / 0.0667, 2), la relación de las aristas
//     existentes (minutos a 4 km/h, `km_a_minutos` de exportar_rutas.py);
//   - coordenadas_pix derivadas: el píxel del nodo digitalizado más cercano
//     más el desplazamiento de TransformacionAfin.aPixeles entre ambos; el
//     nodo entra en `pixeles_derivados`;
//   - regresión: los pares entre nodos con nombre cuya distancia o
//     recorrido cambia, con R1, R2 y R3 (las rutas de ejemplo de
//     docs/mapa_vectorial/mapa-vectorial-referencia.html);
//   - conectividad y validador, antes y después;
//   - las cifras de transformación de assets/calibracion_campo.json, con
//     las que calibra la app (no dependen del bloque).
//
// Sin --aplicar no toca assets/: escribe el JSON resultante y el informe en
// build/fase6c/. Formato del bloque (x, y en metros de campus_vector.json):
//   {"bloque": "...",
//    "nodos": [{"id": "CP1", "x": -102.0, "y": -86.8}],   // nuevo o movido
//    "quitar": [["Cafeteria", "SP1"]],                    // ambos sentidos
//    "agregar": [["Cafeteria", "CP1"]]}                   // ambos sentidos
//
// Uso: dart run tool/cambios_grafo.dart <bloque.json> [--aplicar]
import 'dart:convert';
import 'dart:io';

import 'package:mapa_cusur/data/campus_json_parser.dart';
import 'package:mapa_cusur/data/diccionario_nombres.dart';
import 'package:mapa_cusur/domain/dijkstra.dart';
import 'package:mapa_cusur/domain/interpolacion_nodos.dart';
import 'package:mapa_cusur/domain/transformacion_geo.dart';
import 'package:mapa_cusur/domain/validador_grafo.dart';
import 'package:mapa_cusur/models/grafo_campus.dart';
import 'package:mapa_cusur/utils/geodesia.dart';

import 'hash_ruta.dart';

const _rutasEjemplo = {
  'R1': ('Entrada Principal', 'Edificio M'),
  'R2': ('Rectoría', 'Auditorio C.A.S.A.'),
  'R3': ('C.M.I.D.', 'Auditorio Adolfo Aguilar Zínser'),
};

double _peso(Map<String, dynamic> geo, String a, String b) {
  final km = distanciaHaversineMetros(
          geo[a][0], geo[a][1], geo[b][0], geo[b][1]) /
      1000;
  return double.parse((km / 0.0667).toStringAsFixed(2));
}

typedef _Ruta = ({double? minutos, String hash, List<String> nodos});

Map<(String, String), _Ruta> _todasLasRutas(GrafoCampus base) {
  final grafo = interpolarGrafo(base);
  final ids = base.nodos.keys.where(diccionarioNombres.containsKey).toList()
    ..sort();
  return {
    for (final a in ids)
      for (final b in ids)
        if (a != b)
          (a, b): (() {
            final r = calcularRutaMasCorta(grafo, a, b);
            return (
              minutos: r.esVacia ? null : r.minutos,
              hash: r.esVacia ? 'inalcanzable' : hashRuta(r.nodos),
              nodos: [for (final n in r.nodos) if (base.nodos.containsKey(n)) n],
            );
          })(),
  };
}

Map<String, Object> _cifras(Map<String, dynamic> datos) {
  final grafo =
      parsearGrafoCampus(datos).sinNodos(parsearPixelesDerivados(datos));
  final afin = TransformacionAfin.ajustar(
      [for (final id in parsearPuntosControl(datos)) grafo.nodos[id]!]);
  final dosPuntos = TransformacionDosPuntos(
      controlA: grafo.nodos['EntradaA']!, controlB: grafo.nodos['Edificio_M']!);
  final pxPorMetro = calcularEscalaPxPorMetro(grafo);
  final rAfin =
      evaluarTransformacion(afin, grafo.nodos.values, pxPorMetro: pxPorMetro);
  final rDos = evaluarTransformacion(dosPuntos, grafo.nodos.values,
      pxPorMetro: pxPorMetro);
  return {
    'nodos_digitalizados': grafo.nodos.length,
    'px_por_metro': pxPorMetro,
    'afin_px': rAfin.rmsePx,
    'afin_m': rAfin.rmseMetros,
    'dos_puntos_px': rDos.rmsePx,
    'dos_puntos_m': rDos.rmseMetros,
  };
}

Map<String, List<String>> _problemas(ResultadoValidacionGrafo r) => {
      'ids inexistentes': [for (final p in r.idsInexistentes) p.descripcion],
      'aristas asimétricas': [
        for (final p in r.aristasAsimetricas) p.descripcion
      ],
      'pesos no positivos': [for (final p in r.pesosNoPositivos) p.descripcion],
      'pesos no finitos': [for (final p in r.pesosNoFinitos) p.descripcion],
      'autolazos': [for (final p in r.autolazos) p.descripcion],
      'componentes desconectadas': [
        for (final p in r.componentesDesconectadas) p.descripcion
      ],
      'píxeles duplicados': [for (final p in r.pixelesDuplicados) p.descripcion],
    };

void main(List<String> args) {
  if (args.isEmpty) {
    stderr.writeln('Uso: dart run tool/cambios_grafo.dart <bloque.json> '
        '[--aplicar]');
    exit(64);
  }
  final aplicar = args.contains('--aplicar');
  final bloque = json.decode(File(args.first).readAsStringSync())
      as Map<String, dynamic>;
  final nombreBloque = File(args.first).uri.pathSegments.last
      .replaceAll(RegExp(r'\.json$'), '');

  final archivo = File('assets/campus_data.json');
  final texto = archivo.readAsStringSync();
  final crlf = texto.contains('\r\n');
  final antes = json.decode(texto) as Map<String, dynamic>;
  final despues = json.decode(texto) as Map<String, dynamic>;
  final meta = (json.decode(File('assets/campus_vector.json')
      .readAsStringSync()) as Map<String, dynamic>)['meta'];

  final Map<String, dynamic> geo = despues['coordenadas_geo'];
  final Map<String, dynamic> pix = despues['coordenadas_pix'];
  final Map<String, dynamic> con = despues['conexiones'];
  final List<dynamic> derivados = despues['pixeles_derivados'];
  final errores = <String>[];

  // Nodos nuevos o movidos: metros locales -> lat/lng (inversa de
  // ProyeccionLocal.geoALocal) y píxel derivado.
  final grafoAntes = parsearGrafoCampus(antes);
  final digitalizados =
      grafoAntes.sinNodos(parsearPixelesDerivados(antes)).nodos;
  final afin = TransformacionAfin.ajustar([
    for (final id in parsearPuntosControl(antes)) digitalizados[id]!,
  ]);
  final tocados = {for (final n in bloque['nodos'] ?? []) n['id'] as String};
  final informeNodos = [];
  for (final n in bloque['nodos'] ?? []) {
    final id = n['id'] as String;
    final x = (n['x'] as num).toDouble(), y = (n['y'] as num).toDouble();
    final lat = double.parse((meta['origen']['lat'] -
            y / meta['metros_por_grado']['lat'])
        .toStringAsFixed(9));
    final lng = double.parse((meta['origen']['lng'] +
            x / meta['metros_por_grado']['lng'])
        .toStringAsFixed(9));
    final movido = geo.containsKey(id);
    String? ancla;
    var mejor = double.infinity;
    for (final d in digitalizados.values) {
      if (tocados.contains(d.id)) continue;
      final dist = distanciaHaversineMetros(lat, lng, d.lat, d.lng);
      if (dist < mejor) (mejor, ancla) = (dist, d.id);
    }
    final a = digitalizados[ancla]!;
    final pa = afin.aPixeles(a.lat, a.lng), pn = afin.aPixeles(lat, lng);
    final px = [
      (a.pixelX + pn.x - pa.x).round(),
      (a.pixelY + pn.y - pa.y).round(),
    ];
    informeNodos.add({
      'id': id,
      'x': x,
      'y': y,
      'lat': lat,
      'lng': lng,
      'movido': movido,
      if (movido) 'pix_anterior': pix[id],
      if (movido) 'geo_anterior': geo[id],
      'pix': px,
      'ancla': ancla,
      'metros_al_ancla': mejor,
    });
    geo[id] = [lat, lng];
    pix[id] = px;
    con.putIfAbsent(id, () => <String, dynamic>{});
    if (!derivados.contains(id)) derivados.add(id);
  }

  final quitadas = [];
  for (final par in bloque['quitar'] ?? []) {
    final a = par[0] as String, b = par[1] as String;
    final pab = con[a]?.remove(b), pba = con[b]?.remove(a);
    if (pab == null && pba == null) errores.add('No existe la arista $a–$b');
    quitadas.add({'a': a, 'b': b, 'peso_ab': pab, 'peso_ba': pba});
  }
  final agregadas = [];
  for (final par in bloque['agregar'] ?? []) {
    final a = par[0] as String, b = par[1] as String;
    if (!geo.containsKey(a) || !geo.containsKey(b)) {
      errores.add('Nodo inexistente en $a–$b');
      continue;
    }
    if (con[a].containsKey(b) || con[b].containsKey(a)) {
      errores.add('Ya existe la arista $a–$b');
    }
    final peso = _peso(geo, a, b);
    con[a][b] = peso;
    con[b][a] = peso;
    agregadas.add({
      'a': a,
      'b': b,
      'metros': distanciaHaversineMetros(
          geo[a][0], geo[a][1], geo[b][0], geo[b][1]),
      'peso': peso,
    });
  }
  if (errores.isNotEmpty) {
    stderr.writeln(errores.join('\n'));
    exit(1);
  }

  // Validador y conectividad.
  final grafoDespues = parsearGrafoCampus(despues);
  final vAntes = _problemas(validarGrafo(grafoAntes));
  final vDespues = _problemas(validarGrafo(grafoDespues));
  final validador = {
    for (final k in vAntes.keys)
      k: {
        'antes': vAntes[k]!.length,
        'despues': vDespues[k]!.length,
        'nuevos': vDespues[k]!.where((p) => !vAntes[k]!.contains(p)).toList(),
        'resueltos':
            vAntes[k]!.where((p) => !vDespues[k]!.contains(p)).toList(),
      },
  };

  // Regresión.
  final rAntes = _todasLasRutas(grafoAntes);
  final rDespues = _todasLasRutas(grafoDespues);
  final cambios = [];
  var mismoTiempoOtroCamino = 0;
  var inalcanzables = 0;
  for (final par in rDespues.keys) {
    final x = rAntes[par], y = rDespues[par]!;
    if (y.minutos == null) inalcanzables++;
    if (x == null) continue; // par con un nodo con nombre nuevo
    final dif = (y.minutos ?? double.infinity) - (x.minutos ?? double.infinity);
    if (dif.abs() > 0.001 || dif.isNaN) {
      cambios.add({
        'origen': diccionarioNombres[par.$1],
        'destino': diccionarioNombres[par.$2],
        'antes': x.minutos,
        'despues': y.minutos,
        'diferencia': dif,
      });
    } else if (x.hash != y.hash) {
      mismoTiempoOtroCamino++;
    }
  }
  cambios.sort((p, q) => ((q['diferencia'] as double).abs())
      .compareTo((p['diferencia'] as double).abs()));
  final porNombre = {
    for (final e in diccionarioNombres.entries) e.value: e.key,
  };
  final ejemplos = {
    for (final MapEntry(key: r, value: (o, d)) in _rutasEjemplo.entries)
      r: {
        'origen': o,
        'destino': d,
        'antes': rAntes[(porNombre[o]!, porNombre[d]!)]!.minutos,
        'despues': rDespues[(porNombre[o]!, porNombre[d]!)]!.minutos,
        'nodos_antes': rAntes[(porNombre[o]!, porNombre[d]!)]!.nodos,
        'nodos_despues': rDespues[(porNombre[o]!, porNombre[d]!)]!.nodos,
      },
  };

  final informe = {
    'bloque': bloque['bloque'],
    'nodos': informeNodos,
    'aristas_quitadas': quitadas,
    'aristas_agregadas': agregadas,
    'pares': rDespues.length,
    'pares_inalcanzables': inalcanzables,
    'pares_que_cambian_de_distancia': cambios.length,
    'mas_largos': cambios.where((c) => (c['diferencia'] as double) > 0).length,
    'mas_cortos': cambios.where((c) => (c['diferencia'] as double) < 0).length,
    'mismo_tiempo_otro_recorrido': mismoTiempoOtroCamino,
    'cambios': cambios,
    'rutas_ejemplo': ejemplos,
    'validador': validador,
    // La app calibra con el archivo congelado: estas son sus cifras, que no
    // dependen del bloque.
    'cifras_calibracion': _cifras(json.decode(
        File('assets/calibracion_campo.json').readAsStringSync())),
  };

  final dir = Directory('build/fase6c')..createSync(recursive: true);
  File('${dir.path}/${nombreBloque}_informe.json').writeAsStringSync(
      const JsonEncoder.withIndent('  ').convert(informe));
  var salida = const JsonEncoder.withIndent('    ').convert(despues);
  if (texto.endsWith('\n')) salida += '\n';
  if (crlf) salida = salida.replaceAll('\n', '\r\n');
  final destino =
      aplicar ? archivo : File('${dir.path}/campus_data_$nombreBloque.json');
  destino.writeAsStringSync(salida);

  stdout.writeln('${bloque['bloque']}');
  stdout.writeln('  ${informeNodos.length} nodos, '
      '${quitadas.length} aristas quitadas, ${agregadas.length} agregadas');
  stdout.writeln('  Pares: ${rDespues.length}, inalcanzables: $inalcanzables');
  stdout.writeln('  Cambian de distancia: ${cambios.length} '
      '(${informe['mas_largos']} más largos, ${informe['mas_cortos']} más '
      'cortos); mismo tiempo, otro recorrido: $mismoTiempoOtroCamino');
  if (cambios.isNotEmpty) {
    final c = cambios.first;
    stdout.writeln('  Mayor cambio: ${c['origen']} → ${c['destino']} '
        '${(c['antes'] as double?)?.toStringAsFixed(2)} → '
        '${(c['despues'] as double?)?.toStringAsFixed(2)} min');
  }
  for (final MapEntry(key: r, value: e) in ejemplos.entries) {
    stdout.writeln('  $r ${e['origen']} → ${e['destino']}: '
        '${(e['antes'] as double?)?.toStringAsFixed(2)} → '
        '${(e['despues'] as double?)?.toStringAsFixed(2)} min');
  }
  for (final MapEntry(key: k, value: v) in validador.entries) {
    if (v['antes'] != v['despues'] || (v['nuevos'] as List).isNotEmpty) {
      stdout.writeln('  Validador, $k: ${v['antes']} → ${v['despues']} '
          '(nuevos: ${v['nuevos']}, resueltos: ${v['resueltos']})');
    }
  }
  stdout.writeln('  Cifras de la calibración congelada (las que usa la app): '
      '${informe['cifras_calibracion']}');
  stdout.writeln('  -> ${destino.path}, ${dir.path}/${nombreBloque}_informe.json');
}
