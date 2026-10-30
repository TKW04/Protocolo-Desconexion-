## Bot del jefe El Vendedor (paso 19 de docs/propuesta-mundo-5.md §8, 2026-10-29;
## §7.3). Carga la escena principal (scenes/main.tscn, LevelRunner) en la arena
## 5-boss real y pelea con el Isak real pulsando SOLO acciones del Input Map
## (move_left / move_right, jump, run, pulse, laser, debug, gesture_swipe,
## gesture_pinch y ui_accept para cerrar las lineas importantes y la recompensa);
## nunca Q ni pause, nunca teletransporta, no toca GameState durante la pelea ni
## llama a la API de dano o de pago del jefe. Como los bots de los Mundos 1-4
## (tools/boss_bot.gd … tools/seen_bot.gd) es REACTIVO: una politica por fase que
## cada cuadro lee la API de Vendor / BossBase / WeakPoint (get_phase, get_facing,
## get_turn_stage, is_trap, is_platform_solid, get_label_rect, get_sweep_rect,
## get_coin_columns, get_boxes, get_fuse_left, is_refunding, is_tray_open,
## get_countdown_left, get_core_point…).
##
## Geometria (arena 20 x 11; maquina solida en las columnas 8-11, filas 5-9):
## estantes de una via en la fila 8 (columnas 2-5 y 14-17), plataformas con precio
## en la fila 6 (a 4-5, b 6-7, c 12-13, d 14-15; trampas b y c), techo de la maquina
## en la fila 5, ranura en las filas 6-7 (fase 3) y bandeja-tunel en la fila 9
## (fase 2, mientras procesa una devolucion).
## - Fase 1 «Plataformas con precio»: sube al estante de su lado (el de delante),
##   paga la buena con un pulso a su etiqueta (el torpe paga antes la trampa), salta
##   a ella y al techo con el Debug ya cargando, baja por detras, pulso que marca,
##   suelta el Debug y laser. Sale del estante que barre el brazo y de las columnas
##   de las monedas.
## - Fase 2 «Sorpresa»: abre con el pulso (de cara, en el suelo) el ticket de
##   devolucion de su lado, aturde las bombas que van a explotar cerca, cruza la
##   bandeja comprimido (Pellizcar), se descomprime detras y Debug, pulso, laser.
## - Fase 3 «Oferta por tiempo limitado»: Filo por la ranura (desde el borde
##   interior del estante de delante: Pellizcar, salto y Deslizar en el aire); detras,
##   contra el tiron, se descomprime y Debug, pulso, laser hasta acabar.
##
## Perfiles (--profile):
## - ideal: pelea limpia (Debug solo hasta la marca; los golpes que quepan).
## - clumsy (torpe): validation_model de data/bosses/vendor.json: golpes por
##   ventana (laps.<n>.windows; 0 = ventana perdida con early_debug_s de Debug),
##   segundos de Debug por ventana (laps.<n>.debug_s), un laser fallado por ventana
##   (misses_per_window, antes de marcar), un dash por ventana (dashes_per_window,
##   al volver al suelo tras ella) y una plataforma trampa pagada por fase
##   (trap_payments_per_phase).
## - idle (quieto): no hace nada (solo cierra las lineas): debe perder.
## Accesos (--lap 1|2|3): GameState.lap antes de cargar; El Vendedor lee laps.<n>.
##
## Mide: duracion de la pelea (tiempo de juego, desde que empieza hasta el golpe
## final) frente a target_duration_s y a la franja del paso 19 (Caché ideal
## 100-160 s), golpes, muertes, congelaciones («Procesando pago…»), energia minima
## (toda la pelea, en ventana y por fase) y gasto por ventana frente al margen del
## validador, fichas (gastadas, «te fio»), plataformas pagadas, trampas, tickets,
## bombas aturdidas, Filos, empujones de la ranura, pulsos, laseres y dashes; al
## final, la recompensa (boss_w5_l<n> sin guardar) y la vuelta al hub con 5-boss
## completado, el Mundo 6 disponible y, en Caché, la quinta pieza encendida, el
## fondo completo y las cinco ranuras del candado de M6. Usa user://bot_save.json
## (borrado al empezar). Lo lanza tools/play_boss_bot.gd -- --boss vendor (o
## tools/play_vendor_bot.gd); lo ejecuta tests/test_vendor_bot.gd.
extends Node

signal finished(code: int)

const MAIN_SCENE: String = "res://scenes/main.tscn"
const BOT_SAVE_PATH: String = "user://bot_save.json"
const BOSS_DATA: String = "res://data/bosses/vendor.json"
const LEVEL_DATA: String = "res://data/levels/5-boss.json"
const LEVEL_ID: String = "5-boss"
const UPGRADE_4_6: StringName = &"hub_update_4_6"
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
## Margen de energia del validador de arenas (tools/validate_boss.py, pelea torpe,
## paso 17: el peor de las tres fases por acceso, sin mejoras). Solo informe.
const VALIDATOR_MARGIN: Dictionary = {1: 37.5, 2: 37.5, 3: 37.5}
## Duracion pedida al bot ideal en Caché (paso 19, s de juego).
const IDEAL_CACHE_S: Vector2 = Vector2(100.0, 160.0)
const MAX_FIGHT_S: float = 600.0
const MAX_IDLE_S: float = 1200.0
const MAX_AFTER_S: float = 60.0
const LINE_READ_FRAMES: int = 10
const PULSE_RADIUS: float = 96.0
const REACH_MARGIN: float = 12.0
const RECHARGE_BELOW: Dictionary = {"ideal": 45.0, "clumsy": 55.0}
const BODY_HALF_PX: float = 20.0
## Distancia de la cara de detras a la que se pone para marcar y disparar: el pulso
## llega al boton y la boca del laser (unos 40 px por delante) nace antes que el.
const SERVICE_PX: float = 92.0
const SERVICE_MIN_PX: float = 52.0
const SERVICE_MAX_PX: float = 112.0
const COIN_MARGIN_PX: float = 10.0
## Superficies (y de los pies).
const S_FLOOR: StringName = &"floor"
const S_SHELF: StringName = &"shelf"
const S_PLAT: StringName = &"plat"
const S_ROOF: StringName = &"roof"
const S_AIR: StringName = &"air"

var _profile: String = "ideal"
var _lap: int = 1
var _verbose: bool = false
var _trace: bool = false
var _model: Dictionary = {}
var _boss_cfg: Dictionary = {}
var _target_s: float = 300.0

var _runner: LevelRunner
var _level: Node
var _isak: Isak
var _boss: Vendor
var _tile: float = 64.0
var _floor_y: float = 640.0
var _shelf_y: float = 512.0
var _plat_y: float = 384.0
var _roof_y: float = 320.0
var _m: Rect2 = Rect2()
## Estantes por lado (-1 / +1): x0, x1.
var _shelves: Dictionary = {}

