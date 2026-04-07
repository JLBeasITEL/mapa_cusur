import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:convert';
import 'package:flutter/services.dart';
import 'dart:ui' as ui;
import 'package:geolocator/geolocator.dart';
import 'dart:async'; 

void main() {
  runApp(const CampusNavigationApp());
}

class CampusNavigationApp extends StatelessWidget {
  const CampusNavigationApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'CUSur Campus Nav',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF3B82F6)),
        useMaterial3: true,
        textTheme: GoogleFonts.poppinsTextTheme(),
      ),
      home: const CampusMapScreen(),
    );
  }
}

class CampusMapScreen extends StatefulWidget {
  const CampusMapScreen({super.key});

  @override
  State<CampusMapScreen> createState() => _CampusMapScreenState();
}

class _CampusMapScreenState extends State<CampusMapScreen> {
  Map<String, dynamic>? datosDelCampus;
  List<String> ubicacionesDisponibles = [];
  List<String> rutaCalculada = [];
  String tiempoEstimado = "";
  ui.Image? markerImage; 

  String origenSeleccionado = "";
  String destinoSeleccionado = "";
  int mapTapKey = 0; 

  StreamSubscription<Position>? _gpsStream;
  Position? _posicionEnTiempoReal;
  bool _rastreandoGPS = false;
  
  int disparadorZoom = 0; // Disparador manual de cámara

  final Map<String, String> diccionarioNombres = {
    'EntradaA': 'Entrada Principal (A)', 'EntradaB': 'Entrada Peatonal (B)', 'EntradaC': 'Entrada Estacionamiento (C)', 'Estacionamiento1': 'Estacionamiento 1', 'Estacionamiento2': 'Estacionamiento 2', 'Estacionamiento3': 'Estacionamiento 3', 'Estacionamiento4': 'Estacionamiento 4', 'Estacionamiento5': 'Estacionamiento 5', 'Edificio_B': 'Edificio B', 'Edificio_C': 'Edificio C', 'Edificio_F': 'Edificio F', 'Edificio_G': 'Edificio G', 'Edificio_H': 'Edificio H', 'Edificio_I': 'Edificio I', 'Edificio_J': 'Edificio J', 'Edificio_L': 'Edificio L', 'Edificio_M': 'Edificio M', 'Edificio_N': 'Edificio N', 'Edificio_P': 'Edificio P', 'Edificio_Q': 'Edificio Q', 'Edificio_R': 'Edificio R', 'Edificio_S': 'Edificio S', 'Edificio_T': 'Edificio T', 'Edificio_U': 'Edificio U', 'Edificio_V': 'Edificio V', 'Edificio_W': 'Edificio W', 'Edificio_X': 'Edificio X', 'Edificio_Y': 'Edificio Y', 'Edificio_Z': 'Edificio Z', 'C_Acuatico': 'Centro Acuático', 'Gimnasio': 'Gimnasio Auditorio', 'CASA': 'C.A.S.A. (Biblioteca)', 'Cafeteria': 'Cafetería Principal', 'Cafeteria_P': 'Cafetería Pequeña', 'Rectoria': 'Rectoría', 'Veterinaria': 'Hospital Veterinario', 'Clinica_Escuela': 'Clínica Escuela', 'Bufete_Juridico': 'Bufete Jurídico', 'Auditorio_Ochoa': 'Auditorio Hugo Gutiérrez Ochoa', 'Auditorio_Zinser': 'Auditorio Adolfo Aguilar Zínser', 'Auditorio_CASA': 'Auditorio C.A.S.A.', 'Sala_de_Gobierno': 'Sala de Gobierno', 'CMID': 'C.M.I.D. (Discapacidad)', 'RadioUDG': 'Radio UDG', 'Proteccion_Civil': 'Protección Civil',
  };

  @override
  void initState() {
    super.initState();
    _cargarDatosDelMapa();
    _loadMarkerImage();
  }

  @override
  void dispose() {
    _gpsStream?.cancel(); 
    super.dispose();
  }

