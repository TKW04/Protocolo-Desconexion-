## Bot vertical del 1-2 (paso 15 de docs/propuesta-1-2.md §10, 2026-10-18): carga
## la escena principal (scenes/main.tscn, LevelRunner) en el 1-2 real y sigue,
## paso a paso, el camino que exporta tools/validate_level.py (--export-path,
## formato isak-path/1; contrato en la skill level-builder) con la fisica real:
## pulsa las acciones del Input Map (move_left / move_right, jump, run, pulse,
## laser, debug) con Input.action_press / action_release, nunca teletransporta.
## Dos casos: Calc desconocida (azotea completa: Debug para la pared con glitch,
## 3 pulsos de espaldas al interruptor, laser al interruptor lejano, panel oculto
## con el Debug, espera de la carga de Calc y terminal con corriente; despues, la
## escena de Calc en el hub, linea a linea con ui_accept, y allies_met["calc"]) y
## Calc conocida (camino directo; sin escena en el hub).
## Como un jugador: espera la llegada por el vortice (control bloqueado), cierra
## las lineas importantes de Eco y los avisos (ui_accept) y deja correr las que no
## lo son (guia de Eco), aturde los puntos rojos y las Burbujas que se le echan
## encima con el pulso, espera la barra del 99 %, cronometra los banners
## (wait_phase), dispara a los Posponer en su ventana. NUNCA pulsa help (Q) ni
## pause. Pequenas derivas: un salto que no llega se repite (MAX_STEP_RETRIES) y,
## si Isak acaba en otro sitio (cae a un piso de abajo, muere y reaparece en el
## punto de sincronizacion), retoma el camino desde el paso cuyo origen esta en
## su fila (replanifica el tramo). Si no avanza, falla con el piso, la posicion,
## el paso y el estado.
## Al final compara la duracion de juego y la energia minima con las del camino.
## Usa su propio guardado (BOT_SAVE_PATH, borrado al empezar; o ISAK_SAVE_PATH).
## Lo lanza tools/play_tower_bot.gd (uso y argumentos alli).
## Tambien es la base del bot del 1-3 (tools/dnd_bot.gd, paso 11 de
## docs/propuesta-1-3.md), que sobrescribe los metodos virtuales marcados
## «Virtual» (nivel, progreso, comprobaciones, hub y pasos nuevos).
extends Node

const MAIN_SCENE: String = "res://scenes/main.tscn"
const LEVEL_ID: String = "1-2"
const BOT_SAVE_PATH: String = "user://bot_save.json"
const TILE: float = 64.0
const A_LEFT: StringName = &"move_left"
const A_RIGHT: StringName = &"move_right"
const A_JUMP: StringName = &"jump"
const A_RUN: StringName = &"run"
const A_PULSE: StringName = &"pulse"
const A_LASER: StringName = &"laser"
const A_DEBUG: StringName = &"debug"
const A_ACCEPT: StringName = &"ui_accept"
## Tope de cuadros de juego (sin contar pausas) del recorrido del nivel.
const MAX_PLAY_FRAMES: int = 60 * 600
## Reintentos de un mismo paso y replanificaciones en total.
const MAX_STEP_RETRIES: int = 3
const MAX_REPLANS: int = 12
## Tolerancias (px): llegada andando, fila de los pies.
const WALK_TOL: float = 4.0
const ROW_TOL: float = 6.0
## Margen (px) dentro de la celda de llegada al apuntar un salto.
const AIM_MARGIN: float = 20.0
## Tramos de al menos estos tiles por el pasillo de un banner se cruzan corriendo.
const BANNER_RUN_TILES: float = 6.0
## Distancia (px, centro del punto rojo al pecho de Isak) a la que el bot lanza
## el pulso a un punto rojo que se infla o se lanza.
const ANTICIPATE_PULSE_PX: float = 140.0
## Cuadros que una linea importante esta en pantalla antes de pulsar aceptar.
const LINE_READ_FRAMES: int = 10
## Diferencia permitida (s) entre la duracion de juego del bot y la del camino.
const DURATION_TOLERANCE_S: float = 25.0

## Fin del recorrido: 0 si todo ha ido bien, 1 si algo ha fallado.
signal finished(code: int)

var _known: bool = false
var _wall_start_ms: int = Time.get_ticks_msec()
## --verbose: anota cada paso al empezarlo.
var _verbose: bool = false
var _path: Dictionary = {}
var _steps: Array = []
var _runner: LevelRunner
var _isak: Isak
var _level: GeneratedLevel
var _frame: int = 0
## Cuadros de juego (arbol sin pausa) desde que Isak tiene el control.
var _play_frames: int = 0
var _play_started: bool = false
var _log: PackedStringArray = []
var _taps: Array[StringName] = []
var _tap_queue: Array[StringName] = []
var _axis: float = 0.0
var _min_energy: float = INF
var _hits: int = 0
var _deaths: int = 0
var _replans: int = 0
var _guard_pulses: int = 0
var _important_lines: int = 0
var _line_key: String = ""
var _line_frame: int = 0
var _help_frames: int = 0
var _pause_menu_opens: int = 0
var _step_index: int = -1
var _terminal_frames: int = -1
var _shots_dir: String = ""
var _shot_names: Dictionary = {}
var _isak_hurt_connected: Isak


func _ready() -> void:
	process_physics_priority = -1000
	var env_path: String = OS.get_environment(GameState.SAVE_PATH_ENV)
	GameState.use_save_path(BOT_SAVE_PATH if env_path.is_empty() else env_path, true)
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var at: int = args.find("--case")
	_known = at >= 0 and at + 1 < args.size() and args[at + 1] == "known"
	_verbose = args.has("--verbose")
	at = args.find("--shots")
	if at >= 0 and at + 1 < args.size():
		_shots_dir = args[at + 1]
		DirAccess.make_dir_recursive_absolute(_shots_dir)
	at = args.find("--path")
	var path_file: String = args[at + 1] if at >= 0 and at + 1 < args.size() else ""
	_run.call_deferred(path_file)


func _run(path_file: String) -> void:
	var ok: bool = _load_path(path_file)
	if ok:
		EventBus.pause_menu_opened.connect(func() -> void: _pause_menu_opens += 1)
		_setup_progress()
		ok = await _play_level()
	if ok:
		ok = await _hub()
	_release_all()
	if ok and _pause_menu_opens > 0:
		ok = _fail("el menu de pausa se abrio %d veces (el bot no pulsa pause)" % _pause_menu_opens)
	if ok and not GameState.learned_help.is_empty():
		ok = _fail("el bot no pide ayuda (Q) y hay tipos aprendidos: %s" % [GameState.learned_help.keys()])
	print("%s: %s" % [_bot_label(), "OK" if ok else "FALLO"])
	for line: String in _log:
		print("  " + line)
	finished.emit(0 if ok else 1)


# --- Virtuales (los sobrescribe tools/dnd_bot.gd) ---

## Virtual: id del nivel que recorre el bot.
func _level_id() -> String:
	return LEVEL_ID


## Virtual: etiqueta de la linea de resultado («<etiqueta>: OK»).
func _bot_label() -> String:
	return "play_tower_bot (%s)" % ("Calc conocida" if _known else "Calc desconocida")


