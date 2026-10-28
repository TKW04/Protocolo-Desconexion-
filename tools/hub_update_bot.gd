## Bot del hub «Actualización del sistema» (paso 8 de docs/propuesta-hub-mundos-4-6.md
## §2.7 y §5.2, 2026-10-27). Parte de un GUARDADO de quien acaba de vencer a La
## Curadora (Eco, Notas y Calc conocidos, las seis habilidades, 3-boss completado
## y boss_w3_l1: se escribe en user://bot_save.json y se vuelve a cargar del
## disco), carga la escena principal (scenes/main.tscn, LevelRunner) en el hub y
## juega con el Isak real pulsando SOLO acciones del Input Map (move_left /
## move_right, move_down —golpe al suelo—, jump, run, pulse, laser, debug,
## gesture_swipe, gesture_pinch y ui_accept para cerrar las lineas importantes);
## nunca Q ni pause, nunca teletransporta y no toca GameState durante el juego
## (salvo el perfil nosave, ver abajo). Es un guion por pasos (no reactivo): el
## hub no tiene amenazas.
##
## Llegada: como la deja la pelea con la Curadora (arrived_from_level = 3-boss,
## lo unico que se fija antes de que termine la llegada), asi que Calc dice su
## comentario (no importante) y el bot lo cierra con ui_accept.
##
## Perfil ideal (por defecto): cruza a la pagina 2 (cierra la linea de Eco, que
## pausa), V1 (Debug -> laser a lector1 desde el suelo -> soltar el Debug ->
## salto a la repisa -> pulso a RE dentro de los 6 s), V3 (laser al espejo ->
## Pellizcar -> nicho -> tamano normal -> pulso -> Pellizcar para salir), V2
## (golpe al suelo en la placa -> salto a la plataforma «Cargando...» -> salto
## corriendo + dash aereo al bloque -> pulso), pulso al instalador, ve la
## instalacion (barra, destello y linea de Notas), vuelve a la pagina 1, guarda
## en Notas, y abre M4 en la pagina 2 (con el 4-1 desde el paso 11 del Mundo 4); M5 (pagina 2) y M6
## (pagina 3) bloqueadas con «Sin descargar» y la segunda linea. Mide el tiempo
## del acertijo (desde que se suelta la linea de Eco en la pagina 2 hasta pedir la
## instalacion; objetivo 60-90 s) y el total.
## Perfil idle (quieto): cruza a la pagina 2 y se queda quieto 100 s: ninguna
## verificacion, sin instalar, sale la pista de Eco de los 90 s.
## Perfil nosave: resuelve e instala como el ideal pero NO guarda; entra al 1-1
## desde la carpeta del Mundo 1 («Entrar sin guardar») y alli muere tres veces
## (Sync Rate a 0, como la comprobacion del game over de tools/level_bot.gd: es
## lo unico que toca GameState, y fuera del hub): game over -> rollback a la
## copia; en el hub el upgrade se ha perdido, la pagina 2 vuelve a estar «en
## instalacion», el acertijo esta inerte con la Papelera llena; el bot recupera
## la Papelera y comprueba que el acertijo vuelve a 0/3 en la pagina 2.
## Perfil kept (--lap 2|3): guardado de Kernel / Raiz con el upgrade ya
## instalado (el rollback de fin de vuelta lo conserva): 3 paginas desde el
## principio, sin acertijo ni linea de Eco; cruza a la pagina 2 y a la 3.
##
## Lo lanza tools/play_hub_update_bot.gd; lo ejecuta tests/test_hub_update_bot.gd.
extends Node

signal finished(code: int)
## Un paso de fisica del bot (el guion espera a esta senal).
signal tick

const MAIN_SCENE: String = "res://scenes/main.tscn"
const BOT_SAVE_PATH: String = "user://bot_save.json"
const UPGRADE: StringName = &"hub_update_4_6"
const ACCESS_NAMES: Dictionary = {1: "Caché", 2: "Kernel", 3: "Raíz"}
const A_LEFT: StringName = &"move_left"
const A_RIGHT: StringName = &"move_right"
const A_DOWN: StringName = &"move_down"
const A_JUMP: StringName = &"jump"
const A_RUN: StringName = &"run"
const A_PULSE: StringName = &"pulse"
const A_LASER: StringName = &"laser"
const A_DEBUG: StringName = &"debug"
const A_DASH: StringName = &"gesture_swipe"
const A_PINCH: StringName = &"gesture_pinch"
const A_ACCEPT: StringName = &"ui_accept"
const HOLD_ACTIONS: Array[StringName] = [A_LEFT, A_RIGHT, A_DOWN, A_JUMP, A_RUN, A_DEBUG]
const T: float = 64.0
const LINE_READ_FRAMES: int = 10
const JUMP_HOLD_FRAMES: int = 22
const IDLE_S: float = 100.0
const TARGET_S: Vector2 = Vector2(60.0, 90.0)

var _profile: String = "ideal"
var _lap: int = 1
var _verbose: bool = false
var _trace: bool = false

var _runner: LevelRunner
var _hub: HubRoom
var _isak: Isak
var _frame: int = 0
var _paused_frames: int = 0
var _done: bool = false
var _log: PackedStringArray = []
var _ok: bool = true