# --- Entrada que se aplica al final de cada cuadro ---
var _axis: float = 0.0
var _run: bool = false
var _jump: bool = false
var _debug_hold: bool = false
var _debug_want: bool = false
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
var _air: Dictionary = {}
var _line_key: String = ""
var _line_frame: int = 0
var _hooked: bool = false
var _started: bool = false
var _defeated: bool = false
var _done: bool = false
var _after_frames: int = 0
var _game_over: bool = false
var _win_index: int = -1
var _win_hits: int = 0
var _win_missed: int = 0
var _win_debug_s: float = 0.0
var _win_dash_pending: bool = false
var _recharging: bool = false
var _was_frozen: bool = false
## Fase 1: plataforma elegida para la ventana que viene y trampas pagadas en la fase.
var _plat_choice: String = ""
var _traps_paid_phase: int = 0
## Fase 3: Filo en curso (salto comprimido; Deslizar a los `edge_frame` cuadros).
var _edge_jump: bool = false

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
var _debug_frames: int = 0
var _charges: int = 0
var _freezes: int = 0
var _payments_tray: int = 0
var _payments_time: int = 0
var _platforms_paid: int = 0
var _credits: int = 0
var _traps_folded: int = 0
var _refunds: int = 0
var _bombs: int = 0
var _edges: int = 0
var _rams: int = 0
var _slot_pushes: int = 0
var _tokens_min: int = 999
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
	_target_s = float(lv.get("target_duration_s", 300.0))
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
	EventBus.combo_started.connect(func(kind: StringName) -> void:
		if kind == Isak.COMBO_EDGE:
			_edges += 1
		elif kind == Isak.COMBO_RAM:
			_rams += 1)
	_runner = (load(MAIN_SCENE) as PackedScene).instantiate() as LevelRunner
	_runner.start_level_id = LEVEL_ID
	add_child(_runner)
	_note("perfil %s, acceso %s (vuelta %d)" % [_profile, ACCESS_NAMES[_lap], _lap])


## Progreso de quien acaba de completar el 5-3: Eco, Notas, Calc y la Linterna
## conocidos, las siete habilidades (con la Combinacion), los avisos vistos, la
## actualizacion del hub instalada, los recuerdos de los jefes 1-4 y la fila de
## El Vendedor desbloqueada, en la vuelta pedida.
func _setup_progress() -> void:
	GameState.lap = _lap
	for ally: StringName in [GameState.ALLY_ECO, GameState.ALLY_NOTAS, GameState.ALLY_CALC, GameState.ALLY_LINTERNA]:
		GameState.meet_ally(ally)
	for ability: StringName in [GameState.ABILITY_PULSE, GameState.ABILITY_LASER, GameState.ABILITY_DEBUG,
			GameState.ABILITY_DASH, GameState.ABILITY_GROUND_POUND, GameState.ABILITY_COMPRESS, GameState.ABILITY_COMBO]:
		GameState.obtain_ability(ability)
		GameState.seen_notices[ability] = true
	GameState.seen_notices[&"combo_5_2"] = true
	for id: StringName in [&"1-1", &"1-2", &"1-3", &"1-boss", &"2-1", &"2-2", &"2-3", &"2-boss", &"3-1", &"3-2",
			&"3-3", &"3-boss"]:
		GameState.unlock_level(id)
		GameState.mark_level_completed(id)
	GameState.install_hub_upgrade(UPGRADE_4_6)
	for id: StringName in [&"4-1", &"4-2", &"4-3", &"4-boss", &"5-1", &"5-2", &"5-3"]:
		GameState.unlock_level(id)
		GameState.mark_level_completed(id)
	GameState.unlock_level(&"5-boss")
	for n: int in [1, 2, 3, 4]:
		GameState.obtain_memory(StringName("boss_w%d_l1" % n))


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
			_note("pelea: empieza (%s, fichas %d)" % [_boss.get_counter_label(), _boss.get_tokens()])
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
			if node is Vendor:
				_boss = node as Vendor
				break
		if _boss != null:
			_hook_boss()


func _hook_boss() -> void:
	_hooked = true
	_tile = float(World5ObjectsConfig.tile_size())
	_m = _boss.get_machine_rect()
	_floor_y = _boss.get_floor_y()
	_roof_y = _m.position.y
	_plat_y = _boss.get_platform_rect("a").position.y
	var shelves: Dictionary = (_boss_cfg.get("arena", {}) as Dictionary).get("shelves", {})
	for key: String in ["left", "right"]:
		var s: Array = shelves.get(key, [2, 8, 4])
		var side: int = Vendor.SIDE_LEFT if key == "left" else Vendor.SIDE_RIGHT
		_shelves[side] = Vector2(float(s[0]) * _tile, float(int(s[0]) + int(s[2])) * _tile)
		_shelf_y = float(s[1]) * _tile
	if _verbose:
		_note("geometria: maquina %s, suelo %.0f, estante %.0f %s, plataformas %.0f, techo %.0f" % [_m, _floor_y,
			_shelf_y, _shelves, _plat_y, _roof_y])
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
	_boss.attack_started.connect(_on_attack)
	_boss.platform_paid.connect(func(name: StringName, credit: bool) -> void:
		_platforms_paid += 1
		if credit:
			_credits += 1
		if _boss.is_trap(String(name)):
			_traps_paid_phase += 1
		if _verbose:
			_note("plataforma %s pagada (%s; fichas %d)" % [name, "te fio" if credit else "fichas", _boss.get_tokens()]))
	_boss.platform_folded.connect(func(name: StringName) -> void:
		_traps_folded += 1
		_note("la trampa %s se pliega con Isak encima" % name))
	_boss.refund_started.connect(func() -> void:
		_refunds += 1
		if _verbose:
			_note("«Procesando devolución…» (lado %d)" % _boss.get_facing()))
	_boss.payment_processed.connect(func(by_tray: bool) -> void:
		if by_tray:
			_payments_tray += 1
		else:
			_payments_time += 1
		_note("«Procesando pago…» (%s; x %.0f)" % ["toca la bandeja" if by_tray else "cuenta a 0", _isak.global_position.x]))
	_boss.slot_pushed.connect(func(d: float) -> void:
		_slot_pushes += 1
		if _verbose:
			_note("la ranura lo expulsa (%+.0f)" % d))
	_boss.tokens_changed.connect(func(t: int) -> void: _tokens_min = mini(_tokens_min, t))
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
	if _was_frozen:
		return "pago"
	var body: Rect2 = LevelLookup.isak_body_rect(_isak).grow(6.0)
	if _boss.is_sweeping() and _boss.get_sweep_rect().intersects(body):
		return "brazo"
	if _boss.is_coin_falling():
		for c: int in _boss.get_coin_columns():
			if _boss.get_coin_rect(c).grow(8.0).intersects(body):
				return "moneda"
	if _boss.get_phase() == 2:
		return "bomba"
	if _boss.get_phase() == 1:
		return "trampa"
	return "?"