## Virtual: argumentos de tools/validate_level.py para exportar el camino a `path_file`.
func _export_args(path_file: String) -> PackedStringArray:
	var args: PackedStringArray = [ProjectSettings.globalize_path("res://tools/validate_level.py")]
	if _known:
		args.append_array(["--allies", "calc"])
	args.append_array(["--export-path", path_file, ProjectSettings.globalize_path("res://data/levels/%s.json" % _level_id())])
	return args


## Virtual: archivo (user://) donde se exporta el camino.
func _path_cache_file() -> String:
	return "user://tower_bot_path_%s.json" % ("known" if _known else "unknown")


## Virtual: comprobacion del nivel recien cargado (el 1-2, con la camara de torre).
func _check_level_loaded() -> bool:
	if _isak == null or _isak.camera_mode != Isak.CAMERA_TOWER:
		return _fail("el 1-2 no carga con la camara de torre")
	return true


## Virtual: progreso tras volver al hub (el 1-2 completado y el 1-3 desbloqueado).
func _check_completed() -> bool:
	if not GameState.is_level_completed(&"1-2") or not GameState.is_level_unlocked(&"1-3"):
		return _fail("el 1-2 no queda completado o el 1-3 no se desbloquea")
	return true


## Virtual: pasos del camino que el bot del 1-2 no conoce (dash, wait_beat…).
func _do_extra_step(_s: Dictionary, action: String) -> bool:
	return _fail("accion desconocida en el camino: %s" % action)


# --- Camino ---

## Lee el camino de `path_file` o lo exporta con el validador (caso del bot).
func _load_path(path_file: String) -> bool:
	if path_file.is_empty():
		path_file = ProjectSettings.globalize_path(_path_cache_file())
		var args: PackedStringArray = _export_args(path_file)
		var output: Array = []
		var code: int = OS.execute("python3", args, output, true)
		if code != 0:
			return _fail("el validador no exporta el camino (codigo %d): %s" % [code, "".join(output).right(400)])
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path_file))
	if not parsed is Dictionary or String((parsed as Dictionary).get("format", "")) != "isak-path/1":
		return _fail("camino ilegible o de otro formato: %s" % path_file)
	_path = parsed
	_steps = _path.get("steps", [])
	if String(_path.get("level", "")) != _level_id() or _steps.is_empty():
		return _fail("el camino no es del %s o no tiene pasos" % _level_id())
	_note("camino %s: %d pasos, %.1f s, energia minima %.1f" % [path_file.get_file(), _steps.size(),
		float(_path.get("duration_s", 0.0)), float(_path.get("energy", {}).get("min", 0.0))])
	return true


## Progreso de un jugador que acaba de completar el 1-1 (Eco, Notas, pulso y
## laser; sin Debug); con --case known, Calc ya conocida.
func _setup_progress() -> void:
	GameState.reset_progress()
	GameState.meet_ally(GameState.ALLY_ECO)
	GameState.meet_ally(GameState.ALLY_NOTAS)
	for ability: StringName in [GameState.ABILITY_PULSE, GameState.ABILITY_LASER]:
		GameState.obtained_abilities[ability] = true
		GameState.seen_notices[ability] = true
		GameState.set_ability_unlocked(ability, true)
	GameState.mark_level_completed(&"1-1")
	GameState.unlock_level(&"1-2")
	if _known:
		GameState.meet_ally(GameState.ALLY_CALC)
	GameState.sync_rate = GameState.SYNC_RATE_MAX
	GameState.debug_energy = GameState.get_debug_energy_max()


# --- Nivel ---

func _play_level() -> bool:
	var main: Node = (load(MAIN_SCENE) as PackedScene).instantiate()
	(main as LevelRunner).start_level_id = _level_id()
	get_tree().root.add_child(main)
	_runner = main as LevelRunner
	await get_tree().physics_frame
	_refresh()
	if not _check_level_loaded():
		return false
	# Llegada por el vortice: el control esta bloqueado hasta que se cierra.
	var limit: int = _frame + 60 * 10
	var blocked_seen: bool = false
	while _frame < limit and not _has_control():
		blocked_seen = true
		await _tick()
	if not _has_control():
		return _fail("Isak no recibe el control tras el vortice de llegada")
	_note("llegada por el vortice terminada (control %s); Isak en %s" % [
		"bloqueado hasta entonces" if blocked_seen else "inmediato", _where()])
	_play_started = true
	_shot("01_llegada")
	var i: int = 0
	var retries: Dictionary = {}
	while i < _steps.size():
		var step: Dictionary = _steps[i]
		_step_index = i
		if _play_frames > MAX_PLAY_FRAMES:
			return _fail("tiempo agotado en el paso %d" % i)
		if _verbose:
			_note("paso %d %s (camino t=%.1f s): Isak en %s, energia %.0f" % [i, _describe(step), float(step.get("t", 0.0)),
				_where(), GameState.debug_energy])
		var ok: bool = await _do_step(step)
		if ok:
			i += 1
			continue
		var tries: int = int(retries.get(i, 0)) + 1
		retries[i] = tries
		var resume: int = await _replan(i)
		if resume < 0 or tries > MAX_STEP_RETRIES or _replans >= MAX_REPLANS:
			return _fail("no avanza en el paso %d (%s) tras %d intentos: %s" % [i, _describe(step), tries, _state()])
		i = resume
	if not await _wait_hub():
		return false
	var game_s: float = (_terminal_frames if _terminal_frames >= 0 else _play_frames) / 60.0
	var path_s: float = float(_path.get("duration_s", 0.0))
	var path_min: float = float(_path.get("energy", {}).get("min", 0.0))
	_note("RESULTADO: recorrido %.1f s de juego (camino %.1f s, %+.1f s); energia minima %.1f (camino %.1f, %+.1f); golpes %d, muertes %d, replanificaciones %d, pulsos de defensa %d, lineas importantes %d, cuadros con la Q visible %d (no se pulsa)" % [
		game_s, path_s, game_s - path_s, _min_energy, path_min, _min_energy - path_min, _hits, _deaths, _replans,
		_guard_pulses, _important_lines, _help_frames])
	var tolerance: float = _duration_tolerance_s()
	if absf(game_s - path_s) > tolerance:
		return _fail("la duracion se aleja mas de %.0f s de la del camino" % tolerance)
	return _check_completed()


## Cuanto puede alejarse la duracion de juego de la del camino (los bots hijos la amplian con las esperas que el
## camino cuenta por el peor caso).
func _duration_tolerance_s() -> float:
	return DURATION_TOLERANCE_S


func _wait_hub() -> bool:
	var limit: int = _frame + 60 * 15
	while _frame < limit and not _runner.is_in_hub():
		await _tick()
	if not _runner.is_in_hub():
		return _fail("la terminal no lleva al hub: %s" % _state())
	_note("hub cargado tras completar el %s" % _level_id())
	return true


# --- Hub ---

