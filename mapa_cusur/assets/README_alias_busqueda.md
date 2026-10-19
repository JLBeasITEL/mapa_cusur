# Alias de búsqueda (`alias_busqueda.json`)

Nombres coloquiales con los que también se encuentra un lugar en la barra
de búsqueda (por ejemplo, un apodo o una abreviatura). **No se muestran como
nombre del lugar**: el resultado siempre aparece con su nombre oficial y,
debajo, en texto pequeño, "coincide con: <alias>".

> TODO(JuanLuis): llenar los alias de `alias_busqueda.json`. Hoy todas las
> listas están vacías (solo funciona "Gimnasio", que está en
> `nombresAlternativos`).

## Formato

Un objeto JSON. Cada clave es el **ID del nodo** (el de
`lib/data/diccionario_nombres.dart`) y su valor es una lista de alias:

```json
{
  "CASA": ["alias uno", "alias dos"],
  "Rectoria": []
}
```

- Escribe los alias como se leen; al buscar no importan acentos,
  mayúsculas, puntuación ni espacios de más.
- Una lista vacía (`[]`) significa "sin alias".
- No cambies ni agregues claves: un ID que no sea de un lugar buscable se
  ignora (con una advertencia en la consola en modo debug).
- "Gimnasio" ya es alias del Laboratorio de técnicas deportivas y de
  rescate en `nombresAlternativos` (Dart); no hace falta repetirlo aquí
  (si se repite, cuenta una sola vez).
- Si el archivo falta, está vacío o es JSON inválido, la app funciona igual,
  sin estos alias.

## IDs y nombre oficial

| ID | Nombre que se muestra |
|---|---|
| `EntradaA` | Entrada Sur |
| `EntradaB` | Entrada Principal |
| `EntradaC` | Entrada Este |
| `Estacionamiento1` | Estacionamiento 1 |
| `Estacionamiento2` | Estacionamiento 2 |
| `Estacionamiento3` | Estacionamiento 3 |
| `Estacionamiento4` | Estacionamiento 4 |
| `Estacionamiento5` | Estacionamiento 5 |
| `Edificio_B` | Edificio B |
| `Edificio_C` | Edificio C |
| `Edificio_F` | Edificio F |
| `Edificio_G` | Edificio G |
| `Edificio_H` | Edificio H |
| `Edificio_I` | Edificio I |
| `Edificio_J` | Edificio J |
| `Edificio_L` | Edificio L |
| `Edificio_M` | Edificio M |
| `Edificio_N` | Edificio N |
| `Edificio_P` | Edificio P |
| `Edificio_Q` | Edificio Q |
| `Edificio_R` | Edificio R |
| `Edificio_S` | Edificio S |
| `Edificio_T` | Edificio T |
| `Edificio_U` | Edificio U |
| `Edificio_V` | Edificio V |
| `Edificio_W` | Edificio W |
| `Edificio_X` | Edificio X |
| `Edificio_Y` | Edificio Y |
| `Edificio_Z` | Edificio Z |
| `C_Acuatico` | Centro Acuático |
| `Gimnasio` | Laboratorio de técnicas deportivas y de rescate |
| `CASA` | C.A.S.A. (Biblioteca) |
| `Cafeteria` | Cafetería Pequeña |
| `Cafeteria_P` | Cafetería Principal |
| `Rectoria` | Rectoría |
| `Veterinaria` | Hospital Veterinario |
| `Clinica_Escuela` | Clínica Escuela |
| `Bufete_Juridico` | Bufete Jurídico |
| `Auditorio_Ochoa` | Auditorio Antonio González Ochoa |
| `Auditorio_Zinser` | Auditorio Adolfo Aguilar Zínser |
| `Auditorio_CASA` | Auditorio C.A.S.A. |
| `Sala_de_Gobierno` | Sala de Gobierno |
| `CMID` | C.M.I.D. |
| `Radio_UDG` | Radio UDG |
| `Proteccion_Civil` | Protección Civil |
| `Cancha_Futbol_Central` | Cancha de fútbol central |
| `Cancha_Futbol_Norte` | Cancha de fútbol norte |
| `Cancha_Multiple` | Cancha múltiple |
| `Lab_Programacion` | Laboratorio de Programación |
| `Lab_Electronica` | Laboratorio de Electrónica |
| `Lab_Periodismo` | Laboratorio de Periodismo |
| `Centro_Aprendizaje_Global` | Centro de Aprendizaje Global |
