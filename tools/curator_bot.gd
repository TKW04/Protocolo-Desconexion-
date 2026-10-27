## Bot del jefe La Curadora (paso 18 de docs/propuesta-mundo-3.md §8, 2026-10-27;
## §7.3). Carga la escena principal (scenes/main.tscn, LevelRunner) en la arena
## 3-boss real y pelea con el Isak real pulsando SOLO acciones del Input Map
## (move_left / move_right, jump, run, pulse, laser, debug, gesture_swipe,
## gesture_pinch —Pellizcar— y ui_accept para cerrar las lineas importantes y la
## recompensa); nunca Q ni pause, nunca teletransporta, no toca GameState durante
## la pelea ni llama a la API de dano del jefe. Como los bots de Alerta Mayor
## (tools/boss_bot.gd) y Autoplay (tools/autoplay_bot.gd) es REACTIVO: una
## politica por fase que cada cuadro lee la API de Curator / BossBase / WeakPoint
## (get_phase, get_attack_state, is_window_open, get_window_side, get_core,
## get_crop_rect, get_spike_rects, is_flash_warning, get_hunter_corner,
## get_frame_state, get_frame_side, get_reflections, get_hearts...).
##
## Geometria (de la arena y del jefe, por lado izquierdo / derecho): repisa sobre
## el marco pequeno (filas 8 / 9, columnas 1-2 y 17-18), plataforma de likes
## (columnas 3-5 y 14-16, fila 6, de una via: se sube por la repisa), biombo sobre
## la repisa, cargadores en el suelo.
## - Fase 1 «Sesion de fotos»: espera en la repisa detras del biombo (tapa el
##   flash de la lente; los pinchos del filtro estan en el suelo). Ante el recorte
##   (franja centrada en Isak) salta a la plataforma de likes; si la franja la
##   pilla, al suelo fuera de ella. Ventana: plataforma del lado de la lente
##   (Kernel: al azar; cruza la arena si toca), Debug -> pulso que marca -> soltar
##   el Debug -> laser mientras dura la marca. Recoge los corazones de su lado
##   cuando nada amenaza y recarga en el cargador de su lado si le falta energia.
## - Fase 2 «De espaldas»: espera en el suelo bajo la plataforma de likes (tapa el
##   flash reflejado desde las dos esquinas) sobre el cargador, sale del recorte
##   y aturde a los Ladrones de likes con el pulso si avisan o persiguen. Ventana
##   (posa): Debug, junto al espejo cazador de su lado, espera a que el cazador
##   (que gira hacia Isak desde el norte) mire al espejo de esquina, pulso (lo
##   congela y marca la espalda), soltar el Debug y laser al cazador (sigue el
##   mismo camino: el golpe). Si el cazador ya paso de la esquina, se aparta de su
##   radio para que vuelva al norte.
## - Fase 3 «Retrato perfecto»: espera junto al marco pequeno de su lado; el pulso
##   aturde al Reflejo falso cuando se acerca (y otra vez antes de que despierte).
##   Con el marco que se cierra en su mitad, Pellizcar y meterse en el marco
##   pequeno; tras el cierre, Debug ya, salir, recuperar el tamano, repisa,
##   plataforma, pulso, laser, y vuelta al marco.
##
## Perfiles (--profile):
## - ideal: pelea limpia (Debug solo hasta la marca, un golpe por ventana).
## - clumsy (torpe): validation_model de data/bosses/curator.json (el modelo del
##   validador de arenas): golpes por ventana (laps.<n>.windows; 0 = ventana
##   perdida con early_debug_s de Debug), segundos de Debug por ventana
##   (laps.<n>.debug_s), un laser fallado por ventana (misses_per_window: sin
##   marca, chispa gris o al cazador sin congelar) y un dash por ventana
##   (dashes_per_window: al bajar tras la ventana).
## - idle (quieto): no hace nada (solo cierra las lineas): debe perder.
## Accesos (--lap 1|2|3): GameState.lap antes de cargar; la Curadora lee laps.<n>.
##
## Mide: duracion de la pelea (tiempo de juego, desde que empieza hasta el golpe
## final) frente a target_duration_s y a la franja del paso 18 (Caché ideal
## 100-150 s), golpes, muertes, energia minima (toda la pelea, en ventana y por
## fase) y gasto por ventana frente al margen del validador, flashes que ciegan,
## cierres con Isak fuera de su refugio, corazones, likes al pisar una plataforma,
## pulsos, laseres, dashes y pellizcos; al final, la recompensa (boss_w3_l<n> sin
## guardar) y la vuelta al hub con 3-boss completado, el acertijo del hub
## pendiente (desde el paso 5 de docs/propuesta-hub-mundos-4-6.md el Mundo 4 queda
## oculto hasta instalar el upgrade, con la pagina 2 «en instalacion») y, en
## Caché, la pieza verde encendida. Usa user://bot_save.json (borrado al
## empezar). Lo lanza tools/play_boss_bot.gd -- --boss curator; lo ejecuta
## tests/test_curator_bot.gd.
extends Node

signal finished(code: int)

const MAIN_SCENE: String = "res://scenes/main.tscn"
const BOT_SAVE_PATH: String = "user://bot_save.json"
const BOSS_DATA: String = "res://data/bosses/curator.json"
const LEVEL_DATA: String = "res://data/levels/3-boss.json"
const LEVEL_ID: String = "3-boss"
const A_LEFT: StringName = &"move_left"
const A_RIGHT: StringName = &"move_right"
const A_JUMP: StringName = &"jump"
const A_RUN: StringName = &"run"
const A_PULSE: StringName = &"pulse"
const A_LASER: StringName = &"laser"
const A_DEBUG: StringName = &"debug"
const A_DASH: StringName = &"gesture_swipe"
const A_PINCH: StringName = &"gesture_pinch"
const A_ACCEPT: StringName = &"ui_accept"
const ALL_ACTIONS: Array[StringName] = [A_LEFT, A_RIGHT, A_JUMP, A_RUN, A_PULSE, A_LASER, A_DEBUG, A_DASH, A_PINCH]
const ACCESS_NAMES: Dictionary = {1: "Caché", 2: "Kernel", 3: "Raíz"}
const LEFT: String = "left"
const RIGHT: String = "right"
## Margen de energia del validador de arenas (tools/validate_boss.py, barra base
## 100, pelea torpe; paso 16, el minimo de las tres fases). Solo informe.
const VALIDATOR_MARGIN: Dictionary = {1: 45.0, 2: 42.5, 3: 40.0}
## Duracion pedida al bot ideal en Caché (paso 18, s de juego).
const IDEAL_CACHE_S: Vector2 = Vector2(100.0, 150.0)
const MAX_FIGHT_S: float = 600.0
const MAX_IDLE_S: float = 1200.0
const MAX_AFTER_S: float = 60.0
const LINE_READ_FRAMES: int = 10
## Radio del pulso (data/isak_abilities.json) y margen al apuntar.
const PULSE_RADIUS: float = 96.0
const REACH_MARGIN: float = 10.0
## Por debajo de esta energia va a recargar cuando nada amenaza.
const RECHARGE_BELOW: Dictionary = {"ideal": 45.0, "clumsy": 70.0}
## Distancia (px) del pie al borde de las superficies al ir y venir.
const EDGE_IN_PX: float = 20.0
const EDGE_OUT_PX: float = 26.0
## Margen (px) a cada lado del cuerpo frente al recorte y los pinchos.
const CROP_MARGIN_PX: float = 12.0
const SPIKE_MARGIN_PX: float = 8.0
## Separacion (px) del pie al espejo cazador para pulsarlo (lado izquierdo:
## a la izquierda de su caja; derecho, a la derecha).
const HUNTER_GAP_PX: float = 90.0
## Fase 3: el reflejo se vuelve a aturdir con menos de esto de aturdimiento.
const RESTUN_LEFT_S: float = 0.6

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
var _boss: Curator
var _tile: float = 64.0
var _floor_y: float = 640.0
## Geometria por lado: ledge (x0, x1), ledge_y, plat (x0, x1), plat_y, frame
## (Rect2), frame_x, inner (+1 / -1: de la pared al centro), launch_x (suelo),
## ledge_jump_x, pulse_x, home_floor_x, wait_x, charger_x.
var _geo: Dictionary = {}

