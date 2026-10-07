/// Radio alrededor del nodo de destino dentro del cual se considera que el
/// usuario ya llegó. El GPS de un teléfono tiene un error típico de 3 a
/// 10 m y los nodos interpolados del grafo están separados hasta 8 m, así
/// que comparar solo "nodo más cercano == destino" casi nunca se cumpliría
/// en la práctica: el usuario puede estar parado en el destino y que la
/// lectura lo proyecte sobre una arista vecina.
const double kRadioLlegadaMetros = 10.0;

/// Condición de llegada durante la navegación con la ubicación actual:
/// la ruta tiene un solo nodo (origen y destino coinciden) o la posición
/// proyectada del usuario está a [kRadioLlegadaMetros] o menos del nodo
/// de destino.
bool llegoAlDestino({
  required int nodosEnRuta,
  required double distanciaMetros,
}) {
  return nodosEnRuta == 1 || distanciaMetros <= kRadioLlegadaMetros;
}
