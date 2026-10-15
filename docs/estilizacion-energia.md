# Estilización de los objetos de energía y progreso (1-1)

Estado: **integrado** (2026-10-15), pendiente de revisión del usuario. Sustituye en lo visual a los dibujos provisionales `_draw` de `recharge_pickup`, `power_bank_pickup`, `charger` y `ability_pickup`. Cada objeto crea en `_ready` un `EnergySprite` (`scripts/levels/energy_sprite.gd`, un `AnimatedSprite2D`) con las animaciones de `assets/sprites/energy_objects_frames.tres` (una por estado, con sus fps); el objeto la avanza con tiempo del mundo, así que se ralentiza con el Debug y se detiene con la pausa. Las colisiones no cambian. Los colores de los `_draw` que quedan en `data/world1_objects.json` y `data/recharge_pickup.json` ya no se usan.

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

## Pendiente

- Los `.import` de Godot se crean la primera vez que se abre el editor (o con `tools/run_tests.sh`, que importa el proyecto); se commitean como los del resto de `assets/sprites/`.
