# Estilización de los objetos de energía y progreso (1-1)

Estado: **integrado** (2026-10-15), pendiente de revisión del usuario. Desde la misma fecha también lo siguen los indicadores de Sync Rate y energía del HUD (ver «Indicadores del HUD»). Sustituye en lo visual a los dibujos provisionales `_draw` de `recharge_pickup`, `power_bank_pickup`, `charger` y `ability_pickup`. Cada objeto crea en `_ready` un `EnergySprite` (`scripts/levels/energy_sprite.gd`, un `AnimatedSprite2D`) con las animaciones de `assets/sprites/energy_objects_frames.tres` (una por estado, con sus fps); el objeto la avanza con tiempo del mundo, así que se ralentiza con el Debug y se detiene con la pausa. Las colisiones no cambian. Los colores de los `_draw` que quedan en `data/world1_objects.json` y `data/recharge_pickup.json` ya no se usan.

## Lenguaje visual común: «circuito limpio»

- **Forma:** objetos electrónicos reconocibles por su silueta: pila (energía), nodo octogonal de señal (Sync Rate), power bank vertical, poste con pantalla (cargador) y chip con patas (habilidad). Contorno de 1 px en `noche_profunda` con las esquinas recortadas; bisel de 1 px (`borde_luz` arriba/izquierda, `tile_base` abajo/derecha), igual que el HUD.
- **Circuito:** trazas finas de 1 px en `resplandor` grabadas en la carcasa, terminadas en nodos de 2x2 en `borde_luz`. Cuando el objeto está activo, un tramo de traza se enciende en `debug_cian`.
- **Color por significado** (coherente con el HUD):
  - Energía de Debug = cian (`debug_cian`, con `pulse_core` como brillo y `pulse_dim` como halo, de `effects_pulse.gpl`). Mismo color que la batería y el anillo de carga del HUD.
  - Sync Rate = blanco y gris (`banner_blanco` / `banner_gris`), con las barras de señal del HUD y una cruz de «sumar». Sin cian, para que no se confunda con la energía.
  - Inactivo, vacío o gastado = tonos de tile (`tile_sombra`, `tile_base`, `tile_luz`).
  - No se usan el rojo, el carmín ni el ámbar: el rojo indica daño y el ámbar es el de los puntos de atención.
- **Brillos:** cruces de 1 px (centro `pulse_core`, brazos `pulse_dim`; en el Sync, `banner_blanco` y `borde_luz`) y halo de 1 px alrededor del contorno, solo en algunos cuadros. Sin alfa parcial: la transparencia, si hace falta, se aplica con `modulate`.
- **Animación:** idle corto de 2 a 4 cuadros a unos 8 fps (cuadros de efecto: hasta 12). La flotación (`bob_px` / `bob_hz`) la sigue haciendo el código; no está dibujada en los cuadros.

Paleta: solo `assets/palettes/mundo1.gpl` (sin `ambar`, `alerta` ni `carmin`) y `assets/palettes/effects_pulse.gpl` (`pulse_core`, `pulse_dim`). El cian está en los PNG: en otros mundos el drop de energía y los acentos cian deben regenerarse con el color del Debug de ese mundo (hoy `use_world_debug_color` lo resuelve en el código).

## Archivos