func _on_window_opened(s: float) -> void:
	_begin_window()
	var p: int = _boss.get_phase()
	if _verbose:
		_note("ventana %d de la fase %d (%.1f s del mundo; quiere %d golpes; %s, x %.0f; energia %.0f)" % [
			_win_index, p, s, _window_goal(), _surface(), _isak.global_position.x, GameState.debug_energy])


func _begin_window() -> void:
	_win_index += 1
	_win_hits = 0
	_win_missed = 0
	_win_debug_s = 0.0
	_win_e0 = GameState.debug_energy
	_win_spend = 0.0
	_recharging = false
	var p: int = _boss.get_phase()
	var w: Dictionary = _windows.get(p, {})
	w["windows"] = int(w.get("windows", 0)) + 1
	_windows[p] = w


func _on_window_closed() -> void:
	if _profile == "clumsy" and _window_dashes() > 0:
		_win_dash_pending = true
	_plat_choice = ""
	if _verbose:
		_note("ventana cerrada (%d golpes; Debug %.1f s; gasto %.0f)" % [_win_hits, _win_debug_s, _win_spend])


func _on_phase_changed(phase: int) -> void:
	_note("fase %d a los %.1f s (%s; energia %.0f; fichas %d)" % [phase, _fight_s(), _boss.get_counter_label(),
		GameState.debug_energy, _boss.get_tokens()])
	_reset_phase_state()


func _on_phase_restarted(phase: int) -> void:
	_note("reaparece: la fase %d vuelve a empezar (energia %.0f)" % [phase, GameState.debug_energy])
	_reset_phase_state()


func _reset_phase_state() -> void:
	_win_index = -1
	_win_hits = 0
	_win_dash_pending = false
	_recharging = false
	_plat_choice = ""
	_traps_paid_phase = 0
	_edge_jump = false
	_air = {}


func _on_attack(attack: StringName) -> void:
	if _verbose and attack != Vendor.ATTACK_WINDOW:
		_note("ataque %s (fase %d, %.1f s)" % [attack, _boss.get_phase(), _fight_s()])


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
	var frozen: bool = _isak.is_frozen()
	if frozen and not _was_frozen:
		_freezes += 1
		if _verbose:
			_note("Isak congelado (%s; fase %d, x %.0f)" % [_isak.get_frozen_source(), p, _isak.global_position.x])
	_was_frozen = frozen
	_tokens_min = mini(_tokens_min, _boss.get_tokens())


func _fight_s() -> float:
	return float(_fight_frames) / 60.0


# --- Politica ---

func _fight() -> void:
	if _isak.is_dead() or _isak.is_warping():
		_debug_hold = false
		_air = {}
		_edge_jump = false
		return
	if _isak.is_frozen():
		_axis = 0.0
		_debug_want = DebugMode.is_active() or DebugMode.is_engaged()
		return
	var window: bool = _boss.is_window_open()
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


## Golpes de la proxima ventana (la que viene).
func _window_goal_next() -> int:
	if _profile != "clumsy":
		return 99
	var wins: Array = _model_lap().get("windows", [])
	var p: int = _boss.get_phase() - 1
	if p < 0 or p >= wins.size():
		return 99
	var list: Array = wins[p]
	var i: int = _win_index + 1
	return int(list[i]) if i < list.size() else 99


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


func _clumsy_debug_s() -> float:
	var list: Array = _model_lap().get("debug_s", [3.0, 3.0, 3.0])
	return float(list[clampi(_boss.get_phase() - 1, 0, list.size() - 1)])


## Una ventana perdida del torpe: Debug early_debug_s y nada mas.
func _lost_window() -> bool:
	if not _boss.is_window_open() or _window_goal() != 0:
		return false
	_want_debug(_win_debug_s < _model_phase_value("early_debug_s", 2.0))
	return true


## Ventana: Debug -> pulso que marca el «Cancelar» -> soltar el Debug -> laser,
## desde donde esta (ya a tiro). El torpe falla un laser antes de marcar y deja el
## Debug debug_s.
func _strike() -> void:
	var core: WeakPoint = _boss.get_core()
	var core_at: Vector2 = core.global_position if core != null else _boss.get_core_point()
	var marked: bool = core != null and core.is_marked()
	if _profile == "clumsy":
		_want_debug(_win_debug_s < _clumsy_debug_s() or not marked)
	else:
		_want_debug(not marked)
	if _isak.is_compressed():
		_unpinch()
		return
	if not _isak.is_on_floor():
		return
	var dir: float = signf(core_at.x - _isak.global_position.x)
	# En la franja de servicio: el pulso le llega y la boca del laser nace fuera de
	# la maquina (pegado a ella el disparo nace dentro de la carcasa y no cuenta).
	var here: int = _side_here()
	if here != 0:
		var gap: float = _gap_to_face(here)
		if gap < SERVICE_MIN_PX:
			# Lejos de la cara (contra el tiron de la fase 3, corriendo).
			_axis = float(here)
			_run = true
			return
		if gap > SERVICE_MAX_PX and not marked:
			_walk_to(_service_x(here), 6.0)
			return
	if _isak.facing != dir and absf(core_at.x - _isak.global_position.x) > 4.0:
		_face_x(core_at.x)
		return
	if not marked:
		if _pulse_center_facing(dir).distance_to(core_at) > PULSE_RADIUS - REACH_MARGIN - 4.0:
			_axis = dir * 0.5
			return
		if _profile == "clumsy" and _win_missed < int(_model.get("misses_per_window", 1)) and _win_index >= 0:
			if _try_laser():
				_win_missed += 1
			return
		if DebugMode.is_active() and core != null and core.is_enabled():
			_try_pulse()
		return
	if _profile != "clumsy" and DebugMode.is_active():
		return
	_try_laser()


## El pulso (mirando hacia el rectangulo) alcanza `r` desde donde esta.
func _rect_in_pulse(r: Rect2) -> bool:
	var dir: float = signf(r.get_center().x - _isak.global_position.x)
	if dir == 0.0:
		dir = _isak.facing
	var o: Vector2 = _pulse_center_facing(dir)
	var closest := Vector2(clampf(o.x, r.position.x, r.end.x), clampf(o.y, r.position.y, r.end.y))
	return o.distance_to(closest) <= PULSE_RADIUS - REACH_MARGIN


func _pulse_center_facing(dir: float) -> Vector2:
	return _isak.global_position + Vector2(36.0 * dir, -56.0)


## Lado de delante (al que mira la maquina) y de detras.
func _front() -> int:
	return _boss.get_facing()


