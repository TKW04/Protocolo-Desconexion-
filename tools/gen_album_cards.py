#!/usr/bin/env python3
"""Genera las fichas del album de Notas a partir de los sprites que ya existen.

docs/propuesta-asistentes-y-vidas.md §3.5 y §9: una ficha por tipo de ayuda
(data/help.json) con el primer cuadro de su sprite. Se recorta al contenido
opaco y, si pasa de MAX px, se reduce por un factor entero (cada bloque toma su
color opaco mas frecuente: no aparecen colores nuevos). La ficha queda centrada
en un lienzo de MAX x MAX px (px de pantalla: el album la dibuja a x1 en la
rejilla y a x2 en la vista de ficha). La silueta «???» es el mismo dibujo
relleno en `sombra` de assets/palettes/hub.gpl con un contorno de 1 px en
`base` (para que se lea sobre la celda oscura); el «???» lo escribe el album
con la fuente de textos.

Salidas (assets/sprites/ui/album/):
  album_card_<tipo>.png             ficha desbloqueada  64x64
  album_card_<tipo>_silhouette.png  silueta             64x64

Uso (desde la raiz del repo): python3 -I tools/gen_album_cards.py [--dry-run]
       [--preview <png>]
Validador: tools/validate_album_cards.py.
"""
import json
import os
import site
import sys
from collections import Counter

sys.path.append(site.getusersitepackages())
from PIL import Image  # noqa: E402

REPO = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = "assets/sprites/ui/album"
MAX = 64