# Entrada de este cuadro.
var _axis: float = 0.0
var _holds: Dictionary = {}
var _taps: Array[StringName] = []
var _held_taps: Array[StringName] = []
var _line_key: String = ""
var _line_frame: int = 0
var _lines_closed: PackedStringArray = []
var _first_hub: bool = true

# Medidas.
var _puzzle_start_frame: int = -1
var _puzzle_start_paused: int = 0
var _puzzle_s: float = -1.0
var _v2_attempts: int = 0
var _dashes: int = 0
var _lasers: int = 0
var _pulses: int = 0
var _pinches: int = 0
var _pounds: int = 0
var _min_energy: float = INF


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	process_physics_priority = -1000
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var at: int = args.find("--profile")
	if at >= 0 and at + 1 < args.size():
		_profile = args[at + 1]
	at = args.find("--lap")
	if at >= 0 and at + 1 < args.size():
		_lap = clampi(int(args[at + 1]), 1, 3)
	_verbose = args.has("--verbose") or args.has("--trace")
	_trace = args.has("--trace")
	if not _profile in ["ideal", "idle", "nosave", "kept"]:
		_note("perfil desconocido «%s» (ideal, idle, nosave, kept)" % _profile)
		_finish.call_deferred(false)
		return
	if _profile == "kept" and _lap == 1:
		_lap = 2
	elif _profile != "kept":
		_lap = 1
	var env_path: String = OS.get_environment(GameState.SAVE_PATH_ENV)
	var path: String = BOT_SAVE_PATH if env_path.is_empty() else env_path
	GameState.use_save_path(path, true)
	GameSettings.use_path("user://tool_settings.cfg")
	_setup_save()
	if not GameState.save_game():
		_note("FALLO: no se pudo escribir el guardado de partida")
		_finish.call_deferred(false)
		return
	# Se arranca desde el guardado del disco (como al abrir el juego).
	GameState.reset_progress()
	GameState.use_save_path(path, false)
	if not GameState.started_from_save or not GameState.is_level_completed(&"3-boss"):
		_note("FALLO: el guardado no se carga")
		_finish.call_deferred(false)
		return
	EventBus.dash_started.connect(func(_d: float) -> void: _dashes += 1)
	EventBus.laser_fired.connect(func(_p: Node2D) -> void: _lasers += 1)
	EventBus.pulse_fired.connect(func(_a: Area2D) -> void: _pulses += 1)
	EventBus.ground_pound_landed.connect(func(_r: Rect2, _s: Node2D) -> void: _pounds += 1)
	EventBus.compress_changed.connect(func(on: bool) -> void:
		if on:
			_pinches += 1)
	_runner = (load(MAIN_SCENE) as PackedScene).instantiate() as LevelRunner
	_runner.start_level_id = "hub"
	_runner.hub_shown.connect(_on_hub_shown)
	add_child(_runner)
	_note("perfil %s, acceso %s (vuelta %d); guardado %s" % [_profile, ACCESS_NAMES[_lap], _lap, path])
	_script.call_deferred()


## Guardado de quien acaba de vencer a La Curadora (y lo ha guardado en Notas).
func _setup_save() -> void:
	GameState.lap = _lap
	for ally: StringName in [GameState.ALLY_ECO, GameState.ALLY_NOTAS, GameState.ALLY_CALC]:
		GameState.meet_ally(ally)
	for ability: StringName in [GameState.ABILITY_PULSE, GameState.ABILITY_LASER, GameState.ABILITY_DEBUG,
			GameState.ABILITY_DASH, GameState.ABILITY_GROUND_POUND, GameState.ABILITY_COMPRESS]:
		GameState.obtain_ability(ability)
		GameState.seen_notices[ability] = true
	for id: StringName in [&"1-1", &"1-2", &"1-3", &"1-boss", &"2-1", &"2-2", &"2-3", &"2-boss",
			&"3-1", &"3-2", &"3-3", &"3-boss"]:
		GameState.unlock_level(id)
		GameState.mark_level_completed(id)
	for memory: StringName in [&"boss_w1_l1", &"boss_w2_l1", &"boss_w3_l1"]:
		GameState.obtain_memory(memory)
	if _profile == "kept":
		GameState.install_hub_upgrade(UPGRADE)


## Primera llegada: como la deja la pelea (vuelta de 3-boss), antes de que
## termine la llegada (el comentario de Calc sale al terminar).
func _on_hub_shown(_level_id: String, _points: int) -> void:
	if _first_hub and _profile != "kept":
		_runner.get_hub().arrived_from_level = "3-boss"
	_first_hub = false


# --- Bucle ---

func _physics_process(_delta: float) -> void:
	if _done:
		return
	for action: StringName in _held_taps:
		Input.action_release(action)
	_held_taps.clear()
	_frame += 1
	if get_tree().paused:
		_paused_frames += 1
	_refresh()
	_service_lines()
	tick.emit()
	_apply_inputs()
	if _isak != null and is_instance_valid(_isak):
		_min_energy = minf(_min_energy, GameState.debug_energy)
		if _trace and _frame % 15 == 0:
			print("[trace %.2f] x %.0f y %.0f vy %.0f suelo %s energia %.0f debug %s pausa %s comp %s" % [
				float(_frame) / 60.0, _isak.global_position.x, _isak.global_position.y, _isak.velocity.y,
				_isak.is_on_floor(), GameState.debug_energy, DebugMode.is_active(), get_tree().paused,
				_isak.is_compressed()])