# --- Entrada que se aplica al final de cada cuadro ---
var _axis: float = 0.0
var _run: bool = false
var _jump: bool = false
var _debug_hold: bool = false
var _debug_want: bool = false
var _want_small: bool = false
var _taps: Array[StringName] = []
var _held_taps: Array[StringName] = []
var _debug_tap_cd: int = 0
var _laser_cd: int = 0
var _pulse_cd: int = 0
var _dash_tap_cd: int = 0
var _pinch_cd: int = 0

# --- Estado ---
var _frame: int = 0
var _jumping: bool = false
var _jump_frames: int = 0
## Objetivo del salto en curso: {mode: ledge|plat|drop, side, x, away, from_y}.
var _air: Dictionary = {}
var _line_key: String = ""
var _line_frame: int = 0
var _hooked: bool = false
var _started: bool = false
var _defeated: bool = false
var _done: bool = false
var _after_frames: int = 0
var _game_over: bool = false
## Ventana actual: indice en la fase, golpes, laseres fallados, Debug (s reales).
var _win_index: int = -1
var _win_hits: int = 0
var _win_missed: int = 0
var _win_debug_s: float = 0.0
var _win_open: bool = false
var _win_dash_pending: bool = false
var _was_window: bool = false
var _recharging: bool = false
## Fase 2: el cazador ya paso de la esquina; hay que apartarse hasta que vuelva.
var _hunter_reset: bool = false
## Fase 1 y 3: lado de casa (donde espera).
var _home: String = LEFT
var _last_attack: StringName = &""

# --- Medidas ---
var _fight_frames: int = 0
var _hits: int = 0
var _hit_causes: Dictionary = {}
var _deaths: int = 0
var _min_energy: float = INF
var _min_energy_window: float = INF
var _min_energy_phase: Dictionary = {}
var _win_e0: float = 0.0
var _win_spend: float = 0.0
var _spend_phase: Dictionary = {}
var _debug_cut_in_window: int = 0
var _dashes: int = 0
var _lasers: int = 0
var _pulses: int = 0
var _pinches: int = 0
var _debug_frames: int = 0
var _charges: int = 0
var _flashes: int = 0
var _blinded: int = 0
var _frames_closed: int = 0
var _frames_unsafe: int = 0
var _hearts: int = 0
var _reflection_stuns: int = 0
var _thief_stuns: int = 0
var _likes_on_plat_min: int = 1 << 30
var _was_on_plat: bool = false
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
	EventBus.pulse_fired.connect(func(_a: Area2D) -> void: _pulses += 1)
	EventBus.compress_changed.connect(func(on: bool) -> void:
		if on:
			_pinches += 1)
	_runner = (load(MAIN_SCENE) as PackedScene).instantiate() as LevelRunner
	_runner.start_level_id = LEVEL_ID
	add_child(_runner)
	_note("perfil %s, acceso %s (vuelta %d)" % [_profile, ACCESS_NAMES[_lap], _lap])


## Progreso de quien acaba de completar el 3-3: Eco, Notas y Calc conocidos, las
## seis habilidades (con Pellizcar), los avisos vistos y el jefe del Mundo 3
## desbloqueado, en la vuelta pedida.
func _setup_progress() -> void:
	GameState.lap = _lap
	for ally: StringName in [GameState.ALLY_ECO, GameState.ALLY_NOTAS, GameState.ALLY_CALC]:
		GameState.meet_ally(ally)
	for ability: StringName in [GameState.ABILITY_PULSE, GameState.ABILITY_LASER, GameState.ABILITY_DEBUG,
			GameState.ABILITY_DASH, GameState.ABILITY_GROUND_POUND, GameState.ABILITY_COMPRESS]:
		GameState.obtain_ability(ability)
		GameState.seen_notices[ability] = true
	for id: StringName in [&"1-1", &"1-2", &"1-3", &"1-boss", &"2-1", &"2-2", &"2-3", &"2-boss", &"3-1", &"3-2", &"3-3"]:
		GameState.unlock_level(id)
		GameState.mark_level_completed(id)
	GameState.unlock_level(&"3-boss")


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
	if _boss.is_fighting():
		if not _started:
			_started = true
			_note("pelea: empieza (%s)" % _boss.get_counter_label())
		_fight_frames += 1
		_phase_frames[_boss.get_phase()] = int(_phase_frames.get(_boss.get_phase(), 0)) + 1
		_measure(delta)
		if _profile != "idle":
			_fight()
		if _trace and _fight_frames % 15 == 0:
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
			if node is Curator:
				_boss = node as Curator
				break
		if _boss != null:
			_hook_boss()


