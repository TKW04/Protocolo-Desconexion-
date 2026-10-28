## Bot del jefe El Visto (paso 19 de docs/propuesta-mundo-4.md §8, 2026-10-28;
## §7.3). Carga la escena principal (scenes/main.tscn, LevelRunner) en la arena
## 4-boss real y pelea con el Isak real pulsando SOLO acciones del Input Map
## (move_left / move_right, jump, run, pulse, laser, debug, gesture_swipe y
## ui_accept para cerrar las lineas importantes y la recompensa; sin Agitar,
## retirado el 2026-10-28); nunca Q ni pause, nunca teletransporta, no toca GameState durante
## la pelea ni llama a la API de dano del jefe. Como los bots de Alerta Mayor,
## Autoplay y La Curadora (tools/boss_bot.gd, tools/autoplay_bot.gd,
## tools/curator_bot.gd) es REACTIVO: una politica por fase que cada cuadro lee la
## API de Seen / BossBase / WeakPoint (get_phase, get_attack_state,
## get_dash_stage, get_appear_point, get_falling_columns, get_zone_rects,
## is_shield_up, get_stickers, get_sweep_rect, get_typing_state, get_ghosts...).
##
## Geometria (de la arena, lado izquierdo / derecho): burbuja baja (columnas 1-2
## y 17-18, fila 8, de una via: se sube saltando desde el suelo), burbuja fija
## (columnas 3-6 y 13-16, fila 6, de una via: se sube desde la baja), cargadores
## en las columnas 3, 7, 12 y 16 del suelo.
## - Fase 1 «Ghosting»: espera en el suelo sobre el cargador de la columna 7. Al
##   esfumarse El Visto enciende el Debug (lee el rastro); en la reaparicion
##   (detras, a 2 tiles) se gira, da un paso hacia el, pulso que marca, suelta el
##   Debug y laser. Sale de la columna de las burbujas que caen y apaga con el
##   pulso la zona «Visto» que tiene bajo los pies. Si la ventana se pierde, dash
##   a traves de la embestida.
## - Fase 2 «Grupo»: con Stickers en el suelo, va hacia el que se infla (o el mas
##   cercano) y lo desinfla con un pulso, uno a uno; con la arena limpia, sube a la
##   burbuja fija de su lado y, desde su borde interior y mirando al centro, pulsa
##   el escudo (una capa por pulso; Kernel, dos); el escudo estalla y El Visto cae
##   al suelo: baja, Debug, pulso, suelta el Debug y laser.
##   Apaga con el pulso el barrido «Visto» de su burbuja.
## - Fase 3 «Escribiendo…»: espera en el borde interior de la burbuja fija de su
##   lado; con el «escribiendo…» enciende el Debug y lo deja en silencio con un
##   pulso (desde ahi le llega); aturdido, otro pulso marca el check gris, suelta
##   el Debug y laser. Aturde con el pulso a los Fantasmas que reaparecen y los
##   remata con el laser; congelado, espera a que se acabe (sin Agitar).
##
## Perfiles (--profile):
## - ideal: pelea limpia (Debug solo hasta la marca, un golpe por ventana).
## - clumsy (torpe): validation_model de data/bosses/seen.json: golpes por
##   ventana (laps.<n>.windows; 0 = ventana perdida con early_debug_s de Debug),
##   segundos de Debug por ventana (laps.<n>.debug_s), un laser fallado por
##   ventana (misses_per_window, antes de marcar) y un dash por ventana
##   (dashes_per_window, al bajar al suelo tras ella).
## - idle (quieto): no hace nada (solo cierra las lineas): debe perder.
## Accesos (--lap 1|2|3): GameState.lap antes de cargar; El Visto lee laps.<n>.
##
## Mide: duracion de la pelea (tiempo de juego, desde que empieza hasta el golpe
## final) frente a target_duration_s y a la franja del paso 19 (Caché ideal
## 100-150 s), golpes, muertes, congelaciones (y cuantas por el mensaje), energia
## minima (toda la pelea, en ventana y por fase) y gasto por ventana frente al
## margen del validador, mensajes enviados, «escribiendo…» interrumpidos, escudos
## bloqueados, pulsos, laseres y dashes; al final, la recompensa
## (boss_w4_l<n> sin guardar) y la vuelta al hub con 4-boss completado, el Mundo 5
## disponible y, en Caché, la pieza coral encendida y la cuarta ranura del candado
## de M6. Usa user://bot_save.json (borrado al empezar). Lo lanza
## tools/play_boss_bot.gd -- --boss seen; lo ejecuta tests/test_seen_bot.gd.
extends Node

