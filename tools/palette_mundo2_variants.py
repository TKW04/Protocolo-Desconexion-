"""Variantes de paleta del Mundo 2 «El Feed» para el arte final (paso 10 de docs/propuesta-mundo-2.md, fase A).

ELEGIDA LA B (2026-10-22, fase B): el usuario comparo las variantes en docs/arte/mundo2_paleta_variantes.png
(tools/palette_mundo2_preview.py) y eligio la B con el Debug algo mas oscuro (#ffa858 en lugar de #ffc070).
Con ACTIVE = None el juego usaria la paleta PROVISIONAL de tools/palette_mundo2_provisional.py.

Las tres usan los MISMOS nombres que la provisional (el juego lee los colores por nombre de la seccion palette de
data/world2_objects.json) y reservan los del Mundo 1 que significan algo en todo el juego: alerta / alerta_sombra
(dano) y ambar / ambar_sombra (puntos de atencion, icono del HUD, brillo de Eco con la Q). Lo que cambia es el
fondo, las tarjetas, el magenta y el color del Debug, que es donde estan los dos choques de §6.1:
  - Debug ambar frente al ambar de los puntos;
  - magenta frente al rojo de dano.

Elegir una (fase B, un solo comando; ver tools/palette_mundo2_preview.py --apply):
  python3 -I tools/palette_mundo2_preview.py --apply B
pone ACTIVE = "B" aqui, escribe assets/palettes/mundo2.gpl y la seccion palette, sincroniza el Debug del Mundo 2
de data/hud.json (debug_colors["2"]) y regenera los dibujos del Mundo 2 y las fichas del album.
"""

## Variante que usa el juego. None = la paleta PROVISIONAL de desarrollo. La escribe --apply; no editar a mano.
ACTIVE = "B"

# Por variante: titulo, como resuelve los choques (una linea) y los hex por nombre (16 + debug_ambar).
VARIANTS = {
    "A": {
        "title": "Neón violeta (provisional pulida)",
        "how": "Separa por TONO: Debug naranja (29°) frente al ámbar de los puntos (38°); "
               "magenta neón a 303° sobre el violeta de la provisional. El Debug se acerca algo al rojo de daño.",
        "hex": {
            "feed_noche": "140a24", "feed_fondo": "2a1450", "feed_medio": "45207a", "feed_resplandor": "6a3cb0",
            "tarjeta_sombra": "120a20", "tarjeta_base": "2a1d45", "tarjeta_luz": "4a3a78",
            "tarjeta_borde": "b7a3f0", "blanco": "f4f0fa", "gris": "b8aecf",
            "alerta": "ff4a2a", "alerta_sombra": "a3221c", "magenta": "ff40f6", "magenta_sombra": "8a1a8c",
            "ambar": "ffa000", "ambar_sombra": "a85f00",
            "debug_ambar": "ff8a1c",
        },
    },
    "B": {
        "title": "Índigo frío y Debug miel",
        "how": "Separa por LUZ Y SATURACIÓN: Debug miel tostado (29°, más claro y menos saturado) frente al ámbar "
               "saturado de los puntos; fondo índigo (opuesto al ámbar) y magenta claro a 302°, lejos del rojo.",
        "hex": {
            "feed_noche": "0d0b24", "feed_fondo": "1f1a52", "feed_medio": "33287a", "feed_resplandor": "5243b4",
            "tarjeta_sombra": "0c0a1f", "tarjeta_base": "221e46", "tarjeta_luz": "3f3a7a",
            "tarjeta_borde": "a9a6f2", "blanco": "f2f2fa", "gris": "aeb0d2",
            "alerta": "ff4a2a", "alerta_sombra": "a3221c", "magenta": "ff5cfa", "magenta_sombra": "7a2290",
            "ambar": "ffa000", "ambar_sombra": "a85f00",
            "debug_ambar": "ffa858",  # 2026-10-22: antes ffc070 (el usuario lo quiso algo mas oscuro)
        },
    },
    "C": {
        "title": "Ciruela cálida y Debug naranja",
        "how": "Separa por TONO FUERTE: Debug naranja intenso (27°), el más cercano al rojo de daño; "
               "fondo ciruela cálido y magenta más oscuro (302°).",
        "hex": {
            "feed_noche": "1a0a1c", "feed_fondo": "361440", "feed_medio": "52205e", "feed_resplandor": "803a96",
            "tarjeta_sombra": "170a18", "tarjeta_base": "34203e", "tarjeta_luz": "563c66",
            "tarjeta_borde": "dca8e8", "blanco": "faf0f6", "gris": "cfb0c8",
            "alerta": "ff4a2a", "alerta_sombra": "a3221c", "magenta": "e640e0", "magenta_sombra": "7a1a78",
            "ambar": "ffa000", "ambar_sombra": "a85f00",
            "debug_ambar": "ff7a10",
        },
    },
}

## Colores que ninguna variante puede cambiar (significan lo mismo en todo el juego).
RESERVED = {"alerta": "ff4a2a", "alerta_sombra": "a3221c", "ambar": "ffa000", "ambar_sombra": "a85f00"}


def rows(variant_id, base_rows):
    """Filas (nombre, hex, funcion) de la variante con las funciones de la provisional (base_rows)."""
    hexes = VARIANTS[variant_id]["hex"]
    return [(name, hexes[name], role) for name, _value, role in base_rows]
