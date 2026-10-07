import 'dart:async';
import 'dart:math';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';

import '../../data/campus_repository.dart';
import '../../data/diccionario_nombres.dart';
import '../../domain/dijkstra.dart';
import '../../domain/interpolacion_nodos.dart';
import '../../domain/transformacion_geo.dart';
import '../../domain/ubicacion_en_ruta.dart';
import '../../instrumentacion/directorio_registros.dart';
import '../../instrumentacion/registro_csv_campo.dart';
import '../../instrumentacion/sesion_campo.dart';
import '../../models/grafo_campus.dart';
import '../../models/nodo.dart';
import '../../models/ruta.dart';
import '../../utils/cronometro.dart';
import '../../utils/geodesia.dart';
import '../../utils/indice_espacial.dart';
import '../widgets/map_image_area.dart';
import '../widgets/panel_instrumentacion.dart';
import '../widgets/planning_panel.dart';
import '../widgets/selector_sesion_campo.dart';

/// Modelo de transformación geo→píxel activo, seleccionado en tiempo de
/// compilación con `--dart-define=TRANSFORMACION=afin|dospuntos`. Por
/// defecto, `dospuntos` -el modelo original de la app, documentado y
/// justificado en la tesis- para no cambiar el comportamiento salvo que se
/// pida explícitamente.
const String _modoTransformacion =
    String.fromEnvironment('TRANSFORMACION', defaultValue: 'dospuntos');

/// Activa la instrumentación de campo (Fase 5): cronómetro, registro de
/// recorrido en CSV y modo punto de verificación. Apagada por defecto -en
/// cualquier modo, incluido debug-, así que sin
/// `--dart-define=INSTRUMENTACION=true` la app se ve y se comporta
/// exactamente igual que antes de la Fase 5: ni el botón flotante del
/// panel, ni el panel, ni la pantalla de sesión, ni la opción extra en el
/// menú de nodo llegan a existir.
const bool _modoInstrumentacion = bool.fromEnvironment('INSTRUMENTACION');

/// Cuánto se espera la lectura de GPS de un punto de verificación antes de
/// darla por fallida.
const Duration _kTiempoMaximoLecturaVerificacion = Duration(seconds: 15);

class CampusMapScreen extends StatefulWidget {
  const CampusMapScreen({super.key});

  @override
  State<CampusMapScreen> createState() => _CampusMapScreenState();
}

class _CampusMapScreenState extends State<CampusMapScreen> {
  final CampusRepository _repositorio = const CampusRepository();
  final FiltroPosicion _filtroPosicion = FiltroMediaMovil();
  final Cronometro _cronometro = Cronometro();

  GrafoCampus? _grafo;
  IndiceEspacial? _indiceEspacial;
  TransformacionGeoPixel? _transformacionActiva;
  TransformacionDosPuntos? _transformacionDosPuntos;
  TransformacionAfin? _transformacionAfin;
  double _pxPorMetro = 0;
  List<String> ubicacionesDisponibles = [];
  Ruta rutaCalculada = Ruta.vacia;
  String tiempoEstimado = "";
  ui.Image? markerImage;

  String origenSeleccionado = "";
  String destinoSeleccionado = "";
  int mapTapKey = 0;

  StreamSubscription<Position>? _gpsStream;
  bool _rastreandoGPS = false;
  // Navegación en curso con la ubicación actual como origen: el botón
  // principal se convierte en "Detener ruta" mientras sea true.
  bool _navegando = false;

  // Posición del usuario ya filtrada (precisión), suavizada (media móvil)
  // y proyectada ortogonalmente sobre la arista más cercana (Fase 3). Es lo
  // que se dibuja como marcador "Estás aquí" y lo que decide el nodo de
  // partida para Dijkstra.
  UbicacionEnGrafo? _ubicacionActual;
  UbicacionEnGrafo? _ultimaUbicacionUsadaParaRuta; // para la histéresis

  // Registro en paralelo del nodo que habría devuelto el método anterior
  // (snapping al nodo más cercano, sin filtro ni suavizado) con la misma
  // lectura cruda de GPS: permite reportar en campo el error real de
  // cuantización que evitó la proyección, no solo el simulado.
  String? nodoMasCercanoMetodoAnterior;

  // --- Instrumentación de campo (Fase 5) ---
  SesionCampo? _sesionCampo;
  RegistroCsvCampo? _registroCampo;
  bool _modoVerificacion = false;
  // Evita pedir dos lecturas a la vez (y registrar filas duplicadas) si se
  // toca otro nodo mientras la primera todavía no llega.
  bool _obteniendoLecturaVerificacion = false;

