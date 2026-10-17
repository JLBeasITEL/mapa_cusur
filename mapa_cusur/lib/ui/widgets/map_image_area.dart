import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../data/diccionario_nombres.dart';
import '../../domain/proyeccion_local.dart';
import '../../domain/transformacion_geo.dart';
import '../../domain/ubicacion_en_ruta.dart';
import '../../models/grafo_campus.dart';
import '../../models/mapa_vectorial.dart';
import '../mapa/colores_mapa_vectorial.dart';
import '../mapa/lienzo_mapa.dart';
import '../painters/etiquetas_mapa_painter.dart';
import '../painters/mapa_vectorial_painter.dart';
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

  /// Modo del mapa; por omisión, el de la app ([kModoMapa]).
  final ModoMapa modo;

  /// Datos del mapa vectorial (solo en [ModoMapa.vectorial]). `null`
  /// mientras `campus_vector.json` aún no termina de cargar: mientras
  /// tanto no se dibuja nada, porque sin `meta` no hay lienzo.
  final MapaVectorial? mapaVectorial;

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
    this.modo = kModoMapa,
    this.mapaVectorial,
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

  /// El lienzo activo: el de la imagen (que siempre existe, aunque sin
  /// transformación no pueda ubicar el GPS) o el vectorial (que no existe
  /// hasta que llega `mapaVectorial`).
  LienzoMapa? get _lienzo {
    switch (widget.modo) {
      case ModoMapa.imagen:
        return LienzoImagen(widget.transformacion);
      case ModoMapa.vectorial:
        return _capas?.lienzo;
    }
  }

  /// Lo que el modo vectorial construye una sola vez por cada
  /// `mapaVectorial` (no en cada build ni en cada frame de zoom).
  _CapasVectoriales? _capas;

  void _actualizarCapasVectoriales() {
    final mapa =
        widget.modo == ModoMapa.vectorial ? widget.mapaVectorial : null;
    if (identical(_capas?.mapa, mapa)) return;
    _capas?.etiquetas.dispose();
    _capas = mapa == null ? null : _CapasVectoriales(mapa);
  }

  @override
  void initState() {
    super.initState();
    _actualizarCapasVectoriales();
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
    final lienzo = _lienzo;
    if (ubicacion == null ||
        grafo == null ||
        grafo.nodos.isEmpty ||
        lienzo == null) {
      return;
    }

    // En modo imagen es null sin modelo de transformación (igual que
    // antes); en modo vectorial siempre hay posición.
    final Offset? posicionCanvas =
        lienzo.geoALienzo(ubicacion.lat, ubicacion.lng);
    if (posicionCanvas == null) return;

    final RenderBox? stackBox =
        _stackKey.currentContext?.findRenderObject() as RenderBox?;
    if (stackBox == null) return;

    final Size imgSize = stackBox.size;
    final Size screen = context.size ?? const Size(400, 400);

    // --- CÁLCULO DE CENTRADO DE CÁMARA ---
    double scale = screen.width / imgSize.width;
    if (imgSize.height * scale > screen.height) scale = screen.height / imgSize.height;

    final double renderWidth = imgSize.width * scale;
    final double renderHeight = imgSize.height * scale;

    final double offsetX = (screen.width - renderWidth) / 2;
    final double offsetY = (screen.height - renderHeight) / 2;

    final double targetScreenX = offsetX + (posicionCanvas.dx * scale);
    final double targetScreenY = offsetY + (posicionCanvas.dy * scale);

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
    _actualizarCapasVectoriales();
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
    _capas?.etiquetas.dispose();
    super.dispose();
  }

  void _manejarToqueEnMapa(BuildContext context, Offset toque) {
    final grafo = widget.grafo;
    final lienzo = _lienzo;
    if (grafo == null || lienzo == null) return;

    String? nodoMasCercano;
    double distanciaMinima = double.infinity;

    for (final entry in grafo.nodos.entries) {
      if (!diccionarioNombres.containsKey(entry.key)) continue;
      final double distancia =
          (lienzo.nodoALienzo(entry.value) - toque).distance;
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

  /// El fondo del lienzo, que además le da su tamaño al `Stack`.
  Widget _fondo(LienzoMapa lienzo) {
    final capas = _capas;
    if (widget.modo == ModoMapa.imagen || capas == null) {
      return Image.asset('assets/mapa_CUSur.png');
    }
    // La capa estática no depende del zoom: en su propio RepaintBoundary,
    // no se vuelve a pintar al hacer zoom ni con cada lectura de GPS.
    return SizedBox.fromSize(
      size: lienzo.tamano,
      child: RepaintBoundary(
        child: CustomPaint(
          painter: MapaVectorialPainter(
            geometria: capas.geometria,
            escala: capas.lienzo.proyeccion.escala,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.modo == ModoMapa.imagen) {
      return Container(
        color: Colors.white,
        child: _visor(context, ajuste: 0),
      );
    }

    final capas = _capas;
    return Container(
      color: ColoresMapaVectorial.fondo,
      child: LayoutBuilder(
        builder: (context, restricciones) {
          // Escala del FittedBox (BoxFit.contain): píxeles de pantalla por
          // unidad de lienzo con zoom 1. La capa de etiquetas la necesita
          // para que sus textos tengan tamaño constante en pantalla.
          final double ajuste = capas == null
              ? 0
              : math.min(
                  restricciones.maxWidth / capas.lienzo.tamano.width,
                  restricciones.maxHeight / capas.lienzo.tamano.height);
          return Stack(
            fit: StackFit.expand,
            children: [
              _visor(context, ajuste: ajuste.isFinite ? ajuste : 0),
              // Atribución obligatoria de la ODbL, fuera del
              // InteractiveViewer para que no se mueva con el mapa.
              if (capas != null)
                Positioned(
                  right: 6,
                  bottom: 6,
                  child: IgnorePointer(
                    child: _Atribucion(capas.mapa.meta.atribucion),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  /// [ajuste]: escala del FittedBox (solo la usa la capa de etiquetas del
  /// modo vectorial).
  Widget _visor(BuildContext context, {required double ajuste}) {
    final lienzo = _lienzo;
    return InteractiveViewer(
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
        // Solo es null en modo vectorial, mientras carga
        // campus_vector.json.
        child: lienzo == null
            ? const SizedBox.shrink()
            : _contenido(context, lienzo, ajuste),
      ),
    );
  }

  Widget _contenido(BuildContext context, LienzoMapa lienzo, double ajuste) {
    final grafo = widget.grafo;
    final capas = _capas;
    return GestureDetector(
      onTapUp: (details) => _manejarToqueEnMapa(context, details.localPosition),
      child: Stack(
        key: _stackKey,
        children: [
          _fondo(lienzo),
          // Insignias y textos del mapa vectorial: se repintan con el zoom
          // para mantener su tamaño en pantalla.
          if (capas != null)
            Positioned.fill(
              child: ValueListenableBuilder<double>(
                valueListenable: _zoomNotifier,
                builder: (context, zoom, _) => CustomPaint(
                  painter: EtiquetasMapaPainter(
                    etiquetas: capas.etiquetas,
                    proyeccion: capas.lienzo.proyeccion,
                    pantallaPorLienzo: ajuste * zoom,
                    zoom: zoom,
                  ),
                ),
              ),
            ),
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
                    lienzo: lienzo,
                    markerImage: widget.markerImage,
                    zoomScale: zoom,
                    ubicacionGPS: widget.ubicacionGPS,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Lo que el modo vectorial construye una sola vez por cada
/// [MapaVectorial]: el lienzo, los `Path` de la capa estática y las
/// etiquetas ya maquetadas.
class _CapasVectoriales {
  final MapaVectorial mapa;
  final LienzoVectorial lienzo;
  final GeometriaMapaVectorial geometria;
  final EtiquetasMapaVectorial etiquetas;

  _CapasVectoriales(this.mapa)
      : lienzo = LienzoVectorial(ProyeccionLocal(mapa.meta)),
        geometria = GeometriaMapaVectorial(mapa),
        etiquetas = EtiquetasMapaVectorial(mapa);
}

/// "© colaboradores de OpenStreetMap" (`meta.atribucion`), que la ODbL
/// exige mostrar junto a los datos.
class _Atribucion extends StatelessWidget {
  final String texto;

  const _Atribucion(this.texto);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.75),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        texto,
        style: poppins(fontSize: 11, color: ColoresMapaVectorial.tenue),
      ),
    );
  }
}
