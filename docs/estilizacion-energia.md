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

Batería vacía por coste del láser (2026-10-15): con el láser desbloqueado, una energía menor que su coste (`laser_energy_cost` de `data/isak_abilities.json`, 10, con mejoras; `GameState.get_laser_energy_cost()`) se ve igual que con 0: sin segmentos, rayo apagado y sin rastro, porque ya no se puede disparar. Con el coste justo (10) se enciende 1 segmento, según los tramos. Es solo visual (`Hud.is_energy_shown_empty`): `GameState.debug_energy` conserva el resto, que suma con la siguiente recarga. Sin el láser se mantiene la regla anterior (vacía solo con 0). El Debug no entra en la regla aunque se active con cualquier energía > 0 (duda abierta en `docs/preguntas.md`).

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

- En el hub, los objetos de este estilo se regeneran con `assets/palettes/hub.gpl` (propuesta; `fondo_profundo`, `borde`, `dock` y `traza` en lugar de `noche_profunda`, `borde_luz`, `tile_base` y `resplandor`; ver `07-estilo-visual.md` §15.3.1).

Ambos usan Pillow. Si está instalado en el site de usuario (`pip3 install --user Pillow`), los scripts lo añaden a `sys.path` a mano, así que funcionan también con `python3 -I`.

## Vórtice de llegada y salida (2026-10-15)

Isak ya no cae del cielo al empezar el nivel (P está en el suelo, columna 4, fila 9 del 1-1): llega por un **vórtice** al empezar o reiniciar el nivel y al reaparecer tras morir o caer. Mismo lenguaje «circuito limpio»: tres anillos partidos en arcos que giran en sentidos alternos (exterior `pulse_dim` con nodos `borde_luz` y patillas `resplandor`; medio `debug_cian` con nodos `pulse_core`; interior `pulse_core` con nodos `debug_cian`), sin fondo. Al cerrarse acaba en un destello en cruz.

| Animación | Archivos (`assets/sprites/effects/vortex/`) | Tamaño | Cuadros |
|---|---|---|---|
| Apertura | `vortex_open_00..03.png` | 96x96 | 4 a 12 fps (los anillos crecen) |
| Giro | `vortex_spin_00..03.png` | 96x96 | 4 a 12 fps, bucle |
| Cierre | `vortex_close_00..05.png` | 96x96 | 6 a 12 fps (se cierran hacia el centro; destello) |

Comportamiento (`WarpVortex`, `scripts/levels/warp_vortex.gd`; valores en `data/warp.json`): el vórtice se centra a 48 px sobre los pies de Isak, detrás de él, y avanza con tiempo del mundo. Llegada: Isak oculto y sin control (entrada quieta, no recibe golpes) mientras el fundido de entrada termina; luego el vórtice se abre, gira una vuelta y, al empezar a cerrarse, Isak se muestra (salen entonces las líneas de Eco que esperaban, como la bienvenida, que pausa con el vórtice en pantalla) y se materializa en 4 pasos de opacidad; el control vuelve al terminar el cierre (unos 1,2 s tras el fundido). Salida: igual, pero Isak se desvanece al cerrarse; como llega de espaldas (ver «Terminal de salida»), el vórtice se centra en esa pose (`back_center_offset_px`, 2 px a la derecha de los pies) y se dibuja detrás de él, entre Isak y el monitor.

Regenerar: `python3 -I tools/gen_warp_objects.py` (`--preview <png>` para la hoja ampliada); validar: `python3 -I tools/validate_warp_objects.py` (paletas, alfa, PNG y `assets/sprites/warp_objects_frames.tres` al día con el generador; lo ejecuta `tools/run_tests.sh`).

## Terminal de salida (2026-10-15)

Sustituye a la puerta «Marcar como leído» del Cierre del 1-1 (columna 290; conserva la etiqueta). Monitor moderno de marco fino (bisel `borde_luz`/`tile_luz`/`tile_sombra`) sobre un pedestal con una traza `resplandor` y nodos `borde_luz`; LED de encendido en el marco.

