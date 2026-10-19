import 'dart:convert';

/// Hash estable FNV-1a de 64 bits sobre la secuencia completa de nodos de
/// una ruta. No es criptográfico: solo sirve para detectar, en las pruebas
/// de regresión, si la secuencia de nodos de una ruta cambió entre
/// corridas. Compartido entre tool/generar_linea_base.dart y
/// test/regresion_rutas_test.dart para que generación y verificación nunca
/// diverjan.
String hashRuta(List<String> ruta) {
  const int fnvOffset = 0xcbf29ce484222325;
  const int fnvPrime = 0x100000001b3;
  int hash = fnvOffset;
  final bytes = utf8.encode(ruta.join(','));
  for (final b in bytes) {
    hash ^= b;
    hash = (hash * fnvPrime) & 0xFFFFFFFFFFFFFFFF;
  }
  return hash.toUnsigned(64).toRadixString(16).padLeft(16, '0');
}