signal finished(code: int)

const MAIN_SCENE: String = "res://scenes/main.tscn"
const BOT_SAVE_PATH: String = "user://bot_save.json"
const BOSS_DATA: String = "res://data/bosses/seen.json"
const LEVEL_DATA: String = "res://data/levels/4-boss.json"
const LEVEL_ID: String = "4-boss"
const UPGRADE_4_6: StringName = &"hub_update_4_6"
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
const LEFT: String = "left"
const RIGHT: String = "right"
## Margen de energia del validador de arenas (tools/validate_boss.py, pelea
## torpe, paso 17; sin Agitar desde el 2026-10-28: el minimo de las tres fases por
## acceso). Solo informe.
const VALIDATOR_MARGIN: Dictionary = {1: 50.0, 2: 47.5, 3: 47.5}
## Duracion pedida al bot ideal en Caché (paso 19, s de juego).
const IDEAL_CACHE_S: Vector2 = Vector2(100.0, 150.0)
const MAX_FIGHT_S: float = 600.0
const MAX_IDLE_S: float = 1200.0
const MAX_AFTER_S: float = 60.0
const LINE_READ_FRAMES: int = 10
## Radio del pulso (data/isak_abilities.json) y margen al apuntar.
const PULSE_RADIUS: float = 96.0
const REACH_MARGIN: float = 12.0
## Por debajo de esta energia va a recargar cuando nada amenaza.
const RECHARGE_BELOW: Dictionary = {"ideal": 45.0, "clumsy": 60.0}
## Margen (px) a cada lado del cuerpo frente a las burbujas que caen.
const FALL_MARGIN_PX: float = 10.0
const BODY_HALF_PX: float = 20.0
## Columna de espera en la fase 1 (sobre el cargador) y en el suelo con Stickers.
const HOME_COL_P1: float = 7.5
const STICKER_FLOOR_COL: float = 10.5
## Distancia (px) a la que se planta frente a un Sticker para pulsarlo.
const STICKER_PULSE_PX: float = 96.0

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
var _boss: Seen
var _tile: float = 64.0
var _floor_y: float = 640.0
## Geometria por lado: ledge (burbuja baja x0, x1), ledge_y, plat (burbuja fija
## x0, x1), plat_y, inner (+1 / -1: de la pared al centro), launch_x (suelo),
## ledge_jump_x, shield_x (burbuja fija: pulso al escudo), wait_x (fase 3).
var _geo: Dictionary = {}

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
var _home: String = LEFT
var _last_attack: StringName = &""
var _was_frozen: bool = false
## Fase 1: la reaparicion se dio por perdida (el torpe) o fallo: dash.
var _charge_dashed: bool = false

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
var _freezes_message: int = 0
var _messages: int = 0
var _interrupts: int = 0
var _shield_blocked: int = 0
var _ghost_stuns: int = 0
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
	_runner = (load(MAIN_SCENE) as PackedScene).instantiate() as LevelRunner
	_runner.start_level_id = LEVEL_ID
	add_child(_runner)
	_note("perfil %s, acceso %s (vuelta %d)" % [_profile, ACCESS_NAMES[_lap], _lap])


## Progreso de quien acaba de completar el 4-3: Eco, Notas, Calc y la Linterna
## conocidos, las seis habilidades (sin Agitar, retirado), los avisos vistos, la
## actualizacion del hub instalada, los recuerdos de los jefes 1-3 y la fila de
## El Visto desbloqueada, en la vuelta pedida.
func _setup_progress() -> void:
	GameState.lap = _lap
	for ally: StringName in [GameState.ALLY_ECO, GameState.ALLY_NOTAS, GameState.ALLY_CALC, GameState.ALLY_LINTERNA]:
		GameState.meet_ally(ally)
	for ability: StringName in [GameState.ABILITY_PULSE, GameState.ABILITY_LASER, GameState.ABILITY_DEBUG,
			GameState.ABILITY_DASH, GameState.ABILITY_GROUND_POUND, GameState.ABILITY_COMPRESS]:
		GameState.obtain_ability(ability)
		GameState.seen_notices[ability] = true
	for id: StringName in [&"1-1", &"1-2", &"1-3", &"1-boss", &"2-1", &"2-2", &"2-3", &"2-boss", &"3-1", &"3-2",
			&"3-3", &"3-boss"]:
		GameState.unlock_level(id)
		GameState.mark_level_completed(id)
	GameState.install_hub_upgrade(UPGRADE_4_6)
	for id: StringName in [&"4-1", &"4-2", &"4-3"]:
		GameState.unlock_level(id)
		GameState.mark_level_completed(id)
	GameState.unlock_level(&"4-boss")
	for n: int in [1, 2, 3]:
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
			if node is Seen:
				_boss = node as Seen
				break
		if _boss != null:
			_hook_boss()


