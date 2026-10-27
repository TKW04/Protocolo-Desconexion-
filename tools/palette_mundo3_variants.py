"""Variantes de paleta del Mundo 3 «La Vitrina» (paso 9 de docs/propuesta-mundo-3.md §8 y §6.1).

ELEGIDA LA B (2026-10-26, por el orquestador con la autoridad delegada por el usuario; razon en
docs/propuesta-mundo-3.md §8.1, paso 9): pasa las 5 reglas de §6.1 con el mayor margen minimo y su malva de
trastienda es el mas «galeria» (fondo de terciopelo, oro viejo apagado). Se puede cambiar en cualquier momento:
  python3 -I tools/palette_mundo3_preview.py --apply A|B|C
(pone ACTIVE aqui, reescribe assets/palettes/mundo3.gpl y la seccion palette de data/world3_objects.json y
regenera el arte por script del Mundo 3 y las fichas del album). Comparativa con maqueta y medidas:
docs/arte/mundo3_paleta_variantes.png (python3 -I tools/palette_mundo3_preview.py).

Las tres usan los MISMOS nombres que la provisional del paso 0 (el juego lee los colores por nombre de la seccion
palette de data/world3_objects.json), el mismo Debug verde acido (#a6ff2e, fijado en data/hud.json) y reservan los
del Mundo 1 que significan algo en todo el juego: alerta / alerta_sombra (dano) y ambar / ambar_sombra (puntos de
atencion). Cambian el malva del fondo, el dorado de los marcos y el rosa.
"""

## Variante que usa el juego. None = la paleta PROVISIONAL de desarrollo. La escribe --apply; no editar a mano.
ACTIVE = "B"

## Debug del Mundo 3 (no cambia entre variantes: debug_colors["3"] de data/hud.json).
DEBUG_HEX = "a6ff2e"

# Por variante: titulo, como resuelve las reglas de §6.1 (una linea) y los hex por nombre (16).
VARIANTS = {
    "A": {
        "title": "Ciruela y oro viejo (provisional pulida)",
        "how": "La provisional del paso 0 con el dorado centrado en su tono y el malva algo mas oscuro: "
               "Isak y Eco pasan por poco (3,4:1).",
        "hex": {
            "galeria_noche": "1e1426", "trastienda_fondo": "583a60", "trastienda_medio": "684a70",
            "trastienda_luz": "8a6a92", "marco_sombra": "5e4b2a", "dorado": "b6a25e", "dorado_luz": "dccb90",
            "rosa_pastel": "f6c8dc", "rosa_sombra": "b88aa2", "corazon_rosa": "ffaad2",
            "blanco_brillante": "fbf8fc", "gris_perla": "c8bccb",
            "alerta": "ff4a2a", "alerta_sombra": "a3221c", "ambar": "ffa000", "ambar_sombra": "a85f00",
        },
    },
    "B": {
        "title": "Terciopelo de trastienda",
        "how": "Malva profundo de terciopelo (el de una trastienda de galeria): Isak y Eco a 4,2-4,3:1; oro viejo "
               "mas apagado (43 %) y rosa mas claro (L 89), los dos mas lejos del ambar y del rojo.",
        "hex": {
            "galeria_noche": "180f20", "trastienda_fondo": "4a2f55", "trastienda_medio": "5a3d66",
            "trastienda_luz": "7e5f8c", "marco_sombra": "54442a", "dorado": "b0a064", "dorado_luz": "d6c896",
            "rosa_pastel": "f8d6e8", "rosa_sombra": "a8809a", "corazon_rosa": "ffb0d8",
            "blanco_brillante": "fcf8fc", "gris_perla": "c4b8cc",
            "alerta": "ff4a2a", "alerta_sombra": "a3221c", "ambar": "ffa000", "ambar_sombra": "a85f00",
        },
    },
    "C": {
        "title": "Lavanda gris y champán",
        "how": "Malva grisaceo y dorado champan muy apagado (33 %): el dorado mas lejos del ambar, pero el fondo "
               "mas claro deja a Isak y a Eco justos (3,4:1).",
        "hex": {
            "galeria_noche": "221a2a", "trastienda_fondo": "544260", "trastienda_medio": "604e6c",
            "trastienda_luz": "8e7a96", "marco_sombra": "645a3c", "dorado": "c4b482", "dorado_luz": "e2d8b0",
            "rosa_pastel": "f8d4e2", "rosa_sombra": "bc98aa", "corazon_rosa": "ffb4d4",
            "blanco_brillante": "fefcfc", "gris_perla": "d0c6d0",
            "alerta": "ff4a2a", "alerta_sombra": "a3221c", "ambar": "ffa000", "ambar_sombra": "a85f00",
        },
    },
}

## Colores que ninguna variante puede cambiar (significan lo mismo en todo el juego).
RESERVED = {"alerta": "ff4a2a", "alerta_sombra": "a3221c", "ambar": "ffa000", "ambar_sombra": "a85f00"}


def rows(variant_id, base_rows):
    """Filas (nombre, hex, funcion) de la variante con las funciones de la provisional (base_rows)."""
    hexes = VARIANTS[variant_id]["hex"]
    return [(name, hexes[name], role) for name, _value, role in base_rows]
