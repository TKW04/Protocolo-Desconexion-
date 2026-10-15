#!/usr/bin/env python3
"""Genera los sprites de energia y progreso del 1-1 (estilo circuito limpio).

Objetos: drop de energia, drop de Sync Rate, power bank, estacion de carga y
punto de habilidad. Solo colores de assets/palettes/mundo1.gpl y
assets/palettes/effects_pulse.gpl. Fondo transparente, alfa 0 o 255.

Uso (desde la raiz del repo):
  python3 tools/gen_energy_objects.py [--dry-run] [--preview <png> [--scale N]]
Escribe en assets/sprites/pickups/ y assets/sprites/props/ (la raiz se deduce de
la ubicacion del script). --dry-run no escribe los PNG; --preview guarda una hoja
ampliada (x8 por defecto) para revisarlos. Validador: tools/validate_energy_objects.py.
Pillow puede estar en el site de usuario (pip install --user Pillow); se anade a
sys.path a mano para que el script funcione tambien con python3 -I.
"""
import os
import site
import sys

# Con -I no se carga el site de usuario (donde esta Pillow): se anade a mano.
sys.path.append(site.getusersitepackages())
from PIL import Image  # noqa: E402


def load_gpl(path):
    out = {}
    with open(path, encoding="utf-8") as fh:
        for line in fh:
            s = line.strip()
            if not s or s.startswith("#") or s.startswith("GIMP") or ":" in s.split()[0]:
                continue
            p = s.split()
            if len(p) >= 4 and all(v.isdigit() for v in p[:3]):
                out[p[3]] = tuple(int(v) for v in p[:3]) + (255,)
    return out


REPO = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
PAL = load_gpl(os.path.join(REPO, "assets/palettes/mundo1.gpl"))
PAL.update(load_gpl(os.path.join(REPO, "assets/palettes/effects_pulse.gpl")))
N = PAL["noche_profunda"]
TS = PAL["tile_sombra"]
TB = PAL["tile_base"]
TL = PAL["tile_luz"]
BL = PAL["borde_luz"]
W = PAL["banner_blanco"]
G = PAL["banner_gris"]
R = PAL["resplandor"]
FM = PAL["fondo_medio"]
C = PAL["debug_cian"]
CD = PAL["pulse_dim"]
CC = PAL["pulse_core"]


class Canvas:
    def __init__(self, w, h):
        self.img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
        self.px = self.img.load()
        self.w, self.h = w, h

    def p(self, x, y, c):
        if 0 <= x < self.w and 0 <= y < self.h:
            self.px[x, y] = c

    def get(self, x, y):
        return self.px[x, y]

    def rect(self, x0, y0, x1, y1, c):  # inclusivo
        for y in range(y0, y1 + 1):
            for x in range(x0, x1 + 1):
                self.p(x, y, c)

    def hline(self, x0, x1, y, c):
        self.rect(x0, y, x1, y, c)

    def vline(self, x, y0, y1, c):
        self.rect(x, y0, x, y1, c)

    def box(self, x0, y0, x1, y1, fill, outline=N, cut=True):
        """Caja con contorno de 1 px y esquinas cortadas (aspecto redondeado limpio)."""
        self.rect(x0, y0, x1, y1, outline)
        self.rect(x0 + 1, y0 + 1, x1 - 1, y1 - 1, fill)
        if cut:
            for x, y in ((x0, y0), (x1, y0), (x0, y1), (x1, y1)):
                self.px[x, y] = (0, 0, 0, 0)

    def sparkle(self, x, y, core=CC, arm=CD, big=False):
        """Brillo limpio en cruz: centro y brazos de 1 px (2 si big)."""
        self.p(x, y, core)
        for d in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            self.p(x + d[0], y + d[1], arm)
            if big:
                self.p(x + 2 * d[0], y + 2 * d[1], arm)

    def halo(self, color, only_dirs=None):
        """Anillo de 1 px alrededor de lo opaco (brillo); no pisa lo opaco."""
        opaque = {(x, y) for y in range(self.h) for x in range(self.w) if self.px[x, y][3] == 255}
        ring = set()
        for (x, y) in opaque:
            for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                q = (x + dx, y + dy)
                if q not in opaque and 0 <= q[0] < self.w and 0 <= q[1] < self.h:
                    ring.add(q)
        for (x, y) in ring:
            if only_dirs is None or only_dirs(x, y):
                self.px[x, y] = color


