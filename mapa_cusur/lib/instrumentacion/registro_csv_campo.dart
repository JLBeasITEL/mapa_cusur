import 'dart:io';

import 'package:geolocator/geolocator.dart';

import '../domain/ubicacion_en_ruta.dart';
import 'sesion_campo.dart';

/// Registra en un CSV local, fila por fila, los datos de una sesión de
/// campo: tanto las lecturas de GPS continuas del recorrido (Fase 5, ítem
/// 2) como los puntos de verificación manual (ítem 3). Ambos tipos de fila
/// comparten el mismo esquema de columnas -las que no aplican a un tipo de
/// fila quedan vacías-, así que un único CSV por sesión basta para
/// reconstruir cualquier métrica después, sin volver al campus.
///
/// Recibe el directorio de destino ya resuelto (en vez de llamar a
/// `path_provider` aquí mismo) para poder probarse con un directorio
/// temporal de `dart:io`, sin necesitar simular el canal de plataforma del
/// plugin.
class RegistroCsvCampo {
  final SesionCampo sesion;
  final Directory directorio;

  File? _archivo;

  RegistroCsvCampo({required this.sesion, required this.directorio});

  /// Nombres de columna, en el orden exacto en que se escriben. Cualquier
  /// columna ausente en una fila dada se escribe vacía -nunca se omite ni
  /// se reordena una columna, para que el CSV sea siempre rectangular.
  static const List<String> columnas = [
    // --- Identificación de la sesión (una por fila, repetida) ---
    'timestamp_iso',
    'session_id',
    'dispositivo',
    'recorrido',
    'repeticion',
    'recorrido_id',
    'so',
    'so_version',
    'tipo_evento', // "lectura_gps" | "punto_verificacion"
    // --- Datos crudos de la lectura de GPS ---
    'lat',
    'lng',
    'accuracy_m',
    'speed_mps',
    'speed_accuracy_mps',
    'heading_deg', // vacío si no está disponible
    'heading_accuracy_deg', // vacío si no está disponible
    'is_mocked',
    // --- Derivados: filtrado y proyección (Fase 3) ---
    'lectura_aceptada',
    'proyeccion_lat',
    'proyeccion_lng',
    'distancia_al_camino_m',
    'arista_a',
    'arista_b',
    't_en_arista',
    'nodo_mas_cercano_metodo_anterior',
    'se_recalculo_ruta',
    // --- Solo en filas de punto de verificación ---
    'nodo_verificado_manualmente',
    'pixel_x_dospuntos',
    'pixel_y_dospuntos',
    'error_px_dospuntos',
    'error_m_dospuntos',
    'pixel_x_afin',
    'pixel_y_afin',
    'error_px_afin',
    'error_m_afin',
  ];

  Future<File> _obtenerArchivo() async {
    final archivo = _archivo;
    if (archivo != null) return archivo;
    if (!await directorio.exists()) {
      await directorio.create(recursive: true);
    }
    final nuevo = File('${directorio.path}/${sesion.nombreArchivo}');
    _archivo = nuevo;
    return nuevo;
  }

  static bool _headingDisponible(Position position) {
    return !position.heading.isNaN && position.headingAccuracy >= 0;
  }

  Map<String, String> _columnasBaseDeSesion(Position position, String tipoEvento) {
    return {
      'timestamp_iso': position.timestamp.toIso8601String(),
      'session_id': sesion.sessionId,
      'dispositivo': sesion.dispositivo,
      'recorrido': sesion.recorrido.toString(),
      'repeticion': sesion.repeticion.toString(),
      'recorrido_id': sesion.recorridoId,
      'so': Platform.operatingSystem,
      'so_version': Platform.operatingSystemVersion,
      'tipo_evento': tipoEvento,
      'lat': position.latitude.toString(),
      'lng': position.longitude.toString(),
      'accuracy_m': position.accuracy.toString(),
      'speed_mps': position.speed.toString(),
      'speed_accuracy_mps': position.speedAccuracy.toString(),
      'heading_deg':
          _headingDisponible(position) ? position.heading.toString() : '',
      'heading_accuracy_deg':
          _headingDisponible(position) ? position.headingAccuracy.toString() : '',
      'is_mocked': position.isMocked.toString(),
    };
  }

