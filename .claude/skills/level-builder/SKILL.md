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
- `enemies`: `{id, type, x, y, params}`, uno por cada `E`; `type` es un archivo de `data/enemies/<type>.json` y `params` sobrescribe sus valores (p. ej. `patrol_range_px`, o `health`: la vida de esa instancia; cada tipo define la suya en su JSON, sin valor estándar). Opcional: `open: true` para una Burbuja en abierto a propósito (se puede saltar; el validador no avisa de que su pulso no es obligatorio, solo si en realidad bloquea; desde el 2026-10-15 pisarla no la mata y ya no se le busca repisa: muere con el láser y matarla es opcional).
- `secrets`: `{id, x, y}` sobre una `S`, o `{id, x, y, object: <tipo>}` si el secreto es un objeto (la pared con glitch del 1-1). Opcionales: `reward` y `points` (recompensa), `gates` (ids de las puertas propias del secreto, opcionales a propósito), `needs_debug: true` (solo se llega por plataformas `h`) y `requires_upgrade: <id de data/upgrades.json>` (solo se llega con esa mejora comprada, p. ej. `wide_pulse`).
- `objects` (V7): `{type, x, y, params}` para todo lo que no está en la leyenda. Los tipos, sus params obligatorios y sus valores por defecto están en `data/world<N>_objects.json`: `bridge_inactive`, `receiver`, `glitch_wall`, `popup_blocker`, `exit_door` (contiene la `G`), `eco_line` (zona que dispara una línea de Eco; desde el 2026-10-16 solo para momentos de historia, el resto es ayuda con Q), `eco_encounter` (encuentro con Eco: zona de toda la altura con Eco flotando en `eco_offset_tiles`; presentación, apodo y el pulso; uno por nivel, en un nivel con `abilities_available.pulse: false`; textos en `data/eco_encounter.json`), `power_bank_pickup`, `ability_pickup` (da una habilidad para siempre; `ability`: `pulse`, `debug` o `laser`) y `charger` (cargador de energía al tocarlo; `amount`, `reusable`, `cooldown_s`). Los objetos sólidos (`bridge_inactive`, `glitch_wall`, `popup_blocker`) ocupan celdas que el grid deja en `.`.
- `unlocks`: `{type, id}`, p. ej. `{"type": "level", "id": "1-2"}`.
- Campos opcionales: `abilities_available` (`{"pulse": true, "debug": false}`; también admite `laser`, aunque una habilidad obtenida con `ability_pickup` no se bloquea), `sections` (tramos del documento en orden, `{name, x_from, x_to}`; en un nivel vertical, desde el 2026-10-16, también `y_from`/`y_to`, con todo el ancho / todo el alto por defecto, sin solaparse, y `patterns`), `camera` (`vertical`: `simple` o `tower`, la cámara de torre de `data/camera_tower.json`; `limits`: `grid`), `target_duration_s`, `difficulty`. El grid admite cualquier alto (la torre del 1-2 tiene 62 filas). Un nivel de prueba usa el id `<nombre>_test` (p. ej. `tower_test`).
- `validation` (opcional, 2026-10-16, paso 10 de `docs/propuesta-1-2.md`): parámetros del diseño que comprueba el validador de alcanzabilidad. `time_margin_s` (lo que debe sobrar en ventanas y cuentas; 1,5 s por defecto), `snooze_required` (grupos de recordatorios que **solo** se cruzan con el Posponer: sin él no da tiempo y con él sí), `laser_required` / `debug_required` (la meta exige el láser / el Debug), `start_energy` (energía al empezar; 100), `sync_damage_budget` (Sync Rate que pueden quitar los enemigos en el camino; 0) y, desde el 2026-10-17, `ceiling_margin_px` (0-64: holgura de techo calibrada con el Isak real; ver la regla 7). El esquema rechaza campos desconocidos.

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