func _refresh() -> void:
	if _runner == null or not is_instance_valid(_runner):
		return
	_hub = _runner.get_hub() if _runner.is_in_hub() else null
	_isak = _hub.get_isak() if _hub != null and is_instance_valid(_hub) else _runner.get_isak()


## Cierra las lineas importantes (y el comentario de Calc) tras leerlas unos cuadros.
func _service_lines() -> void:
	var box: EcoTextBox = null
	if _hub != null and is_instance_valid(_hub):
		box = _hub.get_text_box()
	elif _runner != null and _runner.get_level() != null:
		box = _runner.get_level().get_node_or_null(^"EcoTextBox") as EcoTextBox
	if box == null or not box.is_showing() or not (box.is_important() or box.get_speaker_id() == &"calc"):
		_line_key = ""
		return
	var key: String = box.get_speaker_text() + "|" + box.get_text()
	if key != _line_key:
		_line_key = key
		_line_frame = _frame
		_lines_closed.append("%s: «%s»" % [box.get_speaker_text(), box.get_text()])
		if _verbose:
			_note("linea (%s, %s): «%s» -> aceptar" % [box.get_speaker_text(),
				"importante" if box.is_important() else "no importante", box.get_text()])
		return
	if (_frame - _line_frame) % LINE_READ_FRAMES == LINE_READ_FRAMES - 1:
		_press_event(A_ACCEPT)


func _apply_inputs() -> void:
	if _axis > 0.001:
		Input.action_release(A_LEFT)
		Input.action_press(A_RIGHT, minf(_axis, 1.0))
	elif _axis < -0.001:
		Input.action_release(A_RIGHT)
		Input.action_press(A_LEFT, minf(-_axis, 1.0))
	else:
		Input.action_release(A_LEFT)
		Input.action_release(A_RIGHT)
	for action: StringName in [A_DOWN, A_JUMP, A_RUN, A_DEBUG]:
		if bool(_holds.get(action, false)):
			Input.action_press(action)
		else:
			Input.action_release(action)
	for action: StringName in _taps:
		Input.action_press(action)
		_held_taps.append(action)
	_taps.clear()


func _press_event(action: StringName, keep: bool = false) -> void:
	var event := InputEventAction.new()
	event.action = action
	event.pressed = true
	Input.parse_input_event(event)
	if not keep:
		var up := InputEventAction.new()
		up.action = action
		up.pressed = false
		Input.parse_input_event(up)


func _release_all() -> void:
	_axis = 0.0
	_holds.clear()
	for action: StringName in HOLD_ACTIONS:
		Input.action_release(action)
	for action: StringName in [A_PULSE, A_LASER, A_DASH, A_PINCH]:
		Input.action_release(action)


# --- Primitivas del guion ---

func _wait(n: int) -> void:
	for i: int in n:
		await tick


## Espera a `cond` (cuadros sin pausa como mucho `max_s`). Verdadero si se cumple.
func _wait_until(cond: Callable, max_s: float = 10.0) -> bool:
	var left: int = int(max_s * 60.0)
	while left > 0:
		if cond.call():
			return true
		await tick
		if not get_tree().paused:
			left -= 1
	return bool(cond.call())


func _tap(action: StringName) -> void:
	if not _taps.has(action):
		_taps.append(action)
	await tick
	await tick


func _x() -> float:
	return _isak.global_position.x


## Camina hasta que el centro de Isak queda a menos de `tol` px de `x`.
func _walk_to(x: float, tol: float = 6.0, run: bool = false, max_s: float = 12.0) -> bool:
	var left: int = int(max_s * 60.0)
	while left > 0:
		var dx: float = x - _x()
		if absf(dx) < tol:
			break
		_axis = signf(dx) * (1.0 if absf(dx) > 40.0 else 0.4)
		_holds[A_RUN] = run and absf(dx) > 80.0
		await tick
		if not get_tree().paused:
			left -= 1
	_axis = 0.0
	_holds[A_RUN] = false
	await _wait(8)
	return absf(x - _x()) < tol * 2.0


## Gira a Isak hacia `dir` con un toque corto del eje.
func _face(dir: float) -> void:
	for i: int in 20:
		if is_equal_approx(_isak.facing, dir):
			break
		_axis = dir * 0.2
		await tick
	_axis = 0.0
	await _wait(2)


func _on_floor() -> bool:
	return _isak.is_on_floor() and absf(_isak.velocity.y) < 1.0


## Salto: mantiene el salto JUMP_HOLD_FRAMES cuadros con el eje `axis` durante
## `axis_frames` y espera a tocar el suelo.
func _jump(axis: float = 0.0, axis_frames: int = 0, run: bool = false) -> bool:
	_holds[A_JUMP] = true
	_holds[A_RUN] = run
	for i: int in 90:
		_axis = axis if i < axis_frames else 0.0
		_holds[A_JUMP] = i < JUMP_HOLD_FRAMES
		await tick
		if i > 4 and _on_floor():
			break
	_axis = 0.0
	_holds[A_JUMP] = false
	_holds[A_RUN] = false
	await _wait(4)
	return _on_floor()


