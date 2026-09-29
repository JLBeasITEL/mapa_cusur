import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;

import '../models/grafo_campus.dart';
import '../utils/cronometro.dart';
import 'campus_json_parser.dart';

/// Carga los datos del campus (el grafo base, antes de interpolar, y los
/// IDs de los puntos de control para `TransformacionAfin`) desde el asset
/// del paquete.
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
}
