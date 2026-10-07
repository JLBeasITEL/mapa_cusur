import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../data/diccionario_nombres.dart';
import '../../domain/transformacion_geo.dart';
import '../../domain/ubicacion_en_ruta.dart';
import '../../models/grafo_campus.dart';
import '../painters/route_painter.dart';
import '../theme/poppins.dart';

class MapImageArea extends StatefulWidget {
  final List<String> ruta;
  final GrafoCampus? grafo;

  /// Modelo de transformación geo→píxel activo (Fase 4: dos puntos o
  /// afín, según `--dart-define=TRANSFORMACION`). `null` mientras los
  /// datos del campus aún no terminan de cargar.
  final TransformacionGeoPixel? transformacion;

  final ui.Image? markerImage;
  final void Function(String nombreAmigable, bool esOrigen) onNodoSeleccionado;

  /// Ubicación del usuario ya filtrada, suavizada y proyectada
  /// ortogonalmente sobre la arista más cercana (Fase 3). `null` si no hay
  /// rastreo de GPS activo o aún no llega una lectura aceptable.
  final UbicacionEnGrafo? ubicacionGPS;
  final int disparadorZoom;

  /// Cada vez que aumenta, la cámara deja de seguir al usuario y regresa
  /// a la vista inicial del mapa completo ("Limpiar" y "Detener ruta").
  final int disparadorReinicioCamara;

  /// Si no es `null`, el menú de nodo (Fase 5, modo punto de verificación)
  /// ofrece un tercer botón "Registrar punto de verificación aquí" que
  /// invoca esto con el ID interno del nodo tocado.
  final void Function(String nodoId)? onVerificarAqui;

  const MapImageArea({
    super.key,
    required this.ruta,
    required this.grafo,
    required this.transformacion,
    required this.markerImage,
    required this.onNodoSeleccionado,
    required this.ubicacionGPS,
    required this.disparadorZoom,
    required this.disparadorReinicioCamara,
    this.onVerificarAqui,
  });

  @override
  State<MapImageArea> createState() => _MapImageAreaState();
}

