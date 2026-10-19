import 'dart:math' as math;
import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';

/// Alto de la franja que queda visible con el panel minimizado: el handle
/// y un poco de aire alrededor, lo justo para volver a abrirlo.
const double kAlturaPanelColapsado = 36;

/// Duración de la animación al soltar el panel o tocar el handle.
const Duration kDuracionAnimacionPanel = Duration(milliseconds: 280);

/// Velocidad (px/s) a partir de la cual un swipe decide solo hacia dónde va
/// el panel, sin importar dónde se suelte.
const double kVelocidadMinimaSwipe = 700;

/// Alto de la zona del handle: el mismo espacio que ocupaba la rayita
/// cuando era parte del contenido (16 de margen + 5 + 20 debajo).
const double _kAltoZonaAsa = 41;

/// El panel inferior blanco con su handle, que se minimiza deslizándolo
/// hacia abajo (o tocando el handle) y deja todo el espacio a [cuerpo].
///
/// [cuerpo] (el mapa) ocupa siempre lo que el panel deja libre: crece y se
/// encoge con él, no queda solo tapado. El gesto vive únicamente en la
/// franja del handle, así que no compite con el pan/zoom del mapa ni con el
/// scroll interno de [panel].
class PanelColapsable extends StatefulWidget {
  /// Lo que va arriba del panel (el mapa).
  final Widget cuerpo;

  /// El contenido del panel, debajo del handle. Ocupa el alto restante del
  /// panel expandido; si no cabe, debe hacer su propio scroll.
  final Widget panel;

  /// Alto del panel abierto, incluido el handle.
  final double alturaExpandida;

  /// Alto de la franja visible con el panel minimizado.
  final double alturaColapsada;

  /// Alto total del área sin contar el teclado. Con él, [cuerpo] no se
  /// encoge al abrir el teclado: el panel lo tapa, igual que antes. Si es
  /// `null`, se usa el alto que da el padre.
  final double? alturaDisponible;

  const PanelColapsable({
    super.key,
    required this.cuerpo,
    required this.panel,
    required this.alturaExpandida,
    this.alturaColapsada = kAlturaPanelColapsado,
    this.alturaDisponible,
  });

  @override
  State<PanelColapsable> createState() => _PanelColapsableState();
}

class _PanelColapsableState extends State<PanelColapsable>
    with SingleTickerProviderStateMixin {
  /// 0: minimizado; 1: expandido. Arranca expandido.
  late final AnimationController _controlador =
      AnimationController(vsync: this, value: 1);

  /// Estado al que va (o en el que está) el panel. Solo decide la etiqueta
  /// de accesibilidad del handle.
  bool _expandido = true;

  double get _recorrido =>
      math.max(0, widget.alturaExpandida - widget.alturaColapsada);

  @override
  void dispose() {
    _controlador.dispose();
    super.dispose();
  }

  void _animarA({required bool expandir}) {
    // Al minimizar se cierra el teclado: el campo con foco quedaría oculto.
    if (!expandir) FocusScope.of(context).unfocus();
    if (_expandido != expandir) setState(() => _expandido = expandir);
    _controlador.animateTo(expandir ? 1 : 0,
        duration: kDuracionAnimacionPanel, curve: Curves.easeOut);
  }

  void _alArrastrar(DragUpdateDetails detalles) {
    if (_recorrido <= 0) return;
    // Hacia abajo (delta positivo) se cierra.
    _controlador.value -= detalles.primaryDelta! / _recorrido;
  }

  void _alSoltar(DragEndDetails detalles) {
    final double velocidad = detalles.primaryVelocity ?? 0;
    final bool expandir = velocidad.abs() > kVelocidadMinimaSwipe
        ? velocidad < 0
        : _controlador.value >= 0.5;
    _animarA(expandir: expandir);
  }

  @override
  Widget build(BuildContext context) {
    final Widget panel = _PanelDecorado(
      asa: _ZonaAsa(
        expandido: _expandido,
        onTap: () => _animarA(expandir: !_expandido),
        onVerticalDragUpdate: _alArrastrar,
        onVerticalDragEnd: _alSoltar,
      ),
      child: widget.panel,
    );

    return LayoutBuilder(
      builder: (context, restricciones) {
        final double alturaTotal =
            widget.alturaDisponible ?? restricciones.maxHeight;
        return AnimatedBuilder(
          animation: _controlador,
          child: panel,
          builder: (context, panel) {
            final double visible = lerpDouble(widget.alturaColapsada,
                widget.alturaExpandida, _controlador.value)!;
            return Stack(
              children: [
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  height: math.max(0, alturaTotal - visible),
                  child: widget.cuerpo,
                ),
                // El panel siempre se maqueta a su alto completo y solo se
                // desliza hacia abajo: su contenido no se reacomoda (ni se
                // desborda) en cada frame de la animación.
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: visible - widget.alturaExpandida,
                  height: widget.alturaExpandida,
                  child: panel!,
                ),
              ],
            );
          },
        );
      },
    );
  }
}

/// El fondo blanco del panel (bordes redondeados y sombra azul suave) con
/// el handle arriba y el contenido debajo.
class _PanelDecorado extends StatelessWidget {
  final Widget asa;
  final Widget child;

  const _PanelDecorado({required this.asa, required this.child});

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
      child: Column(
        children: [
          asa,
          Expanded(child: child),
        ],
      ),
    );
  }
}

/// La rayita gris y la franja a todo lo ancho que recibe el gesto.
class _ZonaAsa extends StatelessWidget {
  final bool expandido;
  final VoidCallback onTap;
  final GestureDragUpdateCallback onVerticalDragUpdate;
  final GestureDragEndCallback onVerticalDragEnd;

  const _ZonaAsa({
    required this.expandido,
    required this.onTap,
    required this.onVerticalDragUpdate,
    required this.onVerticalDragEnd,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: expandido ? 'Minimizar panel' : 'Mostrar panel',
      onTap: onTap,
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        onVerticalDragUpdate: onVerticalDragUpdate,
        onVerticalDragEnd: onVerticalDragEnd,
        child: SizedBox(
          height: _kAltoZonaAsa,
          width: double.infinity,
          child: Align(
            alignment: Alignment.topCenter,
            child: Container(
                width: 50,
                height: 5,
                margin: const EdgeInsets.only(top: 16),
                decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(10))),
          ),
        ),
      ),
    );
  }
}