def stamp(cv, ox, oy, rows, cmap):
    for j, row in enumerate(rows):
        for i, ch in enumerate(row):
            if ch in cmap:
                cv.p(ox + i, oy + j, cmap[ch])


# Rayo (8x12) usado en drop, estacion de carga y power bank lleno.
BOLT = [
    "....####",
    "...####.",
    "..####..",
    ".####...",
    "#######.",
    "######..",
    "..####..",
    ".####...",
    ".###....",
    "###.....",
    "##......",
    "#.......",
]


# ------------------------------------------------------------------ drops (32x32)
def energy_drop(f):
    cv = Canvas(32, 32)
    # celda vertical de bateria: cuerpo 12x18, borne 6x3
    x0, y0, x1, y1 = 10, 9, 21, 27
    cv.box(13, 6, 18, 9, G)            # borne (metal)
    cv.hline(14, 17, 7, W)
    cv.box(x0, y0, x1, y1, C)
    cv.vline(x0 + 1, y0 + 2, y1 - 2, CC)   # brillo lateral limpio
    cv.hline(x0 + 2, x1 - 1, y1 - 1, CD)   # base algo mas oscura
    stamp(cv, 12, 12, BOLT, {"#": N})
    # pads de circuito a los lados (nodos)
    for y in (13, 22):
        cv.p(x0 - 1, y, N); cv.p(x0 - 2, y, CD)
        cv.p(x1 + 1, y, N); cv.p(x1 + 2, y, CD)
    # animacion: 0 base, 1 halo tenue, 2 halo + brillos, 3 brillo bajando
    if f in (1, 2):
        cv.halo(CD, only_dirs=(lambda x, y: (x + y) % 2 == 0) if f == 1 else None)
    if f == 2:
        cv.sparkle(6, 7, big=True)
        cv.sparkle(25, 24)
    if f == 3:
        cv.sparkle(26, 9)
        cv.p(x0 + 1, y0 + 2, W)
    return cv.img


def sync_drop(f):
    cv = Canvas(32, 32)
    # nodo redondo de senal (octogono 20x20) blanco con 3 barras de senal
    cx0, cy0, cx1, cy1 = 6, 6, 25, 25
    cv.rect(cx0, cy0, cx1, cy1, N)
    for k in range(4):  # esquinas cortadas en diagonal (octogono)
        for i in range(4 - k):
            for (x, y) in ((cx0 + i, cy0 + k), (cx1 - i, cy0 + k), (cx0 + i, cy1 - k), (cx1 - i, cy1 - k)):
                cv.px[x, y] = (0, 0, 0, 0)
    # contorno N ya esta en el borde; anillo blanco interior y fondo oscuro
    inner = [(x, y) for y in range(cy0, cy1 + 1) for x in range(cx0, cx1 + 1) if cv.get(x, y)[3]]
    inset = set()
    for (x, y) in inner:
        if all(cv.get(x + dx, y + dy)[3] for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1))
               if 0 <= x + dx < 32 and 0 <= y + dy < 32):
            inset.add((x, y))
    for (x, y) in inset:
        cv.px[x, y] = W
    core = set()
    for (x, y) in inset:
        if all((x + dx, y + dy) in inset for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1))):
            core.add((x, y))
    for (x, y) in core:
        cv.px[x, y] = TB
    # sombra del anillo abajo-derecha
    for (x, y) in inset - core:
        if x > 18 and y > 18 or (x >= 23) or (y >= 23):
            cv.px[x, y] = G
    # barras de senal (como el HUD): base comun y=20, alturas 4, 7, 10
    lit = {0: 1, 1: 2, 2: 3, 3: 3}[f]
    for i, h in enumerate((4, 7, 10)):
        bx = 11 + i * 4
        col, shade = (W, G) if i < lit else (TL, TL)
        cv.rect(bx, 21 - h, bx + 1, 20, col)
        cv.vline(bx + 1, 21 - h + 1, 20, shade)
    # pequena cruz de curacion (sumar) arriba-izquierda, en blanco
    cv.p(12, 11, W); cv.p(11, 11, W); cv.p(13, 11, W); cv.p(12, 10, W); cv.p(12, 12, W)
    # nodos de circuito a los lados
    for y in (15, 16):
        cv.p(5, y, N); cv.p(26, y, N)
    cv.p(4, 15, G); cv.p(27, 16, G)
    if f == 3:
        cv.halo(BL, only_dirs=lambda x, y: (x + y) % 2 == 0)
        cv.sparkle(25, 6, core=W, arm=BL, big=True)
    return cv.img


