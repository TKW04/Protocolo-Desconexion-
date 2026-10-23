## Bot del jefe Autoplay (paso 19 de docs/propuesta-mundo-2.md §8, 2026-10-23;
## §7.3). Carga la escena principal (scenes/main.tscn, LevelRunner) en la arena
## 2-boss real y pelea con el Isak real pulsando SOLO acciones del Input Map
## (move_left / move_right, move_down —mantener: golpe al suelo—, jump, run,
## laser, debug, gesture_swipe y ui_accept para cerrar las lineas importantes y
## la recompensa); nunca Q ni pause, nunca teletransporta ni llama a la API de
## dano del jefe. Como el bot de Alerta Mayor (tools/boss_bot.gd) es REACTIVO:
## una politica que cada cuadro lee la API de Autoplay / BossBase / WeakPoint
## (get_phase, is_window_open, is_paused, get_clip, get_playhead_x, get_banners,
## get_bells, get_shots, get_conveyor_cards, get_bar_surface_y...).
##
## Capas del control (en _physics_process, antes que Isak):
## - Reflejos: predice el choque con lo que se mueve (ola del suelo, barrido de la
##   barra, proyectiles de la «Cuenta atras», en 2D) y lo atraviesa con el dash o,
##   sin dash, salta; sale de la columna de cada rayo (aviso u onda) corriendo.
##   Antes de la «Cuenta atras» se aparta al extremo de su superficie (el abanico
##   sale del pie de la pantalla, encima del centro de la barra).
## - Ventana (y la cuenta de la fase 2): en la barra, Debug -> golpe al suelo
##   sobre el cabezal (mantener move_down; en Kernel y Raíz, con adelanto por su
##   velocidad) -> PAUSA -> soltar el Debug -> laser a la pantalla mientras dure.
##   Si la ventana pilla al bot abajo, sube por la cinta (tarjeta util -> barra).
## - Fuera de las ventanas: espera en la barra (la solucion de §5.4: en Kernel y
##   Raíz la subida desde el suelo no cabe en la cuenta de 4 s, decision 2 del
##   paso 17) y, por debajo del umbral de energia y justo despues de una ventana,
##   baja al cargador listo mas cercano de su lado y vuelve a subir por la cinta.
##
## Perfiles (--profile):
## - ideal: pelea limpia (Debug solo hasta la pausa, todos los golpes posibles).
## - clumsy (torpe): validation_model de data/bosses/autoplay.json (el modelo del
##   validador de arenas): golpes por ventana (laps.<n>.windows; 0 = ventana
##   perdida con early_debug_s de Debug de mas: en la fase 2 la cuenta llega a 0
##   y cura), segundos de Debug por ventana (laps.<n>.debug_s) y un laser fallado
##   por ventana (misses_per_window: a la pantalla sin pausa, chispa gris).
## - idle (quieto): no hace nada (solo cierra las lineas): debe perder.
## Accesos (--lap 1|2|3): GameState.lap antes de cargar; Autoplay lee laps.<n>.
##
## Mide: duracion de la pelea (tiempo de juego, desde que empieza hasta el golpe
## final) frente a target_duration_s del nivel y a la estimacion del bot de §4.4
## (~110-140 s), golpes, muertes, energia minima (toda la pelea, en ventana y
## por fase) frente al margen del validador, curas de la cuenta, golpes al suelo,
## pausas, laseres y dashes; al final, la recompensa (boss_w2_l<n> sin guardar) y
## la vuelta al hub con 2-boss completado, el Mundo 3 desbloqueado y, en Caché,
## la pieza ambar encendida. Usa user://bot_save.json (borrado al empezar).
## Lo lanza tools/play_boss_bot.gd -- --boss autoplay (o tools/play_autoplay_bot.gd);
## lo ejecuta tests/test_autoplay_bot.gd.
extends Node

signal finished(code: int)

const MAIN_SCENE: String = "res://scenes/main.tscn"
const BOT_SAVE_PATH: String = "user://bot_save.json"
const BOSS_DATA: String = "res://data/bosses/autoplay.json"
const LEVEL_DATA: String = "res://data/levels/2-boss.json"
const LEVEL_ID: String = "2-boss"
const A_LEFT: StringName = &"move_left"
const A_RIGHT: StringName = &"move_right"
const A_DOWN: StringName = &"move_down"
const A_JUMP: StringName = &"jump"
const A_RUN: StringName = &"run"
const A_LASER: StringName = &"laser"
const A_DEBUG: StringName = &"debug"
const A_DASH: StringName = &"gesture_swipe"
const A_ACCEPT: StringName = &"ui_accept"
const ALL_ACTIONS: Array[StringName] = [A_LEFT, A_RIGHT, A_DOWN, A_JUMP, A_RUN, A_LASER, A_DEBUG, A_DASH]
const ACCESS_NAMES: Dictionary = {1: "Caché", 2: "Kernel", 3: "Raíz"}
## Margen de energia del validador de arenas (tools/validate_boss.py, barra base
## 100, pelea torpe; paso 17): 100 - el peor pico por ventana. Solo informe.
const VALIDATOR_MARGIN: Dictionary = {1: 40.0, 2: 37.5, 3: 35.0}
## Duracion del bot estimada en §4.4 de la propuesta (s de juego).
const BOT_ESTIMATE_S: Vector2 = Vector2(110.0, 140.0)
const MAX_FIGHT_S: float = 600.0
const MAX_IDLE_S: float = 900.0
const MAX_AFTER_S: float = 60.0
## Energia por debajo de la que baja a recargar tras una ventana (ideal / torpe)
## y por debajo de la que recarga siempre (fuera de ventana y de pausa).
const RECHARGE_AFTER_WINDOW: Dictionary = {"ideal": 60.0, "clumsy": 90.0}
const RECHARGE_ALWAYS: float = 30.0
## Recarga hasta aqui (o hasta que el cargador da su energia).
const LINE_READ_FRAMES: int = 10
## Reflejos: horizonte (s reales) del dash y del salto ante un choque.
const DASH_HORIZON_S: float = 0.10
const JUMP_HORIZON_S: float = 0.22
const JUMP_CLEAR_FROM_S: float = 0.06
const JUMP_CLEAR_TO_S: float = 0.68
## Tarjeta util desde el suelo (px sobre el suelo de la superficie de la tarjeta)
## y altura maxima de la tarjeta (y global de su superficie respecto a la barra)
## desde la que se salta a la barra.
const CARD_FROM_FLOOR_PX: Vector2 = Vector2(30.0, 160.0)
const CARD_TO_BAR_PX: float = 168.0
## Con rayos en curso, en el suelo, a esta distancia del muro como minimo (los
## rayos persiguen la columna de Isak: contra el muro no hay salida).
const RAY_WALL_GAP_PX: float = 160.0
## Distancia (px) de los pies al centro del cabezal con la que se golpea.
const POUND_TOL_PX: float = 14.0
## Adelanto (s reales) del golpe al suelo: salto de 32 px, anticipacion y caida.
const POUND_FLIGHT_S: float = 0.2
## Margen (px) a los extremos de la barra al esperar o esquivar en ella.
const BAR_EDGE_PX: float = 30.0

