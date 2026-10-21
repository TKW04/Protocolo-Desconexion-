## Bot del jefe Alerta Mayor (paso 14 de docs/propuesta-jefe-alerta-mayor.md §6,
## 2026-10-21; §4.2). Carga la escena principal (scenes/main.tscn, LevelRunner)
## en la arena 1-boss real y pelea con el Isak real pulsando SOLO acciones del
## Input Map (move_left / move_right, jump, run, pulse, laser, debug,
## gesture_swipe y ui_accept para cerrar las lineas importantes y la
## recompensa); nunca Q ni pause, nunca teletransporta ni llama a la API de
## dano del jefe. Una pelea no es un camino: el bot es REACTIVO, una politica
## por fase que cada cuadro lee la API de AlertMajor / BossBase / WeakPoint
## (get_phase, get_move, get_round_state, get_bubbles, get_shield, get_shots,
## get_core, get_core_target, is_window_open...), como el bot del 1-3 lee
## get_beat_phase().
##
## Capas del control (en _physics_process, antes que Isak: process_physics_priority):
## - Reflejos: predice el choque con lo que se mueve (barridos, notificaciones de
##   la rafaga, lanzamientos de las copias, Burbujas que patrullan) y lo esquiva
##   con el dash (a traves) o, si no puede (enfriamiento, sin energia, Debug
##   activo), con un salto; se aparta de las columnas de las campanas antes de
##   su onda.
## - Politica por fase: fase 1, aturdir con el pulso desde el suelo, rematar una
##   Burbuja con dos laseres desde su plataforma (perfil ideal) y mantener
##   aturdida la otra hasta que el jefe baja; fase 2, subir a la plataforma del
##   escudo, pulso al boton; fase 3, esquivar en los cargadores del suelo y, en
##   la ventana, ir a la real. En cada ventana: Debug -> pulso (marca) -> soltar
##   el Debug -> laser mientras dure la marca (WeakPoint.get_mark_time_left()),
##   volviendo a marcar si caduca con la ventana abierta.
## - Energia: por debajo de RECHARGE_BELOW (40) y sin ventana, al cargador
##   listo mas cercano.
##
## Perfiles (--profile):
## - ideal: pelea limpia (lo de arriba, Debug solo para marcar).
## - clumsy (torpe): sigue validation_model de data/bosses/alert_major.json
##   (el modelo de la pelea torpe del validador de arenas): por fase y ventana,
##   los golpes que da (laps.<n>.windows: 0 = ventana perdida), los segundos de
##   Debug por ventana (debug_s, mas extra_debug_s y early_debug_s), un laser
##   fallado por ventana (misses_per_window: dispara al cuerpo sin marca) y las
##   Burbujas rematadas (bubble_kills; en la fase 3, la copia equivocada).
## - idle (quieto): no hace nada (solo cierra las lineas): negativo, debe perder.
##
## Accesos (--lap 1|2|3: Caché / Kernel / Raíz): fija GameState.lap antes de
## cargar la arena; el jefe toma laps.<n> de su JSON (golpes 4/4/4, marca 3 /
## 2,5 s, cargadores 5 / 6 s, 3 pop-ups, compas 1,6 / 1,4 s y 4 copias en Raíz).
## Lo propio de Kernel y Raíz que aun no existe (nucleo detras, cambio de copia
## con el Debug) no se prueba.
##
## Mide y comprueba: duracion de la pelea (tiempo de juego real, sin pausas,
## desde boss_started hasta el golpe final) frente a target_duration_s del
## nivel, golpes recibidos, muertes (vidas perdidas), energia minima (de toda la
## pelea y dentro de las ventanas, por fase) y que el Debug no se corte por
## falta de energia en una ventana; al final, la recompensa (capa
## boss_w1_l<n> sin guardar), la vuelta al hub con 1-boss completado y el
## Mundo 2 desbloqueado. Ideal: vence sin morir. Torpe: vence sin quedarse sin
## energia en una ventana. Quieto: game over sin vencer.
## Usa su propio guardado (user://bot_save.json, borrado al empezar).
## Lo lanza tools/play_boss_bot.gd (uso alli); lo ejecuta tests/test_boss_bot.gd.
extends Node

signal finished(code: int)

const MAIN_SCENE: String = "res://scenes/main.tscn"
const BOT_SAVE_PATH: String = "user://bot_save.json"
const BOSS_DATA: String = "res://data/bosses/alert_major.json"
const LEVEL_DATA: String = "res://data/levels/1-boss.json"
const LEVEL_ID: String = "1-boss"
const A_LEFT: StringName = &"move_left"
const A_RIGHT: StringName = &"move_right"
const A_JUMP: StringName = &"jump"
const A_RUN: StringName = &"run"
const A_PULSE: StringName = &"pulse"
const A_LASER: StringName = &"laser"
const A_DEBUG: StringName = &"debug"
const A_DASH: StringName = &"gesture_swipe"
const A_ACCEPT: StringName = &"ui_accept"
const ALL_ACTIONS: Array[StringName] = [A_LEFT, A_RIGHT, A_JUMP, A_RUN, A_PULSE, A_LASER, A_DEBUG, A_DASH]
const ACCESS_NAMES: Dictionary = {1: "Caché", 2: "Kernel", 3: "Raíz"}
## Margen de energia del validador de arenas (tools/validate_boss.py, barra base
## 100, pelea torpe): 100 - pico por ventana. Solo para el informe.
const VALIDATOR_MARGIN: Dictionary = {1: 32.5, 2: 22.5, 3: 20.0}
## Tope de la pelea (s de juego) y de lo que queda tras el golpe final.
const MAX_FIGHT_S: float = 600.0
const MAX_IDLE_S: float = 900.0
const MAX_AFTER_S: float = 60.0
## Energia por debajo de la que va a recargar (sin ventana abierta).
const RECHARGE_BELOW: float = 40.0
## Cuadros que una linea importante esta en pantalla antes de pulsar aceptar.
const LINE_READ_FRAMES: int = 10
## Radio del pulso (px; data/isak_abilities.json) y margen al apuntar.
const PULSE_RADIUS: float = 96.0
const REACH_MARGIN: float = 8.0
## Distancia horizontal al nucleo desde la que se marca y se dispara.
const STAND_DX: float = 96.0
## Reflejos: horizonte (s del mundo) del dash y del salto ante un choque.
const DASH_HORIZON_S: float = 0.10
const JUMP_HORIZON_S: float = 0.22
## Un salto deja los pies por encima de un peligro a ras de suelo (barrido,
## notificacion) entre estos segundos reales tras despegar (salto de 192 px).
const JUMP_CLEAR_FROM_S: float = 0.06
const JUMP_CLEAR_TO_S: float = 0.68
## Plataformas que parpadean: segundos reales que deben seguir solidas al saltar
## a una lateral (aterrizar) o para cruzar por ella a la central (aterrizar,
## coger carrerilla y saltar). Carrerilla y despegue (px) hacia la central.
const SIDE_PATH_NEED_S: float = 0.75
const CENTER_PATH_NEED_S: float = 1.2
const CENTER_RUNUP_PX: float = 26.0
const CENTER_TAKEOFF_PX: float = 30.0
## Distancia (px) al borde interior de una lateral que parpadea desde la que se
## salta a ella desde el suelo (es maciza: no se atraviesa desde debajo).
const BLINK_TAKEOFF_PX: float = 56.0
## Lanzamiento de una copia: el dash sale este tiempo (s del mundo) antes de
## que acabe el aviso (la invulnerabilidad de 0,3 s cubre el lanzamiento).
const LUNGE_DASH_LEAD_S: float = 0.04
## Esperas (px) fuera de las ventanas: junto a los cargadores 2 y 3 (columnas 8 y
## 15) y a DASH_LAND_PX de las franjas de las campanas (columnas 5, 11 y 18).
const IDLE_X: Array[float] = [600.0, 990.0]
## Donde acaba un dash (px desde el inicio: 192 del dash y un poco de inercia).
const DASH_LAND_PX: float = 220.0