  Future<void> _loadMarkerImage() async {
    const String imagePath = 'assets/pin_marker.png';
    try {
      final ByteData data = await rootBundle.load(imagePath);
      final Uint8List bytes = data.buffer.asUint8List();
      final ui.Codec codec = await ui.instantiateImageCodec(bytes);
      final ui.FrameInfo fi = await codec.getNextFrame();
      setState(() { markerImage = fi.image; });
    } catch (e) { print("Error cargando pin: $e"); }
  }

  Future<void> _cargarDatosDelMapa() async {
    try {
      final String respuesta = await rootBundle.loadString('assets/campus_data.json');
      final data = json.decode(respuesta);
      final Map<String, dynamic> coordenadasGeo = data['coordenadas_geo'];
      final List<String> filtrados = coordenadasGeo.keys.where((id) => diccionarioNombres.containsKey(id)).map((id) => diccionarioNombres[id]!).toList();
      filtrados.sort();
      setState(() { datosDelCampus = data; ubicacionesDisponibles = filtrados; });
    } catch (e) { print("Error cargando datos: $e"); }
  }

  String _encontrarNodoMasCercanoAlGps(double userLat, double userLng) {
    if (datosDelCampus == null) return "";
    Map<String, dynamic> nodosGeo = datosDelCampus!['coordenadas_geo'];
    String idGanador = "";
    double distanciaMinima = double.infinity;
    nodosGeo.forEach((id, coords) {
      double latNodo = coords[0], lngNodo = coords[1];
      double distancia = Geolocator.distanceBetween(userLat, userLng, latNodo, lngNodo);
      if (distancia < distanciaMinima) { distanciaMinima = distancia; idGanador = id; }
    });
    return idGanador;
  }

