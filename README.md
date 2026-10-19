# Mapa CUSur (RutaCUSur)

Aplicación móvil de mapa interactivo para el campus de **CUSur** (Centro Universitario del Sur, Universidad de Guadalajara), desarrollada en **Flutter**. Permite ubicar puntos del campus, trazar la ruta caminando más corta entre un origen y un destino sobre una imagen del mapa, y seguir la posición del usuario en tiempo real por GPS, proyectada ortogonalmente sobre el sendero más cercano.

## Versiones

| Versión | Dónde | Qué es |
|---|---|---|
| `v1.0-tesis` | Etiqueta | Código al momento de redactar la tesis (17 de agosto de 2026), con el mapa de imagen. |
| `v-pruebas-campo` | Etiqueta (commit `d0586da`) | Versión instalada en las pruebas de campo del 8 de octubre de 2026. Con ella se obtuvieron los resultados reportados en la tesis. |
| `v1.1.0` | Rama `main` | Mapa vectorial dibujado por la app con datos de OpenStreetMap y grafo de andadores corregido con un trazo de campo. |

Las cifras del grafo que aparecen más abajo en este README (144 nodos, 1 980 rutas en la línea base, 38 aristas asimétricas, 63 pruebas) corresponden a la versión evaluada en la tesis. La calibración de esa versión se conserva sin cambios en `mapa_cusur/assets/calibracion_campo.json`, por lo que las cifras de transformación reportadas en la tesis se reproducen exactamente en `main`. El detalle de la versión 1.1.0 está en `mapa_cusur/docs/mapa_vectorial/ESTADO.md`.

## Tabla de contenido

