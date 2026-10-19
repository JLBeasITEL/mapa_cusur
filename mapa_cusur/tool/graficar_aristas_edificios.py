"""Fase 6c: un PNG por edificio con las aristas del grafo que lo cruzan.

Agrupa por edificio los cruces de build/reporte_aristas_edificios.csv (el
reporte que escribe test/reporte_aristas_edificios_test.dart) para que Juan
Luis conteste por edificio si se puede atravesar caminando (pasillo real) o
no (corte de esquina). No modifica el grafo ni el mapa: solo lee
assets/campus_data.json y assets/campus_vector.json y escribe en la carpeta
de salida:

  00_vista_general.png       el campus con los edificios cruzados numerados
  NN_<edificio>.png          el edificio, sus aristas resaltadas y numeradas
  resumen.csv / resumen.md   edificio, aristas, metros de cruce y la columna
                             vacía para la respuesta
  aristas_por_edificio.csv   el detalle de cada número de cada imagen

Los cruces se recalculan aquí con la misma fórmula que `largoDentro` del
reporte en Dart (proyección local de `meta`, regla par-impar sobre todos los
anillos) para saber qué tramo dibujar, y se cotejan contra el CSV: si un
cruce o una longitud no coinciden, el script se detiene. Los edificios sin
nombre, que el CSV junta en "(sin nombre)", se separan aquí por polígono.

Uso, desde mapa_cusur/ (requiere matplotlib):
  REPORTE_ARISTAS=1 flutter test test/reporte_aristas_edificios_test.dart
  python tool/graficar_aristas_edificios.py [--csv build/reporte_aristas_edificios.csv]
                                            [--salida build/aristas_por_edificio]
"""

import argparse
import csv
import json
import math
import re
import unicodedata
from collections import defaultdict
from pathlib import Path

import matplotlib

matplotlib.use("Agg")
import matplotlib.patheffects as pe  # noqa: E402
import matplotlib.pyplot as plt  # noqa: E402
from matplotlib.patches import PathPatch  # noqa: E402
from matplotlib.path import Path as MplPath  # noqa: E402

UMBRAL_ROCE = 0.05  # metros; igual que el reporte en Dart

COLORES = [
    "#1f77b4", "#d62728", "#2ca02c", "#9467bd", "#8c564b",
    "#e377c2", "#17becf", "#ff7f0e", "#393b79", "#637939",
]
HALO = [pe.withStroke(linewidth=2.5, foreground="white")]


# --------------------------------------------------------------- geometría

def dentro(p, anillos):
    """Punto en polígono, par-impar sobre todos los anillos (como `_dentro`)."""
    x, y = p
    res = False
    for anillo in anillos:
        j = len(anillo) - 1
        for i in range(len(anillo)):
            ax, ay = anillo[i]
            bx, by = anillo[j]
            if (ay > y) != (by > y) and x < (bx - ax) * (y - ay) / (by - ay) + ax:
                res = not res
            j = i
    return res


def tramos_dentro(p, q, anillos):
    """Intervalos [t0, t1] del segmento p-q que quedan dentro (`largoDentro`)."""
    dx, dy = q[0] - p[0], q[1] - p[1]
    ts = [0.0, 1.0]
    for anillo in anillos:
        for i in range(len(anillo) - 1):
            a = anillo[i]
            ex, ey = anillo[i + 1][0] - a[0], anillo[i + 1][1] - a[1]
            den = dx * ey - dy * ex
            if abs(den) < 1e-12:
                continue
            wx, wy = a[0] - p[0], a[1] - p[1]
            t = (wx * ey - wy * ex) / den
            u = (wx * dy - wy * dx) / den
            if 0 < t < 1 and 0 <= u <= 1:
                ts.append(t)
    ts.sort()
    tramos = []
    for t0, t1 in zip(ts, ts[1:]):
        m = (t0 + t1) / 2
        if t1 > t0 and dentro((p[0] + dx * m, p[1] + dy * m), anillos):
            if tramos and abs(tramos[-1][1] - t0) < 1e-12:
                tramos[-1][1] = t1
            else:
                tramos.append([t0, t1])
    return tramos


def area_firmada(anillo):
    return sum(a[0] * b[1] - b[0] * a[1] for a, b in zip(anillo, anillo[1:])) / 2