var _profile: String = "ideal"
var _lap: int = 1
var _verbose: bool = false
## --trace: cada medio segundo, lo que ve el bot (depuracion).
var _trace: bool = false
var _model: Dictionary = {}
var _boss_cfg: Dictionary = {}
var _target_s: float = 240.0

var _runner: LevelRunner
var _level: Node
var _isak: Isak
var _boss: AlertMajor
var _tile: float = 64.0
var _floor_y: float = 640.0
var _high_y: float = 512.0
var _center_y: float = 384.0
## Plataformas: [x0, x1] globales (px) de cada superficie.
var _plats: Dictionary = {}

# --- Entrada que se aplica al final de cada cuadro ---
var _axis: float = 0.0
var _run: bool = false
var _jump: bool = false
var _debug_hold: bool = false
## Debug que pide la politica en este cuadro (la ultima peticion manda).
var _debug_want: bool = false
var _last_debug_want: bool = false
## Subiendo a la plataforma central (Raíz) por una lateral: direccion (0 si no).
## Mientras, el Debug se suelta (el dash aereo no se combina con el).
var _climb_dir: float = 0.0
var _taps: Array[StringName] = []
var _held_taps: Array[StringName] = []
var _debug_tap_cd: int = 0
var _pulse_cd: int = 0
var _laser_cd: int = 0
var _dash_tap_cd: int = 0

# --- Estado ---
var _frame: int = 0
var _phase_seen: int = 0
var _jumping: bool = false
var _jump_frames: int = 0
var _world_t: float = 0.0
var _launch_t0: float = -1.0
var _launch_dashed: bool = false
var _line_key: String = ""
var _line_frame: int = 0
var _hooked: bool = false
var _started: bool = false
var _defeated: bool = false
var _done: bool = false
var _after_frames: int = 0
var _game_over: bool = false
## Ventana actual: indice en la fase (0, 1...), golpes dados en ella, si ya
## marco, laseres fallados y segundos de Debug gastados en ella.
var _win_index: int = -1
var _win_hits: int = 0
var _win_missed: int = 0
var _win_debug_s: float = 0.0
var _win_early_done: bool = false
var _win_wrong_done: bool = false
var _win_popup_debug: bool = false
var _was_window: bool = false
## Fase 1: Burbuja que se remata en esta ronda (o null).
var _kill_target: AlertBubble
var _kills_this_phase: int = 0
var _pickup_target: Node2D

# --- Medidas ---
var _fight_frames: int = 0
var _hits: int = 0
var _deaths: int = 0
var _min_energy: float = INF
var _min_energy_window: float = INF
var _min_energy_phase: Dictionary = {}
var _debug_cut_in_window: int = 0
var _dashes: int = 0
var _lasers: int = 0
var _pulses: int = 0
var _debug_frames: int = 0
var _charges: int = 0
var _windows: Dictionary = {}
var _phase_frames: Dictionary = {}
var _hit_log: PackedStringArray = []
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
	EventBus.pulse_fired.connect(func(_a: Area2D) -> void: _pulses += 1)
	_runner = (load(MAIN_SCENE) as PackedScene).instantiate() as LevelRunner
	_runner.start_level_id = LEVEL_ID
	add_child(_runner)
	_note("perfil %s, acceso %s (vuelta %d)" % [_profile, ACCESS_NAMES[_lap], _lap])


## Progreso de quien acaba de completar el 1-3: Eco y Notas conocidos, las cuatro
## habilidades, los avisos vistos y el jefe desbloqueado, en la vuelta pedida.
func _setup_progress() -> void:
	GameState.lap = _lap
	GameState.meet_ally(GameState.ALLY_ECO)
	GameState.meet_ally(GameState.ALLY_NOTAS)
	for ability: StringName in [GameState.ABILITY_PULSE, GameState.ABILITY_LASER, GameState.ABILITY_DEBUG,
			GameState.ABILITY_DASH]:
		GameState.obtain_ability(ability)
		GameState.seen_notices[ability] = true
	for id: StringName in [&"1-1", &"1-2", &"1-3"]:
		GameState.mark_level_completed(id)
	GameState.unlock_level(&"1-boss")


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
	_debug_want = false
	_climb_dir = 0.0
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
	var wdt: float = WorldTime.scaled_delta(delta)
	_world_t += wdt
	if _boss.is_fighting():
		if not _started:
			_started = true
			_note("pelea: empieza (%s)" % _boss.get_counter_label())
		_fight_frames += 1
		_phase_frames[_boss.get_phase()] = int(_phase_frames.get(_boss.get_phase(), 0)) + 1
		_measure()
		if _profile != "idle":
			_fight()
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
		_boss = _level.get_node_or_null(^"Objects/alerta_mayor") as AlertMajor
		if _boss != null:
			_hook_boss()


func _hook_boss() -> void:
	_hooked = true
	_tile = float(World1ObjectsConfig.tile_size())
	var lanes: Dictionary = (_boss_cfg.get("arena", {}) as Dictionary).get("lanes", {})
	_floor_y = float((lanes.get("floor", {}) as Dictionary).get("surface_row", 10)) * _tile
	_high_y = float((lanes.get("high", {}) as Dictionary).get("surface_row", 8)) * _tile
	var spots: Dictionary = (_boss_cfg.get("arena", {}) as Dictionary).get("spots", {})
	_center_y = float((spots.get("platform_center", [12.0, 6]) as Array)[1]) * _tile
	# Superficies de la arena (celdas de data/levels/1-boss.json): laterales 3-6 y
	# 17-20 en la fila 8, central 9-14 en la fila 6.
	_plats = {&"left": Vector2(3.0 * _tile, 7.0 * _tile), &"right": Vector2(17.0 * _tile, 21.0 * _tile),
		&"center": Vector2(9.0 * _tile, 15.0 * _tile), &"floor": Vector2(1.0 * _tile, 23.0 * _tile)}
	_boss.window_opened.connect(_on_window_opened)
	_boss.phase_changed.connect(_on_phase_changed)
	_boss.phase_restarted.connect(_on_phase_restarted)
	_boss.hit_taken.connect(func(_r: int) -> void:
		_win_hits += 1
		var p: int = _boss.get_phase()
		var w: Dictionary = _windows.get(p, {})
		w["hits"] = int(w.get("hits", 0)) + 1
		_windows[p] = w)
	_boss.attack_started.connect(_on_attack)
	_boss.final_blow.connect(_on_final_blow)


func _on_hurt() -> void:
	_hits += 1
	var what: String = _nearest_hazard()
	var line: String = "golpe a Isak en la fase %d (%s; x %.0f, y %.0f; Sync %.0f; %s)" % [
		_boss.get_phase() if _boss != null else 0, _state_label(), _isak.global_position.x, _isak.global_position.y,
		GameState.sync_rate, what]
	_hit_log.append(line)
	_note(line)


func _on_window_opened(_s: float) -> void:
	_win_index += 1
	_win_hits = 0
	_win_missed = 0
	_win_debug_s = 0.0
	_win_wrong_done = false
	_win_popup_debug = false
	var p: int = _boss.get_phase()
	var w: Dictionary = _windows.get(p, {})
	w["windows"] = int(w.get("windows", 0)) + 1
	_windows[p] = w
	if _verbose:
		_note("ventana %d de la fase %d (%.1f s del mundo; quiere %d golpes)" % [_win_index, p, _s,
			_window_goal()])


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
	_win_early_done = false
	_kill_target = null
	_kills_this_phase = 0
	_launch_t0 = -1.0


