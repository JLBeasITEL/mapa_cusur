import '../models/grafo_campus.dart';

/// Un problema de integridad encontrado en el grafo, con suficiente detalle
/// para aparecer directamente en un reporte o en el mensaje de una prueba
/// fallida.
class ProblemaGrafo {
  final String descripcion;
  const ProblemaGrafo(this.descripcion);

  @override
  String toString() => descripcion;
}

/// Resultado de [validarGrafo]: un problema por categoría. Una lista vacía
/// significa que esa categoría no encontró nada.
class ResultadoValidacionGrafo {
  /// Aristas que referencian un ID de nodo (origen o destino) sin entrada
  /// en `nodos` -cubre a la vez "nodos sin coordenadas" e "IDs
  /// inexistentes": en este grafo ya interpolado ambos casos se manifiestan
  /// igual, como una arista que apunta a un ID que no existe como nodo.
  final List<ProblemaGrafo> idsInexistentes;

  /// Pares origen→destino sin su inversa, o cuya inversa tiene un peso
  /// distinto (más allá de una tolerancia de punto flotante).
  final List<ProblemaGrafo> aristasAsimetricas;

  /// Aristas con peso ≤ 0.
  final List<ProblemaGrafo> pesosNoPositivos;

  /// Aristas con peso `NaN` o infinito.
  final List<ProblemaGrafo> pesosNoFinitos;

  /// Aristas origen == destino.
  final List<ProblemaGrafo> autolazos;

  /// Si el grafo (tratado como no dirigido, para esta comprobación) tiene
  /// más de una componente conexa, una entrada por cada componente además
  /// de la principal, con su tamaño.
  final List<ProblemaGrafo> componentesDesconectadas;

  /// Grupos de dos o más nodos que comparten exactamente las mismas
  /// coordenadas en píxeles.
  final List<ProblemaGrafo> pixelesDuplicados;

  const ResultadoValidacionGrafo({
    required this.idsInexistentes,
    required this.aristasAsimetricas,
    required this.pesosNoPositivos,
    required this.pesosNoFinitos,
    required this.autolazos,
    required this.componentesDesconectadas,
    required this.pixelesDuplicados,
  });

  bool get esValido =>
      idsInexistentes.isEmpty &&
      aristasAsimetricas.isEmpty &&
      pesosNoPositivos.isEmpty &&
      pesosNoFinitos.isEmpty &&
      autolazos.isEmpty &&
      componentesDesconectadas.isEmpty &&
      pixelesDuplicados.isEmpty;

  int get totalProblemas =>
      idsInexistentes.length +
      aristasAsimetricas.length +
      pesosNoPositivos.length +
      pesosNoFinitos.length +
      autolazos.length +
      componentesDesconectadas.length +
      pixelesDuplicados.length;

  /// Reporte de una línea por problema, agrupado por categoría -pensado
  /// para el mensaje de una prueba fallida o para `REPORTE_DATOS.md`.
  String reporte() {
    final buffer = StringBuffer();
    void seccion(String titulo, List<ProblemaGrafo> problemas) {
      if (problemas.isEmpty) return;
      buffer.writeln('$titulo (${problemas.length}):');
      for (final p in problemas) {
        buffer.writeln('  - $p');
      }
    }

    seccion('IDs inexistentes', idsInexistentes);
    seccion('Aristas asimétricas', aristasAsimetricas);
    seccion('Pesos no positivos', pesosNoPositivos);
    seccion('Pesos no finitos', pesosNoFinitos);
    seccion('Autolazos', autolazos);
    seccion('Componentes desconectadas', componentesDesconectadas);
    seccion('Píxeles duplicados', pixelesDuplicados);

    return buffer.isEmpty ? 'Sin problemas de integridad.' : buffer.toString();
  }
}