func _behind_side() -> int:
	return -_boss.get_facing()


## Lado de Isak (-1 / +1; 0 sobre la maquina).
func _side_here() -> int:
	return _boss.side_of_x(_isak.global_position.x)


## Junto a la cara de detras, en el suelo: x de servicio (a tiro de pulso del «Cancelar»).
func _service_x(side: int) -> float:
	return (_m.end.x + SERVICE_PX) if side == Vendor.SIDE_RIGHT else (_m.position.x - SERVICE_PX)


## Distancia de los pies de Isak a la cara de la maquina de su lado.
func _gap_to_face(side: int) -> float:
	return (_isak.global_position.x - _m.end.x) if side == Vendor.SIDE_RIGHT else (_m.position.x - _isak.global_position.x)


# --- Fase 1 «Plataformas con precio» ---

func _phase1(window: bool) -> void:
	if window and _lost_window():
		_axis = 0.0
		return
	if window and _win_hits < _window_goal() and _side_here() == _behind_side():
		_strike()
		return
	if window and _side_here() == _behind_side() and _surface() == S_AIR:
		# Bajando por detras: el Debug sigue.
		_want_debug(_wants_debug_for_window())
		_air_control()
		return
	if _clumsy_dash():
		return
	if _dodge_hazards():
		return
	var s: StringName = _surface()
	# En el techo: a la espalda y abajo, con el Debug ya cargando.
	if s == S_ROOF:
		_want_debug(_wants_debug_for_window())
		_goto(S_FLOOR, _service_x(_behind_side()))
		return
	if _need_recharge() and s == S_FLOOR and not window and _try_recharge():
		return
	var plat: String = _platform_for_window()
	if plat.is_empty():
		_debug_off()
		_goto(S_FLOOR, _home_x(_front()))
		return
	if _boss.is_platform_solid(plat) and not _boss.is_trap(plat):
		if s == S_PLAT:
			_want_debug(_wants_debug_for_window())
			_goto(S_ROOF, _m.get_center().x)
			return
		_goto(S_PLAT, _boss.get_platform_rect(plat).get_center().x, plat)
		return
	# Pagar: en el estante de su lado, pulso a la etiqueta (reponiendo, espera abajo).
	_debug_off()
	if _boss.is_restocking() and _boss.get_restock_left() > 0.6:
		if _need_recharge() and s == S_FLOOR and _try_recharge():
			return
		_goto(S_FLOOR, _pay_x(plat))
		return
	var lr: Rect2 = _boss.get_label_rect(plat)
	var px: float = _pay_x(plat)
	if s != S_SHELF:
		_goto(S_SHELF, px)
		return
	if _rect_in_pulse(lr) and absf(_isak.global_position.x - px) < 40.0:
		_axis = 0.0
		var dir: float = signf(lr.get_center().x - _isak.global_position.x)
		if dir != 0.0 and _isak.facing != dir:
			_face_x(lr.get_center().x)
			return
		_try_pulse()
		return
	_goto(S_SHELF, px)


func _wants_debug_for_window() -> bool:
	if _profile == "clumsy" and _window_goal_next() == 0:
		return _win_debug_s < _model_phase_value("early_debug_s", 2.0)
	return true


## Plataforma de la ventana que viene en el lado de delante: la buena (el torpe
## paga antes la trampa, trap_payments_per_phase). "" si Isak no esta delante.
func _platform_for_window() -> String:
	var front: int = _front()
	var names: Array[String] = ["a", "b"]
	if front != Vendor.SIDE_LEFT:
		names = ["d", "c"]
	if _profile == "clumsy" and _traps_paid_phase < int(_model.get("trap_payments_per_phase", 1)):
		for n: String in names:
			if _boss.is_trap(n) and not _boss.is_platform_active(n):
				return n
	for n: String in names:
		if not _boss.is_trap(n):
			return n
	return ""


## x del estante desde la que el pulso (mirando a la etiqueta) la alcanza.
func _pay_x(plat: String) -> float:
	var lr: Rect2 = _boss.get_label_rect(plat)
	var side: int = _boss.side_of_x(lr.get_center().x)
	var sh: Vector2 = _shelves.get(side, Vector2())
	var dir: float = 1.0 if side == Vendor.SIDE_LEFT else -1.0
	return clampf(lr.get_center().x - 36.0 * dir, sh.x + 24.0, sh.y - 24.0)


func _home_x(side: int) -> float:
	return (3.5 * _tile) if side == Vendor.SIDE_LEFT else (16.5 * _tile)


## Esquiva el brazo que barre (fuera del estante) y las monedas (fuera de su
## columna, en la misma superficie). Verdadero si actua.
func _dodge_hazards() -> bool:
	var s: StringName = _surface()
	var sweep: Rect2 = _boss.get_sweep_rect()
	if sweep.has_area():
		var body: Rect2 = LevelLookup.isak_body_rect(_isak).grow(4.0)
		if s == S_SHELF and _boss.side_of_x(sweep.get_center().x) == _side_here():
			# Fuera del estante: arriba si la plataforma ya esta (lejos del barrido) o al suelo.
			_debug_off()
			var sh: Vector2 = _shelves.get(_side_here(), Vector2())
			var inner: float = sh.y if _side_here() == Vendor.SIDE_LEFT else sh.x
			_goto(S_FLOOR, inner + (40.0 if _side_here() == Vendor.SIDE_LEFT else -40.0))
			return true
		if s == S_FLOOR and absf(_isak.global_position.y - _floor_y) < 4.0 and body.intersects(sweep):
			return false
	var cols: Array[int] = _boss.get_coin_columns()
	if not cols.is_empty() and s != S_AIR and s != S_ROOF:
		var ix: float = _isak.global_position.x
		if not _x_safe_from_coins(ix, cols):
			var lo: float = 1.3 * _tile
			var hi: float = 18.7 * _tile
			match s:
				S_SHELF:
					var sh2: Vector2 = _shelves.get(_side_here(), Vector2(lo, hi))
					lo = sh2.x + 12.0
					hi = sh2.y - 12.0
				S_PLAT:
					for n: String in Vendor.PLATFORM_NAMES:
						var r: Rect2 = _boss.get_platform_rect(n)
						if ix >= r.position.x - 4.0 and ix <= r.end.x + 4.0:
							lo = r.position.x + 12.0
							hi = r.end.x - 12.0
				_:
					if _side_here() == Vendor.SIDE_LEFT:
						hi = _m.position.x - BODY_HALF_PX - 2.0
					else:
						lo = _m.end.x + BODY_HALF_PX + 2.0
			var best: float = INF
			var x: float = lo
			while x <= hi:
				if _x_safe_from_coins(x, cols) and (best == INF or absf(x - ix) < absf(best - ix)):
					best = x
				x += 4.0
			if best != INF:
				_walk_to(best, 2.0)
				_run = true
				return true
	# Sin pisar el estante que el brazo va a barrer.
	if sweep.has_area() and s == S_FLOOR:
		var under: bool = _isak.global_position.x > sweep.position.x - 40.0 and _isak.global_position.x < sweep.end.x + 40.0
		if under and StringName(_air.get("mode", &"")) == &"":
			_axis = 0.0
			return true
	return false