func _on_attack(attack: StringName) -> void:
	if attack == &"launch":
		_launch_t0 = _world_t
		_launch_dashed = false
	elif attack == &"shield":
		_win_popup_debug = false
		_win_debug_s = 0.0
	if _verbose and attack != &"popup":
		_note("ataque %s (fase %d, %.1f s)" % [attack, _boss.get_phase(), _fight_s()])


func _on_final_blow() -> void:
	_defeated = true
	_after_frames = 0
	_debug_hold = false
	_note("golpe final a los %.1f s de pelea" % _fight_s())


# --- Medidas ---

func _measure() -> void:
	_last_phase = _boss.get_phase()
	_last_counter = _boss.get_counter_label()
	var e: float = GameState.debug_energy
	_min_energy = minf(_min_energy, e)
	var p: int = _boss.get_phase()
	_min_energy_phase[p] = minf(float(_min_energy_phase.get(p, INF)), e)
	var active: bool = DebugMode.is_active()
	if active:
		_debug_frames += 1
	if _boss.is_window_open():
		_min_energy_window = minf(_min_energy_window, e)
		if _was_debug_active and not active and e <= GameState.DEBUG_ENERGY_MIN + 0.01:
			_debug_cut_in_window += 1
			_note("el Debug se corta sin energia en una ventana (fase %d)" % p)
	_was_debug_active = active


func _fight_s() -> float:
	return float(_fight_frames) / 60.0


# --- Politica ---

func _fight() -> void:
	if _isak.is_dead() or _isak.is_warping():
		_debug_hold = false
		return
	var phase: int = _boss.get_phase()
	_track_window_debug()
	# Reflejos primero: si esquivan, este cuadro no hace nada mas.
	if _reflexes() or _dodge_burst():
		# Esquivar no cambia lo que se hacia con el Debug.
		_debug_want = _last_debug_want
		return
	if _boss.is_window_open():
		_was_window = true
		_window_play()
		return
	if _was_window:
		_was_window = false
		_debug_off()
	match phase:
		1:
			_phase1()
		2:
			_phase2()
		3:
			_phase3()


## Golpes que este perfil quiere dar en la ventana actual (ideal: todos).
func _window_goal() -> int:
	if _profile != "clumsy":
		return 99
	var wins: Array = _model_lap().get("windows", [])
	var p: int = _boss.get_phase() - 1
	if p < 0 or p >= wins.size():
		return 99
	var list: Array = wins[p]
	if _win_index < 0:
		return 1
	if _win_index < list.size():
		return int(list[_win_index])
	return 99


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
	var list: Array = _model_lap().get("debug_s", [3.0, 3.0, 3.5])
	var p: int = clampi(_boss.get_phase() - 1, 0, list.size() - 1)
	return float(list[p]) + _model_phase_value("extra_debug_s", 0.0)


func _track_window_debug() -> void:
	if DebugMode.is_active() and _boss.is_window_open():
		_win_debug_s += get_physics_process_delta_time()


## Juega la ventana abierta: Debug -> pulso (marca) -> soltar el Debug -> laser.
func _window_play() -> void:
	var core: WeakPoint = _boss.get_core()
	var goal: int = _window_goal()
	if _boss.get_phase() == 3 and _profile == "clumsy" and goal == 0 and not _win_wrong_done:
		_clumsy_wrong_copy()
		return
	var target: Vector2 = _boss.get_core_target()
	if target == Vector2.INF:
		_debug_off()
		_idle_position()
		return
	var surface: StringName = _surface_of_point(target)
	var stand: float = _stand_x(target, surface)
	var arrived: bool = _go(stand, surface)
	var marked: bool = core.is_marked()
	# Torpe: mantiene el Debug sus segundos (y los de antes de tiempo en la perdida).
	var clumsy_hold: bool = _profile == "clumsy" and _win_debug_s < _clumsy_debug_s()
	if goal == 0:
		# Ventana perdida: Debug encendido sus segundos, un laser fallado y nada mas.
		_want_debug(clumsy_hold)
		if arrived and _win_missed < int(_model.get("misses_per_window", 1)):
			_face_x(target.x)
			if _try_laser():
				_win_missed += 1
		return
	if _win_hits >= goal:
		_want_debug(clumsy_hold)
		return
	if not marked:
		# Torpe: antes de marcar, un laser al cuerpo (sin marca: chispa gris).
		if _profile == "clumsy" and arrived and _win_missed < int(_model.get("misses_per_window", 1)) \
				and core.is_exposed() == false:
			_face_x(target.x)
			if _try_laser():
				_win_missed += 1
			return
		_want_debug(true)
		if arrived and DebugMode.is_active() and _pulse_reaches_point(target, WeakPoint.radius_px()):
			_face_x(target.x)
			_try_pulse()
		return
	# Marcado: suelta el Debug (el ideal enseguida) y dispara.
	_want_debug(clumsy_hold)
	if not arrived:
		return
	_face_x(target.x)
	var left: float = core.get_mark_time_left()
	if left < 0.35 and _boss.get_window_time_left() > 1.2 and _profile == "ideal":
		# Va a caducar con la ventana abierta: se vuelve a marcar con el Debug.
		_want_debug(true)
		if DebugMode.is_active() and _pulse_reaches_point(target, WeakPoint.radius_px()):
			_try_pulse()
		return
	if _laser_reaches(target):
		_try_laser()


## Torpe, fase 3, ventana perdida: va a una copia, la golpea con el pulso
## (se descarta y suelta una Burbuja) y remata la Burbuja con el laser.
func _clumsy_wrong_copy() -> void:
	var clones: Array[AlertMajorClone] = _boss.get_clones()
	_want_debug(_win_debug_s < _clumsy_debug_s())
	if clones.is_empty():
		_win_wrong_done = true
		return
	var best: AlertMajorClone = clones[0]
	for c: AlertMajorClone in clones:
		if absf(c.global_position.x - _isak.global_position.x) < absf(best.global_position.x - _isak.global_position.x):
			best = c
	var at: Vector2 = best.global_position
	var surface: StringName = _surface_of_point(at + Vector2(0.0, _down_half() - _phone_dy()))
	var stand: float = _stand_x(at, surface)
	if _go(stand, surface) and _pulse_reaches_rect(best.get_body_rect()):
		_face_x(at.x)
		if _try_pulse():
			_win_wrong_done = true
			_note("torpe: pulso a una copia (fase 3, ventana %d)" % _win_index)


# --- Fase 1: Burbujas y barridos ---