func _hook_boss() -> void:
	_hooked = true
	_tile = float(World4ObjectsConfig.tile_size())
	var arena: Dictionary = _boss_cfg.get("arena", {})
	var lane: Dictionary = (arena.get("lanes", {}) as Dictionary).get("floor", {})
	_floor_y = float(lane.get("surface_row", 10)) * _tile
	var low: Dictionary = {}
	var fixed: Dictionary = {}
	for node: Node in _all_nodes(_level):
		var b := node as ChatBubble
		if b == null:
			continue
		var r: Rect2 = b.get_card_rect()
		var side: String = _boss.side_of_x(r.get_center().x)
		if r.position.y > 7.0 * _tile:
			low[side] = r
		else:
			fixed[side] = r
	for side: String in [LEFT, RIGHT]:
		var lr: Rect2 = low.get(side, Rect2())
		var fr: Rect2 = fixed.get(side, Rect2())
		var inner: float = 1.0 if side == LEFT else -1.0
		var ledge := Vector2(lr.position.x, lr.end.x)
		var ledge_inner: float = ledge.y if side == LEFT else ledge.x
		var plat := Vector2(fr.position.x, fr.end.x)
		var plat_inner: float = plat.y if side == LEFT else plat.x
		var plat_outer: float = plat.x if side == LEFT else plat.y
		_geo[side] = {
			"inner": inner,
			"ledge": ledge, "ledge_y": lr.position.y, "ledge_inner": ledge_inner,
			"plat": plat, "plat_y": fr.position.y, "plat_inner": plat_inner, "plat_outer": plat_outer,
			"launch_x": ledge_inner + inner * 24.0,
			"ledge_jump_x": ledge_inner - inner * 20.0,
			"ledge_home_x": ledge_inner - inner * 20.0,
			"shield_x": plat_inner - inner * 26.0,
			"wait_x": plat_inner - inner * 26.0,
		}
		if _verbose:
			_note("geometria %s: burbuja baja %s (y %.0f), fija %s (y %.0f)" % [side, ledge, lr.position.y, plat,
				fr.position.y])
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
	_boss.message_sent.connect(func(frozen: bool) -> void:
		_messages += 1
		if frozen:
			_freezes_message += 1
		if _verbose:
			_note("el mensaje sale (congela %s)" % frozen))
	_boss.typing_interrupted.connect(func() -> void: _interrupts += 1)
	_boss.shield_blocked.connect(func() -> void:
		_shield_blocked += 1
		if _verbose:
			_note("pulso al escudo con Stickers vivos: no cede"))
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
	if _boss.get_dash_stage() == Seen.DASH_CHARGE and _boss.get_silhouette_rect().intersects(body):
		return "embestida"
	if _boss.is_bubble_falling():
		return "burbuja"
	for g: Ghost in _boss.get_ghosts():
		if g.get_body_rect().intersects(body):
			return "fantasma"
	for s: Sticker in _boss.get_stickers():
		if s.get_body_rect().grow(96.0).intersects(body):
			return "sticker"
	if _boss.get_phase() == 2:
		return "troll"
	return "?"


func _on_window_opened(s: float) -> void:
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
	if _verbose:
		_note("ventana %d de la fase %d (%.1f s del mundo; quiere %d golpes; %s, x %.0f; energia %.0f)" % [
			_win_index, p, s, _window_goal(), _surface(), _isak.global_position.x, GameState.debug_energy])


func _on_window_closed() -> void:
	if _profile == "clumsy" and _window_dashes() > 0:
		_win_dash_pending = true
	if _verbose:
		_note("ventana cerrada (%d golpes; Debug %.1f s; gasto %.0f)" % [_win_hits, _win_debug_s, _win_spend])


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
	_win_dash_pending = false
	_recharging = false
	_charge_dashed = false
	_air = {}


func _on_attack(attack: StringName) -> void:
	_last_attack = attack
	if attack == Seen.ATTACK_GHOST_DASH:
		_charge_dashed = false
	if _verbose and attack != Seen.ATTACK_WINDOW:
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