func _x_safe_from_coins(x: float, cols: Array[int]) -> bool:
	for c: int in cols:
		var r: Rect2 = _boss.get_coin_rect(c)
		if x + BODY_HALF_PX + COIN_MARGIN_PX > r.position.x and x - BODY_HALF_PX - COIN_MARGIN_PX < r.end.x:
			return false
	return true


# --- Fase 2 «Sorpresa» ---

func _phase2(window: bool) -> void:
	var s: StringName = _surface()
	var here: int = _side_here()
	if window and here == _behind_side() and not _isak.is_compressed() and _lost_window():
		_axis = 0.0
		return
	if window and here == _behind_side() and _win_hits < _window_goal():
		if _bomb_reflex():
			return
		if _isak.is_compressed():
			_want_debug(true)
			_unpinch()
			_walk_to(_service_x(here), 4.0)
			return
		_strike()
		return
	if _boss.is_tray_open() and _isak.is_compressed():
		_cross_tunnel()
		return
	if _isak.is_compressed() and here != 0:
		_unpinch()
		_axis = 0.0
		return
	_debug_off()
	if _clumsy_dash():
		return
	if s == S_AIR:
		_air_control()
		return
	if _bomb_reflex():
		return
	if s == S_SHELF:
		var sweep: Rect2 = _boss.get_sweep_rect()
		if sweep.has_area() and _boss.side_of_x(sweep.get_center().x) == here:
			_goto(S_FLOOR, _home_x(here))
			return
	# Devolucion en curso y delante: a la bandeja, comprimido.
	if _boss.is_refunding() and here == _front():
		_cross_tunnel()
		return
	# El ticket de su lado: de cara y en el suelo, pulso.
	var ticket: SurpriseBox = _ticket_here()
	if ticket != null:
		var r: Rect2 = ticket.get_body_rect()
		if s != S_FLOOR:
			_goto(S_FLOOR, r.get_center().x)
			return
		var dir: float = signf(r.get_center().x - _isak.global_position.x)
		var stand: float = r.get_center().x - (dir if dir != 0.0 else _isak.facing) * 56.0
		if r.position.y < _floor_y - _tile * 1.5:
			stand = r.get_center().x - (dir if dir != 0.0 else _isak.facing) * 24.0
		if _rect_in_pulse(r) and absf(_isak.global_position.x - stand) < 30.0:
			_axis = 0.0
			if dir != 0.0 and _isak.facing != dir:
				_face_x(r.get_center().x)
				return
			_try_pulse()
			return
		_walk_to(_clamp_floor_x(stand, here), 4.0)
		return
	if _need_recharge() and _try_recharge():
		return
	_goto(S_FLOOR, _phase2_home())


## Donde espera la tanda en la fase 2: en el suelo de delante, a media distancia.
func _phase2_home() -> float:
	return (4.5 * _tile) if _front() == Vendor.SIDE_LEFT else (15.5 * _tile)


func _clamp_floor_x(x: float, side: int) -> float:
	if side == Vendor.SIDE_LEFT:
		return clampf(x, 1.0 * _tile + BODY_HALF_PX + 4.0, _m.position.x - BODY_HALF_PX - 2.0)
	return clampf(x, _m.end.x + BODY_HALF_PX + 2.0, 19.0 * _tile - BODY_HALF_PX - 4.0)


## El ticket cerrado y en reposo del lado de Isak (o null).
func _ticket_here() -> SurpriseBox:
	for box: SurpriseBox in _boss.get_boxes():
		if box.content != SurpriseBox.CONTENT_TICKET or box.get_state() != SurpriseBox.STATE_CLOSED:
			continue
		if _boss.side_of_x(box.get_body_rect().get_center().x) == _side_here():
			return box
	return null


## Bomba que va a explotar cerca: pulso (la aturde) si le llega; si no, lejos.
## Verdadero si actua.
func _bomb_reflex() -> bool:
	var blast: float = float((_boss_cfg.get("boxes", {}) as Dictionary).get("blast_tiles", 1.5)) * _tile
	var body: Rect2 = LevelLookup.isak_body_rect(_isak)
	for box: SurpriseBox in _boss.get_boxes():
		var fuse: float = _boss.get_fuse_left(box)
		if fuse < 0.0 or box.get_state() != SurpriseBox.STATE_CLOSED or fuse > 1.4:
			continue
		var c: Vector2 = box.get_body_rect().get_center()
		var nearest := Vector2(clampf(c.x, body.position.x, body.end.x), clampf(c.y, body.position.y, body.end.y))
		if nearest.distance_to(c) > blast + 36.0:
			continue
		if _isak.is_compressed():
			if _boss.side_of_x(_isak.global_position.x) == 0:
				# En el tunel: lo decide _cross_tunnel (espera si la salida peligra).
				return false
			_unpinch()
		if _isak.is_on_floor() and _rect_in_pulse(box.get_body_rect()) and not _isak.is_compressed():
			_axis = 0.0
			var dir: float = signf(c.x - _isak.global_position.x)
			if dir != 0.0 and _isak.facing != dir:
				_face_x(c.x)
				return true
			if _try_pulse():
				_bombs += 1
			return true
		# Lejos de ella por su lado.
		var away: float = signf(_isak.global_position.x - c.x)
		if away == 0.0:
			away = 1.0
		_axis = away
		_run = true
		return true
	return false