func _hub() -> bool:
	var hub: HubRoom = _runner.get_hub()
	var limit: int = _frame + 60 * 10
	while _frame < limit and not hub.has_arrived():
		await _tick()
	if not hub.has_arrived():
		return _fail("Isak no llega al hub por el vortice")
	_shot("20_hub")
	var intro: CalcIntro = hub.get_calc_intro()
	if _known:
		if intro != null and (intro.is_running() or intro.is_done()):
			return _fail("con Calc ya conocida no deberia haber escena de Calc")
		_note("hub: Calc ya conocida, sin escena (correcto)")
		await _wait_frames(6)
		return true
	if intro == null:
		return _fail("Calc desconocida: el hub no tiene la escena de Calc")
	var box: EcoTextBox = hub.get_text_box()
	var speakers: Dictionary = {}
	var lines: int = 0
	var current: String = ""
	limit = _frame + 60 * 60
	while _frame < limit and not intro.is_done():
		await _tick(false)
		if not box.is_showing() or not box.is_important():
			current = ""
			continue
		var key: String = box.get_speaker_text() + "|" + box.get_text()
		if key != current:
			current = key
			lines += 1
			speakers[String(box.get_speaker_id())] = int(speakers.get(String(box.get_speaker_id()), 0)) + 1
			_note("escena de Calc, %s: «%s»" % [box.get_speaker_text(), box.get_text()])
			if lines == 1:
				_shot("21_calc_intro", LINE_READ_FRAMES + 2)
		_confirm_line(box)
	if not intro.is_done():
		return _fail("la escena de Calc no termina (%d lineas)" % lines)
	if not GameState.allies_met.has(GameState.ALLY_CALC) and not GameState.allies_met.has(String(GameState.ALLY_CALC)):
		return _fail("tras la escena allies_met no tiene calc")
	if not speakers.has("eco") and not speakers.has(""):
		return _fail("la escena de Calc no tiene la interrupcion de Eco (%s)" % [speakers])
	await _wait_frames(20)
	if get_tree().paused:
		return _fail("el arbol sigue en pausa tras la escena de Calc")
	_note("escena de Calc terminada: %d lineas (%s); allies_met['calc'] = %s; Calc encendida %s" % [lines, speakers,
		GameState.has_met_ally(GameState.ALLY_CALC), hub.get_calc().is_powered()])
	_shot("22_calc_conocida")
	await _wait_frames(6)
	return true


# --- Pasos ---

func _do_step(s: Dictionary) -> bool:
	var action: String = String(s.get("action", ""))
	match action:
		"walk":
			if s.get("debug", false) and not DebugMode.is_active():
				await _debug_on(s)
			var dir: float = signf(_px(s["to"]).x - _px(s["from"]).x)
			var run: bool = _banner_chases(_px(s["from"]), _px(s["to"]))
			if _continues(_step_index + 1, dir):
				return await _walk_through(_px(s["to"]).x, _px(s["to"]).y, dir, run)
			return await _walk_to(_px(s["to"]).x, _px(s["to"]).y, run)
		"jump", "jump_run", "fall", "hop":
			return await _jump(s, action)
		"pulse":
			return await _pulse_step(s)
		"laser":
			return await _laser_step(s)
		"wait":
			return await _wait_step(s)
		"wait_phase":
			return await _wait_phase(s)
		"pickup":
			return await _pickup(s)
		"charge":
			_note("cargador %s: energia %.0f" % [String(s.get("target", {}).get("id", "?")), GameState.debug_energy])
			return true
		"debug_on":
			return await _debug_on(s)
		"debug_off":
			return await _debug_off()
		"goal":
			return true
	return await _do_extra_step(s, action)


## El paso `index` sigue andando o saltando en la direccion `dir` sin pararse
## (salto con carrerilla o otro tramo andando): el tramo anterior no frena.
func _continues(index: int, dir: float) -> bool:
	if index >= _steps.size() or dir == 0.0:
		return false
	var n: Dictionary = _steps[index]
	match String(n.get("action", "")):
		"walk":
			return signf(_px(n["to"]).x - _px(n["from"]).x) == dir and not n.get("debug", false)
		"jump", "jump_run":
			var target: Variant = n.get("target_x_px", null)
			var tk: float = float(n.get("takeoff_x_px", 0.0))
			var standing: bool = target != null and absf(float(target) - tk) < 8.0
			return float(n.get("direction", 0)) == dir and not standing and not n.get("debug", false) \
				and (tk - _px(n["from"]).x) * dir >= -4.0
	return false


## Anda hasta pasar por `x` (direccion `dir`) sin frenar: el paso siguiente sigue.
func _walk_through(x: float, feet_y: float, dir: float, run: bool = false) -> bool:
	var budget: int = int(absf(x - _isak.global_position.x) / 220.0 * 60.0 * 2.0) + 120
	_hold(A_RUN, run)
	while budget > 0:
		if not _has_control():
			_set_axis(0.0)
			await _tick()
			if _isak.is_dead():
				return false
			continue
		if (x - _isak.global_position.x) * dir <= 2.0:
			_hold(A_RUN, false)
			return absf(_isak.global_position.y - feet_y) < ROW_TOL
		if _isak.is_on_floor() and absf(_isak.global_position.y - feet_y) > TILE * 0.75:
			_set_axis(0.0)
			_hold(A_RUN, false)
			return false
		_set_axis(dir)
		await _tick()
		budget -= 1
	_set_axis(0.0)
	_hold(A_RUN, false)
	return false


## Tramo andando por el pasillo de un banner, en su direccion de barrido y de
## al menos BANNER_RUN_TILES: andando, el siguiente barrido lo alcanza (el banner
## va a 640 px/s y el ciclo es de 3 s), asi que se cruza corriendo, como un
## jugador (hallazgo del paso 15: piso 4, pasillo de banner_2).
func _banner_chases(from: Vector2, to: Vector2) -> bool:
	if absf(to.x - from.x) < BANNER_RUN_TILES * TILE or not is_instance_valid(_level):
		return false
	for node: Node in _level.get_node(^"Enemies").get_children():
		var banner := node as SpamBanner
		if banner == null:
			continue
		var corridor: Rect2 = banner.get_corridor_rect()
		if absf(corridor.end.y - from.y) > ROW_TOL or signf(to.x - from.x) != signf(float(banner.direction)):
			continue
		var a: float = minf(from.x, to.x)
		var b: float = maxf(from.x, to.x)
		if b - a > 0.0 and minf(b, corridor.end.x) - maxf(a, corridor.position.x) > TILE * 6.0:
			if not _banner_runs.has(banner.name):
				_banner_runs[banner.name] = true
				_note("pasillo de %s: se cruza corriendo (andando lo alcanza el barrido)" % banner.name)
			return true
	return false


## Camina hasta `x` por la fila `feet_y`. Falso si cae a otra fila o no llega.
func _walk_to(x: float, feet_y: float, run: bool = false) -> bool:
	var budget: int = int(absf(x - _isak.global_position.x) / 220.0 * 60.0 * 2.0) + 120
	var used: int = 0
	_hold(A_RUN, run)
	while used < budget:
		if not _has_control():
			_set_axis(0.0)
			await _tick()
			if _isak.is_dead():
				return false
			continue
		var dx: float = x - _isak.global_position.x
		if absf(dx) < WALK_TOL and absf(_isak.velocity.x) < 30.0 and _isak.is_on_floor():
			break
		if _isak.is_on_floor() and absf(_isak.global_position.y - feet_y) > TILE * 0.75:
			_set_axis(0.0)
			_hold(A_RUN, false)
			return false
		var speed_axis: float = 1.0 if absf(dx) > 28.0 else (0.4 if absf(dx) > 8.0 else 0.15)
		_set_axis(signf(dx) * speed_axis)
		await _tick()
		used += 1
	_set_axis(0.0)
	_hold(A_RUN, false)
	await _settle()
	return absf(_isak.global_position.x - x) < WALK_TOL * 3.0 and absf(_isak.global_position.y - feet_y) < ROW_TOL