func _hook_boss() -> void:
	_hooked = true
	_tile = float(World3ObjectsConfig.tile_size())
	var arena: Dictionary = _boss_cfg.get("arena", {})
	var lane: Dictionary = (arena.get("lanes", {}) as Dictionary).get("floor", {})
	_floor_y = float(lane.get("surface_row", 10)) * _tile
	var plats: Dictionary = {}
	for node: Node in _all_nodes(_level):
		if node is LikePlatform:
			var card: Rect2 = (node as LikePlatform).get_card_rect()
			plats[_boss.side_of_x(card.get_center().x)] = card
	var chargers: Dictionary = {}
	for node: Node in _all_nodes(_level):
		if node is Charger:
			var cx: float = (node as Charger).global_position.x + _tile * 0.5
			var side: String = _boss.side_of_x(cx)
			# El de la pared (bajo la plataforma de likes).
			var wall_x: float = 0.0 if side == LEFT else 99999.0
			if not chargers.has(side) or absf(cx - wall_x) < absf(float(chargers[side]) - wall_x):
				chargers[side] = cx
	for side: String in [LEFT, RIGHT]:
		var fr: Rect2 = _boss.get_small_frame_rect(side)
		var card: Rect2 = plats.get(side, Rect2())
		var inner: float = 1.0 if side == LEFT else -1.0
		var ledge := Vector2(fr.position.x, fr.end.x)
		var ledge_inner: float = ledge.y if side == LEFT else ledge.x
		var plat := Vector2(card.position.x, card.end.x)
		var plat_inner: float = plat.y if side == LEFT else plat.x
		var plat_outer: float = plat.x if side == LEFT else plat.y
		var charger_x: float = float(chargers.get(side, ledge_inner + inner * 32.0))
		_geo[side] = {
			"inner": inner,
			"ledge": ledge, "ledge_y": fr.position.y - _tile, "ledge_inner": ledge_inner,
			"plat": plat, "plat_y": card.position.y, "plat_inner": plat_inner, "plat_outer": plat_outer,
			"frame": fr, "frame_x": fr.get_center().x,
			"launch_x": ledge_inner + inner * 24.0,
			"ledge_jump_x": ledge_inner - inner * 20.0,
			"ledge_home_x": ledge_inner - inner * 20.0,
			"pulse_x": plat_inner - inner * 14.0,
			"charger_x": charger_x,
			"wait_x": ledge_inner + inner * 44.0,
		}
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
	_boss.flashed.connect(func(blinded: bool) -> void:
		_flashes += 1
		if blinded:
			_blinded += 1
			_note("el flash ciega a Isak (fase %d, x %.0f, y %.0f)" % [_boss.get_phase(), _isak.global_position.x,
				_isak.global_position.y]))
	_boss.frame_closed.connect(func(side: String, safe: bool) -> void:
		_frames_closed += 1
		if not safe:
			_frames_unsafe += 1
			_note("el marco se cierra sobre Isak (%s, x %.0f, comprimido %s)" % [side, _isak.global_position.x,
				_isak.is_compressed()]))
	_boss.attack_started.connect(_on_attack)
	_boss.final_blow.connect(_on_final_blow)


func _on_hurt() -> void:
	_hits += 1
	var cause: String = _guess_cause()
	_hit_causes[cause] = int(_hit_causes.get(cause, 0)) + 1
	_note("golpe a Isak en la fase %d (%s; ataque %s; x %.0f, y %.0f; Sync %.0f)" % [
		_boss.get_phase() if _boss != null else 0, cause, _boss.get_attack_state() if _boss != null else &"?",
		_isak.global_position.x, _isak.global_position.y, GameState.sync_rate])


func _guess_cause() -> String:
	if _boss == null:
		return "?"
	var body: Rect2 = LevelLookup.isak_body_rect(_isak).grow(6.0)
	if _boss.is_crop_cutting() and _boss.get_crop_rect().intersects(body):
		return "recorte"
	for r: Rect2 in _boss.get_spike_rects():
		if r.intersects(body):
			return "pinchos"
	for refl: FalseReflection in _boss.get_reflections():
		if refl.is_present() and refl.get_body_rect_now().intersects(body):
			return "reflejo"
	if _boss.get_phase() == 3:
		return "marco"
	return "?"


func _on_window_opened(s: float) -> void:
	_win_index += 1
	_win_hits = 0
	_win_missed = 0
	_win_debug_s = 0.0
	_win_open = true
	_win_e0 = GameState.debug_energy
	_win_spend = 0.0
	_recharging = false
	_hunter_reset = false
	var p: int = _boss.get_phase()
	var w: Dictionary = _windows.get(p, {})
	w["windows"] = int(w.get("windows", 0)) + 1
	_windows[p] = w
	if _verbose:
		_note("ventana %d de la fase %d (%.1f s del mundo; lado %s; quiere %d golpes; %s, x %.0f; energia %.0f)" % [
			_win_index, p, s, _boss.get_window_side(), _window_goal(), _surface(), _isak.global_position.x,
			GameState.debug_energy])


func _on_window_closed() -> void:
	_win_open = false
	if _profile == "clumsy" and _window_dashes() > 0:
		_win_dash_pending = true
	if _verbose:
		_note("ventana cerrada (%d golpes; Debug %.1f s; gasto %.0f)" % [_win_hits, _win_debug_s, _win_spend])


func _on_phase_changed(phase: int) -> void:
	_note("fase %d a los %.1f s (%s; energia %.0f, likes %d)" % [phase, _fight_s(), _boss.get_counter_label(),
		GameState.debug_energy, GameState.likes])
	_reset_phase_state()


func _on_phase_restarted(phase: int) -> void:
	_note("reaparece: la fase %d vuelve a empezar (energia %.0f, likes %d)" % [phase, GameState.debug_energy,
		GameState.likes])
	_reset_phase_state()


func _reset_phase_state() -> void:
	_win_index = -1
	_win_hits = 0
	_win_open = false
	_win_dash_pending = false
	_recharging = false
	_hunter_reset = false
	_air = {}


func _on_attack(attack: StringName) -> void:
	_last_attack = attack
	if _verbose and attack != Curator.ATTACK_WINDOW:
		_note("ataque %s (fase %d, %.1f s)" % [attack, _boss.get_phase(), _fight_s()])


func _on_final_blow() -> void:
	_defeated = true
	_after_frames = 0
	_debug_hold = false
	_want_small = false
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
	if _boss.is_window_open():
		_min_energy_window = minf(_min_energy_window, e)
		_win_spend = maxf(_win_spend, _win_e0 - e)
		_spend_phase[p] = maxf(float(_spend_phase.get(p, 0.0)), _win_spend)
		if active:
			_win_debug_s += delta
		if _was_debug_active and not active and e <= GameState.DEBUG_ENERGY_MIN + 0.01:
			_debug_cut_in_window += 1
			_note("el Debug se corta sin energia en una ventana (fase %d)" % p)
	_was_debug_active = active
	var on_plat: bool = _surface() == &"plat"
	if on_plat and not _was_on_plat:
		_likes_on_plat_min = mini(_likes_on_plat_min, GameState.likes)
	_was_on_plat = on_plat


func _fight_s() -> float:
	return float(_fight_frames) / 60.0


# --- Politica ---

func _fight() -> void:
	if _isak.is_dead() or _isak.is_warping():
		_debug_hold = false
		_want_small = false
		_air = {}
		return
	_want_small = false
	var window: bool = _boss.is_window_open()
	if window:
		_was_window = true
	elif _was_window:
		_was_window = false
		_after_window()
	match _boss.get_phase():
		1:
			_phase1(window)
		2:
			_phase2(window)
		_:
			_phase3(window)


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