## Cruza la bandeja-tunel comprimido hacia la espalda (abierta solo procesando).
func _cross_tunnel() -> void:
	var front: int = _front()
	var exit_x: float = _service_x(-front)
	var mouth: float = _m.position.x if front == Vendor.SIDE_LEFT else _m.end.x
	var ix: float = _isak.global_position.x
	var toward: float = 1.0 if front == Vendor.SIDE_LEFT else -1.0
	if not _isak.is_compressed():
		if not _isak.is_on_floor():
			_air_control()
			return
		var blocker: SurpriseBox = _box_between(ix, mouth - toward * 20.0)
		if blocker != null:
			# Una caja en el camino (solida en reposo o aturdida): por encima.
			var br: Rect2 = blocker.get_body_rect()
			var near_x: float = (br.position.x - 30.0) if toward > 0.0 else (br.end.x + 30.0)
			# Sin caja encima del despegue (una en el estante o aturdida en el aire).
			for k: int in 6:
				var over: SurpriseBox = _box_overhead(near_x)
				if over == null:
					break
				var orr: Rect2 = over.get_body_rect()
				near_x = (orr.position.x - 26.0) if toward > 0.0 else (orr.end.x + 26.0)
			if absf(ix - near_x) > 10.0:
				_walk_to(near_x, 6.0)
				return
			_launch(&"up", mouth - toward * 34.0, _floor_y)
			return
		if absf(ix - mouth) > 70.0:
			_walk_to(mouth - toward * 50.0, 10.0)
			return
		_axis = 0.0
		_pinch()
		return
	# Comprimido: hacia la salida; antes de salir, si una bomba va a estallar en la boca, espera.
	if _side_here() == 0 and _bomb_near_exit(-front):
		_axis = 0.0
		return
	_want_debug(_boss.is_refunding() and absf(ix - exit_x) < 3.0 * _tile)
	_axis = toward
	if (toward > 0.0 and ix > exit_x - 8.0) or (toward < 0.0 and ix < exit_x + 8.0):
		_axis = 0.0
		_unpinch()


## Caja solida por encima de la cabeza de Isak de pie en `x` (en el estante o
## aturdida en el aire), que cortaria el salto.
func _box_overhead(x: float) -> SurpriseBox:
	for box: SurpriseBox in _boss.get_boxes():
		if not box.is_solid():
			continue
		var r: Rect2 = box.get_body_rect()
		if r.end.y > _floor_y - 80.0 or r.end.y < _floor_y - 260.0:
			continue
		if r.end.x > x - BODY_HALF_PX - 6.0 and r.position.x < x + BODY_HALF_PX + 6.0:
			return box
	return null


## Caja cerrada o aturdida en el suelo entre `x0` y `x1` (o null).
func _box_between(x0: float, x1: float) -> SurpriseBox:
	var lo: float = minf(x0, x1)
	var hi: float = maxf(x0, x1)
	for box: SurpriseBox in _boss.get_boxes():
		if not box.is_solid():
			continue
		var r: Rect2 = box.get_body_rect()
		if r.end.y < _floor_y - 4.0:
			continue
		if r.end.x > lo and r.position.x < hi:
			return box
	return null


func _bomb_near_exit(side: int) -> bool:
	var blast: float = float((_boss_cfg.get("boxes", {}) as Dictionary).get("blast_tiles", 1.5)) * _tile
	var face: float = _m.end.x if side == Vendor.SIDE_RIGHT else _m.position.x
	for box: SurpriseBox in _boss.get_boxes():
		var fuse: float = _boss.get_fuse_left(box)
		if fuse < 0.0 or box.get_state() != SurpriseBox.STATE_CLOSED:
			continue
		var c: Vector2 = box.get_body_rect().get_center()
		if _boss.side_of_x(c.x) == side and absf(c.x - face) < blast + 60.0 and fuse < 2.6:
			return true
	return false


# --- Fase 3 «Oferta por tiempo limitado» ---

func _phase3(window: bool) -> void:
	var here: int = _side_here()
	var s: StringName = _surface()
	if here == _behind_side() and s != S_AIR:
		_edge_jump = false
		if window and _profile == "clumsy" and _window_goal() == 0:
			# Ventana perdida del torpe: early_debug_s de Debug y la da por perdida.
			_want_debug(true)
			if _isak.is_compressed():
				_unpinch()
			if _win_debug_s >= _model_phase_value("early_debug_s", 2.0):
				_begin_window()
			return
		if _dodge_coins_behind():
			return
		if window and _win_hits < _window_goal():
			if _isak.is_compressed():
				_want_debug(true)
				_unpinch()
				return
			_strike()
			return
		if _isak.is_compressed():
			_unpinch()
		_want_debug(false)
		if _clumsy_dash_behind():
			return
		_walk_to(_service_x(here), 6.0)
		return
	if s == S_AIR:
		_debug_off()
		if _edge_jump:
			_edge_air()
		else:
			_air_control()
		return
	_edge_jump = false
	# Delante: Filo por la ranura desde el borde interior del estante.
	_debug_off()
	var front: int = _front()
	var spot: float = _edge_spot(front)
	if not _isak.is_compressed() and _dodge_hazards():
		return
	# El cartel aun baja (ranura cerrada, sin tiron): espera en el borde del estante.
	if _boss.get_offer_grace_left() > 0.35:
		if _isak.is_compressed() and s != S_AIR:
			_unpinch()
		_goto(S_SHELF, spot)
		return
	if s == S_SHELF and absf(_isak.global_position.x - spot) <= 14.0:
		_axis = -float(front) * 0.0
		if not _isak.is_compressed():
			_pinch()
			_hold_against_pull(spot)
			return
		_start_jump()
		_edge_jump = true
		_air = {"mode": &"edge", "t": 0}
		return
	if _isak.is_compressed() and s == S_FLOOR:
		_unpinch()
		_hold_against_pull(_floor_wait_x(front))
		return
	_goto(S_SHELF, spot)


## Borde interior del estante de delante (columna 5 o 14).
func _edge_spot(front: int) -> float:
	var sh: Vector2 = _shelves.get(front, Vector2())
	return (sh.y - 32.0) if front == Vendor.SIDE_LEFT else (sh.x + 32.0)


func _floor_wait_x(front: int) -> float:
	return (3.0 * _tile) if front == Vendor.SIDE_LEFT else (17.0 * _tile)


## Quieto contra el tiron de la oferta (hacia la bandeja).
func _hold_against_pull(x: float) -> void:
	var dx: float = x - _isak.global_position.x
	_axis = clampf(dx / 24.0, -1.0, 1.0)


## En el aire del salto comprimido: Deslizar hacia la maquina a los pocos cuadros.
func _edge_air() -> void:
	var toward: float = 1.0 if _front() == Vendor.SIDE_LEFT else -1.0
	var t: int = int(_air.get("t", 0)) + 1
	_air["t"] = t
	_axis = toward
	if t >= 3 and _isak.is_compressed() and not _isak.is_comboing() and not _isak.is_dashing() \
			and _isak.get_air_dashes_left() > 0 and int(_air.get("dashed", 0)) == 0:
		_tap(A_DASH)
		_air["dashed"] = 1


## Detras, las monedas: fuera de su columna (contra el tiron, hacia la pared).
func _dodge_coins_behind() -> bool:
	var cols: Array[int] = _boss.get_coin_columns()
	if cols.is_empty():
		return false
	var ix: float = _isak.global_position.x
	if _x_safe_from_coins(ix, cols):
		return false
	var lo: float = _m.end.x + BODY_HALF_PX + 2.0
	var hi: float = 19.0 * _tile - BODY_HALF_PX - 4.0
	if _side_here() == Vendor.SIDE_LEFT:
		lo = 1.0 * _tile + BODY_HALF_PX + 4.0
		hi = _m.position.x - BODY_HALF_PX - 2.0
	var best: float = INF
	var x: float = lo
	while x <= hi:
		if _x_safe_from_coins(x, cols) and (best == INF or absf(x - ix) < absf(best - ix)):
			best = x
		x += 4.0
	if best == INF:
		return false
	_axis = signf(best - ix)
	_run = true
	return true