## Salto (o caida, o salto corriendo) del camino. Verifica la fila de llegada.
func _jump(s: Dictionary, action: String) -> bool:
	var dir: float = float(s.get("direction", 1))
	var to: Vector2 = _px(s["to"]) if s.has("to") else _isak.global_position
	var from: Vector2 = _px(s["from"]) if s.has("from") else _isak.global_position
	var takeoff: float = float(s.get("takeoff_x_px", from.x))
	var target: Variant = s.get("target_x_px", null)
	var run: bool = action == "jump_run" or String(s.get("speed", "walk")) == "run"
	if s.get("debug", false) and not DebugMode.is_active():
		await _debug_on(s)
	var standing: bool = action == "hop" or (target != null and absf(float(target) - takeoff) < 8.0)
	# Donde frenar en el aire: el objetivo del camino, metido en la celda de
	# llegada (el camino suelta la direccion en el borde; en el aire Isak sigue
	# ~20 px al soltarla). Sin objetivo (null), sigue hasta aterrizar.
	var to_cell: float = floorf(to.x / TILE) * TILE
	var aim: float = to.x
	if target != null:
		aim = clampf(float(target), to_cell + AIM_MARGIN, to_cell + TILE - AIM_MARGIN)
		if standing and action != "hop" and _ground_at(aim, from.y) and _walkable(takeoff, aim, from.y):
			takeoff = aim
	if action == "fall":
		# Andar hacia el borde hasta dejar el suelo.
		if not await _walk_to(takeoff - dir * 6.0, from.y):
			return false
		var limit: int = 90
		while limit > 0 and _isak.is_on_floor():
			_set_axis(dir)
			await _tick()
			limit -= 1
	elif standing:
		if not await _walk_to(takeoff, from.y):
			return false
		await _press_jump()
	else:
		# Carrerilla: atras (si hay suelo) y salto al pasar por el despegue.
		var back: float = takeoff - dir * (40.0 if run else 26.0)
		var moving: bool = _isak.velocity.x * dir > 150.0 and (takeoff - _isak.global_position.x) * dir > 0.0
		if not moving and (_isak.global_position.x - back) * dir > 0.0 and _ground_at(back, from.y):
			if not await _walk_to(back, from.y):
				return false
		_hold(A_RUN, run)
		var limit2: int = 180
		while limit2 > 0 and (takeoff - _isak.global_position.x) * dir > 2.0:
			if not _has_control():
				await _tick()
				continue
			if not _isak.is_on_floor() or absf(_isak.global_position.y - from.y) > ROW_TOL:
				_set_axis(0.0)
				_hold(A_RUN, false)
				return false
			_set_axis(dir)
			await _tick()
			limit2 -= 1
		await _press_jump()
	# En el aire: direccion hasta el objetivo (o hasta aterrizar si es null).
	var air: int = 0
	var left_floor: bool = false
	var held_jump: int = 0
	while air < 60 * 4:
		if not _has_control():
			await _tick()
			if _isak.is_dead():
				_release_jump()
				return false
			continue
		if not _isak.is_on_floor():
			left_floor = true
		elif left_floor or (air > 20 and standing):
			break
		var x: float = _isak.global_position.x
		var axis: float = 0.0
		if action == "hop":
			axis = 0.0
		else:
			# Frenada predictiva: el error contando lo que aun recorre al soltar.
			var vx: float = _isak.velocity.x
			var err: float = aim - (x + vx * absf(vx) / (2.0 * _isak.physics.air_acceleration))
			axis = clampf(err / 16.0, -1.0, 1.0) if absf(err) > 2.0 else 0.0
		_set_axis(axis)
		held_jump += 1
		if action != "fall" and (_isak.velocity.y >= 0.0 or held_jump > 30) and Input.is_action_pressed(A_JUMP):
			_release_jump()
		await _tick()
		air += 1
	_release_jump()
	_hold(A_RUN, false)
	_set_axis(0.0)
	await _off_enemy_platform()
	var ok: bool = _isak.is_on_floor() and absf(_isak.global_position.y - to.y) < ROW_TOL
	if not ok:
		_note("paso %d (%s): aterriza en %s, se esperaba la fila de %s" % [_step_index, action, _where(),
			str(s.get("to", {}).get("cell", "?"))])
	return ok


func _press_jump() -> void:
	# Espera a poder saltar (pose del pulso o del laser).
	var limit: int = 40
	while limit > 0 and (not _has_control() or not _isak.can_jump()):
		await _tick()
		limit -= 1
	Input.action_press(A_JUMP)


func _release_jump() -> void:
	Input.action_release(A_JUMP)


## Pulso del camino: de pie donde alcanza al objetivo, mirando hacia el, y
## comprobando el efecto (con reintentos).
func _pulse_step(s: Dictionary) -> bool:
	var target: Dictionary = s.get("target", {})
	var kind: String = String(target.get("type", ""))
	var node: Node = _object(String(target.get("id", "")))
	if node is PulseBridge:
		# El camino nombra el puente que abre: el objetivo es su receptor.
		for other: Node in _level.get_node(^"Objects").get_children():
			if other is PulseReceiver and (other as PulseReceiver).target_id == (node as PulseBridge).object_id:
				node = other
	var at: Vector2 = _px(s["at"]) if s.has("at") else _isak.global_position
	var facing: float = float(s.get("facing", 1))
	var stand: float = _pulse_stand_x(node, at, float(s.get("x_px", at.x)), facing)
	if kind == "notification_badge":
		return await _badge_step(node as NotificationBadge)
	if not await _walk_to(stand, at.y):
		return false
	if _pulse_done(kind, node, s):
		return true
	for attempt: int in 3:
		await _face(facing)
		await _wait_can_pulse()
		_tap(A_PULSE)
		var waited: int = 0
		while waited < 50:
			await _tick()
			waited += 1
			if _isak.is_facing_back() and bool(s.get("face_back", false)) and int(s.get("count", 1)) == int(s.get("of", 1)):
				_shot("1%d_%s" % [3 if kind == "power_switch" else 5, String(target.get("id", ""))], 1)
			if _pulse_done(kind, node, s) and not _isak.is_facing_back() and _isak.get_state_name() != PlayerState.PULSE:
				break
		if _pulse_done(kind, node, s):
			if bool(s.get("face_back", false)):
				await _wait_side()
			if kind == "exit_terminal":
				_terminal_frames = _play_frames
				_note("terminal de la azotea activada con el pulso (%s)" % _where())
				_shot("19_terminal")
			elif bool(s.get("face_back", false)):
				_note("pulso de espaldas a %s (%d de %d)" % [target.get("id", "?"), int(s.get("count", 1)), int(s.get("of", 1))])
			return true
	_note("paso %d: el pulso no hace efecto en %s (%s)" % [_step_index, target.get("id", "?"), kind])
	return false


