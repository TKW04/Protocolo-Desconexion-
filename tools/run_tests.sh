#!/usr/bin/env bash
# Ejecuta la suite de GUT en modo headless y devuelve el codigo de salida de GUT
# (o 4 si fallan las pruebas Python: esquema y alcanzabilidad de niveles, escena
# generada al dia, fuente de textos), 5 si la suite creo o cambio el guardado
# real del jugador (user://save.json) o sus ajustes reales (user://settings.cfg;
# se compara su huella, nunca se borran) o 6
# si GUT no pudo cargar algun script (error de sintaxis: GUT lo ignora y saldria
# en verde) o no ejecuto algun tests/test_*.gd (tools/check_gut_log.sh; con
# opciones extra de GUT, p. ej. -gselect, solo se comprueban los errores de carga).
# Antes importa el proyecto (registra class_name nuevos e importa recursos);
# su salida solo se muestra si falla.
# Uso: tools/run_tests.sh [opciones extra de GUT]
# La ruta de Godot se puede cambiar con la variable GODOT.
set -u

GODOT="${GODOT:-/Applications/Godot.app/Contents/MacOS/Godot}"
PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

if [[ ! -x "$GODOT" ]]; then
	echo "run_tests.sh: no se encuentra Godot en '$GODOT' (define GODOT)." >&2
	exit 2
fi

# Guardado real del jugador (user://save.json); ISAK_REAL_SAVE cambia la ruta.
APP_NAME="$(sed -n 's/^config\/name="\(.*\)"$/\1/p' "$PROJECT_DIR/project.godot")"
if [[ "$(uname)" == "Darwin" ]]; then
	REAL_SAVE_DEFAULT="$HOME/Library/Application Support/Godot/app_userdata/$APP_NAME/save.json"
else
	REAL_SAVE_DEFAULT="${XDG_DATA_HOME:-$HOME/.local/share}/godot/app_userdata/$APP_NAME/save.json"
fi
REAL_SAVE="${ISAK_REAL_SAVE:-$REAL_SAVE_DEFAULT}"
# Ajustes reales (user://settings.cfg, GameSettings); ISAK_REAL_SETTINGS cambia la ruta.
REAL_SETTINGS="${ISAK_REAL_SETTINGS:-$(dirname "$REAL_SAVE_DEFAULT")/settings.cfg}"
_fingerprint() {
	if [[ -e "$1" ]]; then
		cksum < "$1"
	else
		echo "ausente"
	fi
}
_real_save_fingerprint() {
	_fingerprint "$REAL_SAVE"
}
REAL_SAVE_BEFORE="$(_real_save_fingerprint)"
REAL_SETTINGS_BEFORE="$(_fingerprint "$REAL_SETTINGS")"

IMPORT_LOG="$(mktemp -t isak_import.XXXXXX)"
if ! "$GODOT" --headless --path "$PROJECT_DIR" --import >"$IMPORT_LOG" 2>&1 \
	|| grep -qE "^(SCRIPT )?ERROR" "$IMPORT_LOG"; then
	echo "run_tests.sh: fallo la importacion del proyecto:" >&2
	cat "$IMPORT_LOG" >&2
	rm -f "$IMPORT_LOG"
	exit 3
fi
rm -f "$IMPORT_LOG"