- [Descripción general](#descripción-general)
- [Stack técnico](#stack-técnico)
- [Estructura del proyecto](#estructura-del-proyecto)
- [Cómo funciona la app](#cómo-funciona-la-app)
  - [Flujo de pantallas](#flujo-de-pantallas)
  - [Datos del campus (`campus_data.json`)](#datos-del-campus-campus_datajson)
  - [Interpolación del grafo (puntos fantasma)](#interpolación-del-grafo-puntos-fantasma)
  - [Cálculo de ruta (Dijkstra)](#cálculo-de-ruta-dijkstra)
  - [Ubicación GPS en tiempo real](#ubicación-gps-en-tiempo-real)
  - [Renderizado del mapa](#renderizado-del-mapa)
  - [Transformación geo→píxel: dos puntos y afín](#transformación-geopíxel-dos-puntos-y-afín)
- [Mapa vectorial](#mapa-vectorial)
  - [De dónde salen los datos](#de-dónde-salen-los-datos)
  - [Licencia de los datos (ODbL)](#licencia-de-los-datos-odbl)
  - [Cambiar entre el mapa vectorial y la imagen](#cambiar-entre-el-mapa-vectorial-y-la-imagen)
- [Instrumentación de campo](#instrumentación-de-campo)
- [Herramientas de datos](#herramientas-de-datos)
  - [`exportar_rutas.py`](#exportar_rutaspy)
  - [`tool/generar_linea_base.dart`](#toolgenerar_linea_basedart)
  - [`analizar_csv_campo.py`](#analizar_csv_campopy)
- [Requisitos y ejecución](#requisitos-y-ejecución)
- [Pruebas](#pruebas)
- [Permisos](#permisos)
- [Documentos del refactor](#documentos-del-refactor)
- [Limitaciones conocidas y trabajo futuro](#limitaciones-conocidas-y-trabajo-futuro)

## Descripción general

La app no usa un SDK de mapas (no hay Google Maps, Mapbox ni Leaflet). En su lugar, el "mapa" es una **imagen estática** del plano del campus (`assets/mapa_CUSur.png`) sobre la que se dibuja, con dos `CustomPainter` separados, un grafo de nodos y aristas que representa las rutas peatonales reales del campus. El usuario elige un punto de partida y un destino (por texto o tocando el mapa) y la app calcula la ruta más rápida caminando y el tiempo estimado de llegada con el algoritmo de Dijkstra sobre ese grafo, densificado con nodos "fantasma" cada ≤8 m para que el trazo siga el camino real y el usuario pueda ubicarse con precisión sobre él.

Este proyecto sustenta una tesis de licenciatura: el código está modularizado, comentado en español, y cubierto por una suite de pruebas automatizadas que incluye una línea base de regresión de rutas (para detectar si un cambio altera silenciosamente el resultado de una ruta ya calculada) y un validador de integridad de los datos del grafo.

## Stack técnico

| Categoría | Detalle |
|---|---|
| Framework | Flutter (Dart SDK `^3.11.1`) |
| UI | Material 3, tipografía Poppins **empaquetada localmente** (`assets/fonts/`, licencia OFL) |
| Ubicación | `geolocator: ^13.0.1` (permisos, stream de posición) |
| Almacenamiento local | `path_provider: ^2.1.6` (solo para el CSV de instrumentación de campo, Fase 5; no hay backend) |
| Iconos de app | `flutter_launcher_icons` (genera el ícono para Android/iOS desde `assets/icon.png`) |
| Persistencia/estado | Ninguna persistente — todo vive en memoria (`setState`) dentro de un único `StatefulWidget` de pantalla |
| Datos del mapa | Estáticos, embebidos como asset JSON (`assets/campus_data.json`) |
| Herramientas auxiliares | `exportar_rutas.py` (fuente del grafo + validación + escritura directa del JSON), `analizar_csv_campo.py` (análisis de datos de campo), `tool/generar_linea_base.dart` (línea base de regresión de rutas) |

No hay backend, base de datos ni llamadas de red: la app es **100% offline** una vez instalada — incluida la tipografía, que ya no se descarga en el primer arranque.

## Estructura del proyecto

```
mapa_cusur/                          # raíz del repositorio
├── README.md                        # este archivo
└── mapa_cusur/                      # proyecto Flutter
    ├── lib/
    │   ├── main.dart                # solo runApp() + MaterialApp
    │   ├── models/                  # Nodo, Arista, GrafoCampus, Ruta (Dart puro)
    │   ├── data/                    # parseo del JSON, diccionario de nombres, repositorio
    │   ├── domain/                  # Dijkstra, interpolación, transformación geo, ubicación en ruta,
    │   │                            # validador del grafo (todo Dart puro, sin Flutter)
    │   ├── ui/
    │   │   ├── screens/             # CampusMapScreen (el StatefulWidget de la pantalla)
    │   │   ├── widgets/             # MapImageArea, PlanningPanel, AutocompleteInputField, paneles de campo
    │   │   └── painters/            # GrafoEstaticoPainter (cacheado) + RoutePainter (ruta/marcador)
    │   ├── utils/                   # geodesia (Haversine), cola de prioridad, índice espacial, cronómetro
    │   └── instrumentacion/         # sesión de campo y registro CSV (Fase 5)
    ├── test/                        # ver "Pruebas" más abajo
    ├── tool/                        # generar_linea_base.dart, hash_ruta.dart
    ├── assets/
    │   ├── campus_data.json         # grafo del campus: nodos, coordenadas, conexiones, puntos de control
    │   ├── mapa_CUSur.png           # imagen de fondo del plano del campus
    │   ├── pin.png                  # ícono de marcador (pin)
    │   ├── icon.png                 # imagen fuente del ícono de la app
    │   └── fonts/                   # Poppins (4 pesos) + OFL.txt
    ├── exportar_rutas.py            # fuente del grafo: genera y valida assets/campus_data.json
    ├── analizar_csv_campo.py        # analiza los CSV de sesiones de campo (Fase 5)
    ├── android/ ios/ macos/ linux/ web/ windows/   # proyectos de cada plataforma
    └── pubspec.yaml                 # dependencias, assets, fuentes y configuración del ícono
```

La lógica ya no vive en un único archivo: `models/` y `domain/` son Dart puro (sin `package:flutter`, probables sin `WidgetTester`); `data/` conoce el formato del JSON; `ui/` es la única capa que depende de Flutter Material.

## Cómo funciona la app

### Flujo de pantallas

La app tiene una sola pantalla (`CampusMapScreen`), dividida en dos zonas dentro de un `Stack`:

1. **Zona superior (40% de la altura)** — `MapImageArea`: el mapa interactivo (zoom/pan con `InteractiveViewer`, mínimo 1x y máximo 8x), con dos capas de dibujo independientes (ver [Renderizado del mapa](#renderizado-del-mapa)).
2. **Zona inferior (50% de la altura)** — `PlanningPanel`: campos de autocompletado para origen/destino, botón de GPS, botón "Comenzar Ruta" y el tiempo estimado de llegada.

Al tocar un punto del mapa se abre una hoja inferior que permite marcarlo como **origen** o **destino** (y, si la instrumentación de campo está activa, también **registrar un punto de verificación** ahí). En cuanto origen y destino están definidos, se calcula la ruta automáticamente.

### Datos del campus (`campus_data.json`)

Es la fuente de verdad del mapa: un JSON con 144 nodos base y cuatro secciones:

```json
{
  "coordenadas_geo": { "EntradaA": [19.72384, -103.46214], ... },
  "coordenadas_pix": { "EntradaA": [177, 102], ... },
  "conexiones":      { "EntradaA": { "Estacionamiento4": 0.73, "Gimnasio": 0.86 }, ... },
  "puntos_control":  ["Bufete_Juridico", "Edificio_F", "Edificio_L", ...]
}
```

- `coordenadas_geo`: coordenadas GPS reales (lat, lng) de cada nodo.
- `coordenadas_pix`: posición en píxeles de cada nodo sobre `mapa_CUSur.png`.
- `conexiones`: lista de adyacencia con **peso en minutos caminando** (Haversine a 4 km/h) entre nodos conectados.
- `puntos_control`: los 8 nodos usados para calibrar el modelo de transformación afín (ver más abajo).

Los nodos incluyen tanto lugares con nombre (entradas, edificios, estacionamientos, cafetería, rectoría, etc. — 45 en total) como nodos puramente estructurales que solo existen para dar forma geométrica a las rutas peatonales y no son seleccionables por el usuario. `data/diccionario_nombres.dart` mapea los IDs internos a nombres amigables y filtra cuáles aparecen en el buscador.

### Interpolación del grafo (puntos fantasma)

Antes de usarse, el grafo cargado se procesa con `interpolarGrafo()` (`lib/domain/interpolacion_nodos.dart`) — **la aportación técnica central de la tesis**. Cualquier arista de más de `kUmbralInterpolacionMetros` (8 metros, calculado con Haversine) se subdivide automáticamente en nodos intermedios ("fantasma"), de modo que:

- la línea de la ruta se vea curva/suave siguiendo el trazo real del camino, en vez de una línea recta entre dos puntos lejanos;
- el peso (tiempo) original de la arista se **reparte equitativamente** entre los sub-tramos nuevos, para que la suma total del tiempo estimado siga siendo correcta;
- el usuario pueda proyectarse sobre el sendero con precisión (ver [Ubicación GPS](#ubicación-gps-en-tiempo-real)), gracias a la densidad de nodos.

144 nodos base → **1008 nodos** tras interpolar (864 fantasma), sobre 558 aristas base. Cifras completas en `MEJORAS.md`, sección "Cifras para la tesis".

### Cálculo de ruta (Dijkstra)

`calcularRutaMasCorta()` (`lib/domain/dijkstra.dart`) ejecuta el algoritmo de **Dijkstra** sobre el grafo ya interpolado, con una cola de prioridad respaldada por un **montículo binario** (`lib/utils/priority_queue.dart`, O(log n) por inserción — antes era una lista ordenada, O(n log n)). El desempate entre caminos igualmente óptimos es **determinista** (por ID de nodo): el mismo grafo siempre produce la misma ruta, sin importar la implementación interna de la cola.

### Ubicación GPS en tiempo real

Al activar el botón de GPS, la app:

1. Verifica que el servicio de ubicación esté activo y solicita permiso si hace falta.
2. Se suscribe a un stream de posición (`LocationAccuracy.bestForNavigation`, actualiza cada 1 metro de desplazamiento).
3. **Descarta lecturas con `accuracy > 15 m`** (`lib/domain/ubicacion_en_ruta.dart`).
4. **Suaviza** las lecturas aceptadas con una media móvil de las últimas 3 (`FiltroMediaMovil`, detrás de una interfaz `FiltroPosicion` sustituible por un filtro de Kalman sin tocar el resto).
5. **Proyecta ortogonalmente** la posición suavizada sobre la arista más cercana del grafo (`proyectarSobreArista`) — ya no se redondea al nodo discreto más cercano, aunque los nodos fantasma se conservan intactos y siguen dando forma al trazo dibujado.
6. Recalcula la ruta solo si el usuario cambió de arista o se alejó más de 20 m de donde se calculó la ruta vigente (histéresis; antes se recalculaba en cada actualización).
7. Anima la cámara (`InteractiveViewer`) para centrarse en la posición proyectada.

### Renderizado del mapa

`MapImageArea` muestra `mapa_CUSur.png` dentro de un `InteractiveViewer` + `FittedBox`, y superpone **dos capas de `CustomPaint` independientes**:

1. `GrafoEstaticoPainter`: el grafo completo (nodos y aristas) en azul tenue. Cachea el `Path` resultante -se invalida solo si cambia el grafo o el zoom-, así que una actualización de GPS no lo redibuja.
2. `RoutePainter`: la ruta calculada (rojo grueso), los pines de origen/destino, y -si el GPS está activo- el marcador "Estás aquí" en la posición proyectada continua (no en la lectura cruda ni en un nodo redondeado).

Las coordenadas en píxeles se escalan con un factor fijo (`kFactorEscalaMapa = 6.0`, en `lib/domain/transformacion_geo.dart`) para ubicarlas sobre la imagen renderizada; este paso es idéntico sin importar qué modelo de transformación esté activo.

### Transformación geo→píxel: dos puntos y afín

Para ubicar una coordenada GPS sobre el mapa (cámara y marcador "Estás aquí"), hay dos modelos intercambiables (`lib/domain/transformacion_geo.dart`), seleccionables con `--dart-define=TRANSFORMACION=afin|dospuntos` (por defecto `dospuntos`):

- **`TransformacionDosPuntos`** (por defecto): el modelo original, proporcional entre dos puntos de referencia (`EntradaA` y `Edificio_M`). RMSE sobre los 144 nodos: **~17.6 m**.
- **`TransformacionAfin`**: ajuste por mínimos cuadrados de 6 parámetros sobre los 8 `puntos_control` del JSON, resuelto con ecuaciones normales (regla de Cramer, sin librería de álgebra lineal). RMSE sobre los 144 nodos: **~7.1 m**.

En modo debug, la app registra el RMSE de ambos modelos al arrancar.

## Mapa vectorial

Además del modo original sobre la imagen `mapa_CUSur.png`, la app puede dibujar el campus como **mapa vectorial**: edificios, canchas, calles, áreas verdes, lugares, entradas y estacionamientos se dibujan a partir de coordenadas, así que las líneas y los textos se mantienen nítidos a cualquier zoom y el mapa queda con el norte arriba. Es el modo activo por defecto.

- **Datos**: `assets/campus_vector.json`, todo en metros sobre una proyección local del campus (`x` hacia el este, `y` hacia el sur desde el origen de `meta.origen`). Se lee con `lib/data/mapa_vectorial_parser.dart` y se convierte a lienzo con `lib/domain/proyeccion_local.dart` (11 unidades de lienzo por metro, la escala aproximada del lienzo de la imagen, para que la ruta, los pines y el marcador se vean igual en los dos modos).
- **Dibujo**: una capa estática que se construye una sola vez (`MapaVectorialPainter`), una capa de etiquetas e íconos que mantiene los textos a tamaño constante en pantalla y evita que se encimen (`EtiquetasMapaPainter`), y encima el mismo `RoutePainter` del modo imagen. En la esquina superior derecha, un botón muestra u oculta los íconos.
- **Rutas**: el grafo, Dijkstra y la interpolación son los mismos en los dos modos; el mapa vectorial solo cambia cómo se dibuja. Los lugares que el mapa muestra y que no tenían nodo (las dos canchas de fútbol, la Cancha múltiple, los laboratorios del edificio L y el Centro de Aprendizaje Global) tienen nodos de acceso propios en `campus_data.json`. Sus `coordenadas_pix` son derivadas, no digitalizadas, y están listadas en `pixeles_derivados`, así que no entran en el cálculo del RMSE ni de la escala px/m de la transformación geo→píxel.
- **Referencia visual**: `mapa_cusur/docs/mapa_vectorial/mapa-vectorial-referencia.html` es la vista previa aprobada (colores, orden de capas, tamaños de texto); `exportar_flutter.py`, en la misma carpeta, documenta cómo se generó el JSON (depende de archivos de trabajo externos y no se ejecuta dentro del repositorio).

### De dónde salen los datos

- **OpenStreetMap**: los edificios, las canchas y las calles.
- **Trazos propios de Juan Luis Beas**: la Cafetería Pequeña, los dos edificios junto a Av. Colón (el Laboratorio de análisis clínicos y uno sin nombre todavía) y las canchas de la Cancha múltiple. En el JSON, esos edificios tienen `"origen": "trazo propio"`.
- **Áreas verdes ilustrativas**: se generaron automáticamente en los espacios libres del campus, lejos de edificios y andadores; no son un levantamiento. En la zona central (de C.A.S.A. a Rectoría) los andadores se dibujaron a mano siguiendo la disposición real: la explanada principal, las diagonales hacia el Edificio M y los andadores hacia los edificios L y C.

### Licencia de los datos (ODbL)

`assets/campus_vector.json` contiene datos derivados de OpenStreetMap y se distribuye bajo la [Open Database License (ODbL) 1.0](https://opendatacommons.org/licenses/odbl/1-0/), con la atribución **"© colaboradores de OpenStreetMap"** ([openstreetmap.org/copyright](https://www.openstreetmap.org/copyright)). La app muestra esa atribución siempre que el mapa vectorial está en pantalla. Esta licencia aplica solo a esos datos; el código de la app sigue bajo los términos indicados al final de este archivo.

### Cambiar entre el mapa vectorial y la imagen

El modo se elige con la constante `kModoMapa` en `mapa_cusur/lib/ui/mapa/lienzo_mapa.dart`:

```dart
const ModoMapa kModoMapa = ModoMapa.vectorial; // o ModoMapa.imagen
```

Con `ModoMapa.imagen`, la app vuelve a la versión documentada en la tesis: dibuja la ruta sobre `mapa_CUSur.png` con `coordenadas_pix`, no carga `campus_vector.json`, no muestra la atribución ni el botón de íconos, y el zoom máximo vuelve a ser 8x (en modo vectorial es 12x). Los cálculos de la transformación geo→píxel y de la instrumentación de campo funcionan igual en los dos modos.

## Instrumentación de campo

Para las pruebas de campo de la tesis (Fase 5), hay un modo de instrumentación completo, **apagado por defecto en cualquier build** (`--dart-define=INSTRUMENTACION=true` para activarlo):

- **Cronómetro** (`lib/utils/cronometro.dart`): mide el parseo del JSON, la interpolación del grafo y cada ejecución de Dijkstra.
- **Registro de recorrido**: un CSV local por sesión (`lib/instrumentacion/`) con datos crudos (timestamp, lat, lng, accuracy, speed, heading, dispositivo, recorrido, repetición) y columnas derivadas (posición proyectada, arista, distancia al camino, si se recalculó la ruta) — nunca sustituye lo crudo, solo lo complementa.
- **Modo punto de verificación**: compara la lectura de GPS cruda contra el píxel conocido de un nodo confirmado manualmente, con ambos modelos de transformación a la vez.
- El **dispositivo** se fija al compilar con `--dart-define=DISPOSITIVO=...` (por defecto `"sin_especificar"`); recorrido y repetición se eligen dentro de la app.

Build típica para una sesión de campo:

```bash
flutter build apk --release \
  --dart-define=INSTRUMENTACION=true \
  --dart-define=DISPOSITIVO="nombre_del_equipo"
```

## Herramientas de datos

### `exportar_rutas.py`

Es la **fuente original** del grafo del campus, y ahora también su único punto de escritura:

- Define en diccionarios de Python las coordenadas geográficas y en píxeles de cada nodo, y las conexiones entre ellos.
- Calcula el peso de cada arista con la fórmula de **Haversine** (radio 6 371 000 m, el mismo que usa la app) convertida a minutos caminando a 4 km/h.
- **Valida la integridad del grafo antes de escribir** (mismas comprobaciones que `lib/domain/validador_grafo.dart`: asimetrías, pesos no positivos o no finitos, autolazos, componentes desconectadas, píxeles duplicados) y **reporta, sin corregir nada solo**.
- Escribe **directamente** en `assets/campus_data.json` (ruta como argumento opcional, con ese valor por defecto).

```bash
cd mapa_cusur
python exportar_rutas.py                       # escribe assets/campus_data.json
python exportar_rutas.py otra/ruta/salida.json  # o a una ruta distinta
```

No requiere `matplotlib` (se quitó: era un import muerto, sin ningún uso real en el script).

### `tool/generar_linea_base.dart`

Genera la línea base de regresión de rutas: recalcula las 1980 rutas posibles entre los 45 nodos con nombre amigable y las guarda en `test/fixtures/`, para que `test/regresion_rutas_test.dart` pueda detectar si un cambio futuro altera silenciosamente el resultado de una ruta ya calculada. Importa directamente el código de producción (no mantiene una copia del algoritmo), así que nunca puede desincronizarse de él.

```bash
cd mapa_cusur
dart run tool/generar_linea_base.dart
```

### `analizar_csv_campo.py`

Consume uno o varios CSV de `instrumentacion/registro_csv_campo.dart` (ver [Instrumentación de campo](#instrumentación-de-campo)) y reporta promedios, máximos y RMSE listos para el capítulo de pruebas de la tesis. Sin dependencias externas.

```bash
python analizar_csv_campo.py archivo1.csv archivo2.csv
python analizar_csv_campo.py --directorio ruta/con/los/csv
```

## Requisitos y ejecución

```bash
cd mapa_cusur
flutter pub get
flutter run              # ejecutar en un emulador/dispositivo conectado
```

Compilar para producción:

```bash
flutter build apk        # Android
flutter build ios        # iOS (requiere macOS + Xcode)
```

Para usar el modelo de transformación afín en vez del de dos puntos:

```bash
flutter run --dart-define=TRANSFORMACION=afin
```

## Pruebas

```bash
cd mapa_cusur
flutter test
```

63 pruebas automatizadas, cubriendo Dijkstra, interpolación, el índice espacial, la transformación geo→píxel, la proyección sobre arista y el filtrado de GPS, la instrumentación de campo, y una línea base de regresión de 1980 rutas. Una prueba (`validador_grafo_test.dart`) falla **a propósito**: es la constancia, dentro de la suite, de que el grafo real todavía tiene 38 asimetrías sin resolver (ver `REPORTE_DATOS.md`) — no bloquea el resto de la suite.

## Permisos

- **Android** (`AndroidManifest.xml`): `ACCESS_FINE_LOCATION`, `ACCESS_COARSE_LOCATION`.
- **iOS** (`Info.plist`): `NSLocationWhenInUseUsageDescription` — "Esta app necesita acceso a tu ubicación para guiarte por el campus."

El nombre visible de la app es **RutaCUSur** en ambas plataformas; el identificador de aplicación es `mx.udg.cusur.rutacusur` (Android `applicationId`/`namespace`, iOS/macOS `PRODUCT_BUNDLE_IDENTIFIER`, Linux `APPLICATION_ID`). El ícono se genera desde `assets/icon.png` vía `flutter_launcher_icons`.

## Documentos del refactor

- **`mapa_cusur/MEJORAS.md`**: bitácora fase por fase de la modularización -qué cambió, por qué, y qué prueba lo respalda-, más una sección consolidada de "Cifras para la tesis".
- **`mapa_cusur/REPORTE_DATOS.md`**: inconsistencias encontradas en `campus_data.json`, con su causa raíz, el valor esperado según la fórmula documentada, y el impacto medido en rutas de cada una -incluidas las 7 correcciones ya aplicadas y las que siguen pendientes de decisión humana-.

## Limitaciones conocidas y trabajo futuro

- 38 asimetrías en `conexiones` (de las 50 originales, se corrigieron 7 + un autolazo) y 2 pares de valores distintos entre direcciones siguen sin resolverse -documentadas en `REPORTE_DATOS.md`, pendientes de una decisión humana sobre el criterio de corrección-.
- La lista de dispositivos para la instrumentación de campo (`--dart-define=DISPOSITIVO=...`) no tiene un catálogo fijo en la app a propósito: aún no está definido qué equipos se usarán en las pruebas de campo.
- No hay CI configurado.


- © 2026 Juan Luis Beas. Todos los derechos reservados. Código publicado solo como portafolio.
