"""Fase 6c: destinos por los que una ruta puede atravesar un edificio.

Lee build/fase6c/destinos_de_paso.json (tool/reporte_destinos_de_paso.dart)
y lista los nodos con nombre que están dentro de un polígono de edificio de
assets/campus_vector.json y tienen más de un vecino: una ruta puede entrar
al edificio por una arista y salir por otra. Dos grupos:

  - dentro de SU edificio (el que los nombra en su campo `nodos`);
  - dentro de otro polígono, o de uno que no los nombra.

Escribe <salida>/destinos_de_paso.png, .md y .csv. No modifica nada.

Uso, desde mapa_cusur/ (requiere matplotlib):
  dart run tool/reporte_destinos_de_paso.dart
  python tool/graficar_destinos_de_paso.py [salida]   # por omisión docs/mapa_vectorial/fase6c
"""

import csv
import json
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import graficar_aristas_edificios as gae  # noqa: E402

plt = gae.plt
HALO = gae.HALO


def main():
    raiz = Path(__file__).resolve().parent.parent
    salida = Path(sys.argv[1]) if len(sys.argv) > 1 else raiz / "docs/mapa_vectorial/fase6c"
    datos = json.loads((raiz / "build/fase6c/destinos_de_paso.json").read_text(encoding="utf-8"))
    nodos, pares, mapa = gae.cargar(raiz)
    edificios = mapa["edificios"]

    filas = []
    for id_, n in datos["nodos"].items():
        if len(n["vecinos"]) < 2:
            continue
        p = nodos[id_]
        contiene = [i for i, e in enumerate(edificios) if gae.dentro(p, e["anillos"])]
        if not contiene:
            continue
        propios = [i for i in contiene if n["nombre"] in edificios[i]["nodos"]]
        i = (propios or contiene)[0]
        filas.append({
            "id": id_, "nombre": n["nombre"], "edificio": gae.etiqueta(edificios[i], i),
            "propio": bool(propios), "indice": i, "vecinos": n["vecinos"],
            "pasan": n["pares_que_pasan"], "transiciones": n["transiciones"],
            "ejemplos": n["ejemplos"],
        })
    filas.sort(key=lambda f: (not f["propio"], -f["pasan"], f["id"]))

    def aristas(f):
        partes = []
        for v, w in f["vecinos"].items():
            if w["ida"] is not None and w["vuelta"] is not None:
                partes.append(f"{v} ({w['ida']:.2f})")
            elif w["ida"] is not None:
                partes.append(f"{v} ({w['ida']:.2f}, solo ida)")
            else:
                partes.append(f"{v} ({w['vuelta']:.2f}, solo vuelta)")
        return ", ".join(partes)

    def transiciones(f, k=3):
        return "; ".join(f"{t} ({c})" for t, c in list(f["transiciones"].items())[:k])

    salida.mkdir(parents=True, exist_ok=True)
    # La columna `decision` la llena Juan Luis: se conserva al regenerar.
    ruta_csv = salida / "destinos_de_paso.csv"
    decisiones = {}
    if ruta_csv.exists():
        decisiones = {r["nodo"]: r["decision"] for r in csv.DictReader(ruta_csv.open(encoding="utf-8"))}
    with ruta_csv.open("w", encoding="utf-8", newline="") as fh:
        w = csv.writer(fh)
        w.writerow(["nodo", "nombre", "edificio", "es_su_edificio", "vecinos", "aristas",
                    "pares_que_pasan", "transiciones_principales", "decision"])
        for f in filas:
            w.writerow([f["id"], f["nombre"], f["edificio"], "si" if f["propio"] else "no",
                        len(f["vecinos"]), aristas(f), f["pasan"], transiciones(f, 5),
                        decisiones.get(f["id"], "")])
    md = [f"Pares de la línea base: {datos['pares']}. «Pasan»: rutas que atraviesan el nodo sin "
          "empezar ni terminar en él (cálculo de la app, grafo interpolado).", ""]
    for titulo, propio in (("Dentro de su edificio", True), ("Dentro de otro polígono", False)):
        grupo = [f for f in filas if f["propio"] == propio]
        md += [f"## {titulo} ({len(grupo)})", "",
               "| # | Nodo | Edificio | Aristas | Pasan | Recorridos más usados |", "|---:|---|---|---|---:|---|"]
        md += [f"| {filas.index(f) + 1} | `{f['id']}` ({f['nombre']}) | {f['edificio']} | {aristas(f)} | "
               f"{f['pasan']} | {transiciones(f)} |" for f in grupo]
        md.append("")
    (salida / "destinos_de_paso.md").write_text("\n".join(md), encoding="utf-8")

    # PNG: el campus, con los destinos de paso resaltados y numerados.
    fig = plt.figure(figsize=(18, 13.6), dpi=110)
    ax = fig.add_axes([0.01, 0.02, 0.56, 0.9])
    gae.dibujar_contexto(ax, mapa, nodos, pares)
    for f in filas:
        e = edificios[f["indice"]]
        color = "#d62728" if f["propio"] else "#ff7f0e"
        ax.add_patch(gae.PathPatch(gae.path_poligono(e["anillos"]), fc=color, ec=color, lw=1.2,
                                   alpha=0.18, zorder=5))
        x, y = nodos[f["id"]]
        for v in f["vecinos"]:
            vx, vy = nodos[v]
            ax.plot([x, vx], [y, vy], color=color, lw=1.8, zorder=7)
    for k, f in enumerate(filas, 1):
        x, y = nodos[f["id"]]
        color = "#d62728" if f["propio"] else "#ff7f0e"
        ax.scatter([x], [y], s=60 + 0.6 * f["pasan"], color=color, edgecolor="white", lw=1.2, zorder=9)
        ax.text(x + 2.5, y - 2.5, f"{k}", fontsize=10, fontweight="bold", color=color, zorder=10,
                path_effects=HALO)
    lim = mapa["meta"]["limites"]
    ventana = gae.ajustar_ventana(ax, lim["min_x"], lim["max_x"], lim["min_y"], lim["max_y"],
                                  aspecto=(0.56 * 18) / (0.9 * 13.6))
    gae.escala_y_norte(ax, *ventana)
    fig.text(0.01, 0.96, "Destinos por los que una ruta puede atravesar un edificio", fontsize=17,
             fontweight="bold")
    fig.text(0.01, 0.935, "Nodo con nombre dentro de un polígono de edificio y con más de un vecino · "
             "rojo: su edificio · naranja: otro polígono · tamaño: rutas que pasan",
             fontsize=10.5, color="#444444")

    lineas = []
    for titulo, propio in (("Dentro de su edificio", True), ("Dentro de otro polígono", False)):
        grupo = [f for f in filas if f["propio"] == propio]
        lineas += [f"{titulo} ({len(grupo)})", ""]
        for f in grupo:
            lineas.append(f"{filas.index(f) + 1}. {f['id']} — {f['edificio']} — pasan {f['pasan']} de "
                          f"{datos['pares']}")
            for t in [aristas(f)] + ([transiciones(f, 2)] if f["transiciones"] else []):
                lineas += gae_wrap(t, "     ")
        lineas.append("")
    fig.text(0.585, 0.9, "\n".join(lineas), fontsize=8.2, va="top", family="DejaVu Sans")
    fig.savefig(salida / "destinos_de_paso.png")
    plt.close(fig)
    print(f"{len(filas)} destinos de paso ({sum(f['propio'] for f in filas)} en su edificio) -> {salida}")


def gae_wrap(texto, sangria):
    import textwrap
    return textwrap.wrap(texto, width=96, initial_indent=sangria, subsequent_indent=sangria)


if __name__ == "__main__":
    main()