def path_poligono(anillos):
    """Path compuesto con los huecos en sentido contrario al exterior."""
    verts, codes = [], []
    signo = None
    for anillo in anillos:
        pts = list(anillo)
        s = area_firmada(pts)
        if signo is None:
            signo = s >= 0
        elif (s >= 0) == signo:
            pts = pts[::-1]
        verts += pts
        codes += [MplPath.MOVETO] + [MplPath.LINETO] * (len(pts) - 2) + [MplPath.CLOSEPOLY]
    return MplPath(verts, codes)


# ------------------------------------------------------------------- datos

def nombre_edificio(e):
    if e.get("nombre"):
        return e["nombre"]
    if e.get("letra"):
        return f"Edificio {e['letra']}"
    return "(sin nombre)"


def slug(texto):
    t = unicodedata.normalize("NFKD", texto).encode("ascii", "ignore").decode()
    return re.sub(r"[^A-Za-z0-9]+", "_", t).strip("_")


def cargar(raiz):
    grafo = json.loads((raiz / "assets/campus_data.json").read_text(encoding="utf-8"))
    mapa = json.loads((raiz / "assets/campus_vector.json").read_text(encoding="utf-8"))
    meta = mapa["meta"]
    lat0, lng0 = meta["origen"]["lat"], meta["origen"]["lng"]
    mlat, mlng = meta["metros_por_grado"]["lat"], meta["metros_por_grado"]["lng"]
    nodos = {
        i: ((lng - lng0) * mlng, -(lat - lat0) * mlat)
        for i, (lat, lng) in grafo["coordenadas_geo"].items()
    }
    pares = set()
    for o, vecinos in grafo["conexiones"].items():
        for d in vecinos:
            if o != d:
                pares.add(tuple(sorted((o, d))))
    return nodos, sorted(pares), mapa


def calcular_cruces(nodos, pares, edificios):
    cruces = []
    for a, b in pares:
        p, q = nodos[a], nodos[b]
        largo = math.dist(p, q)
        for idx, e in enumerate(edificios):
            tramos = tramos_dentro(p, q, e["anillos"])
            metros = sum(t1 - t0 for t0, t1 in tramos) * largo
            if metros < UMBRAL_ROCE:
                continue
            cruces.append({
                "a": a, "b": b, "edificio": idx, "tramos": tramos,
                "metros_dentro": metros, "metros_arista": largo,
                "a_dentro": dentro(p, e["anillos"]),
                "b_dentro": dentro(q, e["anillos"]),
            })
    return cruces


def cotejar(cruces, edificios, ruta_csv):
    filas = list(csv.DictReader(ruta_csv.open(encoding="utf-8")))
    del_csv = defaultdict(list)
    for f in filas:
        del_csv[(f["nodo_a"], f["nodo_b"], f["edificio"])].append(float(f["metros_dentro"]))
    propios = defaultdict(list)
    for c in cruces:
        propios[(c["a"], c["b"], nombre_edificio(edificios[c["edificio"]]))].append(
            round(c["metros_dentro"], 1))
    errores = []
    for k in set(del_csv) | set(propios):
        if sorted(del_csv.get(k, [])) != sorted(propios.get(k, [])):
            errores.append(f"{k}: CSV {del_csv.get(k)} vs. script {propios.get(k)}")
    if errores:
        raise SystemExit("El recálculo no coincide con el CSV:\n  " + "\n  ".join(errores))
    nombres = {}
    for f in filas:
        nombres[f["nodo_a"]] = f["nombre_a"]
        nombres[f["nodo_b"]] = f["nombre_b"]
    return len(filas), nombres


# ----------------------------------------------------------------- dibujo

def dibujar_contexto(ax, mapa, nodos, pares, excluir=None):
    ax.add_patch(plt.Polygon(mapa["campus"], closed=True, fc="#f7f7f2", ec="#bbbbbb", lw=1, zorder=0))
    for anillo in mapa["areas_verdes"]:
        ax.add_patch(plt.Polygon(anillo, closed=True, fc="#dcefd2", ec="none", zorder=1))
    for c in mapa["canchas_futbol"] + mapa["canchas"]:
        ax.add_patch(plt.Polygon(c["poligono"], closed=True, fc="#cfe5c4", ec="#9fbf93", lw=0.6, zorder=1))
    for v in mapa["vialidades"]:
        xs, ys = zip(*v["linea"])
        ax.plot(xs, ys, color="#e3e3e3", lw=3 if v["tipo"] == "calle" else 1.5,
                solid_capstyle="round", zorder=1)
    for idx, e in enumerate(mapa["edificios"]):
        if idx == excluir:
            continue
        ax.add_patch(PathPatch(path_poligono(e["anillos"]), fc="#e2e2e2", ec="#9a9a9a", lw=0.8, zorder=2))
    for a, b in pares:
        (x1, y1), (x2, y2) = nodos[a], nodos[b]
        ax.plot([x1, x2], [y1, y2], color="#a8a8a8", lw=0.7, zorder=3)
    xs, ys = zip(*nodos.values())
    ax.scatter(xs, ys, s=6, color="#8a8a8a", zorder=4)