## Torpe en la fase 3: el dash de la ventana, hacia la pared (lejos de la bandeja).
func _clumsy_dash_behind() -> bool:
	if not _win_dash_pending or not _dash_ready():
		return false
	var dir: float = float(_side_here())
	if _try_dash(dir):
		_win_dash_pending = false
		return true
	return false


# --- Comun ---

func _need_recharge() -> bool:
	if _recharging:
		if GameState.debug_energy >= GameState.get_debug_energy_max() - 8.0:
			_recharging = false
		return _recharging
	if GameState.debug_energy < float(RECHARGE_BELOW.get(_profile, 45.0)):
		_recharging = true
	return _recharging


## Va al cargador listo mas cercano de su lado por el suelo. Falso si no hay.
func _try_recharge() -> bool:
	var best: Charger = null
	var ix: float = _isak.global_position.x
	var here: int = _side_here()
	for node: Node in _all_nodes(_level):
		var c := node as Charger
		if c == null or not c.is_ready():
			continue
		var cx: float = c.global_position.x + _tile * 0.5
		if _boss.side_of_x(cx) != here:
			continue
		if best == null or absf(cx - ix) < absf(best.global_position.x + _tile * 0.5 - ix):
			best = c
	if best == null:
		return false
	_goto(S_FLOOR, best.global_position.x + _tile * 0.5)
	return true


## Torpe: un dash por ventana al volver al suelo tras ella, lejos de la maquina.
func _clumsy_dash() -> bool:
	if not _win_dash_pending or _surface() != S_FLOOR or not _dash_ready() or _isak.is_compressed():
		return false
	var dir: float = float(_side_here())
	if dir == 0.0:
		return false
	if _try_dash(dir):
		_win_dash_pending = false
		return true
	return false


# --- Movimiento ---

## floor, shelf, plat (fila 6), roof (techo de la maquina) o air.
func _surface() -> StringName:
	if _isak == null or not _isak.is_on_floor():
		return S_AIR
	var y: float = _isak.global_position.y
	if absf(y - _floor_y) < 10.0:
		return S_FLOOR
	if absf(y - _shelf_y) < 10.0:
		return S_SHELF
	if absf(y - _plat_y) < 10.0:
		return S_PLAT
	if absf(y - _roof_y) < 10.0:
		return S_ROOF
	return S_FLOOR


## Va a la superficie `goal` y a `x` en ella (por el lado en el que esta). `plat`:
## la plataforma a la que subir (fila 6). Verdadero si ya esta (quieto).
func _goto(goal: StringName, x: float, plat: String = "") -> bool:
	var s: StringName = _surface()
	var ix: float = _isak.global_position.x
	if s == S_AIR:
		_air_control()
		return false
	var here: int = _side_here()
	match s:
		S_ROOF:
			if goal == S_ROOF:
				return _walk_to(clampf(x, _m.position.x + 16.0, _m.end.x - 16.0), 8.0)
			var dir: float = -1.0 if x < _m.get_center().x else 1.0
			_walk_off(dir, x)
			return false
		S_PLAT:
			if goal == S_PLAT:
				var pr: Rect2 = _plat_under(ix)
				return _walk_to(clampf(x, pr.position.x + 14.0, pr.end.x - 14.0), 6.0)
			if goal == S_ROOF:
				var pr2: Rect2 = _plat_under(ix)
				var toward: float = 1.0 if pr2.get_center().x < _m.get_center().x else -1.0
				var adjacent: bool = absf((pr2.end.x if toward > 0.0 else pr2.position.x) - (_m.position.x if toward > 0.0 else _m.end.x)) < 4.0
				var edge: float = (pr2.end.x - 14.0) if toward > 0.0 else (pr2.position.x + 14.0)
				if adjacent:
					edge = (pr2.end.x - 40.0) if toward > 0.0 else (pr2.position.x + 40.0)
				if absf(ix - edge) > 8.0:
					_walk_to(edge, 4.0)
					return false
				_launch(&"roof", x)
				return false
			var out: float = -1.0 if ix < _m.get_center().x else 1.0
			_walk_off(out, x)
			return false
		S_SHELF:
			if goal == S_SHELF:
				var sh: Vector2 = _shelves.get(here, Vector2(ix, ix))
				return _walk_to(clampf(x, sh.x + 14.0, sh.y - 14.0), 6.0)
			if goal == S_PLAT or goal == S_ROOF:
				var target: Rect2 = _boss.get_platform_rect(plat) if not plat.is_empty() else _plat_under(ix)
				var sh2: Vector2 = _shelves.get(here, Vector2(ix, ix))
				var jx: float = clampf(target.get_center().x, sh2.x + 20.0, sh2.y - 20.0)
				if absf(ix - jx) > 6.0 or absf(_isak.velocity.x) > 40.0:
					_walk_to(jx, 3.0)
					return false
				_launch(&"up", target.get_center().x, _plat_y)
				return false
			# Al suelo: por el borde mas cercano a `x`.
			var sh3: Vector2 = _shelves.get(here, Vector2(ix, ix))
			var dir2: float = -1.0 if absf(x - sh3.x) < absf(x - sh3.y) else 1.0
			if x < sh3.x:
				dir2 = -1.0
			elif x > sh3.y:
				dir2 = 1.0
			_walk_off(dir2, x)
			return false
	# En el suelo.
	if goal == S_FLOOR:
		return _walk_to(_clamp_floor_x(x, here) if here != 0 else x, 6.0)
	var sh4: Vector2 = _shelves.get(here, Vector2(ix, ix))
	var target_x: float = x
	if goal != S_SHELF:
		var t: Rect2 = _boss.get_platform_rect(plat) if not plat.is_empty() else Rect2(x, 0, 0, 0)
		target_x = t.get_center().x
	var lx: float = clampf(target_x, sh4.x + 20.0, sh4.y - 20.0)
	if absf(ix - lx) > 6.0 or absf(_isak.velocity.x) > 40.0:
		_walk_to(lx, 3.0)
		return false
	_launch(&"up", lx, _shelf_y)
	return false


## Plataforma de la fila 6 bajo `x` (las con precio o las vitrinas).
func _plat_under(x: float) -> Rect2:
	for n: String in Vendor.PLATFORM_NAMES:
		var r: Rect2 = _boss.get_platform_rect(n)
		if x >= r.position.x - 6.0 and x <= r.end.x + 6.0:
			return r
	return Rect2(x - 32.0, _plat_y, 64.0, 16.0)


