import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;

import '../models/grafo_campus.dart';
import '../models/mapa_vectorial.dart';
import '../utils/cronometro.dart';
import 'campus_json_parser.dart';
import 'mapa_vectorial_parser.dart';

/// Calibración congelada: copia exacta del `assets/campus_data.json` de la
/// etiqueta `v-pruebas-campo`. La afín, la escala px/m, el RMSE y la
/// instrumentación de campo se calculan con ella, así que esas cifras son
/// las de la tesis aunque el grafo de navegación cambie. No se edita.
const String kRutaCalibracion = 'assets/calibracion_campo.json';

/// El grafo base (antes de interpolar), los IDs de los puntos de control
/// para `TransformacionAfin` y los nodos cuyo píxel no es digitalizado (ver
/// [parsearPixelesDerivados]).
typedef DatosCampus = ({
  GrafoCampus grafo,
  List<String> puntosControl,
  List<String> pixelesDerivados,
});

/// Carga los datos del campus, la calibración congelada y el mapa vectorial
/// desde los assets del paquete.
class CampusRepository {
  const CampusRepository();

  /// Si se pasa [cronometro] (Fase 5, panel de depuración), mide en
  /// microsegundos el `json.decode` bajo la etiqueta `"parseo_json"`. Es
  /// opcional y no cambia el resultado: sin él, el comportamiento es
  /// idéntico.
  Future<DatosCampus> cargarDatosCampus({
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
      pixelesDerivados: parsearPixelesDerivados(data),
    );
  }

  /// Carga la calibración congelada ([kRutaCalibracion]). Solo sirve para
  /// las transformaciones y sus cifras; la navegación usa
  /// [cargarDatosCampus].
  Future<DatosCampus> cargarCalibracion({String ruta = kRutaCalibracion}) =>
      cargarDatosCampus(ruta: ruta);

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