func _phase1() -> void:
	_want_debug(false)
	var move: StringName = _boss.get_move()
	if move == AlertMajor.MOVE_DESCEND or move == AlertMajor.MOVE_DOWN:
		# Baja: va hacia el centro (y el ideal ya carga el Debug).
		var spot: Vector2 = _boss.get_spot_center(&"floor_center")
		_go(_stand_x(Vector2(spot.x, _floor_y - 56.0), &"floor"), &"floor")
		if _profile == "ideal":
			_want_debug(true)
		return
	if _maybe_recharge():
		return
	if _pickup_step():
		return
	var bubbles: Array[AlertBubble] = []
	for b: AlertBubble in _boss.get_bubbles():
		if b.is_on_floor():
			bubbles.append(b)
	if bubbles.is_empty():
		_idle_position()
		return
	# Torpe: el Debug antes de tiempo en la ventana que pierde (early_debug_s).
	if _profile == "clumsy" and not _win_early_done and _window_goal_next() == 0 \
			and _model_phase_value("early_debug_s", 0.0) > 0.0 and _boss.are_bubbles_neutralized():
		_want_debug(true)
		if DebugMode.is_active():
			_win_debug_s += get_physics_process_delta_time()
			if _win_debug_s >= _model_phase_value("early_debug_s", 0.0):
				_win_early_done = true
		return
	var kills_goal: int = int(_model_phase_value("bubble_kills", 1.0)) if _profile == "clumsy" else 1
	if (_kill_target == null or not is_instance_valid(_kill_target) or _kill_target.get_state() == AlertBubble.STATE_POPPED) \
			and _kills_this_phase < kills_goal and bubbles.size() >= 2:
		_kill_target = _nearest_bubble(bubbles)
	if _kill_target != null and is_instance_valid(_kill_target) and _kill_target.get_state() != AlertBubble.STATE_POPPED:
		_kill_bubble(_kill_target)
		return
	_kill_target = null
	# Las demas: aturdidas desde el suelo, refrescando el aturdimiento.
	var target: AlertBubble = null
	for b: AlertBubble in bubbles:
		if not b.is_stunned() or b.get_stun_left() < 1.0:
			if target == null or absf(b.global_position.x - _isak.global_position.x) \
					< absf(target.global_position.x - _isak.global_position.x):
				target = b
	if target == null:
		target = _nearest_bubble(bubbles)
		_go(target.global_position.x, &"floor")
		return
	_stun_from_below(target)


func _window_goal_next() -> int:
	var saved: int = _win_index
	_win_index += 1
	var g: int = _window_goal()
	_win_index = saved
	return g


func _nearest_bubble(list: Array[AlertBubble]) -> AlertBubble:
	var best: AlertBubble = list[0]
	for b: AlertBubble in list:
		if absf(b.global_position.x - _isak.global_position.x) < absf(best.global_position.x - _isak.global_position.x):
			best = b
	return best


## Aturde `b` (en una plataforma) desde el suelo, debajo de ella.
func _stun_from_below(b: AlertBubble) -> void:
	var surf: StringName = _isak_surface()
	if surf != &"floor" and surf != &"air":
		# En una plataforma: si la Burbuja esta en la misma, se aturde desde ahi.
		if _pulse_reaches_rect(b.get_body_rect()):
			_face_x(b.global_position.x)
			_try_pulse()
			return
		_go(b.global_position.x, &"floor")
		return
	var x: float = b.global_position.x + b.get_direction() * 12.0
	_go(x, &"floor", 10.0)
	if _pulse_reaches_rect(b.get_body_rect()):
		_face_x(b.global_position.x)
		_try_pulse()


## Remata `b`: aturdida desde abajo, sube a su plataforma y dos laseres.
func _kill_bubble(b: AlertBubble) -> void:
	var plat: StringName = _surface_of_point(b.global_position + Vector2(0.0, -8.0))
	var surf: StringName = _isak_surface()
	if not b.is_stunned() or (b.get_stun_left() < 0.8 and surf != plat):
		_stun_from_below(b)
		return
	# Junto a ella en su plataforma, del lado con sitio.
	var r: Vector2 = _plats.get(plat, Vector2(0, 99999))
	var side: float = -1.0 if b.global_position.x - r.x > r.y - b.global_position.x else 1.0
	var stand: float = clampf(b.global_position.x + side * 90.0, r.x + 20.0, r.y - 20.0)
	if absf(stand - b.global_position.x) < 70.0:
		side = -side
		stand = clampf(b.global_position.x + side * 90.0, r.x + 20.0, r.y - 20.0)
	if not _go(stand, plat):
		return
	if b.is_stunned() and b.get_stun_left() < 0.4 and _pulse_reaches_rect(b.get_body_rect()):
		_face_x(b.global_position.x)
		_try_pulse()
		return
	_face_x(b.global_position.x)
	if _laser_reaches_rect(b.get_body_rect()):
		_try_laser()


func _on_bubble_killed(b: AlertBubble) -> void:
	_kills_this_phase += 1
	_note("Burbuja rematada (fase %d)" % _boss.get_phase())
	_pickup_target = null
	for node: Node in get_tree().get_nodes_in_group(RechargePickup.GROUP):
		var p := node as Node2D
		if p != null and p.global_position.distance_to(b.global_position) < 160.0:
			_pickup_target = p


## Recoge la energia de la Burbuja rematada si sigue ahi.
func _pickup_step() -> bool:
	if _kill_target != null and is_instance_valid(_kill_target) and _kill_target.get_state() == AlertBubble.STATE_POPPED:
		_on_bubble_killed(_kill_target)
		_kill_target = null
	if _pickup_target == null or not is_instance_valid(_pickup_target) or not _pickup_target.is_inside_tree():
		_pickup_target = null
		return false
	var plat: StringName = _surface_of_point(_pickup_target.global_position + Vector2(0.0, 24.0))
	if _go(_pickup_target.global_position.x, plat, 6.0):
		_pickup_target = null
	return true


# --- Fase 2: pop-ups, rafagas y escudo ---

func _phase2() -> void:
	_want_debug(false)
	var move: StringName = _boss.get_move()
	var shield: OverlayPopup = _boss.get_shield()
	if (move == AlertMajor.MOVE_DOWN or move == AlertMajor.MOVE_DESCEND) and shield != null and shield.is_open():
		var center: Vector2 = _boss.get_body_center()
		var core_at: Vector2 = center + Vector2(0.0, _down_half() - _phone_dy())
		var surface: StringName = _surface_of_point(core_at)
		var stand: float = _stand_x(core_at, surface)
		# Torpe: Debug de mas para ver a traves de los pop-ups (extra_debug_s),
		# mientras va hacia el escudo.
		if _profile == "clumsy" and not _win_popup_debug and _model_phase_value("extra_debug_s", 0.0) > 0.0:
			_want_debug(true)
			if DebugMode.is_active():
				_win_debug_s += get_physics_process_delta_time()
				if _win_debug_s >= _model_phase_value("extra_debug_s", 0.0):
					_win_popup_debug = true
					_win_debug_s = 0.0
		if _go(stand, surface) and move == AlertMajor.MOVE_DOWN and _pulse_reaches_rect(shield.get_button_rect()):
			_face_x(center.x)
			_try_pulse()
		return
	if _maybe_recharge():
		return
	_idle_position()


# --- Fase 3: copias al compas ---

func _phase3() -> void:
	_want_debug(false)
	if _maybe_recharge():
		return
	# La Burbuja de una copia rota, si esta en el suelo: aturdida y rematada
	# fuera de los lanzamientos (bubble_kills del modelo).
	if _boss.get_round_state() != &"launch":
		for b: AlertBubble in _boss.get_bubbles():
			if b.is_on_floor() and absf(b.global_position.y - _floor_y) < 8.0:
				_kill_floor_bubble(b)
				return
	_idle_position()


func _kill_floor_bubble(b: AlertBubble) -> void:
	if not b.is_stunned():
		var stand_s: float = _stand_x(b.global_position + Vector2(0.0, -40.0), &"floor")
		if _pulse_reaches_rect(b.get_body_rect()):
			_face_x(b.global_position.x)
			_try_pulse()
		else:
			_go(stand_s, &"floor")
		return
	var stand: float = _stand_x(b.global_position + Vector2(0.0, -40.0), &"floor")
	if _go(stand, &"floor"):
		_face_x(b.global_position.x)
		if _laser_reaches_rect(b.get_body_rect()):
			_try_laser()