func _fight_s() -> float:
	return float(_fight_frames) / 60.0


# --- Politica ---

func _fight() -> void:
	if _isak.is_dead() or _isak.is_warping():
		_debug_hold = false
		_air = {}
		return
	# Congelado: sin Agitar, se espera a que se acabe.
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
	var list: Array = _model_lap().get("debug_s", [3.0, 3.0, 4.0])
	return float(list[clampi(_boss.get_phase() - 1, 0, list.size() - 1)])


## Una ventana perdida del torpe: Debug early_debug_s y nada mas.
func _lost_window() -> bool:
	if not _boss.is_window_open() or _window_goal() != 0:
		return false
	_want_debug(_win_debug_s < _model_phase_value("early_debug_s", 2.0))
	return true


## Ventana: Debug -> pulso que marca el punto debil -> soltar el Debug -> laser,
## desde donde esta (ya a tiro). El torpe falla un laser antes de marcar y deja
## el Debug debug_s. Verdadero si actua (esta a tiro y mirando al nucleo).
func _strike(core_at: Vector2) -> void:
	var core: WeakPoint = _boss.get_core()
	var marked: bool = core != null and core.is_marked()
	if _profile == "clumsy":
		_want_debug(_win_debug_s < _clumsy_debug_s() or not marked)
	else:
		_want_debug(not marked)
	_face_x(core_at.x)
	if _isak.facing != signf(core_at.x - _isak.global_position.x) and absf(core_at.x - _isak.global_position.x) > 4.0:
		return
	if not marked:
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


## El pulso desde el celular alcanza `p` (con margen).
func _pulse_reaches_point(p: Vector2) -> bool:
	return _pulse_center().distance_to(p) <= PULSE_RADIUS - REACH_MARGIN


## Pulso del celular si Isak mirase hacia `dir`.
func _pulse_center_facing(dir: float) -> Vector2:
	return _isak.global_position + Vector2(36.0 * dir, -56.0)


# --- Fase 1 «Ghosting» ---

func _phase1(window: bool) -> void:
	var stage: StringName = _boss.get_dash_stage()
	if window and _lost_window():
		_axis = 0.0
		return
	if window and _win_hits < _window_goal():
		_phase1_window()
		return
	# La embestida (ventana perdida o fallada): dash a traves de ella.
	if stage == Seen.DASH_CHARGE:
		_debug_off()
		var sil: Rect2 = _boss.get_silhouette_rect()
		var dx: float = sil.get_center().x - _isak.global_position.x
		if not _charge_dashed and absf(dx) < 200.0 and _try_dash(signf(dx)):
			_charge_dashed = true
		return
	if stage in [Seen.DASH_WARN, Seen.DASH_READY]:
		# Se gira hacia la reaparicion con el Debug ya encendido (leyo el rastro).
		_want_debug(_wants_early_debug())
		_approach_appear()
		return
	if stage in [Seen.DASH_VANISH, Seen.DASH_HIDDEN]:
		_want_debug(_wants_early_debug())
		_axis = 0.0
		return
	if stage == Seen.DASH_RETURN:
		_debug_off()
		_axis = 0.0
		return
	_debug_off()
	if _clumsy_dash():
		return
	# Burbujas que caen: fuera de sus columnas.
	if not _boss.get_falling_columns().is_empty():
		_dodge_falling()
		return
	# Zonas «Visto»: el pulso apaga la de debajo; si no, fuera.
	if _boss.get_attack_state() == Seen.ATTACK_SEEN_ZONES:
		_handle_zones()
		return
	if _need_recharge() and _try_recharge():
		return
	_go(&"floor", LEFT, HOME_COL_P1 * _tile, 6.0)


## Encender el Debug al esfumarse: el ideal lo quiere para la ventana que viene;
## el torpe lo enciende tambien en la ventana perdida (early_debug_s).
func _wants_early_debug() -> bool:
	if _profile == "clumsy" and _window_goal_next() == 0:
		return _win_debug_s < _model_phase_value("early_debug_s", 2.0)
	return true


## Golpes de la proxima ventana (la de la reaparicion que viene).
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


## Hacia la reaparicion: mirar hacia ella y acercarse hasta que el pulso la alcance.
func _approach_appear() -> void:
	var core_at: Vector2 = _boss.get_appear_point() + Vector2(0.0, -58.0)
	var dir: float = signf(core_at.x - _isak.global_position.x)
	if dir == 0.0:
		dir = _isak.facing
	if _pulse_center_facing(dir).distance_to(core_at) > PULSE_RADIUS - REACH_MARGIN - 6.0:
		_axis = dir * 0.5
		return
	_axis = 0.0
	_face_x(core_at.x)