| Objeto | Archivos (`assets/sprites/…`) | Tamaño | Estados | Cuadros |
|---|---|---|---|---|
| Drop de energía (`recharge_pickup`, `debug_energy`) | `pickups/energy_drop_idle_00..03.png` | 32x32 | idle | 4 (halo que crece y brillo) |
| Drop de Sync Rate (`recharge_pickup`, `sync_rate`) | `pickups/sync_drop_idle_00..03.png` | 32x32 | idle | 4 (barras de señal 1→2→3 y destello) |
| Power bank (`power_bank_pickup`) | `pickups/power_bank_empty_00..01.png` | 32x48 | vacío (como llega en el 1-1) | 2 (LED blanco parpadea) |
| | `pickups/power_bank_partial_00..01.png` | 32x48 | parcial (2/4 segmentos) | 2 (el segmento superior parpadea: cargando) |
| | `pickups/power_bank_full_00..01.png` | 32x48 | lleno (4/4, capacidad 200) | 2 (halo cian y brillo) |
| Estación de carga (`charger`) | `props/charger_ready_00..03.png` | 32x64 | lista | 4 (pulso cian que sube por las trazas) |
| | `props/charger_cooling_00..07.png` | 32x64 | en recarga (20 s) | 8 cuadros de **progreso**, no de bucle: el rayo y la barra se llenan de `pulse_dim` |
| | `props/charger_spent_00.png` | 32x64 | gastado (solo con `reusable: false`) | 1 |
| Punto de habilidad (`ability_pickup`) | `pickups/ability_pickup_idle_00..03.png` | 40x40 | disponible | 4 (las patas encendidas giran: arriba, derecha, abajo, izquierda; el núcleo late) |
| | `pickups/ability_pickup_collected_00.png` | 40x40 | recogido | 1 (chip apagado) |

Validación: tamaño, colores solo de las dos paletas, alfa 0 o 255 y fondo transparente en cada cuadro (`check_asset` de `tools/validate_world1_assets.py`). Generador: `tools/gen_energy_objects.py`; validador: `tools/validate_energy_objects.py` (ver «Regenerar»).

## Indicadores del HUD (Sync Rate y energía)

Desde el 2026-10-15 la señal (Sync Rate) y la batería (energía de Debug) del HUD usan el mismo lenguaje que los drops. Tamaños, tramos y lógica no cambian: 4 barras de señal y 5 segmentos de batería (`data/hud.json`), en píxeles de arte x2.

| Indicador | Archivo (`assets/sprites/ui/`) | Cuadros | Aspecto |
|---|---|---|---|
| Señal (Sync Rate) | `hud_signal.png` | 4x4 de 16x16 (columna = barra, fila = apagada / encendida / Sync Rate bajo / rastro de daño) | Nodo octogonal como el drop de Sync: anillo `banner_blanco` con sombra `banner_gris` abajo/derecha y fondo `tile_base`; dentro, barras de 2 px (3, 5, 7 y 9 de alto) en blanco y gris, `tile_luz` apagadas, `alerta` con Sync Rate bajo. El nodo está dibujado en la columna 0, que siempre se dibuja. |
| Batería (energía) | `hud_battery_shell.png` | 2 filas de 32x16: 0 con energía, 1 vacía | Carcasa de esquinas recortadas con bisel (`borde_luz` arriba/izquierda, `tile_luz` abajo/derecha), celda de la pila con el rayo en cian (`debug_cian`, el color clave que el shader cambia por el Debug del mundo), divisor `noche_profunda`, ventana `tile_sombra` y borne metálico (`banner_gris` con brillo `banner_blanco`). Vacía: el rayo pasa a `tile_luz`. |
| | `hud_battery_segments.png` | 5x3 de 32x16 (columna = segmento, fila = vacío / lleno / rastro) | Segmentos de 3x7: vacío `tile_base`, lleno `debug_cian` con un píxel de brillo `banner_blanco`, rastro `alerta_sombra`. |

Diferencias con los drops: el contorno `noche_profunda` lo pone el propio panel del HUD (es `noche_profunda`), así que en la señal el borde del nodo es ya el anillo; la parte baja y derecha del bisel usa `tile_luz` en vez de `tile_base`, que no se vería sobre el panel; no hay `pulse_core` ni `pulse_dim` (el HUD solo usa `mundo1.gpl`, y el cambio de color por mundo solo sustituye el `debug_cian`). Sin trazas de circuito: a 16 px de alto no caben sin restar legibilidad.

