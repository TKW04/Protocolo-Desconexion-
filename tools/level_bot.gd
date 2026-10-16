## Bot de recorrido del 1-1 (paso 16; generico desde el 1-1 ampliado): carga la escena principal (scenes/main.tscn,
## LevelRunner) y juega el nivel con una entrada falsa (PlayerInput), con la fisica
## y los objetos reales:
##   camina a la derecha; salta si choca con una pared o si delante no hay suelo
##   (rayo hacia abajo: cuenta el puente y la Burbuja aturdida); se para y lanza
##   el pulso en el receptor (espera al puente), ante la Burbuja (espera a que este
##   aturdida y la cruza) y ante el pop-up (espera a que se cierre); con el laser
##   ya recogido (sala del laser del 1-1, rediseno 2026-10-15: dos receptores y un
##   pop-up en alto, que la politica generica resuelve sola) se para y dispara a las
##   Burbujas que tiene delante a su altura hasta matarlas (si le queda energia; si
##   no, vuelve al pulso); toca el punto
##   de sincronizacion y, con --die (por defecto), fuerza una muerte (Sync Rate 0)
##   tras tocarlo y comprueba que reaparece alli con el 100 %; se para en la
##   terminal de salida (2026-10-15: tocarla no basta) y la activa con el pulso
##   (Isak gira de espaldas, mirando al monitor, con un destello cian y es
##   absorbido por el vortice de salida; comprueba que no llega al hub sin
##   haberse puesto de espaldas antes del vortice),
##   llega al hub real (paso 9: vortice de llegada; nivel completado, 1-2
##   desbloqueado, energia llena, «Sin guardar» y nada escrito: guardado
##   manual, 2026-10-15), camina a la copia local y guarda con el pulso, sube a la repisa de
##   la carpeta del Mundo 1, la abre y elige el 1-1 (si pidiera confirmar por
##   cambios sin guardar, elige «Entrar sin guardar»): el nivel vuelve
##   a empezar con Sync Rate y objetos desde cero, pero los puntos de atencion
##   se conservan y los ya capturados no reaparecen (decision 2026-10-14).
## Ayuda de Eco con Q (2026-10-15 (3)): el bot nunca pulsa help; la Q sale sobre
## los tipos no aprendidos sin bloquear nada. Anota cuantos cuadros se vio y
## falla si el juego se pausa sin una linea importante de Eco en pantalla.
## Usa su propio guardado (BOT_SAVE_PATH, borrado al empezar; o ISAK_SAVE_PATH
## si esta definida): nunca toca el user://save.json del jugador.
## Termina con codigo 0 si todo sale bien y 1 si algo falla (con el motivo).
## Lo lanza tools/play_level_bot.gd (los scripts -s no pueden nombrar autoloads
## ni clases que los usen al compilar, asi que la logica va aqui).
## Uso (rapido, sin ventana):
##   Godot --headless --fixed-fps 60 --path . -s tools/play_level_bot.gd [-- --no-die] [--run]
## --run recorre el nivel corriendo. Al activar la terminal anota la duracion del
## recorrido (sin la muerte forzada). Con ventana (para verlo): quita --headless.
extends Node

const MAIN_SCENE: String = "res://scenes/main.tscn"
const TILE: float = 64.0
const MAX_FRAMES: int = 60 * 420
const STUCK_FRAMES: int = 60 * 8
const JUMP_HOLD_FRAMES: int = 22
## Se para a esta distancia (tiles) antes de la celda del receptor para lanzar el pulso.
const RECEIVER_STOP_TILES: float = 1.5
## Se para a esta distancia (px) antes del borde izquierdo del pop-up (boton a mano).
const POPUP_STOP_GAP: float = 58.0
## Diferencia maxima (px) entre los pies de Isak y la base de un receptor o pop-up
## para considerarlo de la ruta.
const ROUTE_TOLERANCE: float = 40.0
## Alcance (px) del rayo que busca suelo delante.
const GROUND_PROBE_PX: float = 100.0
## Distancia (px) entre el celular de Isak y el costado de la Burbuja para lanzar el pulso.
const BUBBLE_PULSE_GAP: float = 70.0
## Distancia maxima (px) entre el celular de Isak y el costado de la Burbuja para dispararle
## el laser (alcance del laser: 768 px).
const BUBBLE_LASER_GAP: float = 6.0 * TILE
const LAYER_WORLD: int = 1
## Se para a esta distancia (px) del borde izquierdo de la terminal de salida (en
## su celda G) para lanzarle el pulso.
const TERMINAL_STOP_PX: float = 24.0
const BOT_SAVE_PATH: String = "user://bot_save.json"
## En el hub, se para a esta distancia (px) a la derecha del borde izquierdo de la
## copia local para lanzarle el pulso (como test_copy_local_station: 2,6 tiles).
const COPY_LOCAL_STAND_PX: float = 2.6 * TILE - 64.0