func _pulse_done(kind: String, node: Node, s: Dictionary) -> bool:
	if node == null:
		return true
	match kind:
		"overlay_popup", "popup_blocker":
			return not node.call(&"is_open")
		"relay_receiver", "receiver":
			return node.call(&"is_active")
		"power_switch", "debug_switch":
			return node.call(&"is_activated") or int(node.call(&"get_count")) >= int(s.get("count", 1))
		"exit_terminal":
			return (node as ExitTerminal).get_state() >= ExitTerminal.State.BOOT
		"dnd_switch":
			return node.call(&"is_on")
	return true


## Punto rojo del camino: espera a que se acerque y lo aturde con el pulso.
func _badge_step(badge: NotificationBadge) -> bool:
	# No se espera al punto rojo (persigue a 70 px/s y Isak anda a 220): la
	# defensa de cada cuadro lo aturde si se acerca. Si ya esta aturdido en la
	# linea del celular, se remata con el laser (no puede danar aturdido).
	if badge == null or badge.is_defeated():
		return true
	if badge.is_stunned():
		var finish: int = 60
		while finish > 0 and badge.is_stunned() and not badge.is_defeated():
			_set_axis(0.0)
			if _has_control() and not _try_finish(badge, badge.get_body_rect()) and finish == 60:
				break
			await _tick()
			finish -= 1
		if badge.is_defeated():
			_note("punto rojo %s eliminado con el laser (energia %.0f)" % [badge.name, GameState.debug_energy])
	else:
		_note("punto rojo %s %s: se sigue (la defensa lo aturde si se acerca)" % [badge.name, badge.get_state()])
	return true


func _laser_step(s: Dictionary) -> bool:
	var target: Dictionary = s.get("target", {})
	var kind: String = String(target.get("type", ""))
	var node: Node = _object(String(target.get("id", "")))
	var at: Vector2 = _px(s["at"]) if s.has("at") else _isak.global_position
	var facing: float = float(s.get("facing", 1))
	# Laser horizontal: vale cualquier punto de la celda; se para donde este si ya
	# esta dentro (los Posponer van con prisa).
	var stand: float = clampf(_isak.global_position.x, at.x - TILE * 0.5 + 12.0, at.x + TILE * 0.5 - 12.0)
	if not await _walk_to(stand, at.y):
		return false
	if _laser_done(kind, node, -1):
		return true
	await _wait_s(float(s.get("wait_before_s", 0.0)))
	var before: int = _laser_count(kind, node)
	for attempt: int in 3:
		await _face(facing)
		var limit: int = 60
		while limit > 0 and not (_has_control() and _isak.can_start_laser() and _isak.get_laser_cooldown_left() <= 0.0
				and not _isak.is_laser_posing()):
			await _tick()
			limit -= 1
		if GameState.debug_energy < _isak.abilities.laser_energy_cost:
			_note("paso %d: sin energia para el laser (%.0f)" % [_step_index, GameState.debug_energy])
			return false
		_tap(A_LASER)
		var waited: int = 0
		while waited < 50 and not _laser_done(kind, node, before):
			await _tick()
			waited += 1
		if _laser_done(kind, node, before):
			_note("laser a %s (%s; energia %.0f)" % [target.get("id", "?"), kind, GameState.debug_energy])
			if kind == "laser_switch":
				_shot("14_interruptor_laser")
			await _wait_s(float(s.get("hold_after_s", 0.0)))
			while _isak.is_laser_posing():
				await _tick()
			return true
	_note("paso %d: el laser no hace efecto en %s" % [_step_index, target.get("id", "?")])
	return false


func _laser_count(kind: String, node: Node) -> int:
	if node == null:
		return 0
	match kind:
		"snooze_button":
			return int(node.call(&"get_snooze_count"))
		"laser_receiver", "laser_switch":
			return int(node.call(&"get_hit_count"))
	return 0


func _laser_done(kind: String, node: Node, before: int) -> bool:
	if node == null:
		return true
	match kind:
		"ad_cover":
			return not node.call(&"is_intact")
		"laser_receiver":
			return before >= 0 and (node.call(&"is_powered") or node.call(&"is_done"))
		"laser_switch":
			return node.call(&"is_activated")
		"snooze_button":
			return before >= 0 and int(node.call(&"get_snooze_count")) > before
	return before >= 0


func _wait_step(s: Dictionary) -> bool:
	var target: Dictionary = s.get("target", {})
	var kind: String = String(target.get("type", ""))
	var node: Node = _object(String(target.get("id", "")))
	var seconds: float = float(s.get("seconds", 0.0))
	match kind:
		"update_bar":
			_note("barra del 99 %%: espera (%s)" % _where())
			_shot("10_barra")
			var ok: bool = await _wait_until(func() -> bool: return node == null or node.call(&"is_open"), seconds + 20.0)
			_note("barra del 99 %%: %s (energia %.0f, golpes %d)" % ["abierta" if ok else "SIN ABRIR", GameState.debug_energy, _hits])
			return ok
		"glitch_wall":
			var ok2: bool = await _wait_until(func() -> bool: return node == null or not node.call(&"is_solid"), seconds + 4.0)
			_note("pared con glitch %s con el Debug" % ("disuelta" if ok2 else "SIN DISOLVER"))
			_shot("12_pared")
			return ok2
		"charge_dock":
			_note("Calc entra y se carga: espera")
			_shot("16_calc_carga")
			var ok3: bool = await _wait_until(func() -> bool: return node == null or node.call(&"is_power_on"), seconds + 10.0)
			_note("Calc %s; terminal con corriente %s" % ["teletransportada" if ok3 else "SIN CARGAR",
				(_object("terminal_azotea") as ExitTerminal).is_powered()])
			_shot("17_terminal_corriente")
			return ok3
		"debug_switch":
			return await _wait_until(func() -> bool: return node == null or node.call(&"is_revealed"), seconds + 2.0)
	await _wait_s(seconds)
	return true


## Espera en el sitio a que el ciclo de cada banner valga banner_cycle_s.
func _wait_phase(s: Dictionary) -> bool:
	var at: Vector2 = _px(s["at"])
	if not await _walk_to(at.x, at.y):
		return false
	var want: Dictionary = s.get("banner_cycle_s", {})
	var period: float = float(s.get("period_s", 3.0))
	var ok: bool = await _wait_until(func() -> bool:
		for id: String in want:
			var banner := _enemy(id) as SpamBanner
			if banner == null:
				continue
			var d: float = fposmod(banner.get_cycle_time() - float(want[id]), period)
			if minf(d, period - d) > 1.5 / 60.0:
				return false
		return true, period * 3.0)
	if not ok:
		_note("paso %d: no se encuentra la fase de los banners" % _step_index)
	return ok


func _pickup(s: Dictionary) -> bool:
	var ability: StringName = StringName(String(s.get("ability", "")))
	var at: Vector2 = _px(s["at"])
	if not GameState.is_ability_obtained(ability):
		await _walk_to(at.x, at.y)
	var ok: bool = await _wait_until(func() -> bool: return GameState.is_ability_obtained(ability), 2.0)
	_note("recoge %s (%s; energia %.0f)" % [ability, _where(), GameState.debug_energy])
	_shot("08_chip_debug")
	return ok