Batería vacía: con 0 de energía (por ejemplo tras el último disparo del láser) no queda ningún segmento encendido, ni rastro de consumo pendiente, y el rayo se apaga (`HudMeter.get_shell_row()`). `tools/validate_ui_assets.py` comprueba que la fila vacía del marco y de los segmentos no tiene el color del Debug.

Regenerar: `python3 tools/gen_hud_assets.py` (rehace todo el arte del HUD y su vista `_hud_assets_preview_x8.png`); validar: `python3 tools/validate_ui_assets.py`; capturas a 1280x720: `$GODOT --path . -s tools/render_hud_states.gd` (necesita ventana).

## Notas para integrar en cada escena

Se recomienda un `AnimatedSprite2D` con `SpriteFrames` (una animación por estado) y filtro nearest. Quitar el `_draw` cuando el sprite esté puesto. Las colisiones no cambian.

- **recharge_pickup:** elegir `energy_drop_idle` o `sync_drop_idle` según `kind`, a 8 fps y en bucle; centrado en el nodo (el dibujo actual está centrado en el origen). El radio de recogida (18 px) cubre el cuerpo del sprite. El cuadro de inicio puede ser aleatorio para que dos drops juntos no parpadeen a la vez.
- **power_bank_pickup:** en el mapa siempre llega vacío, así que en el nivel solo se usa `power_bank_empty` (2 fps). `partial` y `full` sirven para el hub o la tienda de mejoras (elegir por `carga / 200`: 0 vacío, menos de 200 parcial, 200 lleno). La carcasa mide 20x36 dentro del lienzo de 32x48; el borne sobresale por arriba.
- **charger:** el lienzo de 32x64 ocupa la mitad central de la celda de 64x64, apoyado en el borde inferior (como el `size_px` actual). Lista: `charger_ready` a 8 fps en bucle. En recarga: cuadro `floor(progress * 8)` limitado a 7 (con progress = tiempo enfriado / `cooldown_s`), sin reproducir. Gastado: `charger_spent_00`.
- **ability_pickup:** disponible: `ability_pickup_idle` a 6–8 fps; el chip mide 28x28 con las patas, igual que el `size_px` actual, dentro de un lienzo de 40x40 que deja sitio a los brillos. Como el objeto no aparece si la habilidad ya está obtenida, `ability_pickup_collected_00` sirve para el cuadro de transición al recogerlo (o para mostrarlo apagado si eso se decide en el futuro).

## Regenerar

Desde la raíz del repo:

- `python3 tools/gen_energy_objects.py` rehace los 32 PNG (`--dry-run` no escribe; `--preview <png> [--scale N]` guarda una hoja ampliada para revisarlos). La salida es determinista: sin cambios en el script, los PNG salen idénticos.
- `python3 tools/validate_energy_objects.py` los valida (sale con 1 si hay errores).

Ambos usan Pillow. Si está instalado en el site de usuario (`pip3 install --user Pillow`), los scripts lo añaden a `sys.path` a mano, así que funcionan también con `python3 -I`.

## Vórtice de llegada y salida (2026-10-15)

Isak ya no cae del cielo al empezar el nivel (P está en el suelo, columna 4, fila 9 del 1-1): llega por un **vórtice** al empezar o reiniciar el nivel y al reaparecer tras morir o caer. Mismo lenguaje «circuito limpio»: tres anillos partidos en arcos que giran en sentidos alternos (exterior `pulse_dim` con nodos `borde_luz` y patillas `resplandor`; medio `debug_cian` con nodos `pulse_core`; interior `pulse_core` con nodos `debug_cian`), sin fondo. Al cerrarse acaba en un destello en cruz.

| Animación | Archivos (`assets/sprites/effects/vortex/`) | Tamaño | Cuadros |
|---|---|---|---|
| Apertura | `vortex_open_00..03.png` | 96x96 | 4 a 12 fps (los anillos crecen) |
| Giro | `vortex_spin_00..03.png` | 96x96 | 4 a 12 fps, bucle |
| Cierre | `vortex_close_00..05.png` | 96x96 | 6 a 12 fps (se cierran hacia el centro; destello) |