var _input := PlayerInput.new()
var _runner: LevelRunner
var _isak: Isak
var _frame: int = 0
var _jump_left: int = 0
var _hits: int = 0
var _die: bool = true
## --run: recorre el nivel corriendo (accion run) en vez de caminando.
var _running: bool = false
## Cuadros gastados en la muerte forzada (no cuentan en la duracion del recorrido).
var _death_frames: int = 0
var _died_done: bool = false
var _log: PackedStringArray = []
## Puntos de atencion del mapa al empezar (guardado limpio).
var _points_total: int = 0
## Disparos del laser y Burbujas que mata.
var _shots: int = 0
var _kills: PackedStringArray = []


## Fin del recorrido: 0 si todo ha ido bien, 1 si algo ha fallado.
signal finished(code: int)

## Cuadros con la Q de ayuda visible (el bot no la pulsa).
var _help_frames: int = 0
## Capturas (--shots <carpeta>, necesita ventana): nombre -> cuadro en que se toma.
var _shots_dir: String = ""
var _pending_shots: Dictionary = {}


func _ready() -> void:
	var env_path: String = OS.get_environment(GameState.SAVE_PATH_ENV)
	GameState.use_save_path(BOT_SAVE_PATH if env_path.is_empty() else env_path, true)
	var args: PackedStringArray = OS.get_cmdline_user_args()
	_die = not args.has("--no-die")
	_running = args.has("--run")
	var at: int = args.find("--shots")
	if at >= 0 and at + 1 < args.size():
		_shots_dir = args[at + 1]
		DirAccess.make_dir_recursive_absolute(_shots_dir)
		_shot_in("1_inicio", 90)
	_run.call_deferred()


func _run() -> void:
	var main: Node = (load(MAIN_SCENE) as PackedScene).instantiate()
	get_tree().root.add_child(main)
	_runner = main as LevelRunner
	await get_tree().physics_frame
	_attach()
	var ok: bool = await _play()
	if ok:
		ok = await _hub_and_back()
	_note("Q de ayuda visible %d cuadros; tipos aprendidos: %d (el bot no pide ayuda)" % [
		_help_frames, GameState.learned_help.size()])
	if not GameState.learned_help.is_empty():
		ok = _fail("El bot no pide ayuda y hay tipos aprendidos")
	print("play_level_bot: %s" % ("OK" if ok else "FALLO"))
	for line: String in _log:
		print("  " + line)
	finished.emit(0 if ok else 1)


func _attach() -> void:
	_isak = _runner.get_isak()
	_isak.input = _input
	_isak.hurt.connect(func() -> void: _hits += 1)


## Un cuadro de fisica; toma las capturas pendientes que tocan. Cierra las
## lineas importantes de Eco (pausan el juego hasta que el jugador confirma).
func _tick() -> void:
	await get_tree().physics_frame
	_frame += 1
	_watch_help()
	_confirm_eco_lines()
	for name: String in _pending_shots.keys():
		if _frame >= int(_pending_shots[name]):
			_pending_shots.erase(name)
			await RenderingServer.frame_post_draw
			var path: String = _shots_dir.path_join(name + ".png")
			get_viewport().get_texture().get_image().save_png(path)
			_note("captura " + path)


## La Q de ayuda no bloquea: se anota la primera vez que sale y los cuadros que
## se ve (help nunca se pulsa).
func _watch_help() -> void:
	var level: Node = _runner.get_level() if _runner != null else null
	var help := level.get_node_or_null(^"Help") as HelpSystem if is_instance_valid(level) else null
	if help == null or not help.is_prompt_visible():
		return
	if _help_frames == 0:
		var target: Node = help.get_target()
		_note("Q de ayuda visible sobre %s (no se pulsa; no bloquea)" % (target.name if target != null else "?"))
	_help_frames += 1