func _phase1_window() -> void:
	var core_at: Vector2 = _boss.get_window_core_point(1)
	var dir: float = signf(core_at.x - _isak.global_position.x)
	if dir == 0.0:
		dir = _isak.facing
	if _pulse_center_facing(dir).distance_to(core_at) > PULSE_RADIUS - REACH_MARGIN - 4.0 \
			and not (_boss.get_core() != null and _boss.get_core().is_marked()):
		_want_debug(true)
		_axis = dir * 0.5
		return
	_strike(core_at)


func _dodge_falling() -> void:
	var cols: Array[int] = _boss.get_falling_columns()
	var ix: float = _isak.global_position.x
	if _x_safe_from_falling(ix, cols):
		_axis = 0.0
		return
	var best: float = INF
	var x: float = 1.5 * _tile
	while x <= 18.5 * _tile:
		if _x_safe_from_falling(x, cols) and (best == INF or absf(x - ix) < absf(best - ix)):
			best = x
		x += 8.0
	if best != INF:
		_walk_to(best, 3.0)
		_run = true


func _x_safe_from_falling(x: float, cols: Array[int]) -> bool:
	for c: int in cols:
		var r: Rect2 = _boss.get_falling_rect(c)
		if x + BODY_HALF_PX + FALL_MARGIN_PX > r.position.x and x - BODY_HALF_PX - FALL_MARGIN_PX < r.end.x:
			return false
	return true


func _handle_zones() -> void:
	var feet: Vector2 = _isak.global_position + Vector2(0.0, -1.0)
	var under: bool = false
	for r: Rect2 in _boss.get_zone_rects():
		if r.grow_individual(BODY_HALF_PX, 0.0, BODY_HALF_PX, 0.0).has_point(feet):
			under = true
	if not under:
		_axis = 0.0
		return
	if _isak.is_on_floor() and _try_pulse():
		return
	_axis = 0.0


# --- Fase 2 «Grupo» ---

func _phase2(window: bool) -> void:
	if window and _lost_window():
		_go(&"floor", LEFT, 8.0 * _tile, 6.0)
		return
	if window and _win_hits < _window_goal():
		_phase2_window()
		return
	if window:
		_debug_off()
		_go(&"floor", LEFT, HOME_COL_P1 * _tile, 6.0)
		return
	if _clumsy_dash():
		return
	# El barrido «Visto» de su burbuja: el pulso lo apaga.
	if _sweep_threat():
		return
	var stickers: Array[Sticker] = _boss.get_stickers()
	if not stickers.is_empty():
		_debug_off()
		if _surface() != &"floor":
			_go(&"floor", _home, STICKER_FLOOR_COL * _tile, 10.0)
			return
		# Uno a uno: el que se infla primero, si no el mas cercano; el pulso lo desinfla.
		var target: Sticker = _sticker_target(stickers)
		var r: Rect2 = target.get_body_rect()
		var dx: float = r.get_center().x - _isak.global_position.x
		var dir: float = signf(dx) if dx != 0.0 else _isak.facing
		if _rect_in_pulse(r):
			_axis = 0.0
			if _isak.facing != dir:
				_face_x(r.get_center().x)
				return
			_try_pulse()
			return
		_walk_to(clampf(r.get_center().x - dir * STICKER_PULSE_PX, 1.5 * _tile, 18.5 * _tile), 10.0)
		return
	if _need_recharge() and _surface() == &"floor" and _try_recharge():
		return
	# Arena limpia: a la burbuja fija y pulso al escudo desde su borde interior.
	var sx: float = _g(_home, "shield_x")
	if _surface() == &"plat" and _side_here() == _home and absf(_isak.global_position.x - sx) <= 14.0:
		_axis = 0.0
		var shield: Rect2 = _boss.get_shield_rect()
		if _isak.facing != signf(shield.get_center().x - _isak.global_position.x):
			_face_x(shield.get_center().x)
			return
		# El Debug ya cargando para la ventana que viene (k = 2 con el Debug activo).
		_want_debug(_profile != "clumsy" or _window_goal_next() != 0)
		if _rect_in_pulse(shield):
			_try_pulse()
		return
	_debug_off()
	_go(&"plat", _home, sx, 6.0)