func _debug_on(s: Dictionary) -> bool:
	if DebugMode.is_active():
		return true
	Input.action_press(A_DEBUG)
	var ok: bool = await _wait_until(func() -> bool: return DebugMode.is_active(), float(s.get("hold_s", 1.0)) + 1.5)
	Input.action_release(A_DEBUG)
	if not ok:
		_note("paso %d: el Debug no se activa (energia %.0f)" % [_step_index, GameState.debug_energy])
	return ok


func _debug_off() -> bool:
	if not DebugMode.is_active():
		return true
	await _tick()
	_tap(A_DEBUG)
	return await _wait_until(func() -> bool: return not DebugMode.is_active(), 1.0)


## Retoma el camino tras un fallo: el ultimo paso (hasta `failed`) cuyo origen
## esta en la fila de Isak y a su alcance andando. -1 si no hay.
func _replan(failed: int) -> int:
	_release_all()
	_replans += 1
	var limit: int = _frame + 60 * 8
	while _frame < limit and not (_has_control() and _isak.is_on_floor()):
		await _tick()
	if not _has_control():
		return -1
	await _off_enemy_platform()
	var pos: Vector2 = _isak.global_position
	var best: int = -1
	var best_d: float = INF
	for j: int in range(failed, -1, -1):
		var s: Dictionary = _steps[j]
		var origin: Vector2
		if s.has("from"):
			origin = _px(s["from"])
		elif s.has("at"):
			origin = _px(s["at"])
		else:
			continue
		if absf(origin.y - pos.y) > ROW_TOL or not _walkable(pos.x, origin.x, pos.y):
			continue
		var d: float = absf(origin.x - pos.x) + (failed - j) * 4.0
		if d < best_d:
			best_d = d
			best = j
		if failed - j > 60 and best >= 0:
			break
	_note("replanifica tras el paso %d (%s): Isak en %s -> sigue desde el paso %d" % [failed,
		_describe(_steps[failed]), _where(), best])
	if best >= 0 and _steps[best].has("from"):
		var o: Vector2 = _px(_steps[best]["from"])
		if not await _walk_to(o.x, o.y):
			return -1
	return best


# --- Servicios de cada cuadro ---

## Un cuadro de fisica: suelta los toques del cuadro anterior, cierra las lineas
## importantes (ui_accept), defiende de puntos rojos y Burbujas cercanas y anota
## energia, Q y tiempo de juego.
func _tick(guard: bool = true) -> void:
	await get_tree().physics_frame
	_frame += 1
	_refresh()
	if _runner == null:
		return
	if _hurt_pending:
		_hurt_pending = false
		_note("golpe a Isak (%s; Sync %.0f; %s)" % [_where(), GameState.sync_rate,
			_last_hitter if not _last_hitter.is_empty() else "cerca: " + _nearest_enemy()])
		_last_hitter = ""
	if _play_started and not get_tree().paused and not _runner.is_in_hub():
		_play_frames += 1
	if not _runner.is_in_hub():
		_min_energy = minf(_min_energy, GameState.debug_energy)
		var level_box := _level.get_node_or_null(^"EcoTextBox") as EcoTextBox if is_instance_valid(_level) else null
		if level_box != null:
			_confirm_line(level_box)
		var help := _level.get_node_or_null(^"Help") as HelpSystem if is_instance_valid(_level) else null
		if help != null and help.is_prompt_visible():
			_help_frames += 1
		_watch_hits()
		if guard:
			_guard()
	for name: String in _shot_names.keys():
		if _frame >= int(_shot_names[name]):
			_shot_names.erase(name)
			await RenderingServer.frame_post_draw
			var file: String = _shots_dir.path_join(name + ".png")
			get_viewport().get_texture().get_image().save_png(file)


## Linea importante en pantalla: como el jugador, la lee unos cuadros y pulsa
## aceptar (la primera pulsacion completa el texto, la siguiente la cierra).
func _confirm_line(box: EcoTextBox) -> void:
	if not box.is_showing() or not box.is_important():
		_line_key = ""
		return
	var key: String = box.get_speaker_text() + "|" + box.get_text()
	if key != _line_key:
		_line_key = key
		_line_frame = _frame
		_important_lines += 1
		if not _runner.is_in_hub():
			_note("linea importante (%s): «%s» -> aceptar" % [box.get_speaker_text(), box.get_text()])
		return
	if (_frame - _line_frame) % LINE_READ_FRAMES == LINE_READ_FRAMES - 1:
		for pressed: bool in [true, false]:
			var event := InputEventAction.new()
			event.action = A_ACCEPT
			event.pressed = pressed
			Input.parse_input_event(event)


## Defensa: un punto rojo que persigue o se infla, o una Burbuja peligrosa, al
## alcance del pulso -> pulso (como el jugador).
func _guard() -> void:
	if _guard_lock > 0:
		_guard_lock -= 1
		if _guard_lock == 0:
			_set_axis(_axis)
	if not _has_control() or not _can_pulse_now() or not is_instance_valid(_level):
		return
	for node: Node in _enemies():
		var rect := Rect2()
		var threat: bool = false
		if node is NotificationBadge:
			var badge := node as NotificationBadge
			# Andando, Isak deja atras al punto rojo (70 px/s): solo se defiende
			# cuando se infla o se lanza; quieto, en cuanto persigue al alcance.
			var st: StringName = badge.get_state()
			threat = badge.is_chasing() if _axis == 0.0 \
				else (st == NotificationBadge.STATE_ANTICIPATE or st == NotificationBadge.STATE_LUNGE)
			rect = badge.get_body_rect()
		elif node is AlertBubble:
			var bubble := node as AlertBubble
			threat = bubble.is_dangerous()
			rect = bubble.get_body_rect()
		if not threat:
			if _axis == 0.0 and _guard_lock == 0 and _try_finish(node, rect):
				return
			continue
		# El pulso solo mira quien esta en su circulo al lanzarlo (EventBus.
		# pulse_fired): se lanza con el enemigo dentro; si esta detras, primero
		# un toque de la direccion para girarse (la defensa manda 3 cuadros).
		if _in_pulse_range(rect, 0.9, _isak.facing):
			_tap(A_PULSE)
			_guard_pulses += 1
			if _verbose and _guard_pulses % 10 == 0:
				_note("defensa %d: %s %s rect %s; Isak %s estado %s" % [_guard_pulses, node.name,
					String(node.call(&"get_state")), rect, _isak.global_position, _isak.get_state_name()])
			if _guard_pulses == 1:
				_note("defensa: pulso a %s (%s)" % [node.name, _where()])
			return
		var toward: float = signf(rect.get_center().x - _isak.global_position.x)
		if toward != 0.0 and toward != signf(_isak.facing) and _in_pulse_range(rect, 0.9, toward):
			var keep: float = _axis
			Input.action_release(A_LEFT)
			Input.action_release(A_RIGHT)
			_tap(A_RIGHT if toward > 0.0 else A_LEFT)
			_axis = keep
			_guard_lock = 3
			return


