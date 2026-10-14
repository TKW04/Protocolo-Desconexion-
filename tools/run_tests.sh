#!/usr/bin/env bash
# Ejecuta la suite de GUT en modo headless y devuelve el codigo de salida de GUT
# (o 4 si fallan las pruebas Python del esquema de niveles).
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

IMPORT_LOG="$(mktemp -t isak_import.XXXXXX)"
if ! "$GODOT" --headless --path "$PROJECT_DIR" --import >"$IMPORT_LOG" 2>&1 \
	|| grep -qE "^(SCRIPT )?ERROR" "$IMPORT_LOG"; then
	echo "run_tests.sh: fallo la importacion del proyecto:" >&2
	cat "$IMPORT_LOG" >&2
	rm -f "$IMPORT_LOG"
	exit 3
fi
rm -f "$IMPORT_LOG"

# Validador de esquema de niveles (Python, unittest). Si falla, el script sale con 4
# aunque GUT pase; si GUT falla, se devuelve el codigo de GUT.
PY_STATUS=0
if command -v python3 >/dev/null 2>&1; then
	if ! (cd "$PROJECT_DIR" && python3 -m unittest -q tests/test_level_schema.py \
		&& python3 tools/validate_level_schema.py data/levels/*.json); then
		echo "run_tests.sh: fallaron las pruebas del esquema de niveles." >&2
		PY_STATUS=4
	fi
else
	echo "run_tests.sh: python3 no encontrado; se omiten las pruebas del esquema de niveles." >&2
fi

"$GODOT" --headless --path "$PROJECT_DIR" -s addons/gut/gut_cmdln.gd -gexit "$@"
GUT_STATUS=$?
if [[ $GUT_STATUS -ne 0 ]]; then
	exit $GUT_STATUS
fi
exit $PY_STATUS
