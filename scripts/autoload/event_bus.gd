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

## Cambian los power banks que se tienen (`held`, completos; coleccionable puro
## desde el 2026-10-25). Lo emite GameState.
@warning_ignore("unused_signal")
signal power_banks_changed(held: int)

## Se ha comprado el siguiente nivel de la pista de mejoras `id` (data/upgrades.json,
## p. ej. "pulso"). Lo emite GameState.purchase_upgrade.
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
## Isak empieza un dash (gesto Deslizar, 2026-10-19) hacia `direction` (-1/1).
@warning_ignore("unused_signal")
signal dash_started(direction: float)
## Intento de dash sin energia suficiente o con el Debug activo o cargando
## (Isak.DASH_DENIED_ENERGY / DASH_DENIED_DEBUG): chispa gris, no sale.
@warning_ignore("unused_signal")
signal dash_denied(reason: StringName)
## Pellizcar (2026-10-26, docs/propuesta-mundo-3.md §3.3): Isak se comprime
## (`compressed` true) o recupera el tamano (false). Sonidos sfx_gesture_pinch /
## sfx_gesture_unpinch.
@warning_ignore("unused_signal")
signal compress_changed(compressed: bool)
## Likes del Mundo 3 (2026-10-26, paso 2 de docs/propuesta-mundo-3.md §3.1):
## el contador del intento (GameState.likes, 0-likes_max) ha cambiado. No se
## guarda. Lo escuchan HudLikes y las plataformas de likes.
@warning_ignore("unused_signal")
signal likes_changed(likes: int, likes_max: int)
## Golpe al suelo (gesto Mantener presionado, 2026-10-22): Isak aterriza y nace la
## onda en `rect` (px globales, a ras de suelo; incluye unos px bajo los pies).
## Las tarjetas fragiles, los muros y los enemigos que reaccionan se enganchan aqui.
@warning_ignore("unused_signal")
signal ground_pound_landed(rect: Rect2, source: Node2D)
## Scroll forzado del Mundo 2 (2026-10-22): Isak toca el borde que dana
## (`damaged`: le quito Sync Rate). El reloj del HUD (HudClock) salta +1 h con esto.
@warning_ignore("unused_signal")
signal scroll_edge_hit(damaged: bool)
## Una seccion en bucle del Mundo 2 se repite (`count` = repeticiones). El reloj
## del HUD saltara +1 h con esto.
@warning_ignore("unused_signal")
signal loop_wrapped(loop_id: StringName, count: int)

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

## Se ha conocido al asistente `ally` (GameState.meet_ally; propuesta de
## asistentes §2). EcoCompanion aparece cuando es "eco".
@warning_ignore("unused_signal")
signal ally_met(ally: StringName)

## El asistente `ally` se ha ido al hub por un vortice desde un nivel
## (2026-10-17, tanda H1 del paso 14 del 1-2: Calc tras cargarse en la azotea,
## CalcActor). NO lo marca como conocido: GameState lo apunta como llegada
## pendiente de la sesion (ally_arrivals) y el hub hace el encuentro (tanda H3,
## CalcIntro), que llama a GameState.meet_ally al terminar. En pruebas se provoca
## emitiendo esta senal (o con GameState.note_ally_teleported); en builds de
## depuracion, con `-- --ally-teleported=calc`.
@warning_ignore("unused_signal")
signal ally_teleported(ally: StringName)

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

## Cambio un ajuste del jugador (GameSettings: guardado al instante en
## settings.cfg, aparte del guardado de la partida). Hoy: show_eco_help.
@warning_ignore("unused_signal")
signal settings_changed(key: StringName, value: Variant)

## Se abre / se cierra el menu de pausa (PauseMenu).
@warning_ignore("unused_signal")
signal pause_menu_opened
@warning_ignore("unused_signal")
signal pause_menu_closed

## Cambiaron los controles del Input Map (reasignacion en Ajustes > Controles o
## al restablecerlos; ControlBindings). Los prompts de tecla («G», «Q») se
## vuelven a leer del Input Map.
@warning_ignore("unused_signal")
signal controls_changed

## El jugador ha vuelto a leer la ayuda de un tipo ya aprendido (Q apagada).
@warning_ignore("unused_signal")
signal help_reread(help_id: StringName)

## Mejoras de Calc, tanda M2 (docs/propuesta-mejoras.md, 2026-10-17).
## Ocultarte (Pulso 4) se activa o se apaga (GameState.set_player_hidden).
@warning_ignore("unused_signal")
signal hide_changed(active: bool)
## Ocultarte se apago solo o por una accion: `reason` es HideMode.REASON_*
## (cut = Sync Rate o energia al 10 %, pulse, laser, hurt, debug, toggle...).
@warning_ignore("unused_signal")
signal hide_ended(reason: StringName)
## Lo revelado por el Debug se ve y es solido (`revealing`): Debug activo o, con
## el Debug 3, durante la persistencia tras apagarlo (DebugMode.is_revealing).
@warning_ignore("unused_signal")
signal debug_reveal_changed(revealing: bool)
## Pulso de retorno (Pulso 5): aturdir a `enemy` dio `amount` de energia
## (`gained` = lo que entro en la barra; el resto se pierde).
@warning_ignore("unused_signal")
signal pulse_energy_returned(enemy: Node, amount: float, gained: float)
## Se obtuvo el recuerdo `memory_id` (data/memories.json; GameState.obtain_memory):
## queda «sin guardar» y sin leer (docs/propuesta-recuerdos.md §4).
@warning_ignore("unused_signal")
signal memory_obtained(memory_id: StringName)
## Se leyo en Notas el recuerdo `memory_id` (GameState.mark_memory_read): el icono
## de Notas del hub deja de marcarlo como nuevo.
@warning_ignore("unused_signal")
signal memory_read(memory_id: StringName)

## Jefes (2026-10-21, paso 2 de docs/propuesta-jefe-alerta-mayor.md §6; BossBase).
## El audio, el HUD y el bot se enganchan aqui. No hay senal de rollback: ningun
## jefe salvo el final hace rollback (decision 1 de la propuesta).
## Empieza la pelea (fase 1).
@warning_ignore("unused_signal")
signal boss_started(boss_id: StringName)

## Cambia la fase (1, 2, 3...) al vaciar la anterior; no se emite al empezar.
@warning_ignore("unused_signal")
signal boss_phase_changed(boss_id: StringName, phase: int)

## Un golpe al nucleo cuenta; `remaining` = golpes que le quedan al jefe.
@warning_ignore("unused_signal")
signal boss_weak_point_hit(boss_id: StringName, remaining: int)

## El jefe recupera golpes (BossBase.heal_hits: la cuenta de la fase 2 de
## Autoplay llega a 0, 2026-10-23); `remaining` = golpes que le quedan.
@warning_ignore("unused_signal")
signal boss_healed(boss_id: StringName, remaining: int)

## Golpe final: el contador llega a 0.
@warning_ignore("unused_signal")
signal boss_defeated(boss_id: StringName)
