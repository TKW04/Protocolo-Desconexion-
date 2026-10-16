#!/usr/bin/env bash
# Comprueba la salida de GUT (la guarda tools/run_tests.sh) para que un script de
# prueba roto no deje la suite en verde: GUT ignora un archivo con un error de
# sintaxis (avisa «Ignoring script ... because it does not extend GutTest») y
# sale con 0 si el resto pasa.
# Falla (codigo 6) si:
#   - la salida tiene un error de carga de scripts: «SCRIPT ERROR: Parse Error»,
#     «Failed to load script» o «Ignoring script ... does not extend GutTest»;
#   - (salvo con --partial) algun test_*.gd de la carpeta de pruebas no aparece
#     entre los scripts ejecutados (GUT imprime su ruta res://tests/... en una
#     linea propia al ejecutarlo).
# Uso: tools/check_gut_log.sh <salida de GUT> <carpeta tests> [--partial]
# (--partial: se ejecuto solo una parte de la suite, p. ej. con -gselect.)
# Sus pruebas (con salidas de GUT de ejemplo, sin archivos rotos en el repo):
# tests/test_run_tests_guard.py.
set -u

if [[ $# -lt 2 ]]; then
	echo "uso: $0 <salida de GUT> <carpeta tests> [--partial]" >&2
	exit 2
fi
LOG="$1"
TESTS_DIR="$2"
PARTIAL="${3:-}"
if [[ ! -r "$LOG" ]]; then
	echo "check_gut_log.sh: no se puede leer '$LOG'" >&2
	exit 2
fi

# Sin codigos de color (GUT los usa en algunas lineas).
CLEAN="$(sed $'s/\x1b\\[[0-9;]*m//g' "$LOG")"
STATUS=0

LOAD_ERRORS="$(printf '%s\n' "$CLEAN" | grep -E "SCRIPT ERROR: Parse Error|Failed to load script|Ignoring script .* does not extend GutTest|at: GDScript::reload \(res://" || true)"
if [[ -n "$LOAD_ERRORS" ]]; then
	echo "run_tests.sh: GUT no pudo cargar algun script (error de sintaxis o de carga):" >&2
	printf '%s\n' "$LOAD_ERRORS" | sed 's/^/  /' >&2
	STATUS=6
fi

if [[ "$PARTIAL" != "--partial" ]]; then
	MISSING=()
	while IFS= read -r file; do
		rel="${file#"$TESTS_DIR"/}"
		if ! printf '%s\n' "$CLEAN" | grep -qxF "res://tests/$rel"; then
			MISSING+=("res://tests/$rel")
		fi
	done < <(find "$TESTS_DIR" -type f -name 'test_*.gd' | sort)
	if [[ ${#MISSING[@]} -gt 0 ]]; then
		echo "run_tests.sh: GUT no ejecuto estos scripts de prueba:" >&2
		printf '  %s\n' "${MISSING[@]}" >&2
		STATUS=6
	fi
fi
exit $STATUS