## El Debug se activa manteniendo la accion (carga) y queda puesto; otro toque lo apaga.
func _debug_on() -> bool:
	_holds[A_DEBUG] = true
	var ok: bool = await _wait_until(func() -> bool: return DebugMode.is_active(), 2.0)
	_holds[A_DEBUG] = false
	await tick
	return ok


func _debug_off() -> void:
	for i: int in 4:
		if not DebugMode.is_active():
			return
		await _tap(A_DEBUG)
		await _wait(10)


## Pellizcar es un interruptor: toques hasta quedar comprimido (o no).
func _pinch_to(small: bool) -> bool:
	for i: int in 5:
		if _isak.is_compressed() == small:
			return true
		await _tap(A_PINCH)
		await _wait_until(func() -> bool: return _isak.is_compressed() == small, 0.5)
	return _isak.is_compressed() == small


func _pulse_until(cond: Callable, tries: int = 3) -> bool:
	for i: int in tries:
		await _tap(A_PULSE)
		if await _wait_until(cond, 0.8):
			return true
	return bool(cond.call())


func _check(cond: bool, what: String) -> bool:
	if not cond:
		_ok = false
		_note("FALLO: " + what)
	return cond


func _note(text: String) -> void:
	_log.append(text)
	if _verbose:
		print("[hub_update_bot %.1f] %s" % [float(_frame) / 60.0, text])


func _finish(ok: bool) -> void:
	if _done:
		return
	_done = true
	_release_all()
	var label: String = "play_hub_update_bot (%s, %s)" % [ACCESS_NAMES.get(_lap, "?"), _profile]
	print("%s: %s" % [label, "OK" if ok and _ok else "FALLO"])
	for line: String in _log:
		print("  " + line)
	print("  LINEAS: " + (" / ".join(_lines_closed) if not _lines_closed.is_empty() else "ninguna"))
	print("  RESULTADO: acertijo %s (objetivo %.0f-%.0f s), total %.1f s de juego (%.1f s en pausa), intentos de V2 %d, energia minima %.0f" % [
		("%.1f s" % _puzzle_s) if _puzzle_s >= 0.0 else "sin resolver", TARGET_S.x, TARGET_S.y,
		float(_frame) / 60.0, float(_paused_frames) / 60.0, _v2_attempts,
		_min_energy if _min_energy != INF else -1.0])
	print("  ACCIONES: pulsos %d, laseres %d, dashes %d, golpes al suelo %d, pellizcos %d" % [
		_pulses, _lasers, _dashes, _pounds, _pinches])
	finished.emit(0 if ok and _ok else 1)


# --- Guion ---

func _script() -> void:
	var ok: bool = await _arrive()
	if ok:
		match _profile:
			"ideal":
				ok = await _run_ideal()
			"idle":
				ok = await _run_idle()
			"nosave":
				ok = await _run_nosave()
			"kept":
				ok = await _run_kept()
	_finish(ok)


func _arrive() -> bool:
	if not await _wait_until(func() -> bool: return _hub != null and is_instance_valid(_hub) and _hub.has_arrived(), 15.0):
		return _check(false, "Isak no llega al hub")
	await _wait(2)
	_note("hub: llegada en x %.0f (pagina %d de %d); acertijo pendiente %s; sin guardar %s" % [_x(),
		_hub.get_current_page(), _hub.get_page_count(), HubWorlds.is_hub_upgrade_pending(UPGRADE),
		GameState.has_unsaved_changes()])
	if _profile == "kept":
		return true
	if not _check(_hub.get_page_count() == 2 and _hub.get_page_state(2) == HubRoom.PAGE_INSTALLING,
			"con 3-boss la pagina 2 deberia estar «en instalacion»"):
		return false
	# El comentario de Calc (no importante) sale al terminar la llegada.
	await _wait_until(func() -> bool: return _lines_closed.size() > 0, 3.0)
	_check(GameState.is_notice_seen(&"calc_remark_update_3_boss"), "Calc no comenta la actualizacion")
	return true


## Cruza el borde derecho de la pagina actual hasta la siguiente.
func _cross_right() -> bool:
	var page: int = _hub.get_current_page()
	var edge: float = float(page) * _hub.get_page_width_px()
	var target: float = edge + 3.0 * T
	if not await _walk_to(target, 8.0, true, 20.0):
		return _check(false, "no cruza a la pagina %d" % (page + 1))
	await _wait_until(func() -> bool: return not _hub.is_page_sliding(), 3.0)
	return _check(_hub.get_current_page() == page + 1, "no llega a la pagina %d" % (page + 1))


func _cross_left() -> bool:
	var page: int = _hub.get_current_page()
	var edge: float = float(page - 1) * _hub.get_page_width_px()
	if not await _walk_to(edge - 3.0 * T, 8.0, true, 20.0):
		return _check(false, "no cruza a la pagina %d" % (page - 1))
	await _wait_until(func() -> bool: return not _hub.is_page_sliding(), 3.0)
	return _check(_hub.get_current_page() == page - 1, "no vuelve a la pagina %d" % (page - 1))