# ------------------------------------------------------------ power bank (32x48)
def power_bank(level, f):
    """level: 0 vacio, 2 parcial, 4 lleno (segmentos encendidos de 4)."""
    cv = Canvas(32, 48)
    x0, y0, x1, y1 = 6, 9, 25, 44
    # puerto superior (USB) y nodo
    cv.box(12, 5, 19, 9, G)
    cv.hline(14, 17, 7, N)
    cv.box(x0, y0, x1, y1, TL)
    cv.vline(x0 + 1, y0 + 2, y1 - 2, BL)      # bisel claro
    cv.hline(x0 + 2, x1 - 2, y0 + 1, BL)
    cv.vline(x1 - 1, y0 + 2, y1 - 1, TB)      # sombra
    cv.hline(x0 + 2, x1 - 1, y1 - 1, TB)
    # ventana de segmentos
    wx0, wy0, wx1, wy1 = 10, 13, 21, 36
    cv.box(wx0, wy0, wx1, wy1, TS, cut=False)
    for i in range(4):  # segmento 0 abajo
        sy1 = wy1 - 2 - i * 5
        sy0 = sy1 - 3
        on = i < level
        blink = level == 2 and i == level - 1 and f == 1
        if on and not blink:
            cv.rect(wx0 + 2, sy0, wx1 - 2, sy1, C)
            cv.hline(wx0 + 2, wx1 - 2, sy0, CC)
        else:
            cv.rect(wx0 + 2, sy0, wx1 - 2, sy1, TB)
            cv.hline(wx0 + 2, wx1 - 2, sy0, TL if not on else CD)
    # traza de circuito grabada: del puerto baja por la izquierda a un nodo
    cv.vline(8, 13, 38, R)
    cv.hline(8, 12, 39, R)
    cv.rect(13, 39, 14, 40, BL)   # nodo
    cv.vline(23, 15, 30, R)
    cv.rect(22, 31, 23, 32, BL)
    # LED de estado (abajo-derecha)
    if level == 0:
        led = W if f == 0 else TB
    elif level == 4:
        led = CC if f == 0 else C
    else:
        led = C if f == 0 else CD
    cv.rect(18, 39, 20, 40, led)
    if level == 4:
        if f == 1:
            cv.halo(CD)
            cv.sparkle(26, 6, big=True)
    return cv.img


