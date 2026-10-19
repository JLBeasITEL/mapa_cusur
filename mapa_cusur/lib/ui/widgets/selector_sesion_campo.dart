import 'package:flutter/material.dart';

import '../../instrumentacion/sesion_campo.dart';

/// Diálogo para confirmar el dispositivo (fijado al compilar, no se elige
/// aquí) y elegir el recorrido y el número de repetición antes de iniciar
/// una sesión de registro de campo (Fase 5, ítem 2). Devuelve `null` si el
/// usuario cancela.
class SelectorSesionCampoDialog extends StatefulWidget {
  const SelectorSesionCampoDialog({super.key});

  static Future<SesionCampo?> mostrar(BuildContext context) {
    return showDialog<SesionCampo>(
      context: context,
      builder: (_) => const SelectorSesionCampoDialog(),
    );
  }

  @override
  State<SelectorSesionCampoDialog> createState() =>
      _SelectorSesionCampoDialogState();
}

class _SelectorSesionCampoDialogState extends State<SelectorSesionCampoDialog> {
  int _recorrido = kRecorridosDisponibles.first;
  final TextEditingController _repeticionCtrl =
      TextEditingController(text: '1');

  @override
  void dispose() {
    _repeticionCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Nueva sesión de registro de campo'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // El dispositivo NO se elige aquí: viene fijado al compilar con
          // --dart-define=DISPOSITIVO=... Se muestra en modo lectura para
          // poder confirmar de un vistazo que el teléfono correcto tiene
          // la build correcta antes de salir a caminar.
          InputDecorator(
            decoration: const InputDecoration(
                labelText: 'Dispositivo (fijado al compilar)'),
            child: Text(
              dispositivoDeCompilacion,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<int>(
            initialValue: _recorrido,
            decoration: const InputDecoration(labelText: 'Recorrido'),
            items: [
              for (final r in kRecorridosDisponibles)
                DropdownMenuItem(value: r, child: Text('Recorrido $r')),
            ],
            onChanged: (v) => setState(() => _recorrido = v!),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _repeticionCtrl,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'Número de repetición'),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: () {
            final int repeticion = int.tryParse(_repeticionCtrl.text) ?? 1;
            Navigator.of(context).pop(SesionCampo(
              dispositivo: dispositivoDeCompilacion,
              recorrido: _recorrido,
              repeticion: repeticion,
            ));
          },
          child: const Text('Iniciar'),
        ),
      ],
    );
  }
}