## Quieto: remata con el laser a un punto rojo o una Burbuja aturdidos en la
## linea del celular (dos disparos, devuelven 25 de energia y 10 de Sync al
## morir: lo que haria un jugador). Verdadero si dispara o se gira.
func _try_finish(node: Node, rect: Rect2) -> bool:
	var stunned: bool = (node is NotificationBadge and (node as NotificationBadge).is_stunned()) \
		or (node is AlertBubble and (node as AlertBubble).is_stunned())
	if not stunned or not _isak.can_start_laser() or _isak.get_laser_cooldown_left() > 0.0 or _isak.is_laser_posing() \
			or GameState.debug_energy < _isak.abilities.laser_energy_cost * 2.0 or _isak.is_facing_back():
		return false
	var phone_y: float = _isak.global_position.y + _isak.pulse_effect_origin.y
	var dx: float = rect.get_center().x - _isak.global_position.x
	if phone_y < rect.position.y + 2.0 or phone_y > rect.end.y - 2.0 or absf(dx) > _isak.abilities.laser_range_px * 0.8 \
			or absf(dx) < 24.0:
		return false
	if signf(dx) != signf(_isak.facing):
		_tap(A_RIGHT if dx > 0.0 else A_LEFT)
		return true
	_tap(A_LASER)
	if not _kills.has(node.name):
		_kills.append(node.name)
		_note("remata con el laser a %s aturdido (%s; energia %.0f)" % [node.name, _where(), GameState.debug_energy])
	return true


## Enemigos del nivel y los que sueltan las oleadas de la barra del 99 %.
func _enemies() -> Array[Node]:
	var out: Array[Node] = _level.get_node(^"Enemies").get_children()
	for node: Node in _level.get_node(^"Objects").get_children():
		if node is NotificationBadge or node is AlertBubble:
			out.append(node)
	return out


# --- Utilidades ---

func _refresh() -> void:
	if _runner == null:
		return
	var isak: Isak = _runner.get_hub().get_isak() if _runner.is_in_hub() and _runner.get_hub() != null else _runner.get_isak()
	if isak != null and isak != _isak:
		_isak = isak
	if _isak != null and _isak_hurt_connected != _isak:
		_isak_hurt_connected = _isak
		_isak.hurt.connect(func() -> void:
			_hits += 1
			_hurt_pending = true)
	if not _runner.is_in_hub():
		var level: GeneratedLevel = _runner.get_level()
		if level != null:
			_level = level
	if _isak != null and _isak.is_dead() and not _was_dead:
		_deaths += 1
		_note("Isak muere (%s)" % _where())
	_was_dead = _isak != null and _isak.is_dead()


var _was_dead: bool = false
## Enemigos cuya senal hit_player ya se escucha y el ultimo que golpeo.
var _hit_watch: Dictionary = {}
var _banner_runs: Dictionary = {}
## Cuadros en que la defensa manda sobre la direccion (giro y pulso).
var _guard_lock: int = 0
var _hurt_pending: bool = false
var _kills: PackedStringArray = []
var _last_hitter: String = ""


func _watch_hits() -> void:
	if not is_instance_valid(_level):
		return
	for node: Node in _enemies():
		if _hit_watch.has(node) or not node.has_signal(&"hit_player"):
			continue
		_hit_watch[node] = true
		var label: String = node.name
		node.connect(&"hit_player", func(_amount: float) -> void:
			var rel: Vector2 = (node as Node2D).global_position - _isak.global_position if is_instance_valid(node) else Vector2.ZERO
			_last_hitter = "por %s (%s, a %+.0f, %+.0f de los pies; Isak %s, mira %+.0f)" % [label,
				String(node.call(&"get_state")) if is_instance_valid(node) else "?", rel.x, rel.y,
				_isak.get_state_name(), _isak.facing])


func _nearest_enemy() -> String:
	var best: String = "-"
	var best_d: float = INF
	if is_instance_valid(_level):
		for node: Node in _enemies():
			if node is Node2D:
				var d: float = (node as Node2D).global_position.distance_to(_isak.global_position)
				if d < best_d:
					best_d = d
					best = "%s %s a %.0f px" % [node.name, String(node.call(&"get_state")) if node.has_method(&"get_state") else "", d]
	return best


func _has_control() -> bool:
	return _runner != null and _isak != null and not get_tree().paused \
		and _runner.get_phase() == LevelRunner.Phase.PLAYING and not _isak.is_dead() and not _isak.is_warping()


func _can_pulse_now() -> bool:
	return _isak.can_pulse() and _isak.get_state_name() != PlayerState.PULSE and not _isak.is_facing_back() \
		and not _isak.is_laser_posing()


## El pulso alcanza `rect` mirando hacia `facing` (0: hacia el rectangulo).
func _in_pulse_range(rect: Rect2, scale: float = 0.95, facing: float = 0.0) -> bool:
	if facing == 0.0:
		facing = signf(rect.get_center().x - _isak.global_position.x)
	var o: Vector2 = _isak.global_position + Vector2(absf(_isak.pulse_effect_origin.x) * facing,
		_isak.pulse_effect_origin.y)
	var q := Vector2(clampf(o.x, rect.position.x, rect.end.x), clampf(o.y, rect.position.y, rect.end.y))
	return o.distance_to(q) <= _isak.abilities.pulse_radius_px * scale


## X de los pies desde la que el pulso alcanza el objetivo (lo mas cerca del
## centro de la celda); sin rectangulo conocido, la del camino.
func _pulse_stand_x(node: Node, at: Vector2, path_x: float, facing: float) -> float:
	var rect := Rect2()
	for method: StringName in [&"get_button_rect", &"get_hit_rect", &"get_body_rect"]:
		if node != null and node.has_method(method):
			rect = node.call(method)
			break
	if rect.size == Vector2.ZERO:
		return path_x
	var radius: float = _isak.abilities.pulse_radius_px - 10.0
	var best: float = path_x
	var best_d: float = INF
	var x: float = at.x - TILE * 0.5 + 10.0
	while x <= at.x + TILE * 0.5 - 10.0:
		var o := Vector2(x + absf(_isak.pulse_effect_origin.x) * facing, at.y + _isak.pulse_effect_origin.y)
		var q := Vector2(clampf(o.x, rect.position.x, rect.end.x), clampf(o.y, rect.position.y, rect.end.y))
		if o.distance_to(q) <= radius and absf(x - _isak.global_position.x) < best_d:
			best_d = absf(x - _isak.global_position.x)
			best = x
		x += 2.0
	return best


## Gira hacia `facing` con un toque minimo de la direccion.
func _face(facing: float) -> void:
	var limit: int = 6
	while limit > 0 and signf(_isak.facing) != signf(facing):
		if _has_control() and _isak.is_on_floor():
			_set_axis(signf(facing) * 0.1)
		await _tick()
		limit -= 1
	_set_axis(0.0)
	await _settle()


func _wait_can_pulse() -> void:
	var limit: int = 90
	while limit > 0 and not (_has_control() and _can_pulse_now()):
		await _tick()
		limit -= 1


func _wait_side() -> void:
	var limit: int = 120
	while limit > 0 and (_isak.is_facing_back() or not _has_control()):
		await _tick()
		limit -= 1