## Donde espera fuera de las ventanas: junto a los cargadores del suelo de las
## columnas 8 y 15, en un sitio desde el que un dash a cualquier lado acaba fuera
## de las columnas de las campanas de la fase 3 (IDLE_X).
func _idle_position() -> void:
	var phase: int = _boss.get_phase()
	var spots: Array[float] = []
	for x0: float in IDLE_X:
		spots.append(x0)
	var best: float = spots[0]
	var best_cost: float = INF
	for x: float in spots:
		# Lejos de las Burbujas que patrullan en el suelo (fase 3: copias rotas).
		var cost: float = absf(x - _isak.global_position.x)
		for b: AlertBubble in _boss.get_bubbles():
			if absf(b.global_position.y - _floor_y) < 8.0 and absf(b.global_position.x - x) < 320.0:
				cost += 2000.0
		if cost < best_cost:
			best_cost = cost
			best = x
	_go(best, &"floor")


## Recarga: por debajo de RECHARGE_BELOW, al cargador listo mas cercano.
func _maybe_recharge() -> bool:
	if GameState.debug_energy >= RECHARGE_BELOW:
		return false
	var best: Charger = null
	for node: Node in _all_nodes(_level):
		var c := node as Charger
		if c == null or not c.is_ready():
			continue
		if best == null or absf(c.global_position.x - _isak.global_position.x) < absf(best.global_position.x - _isak.global_position.x):
			best = c
	if best == null:
		return false
	_go(best.global_position.x + _tile * 0.5, &"floor", 8.0)
	return true


# --- Reflejos ---

## Esquiva lo que va a golpear ya. Verdadero si este cuadro esquiva.
func _reflexes() -> bool:
	if _isak.is_dashing():
		_axis = 0.0
		return true
	var body: Rect2 = LevelLookup.isak_body_rect(_isak)
	# 1) Lanzamiento de una copia (fase 3): dash justo al acabar el aviso.
	if _launch_t0 >= 0.0 and _boss.get_round_state() == &"launch" and not _launch_dashed:
		var warn: float = _boss.frames_s((_boss.phase_data(3) as Dictionary).get("launch_warn_frames", 9))
		var since: float = _world_t - _launch_t0
		var idx: int = _boss.get_launching_index()
		var from: Vector2 = _launch_origin(idx)
		var reach: float = float((_boss.phase_data(3) as Dictionary).get("lunge_max_px", 384.0)) + 48.0 + 40.0
		if since >= warn - LUNGE_DASH_LEAD_S and from.distance_to(body.get_center()) < reach:
			var dir: float = _escape_dir(from.x)
			if _try_dash(dir):
				_launch_dashed = true
				return true
			if since >= warn - 0.01:
				# Sin dash: se aparta corriendo.
				_launch_dashed = true
		elif since >= warn + 0.4:
			_launch_dashed = true
	# 2) Lo que se mueve en horizontal: barridos y notificaciones. El dash (a
	# traves) si esta listo o lo estara a tiempo; si no, un salto (en el aire,
	# el dash aereo).
	# Isak (dash y salto) va en tiempo real; lo que se mueve, en tiempo del
	# mundo (con el Debug, a la mitad): todo se compara en segundos reales.
	var scale: float = maxf(WorldTime.scale(), 0.05)
	for h: Dictionary in _moving_hazards():
		var rect: Rect2 = h["rect"]
		var vx: float = h["vx"]
		var t_world: float = _time_to_hit(rect, vx, body)
		if t_world < 0.0:
			continue
		var t: float = t_world / scale
		var toward: float = signf(-vx) if absf(vx) > 0.0 else _isak.facing
		if _dash_ready():
			if t <= DASH_HORIZON_S and _try_dash(toward):
				return true
			continue
		if _dash_soon(t):
			_axis = 0.0
			continue
		# Salto: los pies por encima del peligro desde JUMP_CLEAR_FROM_S hasta
		# JUMP_CLEAR_TO_S tras despegar; el cruce dura (ancho) / |vx|.
		var cross: float = (rect.size.x + body.size.x + 8.0) / maxf(absf(vx) * scale, 1.0)
		var latest: float = minf(JUMP_HORIZON_S, JUMP_CLEAR_TO_S - cross)
		if t <= latest and t >= JUMP_CLEAR_FROM_S and _isak.is_on_floor() and not _jumping \
				and _can_jump_over(rect):
			_start_jump()
			_axis = 0.0
			return true
	# 3) Burbujas que patrullan en la superficie de Isak: pulso (no durante el
	# aviso de un lanzamiento: la pose del pulso no deja salir el dash).
	var launching: bool = false
	if _boss.get_round_state() == &"launch" and _launch_t0 >= 0.0:
		var warn3: float = _boss.frames_s((_boss.phase_data(3) as Dictionary).get("launch_warn_frames", 9))
		var since3: float = _world_t - _launch_t0
		launching = since3 > warn3 - 0.45 and since3 < warn3 + 0.35
	for b: AlertBubble in _boss.get_bubbles():
		if launching:
			break
		if b.is_stunned() or not b.is_dangerous() and b.get_state() != AlertBubble.STATE_PATROL:
			continue
		if absf(b.global_position.y - _isak.global_position.y) > 24.0:
			continue
		if absf(b.global_position.x - _isak.global_position.x) < 150.0 and _pulse_reaches_rect(b.get_body_rect()):
			_face_x(b.global_position.x)
			if _try_pulse():
				return true
	# 4) Campanas: fuera de su columna antes de la onda.
	for bell: AlarmBell in _bells():
		if not (bell.is_warning() or bell.is_wave()):
			continue
		var band: Vector2 = _bell_band(bell)
		var x: float = _isak.global_position.x
		if x > band.x and x < band.y:
			var out: float = band.x - 4.0 if x - band.x < band.y - x else band.y + 4.0
			if bell.is_wave() and _try_dash(signf(out - x)):
				return true
			_axis = signf(out - x)
			_run = true
			return true
	return false


## Rafaga en el carril de Isak (fase 2): cambia de carril (sube a la plataforma
## mas cercana o baja de la suya) antes de que lleguen las notificaciones. Los
## reflejos cubren lo que no llegue a tiempo. Verdadero si este cuadro se mueve.
func _dodge_burst() -> bool:
	if _boss.get_phase() != 2 or _boss.get_burst_state() == &"":
		return false
	var lane: String = _boss.get_burst_lane()
	var surf: StringName = _isak_surface()
	var on_floor_lane: bool = _isak.global_position.y > _floor_y - _tile * 1.5
	# Notificaciones que aun no han pasado a Isak (o el aviso): si no hay, nada.
	var body: Rect2 = LevelLookup.isak_body_rect(_isak)
	var pending: bool = _boss.get_burst_state() == &"warn"
	for shot: NotificationShot in _boss.get_shots():
		var r: Rect2 = shot.get_damage_rect()
		if (shot.direction > 0 and r.position.x < body.end.x) or (shot.direction < 0 and r.end.x > body.position.x):
			pending = true
	if not pending:
		return false
	if (lane == "floor") != on_floor_lane:
		# Ya en el otro carril: quieto hasta que pasen (en el aire, sigue).
		if surf == &"left" or surf == &"right":
			_axis = 0.0
			return true
		return surf == &"air"
	if on_floor_lane:
		var best: StringName = &"left" if absf(_isak.global_position.x - _plats[&"left"].y) \
			< absf(_isak.global_position.x - _plats[&"right"].x) else &"right"
		var r2: Vector2 = _plats[best]
		_go(clampf(_isak.global_position.x, r2.x + 30.0, r2.y - 30.0), best)
	else:
		_go(_isak.global_position.x, &"floor")
	return true