class _MapImageAreaState extends State<MapImageArea>
    with SingleTickerProviderStateMixin {
  final TransformationController _transformationController =
      TransformationController();
  late AnimationController _animationController;
  Animation<Matrix4>? _animationReset;

  // ValueNotifier en vez de un campo + setState: antes, cada frame del
  // gesto de zoom reconstruía el widget MapImageArea entero (la imagen del
  // mapa, el GestureDetector, etc.), cuando lo único que en verdad depende
  // del zoom es el CustomPaint del RoutePainter. Con el
  // ValueListenableBuilder de más abajo, solo ese subárbol se reconstruye
  // en cada frame.
  final ValueNotifier<double> _zoomNotifier = ValueNotifier(1.0);
  final GlobalKey _stackKey = GlobalKey();

  bool _isCameraLocked = false;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(vsync: this)
      ..addListener(() {
        if (_animationReset != null) {
          _transformationController.value = _animationReset!.value;
        }
      });
    _transformationController.addListener(() {
      _zoomNotifier.value = _transformationController.value.getMaxScaleOnAxis();
    });
  }

  void _moverCamara(int duracionMillis) {
    final grafo = widget.grafo;
    final ubicacion = widget.ubicacionGPS;
    final transformacion = widget.transformacion;
    if (ubicacion == null ||
        grafo == null ||
        grafo.nodos.isEmpty ||
        transformacion == null) {
      return;
    }

    final RenderBox? stackBox =
        _stackKey.currentContext?.findRenderObject() as RenderBox?;
    if (stackBox == null) return;

    final Size imgSize = stackBox.size;
    final Size screen = context.size ?? const Size(400, 400);

    final posicionCanvas =
        geoACanvas(transformacion, lat: ubicacion.lat, lng: ubicacion.lng);

    // --- CÁLCULO DE CENTRADO DE CÁMARA ---
    double scale = screen.width / imgSize.width;
    if (imgSize.height * scale > screen.height) scale = screen.height / imgSize.height;

    final double renderWidth = imgSize.width * scale;
    final double renderHeight = imgSize.height * scale;

    final double offsetX = (screen.width - renderWidth) / 2;
    final double offsetY = (screen.height - renderHeight) / 2;

    final double targetScreenX = offsetX + (posicionCanvas.x * scale);
    final double targetScreenY = offsetY + (posicionCanvas.y * scale);

    const double zoomNivel = 3.0;
    final double dx = (screen.width / 2) - (targetScreenX * zoomNivel);
    final double dy = (screen.height / 2) - (targetScreenY * zoomNivel);

    final Matrix4 endMatrix = Matrix4.identity()
      ..translateByDouble(dx, dy, 0, 1)
      ..scaleByDouble(zoomNivel, zoomNivel, zoomNivel, 1);

    _animationController.duration = Duration(milliseconds: duracionMillis);
    final Curve curvaDeVuelo =
        duracionMillis > 500 ? Curves.fastOutSlowIn : Curves.linear;

    _animationReset = Matrix4Tween(
      begin: _transformationController.value,
      end: endMatrix,
    ).animate(CurvedAnimation(parent: _animationController, curve: curvaDeVuelo));

    _animationController.forward(from: 0);
  }

  void _reiniciarCamara() {
    _animationController.duration = const Duration(milliseconds: 600);
    _animationReset = Matrix4Tween(
      begin: _transformationController.value,
      end: Matrix4.identity(),
    ).animate(CurvedAnimation(
        parent: _animationController, curve: Curves.fastOutSlowIn));

    _animationController.forward(from: 0);
  }

  @override
  void didUpdateWidget(MapImageArea oldWidget) {
    super.didUpdateWidget(oldWidget);
    // El reinicio va primero: si en el mismo frame también aumentó
    // disparadorZoom, gana el reinicio.
    if (widget.disparadorReinicioCamara > oldWidget.disparadorReinicioCamara) {
      _isCameraLocked = false;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _reiniciarCamara();
      });
    } else if (widget.disparadorZoom > oldWidget.disparadorZoom) {
      _isCameraLocked = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _moverCamara(1000);
      });
    } else if (widget.ubicacionGPS != oldWidget.ubicacionGPS &&
        _isCameraLocked) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _moverCamara(300);
      });
    }
  }

  @override
  void dispose() {
    _transformationController.dispose();
    _animationController.dispose();
    _zoomNotifier.dispose();
    super.dispose();
  }

  void _manejarToqueEnMapa(BuildContext context, Offset toque) {
    final grafo = widget.grafo;
    if (grafo == null) return;

    String? nodoMasCercano;
    double distanciaMinima = double.infinity;

    for (final entry in grafo.nodos.entries) {
      if (!diccionarioNombres.containsKey(entry.key)) continue;
      final p = pixelesACanvas(entry.value.pixelX, entry.value.pixelY);
      final double distancia = (Offset(p.x, p.y) - toque).distance;
      if (distancia < distanciaMinima) {
        distanciaMinima = distancia;
        nodoMasCercano = entry.key;
      }
    }
    if (nodoMasCercano != null) _mostrarMenuDeNodo(context, nodoMasCercano);
  }

  void _mostrarMenuDeNodo(BuildContext context, String nodoID) {
    final String nombreAmigable = diccionarioNombres[nodoID] ?? nodoID;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(25))),
      builder: (ctx) {
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 30.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text("📍 $nombreAmigable",
                  style: poppins(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87),
                  textAlign: TextAlign.center),
              const SizedBox(height: 8),
              Text("¿Qué deseas hacer con este punto?",
                  style: poppins(fontSize: 14, color: Colors.grey[600])),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green[50],
                          foregroundColor: Colors.green[700],
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12))),
                      icon: const Icon(Icons.my_location),
                      label: Text('Definir Origen',
                          style: poppins(fontWeight: FontWeight.bold)),
                      onPressed: () {
                        Navigator.pop(ctx);
                        widget.onNodoSeleccionado(nombreAmigable, true);
                      },
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red[50],
                          foregroundColor: Colors.red[700],
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12))),
                      icon: const Icon(Icons.location_on),
                      label: Text('Definir Destino',
                          style: poppins(fontWeight: FontWeight.bold)),
                      onPressed: () {
                        Navigator.pop(ctx);
                        widget.onNodoSeleccionado(nombreAmigable, false);
                      },
                    ),
                  ),
                ],
              ),
              if (widget.onVerificarAqui != null) ...[
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue[50],
                        foregroundColor: Colors.blue[700],
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12))),
                    icon: const Icon(Icons.rule),
                    label: Text('Registrar punto de verificación aquí',
                        style: poppins(fontWeight: FontWeight.bold)),
                    onPressed: () {
                      Navigator.pop(ctx);
                      widget.onVerificarAqui!(nodoID);
                    },
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final grafo = widget.grafo;
    return Container(
      color: Colors.white,
      child: InteractiveViewer(
        transformationController: _transformationController,
        minScale: 1.0,
        maxScale: 8.0,
        onInteractionStart: (details) {
          setState(() {
            _isCameraLocked = false;
          });
        },
        child: FittedBox(
          fit: BoxFit.contain,
          child: GestureDetector(
            onTapUp: (details) => _manejarToqueEnMapa(context, details.localPosition),
            child: Stack(
              key: _stackKey,
              children: [
                Image.asset('assets/mapa_CUSur.png'),
                // La ruta resaltada, los pines y el marcador de GPS -lo que
                // cambia con cada actualización de posición-. El trazado
                // estático del grafo (aristas y nodos azules) no se dibuja:
                // solo debe verse la ruta calculada.
                if (grafo != null && grafo.nodos.isNotEmpty)
                  Positioned.fill(
                    child: ValueListenableBuilder<double>(
                      valueListenable: _zoomNotifier,
                      builder: (context, zoom, _) => CustomPaint(
                        painter: RoutePainter(
                          ruta: widget.ruta,
                          grafo: grafo,
                          transformacion: widget.transformacion,
                          markerImage: widget.markerImage,
                          zoomScale: zoom,
                          ubicacionGPS: widget.ubicacionGPS,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
