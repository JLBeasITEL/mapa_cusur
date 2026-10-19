/// Resumen estadístico de las mediciones registradas bajo una etiqueta.
class ResumenCronometro {
  final int n;
  final double promedioMicros;
  final int minMicros;
  final int maxMicros;

  const ResumenCronometro({
    required this.n,
    required this.promedioMicros,
    required this.minMicros,
    required this.maxMicros,
  });

  static const ResumenCronometro vacio =
      ResumenCronometro(n: 0, promedioMicros: 0, minMicros: 0, maxMicros: 0);
}

/// Mide en microsegundos cuánto tardan operaciones nombradas (parseo del
/// JSON, interpolación del grafo, cada ejecución de Dijkstra) y acumula el
/// historial para poder reportar promedio/mínimo/máximo. Pensado para el
/// panel de depuración de la Fase 5; no tiene ningún efecto sobre el
/// comportamiento de la app -si nunca se llama a [medir], no mide nada-.
class Cronometro {
  final Map<String, List<int>> _medicionesMicros = {};

  /// Ejecuta [accion], mide cuánto tardó y guarda la medición bajo
  /// [etiqueta]. Devuelve el resultado de [accion] sin modificarlo.
  T medir<T>(String etiqueta, T Function() accion) {
    final sw = Stopwatch()..start();
    final T resultado = accion();
    sw.stop();
    (_medicionesMicros[etiqueta] ??= []).add(sw.elapsedMicroseconds);
    return resultado;
  }

  /// Variante asíncrona de [medir].
  Future<T> medirAsync<T>(String etiqueta, Future<T> Function() accion) async {
    final sw = Stopwatch()..start();
    final T resultado = await accion();
    sw.stop();
    (_medicionesMicros[etiqueta] ??= []).add(sw.elapsedMicroseconds);
    return resultado;
  }

  List<int> medicionesDe(String etiqueta) =>
      List.unmodifiable(_medicionesMicros[etiqueta] ?? const []);

  ResumenCronometro resumenDe(String etiqueta) {
    final valores = _medicionesMicros[etiqueta];
    if (valores == null || valores.isEmpty) return ResumenCronometro.vacio;
    final int suma = valores.reduce((a, b) => a + b);
    return ResumenCronometro(
      n: valores.length,
      promedioMicros: suma / valores.length,
      minMicros: valores.reduce((a, b) => a < b ? a : b),
      maxMicros: valores.reduce((a, b) => a > b ? a : b),
    );
  }

  List<String> get etiquetas => _medicionesMicros.keys.toList();

  void limpiar() => _medicionesMicros.clear();
}
