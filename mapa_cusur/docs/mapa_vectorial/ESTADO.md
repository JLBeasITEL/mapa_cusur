# Estado del mapa vectorial

Estado de la rama `feature/mapa-vectorial` al 17 de octubre de 2026, para retomar el trabajo en una sesión nueva.

## Resumen

`feature/mapa-vectorial` sustituye la imagen `assets/mapa_CUSur.png` por un **mapa vectorial** dibujado por la app a partir de `assets/campus_vector.json`: edificios, canchas, calles, áreas verdes, lugares, entradas y estacionamientos, todo en metros. La ruta, Dijkstra, la interpolación y la instrumentación son las mismas en los dos modos; solo cambia cómo se dibuja el mapa.

- **Base:** la rama sale de `d0586da` ("Avisar con un diálogo al llegar al destino durante la navegación"), la versión instalada en las pruebas de campo del 8 de octubre de 2026, marcada con la etiqueta anotada **`v-pruebas-campo`**. La etiqueta `v1.0-tesis` (`9f3360e`) no se movió.
- **Cambiar de modo:** constante `kModoMapa` en `mapa_cusur/lib/ui/mapa/lienzo_mapa.dart`:

  ```dart
  const ModoMapa kModoMapa = ModoMapa.vectorial; // o ModoMapa.imagen
  ```

  Con `ModoMapa.imagen` la app vuelve a la versión documentada en la tesis: dibuja sobre `mapa_CUSur.png` con `coordenadas_pix`, no carga `campus_vector.json`, no muestra la atribución ni el botón de íconos, y el zoom máximo vuelve a ser ×8.
- **Referencia visual aprobada:** `docs/mapa_vectorial/mapa-vectorial-referencia.html`. `exportar_flutter.py`, en la misma carpeta, solo documenta cómo se generó el JSON.

## Calibración congelada (`assets/calibracion_campo.json`)

**No se edita.** Es una copia byte por byte del `assets/campus_data.json` de la etiqueta `v-pruebas-campo` (blob `f61d201`).

- **Para qué sirve:** la Fase 6c cambia el grafo de navegación: mueve nodos digitalizados y quita aristas entre ellos. La escala px/m es la mediana sobre esas aristas, así que esos cambios moverían las cifras de la tesis. Por ejemplo, el Bloque 1 solo ya daba 1.780 px/m.
- **Quién la usa:** la app (`CampusRepository.cargarCalibracion`, `kRutaCalibracion`) calcula con este archivo la afín, la de dos puntos, la escala px/m y el RMSE. La instrumentación de campo y la posición GPS en modo imagen usan esas transformaciones.
- **Cifras:** 1.772 px/m, afín 12.53 px (7.07 m) y dos puntos 31.15 px (17.58 m) sobre 144 nodos digitalizados, con 38 aristas asimétricas.
- **La navegación** usa `campus_data.json`.
- **Punto de verificación de la instrumentación:** compara contra el nodo del grafo de navegación. `transformacion_geo_test.dart` exige que cada nodo de `campus_data.json` con píxel digitalizado sea idéntico al de la calibración. Un nodo digitalizado que se mueve pasa a `pixeles_derivados`.

## Commits de la rama (desde `d0586da`)