| Estado | Archivos (`assets/sprites/props/exit_terminal/`) | Tamaño | Cuadros |
|---|---|---|---|
| Apagada (Isak lejos) | `terminal_off_00..01.png` | 64x128 | 2 a 2 fps: pantalla `tile_sombra` con reflejo, `>` y cursor `pulse_dim` parpadeando |
| Prompt (Isak cerca) | `terminal_prompt_00..01.png` | 64x128 | 2 a 4 fps: marco interior `pulse_dim`, `>` y cursor cian; LED `pulse_dim` |
| Encendido | `terminal_boot_00..03.png` | 64x128 | 4 a 12 fps, sin bucle: línea central que se abre hasta llenar la pantalla de cian |
| Activa | `terminal_on_00..01.png` | 64x128 | 2 a 4 fps: pantalla `pulse_dim` con líneas de código cian que suben, LED cian y halo cian que late |

Comportamiento (`ExitTerminal`, `scripts/levels/exit_terminal.gd`; sección `exit_terminal` de `data/world1_objects.json`): tocarla no termina el nivel. Con Isak a menos de 1,5 tiles pasa a prompt y encima del monitor sale la tecla del pulso (leída del Input Map, hoy «G») en la fuente de textos sobre una placa con borde cian. Al recibir el pulso (misma prueba que el receptor) se activa una vez: Isak queda sin control y la pantalla se enciende (0,33 s); luego Isak **gira de espaldas** mirando al monitor (estado `TURN`, 3 pasos de 1/12 s = 0,25 s: en los dos primeros la pantalla se queda llena de cian e Isak se tiñe de cian con `modulate`, sin arte nuevo; en el segundo cambia a la pose de espaldas), se abre el vórtice de salida a su alrededor y, al cerrarse, Isak ha sido absorbido y se emite `EventBus.level_completed` (vuelta al hub como antes). Valores `turn_*` en la sección `exit_terminal` de `data/world1_objects.json`. La salida dura 0,25 s más que antes. Solo necesita el pulso, que el 1-1 tiene desde el principio; `tools/validate_level.py` comprueba que el nivel tiene el pulso y que alcanza la terminal desde el camino a la meta.

Línea `eco_glitch` (columna 293, entre la terminal y la pared con glitch de la columna 298): con la puerta solo salía si se saltaba la puerta, porque tocarla terminaba el nivel; con la terminal, quien pase de largo sin pulsar G la oye. Encaja mejor: Eco intenta que el jugador no mire la pared con glitch (secreto D) justo cuando la terminal ya le espera. No se ha cambiado.

### Pose de espaldas de Isak (2026-10-15)

`assets/sprites/isak/isak_back_idle_00.png` (un cuadro, AutoSprite; importado y limpiado con `python3 -I tools/import_isak_back_idle.py`, `--clean-only` reaplica solo la limpieza del borde) es la animación `back_idle` de `scenes/player/isak_frames.tres` (`tools/build_isak_frames.gd`). Se usa desde código, no por estado:

- `isak.face_back()`: Isak se pone de espaldas (sin voltear), queda quieto (los estados ven una entrada quieta, como en el vórtice; la gravedad sigue), no recibe golpes ni arranca la terminal holográfica. Corta el láser.
- `isak.face_side()`: vuelve de perfil hacia `facing` con la animación de su estado y recupera el control (salvo que siga una llegada o salida).
- `isak.is_facing_back()`: consulta. Morir o reaparecer quitan la pose.

Para el hub (aún sin hacer): llamar a `face_back()` cuando Isak se acerque a un monitor o terminal del hub (p. ej. al abrir la selección de nivel o la tienda) y a `face_side()` al cerrarla. Capturas de la secuencia: `$GODOT --path . -s tools/render_warp_terminal.gd -- <carpeta>` (05 destello, 06 de espaldas, 07 vórtice).

## Arte del hub (2026-10-15)