/// Valida la integridad estructural de [grafo]: nodos sin coordenadas /
/// IDs inexistentes, aristas asimétricas, pesos no positivos o no finitos,
/// autolazos, componentes desconectadas y píxeles duplicados.
///
/// No corrige nada -solo reporta-: qué hacer con cada hallazgo es una
/// decisión humana (ver `REPORTE_DATOS.md`).
ResultadoValidacionGrafo validarGrafo(GrafoCampus grafo) {
  final idsInexistentes = <ProblemaGrafo>[];
  final aristasAsimetricas = <ProblemaGrafo>[];
  final pesosNoPositivos = <ProblemaGrafo>[];
  final pesosNoFinitos = <ProblemaGrafo>[];
  final autolazos = <ProblemaGrafo>[];

  final aristasVistas = <String>{};

  for (final origen in grafo.conexiones.keys) {
    final vecinos = grafo.conexiones[origen]!;
    for (final entry in vecinos.entries) {
      final String destino = entry.key;
      final double peso = entry.value;

      if (!grafo.nodos.containsKey(origen)) {
        idsInexistentes.add(ProblemaGrafo(
            '$origen no tiene coordenadas (aparece como origen en conexiones)'));
      }
      if (!grafo.nodos.containsKey(destino)) {
        idsInexistentes.add(ProblemaGrafo(
            '$destino no tiene coordenadas (referenciado desde $origen)'));
      }

      if (origen == destino) {
        autolazos.add(ProblemaGrafo('$origen→$origen (peso $peso)'));
      }

      if (peso.isNaN || peso.isInfinite) {
        pesosNoFinitos.add(ProblemaGrafo('$origen→$destino = $peso'));
      } else if (peso <= 0) {
        pesosNoPositivos.add(ProblemaGrafo('$origen→$destino = $peso'));
      }

      final String claveArista = '$origen→$destino';
      if (aristasVistas.add(claveArista)) {
        final double? pesoInverso = grafo.conexiones[destino]?[origen];
        if (origen != destino) {
          if (pesoInverso == null) {
            aristasAsimetricas.add(ProblemaGrafo(
                '$origen→$destino = $peso, pero $destino→$origen no existe'));
          } else if ((pesoInverso - peso).abs() > 1e-6) {
            aristasAsimetricas.add(ProblemaGrafo(
                '$origen→$destino = $peso, pero $destino→$origen = $pesoInverso'));
          }
        }
      }
    }
  }

  final componentesDesconectadas = _componentesDesconectadas(grafo);
  final pixelesDuplicados = _pixelesDuplicados(grafo);

  return ResultadoValidacionGrafo(
    idsInexistentes: idsInexistentes,
    aristasAsimetricas: aristasAsimetricas,
    pesosNoPositivos: pesosNoPositivos,
    pesosNoFinitos: pesosNoFinitos,
    autolazos: autolazos,
    componentesDesconectadas: componentesDesconectadas,
    pixelesDuplicados: pixelesDuplicados,
  );
}

List<ProblemaGrafo> _componentesDesconectadas(GrafoCampus grafo) {
  if (grafo.nodos.isEmpty) return const [];

  // Adyacencia no dirigida: una arista en cualquier sentido basta para
  // considerar dos nodos "en el mismo camino" a efectos de conectividad,
  // aunque el grafo real sea asimétrico.
  final adyacenciaNoDirigida = <String, Set<String>>{};
  void conectar(String a, String b) {
    (adyacenciaNoDirigida[a] ??= {}).add(b);
    (adyacenciaNoDirigida[b] ??= {}).add(a);
  }

  for (final origen in grafo.conexiones.keys) {
    adyacenciaNoDirigida.putIfAbsent(origen, () => {});
    for (final destino in grafo.conexiones[origen]!.keys) {
      conectar(origen, destino);
    }
  }
  for (final id in grafo.nodos.keys) {
    adyacenciaNoDirigida.putIfAbsent(id, () => {});
  }

  final visitados = <String>{};
  final componentes = <List<String>>[];

  for (final inicio in adyacenciaNoDirigida.keys) {
    if (visitados.contains(inicio)) continue;
    final componenteActual = <String>[];
    final pila = [inicio];
    visitados.add(inicio);
    while (pila.isNotEmpty) {
      final actual = pila.removeLast();
      componenteActual.add(actual);
      for (final vecino in adyacenciaNoDirigida[actual] ?? const {}) {
        if (visitados.add(vecino)) pila.add(vecino);
      }
    }
    componentes.add(componenteActual);
  }

  if (componentes.length <= 1) return const [];

  componentes.sort((a, b) => b.length.compareTo(a.length));
  return [
    for (int i = 1; i < componentes.length; i++)
      ProblemaGrafo('Componente aislada de ${componentes[i].length} nodo(s): '
          '${componentes[i].join(', ')}'),
  ];
}

List<ProblemaGrafo> _pixelesDuplicados(GrafoCampus grafo) {
  final porPixel = <String, List<String>>{};
  grafo.nodos.forEach((id, nodo) {
    final clave = '${nodo.pixelX},${nodo.pixelY}';
    (porPixel[clave] ??= []).add(id);
  });

  return [
    for (final grupo in porPixel.values)
      if (grupo.length > 1)
        ProblemaGrafo('${grupo.join(', ')} comparten el píxel '
            '(${grafo.nodos[grupo.first]!.pixelX}, '
            '${grafo.nodos[grupo.first]!.pixelY})'),
  ];
}