func _walk_off(dir: float, goal_x: float) -> void:
	_axis = dir
	_run = false
	_air = {"mode": &"drop", "x": goal_x, "away": dir, "from_y": _isak.global_position.y}


func _launch(mode: StringName, x: float, y: float = 0.0) -> void:
	_start_jump()
	_air = {"mode": mode, "x": x, "y": y, "from_y": _isak.global_position.y}


func _air_control() -> void:
	var ix: float = _isak.global_position.x
	var fy: float = _isak.global_position.y
	match StringName(_air.get("mode", &"")):
		&"up":
			_axis = _p_axis(float(_air["x"]) - ix, 40.0)
			_run = absf(float(_air["x"]) - ix) > 100.0
		&"roof":
			# Del borde de la plataforma al techo: corriendo hacia el, sin pasarse.
			var tx: float = clampf(float(_air["x"]), _m.position.x + 40.0, _m.end.x - 40.0)
			_axis = _p_axis(tx - ix, 50.0)
			_run = absf(tx - ix) > 60.0
		&"drop":
			if fy < float(_air["from_y"]) + 40.0:
				_axis = float(_air["away"])
			else:
				_axis = _p_axis(float(_air["x"]) - ix, 60.0)
				_run = absf(float(_air["x"]) - ix) > 80.0
		&"edge":
			_edge_air()
		_:
			_axis = 0.0


func _walk_to(x: float, tol: float) -> bool:
	var dx: float = x - _isak.global_position.x
	if absf(dx) <= maxf(tol, 2.0):
		_axis = 0.0
		return absf(_isak.velocity.x) < 30.0 and _isak.is_on_floor()
	_axis = _p_axis(dx, 40.0)
	_run = absf(dx) > 140.0
	return false


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
		_edge_jump = false


func _face_x(x: float) -> void:
	var want: float = signf(x - _isak.global_position.x)
	if want != 0.0 and want != _isak.facing and _axis == 0.0:
		_axis = want * 0.2


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


func _pinch() -> void:
	if _isak.is_compressed() or _pinch_cd > 0:
		return
	_tap(A_PINCH)
	_pinch_cd = 12


func _unpinch() -> void:
	if not _isak.is_compressed() or _pinch_cd > 0:
		return
	_tap(A_PINCH)
	_pinch_cd = 12


func _dash_ready() -> bool:
	if _isak.is_dashing() or _isak.get_dash_cooldown_left() > 0.0 or DebugMode.is_engaged() \
			or GameState.debug_energy < 10.0 or _isak.is_laser_posing() or _isak.is_dead() \
			or _isak.is_frozen() or _isak.get_state_name() == PlayerState.PULSE:
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
	var layer: StringName = StringName("boss_w5_l%d" % _lap)
	var ok: bool = true
	var checks: Array = [
		["5-boss completado", GameState.is_level_completed(&"5-boss")],
		["recuerdo %s sin guardar" % layer, GameState.has_memory(layer) and GameState.has_unsaved_changes()],
		["Mundo 6 disponible", HubWorlds.folder_state(HubWorlds.world(&"m6")) == HubWorlds.STATE_AVAILABLE],
	]
	# La quinta pieza depende de la carpeta del acceso actual: solo Caché tiene hoy
	# las filas del Mundo 5 (los subniveles de Kernel y Raíz aun no existen).
	if _lap == 1:
		checks.append(["quinta pieza encendida", hub.get_piece_animation(5) in [&"on", &"complete"]])
		checks.append(["fondo completo", hub.is_wallpaper_complete()])
		var m6: FolderStation = hub.get_folder(&"m6")
		checks.append(["cinco ranuras del candado", m6 != null and m6.get_lock_slots_lit() == 5])
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
	var label: String = "play_boss_bot vendor (%s, %s)" % [ACCESS_NAMES.get(_lap, "?"), _profile]
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
		print("  RESULTADO: pelea %.1f s (objetivo %.0f s; ideal en Caché %.0f-%.0f s), golpes %d%s, muertes %d, congelaciones %d (bandeja %d, cuenta %d), energia minima %.0f (en ventana %.0f; margen del validador %.1f), Debug cortado en ventana %d" % [
			_fight_s(), _target_s, IDEAL_CACHE_S.x, IDEAL_CACHE_S.y, _hits,
			(" (" + ", ".join(causes) + ")") if not causes.is_empty() else "", _deaths, _freezes, _payments_tray,
			_payments_time, _min_energy if _min_energy != INF else -1.0,
			_min_energy_window if _min_energy_window != INF else -1.0, VALIDATOR_MARGIN.get(_lap, 0.0),
			_debug_cut_in_window])
		print("  ACCIONES: pulsos %d, laseres %d, dashes %d, Filos %d, Embestidas %d, Debug %.1f s, cargas %d, plataformas pagadas %d (te fio %d, trampas plegadas %d), fichas minimas %d, devoluciones %d, bombas aturdidas %d, expulsiones de la ranura %d" % [
			_pulses, _lasers, _dashes, _edges, _rams, float(_debug_frames) / 60.0, _charges, _platforms_paid, _credits,
			_traps_folded, _tokens_min if _tokens_min != 999 else -1, _refunds, _bombs, _slot_pushes])
		print("  FASES: " + "; ".join(phases))
	finished.emit(0 if ok else 1)


func _note(text: String) -> void:
	_log.append(text)
	if _verbose:
		print("[vendor_bot %.1f] %s" % [_fight_s(), text])


func _trace_line() -> void:
	print("[trace %.1f] isak (%.0f,%.0f) %s %s v(%.0f,%.0f) e%.0f axis %.2f jump %s dbg %s/%s comp %s frozen %s | fase %d mira %d giro %s ataque %s ventana %s %.1f fichas %d devol %.1f bandeja %s cuenta %.1f | air %s" % [
		_fight_s(), _isak.global_position.x, _isak.global_position.y, _surface(), _isak.get_state_name(),
		_isak.velocity.x, _isak.velocity.y, GameState.debug_energy, _axis, _jump, DebugMode.is_active(),
		_debug_want, _isak.is_compressed(), _isak.is_frozen(), _boss.get_phase(), _boss.get_facing(),
		_boss.get_turn_stage(), _boss.get_attack_state(), _boss.is_window_open(), _boss.get_window_time_left(),
		_boss.get_tokens(), _boss.get_refund_left(), _boss.is_tray_open(), _boss.get_countdown_left(),
		_air.get("mode", &"-")])
	if _boss.get_phase() == 2:
		var boxes: PackedStringArray = []
		for b: SurpriseBox in _boss.get_boxes():
			boxes.append("%s/%s %s" % [b.content, b.get_state(), b.get_body_rect()])
		print("    cajas: " + "; ".join(boxes))


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