Comportamiento (`WarpVortex`, `scripts/levels/warp_vortex.gd`; valores en `data/warp.json`): el vórtice se centra a 48 px sobre los pies de Isak, detrás de él, y avanza con tiempo del mundo. Llegada: Isak oculto y sin control (entrada quieta, no recibe golpes) mientras el fundido de entrada termina; luego el vórtice se abre, gira una vuelta y, al empezar a cerrarse, Isak se muestra (salen entonces las líneas de Eco que esperaban, como la bienvenida, que pausa con el vórtice en pantalla) y se materializa en 4 pasos de opacidad; el control vuelve al terminar el cierre (unos 1,2 s tras el fundido). Salida: igual, pero Isak se desvanece al cerrarse.

Regenerar: `python3 -I tools/gen_warp_objects.py` (`--preview <png>` para la hoja ampliada); validar: `python3 -I tools/validate_warp_objects.py` (paletas, alfa, PNG y `assets/sprites/warp_objects_frames.tres` al día con el generador; lo ejecuta `tools/run_tests.sh`).

## Terminal de salida (2026-10-15)

Sustituye a la puerta «Marcar como leído» del Cierre del 1-1 (columna 290; conserva la etiqueta). Monitor moderno de marco fino (bisel `borde_luz`/`tile_luz`/`tile_sombra`) sobre un pedestal con una traza `resplandor` y nodos `borde_luz`; LED de encendido en el marco.

| Estado | Archivos (`assets/sprites/props/exit_terminal/`) | Tamaño | Cuadros |
|---|---|---|---|
| Apagada (Isak lejos) | `terminal_off_00..01.png` | 64x128 | 2 a 2 fps: pantalla `tile_sombra` con reflejo, `>` y cursor `pulse_dim` parpadeando |
| Prompt (Isak cerca) | `terminal_prompt_00..01.png` | 64x128 | 2 a 4 fps: marco interior `pulse_dim`, `>` y cursor cian; LED `pulse_dim` |
| Encendido | `terminal_boot_00..03.png` | 64x128 | 4 a 12 fps, sin bucle: línea central que se abre hasta llenar la pantalla de cian |
| Activa | `terminal_on_00..01.png` | 64x128 | 2 a 4 fps: pantalla `pulse_dim` con líneas de código cian que suben, LED cian y halo cian que late |

Comportamiento (`ExitTerminal`, `scripts/levels/exit_terminal.gd`; sección `exit_terminal` de `data/world1_objects.json`): tocarla no termina el nivel. Con Isak a menos de 1,5 tiles pasa a prompt y encima del monitor sale la tecla del pulso (leída del Input Map, hoy «G») en la fuente de textos sobre una placa con borde cian. Al recibir el pulso (misma prueba que el receptor) se activa una vez: Isak queda sin control, la pantalla se enciende y se abre el vórtice de salida a su alrededor; al cerrarse, Isak ha sido absorbido y se emite `EventBus.level_completed` (vuelta al hub como antes). Solo necesita el pulso, que el 1-1 tiene desde el principio; `tools/validate_level.py` comprueba que el nivel tiene el pulso y que alcanza la terminal desde el camino a la meta.

Línea `eco_glitch` (columna 293, entre la terminal y la pared con glitch de la columna 298): con la puerta solo salía si se saltaba la puerta, porque tocarla terminaba el nivel; con la terminal, quien pase de largo sin pulsar G la oye. Encaja mejor: Eco intenta que el jugador no mire la pared con glitch (secreto D) justo cuando la terminal ya le espera. No se ha cambiado.

## Pendiente

- Los `.import` de Godot se crean la primera vez que se abre el editor (o con `tools/run_tests.sh`, que importa el proyecto); se commitean como los del resto de `assets/sprites/`.