## Sticker al que ir: el que se infla (el mas cercano de ellos) o el mas cercano.
func _sticker_target(stickers: Array[Sticker]) -> Sticker:
	var best: Sticker = null
	var best_key: float = INF
	for s: Sticker in stickers:
		var d: float = absf(s.get_body_rect().get_center().x - _isak.global_position.x)
		var key: float = d - (10000.0 if s.is_inflating() else 0.0)
		if key < best_key:
			best_key = key
			best = s
	return best


## El barrido «Visto» de la burbuja fija de su lado: el pulso lo apaga (desde la
## burbuja o desde la baja, que le llega); sin pulso, espera en la baja. Verdadero si actua.
func _sweep_threat() -> bool:
	var s: StringName = _surface()
	if _boss.get_zone_state() == Seen.ZONE_OFF or not s in [&"plat", &"ledge"]:
		return false
	var r: Rect2 = _boss.get_sweep_rect()
	if _side_of(r.get_center().x) != _side_here():
		return false
	var dir: float = signf(r.get_center().x - _isak.global_position.x)
	var o: Vector2 = _pulse_center_facing(dir if s == &"ledge" else _isak.facing)
	var closest := Vector2(clampf(o.x, r.position.x, r.end.x), clampf(o.y, r.position.y, r.end.y))
	if o.distance_to(closest) <= PULSE_RADIUS - REACH_MARGIN:
		_axis = 0.0
		if s == &"ledge":
			_face_x(r.get_center().x)
			if _isak.facing != dir:
				return true
		_try_pulse()
		return true
	if s == &"ledge":
		_axis = 0.0
		return true
	var feet: Vector2 = _isak.global_position + Vector2(0.0, -1.0)
	if r.grow_individual(BODY_HALF_PX, 0.0, BODY_HALF_PX, 0.0).has_point(feet):
		_axis = 0.0
		_try_pulse()
		return true
	return false


func _phase2_window() -> void:
	var core_at: Vector2 = _boss.get_window_core_point(2)
	if _profile != "clumsy":
		_want_debug(not (_boss.get_core() != null and _boss.get_core().is_marked()))
	else:
		_want_debug(true)
	var spot: float = core_at.x - 36.0 - 52.0
	if _surface() != &"floor" or absf(_isak.global_position.x - spot) > 10.0:
		_go(&"floor", _home, spot, 6.0)
		return
	_strike(core_at)


# --- Fase 3 «Escribiendo…» ---

func _phase3(window: bool) -> void:
	var wait_x: float = _g(_home, "wait_x")
	if window and _lost_window():
		return
	if window and _win_hits < _window_goal():
		var core_at: Vector2 = _boss.get_window_core_point(3)
		var spot_ok: bool = _surface() == &"plat" and _side_here() == _home and absf(_isak.global_position.x - wait_x) <= 14.0
		if not spot_ok and not _pulse_reaches_point(core_at):
			_want_debug(true)
			_go(&"plat", _home, wait_x, 6.0)
			return
		_strike(core_at)
		return
	if _clumsy_dash():
		return
	if _ghost_reflex():
		return
	var typing: StringName = _boss.get_typing_state()
	if typing == Seen.TYPING_ON:
		var spot_ok2: bool = _surface() == &"plat" and _side_here() == _home and absf(_isak.global_position.x - wait_x) <= 14.0
		if not spot_ok2:
			# Lejos de su sitio (volvia de recargar): desde el suelo bajo la burbuja
			# «escribiendo…» tambien le llega el pulso; despues sube en la ventana.
			var lost2: bool = _profile == "clumsy" and _window_goal_next() == 0
			var tr: Rect2 = _boss.get_typing_rect()
			if not lost2 and _surface() == &"floor" and _rect_in_pulse(tr):
				_axis = 0.0
				_want_debug(true)
				_face_x(tr.get_center().x)
				var hurry: bool = _boss.get_dots() >= _boss.get_dots_total() - 1 and _boss.get_next_dot_left() < 0.5
				if DebugMode.is_active() or hurry:
					_try_pulse()
				return
			_want_debug(not lost2)
			if _surface() == &"floor" and tr.position.x - 40.0 < _isak.global_position.x \
					and _isak.global_position.x < tr.end.x + 40.0 and not lost2:
				_go(&"floor", _home, tr.position.x + 48.0, 6.0)
				return
			_go(&"plat", _home, wait_x, 6.0)
			return
		_axis = 0.0
		var lost_next: bool = _profile == "clumsy" and _window_goal_next() == 0
		if lost_next:
			# El torpe pierde la ventana: deja que llegue el mensaje (se espera la congelacion).
			_want_debug(_boss.get_dots() >= 1)
			return
		_want_debug(true)
		var rect: Rect2 = _boss.get_typing_rect()
		var dir: float = signf(rect.get_center().x - _isak.global_position.x)
		if _isak.facing != dir:
			_face_x(rect.get_center().x)
			return
		# Interrumpe en cuanto el Debug esta activo (o antes del ultimo punto).
		var last_call: bool = _boss.get_dots() >= _boss.get_dots_total() - 1 and _boss.get_next_dot_left() < 0.5
		if DebugMode.is_active() or last_call:
			_try_pulse()
		return
	_debug_off()
	# Recarga en el hueco entre «escribiendo…» (typing_gap_s) si da tiempo a volver.
	if _need_recharge() and typing == Seen.TYPING_IDLE and _boss.get_attack_state() != Seen.ATTACK_MESSAGE:
		if _surface() == &"floor" or _surface() == &"air":
			if _try_recharge():
				return
		else:
			_go(&"floor", _home, 7.5 * _tile, 6.0)
			return
	_go(&"plat", _home, wait_x, 6.0)