  /// Registra una lectura de GPS del recorrido continuo (ítem 2). [ubicacion]
  /// y [nodoMetodoAnterior] son `null` cuando la lectura fue descartada por
  /// el filtro de precisión -en ese caso [lecturaAceptada] debe ser `false`-
  /// y por lo tanto no llegó a proyectarse.
  Future<void> registrarLecturaGps({
    required Position position,
    required bool lecturaAceptada,
    UbicacionEnGrafo? ubicacion,
    String? nodoMetodoAnterior,
    bool? seRecalculoRuta,
  }) async {
    final fila = _columnasBaseDeSesion(position, 'lectura_gps');
    fila['lectura_aceptada'] = lecturaAceptada.toString();
    if (ubicacion != null) {
      fila['proyeccion_lat'] = ubicacion.lat.toString();
      fila['proyeccion_lng'] = ubicacion.lng.toString();
      fila['distancia_al_camino_m'] = ubicacion.distanciaAlCaminoMetros.toString();
      fila['arista_a'] = ubicacion.aristaA;
      fila['arista_b'] = ubicacion.aristaB;
      fila['t_en_arista'] = ubicacion.t.toString();
    }
    if (nodoMetodoAnterior != null) {
      fila['nodo_mas_cercano_metodo_anterior'] = nodoMetodoAnterior;
    }
    if (seRecalculoRuta != null) {
      fila['se_recalculo_ruta'] = seRecalculoRuta.toString();
    }
    await _escribirFila(fila);
  }

  /// Registra un punto de verificación manual (ítem 3): el usuario confirmó
  /// que está físicamente parado en [nodoVerificado], y se compara esa
  /// posición conocida contra lo que predice cada modelo de transformación
  /// para la lectura de GPS actual.
  Future<void> registrarPuntoVerificacion({
    required Position position,
    required String nodoVerificado,
    required ({double x, double y}) pixelDosPuntos,
    required double errorPxDosPuntos,
    required double errorMDosPuntos,
    required ({double x, double y}) pixelAfin,
    required double errorPxAfin,
    required double errorMAfin,
  }) async {
    final fila = _columnasBaseDeSesion(position, 'punto_verificacion');
    fila['lectura_aceptada'] = 'true';
    fila['nodo_verificado_manualmente'] = nodoVerificado;
    fila['pixel_x_dospuntos'] = pixelDosPuntos.x.toString();
    fila['pixel_y_dospuntos'] = pixelDosPuntos.y.toString();
    fila['error_px_dospuntos'] = errorPxDosPuntos.toString();
    fila['error_m_dospuntos'] = errorMDosPuntos.toString();
    fila['pixel_x_afin'] = pixelAfin.x.toString();
    fila['pixel_y_afin'] = pixelAfin.y.toString();
    fila['error_px_afin'] = errorPxAfin.toString();
    fila['error_m_afin'] = errorMAfin.toString();
    await _escribirFila(fila);
  }

  Future<void> _escribirFila(Map<String, String> valores) async {
    final archivo = await _obtenerArchivo();
    final bool existiaAntes = await archivo.exists() && await archivo.length() > 0;

    final buffer = StringBuffer();
    if (!existiaAntes) {
      buffer.writeln(columnas.map(_csvEscape).join(','));
    }
    buffer.writeln(columnas.map((c) => _csvEscape(valores[c] ?? '')).join(','));

    await archivo.writeAsString(buffer.toString(),
        mode: FileMode.append, flush: true);
  }

  static String _csvEscape(String valor) {
    if (valor.contains(',') || valor.contains('"') || valor.contains('\n')) {
      return '"${valor.replaceAll('"', '""')}"';
    }
    return valor;
  }
}
