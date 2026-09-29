import 'package:flutter/material.dart';

import '../../instrumentacion/sesion_campo.dart';
import '../../utils/cronometro.dart';

/// Panel de depuración de la Fase 5: muestra el resumen del [Cronometro]
/// (parseo del JSON, interpolación, cada ejecución de Dijkstra) y los
/// controles para iniciar/detener una sesión de registro de campo y para
/// activar el modo punto de verificación. Solo se monta cuando el modo de
/// instrumentación está activo -ver `kModoInstrumentacion` en
/// `campus_map_screen.dart`-, así que no aparece en una build de release
/// normal.
class PanelInstrumentacion extends StatelessWidget {
  final Cronometro cronometro;
  final SesionCampo? sesionActiva;
  final String? rutaArchivoActivo;
  final bool modoVerificacion;
  final VoidCallback onIniciarSesion;
  final VoidCallback onDetenerSesion;
  final ValueChanged<bool> onCambiarModoVerificacion;

  const PanelInstrumentacion({
    super.key,
    required this.cronometro,
    required this.sesionActiva,
    required this.rutaArchivoActivo,
    required this.modoVerificacion,
    required this.onIniciarSesion,
    required this.onDetenerSesion,
    required this.onCambiarModoVerificacion,
  });

  static Future<void> mostrar(BuildContext context, PanelInstrumentacion panel) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => panel,
    );
  }

  String _ms(double micros) => (micros / 1000).toStringAsFixed(2);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Instrumentación de campo', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 16),
          Text('Cronómetro', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 4),
          if (cronometro.etiquetas.isEmpty)
            const Text('Sin mediciones todavía.')
          else
            for (final etiqueta in cronometro.etiquetas)
              Builder(builder: (_) {
                final r = cronometro.resumenDe(etiqueta);
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Text(
                      '$etiqueta — n=${r.n}, prom=${_ms(r.promedioMicros)} ms, '
                      'mín=${_ms(r.minMicros.toDouble())} ms, '
                      'máx=${_ms(r.maxMicros.toDouble())} ms'),
                );
              }),
          const Divider(height: 32),
          Text('Registro de recorrido', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          if (sesionActiva == null)
            ElevatedButton.icon(
              onPressed: onIniciarSesion,
              icon: const Icon(Icons.fiber_manual_record),
              label: const Text('Iniciar sesión de registro'),
            )
          else ...[
            Text('Activa: ${sesionActiva!.dispositivo} · ${sesionActiva!.recorridoId}'),
            if (rutaArchivoActivo != null)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: SelectableText(rutaArchivoActivo!,
                    style: const TextStyle(fontSize: 11, color: Colors.grey)),
              ),
            const SizedBox(height: 8),
            ElevatedButton.icon(
              onPressed: onDetenerSesion,
              icon: const Icon(Icons.stop),
              label: const Text('Detener sesión'),
            ),
          ],
          const SizedBox(height: 8),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Modo punto de verificación'),
            subtitle: const Text(
                'Al tocar un nodo en el mapa, registra el error de ambos '
                'modelos de transformación con la lectura de GPS actual.'),
            value: modoVerificacion,
            onChanged: onCambiarModoVerificacion,
          ),
        ],
      ),
    );
  }
}