`python3 tools/validate_level.py data/levels/<id>.json [--json] [--limit 0.85] [--jump-efficiency 0.92] [--run] [--upgrades wide_pulse] [--time-margin 1.5] [--export-path <camino.json>]` (pruebas en `tests/test_validate_level.py` y `tests/test_level_plan.py`, se ejecuta desde `tools/run_tests.sh`). Lee `data/isak_physics.json` (los mismos valores que usa el juego) y comprueba:

1. Existe un camino desde `P` hasta `G`.
2. Cada `C` es alcanzable desde la anterior o desde `P`.
3. Ningún salto exige más del 85% del alcance máximo de Isak (margen de seguridad). Alcance horizontal y vertical se calculan con velocidad y gravedad del archivo de física.
4. Los secretos con `needs_debug` solo se alcanzan pasando por plataformas ocultas `h`, y existe un camino sin Debug hacia la meta. Los demás secretos (de puntos o con objeto recogible) se alcanzan sin Debug.
5. No hay pinchos en el punto de aparición ni en el primer tile de un checkpoint.
6. Mejoras: valida con los valores **base**; `--upgrades wide_pulse` valida con mejoras compradas (hoy solo se modela el radio del pulso). Un secreto con `requires_upgrade` no debe alcanzarse sin la mejora y sí con ella (se comprueba en cada pasada); la meta siempre sin mejoras.

El script termina con código distinto de cero si algo falla, y explica qué fila y columna causan el problema.

7. Tolerancia de techo (2026-10-16): un salto no atraviesa losas y, al subir, la cabeza se comprueba también donde estaría Isak si despegara desde parado (aceleración en el aire) más 8 px (`HEAD_MARGIN_PX`): un salto diagonal que roza con la cabeza la esquina de un forjado no cuenta (bajo un techo plano no cambia nada). En una torre (`camera.vertical: "tower"` o tramos con `y_from`/`y_to`) un fallo dice el piso y la fila («Isak no sube de la fila N») y las reglas por columnas (6d, pulso antes del encuentro con Eco) no se aplican. **Holgura calibrada (2026-10-17):** con `validation.ceiling_margin_px` (el 1-2 usa 16) una subida solo vale si, al subir, la cabeza queda a ese margen de todo sólido de encima con el salto real del juego (184 px a 60 Hz, no los 177 de `--jump-efficiency`) y la caja a 8 px (`CORNER_MARGIN_PX`) de la esquina de una losa (sin los +8 px del modelo anterior); sin el campo no cambia nada. `tools/level_climbs.py` exporta las subidas aceptadas y `tests/test_level_climbs.gd` las comprueba con el Isak real (despegue, carrera de dos tiles y coyote).
8. Paso 10 (2026-10-16): láser, Debug, energía, temporizadores y enemigos. Las habilidades son **estado del grafo**: el láser alcanza objetivos en línea recta a la altura del celular (`laser_range_px`, lo cortan el terreno, los puentes y los pop-ups): lector láser, anuncio, Posponer y Burbujas; el Debug (por `abilities_available.debug` o tras recoger su chip) da movimientos sobre plataformas `h` y paredes con glitch, marcados «con Debug». Acertijos: lector → receptor enlazado → puente (el disparo y el pulso dentro de `window_s`, con el margen; cuenta el último disparo, así que un 2.º disparo rellena la ventana), anuncio → pop-up (el láser lo rompe antes de que el pulso cierre), barra del 99 % (puerta sólida que se abre tras `rise_s` + `wait_s` + `full_s` en su zona; las oleadas no se modelan ni hay que derrotarlas). El **plan del camino** (`tools/level_plan.py`) pone tiempos a cada paso y comprueba: recordatorios (cuenta compartida por grupo desde que se pisa, aviso, caída y `respawn_s`; con el Posponer, `extend_s` hasta `cap_s` y `cooldown_s`; `snooze_required`), pop-ups translúcidos que tapan el camino (cerrar con el pulso o ver con el Debug), tramos con Debug (carga `activation_hold_s`, 20/s), banners (búsqueda por celda y fase con esperas y saltos en el sitio; el bot espera en la entrada a la fase indicada), puntos rojos (simulados a lo largo del camino: si se van a lanzar y el pulso los alcanza, se aturden; el daño que quede ≤ `sync_damage_budget`) y la energía (100; láser 10; Debug 20/s; cargadores con enfriamiento, el chip con `refill_energy` y drops; si falta en un paso obligatorio, desvío a un cargador; si no hay, «sin energía en el paso N»). Solo los niveles con objetos del paso 10 (o con `validation`, o verticales) llevan el plan en la salida: la del 1-1 no cambia.