## Barridos y notificaciones en movimiento: {rect, vx} (px, px/s del mundo).
func _moving_hazards() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for banner: Variant in _boss.get_banners().values():
		var sb := banner as SpamBanner
		if sb == null or not is_instance_valid(sb):
			continue
		if sb.is_sweeping():
			out.append({"rect": sb.get_damage_rect(), "vx": float(sb.direction) * sb.sweep_speed_px_s})
	for shot: NotificationShot in _boss.get_shots():
		out.append({"rect": shot.get_damage_rect(), "vx": float(shot.direction) * shot.speed_px_s})
	return out


## Segundos del mundo hasta que `rect` (moviendose a vx) toque `body`; -1 si no.
func _time_to_hit(rect: Rect2, vx: float, body: Rect2) -> float:
	var grown: Rect2 = body.grow(4.0)
	if rect.end.y < grown.position.y or rect.position.y > grown.end.y:
		return -1.0
	if rect.intersects(grown):
		return 0.0
	if vx > 0.0 and rect.end.x <= grown.position.x:
		return (grown.position.x - rect.end.x) / vx
	if vx < 0.0 and rect.position.x >= grown.end.x:
		return (rect.position.x - grown.end.x) / -vx
	return -1.0


## Un salto desde el suelo deja los pies por encima de `rect` (barrido del suelo
## o notificacion a la altura del celular).
func _can_jump_over(rect: Rect2) -> bool:
	return _isak.global_position.y - rect.position.y < 96.0


## Direccion del dash ante una copia que se lanza desde `from_x`: lejos de ella
## salvo contra el muro (entonces a traves).
func _escape_dir(from_x: float) -> float:
	var x: float = _isak.global_position.x
	var away: float = signf(x - from_x) if absf(x - from_x) > 1.0 else 1.0
	# Primero donde no alcanza ninguna campana; si no, donde ahora no suena.
	for sounding_only: bool in [false, true]:
		for dir: float in [away, -away]:
			var land: float = x + dir * DASH_LAND_PX
			if land < _plats[&"floor"].x + 24.0 or land > _plats[&"floor"].y - 24.0:
				continue
			if _in_bell_band(land, sounding_only):
				continue
			return dir
	return -away


func _launch_origin(idx: int) -> Vector2:
	if idx < 0:
		return Vector2.INF
	var spots: Array[StringName] = _boss.get_copy_spots()
	if idx >= spots.size():
		return Vector2.INF
	return _boss.get_spot_center(spots[idx])


func _bells() -> Array[AlarmBell]:
	var out: Array[AlarmBell] = []
	for node: Node in _all_nodes(_level):
		var b := node as AlarmBell
		if b != null and BossBase.is_phase_node_active(b):
			out.append(b)
	return out


## Franja de x de Isak (pies) en la que la onda de la campana le alcanza.
func _bell_band(bell: AlarmBell) -> Vector2:
	var r: Rect2 = bell.get_wave_rect()
	var half: float = _isak.hitbox_size.x * 0.5 + 6.0
	return Vector2(r.position.x - half, r.end.x + half)


func _in_bell_band(x: float, sounding_only: bool = false) -> bool:
	for bell: AlarmBell in _bells():
		if sounding_only and not (bell.is_warning() or bell.is_wave()):
			continue
		var band: Vector2 = _bell_band(bell)
		if x > band.x and x < band.y:
			return true
	return false


# --- Movimiento ---

## Superficie en la que esta Isak: floor, left, right, center, air u other.
func _isak_surface() -> StringName:
	if not _isak.is_on_floor():
		return &"air"
	return _surface_at(_isak.global_position)


func _surface_at(feet: Vector2) -> StringName:
	if absf(feet.y - _floor_y) < 10.0:
		return &"floor"
	if absf(feet.y - _high_y) < 10.0:
		return &"left" if feet.x < _plats[&"floor"].y * 0.5 else &"right"
	if absf(feet.y - _center_y) < 10.0:
		return &"center"
	return &"other"


## Superficie de la que sale un punto a la altura del celular (`p`: nucleo,
## boton...): la mas alta por debajo de el.
func _surface_of_point(p: Vector2) -> StringName:
	for s: StringName in [&"center", &"left", &"right"]:
		var y: float = _center_y if s == &"center" else _high_y
		var r: Vector2 = _plats[s]
		if p.y < y and p.y > y - 100.0 and p.x >= r.x - 8.0 and p.x <= r.y + 8.0:
			return s
	return &"floor"


## x de pie para marcar y disparar a `target` desde `surface`: a STAND_DX, del
## lado de Isak si cabe y lejos de las columnas de las campanas.
func _stand_x(target: Vector2, surface: StringName) -> float:
	var r: Vector2 = _plats.get(surface, _plats[&"floor"])
	var lo: float = r.x + 22.0
	var hi: float = r.y - 22.0
	var pref: float = signf(_isak.global_position.x - target.x)
	if pref == 0.0:
		pref = -1.0
	var best: float = INF
	for dx: float in [STAND_DX, STAND_DX - 16.0, STAND_DX + 16.0, STAND_DX - 32.0]:
		for side: float in [pref, -pref]:
			var x: float = target.x + side * dx
			if x < lo or x > hi or _in_bell_band(x):
				continue
			return x
	if best == INF:
		best = clampf(target.x + pref * STAND_DX, lo, hi)
	return best


## Va a `x` en `surface`. Verdadero si ya esta (de pie, quieto).
func _go(x: float, surface: StringName, tol: float = 12.0) -> bool:
	var cur: StringName = _isak_surface()
	var ix: float = _isak.global_position.x
	if cur == &"air":
		_axis = _approach_axis(x - ix)
		_run = absf(x - ix) > 60.0
		if surface == &"center" and _isak.global_position.y < _high_y - 8.0:
			var c: Vector2 = _plats[&"center"]
			if ix < c.x - 8.0 or ix > c.y + 8.0:
				_climb_dir = signf(x - ix)
				if _isak.velocity.y > -160.0 and _isak.global_position.y < _center_y - 8.0:
					_try_dash(_climb_dir)
		return false
	if cur == surface:
		return _walk_to(x, tol)
	if surface == &"floor":
		# Bajar de una plataforma andando por el borde mas cercano a x.
		var r: Vector2 = _plats.get(cur, Vector2(ix - 1.0, ix + 1.0))
		if cur == &"other":
			r = Vector2(ix - 96.0, ix + 96.0)
		if x < r.x - 8.0 or x > r.y + 8.0:
			_walk_to(x, 0.0, true)
		else:
			var edge: float = r.x - 40.0 if ix - r.x < r.y - ix else r.y + 40.0
			_walk_to(edge, 0.0, true)
		return false
	if surface == &"center":
		# Por una lateral: se sube junto a su borde interior (fuera de la franja de
		# su campana) y desde ahi se salta a la central corriendo.
		if cur == &"floor" or cur == &"other":
			var side: StringName = &"left" if ix < _plats[&"center"].x + 3.0 * _tile else &"right"
			var r2: Vector2 = _plats[side]
			var runup: float = r2.y - CENTER_RUNUP_PX if side == &"left" else r2.x + CENTER_RUNUP_PX
			_go_platform(runup, side, CENTER_PATH_NEED_S)
			return false
		if cur == &"left" or cur == &"right":
			# Salto desde el borde interior y dash aereo en lo alto (sin el Debug:
			# no se combinan; se vuelve a activar arriba, la carga no gasta).
			var dir: float = 1.0 if cur == &"left" else -1.0
			var inner: float = _plats[cur].y if cur == &"left" else _plats[cur].x
			_climb_dir = dir
			_axis = dir
			_run = true
			if dir * (ix - inner) >= -CENTER_TAKEOFF_PX and not DebugMode.is_engaged():
				_start_jump()
			return false
	# Subir a una plataforma lateral (de una via: se salta desde debajo).
	if cur == &"floor":
		_go_platform(x, surface, SIDE_PATH_NEED_S)
		return false
	# En otra plataforma: primero al suelo.
	_go(x, &"floor")
	return false