| Commit | Qué hace |
|---|---|
| `3311ee0` | Agrega `assets/campus_vector.json` (registrado en `pubspec.yaml`) y copia la referencia HTML y `exportar_flutter.py` a `docs/mapa_vectorial/`. |
| `2ff3184` | Migración automática de Flutter 3.47.6: `analysis_options.yaml` excluye `build/` y las carpetas de plataforma. |
| `9c3aa16` | Modelo inmutable (`models/mapa_vectorial.dart`), parser y `CampusRepository.cargarMapaVectorial`. |
| `113d0b2` | `domain/proyeccion_local.dart`: lat/lng → metros → lienzo con `kEscalaVectorial = 11`. |
| `2d912a3` | `ModoMapa`/`kModoMapa` y `LienzoMapa` (`LienzoImagen` envuelve sin cambios el cálculo de siempre; `LienzoVectorial` ubica por lat/lng). |
| `d1ad39b` | Capa estática: `GeometriaMapaVectorial` (Path construidos una vez) y `MapaVectorialPainter`. |
| `f489485` | Capa de etiquetas e íconos (`EtiquetasMapaPainter`, íconos Material rounded en un mapa const). |
| `79ec704` | Integración en `MapImageArea`, atribución de la ODbL y `kModoMapa = vectorial`. |
| `3abda1a` | Las insignias crecen con el zoom (5.5 px a ×1, tope de 22 px). |
| `d88eaac` | Botón para mostrar u ocultar los íconos. |
| `601e518` | Detección de colisiones para los nombres de calles. |
| `6a79d07` | Atribución en la esquina superior izquierda, 9 px. |
| `e29fc4b` | Letras de edificio en el polo de inaccesibilidad (polylabel). |
| `de986b0` | Umbral de textos largos: 3.1 px/m en vez de zoom ×1.8. |
| `0842a30` | Los nombres largos que chocan con algo de mayor prioridad se ocultan. |
| `4e1f139` | Subtítulos solo con el 75 % de cobertura del edificio; zoom máximo ×12 en modo vectorial. |
| `d282bfe` | Nombres de las cafeterías corregidos (Fase 6a). |
| `5ee5593` | Seis nodos de acceso nuevos: canchas de fútbol central y norte, Cancha múltiple y los tres laboratorios del edificio L. |
| `f7a6b4a` | Lista `pixeles_derivados`: esos nodos no entran en la escala ni en el RMSE de la tesis. |
| `826e6ae` | Insignias de lugares y canchas siempre visibles, al 80 %. |
| `7398562` | Letras siempre visibles, dentro del contorno y sin tapar íconos (bloque A). |
| `58ec3d5` | Nodo de acceso del Centro de Aprendizaje Global (bloque B). |
| `398f112` | El texto de cada entrada busca un lado libre; resuelve "Entrada Este" sobre la R. |
| `6829d28` | El nodo `Gimnasio` se muestra como "Laboratorio de técnicas deportivas y de rescate" y se encuentra por ambos nombres. |
| `d6ccb9b` | Herramienta del reporte de aristas que cruzan edificios (Fase 6c). |
| `c9871c3` | Sección "Mapa vectorial" en el README de la raíz (Fase 5). |
| `d35c0e0` | "Radio UDG" pasa a su edificio en la columna de Av. Colón (Fase 6b). |
| `58498e9` | Versión de la app 1.1.0+3. |

## Decisiones tomadas

**Mapa**
- **Norte arriba**, como la referencia HTML. El modo imagen conserva su orientación (norte a la derecha).
- **Escala:** 11 unidades de lienzo por metro, la escala aproximada del lienzo de la imagen (10.4–12.0 según el par de nodos), para que la ruta, los pines y el marcador se vean igual en los dos modos.
- **Zoom máximo:** ×12 en modo vectorial y ×8 en modo imagen.
- **Unidad Deportiva:** se queda en la orilla del mapa. No se dibuja la etiqueta de una zona cuya posición cae fuera de `meta.limites`.
- **Parque público:** el polígono `verde` del HTML (al norte, fuera del campus) se omite.
- **Atribución ODbL:** "© colaboradores de OpenStreetMap", arriba a la izquierda, 9 px, fondo blanco al 70 %, esquinas de 4 px. Queda fuera del `InteractiveViewer` y no captura toques.
- **Botón de capas:** `Icons.layers_rounded`, arriba a la derecha, solo en modo vectorial. Con los íconos ocultos solo quedan las insignias de las entradas. En modo instrumentación baja a `top: 56` para no quedar bajo el botón de ciencia.

**Etiquetas e insignias**
- **Umbral de textos largos:** 3.1 px de pantalla por metro, lo que daba ×1.8 en la caja del HTML; en un panel de 412 × 360 equivale a ×4. Las calles y las insignias de estacionamientos se ven siempre, como en el HTML.
- **Insignias:** radio = mín(5.5 px × zoom, 22 px); el ícono y el borde escalan igual. Las entradas usan un factor de 1.25, también sobre el tope. Lugares y canchas: siempre visibles, al 80 %.
- **Texto bajo una insignia:** a (radio actual + 8 px).
- **Letras de edificio:** van en el centro del círculo libre más grande del edificio (polylabel con precisión de 0.5 m). Ese círculo excluye las insignias de lugares y la propia del edificio, con su radio a ×1 más 1 m, y se recalcula si cambia el viewport.
  - El tamaño se calcula para que la diagonal de la caja de la letra (medida con TextPainter) quepa en el 90 % del diámetro, con tope de 15 px y sin mínimo: se dibujan siempre.
  - `kPosicionLetraManual` existe, pero está vacío.