**Camino exportado** (`--export-path <archivo.json>`, un nivel; lo seguirá el bot vertical, paso 15 del 1-2): JSON `{"format": "isak-path/1", "level", "tile_size", "physics", "start": {"cell": [col, fila], "feet_px": [x, y]}, "time_margin_s", "duration_s", "duration_world_s", "energy", "steps": [...]}`. Cada paso tiene `i`, `action`, `t` / `t_world` (s al empezar, real y del mundo), `duration_s` y, si hay energía en juego, `energy_before` / `energy_after`. Acciones: `walk` (`from` / `to` con `cell` y `feet_px`, misma fila), `jump` / `jump_run` / `fall` (además `takeoff_x_px` —x de los pies al despegar—, `target_x_px` —donde soltar la dirección; `null` = seguir—, `direction`, `speed`, `air_s` y `debug` si va con el Debug), `laser` y `pulse` (`at`, `x_px`, `facing`, `target {type, id}`; el láser puede llevar `wait_before_s` / `hold_after_s`), `wait` (`seconds`, `reason`), `wait_phase` (esperar en `at` a que el ciclo de cada banner valga `banner_cycle_s` —`SpamBanner.get_cycle_time()`—; `period_s`, `phase_s`), `hop` (salto en el sitio), `pickup` (`ability`, `refill_energy`), `charge` (cargador), `debug_on` (mantener la acción `hold_s` y dejarlo activo `active_s`) / `debug_off` y `goal`; el pulso a la terminal lleva `final: true`.

Además modela los objetos que hacen de puerta (puente tras su receptor, que extendido es una tabla fina en lo alto de su celda y se puede pasar por debajo; pop-up hasta que el pulso alcance su botón; Burbuja bajo un techo bajo hasta aturdirla o matarla con el láser), avisa si una puerta no es obligatoria y busca soft-locks. El pulso puede no existir al empezar (`abilities_available.pulse: false`): lo da el `eco_encounter` al tocar cualquier celda de su zona, que tiene que ser obligatorio, y ninguna puerta que exija el pulso (receptor, pop-up, Burbuja que no se salta, terminal) puede quedar antes de él (regla 6d). Los `ability_pickup` se recogen al tocar su celda y desde entonces la habilidad cuenta como disponible (el láser, horizontal desde el celular con `laser_range_px`, abre Burbujas): comprueba que se alcanzan, avisa si uno no es obligatorio (salvo si está en `gates` de un secreto) y comprueba que la meta se alcanza sin usar el láser (aviso; con `validation.laser_required`, al revés: error si se alcanza sin él); informa de desde dónde alcanza el láser a cada Burbuja. Informa del camino (lista de acciones) y del margen mínimo. La altura real del salto es la nominal × `--jump-efficiency` (0,92, medido a 60 Hz) y no cuenta con el coyote time.

## Criterios por nivel

Respeta la duración aproximada y la dificultad indicadas en la ficha. Una duración mayor sin un motivo claro hace el nivel más pesado de lo previsto.

## Flujo

1. Lee la ficha del nivel en `docs/mundo-N-*.md`.
2. Escribe el JSON y genera la escena.
3. Ejecuta la validación. Corrige hasta que pase.
4. Describe en una línea qué tramos quedaron y qué falta (enemigos o mecánicas que dependen de scripts propios).
5. Recuerda al usuario que probar el nivel jugando es lo único que valida si es divertido.
