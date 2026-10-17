import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;

import '../models/grafo_campus.dart';
import '../models/mapa_vectorial.dart';
import '../utils/cronometro.dart';
import 'campus_json_parser.dart';
import 'mapa_vectorial_parser.dart';

/// Carga los datos del campus (el grafo base, antes de interpolar, y los
/// IDs de los puntos de control para `TransformacionAfin`) y el mapa
/// vectorial desde los assets del paquete.
class CampusRepository {
  const CampusRepository();

  /// Si se pasa [cronometro] (Fase 5, panel de depuración), mide en
  /// microsegundos el `json.decode` bajo la etiqueta `"parseo_json"`. Es
  /// opcional y no cambia el resultado: sin él, el comportamiento es
  /// idéntico.
  Future<({GrafoCampus grafo, List<String> puntosControl})> cargarDatosCampus({
    String ruta = 'assets/campus_data.json',
    Cronometro? cronometro,
  }) async {
    final String contenido = await rootBundle.loadString(ruta);
    final Map<String, dynamic> data = cronometro != null
        ? cronometro.medir(
            'parseo_json', () => json.decode(contenido) as Map<String, dynamic>)
        : json.decode(contenido) as Map<String, dynamic>;
    return (
      grafo: parsearGrafoCampus(data),
      puntosControl: parsearPuntosControl(data),
    );
  }

  /// Carga el mapa vectorial (edificios, calles, áreas verdes...) de
  /// `assets/campus_vector.json`. Es una carga aparte de
  /// [cargarDatosCampus] a propósito: el grafo no depende de ella, así que
  /// quien la llame no debe esperarla antes de cargar el grafo.
  Future<MapaVectorial> cargarMapaVectorial({
    String ruta = 'assets/campus_vector.json',
  }) async {
    final String contenido = await rootBundle.loadString(ruta);
    return parsearMapaVectorial(
        json.decode(contenido) as Map<String, dynamic>);
  }
}
