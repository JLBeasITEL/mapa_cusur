"""Exporta la vista previa del mapa vectorial a assets/campus_vector.json para Flutter.

Toda la geometría derivada (líneas de canchas, semicírculos, centros de etiqueta,
posición y ángulo de los nombres de calles) se calcula aquí, para que el código
Dart solo tenga que dibujar.

Uso: python3 exportar_flutter.py <scratchpad> <salida.json>
"""
import json, math, sys

S, OUT = sys.argv[1], sys.argv[2]
D = json.load(open(S + '/mapa/data.json'))
J = json.load(open('/tmp/mapa_cusur/mapa_cusur/assets/campus_data.json'))['coordenadas_geo']

LAT0, LON0 = 19.7252, -103.4615
KX = 111320 * math.cos(math.radians(LAT0))
KY = 110574.0

CORTOS = {'Centro Acuático de Rehabilitación y Salvamento CUSUR': 'Centro Acuático',
          'Unidad Interna de Proteccion Civil CUSUR': 'Protección Civil',
          'Auditorio Adolfo Aguilar Zinser': 'Auditorio Aguilar Zinser',
          'Hospital Veterinario CUSUR': 'Hospital Veterinario',
          'Bufete Jurídico CUSUR': 'Bufete Jurídico'}
ICONOS = {'C.A.S.A.': 'local_library', 'Cafetería Principal': 'local_cafe', 'Cafetería Pequeña': 'local_cafe',
          'Cancha de fútbol': 'sports_soccer', '__cancha_nw': 'sports_soccer', 'Centro Acuático': 'pool',
          'Auditorio Aguilar Zinser': 'theater_comedy', 'Hospital Veterinario': 'pets',
          'Rectoría (Edificio D)': 'account_balance', 'Laboratorios CMID': 'science',
          'Laboratorio de análisis clínicos': 'science', 'Protección Civil': 'engineering',
          'Bufete Jurídico': 'gavel', 'Radio UDG': 'cell_tower'}
SUB = {'Edificio C': ['Coordinación de tecnologías', 'para el aprendizaje']}

r1 = lambda v: round(v, 1)
pt = lambda p: [r1(p[0]), r1(p[1])]
ring = lambda r: [pt(p) for p in r]
nombre = lambda f: (CORTOS.get(f['n'], f['n']) if f.get('n') else None)
dist = lambda a, b: math.hypot(b[0] - a[0], b[1] - a[1])
mid = lambda r, i: [(r[i][0] + r[i + 1][0]) / 2, (r[i][1] + r[i + 1][1]) / 2]


def media(r, cerrar=True):
    pts = r[:-1] if cerrar else r
    return [sum(p[0] for p in pts) / len(pts), sum(p[1] for p in pts) / len(pts)]


def geo_a_local(lat, lng):
    return [r1((lng - LON0) * KX), r1(-(lat - LAT0) * KY)]


feats = D['feats']
campus = [f for f in feats if f['c'] == 'campus'][0]['p'][0]
xs = [p[0] for p in campus]; ys = [p[1] for p in campus]
M = 30
lim = {'min_x': r1(min(xs) - M), 'min_y': r1(min(ys) - M), 'max_x': r1(max(xs) + M), 'max_y': r1(max(ys) + M)}

out = {
    'version': 1,
    'meta': {
        'descripcion': 'Mapa vectorial del campus CUSur para RutaCUSur.',
        'origen': {'lat': LAT0, 'lng': LON0},
        'metros_por_grado': {'lat': KY, 'lng': round(KX, 3)},
        'ejes': 'x = metros al este del origen; y = metros al sur del origen (y crece hacia abajo, como en el Canvas).',
        'formula': 'x = (lng - lng0) * metros_por_grado.lng ; y = -(lat - lat0) * metros_por_grado.lat',
        'limites': lim,
        'atribucion': '© colaboradores de OpenStreetMap',
        'licencia': 'Datos derivados de OpenStreetMap, disponibles bajo la Open Database License (ODbL) 1.0.',
        'unidades': 'metros',
    },
    'campus': ring(campus),
    'areas_verdes': [ring(r) for r in D['cesped']],
    'zonas_deportivas': [], 'canchas_futbol': [], 'canchas': [],
    'vialidades': [], 'etiquetas_calles': [], 'edificios': [],
    'lugares': [], 'entradas': [], 'estacionamientos': [],
}

