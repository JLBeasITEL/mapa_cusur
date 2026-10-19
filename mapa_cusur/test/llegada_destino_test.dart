import 'package:flutter_test/flutter_test.dart';
import 'package:mapa_cusur/ui/navegacion/llegada_destino.dart';

void main() {
  group('llegoAlDestino', () {
    test('una ruta de un solo nodo cuenta como llegada, sin importar la distancia',
        () {
      expect(llegoAlDestino(nodosEnRuta: 1, distanciaMetros: 50), isTrue);
    });

    test('a menos del radio se considera que llegó', () {
      expect(llegoAlDestino(nodosEnRuta: 5, distanciaMetros: 4.2), isTrue);
    });

    test('exactamente en el radio se considera que llegó', () {
      expect(
          llegoAlDestino(
              nodosEnRuta: 5, distanciaMetros: kRadioLlegadaMetros),
          isTrue);
    });

    test('a más del radio todavía no llega', () {
      expect(
          llegoAlDestino(
              nodosEnRuta: 5, distanciaMetros: kRadioLlegadaMetros + 0.01),
          isFalse);
    });
  });
}