def ajustar_ventana(ax, xmin, xmax, ymin, ymax, aspecto):
    ancho, alto = xmax - xmin, ymax - ymin
    if ancho / alto < aspecto:
        extra = (alto * aspecto - ancho) / 2
        xmin, xmax = xmin - extra, xmax + extra
    else:
        extra = (ancho / aspecto - alto) / 2
        ymin, ymax = ymin - extra, ymax + extra
    ax.set_xlim(xmin, xmax)
    ax.set_ylim(ymax, ymin)  # y crece al sur: norte arriba
    ax.set_aspect("equal", adjustable="box")
    ax.set_xticks([])
    ax.set_yticks([])
    return xmin, xmax, ymin, ymax


def escala_y_norte(ax, xmin, xmax, ymin, ymax):
    ancho = xmax - xmin
    largo = next(n for n in (5, 10, 20, 25, 50, 100, 200) if n >= ancho / 6)
    x0, y0 = xmin + ancho * 0.04, ymax - (ymax - ymin) * 0.04
    ax.plot([x0, x0 + largo], [y0, y0], color="black", lw=3, zorder=20, solid_capstyle="butt")
    ax.text(x0 + largo / 2, y0 - (ymax - ymin) * 0.015, f"{largo} m", ha="center",
            va="bottom", fontsize=9, zorder=20, path_effects=HALO)
    ax.text(xmin + ancho * 0.04, ymin + (ymax - ymin) * 0.05, "N ↑", fontsize=12,
            fontweight="bold", va="center", zorder=20, path_effects=HALO)


def punto(nodos, c, t):
    (x1, y1), (x2, y2) = nodos[c["a"]], nodos[c["b"]]
    return x1 + (x2 - x1) * t, y1 + (y2 - y1) * t