func _confirm_eco_lines() -> void:
	var level: Node = _runner.get_level() if _runner != null else null
	var box := level.get_node_or_null(^"EcoTextBox") as EcoTextBox if is_instance_valid(level) else null
	while box != null and box.is_important() and box.confirm():
		pass


func _shot_in(name: String, frames: int) -> void:
	if not _shots_dir.is_empty():
		_pending_shots[name] = _frame + frames


func _note(text: String) -> void:
	_log.append("[%5.1f s] %s" % [_frame / 60.0, text])


func _fail(text: String) -> bool:
	_note("FALLO: " + text)
	return false


## Juega hasta que se muestra el hub. Falso si se atasca o se agota el tiempo.
## Generico (1-1 ampliado): recorre todos los receptores, puentes, pop-ups y
## Burbujas del nivel. Solo atiende a los de la ruta (a la altura de los pies de
## Isak): el receptor y los pop-ups de los secretos (popup_alto y popup_lejano, el
## del Pulso amplio) quedan en lo alto y se ignoran; los de la sala del laser (3b)
## quedan a la altura de los pies al subir por sus puentes. Las Burbujas en abierto
## se aturden al tenerlas delante y se cruzan andando; con el laser se matan a
## distancia (2026-10-15). No usa sus repisas. Solo recoge los puntos que encuentra
## andando por la ruta (el de la repisa del 3c y los de los secretos no).
func _play() -> bool:
	var level: GeneratedLevel = _runner.get_level()
	var receivers: Array[PulseReceiver] = []
	var bridges: Dictionary = {}
	var popups: Array[PopupBlocker] = []
	for node: Node in level.get_node(^"Objects").get_children():
		if node is PulseReceiver:
			receivers.append(node)
		elif node is PulseBridge:
			bridges[(node as PulseBridge).object_id] = node
		elif node is PopupBlocker:
			popups.append(node)
	var bubbles: Array[AlertBubble] = []
	for node: Node in level.get_node(^"Enemies").get_children():
		if node is AlertBubble:
			bubbles.append(node)
			var bubble_id: String = node.name
			(node as AlertBubble).popped.connect(func() -> void:
				_kills.append(bubble_id)
				_note("laser: %s eliminada" % bubble_id))
	_isak.laser_fired.connect(func(_p: LaserProjectile) -> void: _shots += 1)
	var had_laser: bool = GameState.is_ability_unlocked(GameState.ABILITY_LASER)
	var checkpoint: Checkpoint = level.get_node(^"Checkpoints").get_child(0) as Checkpoint
	var terminal: ExitTerminal = level.get_node(^"Objects/terminal_salida")
	_points_total = level.get_node(^"AttentionPoints").get_child_count()
	var best_x: float = 0.0
	var best_frame: int = 0
	var announced: Dictionary = {}
	while _frame < MAX_FRAMES:
		if _runner.is_in_hub():
			if not announced.has("espaldas"):
				return _fail("Isak no se puso de espaldas ante la terminal antes del vortice de salida")
			_note("hub real cargado tras completar el nivel")
			return true
		var x: float = _isak.global_position.x
		var feet: float = _isak.global_position.y
		if x > best_x + 4.0:
			best_x = x
			best_frame = _frame
		var waiting: bool = false
		_input.move_axis = 1.0
		_input.run_held = _running
		var gate: Dictionary = _gate_ahead(x, feet, receivers, bridges, popups, bubbles)
		var target: AlertBubble = _laser_target(x, feet, bubbles) if gate.is_empty() else null
		if not had_laser and GameState.is_ability_unlocked(GameState.ABILITY_LASER):
			had_laser = true
			_note("recoge el laser (x=%.0f, columna %d; energia %.0f)" % [x, int(x / TILE), GameState.debug_energy])
			_shot_in("6_laser", 30)
		if _runner.get_phase() != LevelRunner.Phase.PLAYING or _isak.is_dead() or _isak.is_warping():
			_input.move_axis = 0.0
			waiting = true
		elif _terminal_waiting(terminal):
			_input.move_axis = 0.0
			waiting = true
			if x >= terminal.global_position.x + TERMINAL_STOP_PX:
				if not announced.has("terminal_prompt"):
					announced["terminal_prompt"] = true
					_note("terminal de salida: prompt %s con la tecla '%s'" % [
						"visible" if terminal.is_key_hint_visible() else "NO visible", terminal.get_key_hint_text()])
				_try_pulse("terminal", announced)
			else:
				_input.move_axis = 1.0
				waiting = false
		elif not gate.is_empty():
			_input.move_axis = 0.0
			waiting = true
			if gate["pulse"]:
				_try_pulse(gate["what"], announced)
		elif target != null:
			_input.move_axis = 0.0
			waiting = true
			_try_laser(target, announced)
		elif _isak.is_on_floor() and _jump_left == 0 and (_isak.is_on_wall() or not _ground_ahead()):
			_jump_left = JUMP_HOLD_FRAMES
			_input.jump_pressed = true
		_input.jump_held = _jump_left > 0
		_jump_left = maxi(_jump_left - 1, 0)
		if terminal.get_state() >= ExitTerminal.State.BOOT and not announced.has("terminal"):
			announced["terminal"] = true
			_note("activa la terminal con el pulso (recorrido: %.1f s de juego sin contar la muerte forzada)" % (
					(_frame - _death_frames) / 60.0))
			_note("laser: %d disparos, %d Burbujas eliminadas (%s); energia al final %.0f" % [_shots, _kills.size(),
					", ".join(_kills), GameState.debug_energy])
			_shot_in("7_terminal", 30)
		if _isak.is_facing_back() and not announced.has("espaldas"):
			announced["espaldas"] = true
			if terminal.get_vortex() != null:
				return _fail("el vortice de salida se abrio antes de que Isak se pusiera de espaldas")
			_note("Isak de espaldas ante la terminal (x=%.0f; terminal en x=%.0f)" % [x, terminal.global_position.x])
			_shot_in("7b_espaldas", 1)
		if checkpoint.is_taken() and not announced.has("checkpoint"):
			announced["checkpoint"] = true
			_shot_in("2_checkpoint", 20)
			_note("punto de sincronizacion tocado (x=%.0f)" % x)
		if _die and checkpoint.is_taken() and not _died_done and x > checkpoint.global_position.x + 3.0 * TILE:
			_died_done = true
			var before: int = _frame
			if not await _force_death(checkpoint):
				return false
			_death_frames += _frame - before
			best_frame = _frame
			continue
		if waiting:
			best_frame = _frame
		elif _frame - best_frame > STUCK_FRAMES:
			return _fail("atascado en x=%.0f (columna %d), y=%.0f (suelo %s, pared %s, estado %s)" % [x, int(x / TILE),
					_isak.global_position.y, _isak.is_on_floor(), _isak.is_on_wall(), _isak.get_state_name()])
		await _tick()
		_input.clear_just_pressed()
	return _fail("tiempo agotado en x=%.0f" % _isak.global_position.x)