  void _toggleRastreoGPS() async {
    if (_rastreandoGPS) {
      _gpsStream?.cancel();
      setState(() { _rastreandoGPS = false; _posicionEnTiempoReal = null; });
      return;
    }
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Activa el GPS.'))); return; }
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) return;
    }
    _gpsStream = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(accuracy: LocationAccuracy.bestForNavigation, distanceFilter: 1)
    ).listen((Position position) {
      setState(() {
        _posicionEnTiempoReal = position;
        if (destinoSeleccionado.isNotEmpty) calcularRuta();
      });
    });
    setState(() { _rastreandoGPS = true; });
  }

  void calcularRuta() {
    String obtenerId(String texto) {
      for (var entry in diccionarioNombres.entries) { if (entry.value == texto) return entry.key; }
      return texto; 
    }
    String idInicio = "";
    
    if (_rastreandoGPS && _posicionEnTiempoReal != null) {
      idInicio = _encontrarNodoMasCercanoAlGps(_posicionEnTiempoReal!.latitude, _posicionEnTiempoReal!.longitude);
      origenSeleccionado = diccionarioNombres[idInicio] ?? idInicio; 
      // NOTA: Aquí quitamos el disparadorZoom++. Solo se activa al presionar el botón.
    } else {
      idInicio = obtenerId(origenSeleccionado);
    }

    String idDestino = obtenerId(destinoSeleccionado);
    if (datosDelCampus == null || idInicio.isEmpty || idDestino.isEmpty) return;
    Map<String, dynamic> graph = datosDelCampus!['conexiones'];
    if (!graph.containsKey(idInicio) || !graph.containsKey(idDestino)) return;

    var distancias = <String, double>{};
    var padres = <String, String?>{};
    var pq = PriorityQueue<MapEntry<String, double>>((a, b) => a.value.compareTo(b.value));

    for (var nodo in graph.keys) { distancias[nodo] = double.infinity; padres[nodo] = null; }
    distancias[idInicio] = 0; pq.add(MapEntry(idInicio, 0));

    while (pq.isNotEmpty) {
      var actual = pq.removeFirst().key;
      if (actual == idDestino) break;
      Map<String, dynamic> vecinos = graph[actual] ?? {};
      vecinos.forEach((vecino, peso) {
        double nuevaDist = distancias[actual]! + (peso as num).toDouble();
        if (nuevaDist < distancias[vecino]!) {
          distancias[vecino] = nuevaDist; padres[vecino] = actual; pq.add(MapEntry(vecino, nuevaDist));
        }
      });
    }
    List<String> ruta = []; String? temp = idDestino;
    while (temp != null) { ruta.insert(0, temp); temp = padres[temp]; }
    double tiempoFinal = distancias[idDestino] ?? 0.0;
    
    setState(() {
      rutaCalculada = distancias[idDestino] == double.infinity ? [] : ruta;
      tiempoEstimado = (tiempoFinal != double.infinity && tiempoFinal > 0) ? "${tiempoFinal.toStringAsFixed(1)} minutos" : ""; 
    });
  }

  void _seleccionarDesdeMapa(String nombreAmigable, bool esOrigen) {
    setState(() {
      if (esOrigen) {
        if (_rastreandoGPS) _toggleRastreoGPS();
        origenSeleccionado = nombreAmigable;
      } else { destinoSeleccionado = nombreAmigable; }
      mapTapKey++; 
      if (origenSeleccionado.isNotEmpty && destinoSeleccionado.isNotEmpty) calcularRuta();
      else { rutaCalculada = []; tiempoEstimado = ""; }
    });
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      body: SafeArea(
        child: Stack(
          children: [
            Positioned(
              top: 0, left: 0, right: 0, height: screenHeight * 0.55, 
              child: MapImageArea(
                ruta: rutaCalculada, pixeles: datosDelCampus?['coordenadas_pix'] ?? {},
                conexiones: datosDelCampus?['conexiones'] ?? {}, coordenadasGeo: datosDelCampus?['coordenadas_geo'] ?? {}, 
                markerImage: markerImage, onNodoSeleccionado: _seleccionarDesdeMapa, 
                diccionarioNombres: diccionarioNombres, posicionRealGPS: _posicionEnTiempoReal, disparadorZoom: disparadorZoom, 
              ),
            ),
            Positioned(
              bottom: 0, left: 0, right: 0, height: screenHeight * 0.4, 
              child: PlanningPanel(
                ubicaciones: ubicacionesDisponibles,
                onCalcular: () {
                  // AQUÍ DISPARAMOS EL ZOOM MANUALMENTE
                  setState(() { disparadorZoom++; });
                  calcularRuta();
                },
                onGpsPressed: _toggleRastreoGPS, isTracking: _rastreandoGPS, 
                tiempoEstimado: tiempoEstimado, origenValue: origenSeleccionado, 
                destinoValue: destinoSeleccionado, mapTapKey: mapTapKey,
                onOrigenChanged: (val) { setState(() { origenSeleccionado = val; rutaCalculada = []; tiempoEstimado = ""; }); },
                onDestinoChanged: (val) { setState(() { destinoSeleccionado = val; rutaCalculada = []; tiempoEstimado = ""; }); },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class MapImageArea extends StatefulWidget {
  final List<String> ruta;
  final Map<String, dynamic> pixeles;
  final Map<String, dynamic> conexiones;
  final Map<String, dynamic> coordenadasGeo; 
  final ui.Image? markerImage; 
  final Function(String, bool) onNodoSeleccionado;
  final Map<String, String> diccionarioNombres; 
  final Position? posicionRealGPS; 
  final int disparadorZoom;

  const MapImageArea({super.key, required this.ruta, required this.pixeles, required this.conexiones, required this.coordenadasGeo, required this.markerImage, required this.onNodoSeleccionado, required this.diccionarioNombres, required this.posicionRealGPS, required this.disparadorZoom});

  @override
  State<MapImageArea> createState() => _MapImageAreaState();
}

class _MapImageAreaState extends State<MapImageArea> with SingleTickerProviderStateMixin {
  final TransformationController _transformationController = TransformationController();
  late AnimationController _animationController;
  Animation<Matrix4>? _animationReset;
  double _zoomActual = 1.0;
  final GlobalKey _stackKey = GlobalKey();
  
  bool _isCameraLocked = false; 

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(vsync: this)..addListener(() {
      if (_animationReset != null) _transformationController.value = _animationReset!.value;
    });
    _transformationController.addListener(() {
      setState(() { _zoomActual = _transformationController.value.getMaxScaleOnAxis(); });
    });
  }

  void _moverCamara(int duracionMillis) {
    if (widget.posicionRealGPS == null || widget.coordenadasGeo.isEmpty) return;

    final RenderBox? stackBox = _stackKey.currentContext?.findRenderObject() as RenderBox?;
    if (stackBox == null) return;
    
    final Size imgSize = stackBox.size; 
    final Size screen = context.size ?? const Size(400, 400);

    // --- CEREBRO MATEMÁTICO SINCRONIZADO ---
    double userLat = widget.posicionRealGPS!.latitude;
    double userLng = widget.posicionRealGPS!.longitude;
    
    double lat1 = widget.coordenadasGeo['EntradaA'][0]; double lng1 = widget.coordenadasGeo['EntradaA'][1];
    double p1x = widget.pixeles['EntradaA'][0].toDouble(); double p1y = widget.pixeles['EntradaA'][1].toDouble();
    
    double lat2 = widget.coordenadasGeo['Edificio_M'][0]; double lng2 = widget.coordenadasGeo['Edificio_M'][1];
    double p2x = widget.pixeles['Edificio_M'][0].toDouble(); double p2y = widget.pixeles['Edificio_M'][1].toDouble();

    double deltaLat = (lat2 - lat1).abs();
    double deltaPxX = (p2x - p1x).abs();
    double deltaPxY = (p2y - p1y).abs();
    
    // Auto-detectamos la rotación real de tu imagen
    bool latControlaX = (deltaPxX / deltaLat) > (deltaPxY / deltaLat);

    double newPxX = 0; double newPxY = 0;

    if (latControlaX) {
      double pctLat = (userLat - lat1) / (lat2 - lat1);
      double pctLng = (userLng - lng1) / (lng2 - lng1);
      newPxX = p1x + (pctLat * (p2x - p1x));
      newPxY = p1y + (pctLng * (p2y - p1y));
    } else {
      double pctLng = (userLng - lng1) / (lng2 - lng1);
      double pctLat = (userLat - lat1) / (lat2 - lat1);
      newPxX = p1x + (pctLng * (p2x - p1x));
      newPxY = p1y + (pctLat * (p2y - p1y));
    }

    // Aplicamos la escala 6.0 y el intercambio (Y es X, X es Y)
    double finalX = newPxY * 6.0; 
    double finalY = newPxX * 6.0;

    // --- CÁLCULO DE CENTRADO DE CÁMARA ---
    double scale = screen.width / imgSize.width;
    if (imgSize.height * scale > screen.height) scale = screen.height / imgSize.height;
    
    double renderWidth = imgSize.width * scale;
    double renderHeight = imgSize.height * scale;
    
    double offsetX = (screen.width - renderWidth) / 2;
    double offsetY = (screen.height - renderHeight) / 2;

    double targetScreenX = offsetX + (finalX * scale);
    double targetScreenY = offsetY + (finalY * scale);

    final double zoomNivel = 3.0;
    double dx = (screen.width / 2) - (targetScreenX * zoomNivel);
    double dy = (screen.height / 2) - (targetScreenY * zoomNivel);

    final Matrix4 endMatrix = Matrix4.identity()
      ..translate(dx, dy)
      ..scale(zoomNivel);

    _animationController.duration = Duration(milliseconds: duracionMillis);
    Curve curvaDeVuelo = duracionMillis > 500 ? Curves.fastOutSlowIn : Curves.linear;

    _animationReset = Matrix4Tween(
      begin: _transformationController.value,
      end: endMatrix,
    ).animate(CurvedAnimation(parent: _animationController, curve: curvaDeVuelo));

    _animationController.forward(from: 0);
  }

  @override
  void didUpdateWidget(MapImageArea oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.disparadorZoom > oldWidget.disparadorZoom) {
      _isCameraLocked = true; 
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _moverCamara(1000); 
      });
    } else if (widget.posicionRealGPS != oldWidget.posicionRealGPS && _isCameraLocked) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _moverCamara(300); 
      });
    }
  }

  @override
  void dispose() {
    _transformationController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  void _manejarToqueEnMapa(BuildContext context, Offset toque) {
    final double factorEscala = 6.0; 
    final double desplazamientoX = 0.0; 
    final double desplazamientoY = 0.0;  

    Offset transformarPunto(List<dynamic> p) {
      double originalX = p[0].toDouble(); double originalY = p[1].toDouble();
      return Offset((originalY * factorEscala) + desplazamientoX, (originalX * factorEscala) + desplazamientoY);
    }

    String? nodoMasCercano;
    double distanciaMinima = double.infinity; 

    for (var nodo in widget.pixeles.keys) {
      if (!widget.diccionarioNombres.containsKey(nodo)) continue; 
      Offset posNodo = transformarPunto(widget.pixeles[nodo]);
      double distancia = (posNodo - toque).distance;
      if (distancia < distanciaMinima) { distanciaMinima = distancia; nodoMasCercano = nodo; }
    }
    if (nodoMasCercano != null) _mostrarMenuDeNodo(context, nodoMasCercano);
  }

  void _mostrarMenuDeNodo(BuildContext context, String nodoID) {
    String nombreAmigable = widget.diccionarioNombres[nodoID] ?? nodoID;
    showModalBottomSheet(
      context: context, backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(25))),
      builder: (ctx) {
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 30.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text("📍 $nombreAmigable", style: GoogleFonts.poppins(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.black87), textAlign: TextAlign.center),
              const SizedBox(height: 8),
              Text("¿Qué deseas hacer con este punto?", style: GoogleFonts.poppins(fontSize: 14, color: Colors.grey[600])),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.green[50], foregroundColor: Colors.green[700], elevation: 0, padding: const EdgeInsets.symmetric(vertical: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                      icon: const Icon(Icons.my_location), label: Text('Definir Origen', style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
                      onPressed: () { Navigator.pop(ctx); widget.onNodoSeleccionado(nombreAmigable, true); },
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.red[50], foregroundColor: Colors.red[700], elevation: 0, padding: const EdgeInsets.symmetric(vertical: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                      icon: const Icon(Icons.location_on), label: Text('Definir Destino', style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
                      onPressed: () { Navigator.pop(ctx); widget.onNodoSeleccionado(nombreAmigable, false); },
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      child: InteractiveViewer(
        transformationController: _transformationController, 
        minScale: 1.0, maxScale: 8.0,
        onInteractionStart: (details) {
          setState(() { _isCameraLocked = false; });
        },
        child: FittedBox(
          fit: BoxFit.contain,
          child: GestureDetector(
            onTapUp: (details) => _manejarToqueEnMapa(context, details.localPosition),
            child: Stack(
              key: _stackKey, 
              children: [
                Image.asset('assets/mapa_CUSur.png'),
                if (widget.pixeles.isNotEmpty)
                  Positioned.fill(
                    child: CustomPaint(
                      painter: RoutePainter(
                        ruta: widget.ruta, pixeles: widget.pixeles, conexiones: widget.conexiones, 
                        coordenadasGeo: widget.coordenadasGeo, markerImage: widget.markerImage,
                        zoomScale: _zoomActual, posicionRealGPS: widget.posicionRealGPS, diccionarioNombres: widget.diccionarioNombres,
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

class RoutePainter extends CustomPainter {
  final List<String> ruta;
  final Map<String, dynamic> pixeles;
  final Map<String, dynamic> conexiones;
  final Map<String, dynamic> coordenadasGeo;
  final ui.Image? markerImage; 
  final double zoomScale; 
  final Position? posicionRealGPS; 
  final Map<String, String> diccionarioNombres;

  RoutePainter({required this.ruta, required this.pixeles, required this.conexiones, required this.coordenadasGeo, required this.markerImage, required this.zoomScale, required this.posicionRealGPS, required this.diccionarioNombres});

  @override
  void paint(Canvas canvas, Size size) {
    final double factorEscala = 6.0; 
    final double desplazamientoX = 0.0; 
    final double desplazamientoY = 0.0;  

    Offset transformarPunto(List<dynamic> p) {
      double originalX = p[0].toDouble(); double originalY = p[1].toDouble();
      return Offset((originalY * factorEscala) + desplazamientoX, (originalX * factorEscala) + desplazamientoY);
    }

    final paintGrafo = Paint()..color = Colors.blueAccent.withOpacity(0.4)..strokeWidth = 4.0 / zoomScale..style = PaintingStyle.stroke;
    final paintNodo = Paint()..color = Colors.blueAccent.withOpacity(0.6)..style = PaintingStyle.fill;
    final paintRuta = Paint()..color = Colors.red..strokeWidth = 36.0..strokeCap = StrokeCap.round..strokeJoin = StrokeJoin.round..style = PaintingStyle.stroke;

    void dibujarPinConEtiquetaTexto(String texto, Offset posicion, Color colorFondo) {
      final double imgSize = 180.0; 
      final double subirPin = 140.0; 

      if (markerImage != null) {
        canvas.save(); canvas.translate(posicion.dx, posicion.dy); 
        final dstRect = Rect.fromLTWH(-imgSize / 2, -subirPin, imgSize, imgSize);
        final srcRect = Rect.fromLTWH(0, 0, markerImage!.width.toDouble(), markerImage!.height.toDouble());
        canvas.drawImageRect(markerImage!, srcRect, dstRect, Paint());
        canvas.restore(); 
      }

      final textStyle = GoogleFonts.poppins(color: Colors.white, fontSize: 50.0, fontWeight: FontWeight.bold);
      final textPainter = TextPainter(text: TextSpan(text: texto, style: textStyle), textDirection: TextDirection.ltr);
      textPainter.layout();
      final Offset textoPos = Offset(posicion.dx, posicion.dy - subirPin - 60); 
      final rect = Rect.fromCenter(center: textoPos, width: textPainter.width + 40, height: textPainter.height + 20);
      
      canvas.drawRRect(RRect.fromRectAndRadius(rect, const Radius.circular(15)), Paint()..color = colorFondo.withOpacity(0.9));
      textPainter.paint(canvas, Offset(textoPos.dx - textPainter.width / 2, textoPos.dy - textPainter.height / 2));
    }

    for (var origen in conexiones.keys) {
      var p1 = pixeles[origen]; if (p1 == null) continue;
      Offset punto1 = transformarPunto(p1);
      canvas.drawCircle(punto1, 8.0 / zoomScale, paintNodo); 
      Map<String, dynamic> vecinos = conexiones[origen] ?? {};
      for (var destino in vecinos.keys) {
        var p2 = pixeles[destino];
        if (p2 != null) canvas.drawLine(punto1, transformarPunto(p2), paintGrafo);
      }
    }

    if (ruta.isNotEmpty) {
      for (int i = 0; i < ruta.length - 1; i++) {
        var p1 = pixeles[ruta[i]]; var p2 = pixeles[ruta[i + 1]];
        if (p1 != null && p2 != null) canvas.drawLine(transformarPunto(p1), transformarPunto(p2), paintRuta);
      }
      String origenNombre = ruta.first; String destinoNombre = ruta.last;
      String aliasOrigen = diccionarioNombres[origenNombre] ?? origenNombre;
      String aliasDestino = diccionarioNombres[destinoNombre] ?? destinoNombre;

      if (pixeles[origenNombre] != null && posicionRealGPS == null) {
        dibujarPinConEtiquetaTexto(aliasOrigen, transformarPunto(pixeles[origenNombre]), Colors.green);
      }
      if (pixeles[destinoNombre] != null) dibujarPinConEtiquetaTexto(aliasDestino, transformarPunto(pixeles[destinoNombre]), Colors.red);
    }

    if (posicionRealGPS != null && coordenadasGeo.isNotEmpty) {
      // --- CEREBRO MATEMÁTICO SINCRONIZADO ---
      double userLat = posicionRealGPS!.latitude; double userLng = posicionRealGPS!.longitude;
      
      double lat1 = coordenadasGeo['EntradaA'][0]; double lng1 = coordenadasGeo['EntradaA'][1];
      double p1x = pixeles['EntradaA'][0].toDouble(); double p1y = pixeles['EntradaA'][1].toDouble();
      
      double lat2 = coordenadasGeo['Edificio_M'][0]; double lng2 = coordenadasGeo['Edificio_M'][1];
      double p2x = pixeles['Edificio_M'][0].toDouble(); double p2y = pixeles['Edificio_M'][1].toDouble();

      double deltaLat = (lat2 - lat1).abs();
      double deltaPxX = (p2x - p1x).abs();
      double deltaPxY = (p2y - p1y).abs();
      
      bool latControlaX = (deltaPxX / deltaLat) > (deltaPxY / deltaLat);

      double newPxX = 0; double newPxY = 0;

      if (latControlaX) {
        double pctLat = (userLat - lat1) / (lat2 - lat1);
        double pctLng = (userLng - lng1) / (lng2 - lng1);
        newPxX = p1x + (pctLat * (p2x - p1x));
        newPxY = p1y + (pctLng * (p2y - p1y));
      } else {
        double pctLng = (userLng - lng1) / (lng2 - lng1);
        double pctLat = (userLat - lat1) / (lat2 - lat1);
        newPxX = p1x + (pctLng * (p2x - p1x));
        newPxY = p1y + (pctLat * (p2y - p1y));
      }

      // Aplicamos la escala 6.0 y el intercambio (Y es X, X es Y) igual que la cámara
      double finalX = newPxY * 6.0; 
      double finalY = newPxX * 6.0;

      Offset posicionUsuarioCanvas = Offset(finalX, finalY);

      final paintAura = Paint()..color = Colors.blue.withOpacity(0.3)..style = PaintingStyle.fill;
      final paintDot = Paint()..color = const Color(0xFF2563EB)..style = PaintingStyle.fill;
      final paintBorder = Paint()..color = Colors.white..strokeWidth = 10.0..style = PaintingStyle.stroke;

      canvas.drawCircle(posicionUsuarioCanvas, 80.0, paintAura);
      canvas.drawCircle(posicionUsuarioCanvas, 35.0, paintDot);
      canvas.drawCircle(posicionUsuarioCanvas, 35.0, paintBorder);

      final textStyleGps = GoogleFonts.poppins(color: Colors.white, fontSize: 35.0, fontWeight: FontWeight.bold);
      final textPainterGps = TextPainter(text: TextSpan(text: "Estás aquí", style: textStyleGps), textDirection: TextDirection.ltr);
      textPainterGps.layout();
      
      final Offset textoPosGps = Offset(posicionUsuarioCanvas.dx, posicionUsuarioCanvas.dy - 110); 
      final rectGps = Rect.fromCenter(center: textoPosGps, width: textPainterGps.width + 40, height: textPainterGps.height + 20);
      
      canvas.drawRRect(RRect.fromRectAndRadius(rectGps, const Radius.circular(15)), Paint()..color = const Color(0xFF2563EB).withOpacity(0.9));
      textPainterGps.paint(canvas, Offset(textoPosGps.dx - textPainterGps.width / 2, textoPosGps.dy - textPainterGps.height / 2));
    }
  }

  @override
  bool shouldRepaint(covariant RoutePainter oldDelegate) {
    return oldDelegate.zoomScale != zoomScale || oldDelegate.ruta != ruta || oldDelegate.posicionRealGPS != posicionRealGPS;
  }
}

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

  const PlanningPanel({super.key, required this.ubicaciones, required this.onCalcular, required this.onGpsPressed, required this.isTracking, required this.tiempoEstimado, required this.origenValue, required this.destinoValue, required this.mapTapKey, required this.onOrigenChanged, required this.onDestinoChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.only(topLeft: Radius.circular(40), topRight: Radius.circular(40)),
        boxShadow: [BoxShadow(color: const Color(0xFF3B82F6).withOpacity(0.08), blurRadius: 20, spreadRadius: 5, offset: const Offset(0, -5))],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
      child: SingleChildScrollView(
        child: Column(
          children: [
            // --- RAYITA SUPERIOR ---
            Container(width: 50, height: 5, margin: const EdgeInsets.only(bottom: 20), decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(10))),
            
            Align(alignment: Alignment.centerLeft, child: Text('Tu Ruta', style: GoogleFonts.poppins(fontSize: 22, fontWeight: FontWeight.bold, color: const Color(0xFF1E293B)))),
            const SizedBox(height: 16),
            
            // --- NUEVO DISEÑO: FILA DE ORIGEN + BOTÓN GPS COMPACTO ---
            Row(
              crossAxisAlignment: CrossAxisAlignment.end, // Alineamos por debajo para que el botón coincida con el cuadro de texto
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
                        onSelected: onOrigenChanged
                      )
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: const EdgeInsets.only(left: 4, bottom: 6), 
                            child: Text('Punto de partida', style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w600, color: const Color(0xFF64748B)))
                          ),
                          Container(
                            height: 54, // Misma altura que el cuadro de texto
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            decoration: BoxDecoration(
                              color: const Color(0xFFEFF6FF),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: const Color(0xFFBFDBFE), width: 1),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.my_location, color: Color(0xFF3B82F6), size: 20),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    'Tu ubicación actual', 
                                    style: GoogleFonts.poppins(color: const Color(0xFF1E3A8A), fontWeight: FontWeight.w600, fontSize: 14),
                                    overflow: TextOverflow.ellipsis, // Por si la pantalla es muy pequeña
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
                  color: isTracking ? const Color(0xFFFEF2F2) : const Color(0xFFEFF6FF), 
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
                        color: isTracking ? const Color(0xFFEF4444) : const Color(0xFF3B82F6)
                      ),
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
              onSelected: onDestinoChanged
            ),
            
            const SizedBox(height: 24), // Damos un poco más de espacio aquí
            
            // --- TIEMPO ESTIMADO ---
            if (tiempoEstimado.isNotEmpty)
              Container(
                margin: const EdgeInsets.only(bottom: 16), padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 20),
                decoration: BoxDecoration(color: const Color(0xFFFFF7ED), borderRadius: BorderRadius.circular(16), border: Border.all(color: const Color(0xFFFFEDD5), width: 1)),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.directions_walk, color: Color(0xFFF97316), size: 20), const SizedBox(width: 10),
                    Text('Llegarás en $tiempoEstimado', style: GoogleFonts.poppins(color: const Color(0xFFC2410C), fontWeight: FontWeight.w600, fontSize: 15)),
                  ],
                ),
              ),
            
            // --- BOTÓN PRINCIPAL ---
            Container(
              decoration: BoxDecoration(borderRadius: BorderRadius.circular(16), boxShadow: [BoxShadow(color: const Color(0xFF3B82F6).withOpacity(0.3), blurRadius: 15, offset: const Offset(0, 8))]),
              child: ElevatedButton(
                onPressed: onCalcular,
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF3B82F6), minimumSize: const Size(double.infinity, 56), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)), elevation: 0),
                child: Text('Comenzar Ruta', style: GoogleFonts.poppins(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
              ),
            ),
            const SizedBox(height: 10),
          ],
        ),
      ),
    );
  }
}

class AutocompleteInputField extends StatelessWidget {
  final Color iconColor; final String title; final String placeholder;
  final List<String> suggestions; final Function(String) onSelected;
  final String initialValue; 

  const AutocompleteInputField({super.key, required this.iconColor, required this.title, required this.placeholder, required this.suggestions, required this.onSelected, this.initialValue = ""});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(padding: const EdgeInsets.only(left: 4, bottom: 6), child: Text(title, style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w600, color: const Color(0xFF64748B)))),
        Autocomplete<String>(
          initialValue: TextEditingValue(text: initialValue),
          optionsBuilder: (val) => val.text.isEmpty ? [] : suggestions.where((s) => s.toLowerCase().contains(val.text.toLowerCase())),
          onSelected: onSelected,
          fieldViewBuilder: (ctx, ctrl, node, fn) => TextField(
            controller: ctrl, focusNode: node, onChanged: onSelected, 
            style: GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.w500, color: const Color(0xFF1E293B)),
            decoration: InputDecoration(
              prefixIcon: Padding(padding: const EdgeInsets.all(14.0), child: Container(decoration: BoxDecoration(color: iconColor.withOpacity(0.2), shape: BoxShape.circle), padding: const EdgeInsets.all(4), child: Icon(Icons.circle, color: iconColor, size: 10))),
              hintText: placeholder, hintStyle: GoogleFonts.poppins(color: const Color(0xFF94A3B8)), filled: true, fillColor: const Color(0xFFF8FAFC), contentPadding: const EdgeInsets.symmetric(vertical: 16),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: Colors.grey.shade200)), enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: Colors.grey.shade200)), focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: const BorderSide(color: Color(0xFF3B82F6), width: 1.5)),
            ),
          ),
        ),
      ],
    );
  }
}

class PriorityQueue<T> {
  final List<T> _items = [];
  final int Function(T, T) compare;
  PriorityQueue(this.compare);
  bool get isNotEmpty => _items.isNotEmpty;
  void add(T item) { _items.add(item); _items.sort(compare); }
  T removeFirst() => _items.removeAt(0);
}