var _profile: String = "ideal"
var _lap: int = 1
var _verbose: bool = false
var _trace: bool = false
var _model: Dictionary = {}
var _boss_cfg: Dictionary = {}
var _target_s: float = 240.0

var _runner: LevelRunner
var _level: Node
var _isak: Isak
var _boss: Autoplay
var _tile: float = 64.0
var _floor_y: float = 640.0
var _bar_y: float = 384.0
## Extremos (x global) de la barra y del carril del suelo.
var _bar: Vector2 = Vector2(320.0, 960.0)
var _floor: Vector2 = Vector2(64.0, 1216.0)
## Columnas de la cinta: [x0, x1] globales de cada lado.
var _columns: Dictionary = {}

# --- Entrada que se aplica al final de cada cuadro ---
var _axis: float = 0.0
var _run: bool = false
var _jump: bool = false
var _down: bool = false
var _debug_hold: bool = false
var _debug_want: bool = false
var _taps: Array[StringName] = []
var _held_taps: Array[StringName] = []
var _debug_tap_cd: int = 0
var _laser_cd: int = 0
var _dash_tap_cd: int = 0

# --- Estado ---
var _frame: int = 0
var _jumping: bool = false
var _jump_frames: int = 0
var _jump_axis: float = 0.0
var _line_key: String = ""
var _line_frame: int = 0
var _hooked: bool = false
var _started: bool = false
var _defeated: bool = false
var _done: bool = false
var _after_frames: int = 0
var _game_over: bool = false
## Ventana actual: indice en la fase, golpes, laser fallado, Debug gastado (s
## reales activos) y si ya se pauso en ella.
var _win_index: int = -1
var _win_hits: int = 0
var _win_missed: int = 0
var _win_debug_s: float = 0.0
var _win_paused: bool = false
var _was_window: bool = false
## Recargando: lado de la cinta (&"left" / &"right") o &"" si no.
var _recharge_side: StringName = &""
var _recharge_from: float = 0.0
## Ultima x del cabezal y su velocidad observada (px por s real).
var _last_playhead_x: float = INF
var _playhead_v: float = 0.0
var _clip_t0: float = -1.0
var _real_t: float = 0.0

# --- Medidas ---
var _fight_frames: int = 0
var _hits: int = 0
var _deaths: int = 0
var _min_energy: float = INF
var _min_energy_window: float = INF
var _min_energy_phase: Dictionary = {}
## Gasto de energia por ventana (energia al abrirse - minima hasta cerrar la
## ventana o su pausa; se suma lo recargado en medio): el mayor por fase, para
## compararlo con el pico de la pelea torpe del validador.
var _win_e0: float = 0.0
var _win_spend: float = 0.0
var _spend_phase: Dictionary = {}
var _debug_cut_in_window: int = 0
var _dashes: int = 0
var _lasers: int = 0
var _pounds: int = 0
var _pauses: int = 0
var _heals: int = 0
var _debug_frames: int = 0
var _charges: int = 0
var _windows: Dictionary = {}
var _phase_frames: Dictionary = {}
var _log: PackedStringArray = []
var _was_debug_active: bool = false
var _last_phase: int = 0
var _last_counter: String = ""


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
	if not _profile in ["ideal", "clumsy", "idle"]:
		_note("perfil desconocido «%s» (ideal, clumsy, idle)" % _profile)
		_finish(false)
		return
	_boss_cfg = JSON.parse_string(FileAccess.get_file_as_string(BOSS_DATA))
	var lv: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(LEVEL_DATA))
	_target_s = float(lv.get("target_duration_s", 240.0))
	_model = _boss_cfg.get("validation_model", {})
	var env_path: String = OS.get_environment(GameState.SAVE_PATH_ENV)
	GameState.use_save_path(BOT_SAVE_PATH if env_path.is_empty() else env_path, true)
	GameState.reset_progress()
	GameSettings.use_path("user://tool_settings.cfg")
	_setup_progress()
	EventBus.player_died.connect(func() -> void: _deaths += 1)
	EventBus.rollback_applied.connect(func(_r: Dictionary) -> void: _game_over = true)
	EventBus.charger_used.connect(func(_id: StringName, _a: float) -> void: _charges += 1)
	EventBus.dash_started.connect(func(_d: float) -> void: _dashes += 1)
	EventBus.laser_fired.connect(func(_p: Node2D) -> void: _lasers += 1)
	EventBus.ground_pound_landed.connect(func(_r: Rect2, _s: Node2D) -> void: _pounds += 1)
	_runner = (load(MAIN_SCENE) as PackedScene).instantiate() as LevelRunner
	_runner.start_level_id = LEVEL_ID
	add_child(_runner)
	_note("perfil %s, acceso %s (vuelta %d)" % [_profile, ACCESS_NAMES[_lap], _lap])


## Progreso de quien acaba de completar el 2-3: Eco, Notas y Calc conocidos, las
## cinco habilidades (con el golpe al suelo), los avisos vistos y el jefe del
## Mundo 2 desbloqueado, en la vuelta pedida.
func _setup_progress() -> void:
	GameState.lap = _lap
	for ally: StringName in [GameState.ALLY_ECO, GameState.ALLY_NOTAS, GameState.ALLY_CALC]:
		GameState.meet_ally(ally)
	for ability: StringName in [GameState.ABILITY_PULSE, GameState.ABILITY_LASER, GameState.ABILITY_DEBUG,
			GameState.ABILITY_DASH, GameState.ABILITY_GROUND_POUND]:
		GameState.obtain_ability(ability)
		GameState.seen_notices[ability] = true
	for id: StringName in [&"1-1", &"1-2", &"1-3", &"1-boss", &"2-1", &"2-2", &"2-3"]:
		GameState.unlock_level(id)
		GameState.mark_level_completed(id)
	GameState.unlock_level(&"2-boss")


# --- Bucle ---