## Desde el suelo, sube a la plataforma lateral `surface` saltando desde debajo
## de `x` cuando seguira solida `need_s` segundos reales.
func _go_platform(x: float, surface: StringName, need_s: float) -> void:
	var pr: Vector2 = _plats[surface]
	if _is_blink(surface):
		# Las que parpadean (fase 3) son macizas: se sube desde fuera, por el
		# lado de dentro de la arena, saltando hacia ella.
		var dir: float = -1.0 if surface == &"left" else 1.0
		var takeoff: float = (pr.y if surface == &"left" else pr.x) - dir * BLINK_TAKEOFF_PX
		if absf(_isak.global_position.x - takeoff) > 14.0 and not _jumping:
			_walk_to(takeoff, 0.0)
			return
		if _jumping or _platform_ready(surface, need_s + 0.2):
			_axis = dir
			_run = true
			_start_jump()
		return
	var under: float = clampf(x, pr.x + 26.0, pr.y - 26.0)
	if _in_bell_band(under):
		# Fuera de la franja de una campana (en la fase 3 suenan sin parar).
		for dx: float in [-16.0, 16.0, -32.0, 32.0, -48.0, 48.0, -64.0, 64.0, -80.0, 80.0, -96.0, 96.0]:
			var c: float = under + dx
			if c >= pr.x + 12.0 and c <= pr.y - 12.0 and not _in_bell_band(c):
				under = c
				break
	if absf(_isak.global_position.x - under) > 14.0:
		_walk_to(under, 0.0)
		return
	if _platform_ready(surface, need_s):
		_start_jump()


## La plataforma lateral `surface` es ahora una que parpadea (fase 3).
func _is_blink(surface: StringName) -> bool:
	var pr: Vector2 = _plats[surface]
	for node: Node in _all_nodes(_level):
		var bp := node as BlinkPlatform
		if bp == null or not BossBase.is_phase_node_active(bp):
			continue
		var r: Rect2 = bp.get_card_rect()
		if r.position.x >= pr.x - 1.0 and r.end.x <= pr.y + 1.0:
			return true
	return false


func _walk_to(x: float, tol: float, force_run: bool = false) -> bool:
	var dx: float = x - _isak.global_position.x
	var bell_stop: float = _bell_blocks(dx)
	if bell_stop != 0.0:
		_axis = 0.0
		return false
	if absf(dx) <= maxf(tol, 2.0):
		_axis = 0.0
		return absf(_isak.velocity.x) < 30.0 and _isak.is_on_floor()
	_axis = _approach_axis(dx)
	_run = force_run or absf(dx) > 140.0
	return false


## Eje con frenada: suave cerca del destino.
func _approach_axis(dx: float) -> float:
	if absf(dx) < 3.0:
		return 0.0
	if absf(dx) < 24.0:
		return signf(dx) * 0.35
	return signf(dx)


## Antes de entrar en la franja de una campana que avisa o suena, espera fuera.
## Devuelve distinto de 0 si hay que parar.
func _bell_blocks(dx: float) -> float:
	if dx == 0.0:
		return 0.0
	var x: float = _isak.global_position.x
	for bell: AlarmBell in _bells():
		if not (bell.is_warning() or bell.is_wave()):
			continue
		var band: Vector2 = _bell_band(bell)
		if x > band.x and x < band.y:
			continue
		var ahead: float = x + signf(dx) * 24.0
		var x_to: float = x + dx
		if (dx > 0.0 and x <= band.x and ahead >= band.x - 8.0 and x_to > band.x) \
				or (dx < 0.0 and x >= band.y and ahead <= band.y + 8.0 and x_to < band.y):
			return 1.0
	return 0.0


## La plataforma `surface` sigue solida el tiempo de un salto (las laterales
## parpadean en la fase 3).
func _platform_ready(surface: StringName, need_s: float = SIDE_PATH_NEED_S) -> bool:
	for node: Node in _all_nodes(_level):
		var bp := node as BlinkPlatform
		if bp == null or not BossBase.is_phase_node_active(bp):
			continue
		var r: Rect2 = bp.get_card_rect()
		var pr: Vector2 = _plats[surface]
		if r.position.x >= pr.x - 1.0 and r.end.x <= pr.y + 1.0 and absf(r.position.y - _high_y) < 4.0:
			if not bp.is_solid():
				return false
			var scale: float = maxf(WorldTime.scale(), 0.05)
			if bp.get_time_to_off() / scale < need_s:
				return false
	return true


func _start_jump() -> void:
	if _jumping or not _isak.is_on_floor():
		return
	_jumping = true
	_jump_frames = 0
	_jump = true


func _update_jump() -> void:
	if not _jumping:
		_jump = false
		return
	_jump_frames += 1
	_jump = _jump_frames < 26 and (_jump_frames < 3 or _isak.velocity.y < 0.0)
	if _jump_frames > 4 and _isak.is_on_floor():
		_jumping = false
		_jump = false
	if _jump_frames > 120:
		_jumping = false
		_jump = false


func _face_x(x: float) -> void:
	var want: float = signf(x - _isak.global_position.x)
	if want != 0.0 and want != _isak.facing and _axis == 0.0:
		_axis = want * 0.2


# --- Acciones ---

func _try_pulse() -> bool:
	if _pulse_cd > 0 or not _isak.can_pulse() or _isak.is_dashing() or _isak.is_laser_posing():
		return false
	if _isak.get_state_name() == PlayerState.PULSE:
		return false
	_tap(A_PULSE)
	_pulse_cd = 24
	return true


func _try_laser() -> bool:
	if _laser_cd > 0 or not _isak.can_start_laser() or _isak.get_laser_cooldown_left() > 0.0 \
			or _isak.is_laser_posing() or GameState.debug_energy < 10.0:
		return false
	if _isak.get_state_name() == PlayerState.PULSE:
		return false
	_tap(A_LASER)
	_laser_cd = 6
	return true


## El dash saldria ahora (sin contar la direccion).
func _dash_ready() -> bool:
	if _isak.is_dashing() or _isak.get_dash_cooldown_left() > 0.0 or DebugMode.is_engaged() \
			or GameState.debug_energy < 10.0 or _isak.is_laser_posing() or _isak.is_dead() \
			or _isak.get_state_name() == PlayerState.PULSE:
		return false
	return _isak.is_on_floor() or _isak.get_air_dashes_left() > 0


## El dash estara listo antes de `t` (s del mundo) sin hacer nada.
func _dash_soon(t: float) -> bool:
	if _isak.is_dashing() or DebugMode.is_engaged() or GameState.debug_energy < 10.0:
		return false
	return _isak.get_dash_cooldown_left() < t - DASH_HORIZON_S * 0.5


func _try_dash(dir: float) -> bool:
	if dir == 0.0 or _isak.is_dashing() or _isak.get_dash_cooldown_left() > 0.0 or DebugMode.is_engaged() \
			or GameState.debug_energy < 10.0 or _isak.is_laser_posing() or _isak.is_dead():
		return false
	if not _isak.is_on_floor() and _isak.get_air_dashes_left() <= 0:
		return false
	if _dash_tap_cd > 0:
		_axis = dir
		return true
	_axis = dir
	_tap(A_DASH)
	_dash_tap_cd = 4
	return true


## Pide el Debug encendido (mantiene la tecla hasta que se activa) o apagado (un
## toque si esta activo). Manda la ultima peticion del cuadro (_resolve_debug).
func _want_debug(on: bool) -> void:
	_debug_want = on and _climb_dir == 0.0


