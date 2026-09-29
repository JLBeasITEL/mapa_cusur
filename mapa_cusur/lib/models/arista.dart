/// Una conexión dirigida entre dos nodos, con su peso en minutos.
class Arista {
  final String origen;
  final String destino;
  final double pesoMinutos;

  const Arista({
    required this.origen,
    required this.destino,
    required this.pesoMinutos,
  });
}