func _physics_process(delta: float) -> void:
	if _done:
		return
	_release_taps()
	_frame += 1
	_refresh()
	if _runner == null:
		return
	_axis = 0.0
	_run = false
	_down = false
	_debug_want = false
	var paused: bool = get_tree().paused
	if is_instance_valid(_level) and _level != null:
		var box := _level.get_node_or_null(^"EcoTextBox") as EcoTextBox
		if box != null:
			_confirm_line(box)
	if _defeated:
		_after_defeat()
		_apply_inputs()
		return
	if _game_over:
		_end_game_over()
		return
	if paused or _isak == null or _boss == null:
		_jump = false
		_debug_want = DebugMode.is_active()
		_apply_inputs()
		return
	_real_t += delta
	if _boss.is_fighting():
		if not _started:
			_started = true
			_note("pelea: empieza (%s)" % _boss.get_counter_label())
		_fight_frames += 1
		_phase_frames[_boss.get_phase()] = int(_phase_frames.get(_boss.get_phase(), 0)) + 1
		_measure(delta)
		if _profile != "idle":
			_fight(delta)
		if _trace and _fight_frames % 30 == 0:
			_trace_line()
		if _fight_frames > int(MAX_FIGHT_S * 60.0) and _profile != "idle":
			_note("FALLO: sin golpe final a los %.0f s (fase %d, %s)" % [MAX_FIGHT_S, _boss.get_phase(),
				_boss.get_counter_label()])
			_finish(false)
			return
		if _profile == "idle" and _fight_frames > int(MAX_IDLE_S * 60.0):
			_note("FALLO: quieto sigue vivo a los %.0f s" % MAX_IDLE_S)
			_finish(false)
			return
	_update_jump()
	_apply_inputs()


func _refresh() -> void:
	if _runner == null or not is_instance_valid(_runner):
		return
	var level: Node = _runner.get_level() if not _runner.is_in_hub() else null
	if level != _level:
		_level = level
		_isak = null
		_boss = null
		_hooked = false
	if _level == null or not is_instance_valid(_level):
		return
	if _isak == null or not is_instance_valid(_isak):
		_isak = _level.get_node_or_null(^"Isak") as Isak
		if _isak != null:
			_isak.hurt.connect(_on_hurt)
	if not _hooked:
		for node: Node in _all_nodes(_level):
			if node is Autoplay:
				_boss = node as Autoplay
				break
		if _boss != null:
			_hook_boss()


func _hook_boss() -> void:
	_hooked = true
	_tile = float(World1ObjectsConfig.tile_size())
	var arena: Dictionary = _boss_cfg.get("arena", {})
	var lanes: Dictionary = arena.get("lanes", {})
	var fl: Dictionary = lanes.get("floor", {})
	var bl: Dictionary = lanes.get("bar", {})
	_floor_y = float(fl.get("surface_row", 10)) * _tile
	_bar_y = _boss.get_bar_surface_y()
	_floor = Vector2(float(fl.get("from_col", 1)) * _tile, float(int(fl.get("to_col", 18)) + 1) * _tile)
	_bar = Vector2(float(bl.get("from_col", 5)) * _tile, float(int(bl.get("to_col", 14)) + 1) * _tile)
	var cols: Array = (arena.get("conveyor", {}) as Dictionary).get("columns", [[1, 3], [16, 18]])
	_columns = {&"left": Vector2(float(cols[0][0]) * _tile, float(int(cols[0][1]) + 1) * _tile),
		&"right": Vector2(float(cols[1][0]) * _tile, float(int(cols[1][1]) + 1) * _tile)}
	_boss.window_opened.connect(_on_window_opened)
	_boss.window_closed.connect(_on_window_closed)
	_boss.phase_changed.connect(_on_phase_changed)
	_boss.phase_restarted.connect(_on_phase_restarted)
	_boss.hit_taken.connect(func(_r: int) -> void:
		_win_hits += 1
		var p: int = _boss.get_phase()
		var w: Dictionary = _windows.get(p, {})
		w["hits"] = int(w.get("hits", 0)) + 1
		_windows[p] = w)
	_boss.pause_changed.connect(func(on: bool) -> void:
		if on:
			_pauses += 1
			_win_paused = true
			if _verbose:
				_note("pausa (fase %d, ventana %s, energia %.0f)" % [_boss.get_phase(), _boss.is_window_open(),
					GameState.debug_energy]))
	_boss.countdown_expired.connect(func(healed: int) -> void:
		_heals += healed
		_note("la cuenta llega a 0: el jefe recupera %d golpe(s) (fase %d, %s)" % [healed, _boss.get_phase(),
			_boss.get_counter_label()]))
	_boss.attack_started.connect(_on_attack)
	_boss.final_blow.connect(_on_final_blow)


func _on_hurt() -> void:
	_hits += 1
	_note("golpe a Isak en la fase %d (clip %s, %s; x %.0f, y %.0f; Sync %.0f)" % [
		_boss.get_phase() if _boss != null else 0, _boss.get_clip() if _boss != null else &"?", _surface(),
		_isak.global_position.x, _isak.global_position.y, GameState.sync_rate])


func _on_window_opened(s: float) -> void:
	_win_index += 1
	_win_hits = 0
	_win_missed = 0
	_win_debug_s = 0.0
	_win_paused = false
	_win_e0 = GameState.debug_energy
	_win_spend = 0.0
	var p: int = _boss.get_phase()
	var w: Dictionary = _windows.get(p, {})
	w["windows"] = int(w.get("windows", 0)) + 1
	_windows[p] = w
	if _verbose:
		_note("ventana %d de la fase %d (%.1f s del mundo; quiere %d golpes; %s, x %.0f; energia %.0f)" % [
			_win_index, p, s, _window_goal(), _surface(), _isak.global_position.x if _isak != null else 0.0,
			GameState.debug_energy])


func _on_window_closed() -> void:
	if _verbose:
		_note("ventana cerrada (%d golpes; Debug %.1f s)" % [_win_hits, _win_debug_s])


func _on_phase_changed(phase: int) -> void:
	_note("fase %d a los %.1f s (%s; energia %.0f)" % [phase, _fight_s(), _boss.get_counter_label(),
		GameState.debug_energy])
	_reset_phase_state()


func _on_phase_restarted(phase: int) -> void:
	_note("reaparece: la fase %d vuelve a empezar (energia %.0f)" % [phase, GameState.debug_energy])
	_reset_phase_state()


func _reset_phase_state() -> void:
	_win_index = -1
	_win_hits = 0
	_win_paused = false
	_recharge_side = &""
	_last_playhead_x = INF


func _on_attack(attack: StringName) -> void:
	_clip_t0 = _real_t
	if _verbose and attack != Autoplay.ATTACK_WINDOW:
		_note("clip %s (fase %d, %.1f s)" % [attack, _boss.get_phase(), _fight_s()])


func _on_final_blow() -> void:
	_defeated = true
	_after_frames = 0
	_debug_hold = false
	_note("golpe final a los %.1f s de pelea" % _fight_s())


# --- Medidas ---