Paso 11 de `propuesta-hub-y-guardado.md` §6.1, **integrado en el hub real (2026-10-15)**: `HubRoom`, la copia local, las carpetas y el HUD del hub lo usan (SpriteFrames `assets/sprites/hub/*_frames.tres`, escritos por el generador). Mismo lenguaje «circuito limpio» con la paleta del hub (`assets/palettes/hub.gpl`, propuesta; roles en `07-estilo-visual.md` §15.3.1): contorno `fondo_profundo`, bisel `borde`/`gris_foto`, trazas `traza` con nodos `borde`, cian para lo interactivo y ámbar solo en «sin guardar». Sin rojo. Fondo, tiles y carpetas se dibujan en rejilla lógica de 2x2 px (como el tileset del Mundo 1); copia local, Calc, huecos e iconos a 1 px (como la terminal de salida). Todo en `assets/sprites/hub/`.

| Objeto | Archivos (`assets/sprites/hub/…`) | Tamaño | Estados | Cuadros |
|---|---|---|---|---|
| Fondo: foto rota en 5 piezas (paisaje neutro en gris, piezas algo desplazadas: «desordenada») | `background/hub_bg_photo_off_00..01.png` | 1280x720, opaco | apagada (hub del 1-1): pieza 1 gris con contorno cian | 2 (contorno `acento_cian` / `cian_tenue`: parpadeo débil, ~1–2 fps) |
| | `background/hub_bg_photo_on_00.png` | 1280x720 | pieza 1 recompuesta y encendida (rampa `cian_tenue` → `acento_cian` → `cian_brillo`, halo y destello en el sol) | 1 |
| Dock (suelo) | `tiles/dock_top_left_00`, `dock_top_center_00`, `dock_top_right_00` | 64x64 | superficie (borde, bisel, traza, remaches) | 1 |
| | `tiles/dock_fill_00`, `dock_fill_alt_00` | 64x64 | interior en `sombra` (alt: rejilla y traza vertical) | 1 |
| Repisas de una vía | `tiles/one_way_left_00`, `one_way_center_00`, `one_way_right_00`, `one_way_single_00` | 64x64 | como las del Mundo 1 | 1 |
| Carpetas (hueco central para el número o la miniatura del mundo, que pone el código; insignia abajo a la derecha) | `folders/folder_locked_00.png` | 128x128 | bloqueada: `gris_apagado`, candado `texto_tenue` | 1 |
| | `folders/folder_available_00..01.png` | 128x128 | disponible: `panel` con contorno `acento_cian` | 2 (halo `cian_tenue` que late) |
| | `folders/folder_completed_00.png` | 128x128 | completada: relleno `acento_cian`, check `fondo_profundo` | 1 |
| Copia local (silueta de `exit_terminal`, icono de disquete) | `local_copy/local_copy_off_00..01.png` | 64x128 | apagada | 2 (LED parpadea) |
| | `local_copy/local_copy_prompt_00..01.png` | 64x128 | prompt (Isak cerca): marco y disquete cian, flecha «copiar» | 2 |
| | `local_copy/local_copy_active_00..01.png` | 64x128 | activa: pantalla `cian_brillo`, flecha que baja, halo | 2 |
| Calc | `calc/calc_sleep_00..02.png` | 64x96 | dormida: gris, ojos cerrados, «z» que sube | 3 |
| | `calc/calc_awake_00..03.png` | 64x96 | despierta: visor con ojos a media asta y media sonrisa en cian, tecla «=» y LED que laten | 4 (mira a un lado en el 2, parpadea en el 3) |
| Huecos del dock | `dock_slots/dock_slot_notes_00`, `dock_slot_flashlight_00`, `dock_slot_trash_00` | 64x96 | silueta apagada de Notas, Linterna y Papelera sobre un zócalo | 1 |
| HUD del hub | `icons/icon_airplane_mode_00.png` | 16x16 | Modo Avión (`texto_claro`) | 1 |
| | `icons/icon_unsaved_00.png` | 16x16 | «sin guardar»: disquete con punto, en `ambar` | 1 |
| Miniatura del mundo (carpetas, 2026-10-15) | `icons/world_icon_m1_00.png` | 16x16 (dibujada x2 junto al número) | Mundo 1: campana `texto_claro` con sombra `texto_tenue`, brillo `cian_brillo`, badajo `acento_cian` y contorno `fondo_profundo` (se lee en la carpeta disponible y en la completada); los mundos bloqueados no llevan miniatura | 1 |
| Indicador de página | `icons/page_dot_current_00.png`, `page_dot_other_00.png` | 8x8 | actual (lleno) / otra (anillo) | 1 |