## La terminal de salida esta delante, sin activar, e Isak ya esta cerca (prompt)
## o la ha alcanzado.
func _terminal_waiting(terminal: ExitTerminal) -> bool:
	if terminal == null or terminal.get_state() >= ExitTerminal.State.BOOT:
		return false
	return terminal.is_player_near() and _isak.is_on_floor()


## Puerta de la ruta que obliga a pararse delante: {what, pulse} o vacio.
func _gate_ahead(x: float, feet: float, receivers: Array[PulseReceiver], bridges: Dictionary,
		popups: Array[PopupBlocker], bubbles: Array[AlertBubble]) -> Dictionary:
	if not _isak.is_on_floor():
		return {}
	for receiver: PulseReceiver in receivers:
		var bridge: PulseBridge = bridges.get(receiver.target_id)
		var rx: float = receiver.global_position.x
		if bridge == null or bridge.is_extended() or absf(receiver.global_position.y + TILE - feet) > ROUTE_TOLERANCE:
			continue
		if x >= rx - RECEIVER_STOP_TILES * TILE and x < rx + TILE:
			return {"what": "receptor", "pulse": not receiver.is_active()}
	for bubble: AlertBubble in bubbles:
		if is_instance_valid(bubble) and bubble.is_dangerous() and _bubble_close(bubble):
			return {"what": "burbuja", "pulse": true}
	for popup: PopupBlocker in popups:
		var px: float = popup.global_position.x
		var bottom: float = popup.global_position.y + popup.height_tiles * TILE
		if popup.is_closed() or absf(bottom - feet) > ROUTE_TOLERANCE:
			continue
		if x >= px - POPUP_STOP_GAP and x < px:
			return {"what": "pop-up", "pulse": popup.is_open()}
	return {}