func _measure(delta: float) -> void:
	_last_phase = _boss.get_phase()
	_last_counter = _boss.get_counter_label()
	var e: float = GameState.debug_energy
	_min_energy = minf(_min_energy, e)
	var p: int = _boss.get_phase()
	_min_energy_phase[p] = minf(float(_min_energy_phase.get(p, INF)), e)
	var active: bool = DebugMode.is_active()
	if active:
		_debug_frames += 1
	var in_window: bool = _boss.is_window_open() or (_boss.is_paused() and _win_paused)
	if in_window:
		_min_energy_window = minf(_min_energy_window, e)
		_win_spend = maxf(_win_spend, _win_e0 - e)
		_spend_phase[p] = maxf(float(_spend_phase.get(p, 0.0)), _win_spend)
		if active:
			_win_debug_s += delta
		if _was_debug_active and not active and e <= GameState.DEBUG_ENERGY_MIN + 0.01:
			_debug_cut_in_window += 1
			_note("el Debug se corta sin energia en una ventana (fase %d)" % p)
	_was_debug_active = active
	# Velocidad del cabezal (px por s real), para adelantar el golpe.
	var px: float = _boss.get_playhead_x()
	if _last_playhead_x != INF and delta > 0.0:
		var v: float = (px - _last_playhead_x) / delta
		_playhead_v = v if absf(v) < 400.0 else _playhead_v
	_last_playhead_x = px


func _fight_s() -> float:
	return float(_fight_frames) / 60.0


# --- Politica ---

func _fight(_delta: float) -> void:
	if _isak.is_dead() or _isak.is_warping():
		_debug_hold = false
		_recharge_side = &""
		return
	var window: bool = _boss.is_window_open()
	var paused: bool = _boss.is_paused()
	if window or paused:
		_was_window = true
	elif _was_window:
		_was_window = false
		_after_window()
	if paused:
		_pause_play()
		return
	if _reflexes():
		_debug_want = DebugMode.is_engaged() and window
		return
	if window:
		_window_play()
		return
	_between_windows()


## Golpes que este perfil quiere dar en la ventana actual (ideal: todos).
func _window_goal() -> int:
	if _profile != "clumsy":
		return 99
	var wins: Array = _model_lap().get("windows", [])
	var p: int = _boss.get_phase() - 1
	if p < 0 or p >= wins.size() or _win_index < 0:
		return 99
	var list: Array = wins[p]
	return int(list[_win_index]) if _win_index < list.size() else 99


func _model_lap() -> Dictionary:
	return (_model.get("laps", {}) as Dictionary).get(str(_lap), {})


func _model_phase_value(key: String, fallback: float) -> float:
	var list: Variant = _model.get(key, [])
	var p: int = _boss.get_phase() - 1
	if list is Array and p >= 0 and p < (list as Array).size():
		return float((list as Array)[p])
	return fallback


## Segundos de Debug por ventana del torpe (debug_s de la vuelta y la fase).
func _clumsy_debug_s() -> float:
	var list: Array = _model_lap().get("debug_s", [4.0, 4.0, 4.0])
	return float(list[clampi(_boss.get_phase() - 1, 0, list.size() - 1)])


## Recien cerrada una ventana: decide si baja a recargar.
func _after_window() -> void:
	var limit: float = float(RECHARGE_AFTER_WINDOW.get(_profile, 60.0))
	if GameState.debug_energy < limit:
		_start_recharge()


func _start_recharge() -> void:
	if _recharge_side != &"":
		return
	_recharge_side = &"left" if _isak.global_position.x < (_floor.x + _floor.y) * 0.5 else &"right"
	_recharge_from = GameState.debug_energy
	if _verbose:
		_note("baja a recargar por la %s (energia %.0f)" % ["izquierda" if _recharge_side == &"left" else "derecha",
			GameState.debug_energy])


## Ventana abierta (sin pausa): en la barra, Debug -> golpe al suelo sobre el
## cabezal. Torpe: un laser fallado antes y, si la ventana es de 0 golpes,
## early_debug_s de Debug y nada mas.
func _window_play() -> void:
	_recharge_side = &""
	var goal: int = _window_goal()
	if goal == 0:
		# Ventana perdida (torpe): Debug un rato sin golpear.
		_want_debug(_win_debug_s < _model_phase_value("early_debug_s", 2.0))
		if _surface() != &"bar":
			_go_bar(_wait_x())
		return
	if _isak.is_ground_pounding():
		# El saltito del golpe deja a Isak en el aire: el Debug sigue hasta que cae.
		_want_debug(true)
		_axis = 0.0
		return
	if _surface() != &"bar":
		# Subiendo con la ventana abierta: el Debug se carga ya en la tarjeta o en
		# el salto a la barra (no hay clips en la ventana: el dash no hace falta).
		_want_debug(_surface() == &"card" or (_surface() == &"air" and _jump_axis != 0.0))
		_go_bar(_boss.get_playhead_x())
		return
	if _profile == "clumsy" and _win_missed < int(_model.get("misses_per_window", 1)) and not DebugMode.is_engaged():
		_face_x(_screen_center_x())
		if _try_laser():
			_win_missed += 1
		return
	_want_debug(true)
	_pound_on_playhead()


## Va al cabezal (con adelanto) y, con el Debug activo y en su caja, mantiene
## move_down hasta que sale el golpe.
func _pound_on_playhead() -> void:
	if _isak.is_ground_pounding():
		_axis = 0.0
		return
	var lead: float = POUND_FLIGHT_S
	var charge_left: float = maxf(_isak.abilities.pound_ground_hold_s - _isak.get_ground_pound_charge_s(), 0.0)
	lead += charge_left
	var target: float = clampf(_boss.get_playhead_x() + _playhead_v * lead, _bar.x + 18.0, _bar.y - 18.0)
	var dx: float = target - _isak.global_position.x
	var near: bool = absf(dx) <= POUND_TOL_PX
	if not near:
		_axis = _approach_axis(dx)
		_run = absf(dx) > 120.0
	else:
		_axis = 0.0 if absf(_playhead_v) < 1.0 else signf(_playhead_v) * minf(absf(_playhead_v) / 220.0, 1.0)
	# Mantener solo con el Debug activo (si no, el golpe solo saca chispa gris) y
	# con el enfriamiento del golpe acabado (hay que soltar entre golpes).
	if DebugMode.is_active() and absf(dx) <= POUND_TOL_PX * 2.0 and _isak.is_on_floor() \
			and _isak.get_ground_pound_cooldown_left() <= 0.0:
		_down = true


## En pausa: soltar el Debug (ideal) o mantenerlo hasta debug_s (torpe) y laser
## a la pantalla hasta los golpes de la ventana.
func _pause_play() -> void:
	_axis = 0.0
	var goal: int = _window_goal()
	if _profile == "clumsy":
		_want_debug(_win_debug_s < _clumsy_debug_s())
	else:
		_debug_off()
	if _win_hits >= goal or _isak.is_ground_pounding():
		return
	_face_x(_screen_center_x())
	_try_laser()