Notas para integrar: los objetos se apoyan en el borde inferior de su lienzo (la copia local y la Calc sobre el dock, las carpetas sobre su repisa). El contenido de la foto es un paisaje neutro provisional: el diseño no dice qué muestra la foto de Isak. Las repisas quedan a 160 px del dock (2,5 tiles, alcanzables de un salto) y las carpetas se bajan 8 px (`folder_sink_px`) para apoyarse en ellas; `--scene` usa esas posiciones de `data/hub.json`.

Regenerar (desde la raíz): `python3 -I tools/gen_hub_objects.py` (`--dry-run`; `--preview <png> [--scale N]` hoja de contacto; `--scene <png>` composición 1280x720 con el mapa de §2.2, y `<png>_on` con la pieza encendida). Validar: `python3 -I tools/validate_hub_objects.py` (tamaño por carpeta, solo colores de `hub.gpl`, sin rojos reservados, alfa 0/255, transparencia, tiles sin costura PNG y SpriteFrames al día con el generador; lo ejecuta `tools/run_tests.sh`).

## Eco compañero (2026-10-16)

Paso 4 de `propuesta-asistentes-y-vidas.md` §10. Esfera de luz blanca y azul con un arco de píxeles que hace de sonrisa (`04-personajes.md` §12.1), coherente con `assets/sprites/ui/eco_icon.png`: contorno `noche_profunda`, borde `resplandor`, núcleo `banner_blanco` con sombra `borde_luz` abajo a la derecha, sonrisa `cielo` (mira a la derecha; el código voltea con Isak) y una órbita de tres arcos partidos con nodos de 2x2 (como el vórtice) que gira. Lienzo 32x32 (esfera de unos 21 px), dibujado a x2 en el juego (`sprite_scale` de `data/eco_companion.json`).

| Animación | Archivos (`assets/sprites/eco/companion/`) | Cuadros |
|---|---|---|
| Reposo | `eco_idle_00..03.png` | 4 a 6 fps, bucle: la órbita gira 30° por cuadro (un tercio de vuelta: bucle limpio); en el 3 la sonrisa «parpadea» (arco corto) |
| Habla | `eco_talk_00..02.png` | 3 a 10 fps, bucle: la boca se abre y se cierra y salen ondas de eco por el lado de la cara |
| Reacción | `eco_notice_00..01.png` | 2 a 8 fps: halo de 1 px, destello en cruz y boca abierta (al hablar o al salir una Q) |
| Aparecer | `eco_appear_00..03.png` | 4 a 12 fps: chispa, esfera pequeña, mediana con halo y completa con halo; desaparecer es la misma secuencia al revés (solo en el SpriteFrames) |
| Hub (atenuada) | `eco_<anim>_dim_NN.png` | Las mismas animaciones con grises de `hub.gpl` (`fondo_profundo`, `panel`, `gris_apagado`, `gris_foto`, `texto_tenue`, `texto_claro`) y la órbita rota (dos arcos de tres): sin cobertura |

Regenerar: `python3 -I tools/gen_eco_companion.py` (`--preview <png> [--scale N]` hoja de contacto sobre el fondo del mundo y del hub; escribe también `assets/sprites/eco_companion_frames.tres`). Validar: `python3 -I tools/validate_eco_companion.py` (tamaño, alfa 0/255, transparencia, paleta por variante sin rojos, ámbar ni cian del Debug, PNG y SpriteFrames al día; lo ejecuta `tools/run_tests.sh`). Comportamiento en `scripts/levels/eco_companion.gd`.
