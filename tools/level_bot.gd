## Bot de recorrido del 1-1 (paso 16; generico desde el 1-1 ampliado): carga la escena principal (scenes/main.tscn,
## LevelRunner) y juega el nivel con una entrada falsa (PlayerInput), con la fisica
## y los objetos reales:
##   camina a la derecha; salta si choca con una pared o si delante no hay suelo
##   (rayo hacia abajo: cuenta el puente y la Burbuja aturdida); se para y lanza
##   el pulso en el receptor (espera al puente), ante la Burbuja (espera a que este
##   aturdida y la cruza) y ante el pop-up (espera a que se cierre); toca el punto
##   de sincronizacion y, con --die (por defecto), fuerza una muerte (Sync Rate 0)
##   tras tocarlo y comprueba que reaparece alli con el 100 %; entra por la puerta,
##   comprueba la pantalla provisional del hub (nivel completado, 1-2 desbloqueado,
##   puntos) y pulsa salto (accion jump) para reiniciar: Sync Rate y objetos
##   desde cero, pero los puntos de atencion se conservan y los ya capturados no
##   reaparecen (decision 2026-10-14).
## Usa su propio guardado (BOT_SAVE_PATH, borrado al empezar; o ISAK_SAVE_PATH
## si esta definida): nunca toca el user://save.json del jugador.
## Termina con codigo 0 si todo sale bien y 1 si algo falla (con el motivo).
## Lo lanza tools/play_level_bot.gd (los scripts -s no pueden nombrar autoloads
## ni clases que los usen al compilar, asi que la logica va aqui).
## Uso (rapido, sin ventana):
##   Godot --headless --fixed-fps 60 --path . -s tools/play_level_bot.gd [-- --no-die] [--run]
## --run recorre el nivel corriendo. Al entrar por la puerta anota la duracion del
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
const LAYER_WORLD: int = 1
const BOT_SAVE_PATH: String = "user://bot_save.json"

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


## Fin del recorrido: 0 si todo ha ido bien, 1 si algo ha fallado.
signal finished(code: int)

## Capturas (--shots <carpeta>, necesita ventana): nombre -> cuadro en que se toma.
var _shots_dir: String = ""
var _shots: Dictionary = {}


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
		ok = await _hub_and_restart()
	print("play_level_bot: %s" % ("OK" if ok else "FALLO"))
	for line: String in _log:
		print("  " + line)
	finished.emit(0 if ok else 1)


func _attach() -> void:
	_isak = _runner.get_isak()
	_isak.input = _input
	_isak.hurt.connect(func() -> void: _hits += 1)


## Un cuadro de fisica; toma las capturas pendientes que tocan.
func _tick() -> void:
	await get_tree().physics_frame
	_frame += 1
	for name: String in _shots.keys():
		if _frame >= int(_shots[name]):
			_shots.erase(name)
			await RenderingServer.frame_post_draw
			var path: String = _shots_dir.path_join(name + ".png")
			get_viewport().get_texture().get_image().save_png(path)
			_note("captura " + path)


func _shot_in(name: String, frames: int) -> void:
	if not _shots_dir.is_empty():
		_shots[name] = _frame + frames


func _note(text: String) -> void:
	_log.append("[%5.1f s] %s" % [_frame / 60.0, text])


func _fail(text: String) -> bool:
	_note("FALLO: " + text)
	return false


## Juega hasta que se muestra el hub. Falso si se atasca o se agota el tiempo.
## Generico (1-1 ampliado): recorre todos los receptores, puentes, pop-ups y
## Burbujas del nivel. Solo atiende a los de la ruta (a la altura de los pies de
## Isak): el receptor y los pop-ups de los secretos (popup_alto y popup_lejano, el
## del Pulso amplio) quedan en lo alto y se ignoran. Solo recoge los puntos de la
## ruta (20 en el 1-1 desde la economia del 2026-10-15).
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
	var checkpoint: Checkpoint = level.get_node(^"Checkpoints").get_child(0) as Checkpoint
	var door: ExitDoor = level.get_node(^"Objects/puerta_salida")
	_points_total = level.get_node(^"AttentionPoints").get_child_count()
	var best_x: float = 0.0
	var best_frame: int = 0
	var announced: Dictionary = {}
	while _frame < MAX_FRAMES:
		if _runner.is_in_hub():
			_note("hub provisional mostrado")
			_shot_in("8_hub", 40)
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
		if _runner.get_phase() != LevelRunner.Phase.PLAYING or _isak.is_dead():
			_input.move_axis = 0.0
			waiting = true
		elif not gate.is_empty():
			_input.move_axis = 0.0
			waiting = true
			if gate["pulse"]:
				_try_pulse(gate["what"], announced)
		elif _isak.is_on_floor() and _jump_left == 0 and (_isak.is_on_wall() or not _ground_ahead()):
			_jump_left = JUMP_HOLD_FRAMES
			_input.jump_pressed = true
		_input.jump_held = _jump_left > 0
		_jump_left = maxi(_jump_left - 1, 0)
		if door.get_state() == ExitDoor.State.OPENING and not announced.has("door"):
			announced["door"] = true
			_note("entra por la puerta (recorrido: %.1f s de juego sin contar la muerte forzada)" % (
					(_frame - _death_frames) / 60.0))
			_shot_in("7_puerta", 6)
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


func _hub_and_restart() -> bool:
	var hub: HubPlaceholder = _runner.get_hub()
	var points: int = GameState.attention_points
	_note("hub: '%s' / '%s'; puntos %d; 1-1 completado %s; 1-2 desbloqueado %s; golpes %d" % [
		hub.get_line_text(&"completed"), hub.get_line_text(&"points"), points,
		GameState.is_level_completed(&"1-1"), GameState.is_level_unlocked(&"1-2"), _hits])
	if not GameState.is_level_completed(&"1-1") or not GameState.is_level_unlocked(&"1-2"):
		return _fail("no se registro el nivel completado o el desbloqueo")
	for i: int in 60:
		await _tick()
	var press := InputEventAction.new()
	press.action = &"jump"
	press.pressed = true
	Input.parse_input_event(press)
	var limit: int = 60 * 3
	while limit > 0 and _runner.is_in_hub():
		await get_tree().process_frame
		limit -= 1
	var release := InputEventAction.new()
	release.action = &"jump"
	release.pressed = false
	Input.parse_input_event(release)
	if _runner.is_in_hub() or _runner.get_level() == null:
		return _fail("pulsar salto en el hub no reinicia el nivel")
	await get_tree().physics_frame
	var bridge: PulseBridge = _runner.get_level().get_node(^"Objects/puente_1")
	var popup: PopupBlocker = _runner.get_level().get_node(^"Objects/popup_1")
	if GameState.attention_points != points or GameState.sync_rate != GameState.SYNC_RATE_MAX \
			or bridge.is_extended() or not popup.is_open():
		return _fail("el reinicio no empieza desde cero (o pierde los puntos)")
	var left: int = 0
	for node: Node in _runner.get_level().get_node(^"AttentionPoints").get_children():
		if node is AttentionPoint and not node.is_queued_for_deletion():
			left += 1
	var captured: int = GameState.get_captured_points(&"1-1").size()
	if captured != points or left + captured != _points_total:
		return _fail("puntos capturados: %d guardados, %d quedan en el mapa" % [captured, left])
	_note("reinicio: Sync 100 %%, %d puntos conservados, %d capturados no reaparecen, puente retraido, pop-up abierto" % [points, captured])
	if not _shots_dir.is_empty():
		_shot_in("9_reinicio", 40)
		for i: int in 45:
			await _tick()
	return true