# ---------------------------------------------------------- estacion (32x64)
def charger(state, f=0, progress=0.0):
    """state: ready (f 0-3), cooling (progress 0..1), spent."""
    cv = Canvas(32, 64)
    # base
    cv.box(2, 57, 29, 63, TL)
    cv.hline(3, 28, 58, BL)
    cv.hline(3, 28, 62, TB)
    # columna
    cv.box(9, 27, 22, 57, TB, cut=False)
    cv.vline(10, 28, 56, TL)
    # cabezal con pantalla
    cv.box(4, 1, 27, 28, TL)
    cv.hline(5, 26, 2, BL)
    cv.vline(5, 3, 26, BL)
    cv.vline(26, 3, 27, TB)
    cv.hline(6, 26, 27, TB)
    sx0, sy0, sx1, sy1 = 7, 4, 24, 24
    cv.box(sx0, sy0, sx1, sy1, TS, cut=False)
    # trazas de la columna (con nodos)
    trace = TB if state == "spent" else R
    cv.vline(13, 30, 54, trace)
    cv.vline(18, 30, 50, trace)
    cv.hline(18, 20, 51, trace)
    for (nx, ny) in ((12, 54), (17, 30), (19, 51), (12, 40)):
        cv.rect(nx, ny, nx + 1, ny + 1, TL if state == "spent" else BL)
    # rayo en la pantalla (8x12 escalado a 2x en vertical? no: centrado tal cual con borde)
    bx, by = 12, 8
    bolt = [(bx + i, by + j) for j, row in enumerate(BOLT) for i, ch in enumerate(row) if ch == "#"]
    # contorno del rayo
    bset = set(bolt)
    ring = {(x + dx, y + dy) for (x, y) in bolt for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1))} - bset
    if state == "ready":
        for q in ring:
            cv.p(*q, CD)
        for q in bolt:
            cv.p(*q, C)
        cv.p(bx + 4, by + 4, CC); cv.p(bx + 3, by + 5, CC); cv.p(bx + 5, by + 1, CC)
        # pulso que sube por las trazas (4 posiciones)
        ys = (52, 45, 38, 31)
        y = ys[f]
        cv.rect(13, y - 1, 13, y + 1, C); cv.p(13, y - 2, CC)
        y2 = ys[(f + 2) % 4]
        if y2 <= 50:
            cv.rect(18, y2 - 1, 18, y2 + 1, C)
        # barra inferior de pantalla: lista
        cv.hline(sx0 + 2, sx1 - 2, sy1 - 2, C)
        if f == 0:
            cv.sparkle(25, 3, big=True)
        if f == 2:
            cv.sparkle(6, 25)
    elif state == "cooling":
        for q in ring:
            cv.p(*q, R)
        for q in bolt:
            cv.p(*q, TB)
        # el rayo se rellena desde abajo con cian tenue segun el progreso
        top, bottom = by, by + len(BOLT) - 1
        level = bottom + 1 - round(progress * len(BOLT))
        for (x, y) in bolt:
            if y >= level:
                cv.p(x, y, CD)
        # barra de progreso al pie de la pantalla
        width = sx1 - sx0 - 3
        filled = round(progress * width)
        cv.hline(sx0 + 2, sx1 - 2, sy1 - 2, TB)
        if filled:
            cv.hline(sx0 + 2, sx0 + 1 + filled, sy1 - 2, CD)
    else:  # spent
        for q in ring:
            cv.p(*q, TB)
    return cv.img


