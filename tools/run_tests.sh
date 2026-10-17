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
# (Python, unittest). Si falla, el script sale con 4 aunque GUT pase; si GUT falla, se devuelve el
# codigo de GUT.
PY_STATUS=0
if command -v python3 >/dev/null 2>&1; then
	if ! (cd "$PROJECT_DIR" && python3 -m unittest -q tests/test_level_schema.py tests/test_text_font.py \
		tests/test_validate_level.py tests/test_build_level.py tests/test_run_tests_guard.py \
		&& python3 tools/validate_level_schema.py data/levels/*.json \
		&& python3 tools/validate_level.py data/levels/*.json >/dev/null \
		&& python3 tools/validate_level.py --upgrades wide_pulse data/levels/*.json >/dev/null \
		&& python3 tools/build_level.py --check data/levels/*.json \
		&& python3 -I tools/validate_warp_objects.py >/dev/null && python3 -I tools/validate_hub_objects.py >/dev/null \
		&& python3 -I tools/validate_eco_companion.py >/dev/null && python3 -I tools/validate_album_cards.py >/dev/null \
		&& python3 -I tools/validate_extra_life.py >/dev/null && python3 -I tools/validate_help_prompt.py >/dev/null \
		&& python3 -I tools/validate_world1_puzzle.py >/dev/null && python3 -I tools/validate_world1_tower.py >/dev/null \
		&& python3 tools/validate_enemy_sprites.py >/dev/null && python3 -I tools/validate_world1_enemies.py >/dev/null); then
		echo "run_tests.sh: fallaron las pruebas Python (niveles: esquema, alcanzabilidad o escena; o fuente de textos)." >&2
		echo "run_tests.sh: detalle con python3 tools/validate_level.py data/levels/<id>.json" >&2
		PY_STATUS=4
	fi
else
	echo "run_tests.sh: python3 no encontrado; se omiten las pruebas del esquema de niveles." >&2
fi

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
