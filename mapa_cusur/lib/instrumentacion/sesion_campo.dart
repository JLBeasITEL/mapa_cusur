/// El modelo del dispositivo se recibe por
/// `--dart-define=DISPOSITIVO=...` al compilar, no se elige dentro de la
/// app: todavía no está definido qué equipos se usarán en campo, así que
/// no tiene sentido mantener una lista fija en el código. Si la bandera no
/// se da, cae en `"sin_especificar"` en vez de fallar -sigue siendo
/// posible iniciar una sesión de registro sin haber fijado el dispositivo,
/// solo que esa columna queda con ese valor y hay que arreglarlo a mano
/// después si hace falta-.
const String dispositivoDeCompilacion =
    String.fromEnvironment('DISPOSITIVO', defaultValue: 'sin_especificar');

/// Los tres recorridos fijos de las pruebas de campo.
const List<int> kRecorridosDisponibles = [1, 2, 3];

/// Identifica una sesión de registro de campo: qué dispositivo, qué
/// recorrido y qué número de repetición, con un identificador de sesión y
/// una marca de tiempo generados al iniciarla. Se crea una vez, al
/// arrancar el registro (`ui/widgets/selector_sesion_campo.dart`, que le
/// pasa [dispositivoDeCompilacion] tal cual), y se usa para las columnas
/// de identificación de cada fila del CSV
/// (`instrumentacion/registro_csv_campo.dart`) y para el nombre del
/// archivo.
class SesionCampo {
  /// Se guarda sin modificar -tal como llegó de `--dart-define=DISPOSITIVO`
  /// o de quien construya la sesión- para la columna `dispositivo` del
  /// CSV. Ver [nombreArchivo] para la versión saneada usada en el nombre
  /// de archivo.
  final String dispositivo;
  final int recorrido;
  final int repeticion;
  final DateTime iniciadaEn;
  final String sessionId;

  SesionCampo({
    required this.dispositivo,
    required this.recorrido,
    required this.repeticion,
    DateTime? iniciadaEn,
  })  : iniciadaEn = iniciadaEn ?? DateTime.now(),
        sessionId = _marcaDeTiempo(iniciadaEn ?? DateTime.now());

  static String _marcaDeTiempo(DateTime momento) {
    return momento.toIso8601String().replaceAll(RegExp(r'[:.]'), '-');
  }

  static String _normalizarParaArchivo(String texto) {
    return texto.replaceAll(RegExp(r'[^A-Za-z0-9]+'), '_');
  }

  /// `recorrido` + `repeticion` en un solo identificador legible, para
  /// facilitar el análisis en el script de Python sin tener que combinar
  /// columnas.
  String get recorridoId => 'recorrido${recorrido}_rep$repeticion';

  /// El nombre de archivo incluye dispositivo, recorrido, repetición y
  /// marca de tiempo -tal como se pidió-, así que dos sesiones nunca
  /// pueden pisarse entre sí ni perder de dónde salió cada CSV.
  String get nombreArchivo {
    final dispositivoSlug = _normalizarParaArchivo(dispositivo);
    return 'registro_campo_${dispositivoSlug}_recorrido${recorrido}_'
        'rep${repeticion}_$sessionId.csv';
  }
}