- **Subtítulos:** solo cuando su edificio cubre al menos el 75 % de la vista; van anclados a la letra.
- **Prioridades de colisión**, en espacio de pantalla con 4 px de margen: entradas, letras, insignias, nombres largos y calles.
  - Los nombres largos que chocan se ocultan por bloque, y un texto no choca con su propia insignia ni con su propia letra.
  - Las calles prueban la posición del JSON y luego el 30, 70, 20 y 80 % de su vialidad.
  - El texto de una entrada prueba abajo, derecha, izquierda y arriba; de respaldo, las diagonales y luego los mismos lados a +1 y +2 alturas de texto. Siempre queda dentro del mapa.

**Grafo**
- **Cafeterías:** `Cafeteria` se muestra como "Cafetería Pequeña" y `Cafeteria_P` como "Cafetería Principal". La línea base solo cambió esas etiquetas.
- **Gimnasio:** el nodo `Gimnasio` se muestra como "Laboratorio de técnicas deportivas y de rescate" y "Gimnasio" queda como nombre de búsqueda (`nombresAlternativos`).
- **Nodos nuevos como hojas, con una sola arista** hacia el nodo estructural más cercano cuyo segmento no cruza edificios. El nodo va en el punto de acceso: la orilla del polígono que da al andador, no el centro.
- **Pesos:** `round(distancia Haversine en km ÷ 0.0667, 2)`, es decir, minutos a 4 km/h con radio de 6371 km (la fórmula `km_a_minutos` de `exportar_rutas.py`). Coincide con 555 de las 558 aristas originales; las otras 3 son asimetrías ya documentadas.
- **`coordenadas_pix` de los nodos nuevos:** derivadas, no digitalizadas. Se calculan como el píxel digitalizado del vecino más el desplazamiento de `TransformacionAfin.aPixeles` entre ambos nodos. Están en la lista `pixeles_derivados` y no entran en la escala ni en el RMSE, que siguen en 1.772 px/m, afín 12.53 px (7.07 m) y dos puntos 31.15 px (17.58 m) sobre los 144 nodos digitalizados.
- **Radio UDG:** el nodo viejo `RadioUDG` (junto a C.A.S.A.) se conserva sin nombre visible como cruce del andador, porque conecta L5 y L6 con el Auditorio C.A.S.A. El nodo nuevo `Radio_UDG` está en el acceso noroeste del edificio real, hacia `P1`.

**Proyecto**
- **Versión:** 1.1.0+3.
- **Flutter:** fijado en 3.47.6.

## Pendientes

| Pendiente | Estado |
|---|---|
| Bloque A: letras de edificio (P y L) | **Hecho** (`7398562`), sin ajustes manuales. La H mide 3.2 px a ×1 (< 5 px) y se dibuja igual. |
| Bloque B: nodo Centro de Aprendizaje Global | **Hecho** (`58ec3d5`). |
| Nodos de canchas y laboratorios (pasos 2a/2b) | **Hecho** (`5ee5593`, `f7a6b4a`, `826e6ae`). |
| "Entrada Este" sobre la letra R | **Hecho** (`398f112`). A ×1 su texto queda unos 34 px debajo del ícono; falta verlo en el teléfono. |
| Gimnasio vs. Laboratorio de técnicas deportivas y de rescate | **Hecho** (`6829d28`); Juan Luis confirmó que son el mismo lugar. Si se prefiere el nombre corto "Laboratorio de técnicas deportivas", es cambiar un texto. |
| Fase 6b (Radio UDG) | **Hecho** (`d35c0e0`). Falta confirmar la entrada: noroeste (`P1`, aplicada) u oeste (`V2`, 18.2 m, mismo peso). |
| Fase 6c (aristas que cruzan edificios) | **En curso, por bloques.** El reporte (`d6ccb9b`) dio 170 cruces en 158 aristas y 27 edificios, 1976.9 m de cruce en total. Juan Luis trazó los andadores reales y decidió arista por arista; sus archivos están en `docs/mapa_vectorial/fase6c/` (`trazo_usuario.json`, `decisiones_aristas.csv`). Cada bloque: propuesta con `bloqueN.json` y `propuesta_bloqueN.png`, aprobación, commit del bloque y commit aparte de la línea base. **Bloques 1 (Cafetería Pequeña) y 2 (cruces de M, B, Rectoría y Auditorio): hechos.** Bloques 3 a 5: pendientes. El Edificio P del mapa vectorial es un solo polígono que incluye Q y la Clínica Escuela. El polígono 35, sin nombre, tiene el nodo `Edificio_I` justo al norte. |
| Mejora de la búsqueda por texto | **No iniciada**; el prompt llega en la sesión nueva. |
| Fase 5 (README) | **Sección agregada** (`c9871c3`). **Pendiente de decisión:** 8 partes del README describen todavía solo el modo imagen o cifras viejas (144/45 nodos, 1980 rutas, 63 pruebas, zoom 8x, painters). También falta decidir cómo presentar las cifras de la tesis frente a las actuales. Además, el README cita `MEJORAS.md` y `REPORTE_DATOS.md`, que el `.gitignore` excluye. |
| Medición en modo perfil | **Descartada** por Juan Luis. |
| Carpeta `mapa_cusur/mapa_vectorial/` sin rastrear | **Cerrado.** La borró la sesión anterior con autorización de Juan Luis; sus archivos ya estaban copiados a `assets/` y `docs/`. |

