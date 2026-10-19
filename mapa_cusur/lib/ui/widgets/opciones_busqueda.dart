import 'package:flutter/material.dart';

import '../../domain/buscador_ubicaciones.dart';
import '../../domain/historial_recientes.dart';
import '../theme/poppins.dart';

/// Altura máxima de la lista de opciones (la misma que usa `Autocomplete`
/// por defecto).
const double kAlturaMaximaOpciones = 200;

/// Texto de ayuda cuando no se encontró nada ni hay a quién sugerir.
const String kAyudaSinResultados =
    'Prueba con menos palabras o revisa cómo está escrito.';

/// Una opción de la lista de la barra de búsqueda.
sealed class OpcionBusqueda {
  const OpcionBusqueda();

  /// Las opciones que muestra la barra para [respuesta]: los lugares
  /// encontrados o, si no hay, una sola [OpcionSinResultados] (para que la
  /// lista se abra y diga que no hubo resultados). Si la consulta está
  /// vacía, una sola [OpcionRecientes] si [conRecientes], o ninguna.
  static List<OpcionBusqueda> de(RespuestaBusqueda respuesta,
      {bool conRecientes = false}) {
    if (respuesta.consultaVacia) {
      return conRecientes ? const [OpcionRecientes()] : const [];
    }
    if (respuesta.resultados.isEmpty) return [OpcionSinResultados(respuesta)];
    return [for (final r in respuesta.resultados) OpcionLugar(r)];
  }
}

/// Un lugar encontrado; elegirlo lo pone en el campo.
class OpcionLugar extends OpcionBusqueda {
  final ResultadoBusqueda resultado;
  const OpcionLugar(this.resultado);
}

/// "No encontramos «...»", con "¿Quisiste decir...?" si hay sugerencia. No
/// es un lugar: no se puede elegir.
class OpcionSinResultados extends OpcionBusqueda {
  final RespuestaBusqueda respuesta;
  const OpcionSinResultados(this.respuesta);
}

/// La sección "Recientes" (con la barra vacía). Es una sola opción que
/// muestra el historial en vivo: `Autocomplete` solo recalcula sus opciones
/// cuando cambia el texto, así que la lista de lugares no puede ser la de
/// sus opciones (quedaría vieja al borrar el historial o al elegir un
/// lugar en el otro campo). Sin recientes no muestra nada.
class OpcionRecientes extends OpcionBusqueda {
  const OpcionRecientes();
}

/// La lista de opciones de la barra de búsqueda: como la de `Autocomplete`
/// por defecto, más:
/// - "coincide con: ..." bajo el nombre si el lugar coincidió por un alias
///   y no por su nombre;
/// - el encabezado "Resultados aproximados" si lo son;
/// - el estado vacío, con la sugerencia ([onSugerencia]) si la hay;
/// - con la barra vacía, los lugares de [historial] (ver [OpcionRecientes]).
class OpcionesBusqueda extends StatelessWidget {
  final Iterable<OpcionBusqueda> opciones;
  final AutocompleteOnSelected<OpcionBusqueda> onSelected;

  /// Se llama con el nombre sugerido al tocar "¿Quisiste decir...?".
  final ValueChanged<String> onSugerencia;

  /// Para [OpcionRecientes]: el historial y el buscador que da el nombre
  /// oficial de cada ID.
  final HistorialRecientes? historial;
  final BuscadorUbicaciones? buscador;

  const OpcionesBusqueda({
    super.key,
    required this.opciones,
    required this.onSelected,
    required this.onSugerencia,
    this.historial,
    this.buscador,
  });

  @override
  Widget build(BuildContext context) {
    final lista = opciones.toList();
    final historial = this.historial;
    final buscador = this.buscador;
    if (lista case [OpcionRecientes()]) {
      if (historial == null || buscador == null) return const SizedBox.shrink();
      return _Recientes(
          historial: historial, buscador: buscador, onSelected: onSelected);
    }
    return Material(
      elevation: 4.0,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxHeight: kAlturaMaximaOpciones),
        child: switch (lista) {
          [OpcionSinResultados(:final respuesta)] =>
            _SinResultados(respuesta: respuesta, onSugerencia: onSugerencia),
          _ => _ListaDeLugares(
              lugares: [
                for (final o in lista)
                  if (o is OpcionLugar) o,
              ],
              onSelected: onSelected,
            ),
        },
      ),
    );
  }
}

class _ListaDeLugares extends StatelessWidget {
  final List<OpcionLugar> lugares;
  final AutocompleteOnSelected<OpcionBusqueda> onSelected;