## Fuera de ventana y de pausa: recarga si toca; si no, a la barra a esperar.
func _between_windows() -> void:
	_debug_off()
	if GameState.debug_energy < RECHARGE_ALWAYS:
		_start_recharge()
	if _recharge_side != &"":
		_recharge()
		return
	if _surface() != &"bar":
		_go_bar(_wait_x())
		return
	_walk_to(_wait_x(), 10.0)


## Donde espera en la barra: ante la «Cuenta atras» en el extremo mas cercano
## (el abanico sale del pie de la pantalla); si no, en el slot de la proxima
## ventana (fase 1: el centro) o en el centro.
func _wait_x() -> float:
	var ix: float = _isak.global_position.x
	if _boss.get_clip() == Autoplay.CLIP_COUNTDOWN and _boss.get_shots().is_empty():
		return _bar.x + BAR_EDGE_PX if ix < _screen_center_x() else _bar.y - BAR_EDGE_PX
	if _boss.get_phase() == 1:
		return _boss.get_slot_x("center")
	return _boss.get_slot_x("center") + (-1.0 if ix < _screen_center_x() else 1.0) * _tile * 1.5


## Baja al cargador listo mas cercano de su lado, recarga y vuelve a la barra.
func _recharge() -> void:
	if GameState.debug_energy >= minf(_recharge_from + 45.0, GameState.get_debug_energy_max() - 5.0):
		if _verbose:
			_note("recargado (energia %.0f): vuelve a la barra" % GameState.debug_energy)
		_recharge_side = &""
		_go_bar(_wait_x())
		return
	var best: Charger = null
	for side_first: bool in [true, false]:
		for node: Node in _all_nodes(_level):
			var c := node as Charger
			if c == null or not c.is_ready():
				continue
			var cx: float = c.global_position.x + _tile * 0.5
			var mine: bool = (cx < (_floor.x + _floor.y) * 0.5) == (_recharge_side == &"left")
			if side_first and not mine:
				continue
			if best == null or absf(cx - _isak.global_position.x) < absf(best.global_position.x + _tile * 0.5 - _isak.global_position.x):
				best = c
		if best != null:
			break
	if best == null:
		# Ninguno listo: espera en la barra.
		_recharge_side = &""
		return
	_go_floor(best.global_position.x + _tile * 0.5)


# --- Reflejos ---

## Esquiva lo que va a golpear ya. Verdadero si este cuadro esquiva.
func _reflexes() -> bool:
	if _isak.is_dashing():
		_axis = 0.0
		return true
	var body: Rect2 = LevelLookup.isak_body_rect(_isak)
	var scale: float = maxf(WorldTime.scale(), 0.05)
	# 1) Lo que se mueve: ola, barrido y proyectiles (en 2D).
	for h: Dictionary in _moving_hazards():
		var rect: Rect2 = h["rect"]
		var v: Vector2 = h["v"]
		var t_world: float = _time_to_hit(rect, v, body.grow(4.0))
		if t_world < 0.0 or t_world > 1.0:
			continue
		var t: float = t_world / scale
		var toward: float = signf(-v.x) if absf(v.x) > 60.0 else _roomy_dir()
		if _dash_ready():
			if t <= DASH_HORIZON_S and _try_dash(toward):
				return true
			continue
		if _dash_soon(t):
			_axis = 0.0
			continue
		var cross: float = (rect.size.x + body.size.x + 8.0) / maxf(absf(v.x) * scale, 1.0)
		var latest: float = minf(JUMP_HORIZON_S, JUMP_CLEAR_TO_S - cross)
		if t <= latest and t >= JUMP_CLEAR_FROM_S and _isak.is_on_floor() and not _jumping \
				and _isak.global_position.y - rect.position.y < 96.0:
			_start_jump(0.0)
			return true
	# 2) Ola o barrido que avisa en su entrada: si Isak esta encima de donde
	# aparecera, se aparta corriendo (aparecer encima no deja atravesarlo).
	for banner: Variant in _boss.get_banners().values():
		var sb := banner as SpamBanner
		if sb == null or not is_instance_valid(sb) or not sb.is_warning():
			continue
		var r: Rect2 = sb.get_damage_rect()
		if r.end.y < body.position.y or r.position.y > body.end.y:
			continue
		var zone: Rect2 = r.grow_individual(72.0, 0.0, 72.0, 0.0)
		if zone.intersects(body):
			var away: float = signf(body.get_center().x - r.get_center().x)
			if away == 0.0:
				away = float(sb.direction)
			_axis = away
			_run = true
			return true
	# 3) Rayos: fuera de la columna (aviso u onda) corriendo.
	var x: float = _isak.global_position.x
	if _in_ray_band(x, false):
		var out: float = _ray_escape_x(x)
		if absf(out - x) > 1.0:
			_axis = signf(out - x)
			_run = true
			return true
	return false


## Ola, barrido y proyectiles en movimiento: {rect, v} (px, px/s del mundo).
func _moving_hazards() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for banner: Variant in _boss.get_banners().values():
		var sb := banner as SpamBanner
		if sb != null and is_instance_valid(sb) and sb.is_sweeping():
			out.append({"rect": sb.get_damage_rect(), "v": Vector2(float(sb.direction) * sb.sweep_speed_px_s, 0.0)})
	for shot: NotificationShot in _boss.get_shots():
		out.append({"rect": shot.get_damage_rect(), "v": shot.heading.normalized() * shot.speed_px_s})
	return out


## Segundos del mundo hasta que `rect` (moviendose a `v`) toque `body`; -1 si no
## (barrido de cajas por ejes).
func _time_to_hit(rect: Rect2, v: Vector2, body: Rect2) -> float:
	var t_in: float = -INF
	var t_out: float = INF
	for axis: int in 2:
		var r0: float = rect.position[axis]
		var r1: float = rect.end[axis]
		var b0: float = body.position[axis]
		var b1: float = body.end[axis]
		var va: float = v[axis]
		if absf(va) < 0.001:
			if r1 <= b0 or r0 >= b1:
				return -1.0
			continue
		var a: float = (b0 - r1) / va
		var b: float = (b1 - r0) / va
		t_in = maxf(t_in, minf(a, b))
		t_out = minf(t_out, maxf(a, b))
	if t_in > t_out or t_out < 0.0:
		return -1.0
	return maxf(t_in, 0.0)


## Hacia donde hay mas sitio en la superficie de Isak.
func _roomy_dir() -> float:
	var r: Vector2 = _surface_range()
	var x: float = _isak.global_position.x
	return 1.0 if r.y - x > x - r.x else -1.0