calles = {}
for f in feats:
    c = f['c']; r = f['p'][0]
    if c == 'deporte' and f['g'] == 'poly':
        n = f.get('n')
        if r and len(r) == 5 and not (n or '').startswith('Unidad'):
            a, b = (0, 2) if dist(r[0], r[1]) + dist(r[2], r[3]) > dist(r[1], r[2]) + dist(r[3], r[4]) else (1, 3)
            A, C = mid(r, a), mid(r, b)
            out['canchas_futbol'].append({
                'nombre': n, 'poligono': ring(r), 'linea_media': [pt(A), pt(C)],
                'circulo_central': {'centro': pt([(A[0] + C[0]) / 2, (A[1] + C[1]) / 2]), 'radio': 9.15},
                'icono': 'sports_soccer', 'icono_pos': pt(media(r))})
        else:
            out['zonas_deportivas'].append({'nombre': n, 'poligono': ring(r), 'etiqueta': pt(media(r, False))})
    elif c == 'cancha':
        L = lambda i: dist(r[i], r[i + 1])
        largo = 0 if L(0) > L(1) else 1; corto = 1 - largo
        k = {'poligono': ring(r), 'lineas': [], 'circulos': [], 'semicirculos': [], 'icono': None, 'icono_pos': None}
        cen = [sum(r[i][0] for i in range(4)) / 4, sum(r[i][1] for i in range(4)) / 4]
        if f.get('grande'):
            k['tipo'] = 'baloncesto'
            A, C = mid(r, largo), mid(r, largo + 2)
            k['lineas'].append([pt(A), pt(C)])
            cx, cy = (A[0] + C[0]) / 2, (A[1] + C[1]) / 2
            k['circulos'].append({'centro': pt([cx, cy]), 'radio': 1.8})
            for s in (corto, corto + 2):
                Mm = mid(r, s); ex = (r[s + 1][0] - r[s][0]) / L(s); ey = (r[s + 1][1] - r[s][1]) / L(s)
                nx, ny = -ey, ex
                if (cx - Mm[0]) * nx + (cy - Mm[1]) * ny < 0: nx, ny = -nx, -ny
                R = 4
                k['semicirculos'].append([pt([Mm[0] + ex * R * math.cos(t) + nx * R * math.sin(t),
                                              Mm[1] + ey * R * math.cos(t) + ny * R * math.sin(t)])
                                          for t in (math.pi * j / 24 for j in range(25))])
            s = 0 if L(0) < L(1) else 1; m = mid(r, s)
            k['icono'] = 'sports_basketball'
            k['icono_pos'] = pt([cen[0] + (m[0] - cen[0]) * .45, cen[1] + (m[1] - cen[1]) * .45])
        else:
            k['tipo'] = 'tenis_azul' if f.get('col') == 'azul' else 'tenis_verde'
            if f.get('col') == 'azul':
                k['lineas'].append([pt(mid(r, corto)), pt(mid(r, corto + 2))])
                k['icono'] = 'sports_tennis'; k['icono_pos'] = pt(cen)
        out['canchas'].append(k)
    elif c in ('calle', 'servicio'):
        out['vialidades'].append({'tipo': c, 'nombre': f.get('n'), 'linea': ring(r), 'ancho': 9 if c == 'calle' else 3.2})
        if c == 'calle' and f.get('n'):
            Lt = sum(dist(r[i - 1], r[i]) for i in range(1, len(r)))
            if f['n'] not in calles or calles[f['n']][0] < Lt: calles[f['n']] = (Lt, r)
    elif c == 'edificio':
        n = nombre(f)
        import re
        m = re.match(r'^Edificio ([A-Z])$', n or '')
        letra = f.get('letra') or (m.group(1) if m else None)
        cx, cy = media(r, False)
        if f.get('tipo') == 'techada':
            bx = [p[0] for p in r]; by = [p[1] for p in r]
            cx = min(bx) + (max(bx) - min(bx)) * .75; cy = min(by) + (max(by) - min(by)) * .22
        out['edificios'].append({
            'nombre': n, 'letra': letra, 'texto': None if m else n,
            'tipo': f.get('tipo', 'normal'), 'anillos': [ring(x) for x in f['p']],
            'etiqueta': pt([cx, cy]), 'icono': ICONOS.get(n), 'subtitulo': SUB.get(f.get('n')),
            'nodos': f.get('nodos', []), 'origen': 'trazo propio' if f.get('propio') else 'OpenStreetMap'})

for n, (Lt, r) in calles.items():
    half = Lt / 2; acc = 0
    for i in range(1, len(r)):
        d = dist(r[i - 1], r[i])
        if acc + d >= half:
            t = (half - acc) / d
            p = [r[i - 1][0] + (r[i][0] - r[i - 1][0]) * t, r[i - 1][1] + (r[i][1] - r[i - 1][1]) * t]
            ang = math.degrees(math.atan2(r[i][1] - r[i - 1][1], r[i][0] - r[i - 1][0]))
            if ang > 90: ang -= 180
            if ang <= -90: ang += 180
            if lim['min_x'] + 5 < p[0] < lim['max_x'] - 5 and lim['min_y'] + 5 < p[1] < lim['max_y'] - 5:
                out['etiquetas_calles'].append({'texto': n, 'pos': pt(p), 'angulo_grados': round(ang, 1)})
            break
        acc += d

for q in D['lugares']:
    out['lugares'].append({'nombre': q['n'], 'lineas': q.get('l') or [q['n']], 'icono': q['ic'],
                           'pos': pt(q['p']), 'en_area_verde': bool(q.get('verde'))})
for k, n in (('EntradaA', 'Entrada Sur'), ('EntradaB', 'Entrada Principal'), ('EntradaC', 'Entrada Este')):
    out['entradas'].append({'nombre': n, 'nodo': k, 'pos': geo_a_local(*J[k])})
for i in range(1, 6):
    k = 'Estacionamiento%d' % i
    out['estacionamientos'].append({'nombre': 'Estacionamiento %d' % i, 'nodo': k, 'pos': geo_a_local(*J[k])})

json.dump(out, open(OUT, 'w'), ensure_ascii=False, separators=(',', ':'))
print({k: len(v) for k, v in out.items() if isinstance(v, list)}, lim)