def imagen_edificio(ruta, n, e, idx, lista, mapa, nodos, pares, total):
    fig = plt.figure(figsize=(15, 8.6), dpi=130)
    ax = fig.add_axes([0.015, 0.03, 0.6, 0.86])
    dibujar_contexto(ax, mapa, nodos, pares, excluir=idx)
    ax.add_patch(PathPatch(path_poligono(e["anillos"]), fc="#ffd86b", ec="#b07800",
                           lw=2.2, alpha=0.75, zorder=5))

    xs = [p[0] for r in e["anillos"] for p in r]
    ys = [p[1] for r in e["anillos"] for p in r]
    for c in lista:
        for nodo in (c["a"], c["b"]):
            xs.append(nodos[nodo][0])
            ys.append(nodos[nodo][1])
    xmin, xmax, ymin, ymax = min(xs), max(xs), min(ys), max(ys)
    margen = max(8.0, 0.08 * max(xmax - xmin, ymax - ymin))
    lado_min = 50.0
    cx, cy = (xmin + xmax) / 2, (ymin + ymax) / 2
    medio_x = max((xmax - xmin) / 2 + margen, lado_min / 2)
    medio_y = max((ymax - ymin) / 2 + margen, lado_min / 2)
    ventana = ajustar_ventana(ax, cx - medio_x, cx + medio_x, cy - medio_y, cy + medio_y,
                              aspecto=(0.6 * 15) / (0.86 * 8.6))
    tam = max(ventana[1] - ventana[0], ventana[3] - ventana[2])

    extremos = set()
    for k, c in enumerate(lista):
        color = COLORES[k % len(COLORES)]
        (x1, y1), (x2, y2) = nodos[c["a"]], nodos[c["b"]]
        ax.plot([x1, x2], [y1, y2], color=color, lw=1.6, ls=(0, (4, 2)), zorder=8)
        for t0, t1 in c["tramos"]:
            pa, pb = punto(nodos, c, t0), punto(nodos, c, t1)
            ax.plot([pa[0], pb[0]], [pa[1], pb[1]], color=color, lw=4.5,
                    solid_capstyle="butt", zorder=9)
        extremos.update((c["a"], c["b"]))

    # Etiquetas sin encimarse: cajas en puntos de pantalla (y hacia abajo).
    pts_por_m = 0.6 * 15 * 72 / (ventana[1] - ventana[0])

    def pantalla(p):
        return (p[0] - ventana[0]) * pts_por_m, (p[1] - ventana[2]) * pts_por_m

    def datos(s):
        return s[0] / pts_por_m + ventana[0], s[1] / pts_por_m + ventana[2]

    ocupadas = []  # (x0, y0, x1, y1) en puntos

    def libre(caja):
        return all(caja[2] + 2 < o[0] or o[2] + 2 < caja[0] or caja[3] + 2 < o[1]
                   or o[3] + 2 < caja[1] for o in ocupadas)

    for nodo in extremos:  # los puntos de los nodos también estorban
        sx, sy = pantalla(nodos[nodo])
        ocupadas.append((sx - 3, sy - 3, sx + 3, sy + 3))

    # Números: sobre el tramo dentro más largo; si no cabe, a un lado, con guía.
    r_num = 9.5
    for k, c in enumerate(lista):
        color = COLORES[k % len(COLORES)]
        t0, t1 = max(c["tramos"], key=lambda r: r[1] - r[0])
        sa, sb = pantalla(nodos[c["a"]]), pantalla(nodos[c["b"]])
        largo = math.dist(sa, sb) or 1.0
        nx, ny = -(sb[1] - sa[1]) / largo, (sb[0] - sa[0]) / largo
        ts = [t0 + (t1 - t0) * f for f in (0.5, 0.3, 0.7, 0.15, 0.85)]
        opciones = [(t, 0.0) for t in ts]
        opciones += [(t, s * d) for d in (24, 40, 56, 72) for t in ts[:3] for s in (1, -1)]
        elegido = None
        for t, d in opciones:
            ax0, ay0 = sa[0] + (sb[0] - sa[0]) * t, sa[1] + (sb[1] - sa[1]) * t
            cx, cy = ax0 + nx * d, ay0 + ny * d
            caja = (cx - r_num, cy - r_num, cx + r_num, cy + r_num)
            if libre(caja):
                elegido = (caja, (cx, cy), (ax0, ay0), d)
                break
        if elegido is None:
            t, d = ts[0], 0.0
            ax0, ay0 = sa[0] + (sb[0] - sa[0]) * t, sa[1] + (sb[1] - sa[1]) * t
            elegido = ((ax0 - r_num, ay0 - r_num, ax0 + r_num, ay0 + r_num),
                       (ax0, ay0), (ax0, ay0), d)
        caja, centro, ancla, d = elegido
        ocupadas.append(caja)
        x, y = datos(centro)
        if d:
            ax0, ay0 = datos(ancla)
            ax.plot([ax0, x], [ay0, y], color=color, lw=1, zorder=14)
        ax.text(x, y, str(k + 1), ha="center", va="center", fontsize=9,
                fontweight="bold", color="white", zorder=15,
                bbox=dict(boxstyle="circle,pad=0.25", fc=color, ec="white", lw=1.2))

    # Nombres de los nodos extremos: arriba, abajo, a los lados o en diagonal.
    for nodo in sorted(extremos, key=lambda n: nodos[n]):
        x, y = nodos[nodo]
        ax.scatter([x], [y], s=28, color="black", zorder=12)
        sx, sy = pantalla((x, y))
        ancho, alto = 4.9 * len(nodo) + 2, 10
        lados = [(0, -(alto / 2 + 5)), (0, alto / 2 + 5), (ancho / 2 + 6, 0),
                 (-(ancho / 2 + 6), 0), (ancho / 2 + 4, -(alto / 2 + 4)),
                 (-(ancho / 2 + 4), -(alto / 2 + 4)), (ancho / 2 + 4, alto / 2 + 4),
                 (-(ancho / 2 + 4), alto / 2 + 4), (0, -(alto * 1.5 + 6)), (0, alto * 1.5 + 6)]
        cajas = [(sx + dx - ancho / 2, sy + dy - alto / 2, sx + dx + ancho / 2,
                  sy + dy + alto / 2) for dx, dy in lados]
        caja = next((c for c in cajas if libre(c)), cajas[0])
        ocupadas.append(caja)
        tx, ty = datos(((caja[0] + caja[2]) / 2, (caja[1] + caja[3]) / 2))
        ax.text(tx, ty, nodo, fontsize=8, ha="center", va="center", zorder=13,
                path_effects=HALO)

    escala_y_norte(ax, *ventana)

    tipo = f" · tipo «{e['tipo']}»" if e["tipo"] != "normal" else ""
    fig.text(0.015, 0.955, f"{n:02d}. {etiqueta(e, idx)}", fontsize=17, fontweight="bold")
    aristas = "1 arista" if len(lista) == 1 else f"{len(lista)} aristas"
    fig.text(0.015, 0.918, f"{aristas} · {total:.1f} m de cruce en total{tipo}",
             fontsize=11.5, color="#444444")
    fig.text(0.63, 0.955, "¿Se puede atravesar caminando?", fontsize=13, fontweight="bold")
    fig.text(0.63, 0.918, "Sí = pasillo real · No = corte de esquina", fontsize=11, color="#444444")

    axt = fig.add_axes([0.63, 0.03, 0.36, 0.86])
    axt.axis("off")
    filas = []
    for k, c in enumerate(lista):
        ext = {(True, True): "A y B", (True, False): "A", (False, True): "B"}.get(
            (c["a_dentro"], c["b_dentro"]), "—")
        filas.append([str(k + 1), c["a"], c["b"], f"{c['metros_dentro']:.1f}",
                      f"{c['metros_arista']:.1f}",
                      f"{100 * c['metros_dentro'] / c['metros_arista']:.0f}", ext])
    tabla = axt.table(cellText=filas,
                      colLabels=["#", "Nodo A", "Nodo B", "Dentro\n(m)", "Arista\n(m)", "%",
                                 "Extremo\ndentro"],
                      colWidths=[0.06, 0.27, 0.27, 0.1, 0.1, 0.07, 0.13],
                      loc="upper center", cellLoc="center")
    tabla.auto_set_font_size(False)
    tabla.set_fontsize(8.5)
    alto_fila = min(0.06, 0.94 / (len(filas) + 1.5))
    for (r, col), celda in tabla.get_celld().items():
        celda.set_height(alto_fila * (1.5 if r == 0 else 1))
        celda.set_edgecolor("#cccccc")
        if r == 0:
            celda.set_facecolor("#eeeeee")
            celda.get_text().set_fontweight("bold")
        elif col == 0:
            celda.set_facecolor(COLORES[(r - 1) % len(COLORES)])
            celda.get_text().set_color("white")
            celda.get_text().set_fontweight("bold")
    fig.savefig(ruta)
    plt.close(fig)