func _ray_band(bell: AlarmBell) -> Vector2:
	var r: Rect2 = bell.get_wave_rect()
	var half: float = _isak.hitbox_size.x * 0.5 + 8.0
	return Vector2(r.position.x - half, r.end.x + half)


func _in_ray_band(x: float, wave_only: bool) -> bool:
	for bell: AlarmBell in _boss.get_bells():
		if not (bell.is_wave() or (not wave_only and bell.is_warning())):
			continue
		var band: Vector2 = _ray_band(bell)
		if x > band.x and x < band.y:
			return true
	return false


## x libre de rayos mas cercana en la superficie de Isak (sin cruzar una franja
## que avisa o suena); si no hay, la mas cercana cruzando solo las que avisan;
## en la barra vale bajarse por un extremo.
func _ray_escape_x(x: float) -> float:
	var r: Vector2 = _surface_range()
	if _surface() == &"bar" or _surface() == &"card":
		# Vale bajarse por un extremo (la tarjeta sube: quedarse en su columna no
		# siempre cabe).
		r = Vector2(r.x - 100.0, r.y + 100.0)
	r = Vector2(maxf(r.x, _floor.x + 20.0), minf(r.y, _floor.y - 20.0))
	# En el suelo, mejor no huir hacia el muro (el rayo siguiente cae en la
	# columna nueva y contra el muro no queda salida), pero antes eso que cruzar
	# una franja que avisa.
	var ranges: Array[Vector2] = [r]
	if _surface() == &"floor":
		ranges.push_front(Vector2(maxf(r.x, _floor.x + RAY_WALL_GAP_PX), minf(r.y, _floor.y - RAY_WALL_GAP_PX)))
	for strict: bool in [true, false]:
		for range_x: Vector2 in ranges:
			var best: float = _ray_escape_in(x, range_x, strict)
			if best != INF:
				return best
	return x


func _ray_escape_in(x: float, r: Vector2, strict: bool) -> float:
	var best: float = INF
	var c: float = r.x
	while c <= r.y:
		if not _in_ray_band(c, false) and absf(c - x) < absf(best - x):
			var blocked: bool = false
			var step: float = 8.0 * signf(c - x)
			var p: float = x + step
			while absf(p - x) < absf(c - x):
				if _band_ahead(x, p, strict):
					blocked = true
					break
				p += step
			if not blocked:
				best = c
		c += 8.0
	return best


## Cruzar `p` desde `x` entra en una franja que no es la de Isak (estricto: que
## avisa o suena; si no, que suena).
func _band_ahead(x: float, p: float, strict: bool) -> bool:
	for bell: AlarmBell in _boss.get_bells():
		if not (bell.is_wave() or (strict and bell.is_warning())):
			continue
		var band: Vector2 = _ray_band(bell)
		var inside_now: bool = x > band.x and x < band.y
		if not inside_now and p > band.x and p < band.y:
			return true
	return false


# --- Movimiento ---

## floor, bar, card o air.
func _surface() -> StringName:
	if _isak == null or not _isak.is_on_floor():
		return &"air"
	var feet: Vector2 = _isak.global_position
	if absf(feet.y - _floor_y) < 10.0:
		return &"floor"
	if absf(feet.y - _bar_y) < 10.0 and feet.x > _bar.x - 20.0 and feet.x < _bar.y + 20.0:
		return &"bar"
	return &"card"


## Extremos (x) de la superficie de Isak.
func _surface_range() -> Vector2:
	match _surface():
		&"bar":
			return Vector2(_bar.x + 18.0, _bar.y - 18.0)
		&"card":
			var side: StringName = _column_of(_isak.global_position.x)
			var col: Vector2 = _columns.get(side, Vector2(_isak.global_position.x - 64.0, _isak.global_position.x + 64.0))
			return Vector2(col.x + 18.0, col.y - 18.0)
	return Vector2(_floor.x + 18.0, _floor.y - 18.0)


func _column_of(x: float) -> StringName:
	return &"left" if x < (_floor.x + _floor.y) * 0.5 else &"right"


## Tarjetas de la cinta de un lado: [{surface_y, x0, x1, solid}].
func _cards(side: StringName) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var col: Vector2 = _columns[side]
	for card: MovingPlatform in _boss.get_conveyor_cards():
		var center: Vector2 = card.get_parent().to_global(card.get_origin() + card.get_offset()) \
			if card.get_parent() is Node2D else card.get_origin() + card.get_offset()
		if center.x < col.x or center.x > col.y:
			continue
		out.append({"surface_y": center.y - card.size.y * 0.5, "solid": card.is_colliding_enabled()})
	return out


## Sube a la barra (por la cinta del lado mas cercano) y va a `x` en ella.
func _go_bar(x: float) -> void:
	var s: StringName = _surface()
	var ix: float = _isak.global_position.x
	if s == &"bar":
		_walk_to(x, 10.0)
		return
	if s == &"air":
		if _jump_axis == 0.0 and _isak.global_position.y > _bar_y + 4.0:
			# Saltando del suelo a una tarjeta: encima de su columna.
			var c: Vector2 = _columns[_column_of(ix)]
			_axis = _approach_axis((c.x + c.y) * 0.5 - ix)
			return
		# Saltando hacia la barra: hacia dentro hasta estar sobre ella.
		var target: float = clampf(x, _bar.x + 60.0, _bar.y - 60.0)
		_axis = _jump_axis if _jump_axis != 0.0 and (ix < _bar.x + 40.0 or ix > _bar.y - 40.0) \
			else _approach_axis(target - ix)
		_run = true
		return
	var side: StringName = _column_of(ix)
	var col: Vector2 = _columns[side]
	if s == &"card":
		var inner: float = col.y - 22.0 if side == &"left" else col.x + 22.0
		var dir: float = 1.0 if side == &"left" else -1.0
		var card_y: float = _isak.global_position.y
		if card_y <= _bar_y + CARD_TO_BAR_PX:
			_axis = dir
			_run = true
			if dir * (ix - inner) >= -40.0:
				_start_jump(dir)
			return
		_walk_to(inner, 6.0)
		return
	# En el suelo: bajo el centro de la columna, salta cuando pasa una tarjeta util.
	var under: float = (col.x + col.y) * 0.5
	if absf(ix - under) > 24.0:
		_walk_to(under, 0.0, absf(ix - under) > 100.0)
		return
	_axis = 0.0
	# Con los rayos en curso no se sube: caen en la columna de Isak y en la
	# tarjeta (o contra el muro) no hay sitio para apartarse; se espera en el
	# suelo, lejos del muro.
	if _boss.get_clip() == Autoplay.CLIP_RAYS or _boss.get_bells().any(func(b: AlarmBell) -> bool: return b.is_busy()):
		_walk_to(clampf(ix, _floor.x + RAY_WALL_GAP_PX, _floor.y - RAY_WALL_GAP_PX), 12.0)
		return
	for card: Dictionary in _cards(side):
		var h: float = _floor_y - float(card["surface_y"])
		if bool(card["solid"]) and h >= CARD_FROM_FLOOR_PX.x and h <= CARD_FROM_FLOOR_PX.y:
			_start_jump(0.0)
			return