# ------------------------------------------------------- habilidad (40x40)
def ability(state, f=0):
    cv = Canvas(40, 40)
    on = state == "available"
    x0, y0, x1, y1 = 10, 10, 29, 29
    pins = (14, 19, 24)
    lit_side = f % 4  # 0 arriba, 1 derecha, 2 abajo, 3 izquierda
    # patas del chip (3 por lado)
    for side in range(4):
        pcol = G if on else TL
        if on and side == lit_side:
            pcol = C
        for p in pins:
            if side == 0:
                cv.rect(p, 6, p + 1, 9, N); cv.rect(p, 6, p + 1, 8, pcol)
            elif side == 2:
                cv.rect(p, 30, p + 1, 33, N); cv.rect(p, 31, p + 1, 33, pcol)
            elif side == 3:
                cv.rect(6, p, 9, p + 1, N); cv.rect(6, p, 8, p + 1, pcol)
            else:
                cv.rect(30, p, 33, p + 1, N); cv.rect(31, p, 33, p + 1, pcol)
    # cuerpo
    cv.box(x0, y0, x1, y1, TB if on else TS)
    cv.hline(x0 + 1, x1 - 1, y0 + 1, TL if on else TB)
    cv.vline(x0 + 1, y0 + 1, y1 - 1, TL if on else TB)
    cv.hline(x0 + 2, x1 - 1, y1 - 1, TS)
    # muesca de orientacion
    cv.p(x0 + 3, y0 + 3, BL if on else TL)
    # trazas internas de las patas al nucleo
    tr = R if on else TB
    for p in (14, 24):
        cv.vline(p, y0 + 2, 15, tr); cv.vline(p, 24, y1 - 2, tr)
        cv.hline(x0 + 2, 15, p, tr); cv.hline(24, x1 - 2, p, tr)
    if on:
        trl = C
        if lit_side == 0:
            cv.vline(14, y0 + 2, 15, trl); cv.vline(24, y0 + 2, 15, trl)
        elif lit_side == 1:
            cv.hline(24, x1 - 2, 14, trl); cv.hline(24, x1 - 2, 24, trl)
        elif lit_side == 2:
            cv.vline(14, 24, y1 - 2, trl); cv.vline(24, 24, y1 - 2, trl)
        else:
            cv.hline(x0 + 2, 15, 14, trl); cv.hline(x0 + 2, 15, 24, trl)
    # nucleo 8x8
    cv.box(16, 16, 23, 23, C if on else TB, cut=False)
    if on:
        cv.rect(17, 17, 22, 22, C)
        cv.rect(18, 18, 21, 21, CC if f in (1, 3) else C)
        cv.rect(19, 19, 20, 20, W if f == 1 else CC)
        cv.hline(17, 22, 22, CD); cv.vline(22, 17, 22, CD)
        cv.rect(16, 16, 23, 16, N); cv.rect(16, 23, 23, 23, N)
        cv.vline(16, 16, 23, N); cv.vline(23, 16, 23, N)
        if f == 1:
            cv.sparkle(5, 5, big=True)
        if f == 3:
            cv.sparkle(35, 35, big=True)
    else:
        cv.rect(19, 19, 20, 20, TL)
    return cv.img


def outputs():
    out = {}
    for f in range(4):
        out[f"pickups/energy_drop_idle_{f:02d}.png"] = energy_drop(f)
        out[f"pickups/sync_drop_idle_{f:02d}.png"] = sync_drop(f)
        out[f"pickups/ability_pickup_idle_{f:02d}.png"] = ability("available", f)
        out[f"props/charger_ready_{f:02d}.png"] = charger("ready", f)
    out["pickups/ability_pickup_collected_00.png"] = ability("collected")
    for name, lvl in (("empty", 0), ("partial", 2), ("full", 4)):
        for f in range(2):
            out[f"pickups/power_bank_{name}_{f:02d}.png"] = power_bank(lvl, f)
    for i in range(8):
        out[f"props/charger_cooling_{i:02d}.png"] = charger("cooling", progress=i / 7 * 0.875 + 0.0)
    out["props/charger_spent_00.png"] = charger("spent")
    return out


def preview(imgs, path, scale=8):
    bg = PAL["cielo"]
    groups = {}
    for k, im in imgs.items():
        base = os.path.basename(k).rsplit("_", 1)[0]
        groups.setdefault(base, []).append(im)
    pad = 8
    rows = list(groups.items())
    width = max(sum(im.width + pad for im in ims) for _, ims in rows) * scale + pad * scale
    height = sum(max(im.height for im in ims) + pad for _, ims in rows) * scale + pad * scale
    sheet = Image.new("RGBA", (width, height), bg)
    y = pad * scale
    for _, ims in rows:
        x = pad * scale
        for im in ims:
            big = im.resize((im.width * scale, im.height * scale), Image.NEAREST)
            sheet.alpha_composite(big, (x, y))
            x += (im.width + pad) * scale
        y += (max(im.height for im in ims) + pad) * scale
    sheet.save(path)


if __name__ == "__main__":
    imgs = outputs()
    dest = os.path.join(REPO, "assets/sprites")
    if "--dry-run" not in sys.argv:
        for k, im in imgs.items():
            p = os.path.join(dest, k)
            os.makedirs(os.path.dirname(p), exist_ok=True)
            im.save(p)
    if "--preview" in sys.argv:
        preview(imgs, sys.argv[sys.argv.index("--preview") + 1],
                int(sys.argv[sys.argv.index("--scale") + 1]) if "--scale" in sys.argv else 8)
    print(f"{len(imgs)} PNG")