## Fantasmas pequenos: el pulso los aturde al reaparecer cerca y el laser los
## remata aturdidos. Verdadero si actua.
func _ghost_reflex() -> bool:
	var ix: Vector2 = _isak.global_position
	for g: Ghost in _boss.get_ghosts():
		var body: Rect2 = g.get_body_rect()
		var c: Vector2 = body.get_center()
		if absf(c.y - (ix.y - 48.0)) > 70.0 or absf(c.x - ix.x) > 260.0:
			continue
		if g.is_stunned():
			# Rematarlo con el laser solo si el haz (a la altura del celular) le da y sobra energia.
			var phone_y: float = ix.y - 56.0
			var in_line: bool = phone_y >= body.position.y + 4.0 and phone_y <= body.end.y - 4.0
			if in_line and GameState.debug_energy >= 40.0 and absf(c.x - ix.x) < 420.0 and _isak.is_on_floor() \
					and g.get_stun_left() > 0.4:
				_axis = 0.0
				_face_x(c.x)
				if _isak.facing == signf(c.x - ix.x):
					_try_laser()
				return true
			continue
		if not g.is_visible_ghost():
			continue
		var dir: float = signf(c.x - ix.x)
		if dir == 0.0:
			dir = _isak.facing
		var o: Vector2 = _pulse_center_facing(dir)
		var closest := Vector2(clampf(o.x, body.position.x, body.end.x), clampf(o.y, body.position.y, body.end.y))
		if o.distance_to(closest) <= PULSE_RADIUS - REACH_MARGIN and _isak.is_on_floor():
			_axis = 0.0
			_face_x(c.x)
			if _isak.facing == dir and _try_pulse():
				_ghost_stuns += 1
			return true
		# Embiste hacia Isak de cerca: dash a traves.
		if g.get_state() == &"charge" and absf(c.x - ix.x) < 150.0 and _try_dash(dir):
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


## Va al cargador listo mas cercano por el suelo. Falso si no hay.
func _try_recharge() -> bool:
	var best: Charger = null
	var ix: float = _isak.global_position.x
	for node: Node in _all_nodes(_level):
		var c := node as Charger
		if c == null or not c.is_ready():
			continue
		var cx: float = c.global_position.x + _tile * 0.5
		if best == null or absf(cx - ix) < absf(best.global_position.x + _tile * 0.5 - ix):
			best = c
	if best == null:
		return false
	_go(&"floor", _home, best.global_position.x + _tile * 0.5, 6.0)
	return true


## Torpe: un dash por ventana al volver al suelo tras ella.
func _clumsy_dash() -> bool:
	if not _win_dash_pending or _surface() != &"floor" or not _dash_ready():
		return false
	var dir: float = 1.0 if _isak.global_position.x < 9.5 * _tile else -1.0
	if _try_dash(dir):
		_win_dash_pending = false
		return true
	return false


# --- Movimiento (como tools/curator_bot.gd: burbuja baja = repisa, fija = plataforma) ---

func _g(side: String, key: String) -> Variant:
	return (_geo.get(side, {}) as Dictionary).get(key)


func _side_of(x: float) -> String:
	return _boss.side_of_x(x)


func _side_here() -> String:
	return _side_of(_isak.global_position.x)