# Tipo -> (PNG de origen, recorte del primer cuadro (x0, y0, x1, y1) o None, escala
# entera previa). attention_point se dibuja en el juego con el color del icono de
# puntos del HUD: su ficha es el icono del HUD a x2.
SOURCES = {
    "alert_bubble": ("assets/sprites/enemies/bubble_idle_00.png", None, 1),
    "attention_point": ("assets/sprites/ui/hud_attention.png", None, 2),
    "receiver": ("assets/sprites/tiles/mundo1_receiver.png", (0, 0, 64, 64), 1),
    "bridge": ("assets/sprites/tiles/mundo1_bridge.png", (0, 0, 64, 64), 1),
    "popup_blocker": ("assets/sprites/tiles/mundo1_popup.png", (0, 0, 192, 192), 1),
    "power_bank_pickup": ("assets/sprites/pickups/power_bank_full_00.png", None, 1),
    "sync_point": ("assets/sprites/tiles/mundo1_checkpoint.png", (64, 0, 128, 128), 1),
    "ability_pickup": ("assets/sprites/pickups/ability_pickup_idle_00.png", None, 1),
    "charger": ("assets/sprites/props/charger_ready_00.png", None, 1),
    "energy_drop": ("assets/sprites/pickups/energy_drop_idle_00.png", None, 2),
    "sync_drop": ("assets/sprites/pickups/sync_drop_idle_00.png", None, 2),
    "exit_terminal": ("assets/sprites/props/exit_terminal/terminal_prompt_00.png", None, 1),
    "glitch_wall": ("assets/sprites/tiles/mundo1_glitch_wall.png", (0, 0, 64, 64), 1),
    "extra_life": ("assets/sprites/pickups/extra_life_idle_00.png", None, 2),
    # Acertijo «Correo certificado» y chip del Debug del 1-2 (tools/gen_world1_puzzle.py).
    "laser_receiver": ("assets/sprites/props/laser_receiver_powered_00.png", None, 1),
    "relay_receiver": ("assets/sprites/props/relay_receiver_powered_00.png", None, 1),
    "ad_cover": ("assets/sprites/props/ad_cover_intact_00.png", None, 1),
    "debug_chip": ("assets/sprites/pickups/debug_chip_idle_00.png", None, 1),
    # Enemigos del 1-2 (tools/gen_world1_enemies.py): punto rojo despierto y el banner barriendo.
    "notification_badge": ("assets/sprites/enemies/badge_chase_00.png", None, 1),
    "spam_banner": ("assets/sprites/enemies/banner_sweep_00.png", None, 1),
    # Banner obligatorio con el dash del 1-3 (paso 4 de docs/propuesta-1-3.md): desde el paso 8, su
    # dibujo propio (el banner con el techo bajo y la estela del dash; tools/gen_world1_dnd.py).
    "spam_banner_dash": ("assets/sprites/props/dnd/banner_dash_card_00.png", None, 1),
    # Pisos 3 y 4 del 1-2 (tools/gen_world1_tower.py): recordatorio, Posponer listo, pop-up
    # translucido (ventana en miniatura) y la barra trabada en el 99 %.
    "reminder_platform": ("assets/sprites/props/tower/reminder_w1_idle_00.png", None, 1),
    "snooze_button": ("assets/sprites/props/tower/snooze_ready_00.png", None, 1),
    "overlay_popup": ("assets/sprites/props/tower/overlay_sample_00.png", None, 1),
    "update_bar": ("assets/sprites/props/tower/update_bar_stuck_00.png", None, 1),
    # Encuentro con Calc en la azotea del 1-2 (tools/gen_calc_encounter.py, tanda H1).
    "power_switch": ("assets/sprites/props/calc_room/power_switch_on_00.png", None, 1),
    "laser_switch": ("assets/sprites/props/calc_room/laser_switch_on_00.png", None, 1),
    "debug_switch": ("assets/sprites/props/calc_room/debug_switch_on_00.png", None, 1),
    "charge_dock": ("assets/sprites/props/calc_room/charge_dock_ready_00.png", None, 1),
    # Mensaje de secreto (tools/gen_memory_pickup.py; paso 4 de docs/propuesta-recuerdos.md).
    "memory_pickup": ("assets/sprites/pickups/memory_pickup_idle_00.png", None, 2),
    # 1-3 «No molestar» (tools/gen_world1_dnd.py; paso 8 de docs/propuesta-1-3.md).
    "dnd_switch": ("assets/sprites/props/dnd/dnd_switch_on_00.png", None, 1),
    "blink_platform": ("assets/sprites/props/dnd/blink_w1_on_04.png", None, 1),
    "alarm_bell": ("assets/sprites/enemies/alarm_bell/alarm_bell_ring_00.png", None, 1),
    # Jefe Alerta Mayor (paso 12 de docs/propuesta-jefe-alerta-mayor.md): el badge y la copia con el
    # arte FINAL del cuerpo (paso 16, tools/import_boss_alert_major.py: flotando y desinflada); el nucleo
    # marcado, el escudo y la notificacion de la rafaga siguen PROVISIONALES
    # (tools/gen_boss_alert_major.py); sus Burbujas (las de siempre) y el pop-up (la ventana en miniatura).
    "alert_major": ("assets/sprites/bosses/alert_major_hover_00.png", None, 1),
    "alert_major_core": ("assets/sprites/bosses/alert_major_core_card.png", None, 1),
    "alert_major_bubble": ("assets/sprites/enemies/bubble_idle_00.png", None, 1),
    "alert_major_popup": ("assets/sprites/props/tower/overlay_sample_00.png", None, 1),
    "boss_popup_shield": ("assets/sprites/bosses/alert_major_shield.png", None, 2),
    "notification_shot": ("assets/sprites/bosses/notification_shot.png", None, 1),
    "alert_major_clone": ("assets/sprites/bosses/alert_major_window_00.png", None, 1),
    # Mundo 2 (paso 4 de docs/propuesta-mundo-2.md §8): dibujos PROVISIONALES de tools/gen_world2_cards.py
    # (paleta provisional del Mundo 2) hasta el arte del mundo.
    "fragile_card": ("assets/sprites/props/world2/fragile_card_00.png", None, 1),
    "story_card": ("assets/sprites/props/world2/story_card_00.png", None, 1),
    "loop_section": ("assets/sprites/props/world2/loop_sign_00.png", None, 1),
    "autoplay_video": ("assets/sprites/props/world2/autoplay_video_00.png", None, 1),
    "video_clone": ("assets/sprites/props/world2/video_clone_00.png", None, 1),
    "commenter": ("assets/sprites/props/world2/commenter_00.png", None, 1),
    "loading_wall": ("assets/sprites/props/world2/loading_wall_00.png", None, 1),
    "pause_player": ("assets/sprites/props/world2/pause_player_00.png", None, 1),
    # Paso 11 (el 2-1 real): la hora (reloj del HUD) y el borde del feed, ayudas sobre carteles.
    "hud_clock": ("assets/sprites/props/world2/hud_clock_00.png", None, 1),
    "feed_edge": ("assets/sprites/props/world2/feed_edge_00.png", None, 1),
    # Jefe Autoplay (paso 20): arte PROVISIONAL del jefe (tools/gen_boss_autoplay.py, paleta B) hasta el
    # arte final (paso 23): la pantalla, el cabezal gris, el boton de pausa revelado, la cinta, la cuenta,
    # la miniatura de un clip y el abanico de la «Cuenta atras».
    "autoplay": ("assets/sprites/bosses/autoplay_screen_placeholder.png", None, 1),
    "autoplay_playhead": ("assets/sprites/bosses/autoplay_playhead_placeholder.png", None, 1),
    "autoplay_pause_button": ("assets/sprites/bosses/autoplay_pause_card_placeholder.png", None, 1),
    "autoplay_card": ("assets/sprites/bosses/autoplay_conveyor_card_placeholder.png", None, 1),
    "autoplay_countdown": ("assets/sprites/bosses/autoplay_countdown_card_placeholder.png", None, 1),
    "autoplay_clip": ("assets/sprites/bosses/autoplay_clip_card_placeholder.png", None, 1),
    "autoplay_fan": ("assets/sprites/bosses/autoplay_fan_card_placeholder.png", None, 1),
    # Mundo 3 (paso 9 de docs/propuesta-mundo-3.md §8): arte por script del mundo con la paleta elegida
    # (tools/gen_world3_objects.py y tools/gen_world3_enemies.py; el Influencer, PROVISIONAL hasta AutoSprite).
    "heart_pickup": ("assets/sprites/props/world3/heart_pickup_00.png", None, 2),
    "like_source": ("assets/sprites/props/world3/like_source_00.png", None, 1),
    "like_platform": ("assets/sprites/props/world3/like_platform_on_00.png", None, 1),
    "like_reset": ("assets/sprites/props/world3/like_reset_00.png", None, 1),
    "crop_tool": ("assets/sprites/props/world3/crop_tool_00.png", None, 1),
    "filter_zone": ("assets/sprites/props/world3/filter_zone_00.png", None, 1),
    "small_frame": ("assets/sprites/props/world3/small_frame_00.png", None, 1),
    "mirror": ("assets/sprites/props/world3/mirror_00.png", None, 1),
    "mirror_wall": ("assets/sprites/props/world3/mirror_wall_00.png", None, 1),
    "mirror_only": ("assets/sprites/props/world3/mirror_only_00.png", None, 1),
    "hunter_mirror": ("assets/sprites/props/world3/hunter_mirror_00.png", None, 1),
    "pose_plate": ("assets/sprites/props/world3/pose_plate_00.png", None, 2),
    "frame_door": ("assets/sprites/props/world3/frame_door_00.png", None, 1),
    "like_thief": ("assets/sprites/enemies/world3/like_thief_warn_00.png", None, 1),
    "influencer_bot": ("assets/sprites/enemies/world3/influencer_bot_placeholder_00.png", None, 1),
    "false_reflection": ("assets/sprites/enemies/world3/false_reflection_00.png", None, 1),
    # Paso 10 (el 3-1 real): el contador de likes del HUD, ayuda sobre el cartel de la sala de inicio.
    "hud_likes": ("assets/sprites/props/world3/hud_likes_00.png", None, 1),
    # Jefe La Curadora (paso 19 de docs/propuesta-mundo-3.md): arte PROVISIONAL del jefe
    # (tools/gen_boss_curator.py, paleta B) hasta el arte final del paso 23.
    "curator_boss": ("assets/sprites/bosses/curator_frame_placeholder.png", None, 1),
    "curator_lens": ("assets/sprites/bosses/curator_lens_card_placeholder.png", None, 1),
    "closing_frame": ("assets/sprites/bosses/curator_closing_frame_card_placeholder.png", None, 1),
}


