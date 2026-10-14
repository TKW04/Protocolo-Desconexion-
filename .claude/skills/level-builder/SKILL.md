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
  "tile_size": 32,
  "debug_color": "cyan",
  "grid": ["...", "..."],
  "checkpoints": [],
  "secrets": [],
  "enemies": [],
  "unlocks": []
}
```

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

## Validación de alcanzabilidad

Escribe `tools/validate_level.py` que lea `data/isak_physics.json` (los mismos valores que usa el juego) y compruebe:

1. Existe un camino desde `P` hasta `G`.
2. Cada `C` es alcanzable desde la anterior o desde `P`.
3. Ningún salto exige más del 85% del alcance máximo de Isak (margen de seguridad). Alcance horizontal y vertical se calculan con velocidad y gravedad del archivo de física.
4. Los secretos con `h` solo se alcanzan pasando por plataformas ocultas, y existe un camino sin Debug hacia la meta.
5. No hay pinchos en el punto de aparición ni en el primer tile de un checkpoint.

El script termina con código distinto de cero si algo falla, y explica qué fila y columna causan el problema.

## Criterios por nivel

Respeta la duración aproximada y la dificultad indicadas en la ficha. Una duración mayor sin un motivo claro hace el nivel más pesado de lo previsto.

## Flujo

1. Lee la ficha del nivel en `docs/mundo-N-*.md`.
2. Escribe el JSON y genera la escena.
3. Ejecuta la validación. Corrige hasta que pase.
4. Describe en una línea qué tramos quedaron y qué falta (enemigos o mecánicas que dependen de scripts propios).
5. Recuerda al usuario que probar el nivel jugando es lo único que valida si es divertido.