## Baja al suelo y va a `x` (por el extremo de la barra o de la tarjeta).
func _go_floor(x: float) -> void:
	var s: StringName = _surface()
	var ix: float = _isak.global_position.x
	if s == &"floor":
		_walk_to(x, 8.0)
		return
	if s == &"air":
		_axis = _approach_axis(x - ix) if _isak.global_position.y > _bar_y + 40.0 else signf(_isak.velocity.x)
		return
	var r: Vector2 = _bar if s == &"bar" else _columns.get(_column_of(ix), Vector2(ix - 64.0, ix + 64.0))
	if x < r.x - 8.0 or x > r.y + 8.0:
		_walk_to(x, 0.0, true)
	else:
		var edge: float = r.x - 40.0 if ix - r.x < r.y - ix else r.y + 40.0
		_walk_to(edge, 0.0, true)


func _walk_to(x: float, tol: float, force_run: bool = false) -> bool:
	var dx: float = x - _isak.global_position.x
	# No entrar en la columna de un rayo que avisa o suena.
	if _band_ahead(_isak.global_position.x, _isak.global_position.x + signf(dx) * 28.0, true):
		_axis = 0.0
		return false
	if absf(dx) <= maxf(tol, 2.0):
		_axis = 0.0
		return absf(_isak.velocity.x) < 30.0 and _isak.is_on_floor()
	_axis = _approach_axis(dx)
	_run = force_run or absf(dx) > 140.0
	return false


func _approach_axis(dx: float) -> float:
	if absf(dx) < 3.0:
		return 0.0
	if absf(dx) < 24.0:
		return signf(dx) * 0.35
	return signf(dx)


func _start_jump(dir: float) -> void:
	if _jumping or not _isak.is_on_floor():
		return
	_jumping = true
	_jump_frames = 0
	_jump = true
	_jump_axis = dir


func _update_jump() -> void:
	if not _jumping:
		_jump = false
		if _isak != null and _isak.is_on_floor():
			_jump_axis = 0.0
		return
	_jump_frames += 1
	_jump = _jump_frames < 26 and (_jump_frames < 3 or _isak.velocity.y < 0.0)
	if _jump_frames > 4 and _isak.is_on_floor():
		_jumping = false
		_jump = false
		_jump_axis = 0.0
	if _jump_frames > 120:
		_jumping = false
		_jump = false
		_jump_axis = 0.0


func _screen_center_x() -> float:
	return _boss.get_screen_rect().get_center().x


func _face_x(x: float) -> void:
	var want: float = signf(x - _isak.global_position.x)
	if want != 0.0 and want != _isak.facing and _axis == 0.0:
		_axis = want * 0.2


# --- Acciones ---

func _try_laser() -> bool:
	if _laser_cd > 0 or not _isak.can_start_laser() or _isak.get_laser_cooldown_left() > 0.0 \
			or _isak.is_laser_posing() or GameState.debug_energy < 10.0:
		return false
	var want: float = signf(_screen_center_x() - _isak.global_position.x)
	if want != 0.0 and want != _isak.facing:
		return false
	_tap(A_LASER)
	_laser_cd = 6
	return true


func _dash_ready() -> bool:
	if _isak.is_dashing() or _isak.get_dash_cooldown_left() > 0.0 or DebugMode.is_engaged() \
			or GameState.debug_energy < 10.0 or _isak.is_laser_posing() or _isak.is_dead() \
			or _isak.is_ground_pounding():
		return false
	return _isak.is_on_floor() or _isak.get_air_dashes_left() > 0


func _dash_soon(t: float) -> bool:
	if _isak.is_dashing() or DebugMode.is_engaged() or GameState.debug_energy < 10.0:
		return false
	return _isak.get_dash_cooldown_left() < t - DASH_HORIZON_S * 0.5


func _try_dash(dir: float) -> bool:
	if dir == 0.0 or not _dash_ready():
		return false
	_axis = dir
	if _dash_tap_cd > 0:
		return true
	_tap(A_DASH)
	_dash_tap_cd = 4
	return true


func _want_debug(on: bool) -> void:
	_debug_want = on


func _debug_off() -> void:
	_want_debug(false)


func _resolve_debug() -> void:
	if _debug_want:
		_debug_hold = not DebugMode.is_active() and (DebugMode.can_enter() or DebugMode.is_engaged())
		return
	_debug_hold = false
	if DebugMode.is_active() and _debug_tap_cd <= 0:
		_tap(A_DEBUG)
		_debug_tap_cd = 12


# --- Entrada ---

func _tap(action: StringName) -> void:
	if not _taps.has(action):
		_taps.append(action)


func _release_taps() -> void:
	for action: StringName in _held_taps:
		Input.action_release(action)
	_held_taps.clear()
	_laser_cd = maxi(_laser_cd - 1, 0)
	_dash_tap_cd = maxi(_dash_tap_cd - 1, 0)
	_debug_tap_cd = maxi(_debug_tap_cd - 1, 0)


func _apply_inputs() -> void:
	_resolve_debug()
	if _axis > 0.001:
		Input.action_release(A_LEFT)
		Input.action_press(A_RIGHT, minf(_axis, 1.0))
	elif _axis < -0.001:
		Input.action_release(A_RIGHT)
		Input.action_press(A_LEFT, minf(-_axis, 1.0))
	else:
		Input.action_release(A_LEFT)
		Input.action_release(A_RIGHT)
	_hold(A_RUN, _run)
	_hold(A_JUMP, _jump)
	_hold(A_DOWN, _down)
	if not _taps.has(A_DEBUG):
		_hold(A_DEBUG, _debug_hold)
	for action: StringName in _taps:
		Input.action_press(action)
		_held_taps.append(action)
	_taps.clear()


func _hold(action: StringName, on: bool) -> void:
	if on:
		Input.action_press(action)
	else:
		Input.action_release(action)


func _release_all() -> void:
	for action: StringName in ALL_ACTIONS:
		Input.action_release(action)


## Linea importante en pantalla: la lee unos cuadros y pulsa aceptar.
func _confirm_line(box: EcoTextBox) -> void:
	if not box.is_showing() or not box.is_important():
		_line_key = ""
		return
	var key: String = box.get_speaker_text() + "|" + box.get_text()
	if key != _line_key:
		_line_key = key
		_line_frame = _frame
		if _verbose:
			_note("linea importante (%s): «%s» -> aceptar" % [box.get_speaker_text(), box.get_text()])
		return
	if (_frame - _line_frame) % LINE_READ_FRAMES == LINE_READ_FRAMES - 1:
		_accept()


