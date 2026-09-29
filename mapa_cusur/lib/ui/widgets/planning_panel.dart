import 'package:flutter/material.dart';

import '../theme/poppins.dart';
import 'autocomplete_input_field.dart';

class PlanningPanel extends StatelessWidget {
  final List<String> ubicaciones;
  final VoidCallback onCalcular;
  final VoidCallback onGpsPressed;
  final bool isTracking;
  final String tiempoEstimado;
  final String origenValue;
  final String destinoValue;
  final int mapTapKey;
  final Function(String) onOrigenChanged;
  final Function(String) onDestinoChanged;

  const PlanningPanel({
    super.key,
    required this.ubicaciones,
    required this.onCalcular,
    required this.onGpsPressed,
    required this.isTracking,
    required this.tiempoEstimado,
    required this.origenValue,
    required this.destinoValue,
    required this.mapTapKey,
    required this.onOrigenChanged,
    required this.onDestinoChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(40), topRight: Radius.circular(40)),
        boxShadow: [
          BoxShadow(
              color: const Color(0xFF3B82F6).withValues(alpha: 0.08),
              blurRadius: 20,
              spreadRadius: 5,
              offset: const Offset(0, -5))
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
      child: SingleChildScrollView(
        child: Column(
          children: [
            // --- RAYITA SUPERIOR ---
            Container(
                width: 50,
                height: 5,
                margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(10))),

            Align(
                alignment: Alignment.centerLeft,
                child: Text('Tu Ruta',
                    style: poppins(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF1E293B)))),
            const SizedBox(height: 16),

            // --- NUEVO DISEÑO: FILA DE ORIGEN + BOTÓN GPS COMPACTO ---
            Row(
              crossAxisAlignment: CrossAxisAlignment
                  .end, // Alineamos por debajo para que el botón coincida con el cuadro de texto
              children: [
                Expanded(
                  child: !isTracking
                      ? AutocompleteInputField(
                          key: ValueKey('origen_$mapTapKey'),
                          iconColor: const Color(0xFF10B981),
                          title: 'Punto de partida',
                          placeholder: '¿Dónde estás?',
                          initialValue: origenValue,
                          suggestions: ubicaciones,
                          onSelected: onOrigenChanged)
                      : Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Padding(
                                padding:
                                    const EdgeInsets.only(left: 4, bottom: 6),
                                child: Text('Punto de partida',
                                    style: poppins(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: const Color(0xFF64748B)))),
                            Container(
                              height: 54, // Misma altura que el cuadro de texto
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 16),
                              decoration: BoxDecoration(
                                color: const Color(0xFFEFF6FF),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                    color: const Color(0xFFBFDBFE), width: 1),
                              ),
                              child: Row(
                                children: [
                                  const Icon(Icons.my_location,
                                      color: Color(0xFF3B82F6), size: 20),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      'Tu ubicación actual',
                                      style: poppins(
                                          color: const Color(0xFF1E3A8A),
                                          fontWeight: FontWeight.w600,
                                          fontSize: 14),
                                      overflow: TextOverflow
                                          .ellipsis, // Por si la pantalla es muy pequeña
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                ),
                const SizedBox(width: 12),

                // --- BOTÓN GPS REDUCIDO Y CUADRADO ---
                Material(
                  color: isTracking
                      ? const Color(0xFFFEF2F2)
                      : const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(16),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(16),
                    onTap: onGpsPressed,
                    child: Container(
                      height: 54,
                      width: 54,
                      alignment: Alignment.center,
                      child: Icon(
                          isTracking ? Icons.gps_fixed : Icons.my_location,
                          size: 24,
                          color: isTracking
                              ? const Color(0xFFEF4444)
                              : const Color(0xFF3B82F6)),
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),

            // --- CAMPO DE DESTINO ---
            AutocompleteInputField(
                key: ValueKey('destino_$mapTapKey'),
                iconColor: const Color(0xFFEF4444),
                title: 'Destino',
                placeholder: '¿A dónde vas?',
                initialValue: destinoValue,
                suggestions: ubicaciones,
                onSelected: onDestinoChanged),

            const SizedBox(height: 24), // Damos un poco más de espacio aquí

            // --- TIEMPO ESTIMADO ---
            if (tiempoEstimado.isNotEmpty)
              Container(
                margin: const EdgeInsets.only(bottom: 16),
                padding:
                    const EdgeInsets.symmetric(vertical: 12, horizontal: 20),
                decoration: BoxDecoration(
                    color: const Color(0xFFFFF7ED),
                    borderRadius: BorderRadius.circular(16),
                    border:
                        Border.all(color: const Color(0xFFFFEDD5), width: 1)),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.directions_walk,
                        color: Color(0xFFF97316), size: 20),
                    const SizedBox(width: 10),
                    Text('Llegarás en $tiempoEstimado',
                        style: poppins(
                            color: const Color(0xFFC2410C),
                            fontWeight: FontWeight.w600,
                            fontSize: 15)),
                  ],
                ),
              ),

            // --- BOTÓN PRINCIPAL ---
            Container(
              decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                        color: const Color(0xFF3B82F6).withValues(alpha: 0.3),
                        blurRadius: 15,
                        offset: const Offset(0, 8))
                  ]),
              child: ElevatedButton(
                onPressed: onCalcular,
                style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF3B82F6),
                    minimumSize: const Size(double.infinity, 56),
                    shape:
                        RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    elevation: 0),
                child: Text('Comenzar Ruta',
                    style: poppins(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5)),
              ),
            ),
            const SizedBox(height: 10),
          ],
        ),
      ),
    );
  }
}
