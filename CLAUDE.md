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

- Resolución base 1280x720 (stretch `viewport`, escala `integer`), filtro nearest. Sprite de Isak en canvas de 128x128 con unos 96 px de altura visible (pies abajo-centro), tiles de 64x64.
- Sync Rate es la vida. La energía de Debug es una barra aparte. Los puntos de atención son la moneda.
- Debug por mundo: 1 cian, 2 ámbar, 3 verde ácido, 4 coral, 5 blanco, 6 cambia por zona.
- Rojo significa daño y puntos débiles. En el Mundo 1 las alertas usan un rojo anaranjado y el punto débil un carmín puro y pulsante.
- Isak lleva chaqueta gris oscura tipo táctica con detalles cian luminosos en cuello y hombro, y siempre su celular. No lleva lentes ni chaqueta verde oliva. La referencia visual es `../Ejemplo/Idle.png` (fuera del repo) (ver `docs/07-estilo-visual.md`, §15.4).
- Todo ataque enemigo se anticipa visualmente de 6 a 12 cuadros antes de dañar.
- Sin marcas reales. Todos los nombres de apps y redes son inventados.
- Textos del juego y del documento en español. Identificadores del código en inglés.

## Decisiones abiertas (no las decidas tú, pregúntame)

- Hex exactos de las paletas por mundo.
- La familia de Isak, que aparece en los recuerdos del Mundo 2.
- Música y efectos de sonido.

## Decisiones tomadas

`docs/preguntas.md` registra estas decisiones y su contexto.

- Pruebas con GUT. Se ejecutan con `tools/run_tests.sh`.
- Los controles leen solo acciones del Input Map de `project.godot`, pensando en un futuro port a móvil. Los gestos usan las acciones `gesture_swipe`, `gesture_hold`, `gesture_pinch` y `gesture_shake`; `gesture_hold` aún no tiene tecla asignada.
- El Debug se implementa completo, pero se desbloquea por nivel mediante `GameState.abilities_unlocked`.
- Al terminar un nivel se vuelve al hub.
- Resolución 1280x720, Isak a 96 px visibles en canvas de 128x128 y tiles de 64x64 (C6, 2026-10-14).
- El diseño de Isak de `../Ejemplo/Idle.png` (arte generado con IA) reemplaza al del documento original y sirve de guía. Las hojas generadas con IA se importan con `tools/import_sheet.py` siguiendo `docs/guia-sprites-ia.md`.

## Cómo trabajar

1. Orden de producción: Isak jugable (caminar, saltar, idle, pulso), luego el tileset del Mundo 1 y el nivel 1-1. Este es el vertical slice. No avances a otros mundos hasta que yo apruebe el ritmo del movimiento.
2. Cambios de movimiento o de física: explica el valor anterior y el nuevo. Los valores se ajustan jugando.
3. El arte de Isak lo aporta el usuario: hojas generadas con IA en `hojas/`, importadas con `tools/import_sheet.py` (guía en `docs/guia-sprites-ia.md`). Los sprites de Isak Optimizado y de los jefes siguen como borrador con sufijo `_placeholder`, salvo que el usuario aporte arte. Yo decidiré si se rehacen a mano.
4. Antes de dar un nivel por terminado, ejecuta la validación de alcanzabilidad de `level-builder` y las pruebas.
5. Haz commits pequeños con mensajes claros.

## Cómo ejecutar

Desde la raíz del repo (`GODOT=/Applications/Godot.app/Contents/MacOS/Godot`):

- Jugar (escena principal `scenes/main.tscn`: el 1-1 completo, con punto de sincronización, muerte, final y pantalla provisional del hub): `/Applications/Godot.app/Contents/MacOS/Godot --path "/Users/isaachiraldo/Projects/PersonalsProyects/Protocolo Desconexion/isak-fix-claude-code"`. Controles: A/D o flechas (mover), Espacio (saltar), Mayús (correr), J (pulso), mantener K (Debug; bloqueado en el 1-1). En la pantalla provisional del hub, W/S o flechas arriba/abajo eligen una mejora, J la compra con puntos de atención (y power banks) y Espacio vuelve a jugar. El progreso (puntos, puntos ya capturados por nivel, mejoras, power banks y niveles) se guarda en `user://save.json` (en macOS, `~/Library/Application Support/Godot/app_userdata/Isak Fix/save.json`; bórralo para empezar de cero). La variable de entorno `ISAK_SAVE_PATH` usa otra ruta. Teclas para probar el nivel (acciones `restart_level` y `debug_wipe_save`, ajustes en `dev_keys` de `data/flow.json`): R o Select/Back del mando reinicia el mapa actual desde el inicio (nivel, enemigos, objetos, Sync Rate y energía iniciales, sin checkpoint) y conserva el guardado; vale jugando, en el hub y durante la animación de muerte (la sustituye), y se ignora durante un fundido. Mantener F9 2 s (aviso «Mantén F9: borrar guardado» en pantalla) borra el guardado actual y reinicia el mapa; solo en builds de depuración (`OS.is_debug_build()`).
- Pruebas (GUT, Python y validadores): `tools/run_tests.sh`.
- Bot que recorre el 1-1 de principio a fin (código 0 si lo termina; anota la duración del recorrido): `$GODOT --headless --fixed-fps 60 --path . -s tools/play_level_bot.gd` (añade `-- --no-die` para no forzar la muerte tras el checkpoint y `--run` para recorrerlo corriendo; sin `--headless` se ve jugar). Usa su propio guardado (`user://bot_save.json`); las pruebas usan `user://test_save.json`, así que ninguno toca el guardado real.
- Nivel 1-1 (ampliado, 2026-10-14): 300x14 tiles, tramos 1, 2a-c, 3a-c, 4a-c y cierre; un punto de sincronización en la columna 150; 103 puntos de atención (79 en la ruta); secretos A, B y C con un power bank vacío cada uno y D (pared con glitch, pendiente del Debug). Unos 90 s caminando y 57 s corriendo por la ruta (bot). Detalle en `docs/preguntas.md` («Notas del 1-1 ampliado»). Capturas: `$GODOT --path . -s tools/render_level_1_1.gd -- <carpeta>`.
- Validar el nivel: `python3 tools/validate_level_schema.py data/levels/1-1.json` y `python3 tools/validate_level.py data/levels/1-1.json`.
- Regenerar la escena del nivel desde el JSON (no editar `scenes/levels/1-1.tscn` a mano): `python3 tools/build_level.py data/levels/1-1.json`; comprobar que está al día: `python3 tools/build_level.py --check data/levels/*.json`.
- Escenas de prueba (no son niveles): `$GODOT --path . res://scenes/levels/test_arena.tscn` (movimiento; F1/F2 bajan/suben el Sync Rate, F3 gasta energía, F4 suma un punto de atención; caer por un hueco devuelve al inicio), `debug_sandbox.tscn` (Debug: mantener K), `alert_bubble_test.tscn` (Burbuja), `eco_text_test.tscn` (cuadro de Eco), `tramo4_test.tscn` y `world1_objects_test.tscn` (objetos del Mundo 1).