def etiqueta(e, idx):
    nombre = nombre_edificio(e)
    return f"Edificio sin nombre (polígono {idx})" if nombre == "(sin nombre)" else nombre


def vista_general(ruta, grupos, mapa, nodos, pares, cruces):
    fig = plt.figure(figsize=(12, 13.6), dpi=130)
    ax = fig.add_axes([0.02, 0.02, 0.96, 0.9])
    dibujar_contexto(ax, mapa, nodos, pares)
    for n, (idx, _, _) in enumerate(grupos, 1):
        e = mapa["edificios"][idx]
        ax.add_patch(PathPatch(path_poligono(e["anillos"]), fc="#ffd86b", ec="#b07800",
                               lw=1.4, alpha=0.8, zorder=5))
    for c in cruces:
        (x1, y1), (x2, y2) = nodos[c["a"]], nodos[c["b"]]
        ax.plot([x1, x2], [y1, y2], color="#d62728", lw=1.1, zorder=8)
    for n, (idx, _, _) in enumerate(grupos, 1):
        e = mapa["edificios"][idx]
        x, y = e.get("etiqueta") or e["anillos"][0][0]
        ax.text(x, y, str(n), ha="center", va="center", fontsize=9, fontweight="bold",
                color="white", zorder=15,
                bbox=dict(boxstyle="circle,pad=0.25", fc="#333333", ec="white", lw=1))
    lim = mapa["meta"]["limites"]
    ventana = ajustar_ventana(ax, lim["min_x"], lim["max_x"], lim["min_y"], lim["max_y"],
                              aspecto=(0.96 * 12) / (0.9 * 13.6))
    escala_y_norte(ax, *ventana)
    fig.text(0.02, 0.955, "Fase 6c · edificios que cruza alguna arista del grafo",
             fontsize=16, fontweight="bold")
    fig.text(0.02, 0.935, f"{len(grupos)} edificios · {len(cruces)} cruces · en rojo, las "
             "aristas que cruzan · el número es el de la imagen de cada edificio",
             fontsize=10.5, color="#444444")
    fig.savefig(ruta)
    plt.close(fig)