func _window_dashes() -> int:
	return int(_model_phase_value("dashes_per_window", 0.0))


## Segundos de Debug por ventana del torpe (debug_s de la vuelta y la fase).
func _clumsy_debug_s() -> float:
	var list: Array = _model_lap().get("debug_s", [3.0, 4.0, 4.0])
	return float(list[clampi(_boss.get_phase() - 1, 0, list.size() - 1)])


func _after_window() -> void:
	_hunter_reset = false


## Ventana: Debug segun el perfil (ideal: hasta la marca; torpe: debug_s); el
## torpe falla un laser antes de marcar.
func _window_debug(before_mark: bool) -> void:
	if _profile == "clumsy":
		_want_debug(_win_debug_s < _clumsy_debug_s() or before_mark)
	else:
		_want_debug(before_mark)


## Una ventana perdida del torpe: Debug early_debug_s y nada mas.
func _lost_window() -> bool:
	if _window_goal() != 0:
		return false
	_want_debug(_win_debug_s < _model_phase_value("early_debug_s", 2.0))
	return true


# --- Fase 1 «Sesion de fotos» ---

func _phase1(window: bool) -> void:
	if window and _win_hits < _window_goal() and not _lost_window():
		_platform_window(_boss.get_window_side())
		return
	if window and _lost_window():
		_hold_spot(_home)
		return
	_debug_off()
	var attack: StringName = _boss.get_attack_state()
	var crop: Rect2 = _boss.get_crop_rect()
	if crop.has_area():
		_escape_crop(crop)
		return
	if _clumsy_dash():
		return
	if _boss.is_flash_warning():
		_take_cover(_home)
		return
	# Filtro de suelo: fuera de los pinchos (la repisa o el suelo sin pincho); con
	# camino libre, recarga o corazones.
	if not _boss.get_spike_rects().is_empty():
		if _surface() == &"floor" and _spiked(_isak.global_position.x):
			var safe: float = _spike_free_x(_home)
			if safe != INF:
				_go(&"floor", _home, safe, 4.0)
			else:
				_go(&"ledge", _home, _g(_home, "ledge_home_x"))
			return
		if _need_recharge() and _try_recharge(_home, true):
			return
		if _collect_hearts(_home):
			return
		# En el suelo sin pincho se queda (el recorte que viene se esquiva andando).
		if _surface() == &"floor":
			_axis = 0.0
			return
		_go(&"ledge", _home, _g(_home, "ledge_home_x"))
		return
	# Tras el filtro viene el recorte: nada de excursiones ni de subir a medias.
	if _last_attack == Curator.ATTACK_FLOOR_FILTER and _surface() == &"floor":
		_axis = 0.0
		return
	if _last_attack != Curator.ATTACK_FLOOR_FILTER:
		if _need_recharge() and _try_recharge(_home, false):
			return
		if _collect_hearts(_home):
			return
	_go(&"ledge", _home, _g(_home, "ledge_home_x"))


## A cubierto del flash de la lente: en el suelo, bajo la plataforma de likes; si
## no, la repisa detras del biombo.
func _take_cover(side: String) -> void:
	if _surface() == &"floor":
		var x: float = _under_plat_x(side, _isak.global_position.x)
		if x != INF:
			_go(&"floor", side, x, 6.0)
			return
	_go(&"ledge", side, _g(side, "ledge_home_x"))


## x del suelo bajo la plataforma de `side` mas cerca de `near` (sin pincho ni
## recorte); INF si no hay.
func _under_plat_x(side: String, near: float) -> float:
	var plat: Vector2 = _g(side, "plat")
	var crop: Rect2 = _boss.get_crop_rect()
	var best: float = INF
	var x: float = plat.x + 18.0
	while x <= plat.y - 18.0:
		var ok: bool = _floor_ok(x) and not _spiked(x)
		if ok and crop.has_area() and x + 16.0 + CROP_MARGIN_PX > crop.position.x and x - 16.0 - CROP_MARGIN_PX < crop.end.x:
			ok = false
		if ok and (best == INF or absf(x - near) < absf(best - near)):
			best = x
		x += 4.0
	return best


## x del suelo de `side` sin pincho mas cerca, sin cruzar pinchos; INF si no hay.
func _spike_free_x(side: String) -> float:
	var ix: float = _isak.global_position.x
	var best: float = INF
	var half: Rect2 = _boss.get_half_rect(side)
	var x: float = half.position.x
	while x <= half.end.x:
		if _floor_ok(x) and not _spiked(x) and _floor_path_clear(ix, x, true) \
				and (best == INF or absf(x - ix) < absf(best - ix)):
			best = x
		x += 4.0
	return best


## Andar por el suelo de `a` a `b` no toca ningun pincho del filtro.
## (`leaving`: sin contar el pincho que ya pisa en `a`, del que esta saliendo).
func _floor_path_clear(a: float, b: float, leaving: bool = false) -> bool:
	var lo: float = minf(a, b) - 16.0 - SPIKE_MARGIN_PX
	var hi: float = maxf(a, b) + 16.0 + SPIKE_MARGIN_PX
	for r: Rect2 in _boss.get_spike_rects():
		if leaving and r.end.x > a - 16.0 - SPIKE_MARGIN_PX and r.position.x < a + 16.0 + SPIKE_MARGIN_PX:
			continue
		if r.end.x > lo and r.position.x < hi:
			return false
	return true


## x del suelo a la que se llega desde la superficie actual (al bajar por dentro).
func _floor_entry_x() -> float:
	var side: String = _side_here()
	match _surface():
		&"ledge":
			return float(_g(side, "ledge_inner")) + float(_g(side, "inner")) * 36.0
		&"plat":
			return float(_g(side, "plat_inner")) + float(_g(side, "inner")) * 48.0
	return _isak.global_position.x


## Sale de la franja del recorte por el camino mas corto: en el suelo, andando
## fuera de ella; en la repisa, a la plataforma (fase 1) o al suelo; en la
## plataforma, a su otra punta o a la repisa.
func _escape_crop(crop: Rect2) -> void:
	var pad: float = CROP_MARGIN_PX + 16.0
	var lo: float = crop.position.x - pad
	var hi: float = crop.end.x + pad
	var ix: float = _isak.global_position.x
	var side: String = _side_here()
	var s: StringName = _surface()
	if ix <= lo or ix >= hi:
		_axis = 0.0
		if s == &"air":
			_air_control()
		return
	var options: Array = []
	match s:
		&"floor", &"air":
			for x: float in [hi + 4.0, lo - 4.0]:
				if _floor_ok(x):
					options.append([absf(x - ix), &"floor", x])
		&"ledge":
			# Bajar por dentro y correr es mas rapido que el arco hasta la plataforma.
			if _floor_ok(hi + 4.0):
				options.append([300.0, &"floor", hi + 4.0])
			if _boss.get_phase() == 1:
				options.append([400.0, &"plat", _g(side, "pulse_x")])
		&"plat":
			var plat: Vector2 = _g(side, "plat")
			for x: float in [plat.x + 18.0, plat.y - 18.0]:
				options.append([absf(x - ix), &"plat", x])
			options.append([600.0, &"ledge", _g(side, "ledge_home_x")])
	options.sort_custom(func(a: Array, b: Array) -> bool: return float(a[0]) < float(b[0]))
	for opt: Array in options:
		var x: float = float(opt[2])
		if x > lo and x < hi:
			continue
		_go(opt[1], side, x, 6.0)
		_run = true
		return
	_go(&"floor", side, hi + 4.0)
	_run = true


