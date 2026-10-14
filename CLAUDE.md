# Isak Fix (The Horizon: Protocolo de Desconexión)

Juego de plataformas 2D en pixel art hecho con Godot 4 y GDScript. Isak, un chico de 17 años, queda atrapado dentro de su celular. Los enemigos son las redes sociales y las IAs. El juego se hace desde cero.

## Fuente de verdad

El diseño está dividido por tema en `docs/`. Lee primero `docs/INDEX.md`, que indica qué archivo leer según la tarea, y luego solo los archivos del tema que necesites (`01` a `08` y `mundo-1` a `mundo-6`). Para un nivel, enemigo o jefe, lee el `mundo-N` correspondiente. No inventes historia, personajes ni mecánicas que no estén ahí. Si algo falta o es ambiguo, pregunta. `docs/preguntas.md` lista contradicciones, vacíos y ambigüedades pendientes de decisión del usuario. El original completo está en `docs/original/diseno.md` (solo lectura, no modificar).

## Skills del proyecto

Están en `.claude/skills/`:
- `godot-isak-fix`: arquitectura, convenciones y física en Godot.
- `pixel-art-pipeline`: paletas, tamaños, animaciones y exportación de sprites.
- `level-builder`: cómo convertir los niveles del documento en datos y validarlos.

## Reglas fijas del diseño

- Resolución base 640x360, escala por múltiplos enteros, filtro nearest. Sprite de Isak en canvas de 64x64, tiles de 32x32.
- Sync Rate es la vida. La energía de Debug es una barra aparte. Los puntos de atención son la moneda.
- Debug por mundo: 1 cian, 2 ámbar, 3 verde ácido, 4 coral, 5 blanco, 6 cambia por zona.
- Rojo significa daño y puntos débiles. En el Mundo 1 las alertas usan un rojo anaranjado y el punto débil un carmín puro y pulsante.
- La chaqueta de Isak es verde oliva desaturado, un color que no usa ninguna otra paleta.
- Todo ataque enemigo se anticipa visualmente de 6 a 12 cuadros antes de dañar.
- Sin marcas reales. Todos los nombres de apps y redes son inventados.
- Textos del juego y del documento en español. Identificadores del código en inglés.

## Decisiones abiertas (no las decidas tú, pregúntame)

- Tamaño final del sprite: 64x64 o 48x48, tras probar el prototipo.
- Hex exactos de las paletas por mundo.
- La familia de Isak, que aparece en los recuerdos del Mundo 2.
- Música y efectos de sonido.

## Decisiones tomadas

`docs/preguntas.md` registra estas decisiones y su contexto.

- Pruebas con GUT. Se ejecutan con `tools/run_tests.sh`.
- Los controles leen solo acciones del Input Map de `project.godot`, pensando en un futuro port a móvil. Los gestos usan las acciones `gesture_swipe`, `gesture_hold`, `gesture_pinch` y `gesture_shake`; `gesture_hold` aún no tiene tecla asignada.
- El Debug se implementa completo, pero se desbloquea por nivel mediante `GameState.abilities_unlocked`.
- Al terminar un nivel se vuelve al hub.

## Cómo trabajar

1. Orden de producción: Isak jugable (caminar, saltar, idle, pulso), luego el tileset del Mundo 1 y el nivel 1-1. Este es el vertical slice. No avances a otros mundos hasta que yo apruebe el ritmo del movimiento.
2. Cambios de movimiento o de física: explica el valor anterior y el nuevo. Los valores se ajustan jugando.
3. Los sprites de Isak, de Isak Optimizado y de los jefes se entregan como borrador con sufijo `_placeholder`. Yo decidiré si se rehacen a mano.
4. Antes de dar un nivel por terminado, ejecuta la validación de alcanzabilidad de `level-builder` y las pruebas.
5. Haz commits pequeños con mensajes claros.
