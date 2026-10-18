"""Fase 6c: PNG de la propuesta de un bloque de cambios del grafo.

Dibuja, sobre el mapa vectorial y el trazo de Juan Luis
(docs/mapa_vectorial/fase6c/trazo_usuario.json), lo que propone un bloque de
tool/cambios_grafo.dart: nodos nuevos o movidos, aristas agregadas en verde
y aristas quitadas en rojo, con un resumen de la regresión. Comprueba además
que ninguna arista agregada cruce un edificio (con la misma fórmula que
tool/graficar_aristas_edificios.py) y se detiene si alguna lo hace.

Uso, desde mapa_cusur/ (requiere matplotlib), después de
`dart run tool/cambios_grafo.dart <bloque.json>`:
  python tool/graficar_propuesta_grafo.py build/fase6c/<bloque>_informe.json <salida.png>
"""

import json
import math
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import graficar_aristas_edificios as gae  # noqa: E402

plt = gae.plt
HALO = gae.HALO


def main():
    raiz = Path(__file__).resolve().parent.parent
    informe = json.loads(Path(sys.argv[1]).read_text(encoding="utf-8"))
    salida = Path(sys.argv[2])
    nodos_antes, pares_antes, mapa = gae.cargar(raiz)
    trazo = json.loads((raiz / "docs/mapa_vectorial/fase6c/trazo_usuario.json")
                       .read_text(encoding="utf-8"))["puntos"]

    nodos = dict(nodos_antes)
    for n in informe["nodos"]:
        nodos[n["id"]] = (n["x"], n["y"])
    quitadas = {tuple(sorted((q["a"], q["b"]))) for q in informe["aristas_quitadas"]}
    agregadas = [(a["a"], a["b"], a["metros"], a["peso"]) for a in informe["aristas_agregadas"]]
    pares = [p for p in pares_antes if p not in quitadas]

    # Ninguna arista agregada puede cruzar un edificio.
    cruces = []
    for a, b, *_ in agregadas:
        largo = math.dist(nodos[a], nodos[b])
        for e in mapa["edificios"]:
            t = gae.tramos_dentro(nodos[a], nodos[b], e["anillos"])
            m = sum(t1 - t0 for t0, t1 in t) * largo
            if m >= gae.UMBRAL_ROCE:
                cruces.append(f"{a}–{b} cruza {gae.nombre_edificio(e)} ({m:.1f} m)")
    if cruces:
        raise SystemExit("Aristas agregadas que cruzan edificios:\n  " + "\n  ".join(cruces))

    fig = plt.figure(figsize=(16, 9.6), dpi=120)
    ax = fig.add_axes([0.01, 0.02, 0.62, 0.88])
    ax.add_patch(plt.Polygon(mapa["campus"], closed=True, fc="#f7f7f2", ec="#bbbbbb", lw=1, zorder=0))
    for anillo in mapa["areas_verdes"]:
        ax.add_patch(plt.Polygon(anillo, closed=True, fc="#dcefd2", ec="none", zorder=1))
    for c in mapa["canchas_futbol"] + mapa["canchas"]:
        ax.add_patch(plt.Polygon(c["poligono"], closed=True, fc="#cfe5c4", ec="#9fbf93", lw=0.6, zorder=1))
    for e in mapa["edificios"]:
        ax.add_patch(gae.PathPatch(gae.path_poligono(e["anillos"]), fc="#e2e2e2", ec="#8a8a8a", lw=0.9, zorder=2))
        if e.get("etiqueta"):
            ax.text(*e["etiqueta"], gae.nombre_edificio(e) if e.get("nombre") else (e.get("letra") or ""),
                    fontsize=8, color="#666666", ha="center", va="center", zorder=2, clip_on=True)
    xs, ys = zip(*trazo)
    ax.scatter(xs, ys, s=5, color="#7f9cff", alpha=0.55, lw=0, zorder=3, label="Tu trazo")
    for a, b in pares:
        (x1, y1), (x2, y2) = nodos[a], nodos[b]
        ax.plot([x1, x2], [y1, y2], color="#9a9a9a", lw=0.9, zorder=4)
    for a, b in quitadas:
        (x1, y1), (x2, y2) = nodos_antes[a], nodos_antes[b]
        ax.plot([x1, x2], [y1, y2], color="#d62728", lw=2.4, ls=(0, (5, 3)), zorder=6)
    for a, b, metros, peso in agregadas:
        (x1, y1), (x2, y2) = nodos[a], nodos[b]
        ax.plot([x1, x2], [y1, y2], color="#1a9e3a", lw=3.6, solid_capstyle="round", zorder=7)
        largo = math.dist((x1, y1), (x2, y2)) or 1.0
        nx, ny = (y2 - y1) / largo, -(x2 - x1) / largo  # a la izquierda en pantalla
        if ny > 0:  # siempre del lado de arriba (norte) o, si es vertical, a la derecha
            nx, ny = -nx, -ny
        ax.text((x1 + x2) / 2 + nx * 2.6, (y1 + y2) / 2 + ny * 2.6, f"{metros:.1f} m · {peso:.2f}",
                fontsize=8, color="#0d5e22", ha="center", va="center", zorder=9,
                path_effects=HALO, clip_on=True)
    for n in informe["nodos"]:
        x, y = n["x"], n["y"]
        if n["movido"]:
            ox, oy = nodos_antes[n["id"]]
            ax.annotate("", xy=(x, y), xytext=(ox, oy), zorder=8,
                        arrowprops=dict(arrowstyle="->", color="#7a3db8", lw=1.6, ls="--"))
            ax.scatter([ox], [oy], s=40, facecolor="white", edgecolor="#7a3db8", lw=1.5, zorder=8)
            ax.text(ox, oy + 2.2, f"{n['id']} (antes)", fontsize=8, color="#7a3db8", ha="center",
                    va="top", zorder=9, path_effects=HALO)
        ax.scatter([x], [y], s=70, color="#7a3db8", edgecolor="white", lw=1.2, zorder=10)
        ax.text(x, y - 1.8, n["id"], fontsize=10, fontweight="bold", color="#4b1f7a",
                ha="center", va="bottom", zorder=11, path_effects=HALO)

    involucrados = {n["id"] for n in informe["nodos"]}
    for a, b, *_ in agregadas:
        involucrados |= {a, b}
    for a, b in quitadas:
        involucrados |= {a, b}
    for i in involucrados - {n["id"] for n in informe["nodos"]}:
        x, y = nodos[i]
        ax.scatter([x], [y], s=30, color="black", zorder=10)
        ax.text(x + 1.2, y - 1.2, i, fontsize=9, zorder=11, path_effects=HALO)
    xs = [nodos[i][0] for i in involucrados] + [nodos_antes[i][0] for i in involucrados if i in nodos_antes]
    ys = [nodos[i][1] for i in involucrados] + [nodos_antes[i][1] for i in involucrados if i in nodos_antes]
    margen = 12
    ventana = gae.ajustar_ventana(ax, min(xs) - margen, max(xs) + margen, min(ys) - margen,
                                  max(ys) + margen, aspecto=(0.62 * 16) / (0.88 * 9.6))
    gae.escala_y_norte(ax, *ventana)

    leyenda = [
        plt.Line2D([], [], color="#7f9cff", marker="o", ls="", ms=5, label="Tu trazo"),
        plt.Line2D([], [], color="#1a9e3a", lw=3.6, label="Arista agregada (m · peso)"),
        plt.Line2D([], [], color="#d62728", lw=2.4, ls=(0, (5, 3)), label="Arista quitada"),
        plt.Line2D([], [], color="#9a9a9a", lw=0.9, label="Arista que se conserva"),
        plt.Line2D([], [], color="#7a3db8", marker="o", ls="", ms=8, label="Nodo nuevo o movido"),
    ]
    ax.legend(handles=leyenda, loc="lower right", fontsize=8.5, framealpha=0.92)

    fig.text(0.01, 0.955, f"Propuesta · {informe['bloque']}", fontsize=17, fontweight="bold")
    fig.text(0.01, 0.92, "Ninguna arista agregada cruza un edificio · pesos = round(km Haversine / 0.0667, 2)",
             fontsize=10.5, color="#444444")

    lineas = ["Nodos"]
    for n in informe["nodos"]:
        accion = "se mueve" if n["movido"] else "nuevo"
        lineas.append(f"  {n['id']} ({accion}): ({n['x']:.1f}, {n['y']:.1f}) m · píxel {n['pix'][0]}, "
                      f"{n['pix'][1]} (de {n['ancla']})")
    lineas += ["", "Aristas quitadas"]
    for q in informe["aristas_quitadas"]:
        sentidos = " y ".join(s for s, p in (("ida", q["peso_ab"]), ("vuelta", q["peso_ba"])) if p is not None)
        peso = q["peso_ab"] if q["peso_ab"] is not None else q["peso_ba"]
        lineas.append(f"  {q['a']}–{q['b']} ({peso:.2f}; {sentidos})")
    lineas += ["", "Aristas agregadas (ambos sentidos)"]
    for a, b, metros, peso in agregadas:
        lineas.append(f"  {a}–{b}: {metros:.1f} m, {peso:.2f}")
    lineas += ["", f"Regresión ({informe['pares']} pares, {informe['pares_inalcanzables']} inalcanzables)",
               f"  Cambian de distancia: {informe['pares_que_cambian_de_distancia']} "
               f"({informe['mas_largos']} más largos, {informe['mas_cortos']} más cortos)"]
    if informe["cambios"]:
        c = informe["cambios"][0]
        lineas.append(f"  Mayor: {c['origen']} → {c['destino']}")
        lineas.append(f"         {c['antes']:.2f} → {c['despues']:.2f} min ({c['diferencia']:+.2f})")
    for r, e in informe["rutas_ejemplo"].items():
        lineas.append(f"  {r} {e['origen']} → {e['destino']}: {e['antes']:.2f} → {e['despues']:.2f}")
    lineas += ["", "Validador"]
    for k, v in informe["validador"].items():
        if v["antes"] != v["despues"] or v["nuevos"]:
            lineas.append(f"  {k}: {v['antes']} → {v['despues']} ({len(v['nuevos'])} nuevos)")
    if lineas[-1] == "Validador":
        lineas.append("  sin cambios")
    c = informe["cifras_calibracion"]
    lineas += ["", f"Cifras de la tesis (calibración congelada, {c['nodos_digitalizados']} nodos):",
               f"  {c['px_por_metro']:.3f} px/m · afín {c['afin_px']:.2f} px / {c['afin_m']:.2f} m · "
               f"dos puntos {c['dos_puntos_px']:.2f} px / {c['dos_puntos_m']:.2f} m"]
    fig.text(0.645, 0.885, "\n".join(lineas), fontsize=8.8, va="top", family="DejaVu Sans")
    salida.parent.mkdir(parents=True, exist_ok=True)
    fig.savefig(salida)
    plt.close(fig)
    print(f"-> {salida}")


if __name__ == "__main__":
    main()
