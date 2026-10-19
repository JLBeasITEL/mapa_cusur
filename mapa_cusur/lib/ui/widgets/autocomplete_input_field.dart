import 'package:flutter/material.dart';

import '../../data/ubicaciones_buscables.dart';
import '../../domain/buscador_ubicaciones.dart';
import '../theme/poppins.dart';

class AutocompleteInputField extends StatefulWidget {
  final Color iconColor;
  final String title;
  final String placeholder;
  final List<String> suggestions;
  final Function(String) onSelected;
  final String initialValue;

  /// El buscador ya armado (con sus nombres normalizados una sola vez al
  /// cargar los datos). Si es `null`, se arma uno con [suggestions].
  final BuscadorUbicaciones? buscador;

  const AutocompleteInputField({
    super.key,
    required this.iconColor,
    required this.title,
    required this.placeholder,
    required this.suggestions,
    required this.onSelected,
    this.initialValue = "",
    this.buscador,
  });

  @override
  State<AutocompleteInputField> createState() => _AutocompleteInputFieldState();
}

class _AutocompleteInputFieldState extends State<AutocompleteInputField> {
  late BuscadorUbicaciones _buscador;

  @override
  void initState() {
    super.initState();
    _buscador = _armarBuscador();
  }

  @override
  void didUpdateWidget(AutocompleteInputField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.buscador != oldWidget.buscador ||
        widget.suggestions != oldWidget.suggestions) {
      _buscador = _armarBuscador();
    }
  }

  BuscadorUbicaciones _armarBuscador() =>
      widget.buscador ??
      BuscadorUbicaciones(ubicacionesDesdeNombres(widget.suggestions));

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 6),
          child: Text(
            widget.title,
            style: poppins(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF64748B)),
          ),
        ),
        Autocomplete<ResultadoBusqueda>(
          initialValue: TextEditingValue(text: widget.initialValue),
          // La comparación y el orden viven en BuscadorUbicaciones: sin
          // importar acentos, mayúsculas ni orden de las palabras, y también
          // por nombres alternativos (p. ej. "Gimnasio"). La opción siempre
          // muestra el nombre amigable.
          optionsBuilder: (val) => _buscador.buscar(val.text),
          displayStringForOption: (r) => r.nombre,
          onSelected: (r) => widget.onSelected(r.nombre),
          // Se escucha el controller para que el botón de borrar aparezca o
          // desaparezca mientras el usuario escribe.
          fieldViewBuilder: (ctx, ctrl, node, fn) =>
              ValueListenableBuilder<TextEditingValue>(
            valueListenable: ctrl,
            builder: (ctx, valor, _) => TextField(
              controller: ctrl,
              focusNode: node,
              onChanged: widget.onSelected,
              style: poppins(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  color: const Color(0xFF1E293B)),
              decoration: InputDecoration(
                prefixIcon: Padding(
                  padding: const EdgeInsets.all(14.0),
                  child: Container(
                    decoration: BoxDecoration(
                        color: widget.iconColor.withValues(alpha: 0.2),
                        shape: BoxShape.circle),
                    padding: const EdgeInsets.all(4),
                    child: Icon(Icons.circle, color: widget.iconColor, size: 10),
                  ),
                ),
                suffixIcon: valor.text.isEmpty
                    ? null
                    : IconButton(
                        tooltip: 'Borrar',
                        icon: const Icon(Icons.cancel,
                            color: Color(0xFF94A3B8), size: 20),
                        onPressed: () {
                          // Vaciar el texto deja sin opciones al
                          // optionsBuilder, y quitar el foco cierra la lista.
                          ctrl.clear();
                          widget.onSelected("");
                          node.unfocus();
                        },
                      ),
                hintText: widget.placeholder,
                hintStyle: poppins(color: const Color(0xFF94A3B8)),
                filled: true,
                fillColor: const Color(0xFFF8FAFC),
                contentPadding: const EdgeInsets.symmetric(vertical: 16),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide(color: Colors.grey.shade200)),
                enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide(color: Colors.grey.shade200)),
                focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide:
                        const BorderSide(color: Color(0xFF3B82F6), width: 1.5)),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