## X de la sala de la columna local `col` de la pagina 2 (centro de Isak).
func _p2(col: float) -> float:
	return _hub.get_page_width_px() + col * T


func _go_to_page_two() -> bool:
	if not await _cross_right():
		return false
	# La linea de Eco al llegar (importante: pausa) la cierra _service_lines.
	await _wait(3)
	await _wait_until(func() -> bool: return not get_tree().paused and not _hub.get_text_box().is_important(), 10.0)
	_check(GameState.is_notice_seen(&"hub_update_intro"), "Eco no habla al llegar a la pagina 2")
	return true


func _run_ideal() -> bool:
	if not await _go_to_page_two():
		return false
	if not await _solve_and_install():
		return false
	if not await _check_after_install():
		return false
	if not await _save_at_notas():
		return false
	return await _visit_new_folders()


func _solve_and_install() -> bool:
	var puzzle: HubUpdatePuzzle = _hub.get_update_puzzle()
	if not _check(puzzle != null and puzzle.get_done_count() == 0, "sin acertijo a 0/3 en la pagina 2"):
		return false
	_puzzle_start_frame = _frame
	_puzzle_start_paused = _paused_frames
	if not await _solve_v1(puzzle):
		return false
	if not await _solve_v3(puzzle):
		return false
	if not await _solve_v2(puzzle):
		return false
	return await _install(puzzle)


## V1: Debug -> laser a lector1 desde el suelo -> repisa -> pulso a RE (6 s).
func _solve_v1(puzzle: HubUpdatePuzzle) -> bool:
	var reader: LaserReceiver = puzzle.get_reader1()
	if not await _walk_to(_p2(3.5)):
		return _check(false, "V1: no llega bajo la repisa")
	await _face(-1.0)
	_check(not reader.is_targetable(), "V1: lector1 se ve sin el Debug")
	if not await _debug_on():
		return _check(false, "V1: el Debug no se activa en el hub")
	await _wait(2)
	await _tap(A_LASER)
	var powered: bool = await _wait_until(func() -> bool: return reader.is_powered(), 1.5)
	await _debug_off()
	if not _check(powered, "V1: el laser no da corriente a lector1"):
		return false
	_note("V1: Debug + laser a lector1 (corriente %.1f s)" % 6.0)
	await _wait(20)  # pose del laser (no se salta durante ella)
	if not _check(await _jump(), "V1: no sube a la repisa de RE") \
			or not _check(_isak.global_position.y < _hub.get_floor_y() - 100.0, "V1: el salto no llega a la repisa"):
		return false
	await _walk_to(_p2(5.4))
	if not await _pulse_until(func() -> bool: return puzzle.get_check(&"v1").is_completed()):
		return _check(false, "V1: el pulso a RE no enciende V1 (corriente %s)" % reader.is_powered())
	_note("V1 encendida a los %.1f s (%d/3)" % [_puzzle_elapsed(), puzzle.get_done_count()])
	return true


## V3: laser al espejo -> marco iluminado -> Pellizcar -> nicho -> pulso.
func _solve_v3(puzzle: HubUpdatePuzzle) -> bool:
	# Baja de la repisa por su borde derecho y va al suelo frente al espejo.
	if not await _walk_to(_p2(13.5), 6.0, true):
		return _check(false, "V3: no llega frente al espejo")
	await _wait_until(_on_floor, 2.0)
	await _face(1.0)
	await _tap(A_LASER)
	if not await _wait_until(func() -> bool: return puzzle.is_frame_lit(), 1.5):
		return _check(false, "V3: el laser no llega a lector3 por el espejo")
	await _wait(4)
	_note("V3: laser por el espejo, marco iluminado (hueco abierto %s)" % (not puzzle.is_frame_blocked()))
	await _tap(A_PINCH)
	if not await _wait_until(func() -> bool: return _isak.is_compressed(), 1.0):
		return _check(false, "V3: Pellizcar no comprime a Isak")
	if not await _walk_to(_p2(18.7), 10.0, false, 8.0):
		return _check(false, "V3: comprimido no entra al nicho (x %.0f)" % _x())
	await _tap(A_PINCH)
	if not await _wait_until(func() -> bool: return not _isak.is_compressed(), 2.0):
		return _check(false, "V3: no vuelve al tamano normal en el nicho")
	await _wait(6)
	if not await _pulse_until(func() -> bool: return puzzle.get_check(&"v3").is_completed()):
		return _check(false, "V3: el pulso no enciende V3")
	_note("V3 encendida a los %.1f s (%d/3)" % [_puzzle_elapsed(), puzzle.get_done_count()])
	await _wait(30)  # pose del pulso de espaldas
	if not await _pinch_to(true):
		return _check(false, "V3: no se comprime para salir del nicho")
	if not await _walk_to(_p2(15.8), 10.0, false, 8.0):
		return _check(false, "V3: no sale del nicho")
	await _tap(A_PINCH)
	if not await _wait_until(func() -> bool: return not _isak.is_compressed(), 2.0):
		return _check(false, "V3: fuera del nicho no recupera el tamano")
	return true


