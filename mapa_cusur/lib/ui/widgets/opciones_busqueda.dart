import 'package:flutter/material.dart';

import '../../domain/buscador_ubicaciones.dart';
import '../theme/poppins.dart';

/// Altura máxima de la lista de opciones (la misma que usa `Autocomplete`
/// por defecto).
const double kAlturaMaximaOpciones = 200;

/// La lista de opciones de la barra de búsqueda: como la de `Autocomplete`
/// por defecto, pero si un lugar coincidió por un alias y no por su nombre,
/// lo dice debajo del nombre ("coincide con: ...").
class OpcionesBusqueda extends StatelessWidget {
  final Iterable<ResultadoBusqueda> opciones;
  final AutocompleteOnSelected<ResultadoBusqueda> onSelected;

  const OpcionesBusqueda({
    super.key,
    required this.opciones,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    final int resaltada = AutocompleteHighlightedOption.of(context);
    final lista = opciones.toList();

    return Material(
      elevation: 4.0,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxHeight: kAlturaMaximaOpciones),
        child: ListView.builder(
          padding: EdgeInsets.zero,
          shrinkWrap: true,
          itemCount: lista.length,
          itemBuilder: (context, i) => _Opcion(
            resultado: lista[i],
            resaltada: i == resaltada,
            onTap: () => onSelected(lista[i]),
          ),
        ),
      ),
    );
  }
}

class _Opcion extends StatelessWidget {
  final ResultadoBusqueda resultado;
  final bool resaltada;
  final VoidCallback onTap;

  const _Opcion({
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
