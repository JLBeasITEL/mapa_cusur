import 'package:flutter/material.dart';

/// Factor de escala a partir del cual se considera que el mapa tiene zoom.
/// Un poco arriba de 1 para que los errores de punto flotante al volver a
/// la vista inicial no hagan parpadear el botón.
const double kUmbralEscalaConZoom = 1.02;

/// Duración de la aparición y desaparición del botón.
const Duration kDuracionBotonResetZoom = Duration(milliseconds: 200);

/// Regresa el mapa a su vista inicial. Mismo estilo que el botón de capas
/// (blanco, esquinas redondeadas, sombra suave e ícono azul). Aparece y
/// desaparece con fade + scale según [visible].
class BotonResetZoom extends StatelessWidget {
  final bool visible;
  final VoidCallback onPressed;

  const BotonResetZoom(
      {super.key, required this.visible, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: kDuracionBotonResetZoom,
      switchInCurve: Curves.easeOut,
      switchOutCurve: Curves.easeIn,
      transitionBuilder: (child, animacion) => FadeTransition(
        opacity: animacion,
        child: ScaleTransition(scale: animacion, child: child),
      ),
      child: visible
          ? _Boton(key: const ValueKey(true), onPressed: onPressed)
          : const SizedBox.shrink(key: ValueKey(false)),
    );
  }
}

class _Boton extends StatelessWidget {
  final VoidCallback onPressed;

  const _Boton({super.key, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    const String texto = 'Restablecer vista';
    return Semantics(
      button: true,
      label: texto,
      child: Tooltip(
        message: texto,
        excludeFromSemantics: true,
        child: Material(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          elevation: 3,
          shadowColor: Colors.black26,
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: onPressed,
            child: const SizedBox(
              width: 40,
              height: 40,
              child: Icon(Icons.zoom_out,
                  size: 22, color: Color(0xFF3B82F6)),
            ),
          ),
        ),
      ),
    );
  }
}