## V2: golpe al suelo en la placa -> plataforma -> salto corriendo + dash aereo.
func _solve_v2(puzzle: HubUpdatePuzzle) -> bool:
	var plate: PoundPlate = puzzle.get_plate()
	var block_top: float = 320.0
	for attempt: int in 4:
		_v2_attempts += 1
		if not await _walk_to(_p2(9.5), 5.0, true):
			return _check(false, "V2: no llega a la placa")
		await _wait_until(_on_floor, 2.0)
		await _wait_until(func() -> bool: return not plate.is_platform_up() and not plate.is_platform_solid(), 4.0)
		_holds[A_DOWN] = true
		var up: bool = await _wait_until(func() -> bool: return plate.is_platform_up(), 1.5)
		_holds[A_DOWN] = false
		if not _check(up, "V2: el golpe al suelo no sube la plataforma"):
			return false
		await _wait_until(func() -> bool: return _on_floor() and plate.is_platform_solid(), 1.0)
		await _wait(24)  # pose del golpe al suelo
		# A la plataforma (columnas 10-11, arriba en y 448).
		await _jump(1.0, 14)
		await _wait_until(func() -> bool: return plate.is_platform_up() and _isak.global_position.y <= 449.0, 0.5)
		if _isak.global_position.y > 470.0:
			_note("V2 intento %d: no cae en la plataforma (x %.0f, y %.0f)" % [attempt + 1, _x(), _isak.global_position.y])
			continue
		await _walk_to(_p2(10.3), 6.0, false, 1.0)
		# Salto corriendo desde el borde derecho de la plataforma + dash aereo.
		_holds[A_RUN] = true
		_axis = 1.0
		for i: int in 60:
			if _x() >= _hub.get_page_width_px() + 760.0:
				break
			await tick
		_holds[A_JUMP] = true
		var dashed: bool = false
		for i: int in 120:
			_holds[A_JUMP] = i < JUMP_HOLD_FRAMES
			if i == 20:
				_taps.append(A_DASH)
				dashed = true
			await tick
			if i > 4 and _on_floor():
				break
		_axis = 0.0
		_holds[A_RUN] = false
		_holds[A_JUMP] = false
		await _wait(6)
		if dashed and absf(_isak.global_position.y - block_top) < 3.0:
			break
		_note("V2 intento %d: no llega al bloque (x %.0f, y %.0f)" % [attempt + 1, _x(), _isak.global_position.y])
	if not _check(absf(_isak.global_position.y - block_top) < 3.0, "V2: no sube al bloque alto"):
		return false
	await _walk_to(_p2(18.2))
	if not await _pulse_until(func() -> bool: return puzzle.get_check(&"v2").is_completed()):
		return _check(false, "V2: el pulso no enciende V2")
	_note("V2 encendida a los %.1f s (%d/3, %d intentos)" % [_puzzle_elapsed(), puzzle.get_done_count(), _v2_attempts])
	# Baja del bloque con un salto hacia la izquierda (por encima de lector3).
	await _walk_to(_p2(17.4), 6.0)
	await _jump(-1.0, 40)
	return _check(_isak.global_position.y > _hub.get_floor_y() - 4.0, "V2: no baja del bloque (y %.0f)" % _isak.global_position.y)


func _install(puzzle: HubUpdatePuzzle) -> bool:
	if not _check(puzzle.is_complete(), "el acertijo no llega a 3/3"):
		return false
	var installer: HubInstaller = puzzle.get_installer()
	await _walk_to(installer.global_position.x + installer.get_size().x * 0.5, 6.0, true)
	if not await _pulse_until(func() -> bool: return _hub.is_update_install_requested()):
		return _check(false, "el pulso al instalador no pide la instalacion")
	_puzzle_s = _puzzle_elapsed()
	_note("instalador: instalacion pedida a los %.1f s del acertijo" % _puzzle_s)
	var install: HubUpdateInstall = null
	if await _wait_until(func() -> bool: return _hub.get_update_install() != null, 1.0):
		install = _hub.get_update_install()
	if not _check(install != null, "no empieza la instalacion"):
		return false
	var saw_bar: bool = false
	var saw_flash: bool = false
	var start: int = _frame
	for i: int in 60 * 20:
		if install == null or not is_instance_valid(install) or install.is_done():
			break
		saw_bar = saw_bar or install.get_step() == HubUpdateInstall.Step.BAR
		saw_flash = saw_flash or install.get_step() == HubUpdateInstall.Step.FLASH
		if i == 30 and install.get_step() == HubUpdateInstall.Step.BAR:
			_check(get_tree().paused, "la instalacion no pausa el juego")
		await tick
	_check(saw_bar and saw_flash, "la instalacion no muestra la barra y el destello")
	await _wait_until(func() -> bool: return not get_tree().paused, 5.0)
	_note("instalacion vista: barra y destello, linea de Notas cerrada; %.1f s" % (float(_frame - start) / 60.0))
	return true


func _puzzle_elapsed() -> float:
	if _puzzle_start_frame < 0:
		return 0.0
	return float((_frame - _puzzle_start_frame) - (_paused_frames - _puzzle_start_paused)) / 60.0