## De pie sobre un enemigo aturdido (punto rojo o Burbuja: sus pies no estan en
## una fila de tiles): espera a que se despierte y Isak caiga al suelo (5 s).
func _off_enemy_platform() -> void:
	var limit: int = 60 * 5
	while limit > 0 and _isak.is_on_floor() and _off_grid():
		if limit == 60 * 5:
			_note("de pie sobre un enemigo aturdido (%s): espera a bajar" % _where())
		await _tick()
		limit -= 1
	await _settle()


func _off_grid() -> bool:
	var y: float = _isak.global_position.y
	return absf(y - roundf(y / TILE) * TILE) > 3.0


func _settle() -> void:
	var limit: int = 30
	while limit > 0 and (absf(_isak.velocity.x) > 5.0 or not _isak.is_on_floor()):
		await _tick()
		limit -= 1


## Espera (tiempo de juego, sin contar pausas) a que `done` sea verdadero.
func _wait_until(done: Callable, seconds: float) -> bool:
	var frames: int = int(seconds * 60.0) + 1
	while frames > 0:
		if done.call():
			return true
		await _tick()
		if not get_tree().paused:
			frames -= 1
	return done.call()


func _wait_s(seconds: float) -> void:
	var frames: int = roundi(seconds * 60.0)
	while frames > 0:
		await _tick()
		if not get_tree().paused:
			frames -= 1


func _wait_frames(count: int) -> void:
	for i: int in count:
		await _tick(false)


func _set_axis(a: float) -> void:
	_axis = a
	if _guard_lock > 0:
		return
	if a > 0.001:
		Input.action_release(A_LEFT)
		Input.action_press(A_RIGHT, minf(a, 1.0))
	elif a < -0.001:
		Input.action_release(A_RIGHT)
		Input.action_press(A_LEFT, minf(-a, 1.0))
	else:
		Input.action_release(A_LEFT)
		Input.action_release(A_RIGHT)


func _hold(action: StringName, on: bool) -> void:
	if on:
		Input.action_press(action)
	else:
		Input.action_release(action)


## Toque de una accion (un cuadro). Se pulsa en el _physics_process del bot,
## que va antes que el de Isak (process_physics_priority), para que Isak lo vea
## como «recien pulsado» (is_action_just_pressed) en ese mismo cuadro; se
## suelta en el siguiente.
func _tap(action: StringName) -> void:
	if not _tap_queue.has(action):
		_tap_queue.append(action)


func _physics_process(_delta: float) -> void:
	for action: StringName in _taps:
		if not _tap_queue.has(action):
			Input.action_release(action)
	_taps.clear()
	for action: StringName in _tap_queue:
		Input.action_press(action)
		_taps.append(action)
	_tap_queue.clear()


func _release_all() -> void:
	for action: StringName in [A_LEFT, A_RIGHT, A_JUMP, A_RUN, A_PULSE, A_LASER, A_DEBUG]:
		Input.action_release(action)
	_taps.clear()
	_tap_queue.clear()
	_axis = 0.0


func _ground_at(x: float, feet_y: float) -> bool:
	var from := Vector2(x, feet_y - 8.0)
	var query := PhysicsRayQueryParameters2D.create(from, from + Vector2(0.0, 24.0), 1)
	return not _isak.get_world_2d().direct_space_state.intersect_ray(query).is_empty()


## Hay suelo continuo (cada 16 px) entre `x0` y `x1` en la fila `feet_y` y nada
## solido a la altura del cuerpo.
func _walkable(x0: float, x1: float, feet_y: float) -> bool:
	var space: PhysicsDirectSpaceState2D = _isak.get_world_2d().direct_space_state
	var x: float = x0
	var step: float = 16.0 * signf(x1 - x0)
	while absf(x - x1) > 16.0:
		if not _ground_at(x, feet_y):
			return false
		x += step
	var body := PhysicsRayQueryParameters2D.create(Vector2(x0, feet_y - 32.0), Vector2(x1, feet_y - 32.0), 1)
	return space.intersect_ray(body).is_empty()


func _px(p: Dictionary) -> Vector2:
	var f: Array = p.get("feet_px", [0.0, 0.0])
	return Vector2(float(f[0]), float(f[1]))


func _object(id: String) -> Node:
	if id.is_empty() or not is_instance_valid(_level):
		return null
	var node: Node = _level.get_node_or_null(NodePath("Objects/" + id))
	return node if node != null else _level.get_node_or_null(NodePath("Enemies/" + id))


func _enemy(id: String) -> Node:
	if id.is_empty() or not is_instance_valid(_level):
		return null
	return _level.get_node_or_null(NodePath("Enemies/" + id))


## Piso (1-2) o tramo (1-3) segun la celda de los pies (sections del nivel:
## y_from/y_to en la torre, x_from/x_to en los horizontales).
func _floor_name() -> String:
	if _isak == null:
		return "?"
	var row: int = roundi(_isak.global_position.y / TILE) - 1
	var col: int = int(_isak.global_position.x / TILE)
	if _sections.is_empty():
		var level_data: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/levels/%s.json" % _level_id()))
		_sections = (level_data as Dictionary).get("sections", []) if level_data is Dictionary else []
	for sec: Variant in _sections:
		if not sec is Dictionary:
			continue
		var d: Dictionary = sec
		var inside: bool = (row >= int(d.get("y_from", -1)) and row <= int(d.get("y_to", -1))) if d.has("y_from") \
			else (col >= int(d.get("x_from", -1)) and col <= int(d.get("x_to", -1)))
		if inside:
			return String(d.get("name", d.get("id", "?")))
	return "fila %d" % row


var _sections: Array = []


func _where() -> String:
	if _isak == null:
		return "?"
	var p: Vector2 = _isak.global_position
	return "%s, x=%.0f y=%.0f (celda %d, %d)" % [_floor_name(), p.x, p.y, int(p.x / TILE), roundi(p.y / TILE) - 1]


func _state() -> String:
	if _isak == null:
		return "sin Isak"
	return "%s; estado %s, suelo %s, vel (%.0f, %.0f), energia %.0f, Sync %.0f, Debug %s, fase %s, pausa %s" % [
		_where(), _isak.get_state_name(), _isak.is_on_floor(), _isak.velocity.x, _isak.velocity.y,
		GameState.debug_energy, GameState.sync_rate, DebugMode.is_active(), _runner.get_phase(), get_tree().paused]


func _describe(s: Dictionary) -> String:
	var out: String = String(s.get("action", "?"))
	if s.has("from"):
		out += " %s->%s" % [str(s["from"].get("cell")), str(s.get("to", {}).get("cell"))]
	elif s.has("at"):
		out += " en %s" % str(s["at"].get("cell"))
	if s.has("target"):
		out += " a %s" % String(s["target"].get("id", ""))
	return out


func _shot(name: String, delay: int = 2) -> void:
	if not _shots_dir.is_empty() and not _shot_names.has(name):
		_shot_names[name] = _frame + delay


func _note(text: String) -> void:
	_log.append("[%6.1f s | pared %5.1f s] %s" % [_play_frames / 60.0, (Time.get_ticks_msec() - _wall_start_ms) / 1000.0, text])


func _fail(text: String) -> bool:
	_note("FALLO: " + text)
	if not _shots_dir.is_empty():
		var file: String = _shots_dir.path_join("fallo.png")
		get_viewport().get_texture().get_image().save_png(file)
		_note("captura del fallo: " + file)
	return false