func _try_pulse(what: String, announced: Dictionary) -> void:
	if not _isak.is_on_floor() or _isak.get_state_name() == PlayerState.PULSE:
		return
	if _isak.get_state_name() != PlayerState.IDLE and absf(_isak.velocity.x) > 1.0:
		return
	_input.pulse_pressed = true
	var key: String = "pulse_" + what
	announced[key] = int(announced.get(key, 0)) + 1
	if int(announced[key]) == 1:
		_note("pulso: %s (x=%.0f)" % [what, _isak.global_position.x])
		_shot_in("pulso_" + what.replace("-", ""), 12)


## Burbuja viva delante, a la altura de los pies y al alcance del laser, si Isak lo
## tiene, esta de pie y le queda energia para un disparo; si no, null.
func _laser_target(x: float, feet: float, bubbles: Array[AlertBubble]) -> AlertBubble:
	if not _isak.can_start_laser():
		return null
	if GameState.debug_energy < _isak.abilities.laser_energy_cost:
		return null
	var phone_x: float = x + _isak.get_pulse_origin().x
	for bubble: AlertBubble in bubbles:
		if not is_instance_valid(bubble) or bubble.get_state() == AlertBubble.STATE_POPPED:
			continue
		if absf(bubble.global_position.y - feet) > ROUTE_TOLERANCE:
			continue
		var body: Rect2 = bubble.get_body_rect()
		if body.end.x > x and body.position.x - phone_x < BUBBLE_LASER_GAP:
			return bubble
	return null


## Dispara el laser (hacia la derecha, donde mira el bot) si no se esta enfriando.
func _try_laser(bubble: AlertBubble, announced: Dictionary) -> void:
	if _isak.get_laser_cooldown_left() > 0.0 or _isak.is_laser_charging():
		return
	_input.laser_pressed = true
	if not announced.has("laser"):
		announced["laser"] = true
		_note("primer disparo del laser a %s (x=%.0f)" % [bubble.name, _isak.global_position.x])
		_shot_in("laser_disparo", 4)


func _bubble_close(bubble: AlertBubble) -> bool:
	var body: Rect2 = bubble.get_body_rect()
	var phone_x: float = _isak.global_position.x + _isak.get_pulse_origin().x
	return body.position.x - phone_x < BUBBLE_PULSE_GAP and body.end.x > _isak.global_position.x


## Suelo delante de los pies (rayo hacia abajo a 40 px por delante). Llega a
## GROUND_PROBE_PX: un escalon de bajada de 1 tile cuenta como suelo (baja andando
## y no salta por encima de un receptor), un foso de 2 tiles no (lo salta).
func _ground_ahead() -> bool:
	var feet: Vector2 = _isak.global_position
	var from := Vector2(feet.x + 40.0, feet.y - 8.0)
	var query := PhysicsRayQueryParameters2D.create(from, from + Vector2(0.0, GROUND_PROBE_PX), LAYER_WORLD)
	return not _isak.get_world_2d().direct_space_state.intersect_ray(query).is_empty()


func _force_death(checkpoint: Checkpoint) -> bool:
	_note("muerte forzada (Sync Rate 0) en x=%.0f" % _isak.global_position.x)
	_input.move_axis = 0.0
	GameState.sync_rate = GameState.SYNC_RATE_MIN
	if not _isak.is_dead():
		return _fail("Isak no muere con Sync Rate 0")
	_shot_in("3_muerte", 40)
	_shot_in("4_fundido", roundi(_runner.get_death_wait_s() * 60.0) + 14)
	var limit: int = _frame + 60 * 6
	while _frame < limit and not (_runner.get_phase() == LevelRunner.Phase.PLAYING and not _isak.is_dead()):
		await _tick()
	if _isak.is_dead():
		return _fail("no reaparece tras morir")
	var dist: float = _isak.global_position.distance_to(checkpoint.get_spawn_position())
	if dist > TILE or GameState.sync_rate != GameState.SYNC_RATE_MAX or DebugMode.is_active():
		return _fail("reaparicion incorrecta: a %.0f px del checkpoint, Sync %.0f" % [dist, GameState.sync_rate])
	_note("reaparece en el checkpoint con Sync Rate 100 %")
	_shot_in("5_reaparicion", 6)
	return true


