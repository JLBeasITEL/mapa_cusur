"""Consume los CSV de campo generados por RegistroCsvCampo (Fase 5) y
produce promedios, máximos y RMSE listos para el capítulo de pruebas de la
tesis.

Uso:
    python analizar_csv_campo.py archivo1.csv archivo2.csv ...
    python analizar_csv_campo.py --directorio ruta/a/los/csv

No requiere dependencias externas: solo la biblioteca estándar de Python,
para poder correr en cualquier equipo sin instalar nada primero.
"""

import argparse
import csv
import glob
import os
import statistics
import sys
from collections import defaultdict

# En Windows, la consola por defecto no siempre usa UTF-8: sin esto, los
# acentos de este script se ven mal (aunque el CSV en sí esté bien).
if hasattr(sys.stdout, "reconfigure"):
    sys.stdout.reconfigure(encoding="utf-8")


def leer_filas(rutas_csv):
    filas = []
    for ruta in rutas_csv:
        with open(ruta, encoding="utf-8") as f:
            lector = csv.DictReader(f)
            for fila in lector:
                fila["_archivo"] = os.path.basename(ruta)
                filas.append(fila)
    return filas


def _flotante(valor):
    if valor is None or valor == "":
        return None
    try:
        return float(valor)
    except ValueError:
        return None


def _resumen(valores, unidad=""):
    valores = [v for v in valores if v is not None]
    if not valores:
        return "sin datos"
    rmse = (sum(v * v for v in valores) / len(valores)) ** 0.5
    return (
        f"n={len(valores)}, promedio={statistics.mean(valores):.2f}{unidad}, "
        f"máximo={max(valores):.2f}{unidad}, mínimo={min(valores):.2f}{unidad}, "
        f"RMSE={rmse:.2f}{unidad}"
    )


def analizar_lecturas_gps(filas):
    lecturas = [f for f in filas if f.get("tipo_evento") == "lectura_gps"]
    if not lecturas:
        print("No hay filas de tipo 'lectura_gps'.")
        return

    aceptadas = [f for f in lecturas if f.get("lectura_aceptada") == "True"
                 or f.get("lectura_aceptada") == "true"]
    descartadas = [f for f in lecturas if f not in aceptadas]

    print(f"\n=== Lecturas de GPS ({len(lecturas)} filas) ===")
    print(f"Aceptadas: {len(aceptadas)} ({100 * len(aceptadas) / len(lecturas):.1f}%)")
    print(f"Descartadas por precisión: {len(descartadas)} "
          f"({100 * len(descartadas) / len(lecturas):.1f}%)")

    print("Precisión (accuracy_m) — todas las lecturas: "
          + _resumen([_flotante(f.get("accuracy_m")) for f in lecturas], " m"))
    print("Velocidad (speed_mps) — todas las lecturas: "
          + _resumen([_flotante(f.get("speed_mps")) for f in lecturas], " m/s"))

    distancias_al_camino = [_flotante(f.get("distancia_al_camino_m"))
                             for f in aceptadas]
    print("Distancia al camino tras proyectar (solo aceptadas): "
          + _resumen(distancias_al_camino, " m"))

    recalculos = [f for f in aceptadas if f.get("se_recalculo_ruta") == "True"
                  or f.get("se_recalculo_ruta") == "true"]
    con_dato_recalculo = [f for f in aceptadas if f.get("se_recalculo_ruta") not in (None, "")]
    if con_dato_recalculo:
        print(f"Recálculos de ruta: {len(recalculos)} de "
              f"{len(con_dato_recalculo)} lecturas con destino activo "
              f"({100 * len(recalculos) / len(con_dato_recalculo):.1f}%)")


def analizar_puntos_verificacion(filas):
    puntos = [f for f in filas if f.get("tipo_evento") == "punto_verificacion"]
    if not puntos:
        print("\nNo hay filas de tipo 'punto_verificacion'.")
        return

    print(f"\n=== Puntos de verificación ({len(puntos)} filas) ===")
    # error_gps_m se agregó después: los CSV anteriores no la traen, y en
    # ese caso _flotante() recibe None y _resumen() reporta "sin datos".
    errores_gps = [_flotante(f.get("error_gps_m")) for f in puntos]
    errores_dospuntos = [_flotante(f.get("error_m_dospuntos")) for f in puntos]
    errores_afin = [_flotante(f.get("error_m_afin")) for f in puntos]

    print("Error del GPS (lectura vs. nodo): " + _resumen(errores_gps, " m"))
    print("Error del modelo de dos puntos:   " + _resumen(errores_dospuntos, " m"))
    print("Error del modelo afín:            " + _resumen(errores_afin, " m"))

    print("\nPor nodo verificado:")
    por_nodo = defaultdict(list)
    for f in puntos:
        nodo = f.get("nodo_verificado_manualmente", "?")
        por_nodo[nodo].append(f)
    for nodo, filas_nodo in sorted(por_nodo.items()):
        e_gps = [_flotante(f.get("error_gps_m")) for f in filas_nodo]
        e_dos = [_flotante(f.get("error_m_dospuntos")) for f in filas_nodo]
        e_afin = [_flotante(f.get("error_m_afin")) for f in filas_nodo]
        print(f"  {nodo}: GPS {_resumen(e_gps, ' m')} | "
              f"dos puntos {_resumen(e_dos, ' m')} | "
              f"afín {_resumen(e_afin, ' m')}")


def analizar_por_recorrido(filas):
    print("\n=== Desglose por recorrido/repetición/dispositivo ===")
    por_grupo = defaultdict(list)
    for f in filas:
        clave = (f.get("dispositivo", "?"), f.get("recorrido_id", "?"))
        por_grupo[clave].append(f)

    for (dispositivo, recorrido_id), filas_grupo in sorted(por_grupo.items()):
        lecturas = [f for f in filas_grupo if f.get("tipo_evento") == "lectura_gps"]
        verificaciones = [f for f in filas_grupo if f.get("tipo_evento") == "punto_verificacion"]
        print(f"  {dispositivo} / {recorrido_id}: "
              f"{len(lecturas)} lecturas, {len(verificaciones)} verificaciones "
              f"({filas_grupo[0].get('_archivo', '?')})")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("archivos", nargs="*", help="Rutas a archivos CSV")
    parser.add_argument("--directorio", help="Carpeta con CSV a analizar juntos "
                                              "(busca *.csv recursivamente)")
    args = parser.parse_args()

    rutas = list(args.archivos)
    if args.directorio:
        rutas += glob.glob(os.path.join(args.directorio, "**", "*.csv"), recursive=True)

    if not rutas:
        parser.error("Da al menos un archivo CSV o --directorio.")

    print(f"Analizando {len(rutas)} archivo(s):")
    for r in rutas:
        print(f"  - {r}")

    filas = leer_filas(rutas)
    print(f"\nTotal de filas leídas: {len(filas)}")

    analizar_lecturas_gps(filas)
    analizar_puntos_verificacion(filas)
    analizar_por_recorrido(filas)


if __name__ == "__main__":
    main()
