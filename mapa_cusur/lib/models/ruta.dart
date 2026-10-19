/// El resultado de calcular la ruta más corta entre dos nodos: la secuencia
/// completa de nodos (incluyendo fantasma) y el tiempo total en minutos.
class Ruta {
  final List<String> nodos;
  final double minutos;

  const Ruta({required this.nodos, required this.minutos});

  bool get esVacia => nodos.isEmpty;

  static const Ruta vacia = Ruta(nodos: [], minutos: 0.0);
}
