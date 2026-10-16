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

## Un enemigo queda eliminado (p. ej. la Burbuja de alerta al reventar cuando
## Isak cae sobre ella aturdida, C7). `enemy` sigue valido durante la senal.
@warning_ignore("unused_signal")
signal enemy_defeated(enemy: Node2D)

## Alguien (p. ej. un disparador eco_line del nivel) pide mostrar una linea de
## Eco en el cuadro de texto (EcoTextBox). `duration_s` <= 0: tiempo por
## defecto de data/eco_text_box.json. Si ya hay una linea en pantalla, se pone
## en cola. `important` (habilidad adquirida, historia): pausa el juego hasta
## que el jugador la cierra y pasa delante de las normales en cola.
@warning_ignore("unused_signal")
signal eco_line_requested(text: String, duration_s: float, important: bool)

## El cuadro de Eco empieza a mostrar `text` (comienza la maquina de escribir).
@warning_ignore("unused_signal")
signal eco_line_started(text: String)

## El cuadro de Eco termina de mostrar la linea actual (ya se ha ocultado).
@warning_ignore("unused_signal")
signal eco_line_finished

## Isak ha completado el nivel `level_id` (ExitTerminal o ExitDoor, al terminar
## su salida). LevelRunner lo usa para volver al hub real (C4; paso 9 de
## docs/propuesta-hub-y-guardado.md, scenes/hub/hub.tscn).
@warning_ignore("unused_signal")
signal level_completed(level_id: String)

## Isak ha tocado un punto de sincronizacion: pasa a ser el ultimo de `level_id`
## (GameState.last_checkpoint). Lo emite GameState.set_last_checkpoint.
@warning_ignore("unused_signal")
signal checkpoint_activated(level_id: String, checkpoint_id: StringName)

## Isak reaparece (LevelRunner) tras morir (`after_death`) o tras caer fuera del
## nivel (red de seguridad), en `position` (pies).
@warning_ignore("unused_signal")
signal player_respawned(position: Vector2, after_death: bool)

## Cambian los power banks: `full` completos y `charge` de carga parcial sobre
## `capacity` (data/power_bank.json). Lo emite GameState.
@warning_ignore("unused_signal")
signal power_banks_changed(full: int, charge: float, capacity: float)

## Se ha comprado la mejora permanente `id` (data/upgrades.json). Lo emite
## GameState.purchase_upgrade.
@warning_ignore("unused_signal")
signal upgrade_purchased(id: StringName)

## Isak recoge una recarga (RechargePickup): `kind` es "debug_energy" o
## "sync_rate" y `amount` lo que valia.
@warning_ignore("unused_signal")
signal recharge_collected(kind: StringName, amount: float)

## Isak obtiene para siempre la habilidad `ability` (ability_pickup; lo emite
## GameState.obtain_ability). P. ej. &"laser".
@warning_ignore("unused_signal")
signal ability_obtained(ability: StringName)

## Isak dispara el laser: `projectile` es el LaserProjectile recien creado.
@warning_ignore("unused_signal")
signal laser_fired(projectile: Node2D)

## Isak intenta disparar el laser sin energia suficiente (no sale el disparo).
@warning_ignore("unused_signal")
signal laser_denied

## Un cargador (charger) repone `amount` de energia de Debug.
@warning_ignore("unused_signal")
signal charger_used(charger_id: StringName, amount: float)

## Cambia si hay progreso sin guardar (guardado manual, 2026-10-15): true al
## primer cambio tras guardar o cargar (GameState.request_save), false al
## guardar (GameState.save_game) o cargar. Lo usan el indicador «sin guardar»
## y el aviso al salir.
@warning_ignore("unused_signal")
signal unsaved_changes_changed(has_changes: bool)

## Se ha escrito el guardado en disco (GameState.save_game) en `path`.
@warning_ignore("unused_signal")
signal game_saved(path: String)

## Se ha aprendido la ayuda con Q del tipo `help_id` (GameState.learn_help;
## docs/propuesta-asistentes-y-vidas.md §3): ninguna instancia de ese tipo
## vuelve a mostrar la Q.
@warning_ignore("unused_signal")
signal help_learned(help_id: StringName)

## «Olvidar ayudas» del album de Notas vacio learned_help (GameState.forget_help).
@warning_ignore("unused_signal")
signal help_forgotten

## Se ha conocido al asistente `ally` (GameState.meet_ally; propuesta de
## asistentes §2). EcoCompanion aparece cuando es "eco".
@warning_ignore("unused_signal")
signal ally_met(ally: StringName)

## El apodo cambio (GameState.set_nickname).
@warning_ignore("unused_signal")
signal nickname_changed(nickname: String)

## Sale una Q de ayuda sobre `target` (HelpSystem; Eco reacciona).
@warning_ignore("unused_signal")
signal help_prompt_shown(target: Node2D)

## Cambian las vidas (intentos) del intento en curso o su maximo; `active`:
## ya cuentan (desde la primera llegada al hub). Lo emite GameState; lo usa el
## HUD de vidas.
@warning_ignore("unused_signal")
signal lives_changed(lives: int, lives_max: int, active: bool)

## Se ha perdido una vida al morir; quedan `lives_left` (0 = game over).
@warning_ignore("unused_signal")
signal life_lost(lives_left: int)
## Vida extra recogida (paso 14): lives_max ya subio y el secreto `secret_id`
## de `level` quedo en found_secrets.
signal extra_life_collected(level: StringName, secret_id: StringName)

## Eco aplico un rollback (GameState.apply_rollback): `report` con reason,
## had_copy, first, trash_has_content y trash.
@warning_ignore("unused_signal")
signal rollback_applied(report: Dictionary)

## Cambia si hay contenido en la papelera pendiente de recuperar.
@warning_ignore("unused_signal")
signal trash_changed(pending: bool)

## Se recupero todo lo de la papelera (`trash`: lo que tenia).
@warning_ignore("unused_signal")
signal trash_recovered(trash: Dictionary)