## Una x del suelo donde cabe Isak de pie (no bajo una repisa ni contra un muro).
func _floor_ok(x: float) -> bool:
	for side: String in [LEFT, RIGHT]:
		var ledge: Vector2 = _g(side, "ledge")
		if x > ledge.x - 18.0 and x < ledge.y + 18.0:
			return false
	return x > _g(LEFT, "ledge").y + 18.0 and x < _g(RIGHT, "ledge").x - 18.0


## Ventana de las fases 1 y 3: plataforma de `side`, Debug -> pulso -> soltar el
## Debug -> laser.
func _platform_window(side: String) -> void:
	var core: WeakPoint = _boss.get_core()
	var marked: bool = core != null and core.is_marked()
	_window_debug(not marked)
	if _boss.get_phase() == 3 and _reflection_reflex(false):
		return
	var at_spot: bool = _surface() == &"plat" and _side_here() == side \
		and absf(_isak.global_position.x - _g(side, "pulse_x")) <= 14.0
	if not at_spot:
		_go(&"plat", side, _g(side, "pulse_x"), 4.0)
		return
	_axis = 0.0
	var dir: float = _g(side, "inner")
	if _isak.facing != dir:
		_axis = dir * 0.2
		return
	if not marked:
		if _profile == "clumsy" and _win_missed < int(_model.get("misses_per_window", 1)):
			if _try_laser():
				_win_missed += 1
			return
		if DebugMode.is_active() and core != null and core.is_enabled():
			_try_pulse()
		return
	# Marcado: ideal suelta el Debug y dispara cuando se ha apagado; el torpe
	# dispara con el Debug que le quede.
	if _profile != "clumsy" and DebugMode.is_active():
		return
	_try_laser()


# --- Fase 2 «De espaldas» ---

func _phase2(window: bool) -> void:
	if window and _win_hits < _window_goal() and not _lost_window():
		_hunter_window()
		return
	if window and _lost_window():
		_go(&"floor", _home, _g(_home, "charger_x"))
		return
	_debug_off()
	if _thief_reflex():
		return
	var crop: Rect2 = _boss.get_crop_rect()
	if crop.has_area():
		_escape_crop(crop)
		return
	if _clumsy_dash():
		return
	_go(&"floor", _home, _cover_x(_home))


## x del suelo bajo la plataforma de `side` (tapa el flash reflejado) lo mas
## cerca del cargador, fuera del recorte.
func _cover_x(side: String) -> float:
	var plat: Vector2 = _g(side, "plat")
	var best: float = _g(side, "charger_x")
	var crop: Rect2 = _boss.get_crop_rect()
	var x: float = plat.x + 18.0
	var found: float = INF
	while x <= plat.y - 18.0:
		var ok: bool = _floor_ok(x)
		if ok and crop.has_area() and x + 16.0 + CROP_MARGIN_PX > crop.position.x and x - 16.0 - CROP_MARGIN_PX < crop.end.x:
			ok = false
		if ok and (found == INF or absf(x - best) < absf(found - best)):
			found = x
		x += 4.0
	return found if found != INF else best


## Ventana de la fase 2: junto al cazador de su lado; con el Debug, pulso cuando
## mira al espejo de esquina; soltar el Debug y laser al cazador.
func _hunter_window() -> void:
	var hunter: HunterMirror = _boss.get_hunter()
	var core: WeakPoint = _boss.get_core()
	if hunter == null or core == null:
		return
	var marked: bool = core.is_marked()
	_window_debug(not marked)
	var hr: Rect2 = hunter.get_hit_rect()
	var side: String = _side_here()
	var dir: float = 1.0 if side == LEFT else -1.0
	var spot: float = hr.position.x - HUNTER_GAP_PX if side == LEFT else hr.end.x + HUNTER_GAP_PX
	var corner: String = _boss.get_hunter_corner()
	var facing: int = hunter.get_facing_index()
	var rest: int = HunterMirror.facing_index(hunter.get_rest_facing_name())
	if marked:
		if not hunter.is_frozen():
			# La marca sigue pero el cazador ya no mira a la esquina: espera.
			pass
		if _profile != "clumsy" and DebugMode.is_active():
			_hold_x(spot, dir)
			return
		if _hold_x(spot, dir) and hunter.is_frozen() and corner == side:
			_try_laser()
		return
	if _thief_reflex():
		return
	# El cazador ya paso de la esquina (mira a Isak): fuera de su radio hasta que
	# vuelva al norte.
	if not hunter.is_frozen() and facing != rest and corner != side:
		_hunter_reset = true
	if _hunter_reset:
		if facing == rest:
			_hunter_reset = false
		else:
			var out: float = hunter.get_center().x - dir * (hunter.get_track_radius_px() + 40.0)
			_go(&"floor", side, out, 10.0)
			return
	if not _hold_x(spot, dir):
		return
	if _profile == "clumsy" and _win_missed < int(_model.get("misses_per_window", 1)) and corner != side:
		if _try_laser():
			_win_missed += 1
		return
	if corner == side and not hunter.is_frozen() and DebugMode.is_active():
		_try_pulse()


## Quieto en `x` mirando a `dir`. Verdadero si ya esta.
func _hold_x(x: float, dir: float) -> bool:
	if _surface() != &"floor" or absf(_isak.global_position.x - x) > 10.0:
		_go(&"floor", _side_of(x), x, 6.0)
		return false
	_axis = 0.0
	if _isak.facing != dir:
		_axis = dir * 0.2
		return false
	return true


## Ladrones de likes: el pulso los aturde si avisan o persiguen y estan a tiro.
func _thief_reflex() -> bool:
	if not _can_pulse_now():
		return false
	for node: Node in _all_nodes(_level):
		var t := node as LikeThief
		if t == null or not BossBase.is_phase_node_active(t) or t.is_defeated() or t.is_stunned():
			continue
		if not (t.is_noticing() or t.is_chasing()):
			continue
		var r: Rect2 = t.get_body_rect()
		if not _pulse_reaches_rect(r):
			if absf(r.get_center().x - _isak.global_position.x) < 140.0:
				_face_x(r.get_center().x)
			continue
		if _try_pulse():
			_thief_stuns += 1
			return true
	return false