Para regenerar el reporte de la Fase 6c:

```bash
cd mapa_cusur
REPORTE_ARISTAS=1 flutter test test/reporte_aristas_edificios_test.dart
# escribe build/reporte_aristas_edificios.csv (o REPORTE_ARISTAS=<ruta del csv>)
python tool/graficar_aristas_edificios.py
# escribe build/aristas_por_edificio/: 00_vista_general.png, un NN_<edificio>.png
# por edificio, resumen.csv, resumen.md y aristas_por_edificio.csv (requiere matplotlib)
```

El script recalcula los cruces con la misma fórmula que el reporte en Dart y se detiene si no coinciden con el CSV. Separa por polígono los edificios sin nombre, que el CSV junta en "(sin nombre)".

Para proponer y aplicar un bloque:

```bash
dart run tool/cambios_grafo.dart docs/mapa_vectorial/fase6c/bloqueN.json
# sin --aplicar: escribe build/fase6c/campus_data_bloqueN.json y build/fase6c/bloqueN_informe.json
# (regresión, R1-R3, validador y cifras de la calibración), sin tocar assets/
python tool/graficar_propuesta_grafo.py build/fase6c/bloqueN_informe.json docs/mapa_vectorial/fase6c/propuesta_bloqueN.png
dart run tool/cambios_grafo.dart docs/mapa_vectorial/fase6c/bloqueN.json --aplicar   # tras la aprobación
dart run tool/generar_linea_base.dart                                               # commit aparte
```

`cambios_grafo.dart` calcula los pesos con `round(km de Haversine / 0.0667, 2)` y los píxeles derivados con `TransformacionAfin.aPixeles`, a partir del nodo digitalizado más cercano. Pone las aristas en ambos sentidos.

**R1, R2 y R3** son las rutas de ejemplo de `mapa-vectorial-referencia.html`. Se miden de nodo a nodo, no desde la coordenada GPS de inicio de las pruebas de campo:
- R1: `EntradaB` → `Edificio_M`
- R2: `Rectoria` → `Auditorio_CASA`
- R3: `CMID` → `Auditorio_Zinser`

El informe de cada bloque da la secuencia de nodos antes y después de dos formas:
- **Como la calcula la app:** Dijkstra sobre el grafo interpolado. Es la definición de la línea base.
- **Sobre el grafo sin interpolar.**

Las dos difieren porque `interpolarGrafo` subdivide las aristas de más de 8 m con tramos en ambos sentidos, aunque en el JSON tengan uno solo. Así lo hacía ya la versión de la tesis.
- **R1 en la app:** 5.25 min, por Ce4–C1–C2–C3–CR–Rectoria–B2–B4–M5–M3–M4. Usa `B4→B2` en sentido contrario.
- **R1 sin interpolar:** 5.45 min, por Q4–CF3–Cafeteria_P–CF4–Edificio_R–R3–B1–B3–M8–M2. Es la polilínea R1 de la referencia HTML (363 m).

