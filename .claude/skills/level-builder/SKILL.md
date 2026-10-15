---
name: level-builder
description: Convierte los niveles descritos en docs/mundo-N-*.md en datos jugables y valida que sean alcanzables con la física de Isak. Úsalo al crear, modificar o revisar cualquier nivel.
---

# Constructor y validador de niveles

## Principio

Los niveles son datos, no escenas hechas a mano. Un script genera la escena de Godot a partir del archivo de datos. Así se puede validar, modificar y regenerar.

## Formato

Un archivo por nivel en `data/levels/<mundo>-<nivel>.json`:

```json
{
  "id": "1-1",
  "name": "Bandeja de entrada",
  "world": 1,
  "tile_size": 64,
  "debug_color": "cyan",
  "grid": ["...", "..."],
  "checkpoints": [],
  "secrets": [],
  "enemies": [],
  "objects": [],
  "unlocks": []
}
```

Ejemplo completo: `data/levels/1-1.json`. Las coordenadas `x, y` de todas las listas son celdas del grid (columna, fila), con tiles de 64 px (igual que `tile_size` de `data/isak_physics.json`). El grid tiene al menos `ceil(720 / tile_size)` = 12 filas.

- `checkpoints`: `{id, x, y}`, uno por cada `C` del grid.
- `enemies`: `{id, type, x, y, params}`, uno por cada `E`; `type` es un archivo de `data/enemies/<type>.json` y `params` sobrescribe sus valores (p. ej. `patrol_range_px`).
- `secrets`: `{id, x, y}` sobre una `S`, o `{id, x, y, object: <tipo>}` si el secreto es un objeto (la pared con glitch del 1-1). Opcionales: `reward` y `points` (recompensa), `gates` (ids de las puertas propias del secreto, opcionales a propósito), `needs_debug: true` (solo se llega por plataformas `h`) y `requires_upgrade: <id de data/upgrades.json>` (solo se llega con esa mejora comprada, p. ej. `wide_pulse`).
- `objects` (V7): `{type, x, y, params}` para todo lo que no está en la leyenda. Los tipos, sus params obligatorios y sus valores por defecto están en `data/world<N>_objects.json`: `bridge_inactive`, `receiver`, `glitch_wall`, `popup_blocker`, `exit_door` (contiene la `G`) y `eco_line` (zona que dispara una línea de Eco). Los objetos sólidos (`bridge_inactive`, `glitch_wall`, `popup_blocker`) ocupan celdas que el grid deja en `.`.
- `unlocks`: `{type, id}`, p. ej. `{"type": "level", "id": "1-2"}`.
- Campos opcionales: `abilities_available` (`{"pulse": true, "debug": false}`), `sections` (tramos del documento en orden, `{name, x_from, x_to}`), `camera`, `target_duration_s`, `difficulty`.

`grid` es una lista de cadenas, una por fila, con esta leyenda:

| Carácter | Significado |
|---|---|
| `#` | tile sólido |
| `.` | vacío |
| `^` | pinchos |
| `-` | plataforma de una vía |
| `h` | plataforma oculta, solo visible con Debug |
| `P` | inicio del jugador |
| `G` | meta |
| `C` | punto de sincronización |
| `o` | punto de atención |
| `E` | enemigo (el tipo se define en la lista `enemies`) |
| `S` | secreto o coleccionable |

Las mecánicas de cada mundo (scroll forzado, plataformas de likes, burbujas de chat, tentación) se declaran como campos extra del nivel y se implementan en scripts propios, no en el grid.

## De dónde sale cada nivel

Cada nivel tiene su ficha en `docs/mundo-N-*.md` (el archivo del mundo correspondiente) con objetivo, dificultad, tramos, secreto y punto de sincronización. Respeta esa estructura: un tramo del documento equivale a una sección del nivel, en el mismo orden. Si la ficha pide algo que el formato no soporta, pregunta antes de improvisar.

## Validación de esquema

`tools/validate_level_schema.py` comprueba solo la forma del archivo (no la alcanzabilidad): campos y tipos, grid rectangular con caracteres de la leyenda, exactamente un `P` y un `G`, listas coincidentes con las celdas `C`, `E` y `S`, objetos del catálogo con sus params obligatorios, ids únicos y sin pinchos en `P` ni junto a una `C`. Sus pruebas (`tests/test_level_schema.py`) se ejecutan desde `tools/run_tests.sh`.

## Generador de la escena

`python3 tools/build_level.py data/levels/<id>.json` escribe `scenes/levels/<id>.tscn` (raíz `GeneratedLevel`, `scripts/levels/generated_level.gd`): TileMapLayer con auto-tile según `data/tileset_mundo<N>.json`, pinchos con Area de daño (`data/hazards.json`), plataformas ocultas, puntos de atención, checkpoints mínimos, objetos del catálogo con sus params, enemigos con sus `params`, Isak con los límites de cámara del grid, HUD y cuadro de Eco. Es idempotente: no edites la escena a mano, regenera. `--check` sale con 1 si la escena no está al día (lo usa `tools/run_tests.sh`).

## Validación de alcanzabilidad

`python3 tools/validate_level.py data/levels/<id>.json [--json] [--limit 0.85] [--jump-efficiency 0.92] [--run] [--upgrades wide_pulse]` (pruebas en `tests/test_validate_level.py`, se ejecuta desde `tools/run_tests.sh`). Lee `data/isak_physics.json` (los mismos valores que usa el juego) y comprueba:

1. Existe un camino desde `P` hasta `G`.
2. Cada `C` es alcanzable desde la anterior o desde `P`.
3. Ningún salto exige más del 85% del alcance máximo de Isak (margen de seguridad). Alcance horizontal y vertical se calculan con velocidad y gravedad del archivo de física.
4. Los secretos con `needs_debug` solo se alcanzan pasando por plataformas ocultas `h`, y existe un camino sin Debug hacia la meta. Los demás secretos (de puntos o con objeto recogible) se alcanzan sin Debug.
5. No hay pinchos en el punto de aparición ni en el primer tile de un checkpoint.
6. Mejoras: valida con los valores **base**; `--upgrades wide_pulse` valida con mejoras compradas (hoy solo se modela el radio del pulso). Un secreto con `requires_upgrade` no debe alcanzarse sin la mejora y sí con ella (se comprueba en cada pasada); la meta siempre sin mejoras.

El script termina con código distinto de cero si algo falla, y explica qué fila y columna causan el problema.

Además modela los objetos que hacen de puerta (puente tras su receptor, pop-up hasta que el pulso alcance su botón, Burbuja bajo un techo bajo hasta aturdirla), avisa si una puerta no es obligatoria y busca soft-locks. Informa del camino (lista de acciones) y del margen mínimo. La altura real del salto es la nominal × `--jump-efficiency` (0,92, medido a 60 Hz) y no cuenta con el coyote time.

## Criterios por nivel

Respeta la duración aproximada y la dificultad indicadas en la ficha. Una duración mayor sin un motivo claro hace el nivel más pesado de lo previsto.

## Flujo

1. Lee la ficha del nivel en `docs/mundo-N-*.md`.
2. Escribe el JSON y genera la escena.
3. Ejecuta la validación. Corrige hasta que pase.
4. Describe en una línea qué tramos quedaron y qué falta (enemigos o mecánicas que dependen de scripts propios).
5. Recuerda al usuario que probar el nivel jugando es lo único que valida si es divertido.
