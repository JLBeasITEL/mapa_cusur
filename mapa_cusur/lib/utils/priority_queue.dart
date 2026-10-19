/// Cola de prioridad respaldada por un montículo binario (min-heap) sobre
/// un arreglo: [add] y [removeFirst] son O(log n).
///
/// Antes (Fase 1 y anteriores) esta clase ordenaba la lista completa en
/// cada `add` y extraía con `removeAt(0)`: O(n log n) por inserción. Sobre
/// el grafo interpolado (~1000 nodos), ejecutándose en cada actualización
/// de GPS (que llega cada metro), era el cuello de botella del sistema. La
/// API pública (constructor con comparador, [isNotEmpty], [add],
/// [removeFirst]) no cambió, así que ningún llamador se modificó.
class PriorityQueue<T> {
  final List<T> _items = [];
  final int Function(T, T) compare;

  PriorityQueue(this.compare);

  bool get isNotEmpty => _items.isNotEmpty;

  void add(T item) {
    _items.add(item);
    _siftUp(_items.length - 1);
  }

  T removeFirst() {
    final T minimo = _items.first;
    final T ultimo = _items.removeLast();
    if (_items.isNotEmpty) {
      _items[0] = ultimo;
      _siftDown(0);
    }
    return minimo;
  }

  void _siftUp(int indice) {
    while (indice > 0) {
      final int padre = (indice - 1) ~/ 2;
      if (compare(_items[indice], _items[padre]) >= 0) break;
      _intercambiar(indice, padre);
      indice = padre;
    }
  }

  void _siftDown(int indice) {
    final int n = _items.length;
    while (true) {
      final int izquierdo = 2 * indice + 1;
      final int derecho = 2 * indice + 2;
      int menor = indice;
      if (izquierdo < n && compare(_items[izquierdo], _items[menor]) < 0) {
        menor = izquierdo;
      }
      if (derecho < n && compare(_items[derecho], _items[menor]) < 0) {
        menor = derecho;
      }
      if (menor == indice) break;
      _intercambiar(indice, menor);
      indice = menor;
    }
  }

  void _intercambiar(int i, int j) {
    final T temp = _items[i];
    _items[i] = _items[j];
    _items[j] = temp;
  }
}
