#!/usr/bin/env bash
# Ejecuta la suite de GUT en modo headless y devuelve el codigo de salida de GUT.
# Uso: tools/run_tests.sh [opciones extra de GUT]
# La ruta de Godot se puede cambiar con la variable GODOT.
set -u

GODOT="${GODOT:-/Applications/Godot.app/Contents/MacOS/Godot}"
PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

if [[ ! -x "$GODOT" ]]; then
	echo "run_tests.sh: no se encuentra Godot en '$GODOT' (define GODOT)." >&2
	exit 2
fi

"$GODOT" --headless --path "$PROJECT_DIR" -s addons/gut/gut_cmdln.gd -gexit "$@"
exit $?