func _check_after_install() -> bool:
	var ok: bool = _check(GameState.has_hub_upgrade(UPGRADE), "tras instalar no hay upgrade") \
			and _check(GameState.has_unsaved_changes(), "instalar deberia marcar «sin guardar»") \
			and _check(_hub.get_page_count() == 3, "tras instalar no hay 3 paginas") \
			and _check(_hub.get_update_puzzle() == null, "el acertijo sigue montado tras instalar")
	if ok:
		_note("upgrade instalado (sin guardar): 3 paginas, acertijo retirado, decorado %s" % (_hub.get_installer_decor() != null))
	return ok


func _save_at_notas() -> bool:
	if not await _cross_left():
		return false
	var station: NotasStation = _hub.get_notas()
	if not await _walk_to(station.global_position.x + 2.6 * T - 64.0, 6.0, true, 20.0):
		return _check(false, "no llega a Notas")
	if not await _pulse_until(func() -> bool: return station.is_panel_open()):
		return _check(false, "el pulso no abre Notas")
	await _wait(15)
	_press_event(A_PULSE)  # Guardar
	await _wait(4)
	if not _check((station.get_panel() as NotasPanel).get_mode() == NotasPanel.Mode.CONFIRM, "Guardar no pide confirmacion"):
		return false
	await _wait(10)
	_press_event(A_PULSE)  # Si, guardar
	await _wait(4)
	if not _check(not GameState.has_unsaved_changes() and FileAccess.file_exists(GameState.save_path),
			"Notas no guarda"):
		return false
	var on_disk: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(GameState.save_path))
	_check(Array(on_disk.get("hub_upgrades", [])).has(String(UPGRADE)), "el upgrade no esta en el guardado")
	_note("guardado en Notas con el upgrade (%s)" % GameState.save_path)
	await _wait(5)
	_press_event(A_JUMP)
	await _wait(10)
	return _check(not station.is_panel_open(), "el salto no cierra Notas")


## Sube de un salto a la repisa de la carpeta `id` (por debajo).
func _stand_on_folder(id: StringName) -> FolderStation:
	var folder: FolderStation = _hub.get_folder(id)
	if folder == null:
		_check(false, "sin carpeta %s" % id)
		return null
	if _isak.global_position.y < _hub.get_floor_y() - 4.0:
		await _jump(signf(folder.global_position.x - _x()), 30)
	if not await _walk_to(folder.global_position.x + folder.get_size().x * 0.5, 6.0, true, 20.0):
		_check(false, "no llega bajo la carpeta %s" % id)
		return null
	await _wait_until(func() -> bool: return not _hub.is_page_sliding(), 3.0)
	await _jump()
	if not _check(absf(_isak.global_position.y - _hub.get_shelf_top_y()) < 3.0, "no sube a la repisa de %s" % id):
		return null
	await _wait(20)
	return folder


func _visit_new_folders() -> bool:
	if not await _cross_right():
		return false
	var m4: FolderStation = await _stand_on_folder(&"m4")
	if m4 == null:
		return false
	if not await _pulse_until(func() -> bool: return m4.is_panel_open()):
		return _check(false, "el pulso no abre M4")
	await _wait(15)
	var panel: FolderPanel = m4.get_folder_panel()
	# Desde el paso 11 de docs/propuesta-mundo-4.md el 4-1 es jugable (antes, «Próximamente» sin niveles).
	var first: String = panel.level_text(HubWorlds.levels(HubWorlds.world(&"m4"))[0])
	_check(panel.get_option_ids().has(&"4-1") and first == "4-1 Chats recientes - Nuevo",
		"M4 no lista el 4-1 (%s; %s)" % [first, panel.get_option_ids()])
	_note("M4 disponible: %s / %s" % [panel.get_title(), first])
	_press_event(A_JUMP)
	await _wait(12)
	_check(not m4.is_panel_open(), "el salto no cierra M4")
	if not await _check_locked(&"m5"):
		return false
	if not await _cross_right():
		return false
	return await _check_locked(&"m6")


func _check_locked(id: StringName) -> bool:
	var folder: FolderStation = await _stand_on_folder(id)
	if folder == null:
		return false
	var ok: bool = _check(folder.get_folder_animation() == &"locked", "%s no esta bloqueada" % id) \
			and _check(folder.is_locked_hint_visible() and folder.get_locked_hint_text() == "Sin descargar",
				"%s no dice «Sin descargar»" % id) \
			and _check(folder.is_locked_condition_visible(), "%s sin la segunda linea" % id)
	if ok:
		_note("%s bloqueada: «%s» + «%s» (pagina %d)" % [id, folder.get_locked_hint_text(),
			folder.get_locked_condition_text(), _hub.get_current_page()])
	return ok


func _run_idle() -> bool:
	if not await _go_to_page_two():
		return false
	var puzzle: HubUpdatePuzzle = _hub.get_update_puzzle()
	if not _check(puzzle != null, "sin acertijo en la pagina 2"):
		return false
	await _wait(int(IDLE_S * 60.0))
	var ok: bool = _check(puzzle.get_done_count() == 0, "quieto no deberia encender verificaciones") \
			and _check(not _hub.is_update_install_requested() and not GameState.has_hub_upgrade(UPGRADE),
				"quieto no deberia instalar") \
			and _check(GameState.is_notice_seen(&"hub_update_hint_eco"), "sin la pista de Eco de los 90 s")
	if ok:
		_note("quieto no resuelve: 0/3 tras %.0f s en la pagina 2; pista de Eco a los 90 s" % IDLE_S)
	return ok


