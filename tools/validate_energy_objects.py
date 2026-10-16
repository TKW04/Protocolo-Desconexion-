#!/usr/bin/env python3
"""Valida los sprites de energia y progreso (tools/gen_energy_objects.py).

Para cada PNG de assets/sprites/pickups/ y assets/sprites/props/ comprueba tamano,
colores solo de mundo1.gpl + effects_pulse.gpl, alfa 0 o 255 y fondo transparente
(check_asset de tools/validate_world1_assets.py).

Uso (desde la raiz del repo): python3 tools/validate_energy_objects.py
Sale con 1 si hay errores. Pillow puede estar en el site de usuario: se anade a
sys.path a mano para que funcione tambien con python3 -I.
"""
import glob
import os
import site
import sys

sys.path.append(site.getusersitepackages())
TOOLS = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.dirname(TOOLS)
sys.path.insert(0, TOOLS)
from validate_world1_assets import check_asset, load_gpl  # noqa: E402

SIZES = {"energy_drop": (32, 32), "sync_drop": (32, 32), "ability_pickup": (40, 40),
         "power_bank": (32, 48), "charger": (32, 64), "extra_life": (32, 32)}


def main():
    pal = (load_gpl(os.path.join(REPO, "assets/palettes/mundo1.gpl"), set())
           | load_gpl(os.path.join(REPO, "assets/palettes/effects_pulse.gpl"), set()))
    files = sorted(glob.glob(os.path.join(REPO, "assets/sprites/pickups/*.png"))
                   + glob.glob(os.path.join(REPO, "assets/sprites/props/*.png")))
    errs = []
    for f in files:
        key = next((k for k in SIZES if os.path.basename(f).startswith(k)), None)
        if key is None:
            errs.append(f"{f}: prefijo desconocido")
            continue
        errs += check_asset({"path": f, "frame_size": list(SIZES[key]), "columns": 1, "rows": 1,
                             "needs_transparency": True, "seamless_x": False}, pal)
    print("\n".join(errs) if errs else f"OK ({len(files)} PNG, {len(pal)} colores: mundo1 + effects_pulse)")
    return 1 if errs else 0


if __name__ == "__main__":
    sys.exit(main())