func _resolve_debug() -> void:
	if _debug_want:
		_debug_hold = not DebugMode.is_active() and (DebugMode.can_enter() or DebugMode.is_engaged())
		return
	_debug_hold = false
	if DebugMode.is_active() and _debug_tap_cd <= 0:
		_tap(A_DEBUG)
		_debug_tap_cd = 12


func _debug_off() -> void:
	_want_debug(false)


func _pulse_reaches_point(p: Vector2, radius: float) -> bool:
	var o: Vector2 = _pulse_center_facing(p.x)
	return o.distance_to(p) <= PULSE_RADIUS + radius - REACH_MARGIN


func _pulse_reaches_rect(r: Rect2) -> bool:
	var o: Vector2 = _pulse_center_facing(r.get_center().x)
	var closest := Vector2(clampf(o.x, r.position.x, r.end.x), clampf(o.y, r.position.y, r.end.y))
	return o.distance_to(closest) <= PULSE_RADIUS - REACH_MARGIN


## Centro del pulso si Isak mira hacia `x`.
func _pulse_center_facing(x: float) -> Vector2:
	var origin: Vector2 = _isak.pulse_effect_origin
	var f: float = signf(x - _isak.global_position.x)
	if f == 0.0:
		f = _isak.facing
	return _isak.global_position + Vector2(origin.x * f, origin.y)


func _laser_reaches(p: Vector2) -> bool:
	var o: Vector2 = _isak.global_position + Vector2(0.0, _isak.pulse_effect_origin.y)
	return absf(p.y - o.y) <= WeakPoint.radius_px() - 2.0 and absf(p.x - o.x) < 700.0 \
		and signf(p.x - o.x) == _isak.facing


func _laser_reaches_rect(r: Rect2) -> bool:
	var y: float = _isak.global_position.y + _isak.pulse_effect_origin.y
	return y > r.position.y + 2.0 and y < r.end.y - 2.0 and signf(r.get_center().x - _isak.global_position.x) == _isak.facing


func _down_half() -> float:
	var s: Array = (_boss_cfg.get("arena", {}) as Dictionary).get("body_down_px", [128, 128])
	return float(s[1]) * 0.5


func _phone_dy() -> float:
	var off: Array = (_boss_cfg.get("arena", {}) as Dictionary).get("core_offset_px", [0, -56])
	return -float(off[1])


func _col_x(col: int) -> float:
	return (float(col) + 0.5) * _tile


# --- Entrada ---

func _tap(action: StringName) -> void:
	if not _taps.has(action):
		_taps.append(action)


func _release_taps() -> void:
	for action: StringName in _held_taps:
		Input.action_release(action)
	_held_taps.clear()
	_pulse_cd = maxi(_pulse_cd - 1, 0)
	_laser_cd = maxi(_laser_cd - 1, 0)
	_dash_tap_cd = maxi(_dash_tap_cd - 1, 0)
	_debug_tap_cd = maxi(_debug_tap_cd - 1, 0)


func _apply_inputs() -> void:
	_last_debug_want = _debug_want
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
	var layer: StringName = StringName("boss_w1_l%d" % _lap)
	var ok: bool = true
	var checks: Array = [
		["1-boss completado", GameState.is_level_completed(&"1-boss")],
		["recuerdo %s sin guardar" % layer, GameState.has_memory(layer) and GameState.has_unsaved_changes()],
		["Mundo 2 desbloqueado", HubWorlds.is_world_unlocked(HubWorlds.world(&"m2"))],
	]
	# La pieza cian depende de la carpeta del acceso actual: solo Caché tiene hoy
	# la fila del jefe (los subniveles de Kernel y Raíz aun no existen).
	if _lap == 1:
		checks.append(["pieza cian encendida", hub.get_background_state() == &"on"])
	var parts: PackedStringArray = []
	for c: Array in checks:
		parts.append("%s %s" % [c[0], "si" if c[1] else "NO"])
		ok = ok and bool(c[1])
	_note("hub tras la pelea: " + ", ".join(parts))
	if _profile == "ideal" and _deaths > 0:
		_note("FALLO: el perfil ideal muere %d veces" % _deaths)
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
	var label: String = "play_boss_bot (%s, %s)" % [ACCESS_NAMES.get(_lap, "?"), _profile]
	print("%s: %s" % [label, "OK" if ok else "FALLO"])
	for line: String in _log:
		print("  " + line)
	if _started:
		var phases: PackedStringArray = []
		for p: int in [1, 2, 3]:
			var w: Dictionary = _windows.get(p, {})
			phases.append("F%d %.1f s, %d ventanas, %d golpes, energia min %.0f" % [p,
				float(_phase_frames.get(p, 0)) / 60.0, int(w.get("windows", 0)), int(w.get("hits", 0)),
				float(_min_energy_phase.get(p, INF)) if _min_energy_phase.has(p) else -1.0])
		print("  RESULTADO: pelea %.1f s (objetivo %.0f s), golpes %d, muertes %d, energia minima %.0f (en ventana %.0f; margen del validador %.1f), Debug cortado en ventana %d" % [
			_fight_s(), _target_s, _hits, _deaths, _min_energy if _min_energy != INF else -1.0,
			_min_energy_window if _min_energy_window != INF else -1.0, VALIDATOR_MARGIN.get(_lap, 0.0),
			_debug_cut_in_window])
		print("  ACCIONES: dashes %d, laseres %d, pulsos %d, Debug %.1f s, cargas %d" % [_dashes, _lasers, _pulses,
			float(_debug_frames) / 60.0, _charges])
		print("  FASES: " + "; ".join(phases))
	finished.emit(0 if ok else 1)


func _note(text: String) -> void:
	_log.append(text)
	if _verbose:
		print("[boss_bot %.1f] %s" % [_fight_s(), text])


func _state_label() -> String:
	if _boss == null:
		return "?"
	return "mov %s, ronda %s, ventana %s" % [_boss.get_move(), _boss.get_round_state(), _boss.is_window_open()]


func _nearest_hazard() -> String:
	if _boss == null or _isak == null:
		return "?"
	var body: Rect2 = LevelLookup.isak_body_rect(_isak)
	for h: Dictionary in _moving_hazards():
		if (h["rect"] as Rect2).grow(24.0).intersects(body):
			return "barrido o notificacion"
	for bell: AlarmBell in _bells():
		if bell.is_wave() and bell.get_wave_rect().grow(16.0).intersects(body):
			return "campana"
	if _boss.get_round_state() == &"launch":
		return "lanzamiento"
	for b: AlertBubble in _boss.get_bubbles():
		if b.get_damage_rect().grow(16.0).intersects(body):
			return "Burbuja"
	return "otro"


func _trace_line() -> void:
	var bs: PackedStringArray = []
	for b: AlertBubble in _boss.get_bubbles():
		bs.append("(%.0f,%.0f %s %.1f)" % [b.global_position.x, b.global_position.y, b.get_state(), b.get_stun_left()])
	print("[trace %.1f] isak (%.0f,%.0f) %s %s v(%.0f,%.0f) e%.0f axis %.2f jump %s dbg %s/%s hold %s | boss %s %s ventana %s %.1f | burbujas %s" % [
		_fight_s(), _isak.global_position.x, _isak.global_position.y, _isak_surface(), _isak.get_state_name(),
		_isak.velocity.x, _isak.velocity.y, GameState.debug_energy, _axis, _jump, DebugMode.is_active(), DebugMode.get_state(), _debug_hold,
		_boss.get_move(), _boss.get_round_state(), _boss.is_window_open(), _boss.get_window_time_left(), " ".join(bs)])


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