  const _ListaDeLugares({required this.lugares, required this.onSelected});

  @override
  Widget build(BuildContext context) {
    final int resaltada = AutocompleteHighlightedOption.of(context);
    final aproximados = lugares.isNotEmpty &&
        lugares.first.resultado.nivel == NivelCoincidencia.aproximada;
    final encabezado = aproximados ? 1 : 0;

    return ListView.builder(
      padding: EdgeInsets.zero,
      shrinkWrap: true,
      itemCount: lugares.length + encabezado,
      itemBuilder: (context, i) {
        if (i < encabezado) {
          return Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: Text('Resultados aproximados',
                style: poppins(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF64748B))),
          );
        }
        final indice = i - encabezado;
        return _Lugar(
          resultado: lugares[indice].resultado,
          resaltada: indice == resaltada,
          onTap: () => onSelected(lugares[indice]),
        );
      },
    );
  }
}

class _Lugar extends StatelessWidget {
  final ResultadoBusqueda resultado;
  final bool resaltada;
  final VoidCallback onTap;

  const _Lugar({
    required this.resultado,
    required this.resaltada,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final alias = resultado.aliasCoincidente;
    return Semantics(
      button: true,
      child: InkWell(
        onTap: onTap,
        child: Container(
          color: resaltada ? Theme.of(context).focusColor : null,
          padding: EdgeInsets.symmetric(
              horizontal: 16, vertical: alias == null ? 16 : 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(resultado.nombre),
              if (alias != null)
                Text('coincide con: $alias',
                    style: poppins(
                        fontSize: 12, color: const Color(0xFF64748B))),
            ],
          ),
        ),
      ),
    );
  }
}

class _SinResultados extends StatelessWidget {
  final RespuestaBusqueda respuesta;
  final ValueChanged<String> onSugerencia;

  const _SinResultados({required this.respuesta, required this.onSugerencia});

  @override
  Widget build(BuildContext context) {
    final sugerencia = respuesta.sugerencia;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('No encontramos «${respuesta.consulta}»',
              style: poppins(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF1E293B))),
          const SizedBox(height: 6),
          if (sugerencia != null)
            Semantics(
              button: true,
              child: InkWell(
                onTap: () => onSugerencia(sugerencia.nombre),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Text.rich(TextSpan(
                    style: poppins(
                        fontSize: 14, color: const Color(0xFF1E293B)),
                    children: [
                      const TextSpan(text: '¿Quisiste decir '),
                      TextSpan(
                          text: sugerencia.nombre,
                          style: poppins(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: const Color(0xFF3B82F6))),
                      const TextSpan(text: '?'),
                    ],
                  )),
                ),
              ),
            )
          else
            Text(kAyudaSinResultados,
                style:
                    poppins(fontSize: 13, color: const Color(0xFF64748B))),
        ],
      ),
    );
  }
}

class _Recientes extends StatelessWidget {
  final HistorialRecientes historial;
  final BuscadorUbicaciones buscador;
  final AutocompleteOnSelected<OpcionBusqueda> onSelected;

  const _Recientes({
    required this.historial,
    required this.buscador,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: historial,
      builder: (context, _) {
        // Un ID que ya no es un lugar buscable se salta en silencio.
        final lugares = [
          for (final id in historial.ids) ?buscador.ubicacion(id),
        ];
        if (lugares.isEmpty) return const SizedBox.shrink();

        return Material(
          elevation: 4.0,
          child: ConstrainedBox(
            constraints:
                const BoxConstraints(maxHeight: kAlturaMaximaOpciones),
            child: ListView(
              padding: EdgeInsets.zero,
              shrinkWrap: true,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 4, 0),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text('Recientes',
                            style: poppins(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: const Color(0xFF64748B))),
                      ),
                      TextButton(
                        onPressed: historial.borrar,
                        child: Text('Borrar historial',
                            style: poppins(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: const Color(0xFF3B82F6))),
                      ),
                    ],
                  ),
                ),
                for (final u in lugares)
                  Semantics(
                    button: true,
                    child: InkWell(
                      // Elegir un reciente es elegir de la lista: lo pone en
                      // el campo y lo vuelve el más reciente.
                      onTap: () => onSelected(OpcionLugar(ResultadoBusqueda(
                          id: u.id,
                          nombre: u.nombre,
                          nivel: NivelCoincidencia.exacta))),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 14),
                        child: Row(
                          children: [
                            const Icon(Icons.history,
                                size: 18, color: Color(0xFF94A3B8)),
                            const SizedBox(width: 12),
                            Expanded(child: Text(u.nombre)),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}