# ------------------------------------------------------------------- main

def main():
    raiz = Path(__file__).resolve().parent.parent
    args = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    args.add_argument("--csv", type=Path, default=raiz / "build/reporte_aristas_edificios.csv")
    args.add_argument("--salida", type=Path, default=raiz / "build/aristas_por_edificio")
    args = args.parse_args()

    nodos, pares, mapa = cargar(raiz)
    edificios = mapa["edificios"]
    cruces = calcular_cruces(nodos, pares, edificios)
    filas_csv, nombres = cotejar(cruces, edificios, args.csv)

    por_edificio = defaultdict(list)
    for c in cruces:
        por_edificio[c["edificio"]].append(c)
    grupos = []
    for idx, lista in por_edificio.items():
        lista.sort(key=lambda c: (-c["metros_dentro"], c["a"], c["b"]))
        grupos.append((idx, lista, sum(c["metros_dentro"] for c in lista)))
    grupos.sort(key=lambda g: (-g[2], etiqueta(edificios[g[0]], g[0])))

    args.salida.mkdir(parents=True, exist_ok=True)
    for viejo in args.salida.glob("*.png"):
        viejo.unlink()

    resumen, detalle = [], []
    for n, (idx, lista, total) in enumerate(grupos, 1):
        e = edificios[idx]
        archivo = f"{n:02d}_{slug(etiqueta(e, idx))}.png"
        imagen_edificio(args.salida / archivo, n, e, idx, lista, mapa, nodos, pares, total)
        resumen.append([n, etiqueta(e, idx), e["tipo"], len(lista), f"{total:.1f}", archivo, ""])
        for k, c in enumerate(lista, 1):
            detalle.append([n, etiqueta(e, idx), k, c["a"], nombres.get(c["a"], ""), c["b"],
                            nombres.get(c["b"], ""), f"{c['metros_dentro']:.1f}",
                            f"{c['metros_arista']:.1f}",
                            f"{100 * c['metros_dentro'] / c['metros_arista']:.0f}",
                            "si" if c["a_dentro"] else "no", "si" if c["b_dentro"] else "no"])
    vista_general(args.salida / "00_vista_general.png", grupos, mapa, nodos, pares, cruces)

    with (args.salida / "resumen.csv").open("w", encoding="utf-8", newline="") as f:
        w = csv.writer(f)
        w.writerow(["n", "edificio", "tipo", "aristas", "metros_cruce_total", "imagen",
                    "se_puede_atravesar"])
        w.writerows(resumen)
    with (args.salida / "aristas_por_edificio.csv").open("w", encoding="utf-8", newline="") as f:
        w = csv.writer(f)
        w.writerow(["n_edificio", "edificio", "n_arista", "nodo_a", "nombre_a", "nodo_b",
                    "nombre_b", "metros_dentro", "metros_arista", "porcentaje_dentro",
                    "a_dentro_del_edificio", "b_dentro_del_edificio"])
        w.writerows(detalle)
    md = ["| # | Edificio | Aristas | Metros de cruce | Imagen |", "|---:|---|---:|---:|---|"]
    md += [f"| {r[0]} | {r[1]} | {r[3]} | {r[4]} | `{r[5]}` |" for r in resumen]
    md.append(f"| | **Total** | **{len(cruces)}** | "
              f"**{sum(g[2] for g in grupos):.1f}** | |")
    (args.salida / "resumen.md").write_text("\n".join(md) + "\n", encoding="utf-8")

    print(f"{len(cruces)} cruces (CSV: {filas_csv}) de {len({(c['a'], c['b']) for c in cruces})} "
          f"aristas en {len(grupos)} edificios -> {args.salida}")


if __name__ == "__main__":
    main()