| Bloque | Commit | Cambio | Rutas |
|---|---|---|---|
| 1. Cafetería Pequeña | `8b18981` (línea base: `cbbaf89`) | `Cafeteria` pasa a la fachada sureste de su edificio como destino sin paso (`Cafeteria`–`CP1`). `CP1`, `CP2` y `CP3` siguen el trazo al norte (a SP3) y al oeste (a F7) de C.A.S.A. Se quitan las 4 aristas que cruzaban C.A.S.A. | 142 pares más largos: 102 de la cafetería (+0.15 a +1.01 min) y 40 del Centro de Aprendizaje Global (hasta +0.55). R1-R3 sin cambio. Asimétricas: 38 → 36. |
| 2. Cruces de M, B, Rectoría y Auditorio | (este; línea base: commit siguiente) | Se quitan B3–M8, Edificio_M–M2, M1–M2, M2–M8, B2–RB y M10–M9. **Se elimina M2**, que quedaba como punta muerta dentro del Edificio M, junto con M2–M4. Nodos nuevos sobre el trazo: `M11` y `M12` (esquinas noroeste y noreste de M), `M13` (lado oeste de M) y `M14` (extremo norte del andador entre la Cancha múltiple y el Auditorio). M8 se llega por M12–M11, y M9 por M14–M11, en lugar de M10–M9. `RB1` rodea la Rectoría por el norte (B2–RB1–RB). Edificio_M–M13 da acceso desde el norte. M1 queda como punta muerta (se revisa en el Bloque 5). | 234 pares más largos, hasta +0.77 min (Hospital Veterinario → Centro de Aprendizaje Global). R1-R3 sin cambio en la app. Sin interpolar, R1 pasa de 5.45 a 6.07 min. Asimétricas: 36 → 35 (`B3→M8`). |

**M2 sigue en `assets/calibracion_campo.json`.** Es el nodo del segmento M2–M8 donde la tesis reporta el desfase de 8 a 13 m. La tesis no cambia; solo el grafo de navegación deja de tenerlo.

## Reglas de trabajo

- **Fases con autorización** y un commit por cambio, con mensaje en español en imperativo. Al terminar se corren `flutter analyze` y `flutter test`, y se espera la autorización de la siguiente fase.
- **La tesis manda.** No se tocan la tesis ni los documentos ligados a ella, ni `TransformacionDosPuntos`, `TransformacionAfin`, `pixelesACanvas`, `kFactorEscalaMapa`, el cálculo de errores de representación ni `lib/instrumentacion/`. El modo imagen debe comportarse exactamente como la versión de la tesis.
- **No inventar datos.** Si falta una coordenada, un nombre o una decisión, se pregunta.
- **Sin paquetes nuevos.** La app sigue 100 % offline.
- **Cambios al grafo:** primero una propuesta con imagen (PNG) y, solo después de la aprobación, el cambio en `campus_data.json`. Las rutas existentes de la línea base (originalmente los 1980 pares; hoy 2652) **no pueden cambiar sin autorización**. Si cambian, se muestra qué pares y cuánto, y la línea base se actualiza en el mismo commit, explicando el motivo.
- **Si una prueba existente falla,** se explica por qué antes de modificarla.
- **Sin push ni merge** a `refactor/pre-defensa` o `main` sin que Juan Luis lo pida.

## Cómo compilar

`Documentos` está sincronizado con OneDrive, que bloquea los borrados en `build/`. Por eso las APK se compilan en el **worktree `C:\dev\rutacusur-vectorial`**:

```powershell
git -C C:\dev\rutacusur-vectorial checkout --detach feature/mapa-vectorial
cd C:\dev\rutacusur-vectorial\mapa_cusur
flutter pub get
flutter build apk --release
# APK: C:\dev\rutacusur-vectorial\mapa_cusur\build\app\outputs\flutter-apk\app-release.apk
```

Flutter está fijado en **3.47.6** en `C:\src\flutter` (checkout de la etiqueta con git, sin `flutter upgrade`). En `Documentos`, si `flutter test` no puede borrar `build\unit_test_assets`, se borra a mano y se repite.

## Línea base de pruebas (18 de octubre de 2026, después del Bloque 1 de la Fase 6c)

- `flutter analyze`: sin problemas.
- `flutter test`: **207 pasan, 1 omitida y 1 falla**.
  - **Omitida:** el reporte de la Fase 6c, que corre solo bajo demanda.
  - **Falla (esperada):** `validador_grafo_test.dart`, "el grafo real del campus NO pasa la validación…". Es la constancia de las aristas asimétricas sin resolver. Las pruebas que fijan las cifras pasan: 38 en la calibración congelada y 36 en el grafo actual.
- Línea base de rutas: 2652 pares entre 52 nodos con nombre, todos alcanzables. Grafo: 155 nodos y 578 aristas antes de interpolar; 1016 nodos y 2330 aristas después.