# --- Fase 3 «Retrato perfecto» ---

func _phase3(window: bool) -> void:
	var frame_state: StringName = _boss.get_frame_state()
	if window and _win_hits < _window_goal() and not _lost_window():
		_want_small = false
		_platform_window(_boss.get_window_side())
		return
	if window and _lost_window():
		_go_frame(_home)
		return
	_debug_off()
	if _surface() == &"floor" and not _isak.is_compressed():
		_home = _side_here()
	if frame_state != Curator.FRAME_IDLE:
		var fside: String = _boss.get_frame_side()
		if _boss.side_of_x(_isak.global_position.x) == fside:
			_home = fside
			_go_frame(fside)
			return
	if _clumsy_dash():
		return
	if not _isak.is_compressed() and _reflection_reflex(false):
		return
	if _need_recharge() and not _isak.is_compressed() and _try_recharge(_home, false):
		return
	# Espera comprimido dentro del marco pequeno de su lado: el reflejo que lo
	# sigue se borra al entrar y el marco que se cierra no le alcanza.
	_go_frame(_home)


## Reflejos falsos: el pulso los aturde cuando se acercan (y otra vez antes de
## que despierten). Si va a despertar fuera de alcance con Isak quieto (saldria
## donde estaba Isak hace su retraso: encima), echa a andar para que despierte
## detras y luego se le aturde al acercarse. Verdadero si este cuadro se ocupa.
func _reflection_reflex(allow_walk: bool = true) -> bool:
	var ib: Rect2 = LevelLookup.isak_body_rect(_isak)
	for r: FalseReflection in _boss.get_reflections():
		if not r.is_present():
			continue
		var body: Rect2 = r.get_body_rect_now()
		if not body.has_area():
			continue
		var dx: float = body.get_center().x - _isak.global_position.x
		var near: bool = absf(dx) <= 150.0 and absf(body.get_center().y - ib.get_center().y) <= 120.0
		if r.is_stunned():
			if r.get_stun_left() > RESTUN_LEFT_S:
				continue
			if near and _can_pulse_now() and _pulse_reaches_rect(body):
				if _try_pulse():
					_reflection_stuns += 1
				return true
			var wake_in: float = r.get_stun_left() / maxf(WorldTime.scale(), 0.05)
			if allow_walk and wake_in < 0.9 and _surface() == &"floor":
				_walk_away()
				return true
			continue
		if not near or not _can_pulse_now():
			continue
		if _pulse_reaches_rect(body):
			if _try_pulse():
				_reflection_stuns += 1
				return true
			continue
		# Mirar hacia el (el pulso sale del celular).
		if signf(dx) != _isak.facing and absf(dx) < 110.0:
			_axis = signf(dx) * 0.2
			return true
	return false


## Anda (sin correr) hacia donde hay sitio en su mitad.
func _walk_away() -> void:
	var half: Rect2 = _boss.get_half_rect(_home)
	var ix: float = _isak.global_position.x
	var dir: float = float(_g(_home, "inner"))
	var wall_x: float = float(_g(_home, "launch_x"))
	if absf(ix - wall_x) > half.size.x * 0.5:
		dir = -dir
	if dir > 0.0 and ix > half.end.x - 60.0 or dir < 0.0 and ix < half.position.x + 60.0:
		dir = -dir
	_axis = dir
	_run = false


## Comprimido dentro del marco pequeno de `side`.
func _go_frame(side: String) -> void:
	var fr: Rect2 = _g(side, "frame")
	var fx: float = _g(side, "frame_x")
	var ix: float = _isak.global_position.x
	if _surface() != &"floor":
		_go(&"floor", side, _g(side, "launch_x"), 30.0)
		return
	if not _isak.is_compressed():
		if absf(ix - fx) < 170.0:
			_want_small = true
		_axis = _p_axis(fx - ix, 50.0)
		_run = absf(fx - ix) > 120.0
		return
	_want_small = true
	_axis = _p_axis(fx - ix, 40.0)
	if fr.grow(2.0).encloses(LevelLookup.isak_body_rect(_isak)) and absf(fx - ix) < 6.0:
		_axis = 0.0


func _in_frame() -> bool:
	for side: String in [LEFT, RIGHT]:
		if (_g(side, "frame") as Rect2).grow(2.0).encloses(LevelLookup.isak_body_rect(_isak)):
			return true
	return false


# --- Comun ---

## Quieto en la repisa (o donde toque) en una ventana perdida.
func _hold_spot(side: String) -> void:
	var crop: Rect2 = _boss.get_crop_rect()
	if crop.has_area():
		_escape_crop(crop)
		return
	_go(&"ledge", side, _g(side, "ledge_home_x"))


func _need_recharge() -> bool:
	if _recharging:
		if GameState.debug_energy >= GameState.get_debug_energy_max() - 8.0:
			_recharging = false
		return _recharging
	if GameState.debug_energy < float(RECHARGE_BELOW.get(_profile, 45.0)):
		_recharging = true
	return _recharging


## Va al cargador listo de su lado (sin pincho si `spikes`). Falso si no hay.
func _try_recharge(side: String, spikes: bool) -> bool:
	var best: Charger = null
	var ix: float = _isak.global_position.x
	for node: Node in _all_nodes(_level):
		var c := node as Charger
		if c == null or not c.is_ready():
			continue
		var cx: float = c.global_position.x + _tile * 0.5
		if _boss.side_of_x(cx) != side:
			continue
		if spikes and (_spiked(cx) or not _floor_path_clear(_floor_entry_x(), cx)):
			continue
		if best == null or absf(cx - ix) < absf(best.global_position.x + _tile * 0.5 - ix):
			best = c
	if best == null:
		return false
	_go(&"floor", side, best.global_position.x + _tile * 0.5, 6.0)
	return true


func _spiked(x: float) -> bool:
	for r: Rect2 in _boss.get_spike_rects():
		if x + 16.0 + SPIKE_MARGIN_PX > r.position.x and x - 16.0 - SPIKE_MARGIN_PX < r.end.x:
			return true
	return false


## Corazones de su lado en el suelo con camino libre de pinchos y fuera del
## recorte. Verdadero si va.
func _collect_hearts(side: String, near: float = INF, reach: float = INF) -> bool:
	if _boss.get_crop_rect().has_area():
		return false
	var from: float = _floor_entry_x()
	var best: HeartPickup = null
	for h: HeartPickup in _boss.get_hearts():
		if not h.can_be_collected():
			continue
		var hx: float = h.get_center().x
		if _boss.side_of_x(hx) != side or not _floor_ok(hx):
			continue
		if _spiked(hx) or not _floor_path_clear(from, hx):
			continue
		if near != INF and absf(hx - near) > reach:
			continue
		if best == null or absf(hx - from) < absf(best.get_center().x - from):
			best = h
	if best == null:
		return false
	_go(&"floor", side, best.get_center().x, 4.0)
	return true


