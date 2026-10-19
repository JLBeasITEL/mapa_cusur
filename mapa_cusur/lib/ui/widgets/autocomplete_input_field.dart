import 'package:flutter/material.dart';

import '../../data/ubicaciones_buscables.dart';
import '../../domain/buscador_ubicaciones.dart';
import '../../domain/historial_recientes.dart';
import '../theme/poppins.dart';
import 'opciones_busqueda.dart';

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

  /// Los últimos lugares elegidos de la lista (compartido entre origen y
  /// destino). Con el campo vacío y enfocado se muestran como "Recientes".
  /// Si es `null`, no hay recientes.
  final HistorialRecientes? historial;

  const AutocompleteInputField({
    super.key,
    required this.iconColor,
    required this.title,
    required this.placeholder,
    required this.suggestions,
    required this.onSelected,
    this.initialValue = "",
    this.buscador,
    this.historial,
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

  /// El controller del campo que crea `Autocomplete` (se recibe en su
  /// fieldViewBuilder).
  TextEditingController? _controlador;

  /// "¿Quisiste decir [nombre]?": la consulta se reemplaza por [nombre], lo
  /// que vuelve a buscar y muestra sus resultados. Se avisa con onSelected
  /// igual que si se hubiera escrito (el campo siempre le avisa su texto a
  /// la pantalla, ver onChanged); no es elegir un lugar de la lista.
  void _usarSugerencia(String nombre) {
    _controlador?.value = TextEditingValue(
        text: nombre, selection: TextSelection.collapsed(offset: nombre.length));
    widget.onSelected(nombre);
  }

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
        Autocomplete<OpcionBusqueda>(
          initialValue: TextEditingValue(text: widget.initialValue),
          // La comparación y el orden viven en BuscadorUbicaciones: sin
          // importar acentos, mayúsculas ni orden de las palabras, también
          // por alias (p. ej. "Gimnasio") y, si no hay nada, tolerando
          // errores de dedo. La opción siempre muestra el nombre amigable.
          optionsBuilder: (val) => OpcionBusqueda.de(
              _buscador.consultar(val.text),
              conRecientes: widget.historial != null),
          displayStringForOption: (o) => switch (o) {
            OpcionLugar(:final resultado) => resultado.nombre,
            OpcionSinResultados(:final respuesta) => respuesta.consulta,
            OpcionRecientes() => '',
          },
          // Solo lo elegido de la lista cuenta como reciente; lo escrito a
          // mano llega a la pantalla por onChanged y no se guarda.
          onSelected: (o) {
            if (o is! OpcionLugar) return;
            widget.historial?.agregar(o.resultado.id);
            widget.onSelected(o.resultado.nombre);
          },
          optionsViewBuilder: (ctx, onSelected, opciones) => OpcionesBusqueda(
            opciones: opciones,
            onSelected: onSelected,
            onSugerencia: _usarSugerencia,
            historial: widget.historial,
            buscador: _buscador,
          ),
          // Se escucha el controller para que el botón de borrar aparezca o
          // desaparezca mientras el usuario escribe.
          fieldViewBuilder: (ctx, ctrl, node, fn) =>
              ValueListenableBuilder<TextEditingValue>(
            // Se guarda el controller para poder usar una sugerencia.
            valueListenable: _controlador = ctrl,
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