## floor, ledge (burbuja baja), plat (burbuja fija) o air.
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
	if kind == &"floor":
		return _walk_to(x, tol)
	var lx: float = _g(side, "launch_x")
	if absf(ix - lx) > 6.0 or absf(_isak.velocity.x) > 40.0:
		_walk_to(lx, 3.0)
		return false
	_launch(&"ledge", side, x)
	return false


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
			var py: float = _g(side2, "plat_y")
			if fy > py - 4.0 and _isak.velocity.y < 0.0:
				# Subiendo por debajo de la burbuja: aun no se avanza (que no choque con el canto).
				_axis = 0.0
			else:
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


func _face_x(x: float) -> void:
	var want: float = signf(x - _isak.global_position.x)
	if want != 0.0 and want != _isak.facing and _axis == 0.0:
		_axis = want * 0.2


func _pulse_center() -> Vector2:
	return _isak.global_position + _isak.get_pulse_origin()


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
	var layer: StringName = StringName("boss_w4_l%d" % _lap)
	var ok: bool = true
	var checks: Array = [
		["4-boss completado", GameState.is_level_completed(&"4-boss")],
		["recuerdo %s sin guardar" % layer, GameState.has_memory(layer) and GameState.has_unsaved_changes()],
		["Mundo 5 disponible", HubWorlds.folder_state(HubWorlds.world(&"m5")) == HubWorlds.STATE_AVAILABLE],
	]
	# La pieza coral depende de la carpeta del acceso actual: solo Caché tiene hoy
	# las filas del Mundo 4 (los subniveles de Kernel y Raíz aun no existen).
	if _lap == 1:
		checks.append(["pieza coral encendida", hub.get_piece_animation(4) == &"on"])
		var m6: FolderStation = hub.get_folder(&"m6")
		checks.append(["cuarta ranura del candado", m6 != null and m6.get_lock_slots_lit() == 4])
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
	var label: String = "play_boss_bot seen (%s, %s)" % [ACCESS_NAMES.get(_lap, "?"), _profile]
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
		print("  RESULTADO: pelea %.1f s (objetivo %.0f s; ideal en Caché %.0f-%.0f s), golpes %d%s, muertes %d, congelaciones %d (por el mensaje %d), energia minima %.0f (en ventana %.0f; margen del validador %.1f), Debug cortado en ventana %d" % [
			_fight_s(), _target_s, IDEAL_CACHE_S.x, IDEAL_CACHE_S.y, _hits,
			(" (" + ", ".join(causes) + ")") if not causes.is_empty() else "", _deaths, _freezes, _freezes_message,
			_min_energy if _min_energy != INF else -1.0, _min_energy_window if _min_energy_window != INF else -1.0,
			VALIDATOR_MARGIN.get(_lap, 0.0), _debug_cut_in_window])
		print("  ACCIONES: pulsos %d, laseres %d, dashes %d, Debug %.1f s, cargas %d, mensajes enviados %d, «escribiendo…» interrumpidos %d, escudos bloqueados %d, fantasmas aturdidos %d" % [
			_pulses, _lasers, _dashes, float(_debug_frames) / 60.0, _charges, _messages, _interrupts,
			_shield_blocked, _ghost_stuns])
		print("  FASES: " + "; ".join(phases))
	finished.emit(0 if ok else 1)


func _note(text: String) -> void:
	_log.append(text)
	if _verbose:
		print("[seen_bot %.1f] %s" % [_fight_s(), text])


func _trace_line() -> void:
	var ghosts: PackedStringArray = []
	for g: Ghost in _boss.get_ghosts():
		ghosts.append("%s(%.0f,%.0f)" % [g.get_state(), g.global_position.x, g.global_position.y])
	print("[trace %.1f] isak (%.0f,%.0f) %s %s v(%.0f,%.0f) e%.0f axis %.2f jump %s dbg %s/%s frozen %s | fase %d ataque %s dash %s ventana %s %.1f escudo %s stickers %d typing %s %d | air %s | fantasmas %s" % [
		_fight_s(), _isak.global_position.x, _isak.global_position.y, _surface(), _isak.get_state_name(),
		_isak.velocity.x, _isak.velocity.y, GameState.debug_energy, _axis, _jump, DebugMode.is_active(),
		_debug_want, _isak.is_frozen(), _boss.get_phase(), _boss.get_attack_state(), _boss.get_dash_stage(),
		_boss.is_window_open(), _boss.get_window_time_left(), _boss.is_shield_up(), _boss.get_stickers().size(),
		_boss.get_typing_state(), _boss.get_dots(), _air.get("mode", &"-"), ", ".join(ghosts)])


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