## Torpe: un dash por ventana al bajar de ella (en el suelo, hacia casa).
func _clumsy_dash() -> bool:
	if not _win_dash_pending:
		return false
	if _surface() != &"floor":
		return false
	if not _dash_ready():
		return false
	var target: float = _g(_home, "charger_x")
	var dx: float = target - _isak.global_position.x
	var dir: float = signf(dx) if absf(dx) > 40.0 else -_g(_home, "inner")
	if _try_dash(dir):
		_win_dash_pending = false
		return true
	return false


# --- Movimiento ---

func _g(side: String, key: String) -> Variant:
	return (_geo.get(side, {}) as Dictionary).get(key)


func _side_of(x: float) -> String:
	return _boss.side_of_x(x)


func _side_here() -> String:
	return _side_of(_isak.global_position.x)


## floor, ledge, plat o air.
func _surface() -> StringName:
	if _isak == null or not _isak.is_on_floor():
		return &"air"
	var y: float = _isak.global_position.y
	if absf(y - _floor_y) < 10.0:
		return &"floor"
	var side: String = _side_here()
	if absf(y - float(_g(side, "ledge_y"))) < 10.0:
		return &"ledge"
	if absf(y - float(_g(side, "plat_y"))) < 10.0:
		return &"plat"
	return &"floor"


## Va a la superficie `kind` (floor, ledge, plat) de `side` y a `x` en ella.
## Verdadero si ya esta (quieto).
func _go(kind: StringName, side: String, x: float, tol: float = 8.0) -> bool:
	var s: StringName = _surface()
	var ix: float = _isak.global_position.x
	if s == &"air":
		_air_control()
		return false
	# Comprimido fuera del marco: sale hacia dentro y pide recuperar el tamano.
	if _isak.is_compressed():
		_want_small = false
		var fr_side: String = _side_here()
		var out_x: float = float(_g(fr_side, "launch_x")) + float(_g(fr_side, "inner")) * 6.0
		var ledge: Vector2 = _g(fr_side, "ledge")
		if ix > ledge.x - 18.0 and ix < ledge.y + 18.0:
			_axis = _p_axis(out_x - ix, 30.0)
			return false
	var here: String = _side_here()
	match s:
		&"plat":
			if kind == &"plat" and here == side:
				return _walk_to(x, tol)
			if kind == &"ledge" and here == side:
				_walk_off(float(_g(here, "plat_outer")), -float(_g(here, "inner")), side, x)
				return false
			_walk_off(float(_g(here, "plat_inner")), float(_g(here, "inner")), side, x)
			return false
		&"ledge":
			if kind == &"ledge" and here == side:
				return _walk_to(x, tol)
			if kind == &"plat" and here == side:
				var jx: float = _g(side, "ledge_jump_x")
				if absf(ix - jx) > 8.0:
					_walk_to(jx, 4.0)
					return false
				_launch(&"plat", side, x)
				return false
			_walk_off(float(_g(here, "ledge_inner")), float(_g(here, "inner")), side, x)
			return false
	# En el suelo.
	if kind == &"floor":
		return _walk_to(x, tol)
	var lx: float = _g(side, "launch_x")
	if absf(ix - lx) > 6.0 or absf(_isak.velocity.x) > 40.0:
		_walk_to(lx, 3.0)
		return false
	if _isak.is_compressed():
		return false
	_launch(&"ledge", side, x)
	return false


## Sale andando por el borde `edge` hacia `dir` (cae a la superficie de abajo).
func _walk_off(edge: float, dir: float, side: String, goal_x: float) -> void:
	_axis = dir
	_run = false
	_air = {"mode": &"drop", "side": side, "x": goal_x, "away": dir, "from_y": _isak.global_position.y}


func _launch(mode: StringName, side: String, x: float) -> void:
	_start_jump()
	_air = {"mode": mode, "side": side, "x": x, "from_y": _isak.global_position.y}


func _air_control() -> void:
	var ix: float = _isak.global_position.x
	var fy: float = _isak.global_position.y
	match StringName(_air.get("mode", &"")):
		&"ledge":
			var side: String = _air["side"]
			var ly: float = _g(side, "ledge_y")
			if fy < ly - 6.0:
				var tx: float = float(_g(side, "ledge_jump_x")) - float(_g(side, "inner")) * 14.0
				_axis = _p_axis(tx - ix, 40.0)
			else:
				_axis = 0.0
		&"plat":
			var side2: String = _air["side"]
			var plat: Vector2 = _g(side2, "plat")
			var tx2: float = clampf(float(_air["x"]), plat.x + 18.0, plat.y - 16.0)
			_axis = _p_axis(tx2 - ix, 50.0)
			_run = absf(tx2 - ix) > 100.0
		&"drop":
			if fy < float(_air["from_y"]) + 48.0:
				_axis = float(_air["away"])
			else:
				_axis = _p_axis(float(_air["x"]) - ix, 60.0)
				_run = true
		_:
			_axis = 0.0


func _walk_to(x: float, tol: float) -> bool:
	var dx: float = x - _isak.global_position.x
	if absf(dx) <= maxf(tol, 2.0):
		_axis = 0.0
		return absf(_isak.velocity.x) < 30.0 and _isak.is_on_floor()
	_axis = _p_axis(dx, 40.0)
	_run = absf(dx) > 140.0 and not _isak.is_compressed()
	return false


## Eje proporcional a la distancia (frena al llegar).
func _p_axis(dx: float, span: float) -> float:
	if absf(dx) < 2.0:
		return 0.0
	var a: float = clampf(dx / span, -1.0, 1.0)
	if absf(a) < 0.25:
		a = signf(a) * 0.25
	return a


func _start_jump() -> void:
	if _jumping or not _isak.is_on_floor():
		return
	_jumping = true
	_jump_frames = 0
	_jump = true


func _update_jump() -> void:
	if not _jumping:
		_jump = false
		if _isak != null and _isak.is_on_floor() and _air.get("mode", &"") != &"drop":
			_air = {}
		elif _isak != null and _isak.is_on_floor() and absf(_isak.global_position.y - float(_air.get("from_y", 0.0))) > 20.0:
			_air = {}
		return
	_jump_frames += 1
	_jump = _jump_frames < 26 and (_jump_frames < 3 or _isak.velocity.y < 0.0)
	if (_jump_frames > 4 and _isak.is_on_floor()) or _jump_frames > 120:
		_jumping = false
		_jump = false
		_air = {}


func _face_x(x: float) -> void:
	var want: float = signf(x - _isak.global_position.x)
	if want != 0.0 and want != _isak.facing and _axis == 0.0:
		_axis = want * 0.2


func _pulse_center() -> Vector2:
	return _isak.global_position + _isak.get_pulse_origin()