func _accept() -> void:
	for pressed: bool in [true, false]:
		var event := InputEventAction.new()
		event.action = A_ACCEPT
		event.pressed = pressed
		Input.parse_input_event(event)


# --- Despues del golpe final ---

func _after_defeat() -> void:
	_after_frames += 1
	_jump = false
	_axis = 0.0
	if _boss != null and is_instance_valid(_boss):
		var defeat: BossDefeat = _boss.get_defeat()
		if defeat != null:
			var reward: BossReward = defeat.get_reward()
			if reward != null and reward.can_close() and _after_frames % LINE_READ_FRAMES == 0:
				_accept()
	if _runner.is_in_hub():
		var hub: HubRoom = _runner.get_hub()
		if hub != null and hub.has_arrived() and not hub.is_piece_pending() and not hub.is_piece_lighting():
			_finish(_check_victory(hub))
			return
	if _after_frames > int(MAX_AFTER_S * 60.0):
		_note("FALLO: sin volver al hub %.0f s despues del golpe final" % MAX_AFTER_S)
		_finish(false)


func _check_victory(hub: HubRoom) -> bool:
	var layer: StringName = StringName("boss_w2_l%d" % _lap)
	var ok: bool = true
	var checks: Array = [
		["2-boss completado", GameState.is_level_completed(&"2-boss")],
		["recuerdo %s sin guardar" % layer, GameState.has_memory(layer) and GameState.has_unsaved_changes()],
		["Mundo 3 desbloqueado", HubWorlds.is_world_unlocked(HubWorlds.world(&"m3"))],
		["Mundo 3 Próximamente", HubWorlds.levels_for_lap(HubWorlds.world(&"m3")).is_empty()],
	]
	# La pieza ambar depende de la carpeta del acceso actual: solo Caché tiene hoy
	# la fila del jefe (los subniveles de Kernel y Raíz aun no existen).
	if _lap == 1:
		checks.append(["pieza ambar encendida", hub.get_piece_animation(2) == &"on"])
	var parts: PackedStringArray = []
	for c: Array in checks:
		parts.append("%s %s" % [c[0], "si" if c[1] else "NO"])
		ok = ok and bool(c[1])
	_note("hub tras la pelea: " + ", ".join(parts))
	if _deaths > 0 and _profile != "idle":
		_note("FALLO: el perfil %s muere %d veces" % [_profile, _deaths])
		ok = false
	if _profile == "clumsy" and _debug_cut_in_window > 0:
		_note("FALLO: el torpe se queda sin energia en una ventana %d veces" % _debug_cut_in_window)
		ok = false
	if _min_energy_window <= 0.0:
		_note("FALLO: energia 0 dentro de una ventana")
		ok = false
	return ok


func _end_game_over() -> void:
	_release_all()
	if _profile == "idle":
		_note("game over a los %.1f s de pelea (fase %d, %s; %d golpes, %d muertes): quieto pierde" % [_fight_s(),
			_last_phase, _last_counter, _hits, _deaths])
		_finish(not _defeated)
		return
	_note("FALLO: game over (fase %d, %s)" % [_last_phase, _last_counter])
	_finish(false)


# --- Informe ---

func _finish(ok: bool) -> void:
	if _done:
		return
	_done = true
	_release_all()
	var label: String = "play_boss_bot autoplay (%s, %s)" % [ACCESS_NAMES.get(_lap, "?"), _profile]
	print("%s: %s" % [label, "OK" if ok else "FALLO"])
	for line: String in _log:
		print("  " + line)
	if _started:
		var phases: PackedStringArray = []
		for p: int in [1, 2, 3]:
			var w: Dictionary = _windows.get(p, {})
			phases.append("F%d %.1f s, %d ventanas, %d golpes, energia min %.0f, gasto max por ventana %.0f" % [p,
				float(_phase_frames.get(p, 0)) / 60.0, int(w.get("windows", 0)), int(w.get("hits", 0)),
				float(_min_energy_phase.get(p, INF)) if _min_energy_phase.has(p) else -1.0,
				float(_spend_phase.get(p, 0.0))])
		var in_range: String = "dentro" if _fight_s() >= BOT_ESTIMATE_S.x and _fight_s() <= BOT_ESTIMATE_S.y \
			else "fuera"
		print("  RESULTADO: pelea %.1f s (objetivo %.0f s; estimacion del bot %.0f-%.0f s: %s), golpes %d, muertes %d, energia minima %.0f (en ventana %.0f; margen del validador %.1f), Debug cortado en ventana %d, curas de la cuenta %d" % [
			_fight_s(), _target_s, BOT_ESTIMATE_S.x, BOT_ESTIMATE_S.y, in_range, _hits, _deaths,
			_min_energy if _min_energy != INF else -1.0, _min_energy_window if _min_energy_window != INF else -1.0,
			VALIDATOR_MARGIN.get(_lap, 0.0), _debug_cut_in_window, _heals])
		print("  ACCIONES: golpes al suelo %d, pausas %d, laseres %d, dashes %d, Debug %.1f s, cargas %d" % [
			_pounds, _pauses, _lasers, _dashes, float(_debug_frames) / 60.0, _charges])
		print("  FASES: " + "; ".join(phases))
	finished.emit(0 if ok else 1)


func _note(text: String) -> void:
	_log.append(text)
	if _verbose:
		print("[autoplay_bot %.1f] %s" % [_fight_s(), text])


func _trace_line() -> void:
	print("[trace %.1f] isak (%.0f,%.0f) %s %s v(%.0f,%.0f) e%.0f axis %.2f jump %s down %s dbg %s/%s | jefe fase %d clip %s ventana %s %.1f pausa %s cabezal %.0f (v %.0f) | recarga %s" % [
		_fight_s(), _isak.global_position.x, _isak.global_position.y, _surface(), _isak.get_state_name(),
		_isak.velocity.x, _isak.velocity.y, GameState.debug_energy, _axis, _jump, _down, DebugMode.is_active(),
		DebugMode.get_state(), _boss.get_phase(), _boss.get_clip(), _boss.is_window_open(),
		_boss.get_window_time_left(), _boss.is_paused(), _boss.get_playhead_x(), _playhead_v, _recharge_side])


func _all_nodes(root: Node) -> Array[Node]:
	var out: Array[Node] = []
	if root == null or not is_instance_valid(root):
		return out
	var stack: Array[Node] = [root]
	while not stack.is_empty():
		var node: Node = stack.pop_back()
		out.append(node)
		for child: Node in node.get_children():
			stack.append(child)
	return out