func _run_nosave() -> bool:
	if not await _go_to_page_two():
		return false
	if not await _solve_and_install():
		return false
	if not await _check_after_install():
		return false
	if not await _cross_left():
		return false
	# Entra al 1-1 sin guardar y cae tres veces: game over.
	var folder: FolderStation = await _stand_on_folder(&"m1")
	if folder == null:
		return false
	if not await _pulse_until(func() -> bool: return folder.is_panel_open()):
		return _check(false, "el pulso no abre M1")
	await _wait(15)
	var panel: FolderPanel = folder.get_folder_panel()
	if not _check(panel.get_selected_option() == &"1-1", "la primera opcion de M1 no es el 1-1"):
		return false
	_press_event(A_PULSE)
	await _wait(4)
	_check(panel.is_confirming_unsaved(), "sin guardar, la carpeta deberia preguntar")
	await _wait(15)
	_press_event(A_PULSE)  # Entrar sin guardar
	if not await _wait_until(func() -> bool: return not _runner.is_in_hub() and _runner.get_level() != null \
			and _runner.get_level_id() == "1-1" and _runner.get_phase() == LevelRunner.Phase.PLAYING, 15.0):
		return _check(false, "la carpeta no carga el 1-1")
	_note("en el 1-1 sin guardar: upgrade en memoria %s" % GameState.has_hub_upgrade(UPGRADE))
	for i: int in GameState.lives_max:
		await _wait_until(func() -> bool: return _runner.get_phase() == LevelRunner.Phase.PLAYING \
				and _isak != null and not _isak.is_dead() and not _isak.is_warping(), 10.0)
		GameState.sync_rate = GameState.SYNC_RATE_MIN
		await _wait(4)
	if not await _wait_until(func() -> bool: return _runner.is_in_hub() and _hub != null and _hub.has_arrived(), 20.0):
		return _check(false, "el game over no lleva al hub")
	await _wait_until(func() -> bool: return not get_tree().paused and not _hub.get_text_box().is_showing(), 20.0)
	var puzzle: HubUpdatePuzzle = _hub.get_update_puzzle()
	var ok: bool = _check(not GameState.has_hub_upgrade(UPGRADE), "el upgrade sin guardar sobrevive al game over") \
			and _check(HubWorlds.is_hub_upgrade_pending(UPGRADE), "el acertijo no vuelve a estar pendiente") \
			and _check(_hub.get_page_count() == 2 and _hub.get_page_state(2) == HubRoom.PAGE_INSTALLING,
				"la pagina 2 no vuelve a estar «en instalacion»") \
			and _check(puzzle != null and puzzle.is_inert() == GameState.has_trash_pending(),
				"con la Papelera llena el acertijo deberia estar inerte")
	if not ok:
		return false
	_note("game over sin guardar: upgrade perdido, pagina 2 «en instalacion», acertijo inerte %s (Papelera %s)" % [
		puzzle.is_inert(), GameState.has_trash_pending()])
	if GameState.has_trash_pending():
		var papelera: Papelera = _hub.get_papelera()
		await _walk_to(papelera.get_center().x, 6.0, true, 20.0)
		if not await _wait_until(func() -> bool: return not GameState.has_trash_pending(), 3.0):
			return _check(false, "no recupera la Papelera")
		await _wait(4)
		_check(not puzzle.is_inert(), "tras recuperar la Papelera el acertijo sigue inerte")
		_note("Papelera recuperada: acertijo activo")
	if not await _go_to_page_two():
		return false
	puzzle = _hub.get_update_puzzle()
	return _check(puzzle != null and puzzle.get_done_count() == 0 and not puzzle.is_inert(),
		"el acertijo no se repite desde 0/3") and _note_ok("el acertijo se repite: pagina 2 en 0/3")


func _note_ok(text: String) -> bool:
	_note(text)
	return true


func _run_kept() -> bool:
	var ok: bool = _check(GameState.has_hub_upgrade(UPGRADE), "el upgrade no se conserva en %s" % ACCESS_NAMES[_lap]) \
			and _check(not HubWorlds.is_hub_upgrade_pending(UPGRADE), "el acertijo no deberia estar pendiente") \
			and _check(_hub.get_page_count() == 3, "deberia haber 3 paginas desde el principio") \
			and _check(_hub.get_update_puzzle() == null, "el acertijo no deberia montarse")
	if not ok:
		return false
	if not await _cross_right():
		return false
	await _wait(20)
	_check(not GameState.is_notice_seen(&"hub_update_intro") and not get_tree().paused,
		"sin acertijo no deberia salir la linea de Eco")
	_check(_hub.get_folder(&"m4") != null and _hub.get_folder(&"m5") != null, "sin carpetas en la pagina 2")
	var m4: FolderStation = _hub.get_folder(&"m4")
	_note("%s: 3 paginas, sin acertijo; M4 %s" % [ACCESS_NAMES[_lap], m4.get_folder_animation() if m4 != null else &"?"])
	if not await _cross_right():
		return false
	return _check(_hub.get_folder(&"m6") != null, "sin M6 en la pagina 3")
