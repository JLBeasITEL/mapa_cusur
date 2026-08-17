# Mapa CUSur

Aplicación móvil de mapa interactivo para el campus de **CUSur** (Centro Universitario del Sur, Universidad de Guadalajara), desarrollada en **Flutter**. Permite ubicar puntos del campus, trazar la ruta caminando más corta entre un origen y un destino sobre una imagen del mapa, y seguir la posición del usuario en tiempo real por GPS.

## Tabla de contenido

- [Descripción general](#descripción-general)
- [Stack técnico](#stack-técnico)
- [Estructura del proyecto](#estructura-del-proyecto)
- [Cómo funciona la app](#cómo-funciona-la-app)
  - [Flujo de pantallas](#flujo-de-pantallas)
  - [Datos del campus (`campus_data.json`)](#datos-del-campus-campus_datajson)
  - [Interpolación del grafo (puntos fantasma)](#interpolación-del-grafo-puntos-fantasma)
  - [Cálculo de ruta (Dijkstra)](#cálculo-de-ruta-dijkstra)
  - [Renderizado del mapa](#renderizado-del-mapa)
  - [Ubicación GPS en tiempo real](#ubicación-gps-en-tiempo-real)
- [Script de generación de datos (`exportar_rutas.py`)](#script-de-generación-de-datos-exportar_rutaspy)
- [Requisitos y ejecución](#requisitos-y-ejecución)
- [Permisos](#permisos)
- [Limitaciones conocidas](#limitaciones-conocidas)

## Descripción general

La app no usa un SDK de mapas (no hay Google Maps, Mapbox ni Leaflet). En su lugar, el "mapa" es una **imagen estática** del plano del campus (`assets/mapa_CUSur.png`) sobre la que se dibuja, con un `CustomPainter`, un grafo de nodos y aristas que representa las rutas peatonales reales del campus. El usuario elige un punto de partida y un destino (por texto o tocando el mapa) y la app calcula la ruta más rápida caminando y el tiempo estimado de llegada, usando el algoritmo de Dijkstra sobre ese grafo.

## Stack técnico

| Categoría | Detalle |
|---|---|
| Framework | Flutter (Dart SDK `^3.11.1`) |
| UI | Material 3, tipografía `google_fonts` (Poppins) |
| Ubicación | `geolocator: ^13.0.1` (permisos, stream de posición, cálculo de distancias) |
| Iconos de app | `flutter_launcher_icons` (genera el ícono para Android/iOS desde `assets/icon.png`) |
| Persistencia/estado | Ninguna — todo vive en memoria (`setState`) dentro de un único `StatefulWidget` |
| Datos del mapa | Estáticos, embebidos como asset JSON (`assets/campus_data.json`) |
| Herramienta auxiliar | Script en Python (`exportar_rutas.py`) para autorar/editar el grafo del campus fuera de la app |

No hay backend, base de datos ni llamadas de red: la app es 100% offline una vez instalada.

## Estructura del proyecto

```
mapa_cusur/                      # raíz del repositorio
└── mapa_cusur/                  # proyecto Flutter
    ├── lib/
    │   └── main.dart            # toda la app (pantalla, mapa, algoritmo, UI) en un solo archivo
    ├── assets/
    │   ├── campus_data.json     # grafo del campus: nodos, coordenadas y conexiones
    │   ├── mapa_CUSur.png       # imagen de fondo del plano del campus
    │   ├── pin.png              # ícono de marcador (pin)
    │   └── icon.png             # imagen fuente del ícono de la app
    ├── exportar_rutas.py        # script offline para (re)generar campus_data.json
    ├── android/ ios/ web/ ...   # proyectos de cada plataforma (generados por Flutter)
    └── pubspec.yaml             # dependencias, assets y configuración del ícono
```

Toda la lógica de la aplicación —pantalla, widget del mapa, `CustomPainter`, panel de planeación de ruta, autocompletado y cola de prioridad para Dijkstra— está en un único archivo: [`lib/main.dart`](mapa_cusur/lib/main.dart) (~890 líneas).

## Cómo funciona la app

### Flujo de pantallas

La app tiene una sola pantalla (`CampusMapScreen`), dividida en dos zonas dentro de un `Stack`:

1. **Zona superior (40% de la altura)** — `MapImageArea`: el mapa interactivo (zoom/pan con `InteractiveViewer`, mínimo 1x y máximo 8x).
2. **Zona inferior (50% de la altura)** — `PlanningPanel`: campos de autocompletado para origen/destino, botón de GPS, botón "Comenzar Ruta" y el tiempo estimado de llegada.

Al tocar un punto del mapa se abre una hoja inferior (`_mostrarMenuDeNodo`) que permite marcarlo como **origen** o **destino**. En cuanto ambos están definidos, se calcula la ruta automáticamente.

### Datos del campus (`campus_data.json`)

Es la fuente de verdad del mapa: un JSON con ~144 nodos y tres secciones:

```json
{
  "coordenadas_geo": { "EntradaA": [19.72384, -103.46214], ... },
  "coordenadas_pix": { "EntradaA": [177, 102], ... },
  "conexiones":      { "EntradaA": { "Estacionamiento4": 0.73, "Gimnasio": 0.86 }, ... }
}
```

- `coordenadas_geo`: coordenadas GPS reales (lat, lng) de cada nodo — se usan para GPS y para calcular distancias.
- `coordenadas_pix`: posición en píxeles de cada nodo sobre `mapa_CUSur.png` — se usan para dibujar.
- `conexiones`: lista de adyacencia con **peso en minutos caminando** entre nodos conectados.

Los nodos incluyen tanto lugares con nombre (entradas, edificios, estacionamientos, cafetería, rectoría, etc.) como nodos puramente estructurales (`L1`, `C2`, `SP4`, ...) que solo existen para dar forma geométrica a las rutas peatonales y no son seleccionables por el usuario. Un diccionario `diccionarioNombres` en `main.dart` (~46 entradas) mapea los IDs internos a nombres amigables ("Edificio B", "Centro Acuático", "C.A.S.A. (Biblioteca)", etc.) y filtra cuáles aparecen en el buscador.

### Interpolación del grafo (puntos fantasma)

Antes de usarse, el grafo cargado se procesa con `_interpolarGrafo()` (`main.dart:109`). Cualquier arista de más de 8 metros (calculado con `Geolocator.distanceBetween`) se subdivide automáticamente en nodos intermedios ("fantasma", con ID tipo `Nodo1_Nodo2_inter_1`), de modo que:

- la línea de la ruta se vea curva/suave siguiendo el trazo real del camino, en vez de una línea recta entre dos puntos lejanos;
- el peso (tiempo) original de la arista se **reparte equitativamente** entre los sub-tramos nuevos, para que la suma total del tiempo estimado siga siendo correcta.

Este mecanismo fue la corrección al bug de estimación de tiempo mencionado en el historial de commits del proyecto.

### Cálculo de ruta (Dijkstra)

`calcularRuta()` (`main.dart:223`) ejecuta el algoritmo de **Dijkstra** sobre el grafo (ya interpolado) usando una cola de prioridad hecha a mano (`PriorityQueue<T>`, `main.dart:883`, ya que Dart no trae una en su librería estándar). El resultado es la secuencia de nodos de la ruta más corta y la suma de los pesos (minutos) del camino, que se muestra como "Llegarás en X minutos".

### Renderizado del mapa

`MapImageArea` muestra `mapa_CUSur.png` dentro de un `InteractiveViewer` + `FittedBox`, y superpone un `CustomPaint` (`RoutePainter`) que dibuja, en este orden:

1. Todo el grafo (nodos y aristas) en azul tenue, como referencia visual.
2. La ruta calculada, en rojo grueso.
3. Pines con etiqueta de texto para el origen (verde) y destino (rojo).
4. Si el GPS está activo, un punto azul pulsante con la etiqueta "Estás aquí" en la posición real del usuario.

Las coordenadas en píxeles se escalan con un factor fijo (`factorEscala = 6.0`) para ubicarlas sobre la imagen renderizada.

### Ubicación GPS en tiempo real

Al activar el botón de GPS (`_toggleRastreoGPS`), la app:

1. Verifica que el servicio de ubicación esté activo y solicita permiso si hace falta.
2. Se suscribe a un stream de posición (`LocationAccuracy.bestForNavigation`, actualiza cada 1 metro de desplazamiento).
3. En cada actualización, busca el nodo del grafo más cercano a la posición real (`_encontrarNodoMasCercanoAlGps`) y lo usa como origen, recalculando la ruta.
4. Convierte la coordenada GPS real a espacio de píxeles usando dos puntos de referencia conocidos (`EntradaA` y `Edificio_M`) para auto-detectar la orientación/escala del mapa, y anima la cámara (`InteractiveViewer`) para centrarse en el usuario.

## Script de generación de datos (`exportar_rutas.py`)

Es una herramienta **externa a la app**, en Python, que actúa como fuente original del grafo del campus:

- Define en diccionarios de Python las coordenadas geográficas y en píxeles de cada nodo, y las conexiones entre ellos.
- Calcula el peso de cada arista con la fórmula de **Haversine** (distancia real en km) convertida a minutos caminando a una velocidad asumida de 4 km/h.
- Incluye su propia implementación de Dijkstra para validar rutas antes de exportar.
- Genera `campus_data.json` con `generar_json_para_flutter()`.

Este script se ejecuta manualmente cada vez que se agregan o modifican puntos del campus; el JSON resultante debe copiarse a mano a `assets/campus_data.json`. Requiere `matplotlib` instalado (se usa para visualizar/depurar el grafo al editarlo).

## Requisitos y ejecución

```bash
cd mapa_cusur/mapa_cusur
flutter pub get
flutter run              # ejecutar en un emulador/dispositivo conectado
```

Compilar para producción:

```bash
flutter build apk        # Android
flutter build ios        # iOS (requiere macOS + Xcode)
```

Para regenerar el grafo del campus tras editarlo en `exportar_rutas.py`:

```bash
cd mapa_cusur/mapa_cusur
python exportar_rutas.py    # requiere matplotlib; genera un nuevo campus_data.json
# copiar el resultado a assets/campus_data.json
```

## Permisos

- **Android** (`AndroidManifest.xml`): `ACCESS_FINE_LOCATION`, `ACCESS_COARSE_LOCATION`.
- **iOS** (`Info.plist`): `NSLocationWhenInUseUsageDescription` — "Esta app necesita acceso a tu ubicación para guiarte por el campus."

El nombre visible de la app es **RutaCUSur** en ambas plataformas (configurado en `AndroidManifest.xml` / `Info.plist`); el ícono se genera desde `assets/icon.png` vía `flutter_launcher_icons`.

## Limitaciones conocidas

- El `applicationId`/namespace de Android sigue siendo el valor por defecto de la plantilla de Flutter (`com.example.mapa_cusur`) — se recomienda cambiarlo antes de publicar.
- El código carga `assets/pin_marker.png` para el ícono del pin (`_loadMarkerImage`), pero ese archivo no existe en `assets/` (solo existe `pin.png`, que tampoco se referencia ahí) — la carga falla silenciosamente y solo se registra en consola.
- `test/widget_test.dart` es todavía la prueba por defecto de un proyecto Flutter nuevo (contador), no cubre la lógica real de la app.
- No hay modularización: toda la lógica vive en un único archivo `main.dart`.
- No hay CI configurado.
