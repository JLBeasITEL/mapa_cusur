"""Bloque 6: Edificio L con sus laboratorios, el trazo y los espacios abiertos entre alas, para marcar el patio.

El polígono de L en assets/campus_vector.json es un solo contorno, sin huecos: el patio interior
no aparece como tal. Esta imagen muestra los tres espacios abiertos entre alas (A, B y C) para que
Juan Luis indique cuál es el patio (o lo dibuje). No modifica nada.

Uso, desde mapa_cusur/: python tool/graficar_patios_L.py <salida.png>
"""

import json
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import graficar_aristas_edificios as gae  # noqa: E402

plt = gae.plt
HALO = gae.HALO

# Espacios abiertos entre las alas de L, con los vértices del polígono que los limitan.
CANDIDATOS = {
    'A': ([(-24.7, -1.0), (-22.6, -8.5), (-11.9, -5.6), (-3.5, -0.6)],
          'Entre el ala media y el ala sur, abierto al este'),
    'B': ([(-28.3, -30.4), (-30.7, -21.7), (-56.5, -28.7), (-42.0, -36.0)],
          'Entre el ala norte y el ala oeste, abierto al noroeste'),
    'C': ([(-33.5, -11.5), (-59.3, -18.5), (-52.0, -1.4), (-36.4, -1.2)],
          'Entre el ala oeste y el ala suroeste, abierto al oeste'),
}
LABS = {'Lab_Periodismo': 'Laboratorio de Periodismo', 'Lab_Programacion': 'Laboratorio de Programación',
        'Lab_Electronica': 'Laboratorio de Electrónica'}


def main():
    raiz = Path(__file__).resolve().parent.parent
    nodos, pares, mapa = gae.cargar(raiz)
    trazo = json.loads((raiz / 'docs/mapa_vectorial/fase6c/trazo_usuario.json').read_text(encoding='utf-8'))['puntos']
    fig = plt.figure(figsize=(15, 10.5), dpi=120)
    ax = fig.add_axes([0.01, 0.02, 0.66, 0.88])
    gae.dibujar_contexto(ax, mapa, nodos, pares)
    colores = {'A': '#2ca02c', 'B': '#1f77b4', 'C': '#ff7f0e'}
    for k, (pts, _) in CANDIDATOS.items():
        ax.add_patch(plt.Polygon(pts, closed=True, fc=colores[k], ec=colores[k], alpha=0.25, lw=2, zorder=5))
        cx = sum(p[0] for p in pts) / len(pts)
        cy = sum(p[1] for p in pts) / len(pts)
        ax.text(cx, cy, k, fontsize=22, fontweight='bold', color=colores[k], ha='center', va='center',
                zorder=9, path_effects=HALO)
    xs, ys = zip(*trazo)
    ax.scatter(xs, ys, s=5, color='#7f9cff', alpha=0.6, lw=0, zorder=6)
    for l in mapa['lugares']:
        if l['nombre'] in LABS.values():
            ax.scatter([l['pos'][0]], [l['pos'][1]], marker='s', s=90, color='#7a3db8', zorder=10)
            ax.text(l['pos'][0], l['pos'][1] + 2.2, l['nombre'].replace('Laboratorio de ', 'Lab. ') + ' (ícono)',
                    fontsize=9, color='#4b1f7a', ha='center', va='top', zorder=11, path_effects=HALO)
    for n in LABS:
        x, y = nodos[n]
        ax.scatter([x], [y], s=80, color='#d62728', edgecolor='white', zorder=10)
        ax.text(x, y - 1.6, f'{n} (nodo)', fontsize=9, color='#a51d1d', ha='center', va='bottom', zorder=11,
                path_effects=HALO)
    for n in ['L1', 'L2', 'L4', 'L5', 'L7', 'L8', 'Edificio_L', 'LE3', 'LE5', 'LE6', 'LE8', 'LE9']:
        x, y = nodos[n]
        ax.scatter([x], [y], s=26, color='black', zorder=10)
        ax.text(x + 0.9, y - 0.9, n, fontsize=8, zorder=11, path_effects=HALO)
    gae.ajustar_ventana(ax, -66, 6, -40, 16, aspecto=(0.66 * 15) / (0.88 * 10.5))
    fig.text(0.01, 0.955, 'Edificio L: ¿dónde está el patio interior?', fontsize=17, fontweight='bold')
    fig.text(0.01, 0.925, 'El polígono de campus_vector.json es un solo contorno, sin patio; A, B y C son los '
             'espacios abiertos entre alas.', fontsize=10.5, color='#444444')
    lineas = ['Espacios abiertos entre alas:', '']
    for k, (_, desc) in CANDIDATOS.items():
        lineas.append(f'  {k}: {desc}')
    lineas += ['', 'Laboratorios (nodo actual · ícono del mapa):']
    for n, nombre in LABS.items():
        x, y = nodos[n]
        lineas.append(f'  {nombre}: nodo ({x:.1f}, {y:.1f}), conectado a '
                      f'{", ".join(json.loads((raiz / "assets/campus_data.json").read_text(encoding="utf-8"))["conexiones"][n])}')
    lineas += ['', 'Azul claro: tu trazo. El ramal LE6–LE8–LE9 (Bloque 5) entra a A', 'desde el este.',
               '', 'Indica la letra del patio (o dibújalo sobre la imagen) y', 'frente a qué fachada está la '
               'entrada de cada laboratorio.']
    fig.text(0.69, 0.88, '\n'.join(lineas), fontsize=10, va='top')
    fig.savefig(sys.argv[1])
    print(f'-> {sys.argv[1]}')


if __name__ == '__main__':
    main()
