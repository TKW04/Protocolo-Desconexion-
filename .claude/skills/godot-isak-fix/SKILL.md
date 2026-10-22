---
name: godot-isak-fix
description: Convenciones de arquitectura, física y configuración de Godot 4 para Isak Fix. Úsalo al escribir o modificar cualquier script, escena, estado del personaje, enemigo, jefe, HUD o configuración del proyecto.
---

# Godot 4 para Isak Fix

## Configuración del proyecto

- Display, ventana: ancho 1280, alto 720. Stretch mode `viewport`, scale mode `integer` (decisión del 2026-10-14; antes 640x360). Desde el 2026-10-20 el jugador elige «Escalado: Llenar ventana» (por defecto, fraccional) o «Nítido» (entera); `GameSettings.apply_scale_mode` lo aplica en tiempo de ejecución sin tocar `project.godot`.
- Rendering, texturas: default texture filter en `Nearest`.
- Activa el ajuste de transformaciones 2D a píxel (`snap_2d_transforms_to_pixel`) para evitar temblor.
- Usa `TileMapLayer` para los niveles. Tiles de 64x64. El sprite de Isak usa un canvas de 128x128 con unos 96 px visibles y los pies abajo-centro.

## Estructura de carpetas

```
res://
  assets/
    sprites/        # por entidad: isak/, enemies/, bosses/, ui/
    palettes/       # un .gpl por mundo
    audio/
  data/
    isak_physics.json
    levels/         # un archivo por nivel, ver level-builder
  scenes/
    player/ enemies/ bosses/ levels/ hub/ ui/
  scripts/
    autoload/       # GameState, EventBus
    player/ enemies/ bosses/ levels/ ui/
  tests/
```

## Convenciones de código

- GDScript tipado siempre: `var speed: float = 360.0`, `func take_damage(amount: int) -> void:`.
- Nombres en inglés con snake_case. Clases en PascalCase. Constantes en MAYUSCULAS.
- Comunicación entre nodos con señales. Para eventos globales, un autoload `EventBus`.
- Estado global (Sync Rate, energía de Debug, puntos de atención, fragmentos recuperados, nivel actual) en un autoload `GameState`. Nada de estado del jugador repartido por escenas.
- Los valores de ajuste (velocidades, tiempos, daños) van en archivos de datos o `@export`, nunca como números sueltos dentro de la lógica.

## El jugador (Isak)

`CharacterBody2D` con una máquina de estados: `Idle`, `Run`, `Jump`, `Fall`, `Pulse`, `Dash`, `GroundPound`, `Compressed`, `Hurt`, `Dead`. Cada estado es un nodo o un script propio. Las habilidades se desbloquean por mundo, así que `GameState` guarda cuáles están activas.

### Física inicial (ajustar jugando, son punto de partida)

Altura de salto de 3 tiles (192 px, con tiles de 64) y tiempo al apogeo de 0.4 s. Valores ×2 respecto a la versión de 640x360, con los mismos tiempos:

- `jump_velocity = -2 * h / t = -960`
- `gravity = 2 * h / t^2 = 2400`
- Velocidad de caminar 220 px/s y de correr 360 px/s, con aceleración y fricción suaves para sentir peso.
- Coyote time 0.1 s. Jump buffer 0.1 s. Caída con gravedad un 30% mayor que la subida.
- Guarda estos valores en `data/isak_physics.json`. El validador de `level-builder` los lee de ahí.

### Idle
Tras unos segundos quieto, Isak reproduce la animación de la terminal holográfica. Es un detalle de personalidad y en el combate final tiene un uso de gameplay (detenerse), así que el estado `Idle` debe poder detectar "tiempo quieto".

### Habilidades (ver docs/02-isak-habilidades.md)
- Pulso de datos: aturde enemigos y activa objetos del entorno.
- Debug Mode: ralentiza el tiempo, muestra plataformas ocultas y puntos débiles. Gasta energía. Su color depende del mundo.
- Láser (2026-10-15): acción `laser` (F / gatillo izquierdo), proyectil horizontal (`LaserProjectile`) que gasta la misma energía que el Debug; desbloqueable con `ability_pickup`. A quien alcanza le llama `on_laser_hit(damage, source)`; los objetos del entorno que reaccionen en el futuro implementan ese método (y, si son Area2D, van en el grupo `laser_activatable`).
- Enemigos y jefes: vida con `EnemyHealth` (`health` en el JSON del enemigo, `params.health` del nivel la sobrescribe) y `drops` al morir.
- Gestos por mundo: dash, golpe al suelo, compresión, onda de aturdimiento y combos. El mapeo a controles es una decisión abierta: pregunta antes de fijarlo. Decididos: Deslizar (dash) = `gesture_swipe` (L / B); Mantener presionado (golpe al suelo, 2026-10-22) = mantener los eventos de `move_down` (S / flecha abajo / abajo del mando; `ActionPlayerInput.hold_held`), sin tecla nueva; estado `GroundPound` y sección `ground_pound` de `data/isak_abilities.json`.

## Efectos

- Debug: ralentizar con `Engine.time_scale` o con un factor propio que no afecte a la UI. Teñido con shader y viñeta del color del mundo.
- Daño: shader de desplazamiento de píxeles (glitch) de corta duración.
- Sync Rate menor al 20%: ruido y distorsión con una opción de accesibilidad para reducirlos.

## Pruebas

- Ejecuta Godot sin ventana: `godot --headless` con el framework de pruebas que se elija (GUT o gdUnit4, pregunta cuál).
- Mínimo: pruebas de la física del salto, de coyote time, de jump buffer y de las transiciones de estado.