  int disparadorZoom = 0; // Disparador manual de cámara

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
    // Antes decía 'assets/pin_marker.png', un archivo que nunca existió
    // -pubspec.yaml siempre declaró 'assets/pin.png'-, así que esta carga
    // fallaba en silencio en todas las builds.
    const String imagePath = 'assets/pin.png';
    try {
      final ByteData data = await rootBundle.load(imagePath);
      final Uint8List bytes = data.buffer.asUint8List();
      final ui.Codec codec = await ui.instantiateImageCodec(bytes);
      final ui.FrameInfo fi = await codec.getNextFrame();
      setState(() {
        markerImage = fi.image;
      });
    } catch (e, stack) {
      // FlutterError.reportError (en vez de un print/debugPrint) para que
      // el fallo se vea de verdad en modo debug -banner rojo en la
      // consola, no una línea de texto fácil de perder entre el resto del
      // log- en lugar de fallar en silencio.
      FlutterError.reportError(FlutterErrorDetails(
        exception: e,
        stack: stack,
        library: 'mapa_cusur',
        context: ErrorDescription('cargando el marcador del pin ($imagePath)'),
      ));
    }
  }

  Future<void> _cargarDatosDelMapa() async {
    try {
      final datos = await _repositorio.cargarDatosCampus(
        cronometro: _modoInstrumentacion ? _cronometro : null,
      );
      final GrafoCampus grafoBase = datos.grafo;
      final GrafoCampus grafoInterpolado = _modoInstrumentacion
          ? _cronometro.medir('interpolacion', () => interpolarGrafo(grafoBase))
          : interpolarGrafo(grafoBase);

      final List<String> filtrados = grafoBase.nodos.keys
          .where((id) => diccionarioNombres.containsKey(id))
          .map((id) => diccionarioNombres[id]!)
          .toList();

      filtrados.sort();

      final dosPuntos = TransformacionDosPuntos(
        controlA: grafoBase.nodos['EntradaA']!,
        controlB: grafoBase.nodos['Edificio_M']!,
      );

      TransformacionAfin? afin;
      try {
        final puntosControl =
            datos.puntosControl.map((id) => grafoBase.nodos[id]!).toList();
        afin = TransformacionAfin.ajustar(puntosControl);
      } catch (e) {
        debugPrint('No se pudo ajustar TransformacionAfin: $e');
      }

      final double pxPorMetro = calcularEscalaPxPorMetro(grafoBase);

      if (kDebugMode) {
        final rDosPuntos = evaluarTransformacion(dosPuntos, grafoBase.nodos.values,
            pxPorMetro: pxPorMetro);
        debugPrint('RMSE TransformacionDosPuntos (${grafoBase.nodos.length} '
            'nodos): ${rDosPuntos.rmsePx.toStringAsFixed(2)} px '
            '(${rDosPuntos.rmseMetros.toStringAsFixed(2)} m)');
        if (afin != null) {
          final rAfin = evaluarTransformacion(afin, grafoBase.nodos.values,
              pxPorMetro: pxPorMetro);
          debugPrint('RMSE TransformacionAfin (${grafoBase.nodos.length} '
              'nodos): ${rAfin.rmsePx.toStringAsFixed(2)} px '
              '(${rAfin.rmseMetros.toStringAsFixed(2)} m)');
        }
        debugPrint('Modelo de transformación activo: $_modoTransformacion');
      }

      setState(() {
        _grafo = grafoInterpolado;
        _indiceEspacial = IndiceEspacial(grafoInterpolado.nodos);
        _transformacionDosPuntos = dosPuntos;
        _transformacionAfin = afin;
        _pxPorMetro = pxPorMetro;
        _transformacionActiva =
            (_modoTransformacion == 'afin' && afin != null) ? afin : dosPuntos;
        ubicacionesDisponibles = filtrados;
      });
    } catch (e) {
      debugPrint("❌ Error cargando datos: $e");
    }
  }

  void _toggleRastreoGPS() async {
    if (_rastreandoGPS) {
      _gpsStream?.cancel();
      setState(() {
        _rastreandoGPS = false;
        _navegando = false;
        _ubicacionActual = null;
        _ultimaUbicacionUsadaParaRuta = null;
        nodoMasCercanoMetodoAnterior = null;
      });
      return;
    }
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!mounted) return;
    if (!serviceEnabled) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Activa el GPS.')));
      return;
    }
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (!mounted) return;
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      return;
    }
    _filtroPosicion.reiniciar();
    _gpsStream = Geolocator.getPositionStream(
            locationSettings: const LocationSettings(
                accuracy: LocationAccuracy.bestForNavigation, distanceFilter: 1))
        .listen(_procesarLecturaGps);
    setState(() {
      _rastreandoGPS = true;
    });
  }

  void _procesarLecturaGps(Position position) {
    final grafo = _grafo;
    if (grafo == null) return;

    // Registro en paralelo: qué nodo habría devuelto el snapping por nodo
    // más cercano con esta misma lectura cruda -sin filtro de precisión ni
    // suavizado-, tal como lo hacía el código antes de la Fase 3.
    final String? nodoMetodoAnterior =
        _indiceEspacial?.masCercano(position.latitude, position.longitude);

    if (!lecturaGpsEsAceptable(position.accuracy)) {
      debugPrint('GPS descartado por baja precisión: '
          '${position.accuracy.toStringAsFixed(1)} m '
          '(umbral: $kPrecisionMaximaMetros m)');
      _registroCampo?.registrarLecturaGps(
        position: position,
        lecturaAceptada: false,
        nodoMetodoAnterior: nodoMetodoAnterior,
      );
      return;
    }

    final suavizada = _filtroPosicion.filtrar(position.latitude, position.longitude);
    final UbicacionEnGrafo? ubicacion =
        proyectarSobreArista(grafo, suavizada.lat, suavizada.lng);
    if (ubicacion == null) return;

    debugPrint('Ubicación GPS -> método anterior (nodo más cercano): '
        '${nodoMetodoAnterior ?? "?"} | método actual (proyección): '
        'arista ${ubicacion.aristaA}-${ubicacion.aristaB}, '
        't=${ubicacion.t.toStringAsFixed(3)}, '
        'distancia al camino=${ubicacion.distanciaAlCaminoMetros.toStringAsFixed(2)} m');

    bool seRecalculo = false;
    setState(() {
      _ubicacionActual = ubicacion;
      nodoMasCercanoMetodoAnterior = nodoMetodoAnterior;

      if (destinoSeleccionado.isNotEmpty &&
          debeRecalcularRuta(
              ultimaUbicacionUsada: _ultimaUbicacionUsadaParaRuta,
              ubicacionActual: ubicacion)) {
        _ultimaUbicacionUsadaParaRuta = ubicacion;
        seRecalculo = true;
        calcularRuta();
      }
    });

    _registroCampo?.registrarLecturaGps(
      position: position,
      lecturaAceptada: true,
      ubicacion: ubicacion,
      nodoMetodoAnterior: nodoMetodoAnterior,
      seRecalculoRuta: seRecalculo,
    );
  }

  void calcularRuta() {
    String obtenerId(String texto) {
      for (var entry in diccionarioNombres.entries) {
        if (entry.value == texto) return entry.key;
      }
      return texto;
    }

    final grafo = _grafo;
    if (grafo == null) return;

    String idInicio = "";

    if (_rastreandoGPS && _ubicacionActual != null) {
      idInicio = _ubicacionActual!.nodoMasCercanoEnLaArista;
      origenSeleccionado = diccionarioNombres[idInicio] ?? idInicio;
      // NOTA: Aquí quitamos el disparadorZoom++. Solo se activa al presionar el botón.
    } else {
      idInicio = obtenerId(origenSeleccionado);
    }

    final String idDestino = obtenerId(destinoSeleccionado);
    if (idInicio.isEmpty || idDestino.isEmpty) return;
    if (!grafo.conexiones.containsKey(idInicio) ||
        !grafo.conexiones.containsKey(idDestino)) {
      return;
    }

    final Ruta resultado = _modoInstrumentacion
        ? _cronometro.medir(
            'dijkstra', () => calcularRutaMasCorta(grafo, idInicio, idDestino))
        : calcularRutaMasCorta(grafo, idInicio, idDestino);

    setState(() {
      rutaCalculada = resultado;
      tiempoEstimado = (!resultado.esVacia && resultado.minutos > 0)
          ? "${resultado.minutos.toStringAsFixed(1)} minutos"
          : "";
    });
  }

  void _seleccionarDesdeMapa(String nombreAmigable, bool esOrigen) {
    setState(() {
      if (esOrigen) {
        if (_rastreandoGPS) _toggleRastreoGPS();
        origenSeleccionado = nombreAmigable;
      } else {
        destinoSeleccionado = nombreAmigable;
        _navegando = false;
      }
      mapTapKey++;
      if (origenSeleccionado.isNotEmpty && destinoSeleccionado.isNotEmpty) {
        calcularRuta();
      } else {
        rutaCalculada = Ruta.vacia;
        tiempoEstimado = "";
      }
    });
  }

  void _limpiarRuta() {
    if (_rastreandoGPS) _toggleRastreoGPS();
    setState(() {
      origenSeleccionado = "";
      destinoSeleccionado = "";
      rutaCalculada = Ruta.vacia;
      tiempoEstimado = "";
      _navegando = false;
      mapTapKey++; // reconstruye los campos para que se vean vacíos
    });
  }

  void _comenzarRuta() {
    // AQUÍ DISPARAMOS EL ZOOM MANUALMENTE
    setState(() {
      disparadorZoom++;
    });
    calcularRuta();
    // Solo la navegación con GPS se puede "detener"; una ruta con origen
    // elegido a mano es estática.
    if (_rastreandoGPS &&
        destinoSeleccionado.isNotEmpty &&
        !rutaCalculada.esVacia) {
      setState(() => _navegando = true);
    }
  }

  void _detenerRuta() {
    // Apagar el GPS también pone _navegando en false.
    if (_rastreandoGPS) _toggleRastreoGPS();
    setState(() {
      _navegando = false;
      rutaCalculada = Ruta.vacia;
      tiempoEstimado = "";
      // El destino se conserva para poder volver a empezar.
    });
  }

  // --- Instrumentación de campo (Fase 5) ---

  Future<void> _iniciarSesionCampo() async {
    final sesion = await SelectorSesionCampoDialog.mostrar(context);
    if (sesion == null || !mounted) return;
    final directorio = await resolverDirectorioRegistros();
    if (!mounted) return;
    final registro = RegistroCsvCampo(sesion: sesion, directorio: directorio);
    setState(() {
      _sesionCampo = sesion;
      _registroCampo = registro;
    });
    ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Registro iniciado: ${registro.rutaArchivo}')));
  }

  void _detenerSesionCampo() {
    setState(() {
      _sesionCampo = null;
      _registroCampo = null;
    });
  }

  double _distanciaPx(({double x, double y}) pixel, Nodo nodo) {
    final double dx = pixel.x - nodo.pixelX;
    final double dy = pixel.y - nodo.pixelY;
    return sqrt(dx * dx + dy * dy);
  }

  /// Modo punto de verificación (Fase 5, ítem 3): el usuario confirma que
  /// está parado en [nodoId], se pide una lectura de GPS nueva en ese
  /// momento y se compara contra lo que predice cada modelo de
  /// transformación para esa misma posición conocida. Si la lectura falla
  /// o tarda más de [_kTiempoMaximoLecturaVerificacion], no se registra
  /// nada.
  Future<void> _registrarVerificacionEnNodo(String nodoId) async {
    if (_obteniendoLecturaVerificacion) return;
    final grafo = _grafo;
    final dosPuntos = _transformacionDosPuntos;
    if (grafo == null || dosPuntos == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('El mapa aún no termina de cargar.')));
      return;
    }
    final Nodo? nodo = grafo.nodos[nodoId];
    if (nodo == null) return;

    final mensajero = ScaffoldMessenger.of(context);
    mensajero.showSnackBar(const SnackBar(
      duration: Duration(minutes: 1), // se oculta a mano al terminar
      content: Row(
        children: [
          SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
          ),
          SizedBox(width: 12),
          Text('Obteniendo lectura…'),
        ],
      ),
    ));

    _obteniendoLecturaVerificacion = true;
    final Position posicion;
    try {
      posicion = await Geolocator.getCurrentPosition(
        locationSettings:
            const LocationSettings(accuracy: LocationAccuracy.bestForNavigation),
      ).timeout(_kTiempoMaximoLecturaVerificacion);
    } catch (e) {
      final String motivo = e is TimeoutException
          ? 'tardó más de ${_kTiempoMaximoLecturaVerificacion.inSeconds} s'
          : '$e';
      if (mounted) {
        mensajero
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(
              content: Text('No se pudo obtener la lectura de GPS ($motivo). '
                  'No se registró nada.')));
      }
      return;
    } finally {
      _obteniendoLecturaVerificacion = false;
    }

    // Error del GPS solo: lectura cruda vs. coordenadas reales del nodo,
    // sin pasar por ningún modelo de transformación.
    final double errorGpsM = distanciaHaversineMetros(
        posicion.latitude, posicion.longitude, nodo.lat, nodo.lng);

    final pixelDosPuntos = dosPuntos.aPixeles(posicion.latitude, posicion.longitude);
    final double errorPxDosPuntos = _distanciaPx(pixelDosPuntos, nodo);
    final double errorMDosPuntos =
        _pxPorMetro > 0 ? errorPxDosPuntos / _pxPorMetro : double.nan;

    final afin = _transformacionAfin;
    final pixelAfin = afin != null
        ? afin.aPixeles(posicion.latitude, posicion.longitude)
        : (x: double.nan, y: double.nan);
    final double errorPxAfin = afin != null ? _distanciaPx(pixelAfin, nodo) : double.nan;
    final double errorMAfin =
        (afin != null && _pxPorMetro > 0) ? errorPxAfin / _pxPorMetro : double.nan;

    await _registroCampo?.registrarPuntoVerificacion(
      position: posicion,
      nodoVerificado: nodoId,
      nodoLat: nodo.lat,
      nodoLng: nodo.lng,
      errorGpsM: errorGpsM,
      pixelDosPuntos: pixelDosPuntos,
      errorPxDosPuntos: errorPxDosPuntos,
      errorMDosPuntos: errorMDosPuntos,
      pixelAfin: pixelAfin,
      errorPxAfin: errorPxAfin,
      errorMAfin: errorMAfin,
    );

    if (!mounted) return;
    mensajero.hideCurrentSnackBar();
    mensajero.showSnackBar(SnackBar(
      content: Text('Verificación en $nodoId — '
          'GPS: ${errorGpsM.toStringAsFixed(1)} m · '
          'dos puntos: ${errorMDosPuntos.toStringAsFixed(1)} m · '
          'afín: ${afin != null ? "${errorMAfin.toStringAsFixed(1)} m" : "no disponible"}'),
    ));
  }

  void _mostrarPanelInstrumentacion() {
    PanelInstrumentacion.mostrar(
      context,
      PanelInstrumentacion(
        cronometro: _cronometro,
        sesionActiva: _sesionCampo,
        rutaArchivoActivo: _registroCampo?.rutaArchivo,
        modoVerificacion: _modoVerificacion,
        onIniciarSesion: () {
          Navigator.of(context).pop();
          _iniciarSesionCampo();
        },
        onDetenerSesion: () {
          Navigator.of(context).pop();
          _detenerSesionCampo();
        },
        onCambiarModoVerificacion: (v) {
          setState(() => _modoVerificacion = v);
          Navigator.of(context).pop();
        },
      ),
    );
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
              top: 0,
              left: 0,
              right: 0,
              height: screenHeight * 0.4,
              child: MapImageArea(
                ruta: rutaCalculada.nodos,
                grafo: _grafo,
                transformacion: _transformacionActiva,
                markerImage: markerImage,
                onNodoSeleccionado: _seleccionarDesdeMapa,
                ubicacionGPS: _ubicacionActual,
                disparadorZoom: disparadorZoom,
                onVerificarAqui:
                    _modoVerificacion ? _registrarVerificacionEnNodo : null,
              ),
            ),
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              height: screenHeight * 0.5,
              child: PlanningPanel(
                ubicaciones: ubicacionesDisponibles,
                onCalcular: _comenzarRuta,
                onDetener: _detenerRuta,
                navegando: _navegando,
                onGpsPressed: _toggleRastreoGPS,
                isTracking: _rastreandoGPS,
                tiempoEstimado: tiempoEstimado,
                origenValue: origenSeleccionado,
                destinoValue: destinoSeleccionado,
                mapTapKey: mapTapKey,
                onOrigenChanged: (val) {
                  setState(() {
                    origenSeleccionado = val;
                    rutaCalculada = Ruta.vacia;
                    tiempoEstimado = "";
                  });
                },
                onDestinoChanged: (val) {
                  setState(() {
                    destinoSeleccionado = val;
                    _navegando = false;
                    rutaCalculada = Ruta.vacia;
                    tiempoEstimado = "";
                  });
                },
                onLimpiar: _limpiarRuta,
              ),
            ),
            if (_modoInstrumentacion)
              Positioned(
                top: 8,
                right: 8,
                child: FloatingActionButton.small(
                  heroTag: 'panelInstrumentacion',
                  backgroundColor: Colors.black87,
                  onPressed: _mostrarPanelInstrumentacion,
                  child: const Icon(Icons.science, color: Colors.white),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