# Validadores de niveles (esquema y alcanzabilidad), escena generada al dia, sprites del vortice,
# de la terminal de salida, del hub, de Eco companero, de las fichas del album y de los objetos del acertijo del laser
# y del chip del Debug y de los pisos 3 y 4 del 1-2 (recordatorio, Posponer, pop-up translucido, barra del 99 %;
# al dia con su generador), de los enemigos (Burbuja, punto rojo y banner), colores de la Q
# (normal y apagada de relectura) y fuente de textos
# (Python, unittest). Desde el 2026-10-16 (paso 10 de docs/propuesta-1-2.md) tambien el plan del
# camino (tests/test_level_plan.py: salas de prueba y casos negativos sinteticos) y la exportacion
# del camino de cada sala de prueba (data/levels/*_test.json, --export-path a un temporal). Desde el
# paso 13 del 1-2: el nivel 1-2 (tests/test_level_1_2.py y su camino exportado) y la fachada de la
# torre (tools/validate_world1_facade.py). Desde el 2026-10-17 (ajuste del 1-2): las subidas del 1-2
# que mide con el Isak real tests/test_level_climbs.gd (tests/fixtures/climbs_1-2.json, al dia con
# tools/level_climbs.py --check). Desde el 2026-10-17 (tanda H1 del paso 14 del 1-2): el arte del
# encuentro con Calc (tools/validate_calc_encounter.py). Desde la tanda H2 (2026-10-17): el 1-2 se valida
# con Calc desconocida (acertijo de la azotea) y conocida (camino directo; --allies calc), con su camino.
# Desde la tanda M1 de las mejoras de Calc (2026-10-17): el catalogo por pistas y su economia
# (tests/test_upgrade_economy.py), los niveles con --upgrades pista:nivel y el arte de la tienda
# (tools/validate_calc_chips.py). Desde la tanda M2 (2026-10-17): los niveles con todas las pistas al
# maximo (pulso:5,laser:5,debug:5,sync:5,energia:5) y con el tope del acceso de cada nivel (--access-cap),
# el camino del 1-2 exportado con las pistas al maximo y el arte de los efectos de las mejoras
# (tools/validate_upgrade_fx.py: «+4», perforacion, «?» y el icono «oculto» del HUD).
# Desde el 2026-10-18 (paso 15 del 1-2) GUT lanza ademas el bot vertical en ambos casos
# (tests/test_tower_bot.gd: tools/play_tower_bot.gd --headless --fixed-fps 60 en un proceso aparte,
# ~20-30 s de pared por caso; usa user://bot_save.json).
# Desde el 2026-10-20 (paso 11 de docs/propuesta-1-3.md) GUT lanza tambien el bot del 1-3
# (tests/test_dnd_bot.gd: tools/play_dnd_bot.gd en un proceso aparte, unos 2 min de pared con la
# exportacion del camino; usa user://bot_save.json).
# Desde el 2026-10-23 (paso 12 de docs/propuesta-mundo-2.md) GUT lanza tambien el bot del feed en el 2-1
# (tests/test_feed_bot.gd: tools/play_feed_bot.gd en un proceso aparte, unos 40 s de pared con la
# exportacion del camino; usa user://bot_save.json).
# Desde el 2026-10-27 (paso 11 de docs/propuesta-mundo-3.md) GUT lanza tambien el bot de la galeria en el 3-1
# (tests/test_gallery_bot.gd: tools/play_gallery_bot.gd en procesos aparte, el 3-1 y las salas recorte_test y
# reflejo_test; desde los pasos 12 y 13 tambien el 3-2 y el 3-3; unos 90 s de pared con la exportacion del camino;
# cada caso con su ISAK_SAVE_PATH).
# Desde el 2026-10-28 (paso 12 de docs/propuesta-mundo-4.md) GUT lanza tambien el bot del chat en el 4-1
# (tests/test_chat_bot.gd: tools/play_chat_bot.gd en un proceso aparte, logica en tools/chat_bot.gd; unos 65 s de
# pared con la exportacion del camino; su propio ISAK_SAVE_PATH; falla si la duracion sale del 40-55 % del objetivo).
# Desde el 2026-10-21 (paso 14 de docs/propuesta-jefe-alerta-mayor.md) GUT lanza tambien el bot del jefe
# (tests/test_boss_bot.gd: tools/play_boss_bot.gd en procesos aparte, perfiles ideal y torpe en Caché,
# Kernel y Raíz y el quieto que pierde; unos 50 s de pared en total; usa user://bot_save.json).
# Desde el 2026-10-23 (paso 19 de docs/propuesta-mundo-2.md) GUT lanza tambien el bot del jefe Autoplay
# (tests/test_autoplay_bot.gd: tools/play_boss_bot.gd -- --boss autoplay, logica en tools/autoplay_bot.gd,
# en procesos aparte: ideal y torpe en Caché, Kernel y Raíz y el quieto que pierde; unos 40 s de pared en
# total; usa user://bot_save.json) y, con el paso 20, las ayudas, textos y sonidos del jefe
# (tests/test_autoplay_help.gd).
# Desde el 2026-10-27 (paso 18 de docs/propuesta-mundo-3.md) GUT lanza tambien el bot del jefe La Curadora
# (tests/test_curator_bot.gd: tools/play_boss_bot.gd -- --boss curator, logica en tools/curator_bot.gd, en procesos
# aparte: ideal y torpe en Caché, Kernel y Raíz y el quieto que pierde; unos 60 s de pared en total; usa
# user://bot_save.json).
# Desde el 2026-10-19 (paso 1 de docs/propuesta-recuerdos.md): el esquema de los recuerdos
# (data/memories.json; tools/validate_memories.py y tests/test_memories.py).
# Desde el paso 4 (2026-10-19): el arte del mensaje de secreto (tools/validate_memory_pickup.py).
# Desde el paso 7 (2026-10-22): las ilustraciones de los recuerdos de jefe (tools/validate_memory_art.py,
# tests/test_memory_art.py).
# Desde el paso 8 de docs/propuesta-1-3.md (2026-10-20): el arte del 1-3 (tools/validate_world1_dnd.py).
# Desde el paso 9 (2026-10-20): el validador con el dash, el ritmo, el tunel y las campanas (tests/test_level_plan.py,
# DashAndRhythmTest; las salas del 1-3 se validan y exportan como las demas).
# Desde el 2026-10-20 (docs/lista-sonidos.md, «Integracion»): el catalogo de audio
# (data/audio.json; tools/validate_audio.py y tests/test_audio_catalog.py).
# Desde el 2026-10-21 (paso 2 de docs/propuesta-jefe-alerta-mayor.md §6): los datos de los jefes
# (data/bosses/*.json; tests/test_boss_data.py). Desde el paso 5 (2026-10-21): la arena 1-boss y el validador de
# arenas (tools/validate_boss.py, al que delega tools/validate_level.py con kind boss; tests/test_boss_validator.py,
# con sus casos negativos), sus subidas con el Isak real (tests/fixtures/climbs_1-boss.json) y el arte provisional
# del jefe (tools/gen_boss_alert_major.py --check, en tests/test_boss_data.py).
# Desde el 2026-10-22 (paso 0 de docs/propuesta-mundo-2.md): la paleta provisional del Mundo 2 al dia
# (tools/palette_mundo2_provisional.py --check). Desde el paso 2: el catalogo unido del Mundo 2 y la seccion
# scroll del esquema (tests/test_world2_schema.py; la sala scroll_test se valida y exporta como las demas).
# Desde el paso 4: los dibujos provisionales de las tarjetas del Mundo 2 para el album
# (tools/gen_world2_cards.py --check) y la sala tarjetas_test.
# Desde el paso 10 (fase A): las reglas de las variantes de paleta del Mundo 2 (tools/palette_mundo2_preview.py --check).
# Desde el paso 9b: el validador con el video en autoplay, los clones, el Comentarista, el muro y el reproductor
# (tests/test_world2_feed_validator.py).
# Desde el paso 11 (2026-10-22): el 2-1 real (tests/test_level_2_1.py, camino exportado y subidas al dia).
# Desde el paso 13 (2026-10-23): el 2-2 real (tests/test_level_2_2.py).
# Desde el paso 14 (2026-10-23): el 2-3 real (tests/test_level_2_3.py).
# Desde el paso 23 (2026-10-26): el arte final de Autoplay y del Comentarista al dia
# (tools/import_boss_autoplay.py --check, tools/import_commenter.py --check).
# Desde el paso 23 del Mundo 3 (2026-10-27): el arte final de La Curadora y del Influencer bot al dia
# (tools/import_boss_curator.py --check, tools/import_influencer_bot.py --check).
# Desde el paso 0 de docs/propuesta-mundo-3.md (2026-10-26): la paleta provisional del Mundo 3 al dia y sus 5 reglas
# de §6.1 (tools/palette_mundo3_provisional.py --check, tests/test_palette_mundo3.py).
# Desde el paso 9 (2026-10-26): las 3 variantes de paleta del Mundo 3 cumplen las 5 reglas
# (tools/palette_mundo3_preview.py --check; la elegida, la B, la escribe palette_mundo3_provisional.py), el arte por
# script de objetos y enemigos (tools/validate_world3_objects.py) y el tileset y el fondo de la galeria con el
# contraste de Isak y Eco (tools/validate_world3_tiles.py).
# Desde el paso 10 (2026-10-26): el 3-1 real (tests/test_level_3_1.py, camino exportado y subidas al dia).
# Desde el paso 12 (2026-10-27): el 3-2 real (tests/test_level_3_2.py, camino exportado y subidas al dia).
# Desde el paso 13 (2026-10-27): el 3-3 real (tests/test_level_3_3.py, camino exportado y subidas al dia) y el arte
# del marco dorado de salida (tools/gen_world3_exit_frame.py --check).
# Desde el paso 14 (2026-10-27): los datos y la logica de La Curadora (tests/test_curator.gd, GUT: marca solo con el
# Debug, un golpe por marca y la via por el espejo cazador de la fase 2).
# Desde el paso 15 (2026-10-27): la arena 3-boss «Exposición» (se valida y construye con las demas: esquema,
# comprobaciones basicas de validate_basic_arena y escena al dia; el validador completo es el paso 16), sus fases
# (tests/test_curator_arena.gd, GUT) y el arte provisional de la Curadora (tools/gen_boss_curator.py --check).
# Desde el paso 17 (2026-10-27): la pieza verde acido del hub (tools/gen_hub_piece_w3.py --check); la barra
# «retrato», la recompensa, la fila «Jefe: La Curadora» y el Mundo 4 los prueban tests/test_boss_bar.gd,
# tests/test_boss_reward.gd, tests/test_hub_boss_entry.gd y tests/test_boss_save_flow.gd (GUT).
# Desde el paso 20 (2026-10-27): el esquema de los filtros y el validador del Mundo 3 con sus negativos sinteticos
# (tests/test_world3_filter_schema.py y tests/test_world3_validator.py, de los pasos 3 y 8, que no estaban en la
# lista) y las pruebas de conjunto del Mundo 3 (tests/test_world3_negatives.py: perder likes nunca bloquea y el filtro
# no mata en los niveles reales; su parte con el Isak real, tests/test_world3_negatives.gd, GUT).
# Desde el paso 2 del Mundo 4 (2026-10-28): el esquema de los objetos del Mundo 4 (tests/test_world4_schema.py:
# zonas «Visto» y, desde el paso 3, burbujas). Desde el paso 9 (2026-10-28): el validador del Mundo 4 con sus
# negativos sinteticos (tests/test_world4_validator.py: tools/world4_model.py; las salas de los pasos 2-8 validan y
# exportan su camino como las demas *_test).
# Desde los pasos 7-8 de docs/propuesta-hub-mundos-4-6.md (2026-10-27): el arte del acertijo del hub
# (tools/gen_hub_update_art.py --check) y el bot del hub (tests/test_hub_update_bot.gd, GUT:
# tools/play_hub_update_bot.gd en procesos aparte, perfiles ideal, quieto, sin guardar y Kernel/Raiz; unos
# 20 s de pared en total; usa user://bot_save.json).
# Desde el paso 0 de docs/propuesta-mundo-4.md (2026-10-27): la paleta provisional del Mundo 4 al dia, sus 5 reglas
# de §6.1 y el coral decidido (#ff9f7a) igual en la paleta, data/hud.json y el hub
# (tools/palette_mundo4_provisional.py --check, tests/test_palette_mundo4.py).
# Desde el paso 10 (2026-10-28): las 3 variantes de paleta del Mundo 4 cumplen §6.1 y su comparativa esta al dia
# (tools/palette_mundo4_variants.py --check; la elegida, la B, la escribe palette_mundo4_provisional.py) y el arte
# por script de objetos y enemigos del Mundo 4 al dia y dentro de la paleta (tools/gen_world4_objects.py --check).
# Desde el paso 11 (2026-10-28): el 4-1 real (tests/test_level_4_1.py, camino exportado y subidas al dia).
# Desde el paso 13 (2026-10-28): el 4-2 real (tests/test_level_4_2.py, camino exportado y subidas al dia).
# Si falla, el script sale con 4 aunque GUT pase; si GUT falla, se devuelve el codigo de GUT.
PY_STATUS=0
EXPORT_DIR="$(mktemp -d -t isak_paths.XXXXXX)"
_export_test_rooms() {
	local room
	for room in "$PROJECT_DIR"/data/levels/*_test.json "$PROJECT_DIR"/data/levels/1-2.json \
		"$PROJECT_DIR"/data/levels/1-3.json "$PROJECT_DIR"/data/levels/2-1.json "$PROJECT_DIR"/data/levels/2-2.json \
		"$PROJECT_DIR"/data/levels/2-3.json "$PROJECT_DIR"/data/levels/3-1.json \
		"$PROJECT_DIR"/data/levels/3-2.json "$PROJECT_DIR"/data/levels/3-3.json "$PROJECT_DIR"/data/levels/4-1.json \
		"$PROJECT_DIR"/data/levels/4-2.json; do
		python3 tools/validate_level.py --export-path "$EXPORT_DIR/$(basename "$room")" "$room" >/dev/null || return 1
		[[ -s "$EXPORT_DIR/$(basename "$room")" ]] || return 1
	done
	# El 1-2 con Calc ya conocida (tanda H2 del paso 14): camino directo a la terminal.
	python3 tools/validate_level.py --allies calc --export-path "$EXPORT_DIR/1-2_calc.json" \
		"$PROJECT_DIR/data/levels/1-2.json" >/dev/null || return 1
	[[ -s "$EXPORT_DIR/1-2_calc.json" ]] || return 1
	# El 1-2 con todas las pistas al maximo (tanda M2): el camino sigue saliendo.
	python3 tools/validate_level.py --upgrades pulso:5,laser:5,debug:5,sync:5,energia:5 \
		--export-path "$EXPORT_DIR/1-2_max.json" "$PROJECT_DIR/data/levels/1-2.json" >/dev/null || return 1
	[[ -s "$EXPORT_DIR/1-2_max.json" ]] || return 1
}
# Pasadas del validador de alcanzabilidad sobre todos los niveles (sin mejoras, con mejoras, al maximo,
# con el tope del acceso) y caminos exportados: son independientes, asi que se lanzan a la vez y se espera
# a todas (paso 10 del 1-3, 2026-10-20: el 1-3 tarda unos 40 s por pasada). Falla si falla cualquiera.
_validate_levels() {
	local pids=() pid status=0
	python3 tools/validate_level.py data/levels/*.json >/dev/null & pids+=($!)
	python3 tools/validate_level.py --upgrades wide_pulse data/levels/*.json >/dev/null & pids+=($!)
	python3 tools/validate_level.py --upgrades pulso:3,laser:4,debug:2,sync:4,energia:4 data/levels/*.json >/dev/null \
		& pids+=($!)
	python3 tools/validate_level.py --upgrades pulso:5,laser:5,debug:5,sync:5,energia:5 data/levels/*.json >/dev/null \
		& pids+=($!)
	python3 tools/validate_level.py --access-cap data/levels/*.json >/dev/null & pids+=($!)
	_export_test_rooms & pids+=($!)
	for pid in "${pids[@]}"; do
		wait "$pid" || status=1
	done
	return $status
}
if command -v python3 >/dev/null 2>&1; then
	if ! (cd "$PROJECT_DIR" && python3 -m unittest -q tests/test_level_schema.py tests/test_text_font.py \
		tests/test_validate_level.py tests/test_level_plan.py tests/test_build_level.py tests/test_run_tests_guard.py \
		tests/test_level_1_2.py tests/test_level_1_3.py tests/test_level_2_1.py tests/test_level_2_2.py tests/test_level_2_3.py tests/test_level_3_1.py tests/test_level_3_2.py tests/test_level_3_3.py tests/test_level_4_1.py tests/test_level_4_2.py tests/test_upgrade_economy.py tests/test_memories.py tests/test_memory_art.py \
		tests/test_audio_catalog.py tests/test_boss_data.py tests/test_boss_validator.py tests/test_boss_arena_tuning.py tests/test_reduce_palette.py \
		tests/test_world2_schema.py tests/test_world2_feed_validator.py tests/test_palette_mundo3.py tests/test_palette_mundo4.py tests/test_world4_schema.py tests/test_world4_validator.py \
		tests/test_world3_filter_schema.py tests/test_world3_validator.py tests/test_world3_negatives.py \
		tests/test_hub_update_validator.py \
		&& python3 tools/validate_level_schema.py data/levels/*.json \
		&& _validate_levels \
		&& python3 tools/build_level.py --check data/levels/*.json \
		&& python3 tools/level_climbs.py --check data/levels/1-2.json \
		&& python3 tools/level_climbs.py --check data/levels/1-3.json \
		&& python3 tools/level_climbs.py --check data/levels/1-boss.json \
		&& python3 tools/level_climbs.py --check data/levels/2-1.json \
		&& python3 tools/level_climbs.py --check data/levels/2-2.json \
		&& python3 tools/level_climbs.py --check data/levels/2-3.json \
		&& python3 tools/level_climbs.py --check data/levels/3-1.json \
		&& python3 tools/level_climbs.py --check data/levels/3-2.json \
		&& python3 tools/level_climbs.py --check data/levels/3-3.json \
		&& python3 tools/level_climbs.py --check data/levels/4-1.json \
		&& python3 tools/level_climbs.py --check data/levels/4-2.json \
		&& python3 -I tools/validate_warp_objects.py >/dev/null && python3 -I tools/validate_hub_objects.py >/dev/null \
		&& python3 -I tools/validate_eco_companion.py >/dev/null && python3 -I tools/validate_album_cards.py >/dev/null \
		&& python3 -I tools/validate_extra_life.py >/dev/null && python3 -I tools/validate_help_prompt.py >/dev/null \
		&& python3 -I tools/validate_world1_puzzle.py >/dev/null && python3 -I tools/validate_world1_tower.py >/dev/null \
		&& python3 -I tools/validate_world1_facade.py >/dev/null \
		&& python3 -I tools/validate_calc_encounter.py >/dev/null && python3 -I tools/validate_calc_chips.py >/dev/null \
		&& python3 -I tools/validate_upgrade_fx.py >/dev/null && python3 -I tools/validate_memories.py >/dev/null \
		&& python3 -I tools/validate_memory_pickup.py >/dev/null && python3 -I tools/validate_memory_art.py >/dev/null \
		&& python3 -I tools/validate_world1_dnd.py >/dev/null && python3 -I tools/validate_audio.py >/dev/null \
		&& python3 tools/validate_enemy_sprites.py >/dev/null && python3 -I tools/validate_world1_enemies.py >/dev/null \
		&& python3 -I tools/palette_mundo2_provisional.py --check && python3 -I tools/gen_world2_cards.py --check \
		&& python3 -I tools/palette_mundo3_provisional.py --check && python3 -I tools/palette_mundo3_preview.py --check \
		&& python3 -I tools/gen_world3_exit_frame.py --check && python3 -I tools/palette_mundo4_provisional.py --check \
		&& python3 -I tools/palette_mundo4_variants.py --check && python3 -I tools/gen_world4_objects.py --check \
		&& python3 -I tools/validate_world3_objects.py >/dev/null && python3 -I tools/validate_world3_tiles.py >/dev/null \
		&& python3 -I tools/gen_boss_autoplay.py --check && python3 -I tools/gen_hub_piece_w2.py --check \
		&& python3 -I tools/gen_boss_curator.py --check && python3 -I tools/gen_hub_piece_w3.py --check \
		&& python3 -I tools/gen_hub_update_art.py --check \
		&& python3 -I tools/import_boss_autoplay.py --check >/dev/null && python3 -I tools/import_commenter.py --check >/dev/null \
		&& python3 -I tools/import_boss_curator.py --check >/dev/null && python3 -I tools/import_influencer_bot.py --check >/dev/null \
		&& python3 -I tools/palette_mundo2_preview.py --check); then
		echo "run_tests.sh: fallaron las pruebas Python (niveles: esquema, alcanzabilidad o escena; o fuente de textos)." >&2
		echo "run_tests.sh: detalle con python3 tools/validate_level.py data/levels/<id>.json" >&2
		PY_STATUS=4
	fi
else
	echo "run_tests.sh: python3 no encontrado; se omiten las pruebas del esquema de niveles." >&2
fi
rm -rf "$EXPORT_DIR"

GUT_LOG="$(mktemp -t isak_gut.XXXXXX)"
"$GODOT" --headless --path "$PROJECT_DIR" -s addons/gut/gut_cmdln.gd -gexit "$@" 2>&1 | tee "$GUT_LOG"
GUT_STATUS=${PIPESTATUS[0]}
if [[ $GUT_STATUS -ne 0 ]]; then
	rm -f "$GUT_LOG"
	exit $GUT_STATUS
fi
# Un script de prueba con un error de sintaxis no hace fallar a GUT: lo ignora.
PARTIAL=""
if [[ $# -gt 0 ]]; then
	PARTIAL="--partial"
fi
if ! "$PROJECT_DIR/tools/check_gut_log.sh" "$GUT_LOG" "$PROJECT_DIR/tests" $PARTIAL; then
	rm -f "$GUT_LOG"
	exit 6
fi
rm -f "$GUT_LOG"

# La suite (GUT, bot, herramientas) nunca debe crear ni cambiar el guardado real
# del jugador. No se borra nada: solo se compara su huella antes y despues.
if [[ "$(_real_save_fingerprint)" != "$REAL_SAVE_BEFORE" ]]; then
	echo "run_tests.sh: la suite creo o modifico el guardado real ($REAL_SAVE)" >&2
	echo "run_tests.sh: (o se jugo al juego mientras corria la suite)." >&2
	exit 5
fi
if [[ "$(_fingerprint "$REAL_SETTINGS")" != "$REAL_SETTINGS_BEFORE" ]]; then
	echo "run_tests.sh: la suite creo o modifico los ajustes reales ($REAL_SETTINGS)" >&2
	echo "run_tests.sh: (las pruebas usan user://test_settings.cfg y los scripts user://tool_settings.cfg)." >&2
	exit 5
fi
exit $PY_STATUS