def load_gpl(path):
    out = {}
    with open(path, encoding="utf-8") as fh:
        for line in fh:
            p = line.split()
            if len(p) >= 4 and all(v.isdigit() for v in p[:3]):
                out[p[3]] = tuple(int(v) for v in p[:3]) + (255,)
    return out


HUB = load_gpl(os.path.join(REPO, "assets", "palettes", "hub.gpl"))
SHADOW = HUB["sombra"]
OUTLINE = HUB["base"]


def help_types():
    with open(os.path.join(REPO, "data", "help.json"), encoding="utf-8") as fh:
        return list(json.load(fh)["types"].keys())


def reduce(img, factor):
    """Reduce por `factor` entero: cada bloque toma su color opaco mas frecuente
    si al menos la mitad del bloque es opaco; si no, transparente."""
    w, h = img.width // factor, img.height // factor
    out = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    src = img.load()
    dst = out.load()
    for y in range(h):
        for x in range(w):
            colors = Counter()
            for j in range(factor):
                for i in range(factor):
                    c = src[x * factor + i, y * factor + j]
                    if c[3] == 255:
                        colors[c] += 1
            if sum(colors.values()) * 2 >= factor * factor:
                dst[x, y] = colors.most_common(1)[0][0]
    return out


def card(help_type):
    path, box, scale = SOURCES[help_type]
    img = Image.open(os.path.join(REPO, path)).convert("RGBA")
    if box:
        img = img.crop(box)
    # Solo alfa 0 o 255 (los sprites ya lo cumplen; por si acaso).
    px = img.load()
    for y in range(img.height):
        for x in range(img.width):
            if 0 < px[x, y][3] < 255:
                px[x, y] = px[x, y][:3] + (255,) if px[x, y][3] >= 128 else (0, 0, 0, 0)
    img = img.crop(img.getbbox())
    if scale > 1:
        img = img.resize((img.width * scale, img.height * scale), Image.NEAREST)
    factor = 1
    while img.width / factor > MAX or img.height / factor > MAX:
        factor += 1
    if factor > 1:
        img = reduce(img, factor)
        img = img.crop(img.getbbox())
    out = Image.new("RGBA", (MAX, MAX), (0, 0, 0, 0))
    out.alpha_composite(img, ((MAX - img.width) // 2, (MAX - img.height) // 2))
    return out


def silhouette(img):
    out = Image.new("RGBA", img.size, (0, 0, 0, 0))
    src, dst = img.load(), out.load()
    w, h = img.size
    for y in range(h):
        for x in range(w):
            if src[x, y][3] == 255:
                dst[x, y] = SHADOW
    for y in range(h):
        for x in range(w):
            if src[x, y][3] == 255:
                continue
            for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                qx, qy = x + dx, y + dy
                if 0 <= qx < w and 0 <= qy < h and src[qx, qy][3] == 255:
                    dst[x, y] = OUTLINE
                    break
    return out


def outputs():
    """{nombre de archivo: imagen} (orden estable). Tipos de help.json sin
    sprite en SOURCES no tienen ficha (el album dibuja solo el «???»/nombre)."""
    out = {}
    for t in help_types():
        if t not in SOURCES:
            continue
        im = card(t)
        out[f"album_card_{t}.png"] = im
        out[f"album_card_{t}_silhouette.png"] = silhouette(im)
    return out


def main(argv):
    imgs = outputs()
    if "--dry-run" not in argv:
        os.makedirs(os.path.join(REPO, OUT), exist_ok=True)
        for k, im in imgs.items():
            im.save(os.path.join(REPO, OUT, k), optimize=True)
    if "--preview" in argv:
        names = sorted(imgs)
        sheet = Image.new("RGBA", (len(names) * 140 + 10, 150), HUB["fondo_profundo"])
        for i, k in enumerate(names):
            im = imgs[k].resize((128, 128), Image.NEAREST)
            sheet.alpha_composite(im, (10 + i * 140, 10))
        sheet.save(argv[argv.index("--preview") + 1])
    print(f"{len(imgs)} PNG")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
