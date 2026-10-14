# EventBus (autoload)
# Bus de eventos globales. Solo declara señales; no guarda estado ni contiene lógica.
# Los nodos que necesitan enterarse de cambios globales (HUD, efectos, etc.) se
# conectan aquí en lugar de referenciarse entre sí. GameState emite estas señales
# desde sus setters cuando cambia un valor.
extends Node

@warning_ignore("unused_signal")
signal sync_rate_changed(new_value: float, max_value: float)

@warning_ignore("unused_signal")
signal energy_changed(new_value: float, max_value: float)

@warning_ignore("unused_signal")
signal attention_points_changed(new_value: int)

## El Sync Rate cruza el umbral de Sync Rate bajo (data/hud.json). Gancho para
## el ruido/distorsion de pantalla y la musica deformada (pendientes).
@warning_ignore("unused_signal")
signal low_sync_changed(is_low: bool)

## Cambia el mundo actual (1-6). El HUD lo usa para el color del Debug.
@warning_ignore("unused_signal")
signal world_changed(world: int)

## Opcion de accesibilidad: reducir los efectos de Sync Rate bajo (docs 3.3, 15.6).
@warning_ignore("unused_signal")
signal reduce_low_sync_effects_changed(enabled: bool)

## Alguien (p. ej. el HUD al aparecer) pide que GameState reemita su estado.
@warning_ignore("unused_signal")
signal state_refresh_requested

@warning_ignore("unused_signal")
signal ability_unlock_changed(ability: StringName, unlocked: bool)

@warning_ignore("unused_signal")
signal player_died

## El Debug Mode se activa o se apaga (DebugMode). `active` cambia al instante;
## la transicion visual y de tiempo sigue unos instantes (data/debug_mode.json).
@warning_ignore("unused_signal")
signal debug_mode_changed(active: bool)

## Progreso (0-1) de la pulsacion larga que activa el Debug (DebugMode). Vale
## 0 cuando no se esta cargando (cancelado, ya activo o bloqueado). Lo usa el
## indicador de carga del HUD.
@warning_ignore("unused_signal")
signal debug_activation_progress_changed(progress: float)

## Cambia la escala de tiempo del mundo (1 = normal; 0,5 con el Debug). La
## consumen los objetos del mundo (ver scripts/autoload/world_time.gd).
@warning_ignore("unused_signal")
signal world_time_scale_changed(scale: float)

## Opcion de accesibilidad: contorno mas claro y grueso en las plataformas
## ocultas del Debug (daltonismo, docs 15.6).
@warning_ignore("unused_signal")
signal debug_high_contrast_outline_changed(enabled: bool)

## Isak dispara el pulso de datos (lo reemite Isak.set_pulse_area_active junto
## a su senal pulse_fired). `area` es PulseArea: un circulo de pulse_radius_px
## centrado en el celular. Lo usan los objetos del entorno que el pulso activa
## (receptores del Mundo 1).
@warning_ignore("unused_signal")
signal pulse_fired(area: Area2D)