func _pulse_reaches_rect(r: Rect2) -> bool:
	var o: Vector2 = _pulse_center()
	var closest := Vector2(clampf(o.x, r.position.x, r.end.x), clampf(o.y, r.position.y, r.end.y))
	return o.distance_to(closest) <= PULSE_RADIUS - REACH_MARGIN


# --- Acciones ---

func _can_pulse_now() -> bool:
	return _pulse_cd <= 0 and _isak.can_pulse() and not _isak.is_dashing() and not _isak.is_laser_posing() \
		and _isak.get_state_name() != PlayerState.PULSE and _isak.get_state_name() != PlayerState.HURT


func _try_pulse() -> bool:
	if not _can_pulse_now():
		return false
	_tap(A_PULSE)
	_pulse_cd = 8
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


func _dash_ready() -> bool:
	if _isak.is_dashing() or _isak.get_dash_cooldown_left() > 0.0 or DebugMode.is_engaged() \
			or GameState.debug_energy < 10.0 or _isak.is_laser_posing() or _isak.is_dead() \
			or _isak.is_compressed() or _isak.get_state_name() == PlayerState.PULSE:
		return false
	return _isak.is_on_floor()


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


## Pellizcar es un interruptor: un toque cuando lo pedido no coincide.
func _resolve_pinch() -> void:
	if _isak == null or _pinch_cd > 0 or _isak.is_dead():
		return
	if _want_small and not _isak.is_compressed():
		if _isak.compress_denial() == &"" and _isak.is_on_floor():
			_tap(A_PINCH)
			_pinch_cd = 8
	elif not _want_small and _isak.is_compressed() and not _isak.is_uncompress_pending():
		_tap(A_PINCH)
		_pinch_cd = 8


# --- Entrada ---

func _tap(action: StringName) -> void:
	if not _taps.has(action):
		_taps.append(action)


func _release_taps() -> void:
	for action: StringName in _held_taps:
		Input.action_release(action)
	_held_taps.clear()
	_laser_cd = maxi(_laser_cd - 1, 0)
	_pulse_cd = maxi(_pulse_cd - 1, 0)
	_dash_tap_cd = maxi(_dash_tap_cd - 1, 0)
	_debug_tap_cd = maxi(_debug_tap_cd - 1, 0)
	_pinch_cd = maxi(_pinch_cd - 1, 0)


func _apply_inputs() -> void:
	_resolve_debug()
	if _started and not _defeated and _profile != "idle":
		_resolve_pinch()
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
	_want_small = false
	if _isak != null and is_instance_valid(_isak) and _isak.is_compressed() and not _isak.is_uncompress_pending() \
			and _pinch_cd <= 0:
		_tap(A_PINCH)
		_pinch_cd = 8
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
	var layer: StringName = StringName("boss_w3_l%d" % _lap)
	var ok: bool = true
	var checks: Array = [
		["3-boss completado", GameState.is_level_completed(&"3-boss")],
		["recuerdo %s sin guardar" % layer, GameState.has_memory(layer) and GameState.has_unsaved_changes()],
		["acertijo del hub pendiente", HubWorlds.is_hub_upgrade_pending()
			and HubWorlds.folder_state(HubWorlds.world(&"m4")) == HubWorlds.STATE_HIDDEN
			and hub.get_page_state(2) == HubRoom.PAGE_INSTALLING],
	]
	# La pieza verde depende de la carpeta del acceso actual: solo Caché tiene hoy
	# la fila del jefe (los subniveles de Kernel y Raíz aun no existen).
	if _lap == 1:
		checks.append(["pieza verde encendida", hub.get_piece_animation(3) == &"on"])
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
	if _profile == "ideal" and _lap == 1 and (_fight_s() < IDEAL_CACHE_S.x or _fight_s() > IDEAL_CACHE_S.y):
		_note("FALLO: el ideal en Caché tarda %.1f s (franja %.0f-%.0f s)" % [_fight_s(), IDEAL_CACHE_S.x,
			IDEAL_CACHE_S.y])
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
	var label: String = "play_boss_bot curator (%s, %s)" % [ACCESS_NAMES.get(_lap, "?"), _profile]
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
		var causes: PackedStringArray = []
		for k: String in _hit_causes:
			causes.append("%s %d" % [k, int(_hit_causes[k])])
		print("  RESULTADO: pelea %.1f s (objetivo %.0f s; ideal en Caché %.0f-%.0f s), golpes %d%s, muertes %d, energia minima %.0f (en ventana %.0f; margen del validador %.1f), Debug cortado en ventana %d" % [
			_fight_s(), _target_s, IDEAL_CACHE_S.x, IDEAL_CACHE_S.y, _hits,
			(" (" + ", ".join(causes) + ")") if not causes.is_empty() else "", _deaths,
			_min_energy if _min_energy != INF else -1.0, _min_energy_window if _min_energy_window != INF else -1.0,
			VALIDATOR_MARGIN.get(_lap, 0.0), _debug_cut_in_window])
		print("  ACCIONES: pulsos %d, laseres %d, dashes %d, pellizcos %d, Debug %.1f s, cargas %d, flashes %d (ciegan %d), marcos cerrados %d (fuera del refugio %d), reflejos aturdidos %d, ladrones aturdidos %d, likes al pisar una plataforma min %d" % [
			_pulses, _lasers, _dashes, _pinches, float(_debug_frames) / 60.0, _charges, _flashes, _blinded,
			_frames_closed, _frames_unsafe, _reflection_stuns, _thief_stuns,
			_likes_on_plat_min if _likes_on_plat_min < (1 << 30) else -1])
		print("  FASES: " + "; ".join(phases))
	finished.emit(0 if ok else 1)


func _note(text: String) -> void:
	_log.append(text)
	if _verbose:
		print("[curator_bot %.1f] %s" % [_fight_s(), text])


func _trace_line() -> void:
	var refl: PackedStringArray = []
	for r: FalseReflection in _boss.get_reflections():
		refl.append("%s(%.0f) %.1f" % [r.get_state(), r.global_position.x, r.get_stun_left()])
	print("[trace %.1f] isak (%.0f,%.0f) %s %s v(%.0f,%.0f) e%.0f likes %d axis %.2f jump %s small %s/%s dbg %s | fase %d ataque %s ventana %s %.1f lado %s marco %s/%s | air %s | refl %s" % [
		_fight_s(), _isak.global_position.x, _isak.global_position.y, _surface(), _isak.get_state_name(),
		_isak.velocity.x, _isak.velocity.y, GameState.debug_energy, GameState.likes, _axis, _jump, _want_small,
		_isak.is_compressed(), DebugMode.is_active(), _boss.get_phase(), _boss.get_attack_state(),
		_boss.is_window_open(), _boss.get_window_time_left(), _boss.get_window_side(), _boss.get_frame_state(),
		_boss.get_frame_side(), _air.get("mode", &"-"), ", ".join(refl)])


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