## Hub real (paso 9 de docs/propuesta-hub-y-guardado.md): espera a que Isak
## llegue por el vortice; comprueba nivel completado, 1-2 desbloqueado, energia
## llena y que nada se ha escrito (guardado manual); camina a la copia local y
## guarda con el pulso (Guardar y «Si, guardar»); sube de un salto a la repisa
## de la carpeta del Mundo 1, la abre con el pulso y elige el 1-1: Isak se va
## por el vortice de salida y el LevelRunner carga el 1-1 desde cero.
func _hub_and_back() -> bool:
	var hub: HubRoom = _runner.get_hub()
	var limit: int = _frame + 60 * 6
	while _frame < limit and not hub.has_arrived():
		await _tick()
	if not hub.has_arrived():
		return _fail("Isak no llega al hub por el vortice")
	_isak = hub.get_isak()
	_isak.input = _input
	var points: int = GameState.attention_points
	_note("hub real: Isak llega en x=%.0f; puntos %d; 1-1 completado %s; 1-2 desbloqueado %s; energia %.0f/%.0f; golpes %d" % [
		_isak.global_position.x, points, GameState.is_level_completed(&"1-1"), GameState.is_level_unlocked(&"1-2"),
		GameState.debug_energy, GameState.get_debug_energy_max(), _hits])
	_shot_in("8_hub", 10)
	if not GameState.is_level_completed(&"1-1") or not GameState.is_level_unlocked(&"1-2"):
		return _fail("no se registro el nivel completado o el desbloqueo")
	if not is_equal_approx(GameState.debug_energy, GameState.get_debug_energy_max()):
		return _fail("la energia no se lleno al llegar al hub")
	if not GameState.has_unsaved_changes() or FileAccess.file_exists(GameState.save_path):
		return _fail("guardado manual: al llegar al hub deberia haber cambios sin guardar y nada escrito")
	if not hub.get_hud().is_unsaved_indicator_shown():
		return _fail("el HUD del hub no muestra «Sin guardar»")
	if not await _save_at_copy_local(hub):
		return false
	if not await _enter_from_folder(hub):
		return false
	_isak = _runner.get_isak()
	_isak.input = _input
	await get_tree().physics_frame
	var bridge: PulseBridge = _runner.get_level().get_node(^"Objects/puente_1")
	var popup: PopupBlocker = _runner.get_level().get_node(^"Objects/popup_1")
	if GameState.attention_points != points or GameState.sync_rate != GameState.SYNC_RATE_MAX \
			or bridge.is_extended() or not popup.is_open():
		return _fail("el 1-1 no empieza desde cero (o pierde los puntos)")
	var left: int = 0
	for node: Node in _runner.get_level().get_node(^"AttentionPoints").get_children():
		if node is AttentionPoint and not node.is_queued_for_deletion():
			left += 1
	var captured: int = GameState.get_captured_points(&"1-1").size()
	if captured != points or left + captured != _points_total:
		return _fail("puntos capturados: %d guardados, %d quedan en el mapa" % [captured, left])
	_note("1-1 de nuevo desde la carpeta: Sync 100 %%, %d puntos conservados, %d capturados no reaparecen, puente retraido, pop-up abierto" % [points, captured])
	if not _shots_dir.is_empty():
		_shot_in("9_reinicio", 40)
		for i: int in 45:
			await _tick()
	return true


## Camina hasta la copia local, la abre con el pulso y guarda (Guardar y
## confirmacion); cierra el panel con salto.
func _save_at_copy_local(hub: HubRoom) -> bool:
	var station := hub.get_station(&"copia_local") as CopyLocalStation
	if not await _walk_to_x(station.position.x + COPY_LOCAL_STAND_PX):
		return _fail("no llega a la copia local")
	_isak.facing = -1.0
	if not await _pulse_until(func() -> bool: return station.is_panel_open()):
		return _fail("el pulso no abre la copia local")
	_note("copia local abierta (x=%.0f): '%s'" % [_isak.global_position.x, " / ".join(station.get_panel().get_lines())])
	_shot_in("8b_copia_local", 1)
	await _wait_frames(15)
	await _press_action(&"pulse")  # Guardar
	if (station.get_panel() as CopyLocalPanel).get_mode() != CopyLocalPanel.Mode.CONFIRM:
		return _fail("Guardar no pide confirmacion")
	await _press_action(&"pulse")  # Si, guardar
	if GameState.has_unsaved_changes() or not FileAccess.file_exists(GameState.save_path):
		return _fail("la copia local no guardo")
	_note("guardado manual en la copia local: '%s' (%s); HUD «Sin guardar» %s" % [
		station.get_panel().get_message(), GameState.save_path,
		"visible" if hub.get_hud().is_unsaved_indicator_shown() else "apagado"])
	_shot_in("8c_guardado", 1)
	await _wait_frames(5)
	await _press_action(&"jump")
	await _wait_frames(6)
	if station.is_panel_open() or _isak.is_facing_back():
		return _fail("salto no cierra la copia local")
	return true


## Sube de un salto a la repisa de la carpeta del Mundo 1, la abre con el pulso
## y elige el 1-1 (primera opcion); espera a que el LevelRunner cargue el nivel.
func _enter_from_folder(hub: HubRoom) -> bool:
	var folder: FolderStation = hub.get_folder(&"m1")
	var under: float = folder.position.x + folder.get_size().x * 0.5
	if not await _walk_to_x(under):
		return _fail("no llega bajo la carpeta del Mundo 1")
	await _wait_frames(4)
	_input.jump_pressed = true
	_input.jump_held = true
	for i: int in 50:
		await _tick()
		_input.clear_just_pressed()
		_input.jump_held = i < JUMP_HOLD_FRAMES
	_input.jump_held = false
	if not _isak.is_on_floor() or absf(_isak.global_position.y - hub.get_shelf_top_y()) > 2.0:
		return _fail("no sube a la repisa de la carpeta (y=%.0f, repisa %.0f)" % [_isak.global_position.y, hub.get_shelf_top_y()])
	_note("de pie en la repisa de M1 (y=%.0f); tecla del pulso %s" % [_isak.global_position.y,
		"visible" if folder.is_key_hint_visible() else "NO visible"])
	if not await _pulse_until(func() -> bool: return folder.is_panel_open()):
		return _fail("el pulso no abre la carpeta del Mundo 1")
	var panel: FolderPanel = folder.get_folder_panel()
	_note("carpeta abierta: %s / %s" % [panel.get_title(), " / ".join(panel.get_lines())])
	_shot_in("8d_carpeta", 1)
	await _wait_frames(15)
	if panel.get_selected_option() != &"1-1":
		return _fail("la primera opcion de la carpeta no es el 1-1")
	await _press_action(&"pulse")
	# Con cambios sin guardar la carpeta pide confirmacion: entrar sin guardar.
	if panel.is_confirming_unsaved():
		_note("carpeta: «%s» -> Entrar sin guardar" % panel.get_title())
		await _wait_frames(15)
		await _press_action(&"pulse")
	if hub.get_entering_level() != &"1-1":
		return _fail("elegir el 1-1 no lleva al vortice de salida")
	_note("elige el 1-1: vortice de salida")
	var limit: int = _frame + 60 * 8
	while _frame < limit and (_runner.is_in_hub() or _runner.get_level() == null \
			or _runner.get_phase() != LevelRunner.Phase.PLAYING):
		await _tick()
	if _runner.is_in_hub() or _runner.get_level() == null or _runner.get_level_id() != "1-1":
		return _fail("la carpeta no carga el 1-1")
	return true


## Camina (entrada falsa) hasta que el centro de Isak queda a menos de 6 px de
## `x`. Falso si no llega en 6 s.
func _walk_to_x(x: float) -> bool:
	var limit: int = _frame + 60 * 6
	while _frame < limit:
		var dx: float = x - _isak.global_position.x
		if absf(dx) < 6.0:
			break
		_input.move_axis = signf(dx) * (1.0 if absf(dx) > 24.0 else 0.4)
		await _tick()
		_input.clear_just_pressed()
	_input.move_axis = 0.0
	for i: int in 10:
		await _tick()
	return absf(x - _isak.global_position.x) < 12.0


## Lanza el pulso (entrada falsa) hasta que `done` sea verdadero (2 s como mucho).
func _pulse_until(done: Callable) -> bool:
	for attempt: int in 4:
		_input.pulse_pressed = true
		for i: int in 30:
			await _tick()
			_input.clear_just_pressed()
			if done.call():
				return true
	return false


## Pulsa y suelta la accion `action` del Input Map (paneles del hub).
func _press_action(action: StringName) -> void:
	for pressed: bool in [true, false]:
		var event := InputEventAction.new()
		event.action = action
		event.pressed = pressed
		Input.parse_input_event(event)
		await _tick()


func _wait_frames(count: int) -> void:
	for i: int in count:
		await _tick()
