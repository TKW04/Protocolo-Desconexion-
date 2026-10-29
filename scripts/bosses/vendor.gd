## El Vendedor, jefe del Mundo 5 «La Tienda» (docs/propuesta-mundo-5.md §5; pasos
## 15-16 de §8, 2026-10-29). Un BossBase con tres fases; datos en
## data/bosses/vendor.json (arena, turn, priced_platforms, arm_sweep, coins, boxes,
## offer, phase1-3, laps, texts) y las fichas en data/economy.json (boss_tokens).
## Arena data/levels/5-boss.json «Gran almacén» (20 x 11, camara fija).
##
## - Cuerpo: maquina expendedora de 4 x 5 tiles, SOLIDA (StaticBody2D de la capa
##   world hecho aqui: techo y cuerpo, ranura de la fila 7, fila 8 y bandeja de la
##   fila 9). SIEMPRE TE ATIENDE DE FRENTE: mira a un lado (get_facing) y, cuando Isak
##   pasa al otro lado de la maquina, se gira laps.<n>.turn_s s del mundo despues
##   (aviso turn.warn_frames antes; giro de turn.anim_s en el que el boton sigue en la
##   espalda vieja). El «Cancelar» (WeakPoint) va en la ESPALDA a la altura del
##   celular de Isak de pie en el suelo y solo esta activo con Isak DETRAS (o
##   marcado: la marca es del boton y no cae al girarse). Debug (revela) -> pulso con
##   el Debug ACTIVO (marca) -> laser (un golpe por marca, sin Debug). En las fases 1
##   y 2 el golpe hace que se gire ya (un golpe por ventana). Nada mas hace dano.
## - Fase 1 «Plataformas con precio»: cuatro plataformas de una via (a, b; c, d) que
##   aparecen al pagar su etiqueta con un pulso (fichas; con 0, «te fio» y una
##   Suscripcion que drena energia) y duran life_s; las trampas (laps.<n>.traps) se
##   pliegan fold_s despues de pisarlas (al caer, -10 y empuje al frente). Desde ellas
##   al techo de la maquina y por detras. Brazo que barre un estante y monedas.
## - Fase 2 «Sorpresa»: tandas de cajas (SurpriseBox) lanzadas con contenido fijo:
##   fichas, energia, bomba (mecha fuse_s tras caer; el pulso la aturde y sirve de
##   escalon) y ticket de devolucion (abrirlo: «Procesando devolución…» refund_s, no
##   se gira y la bandeja-tunel se abre). Brazo que barre.
## - Fase 3 «Oferta por tiempo limitado»: cuenta laps.<n>.countdown_s (tic por
##   segundo); no se gira; tira de Isak hacia la bandeja (por delante) o hacia la
##   maquina (por detras) como una Oferta (grupo offer_sign, get_pull_weight). Dos
##   caminos a la espalda: Embestida sobre el escaparate (persiana de pared en el
##   techo, pegada a la espalda; se repone en cada cuenta) desde una vitrina, o Filo
##   por la ranura (Isak en ella sin el Filo sale empujado). Tocar la bandeja o llegar
##   a 0: «Procesando pago…» (congelado pay_freeze_s; nada ataca) y la cuenta vuelve a
##   empezar. Monedas.
## - Llegada, intro, reaparicion por fase (energia >= 50 y las fichas de esa fase),
##   golpe final y secuencia de derrota como El Visto (BossBase, BossDefeat). Sin
##   rollback. Arte PROVISIONAL por codigo (VendorFx; el final es el paso 24). Tiempo
##   del mundo (advance; las pruebas lo llaman a mano con auto_process falso).
class_name Vendor
extends BossBase

## Empieza un ataque (arm_sweep, coins, boxes) o la ventana (window).
signal attack_started(attack: StringName)
## Cambia el lado al que mira (-1 izquierda, +1 derecha).
signal turned(facing: int)
## Empieza el aviso del giro (brazos que se recogen y sonrisa que parpadea).
signal turn_warned
## Cambian las fichas (`tokens`, las que quedan).
signal tokens_changed(tokens: int)
## Se paga una plataforma (`credit`: con 0 fichas, «te fio»).
signal platform_paid(platform: StringName, credit: bool)
## Una plataforma trampa se pliega.
signal platform_folded(platform: StringName)
## Explota una bomba en `at` (global).
signal bomb_exploded(at: Vector2)
## Empieza / termina «Procesando devolución…» (fase 2).
signal refund_started
signal refund_finished
## Un segundo de la cuenta de la fase 3 (`left`, los que quedan; sfx_w5_countdown).
signal countdown_ticked(left: int)
## «Compra realizada» / la cuenta a 0: «Procesando pago…» (`by_tray`: por tocar la bandeja).
signal payment_processed(by_tray: bool)
## Isak sale empujado de la ranura (fase 3).
signal slot_pushed(direction: float)
## Golpe final (contador a 0).
signal final_blow
signal disarmed

const SHUTTER_SCENE: PackedScene = preload("res://scenes/levels/shutter.tscn")
const BOX_SCENE: PackedScene = preload("res://scenes/levels/surprise_box.tscn")
const WEAK_POINT_SCENE: PackedScene = preload("res://scenes/bosses/weak_point.tscn")
const ECONOMY_PATH: String = "res://data/economy.json"

const ATTACK_ARM_SWEEP: StringName = &"arm_sweep"
const ATTACK_COINS: StringName = &"coins"
const ATTACK_BOXES: StringName = &"boxes"
const ATTACK_WINDOW: StringName = &"window"
const ATTACK_GAP: StringName = &"gap"

## Etapas del giro.
const TURN_NONE: StringName = &"none"
const TURN_PENDING: StringName = &"pending"
const TURN_WARN: StringName = &"warn"
const TURN_TURNING: StringName = &"turning"

## Quien congela en «Procesando pago…» (Isak.freeze).
const FREEZE_SOURCE_PAY: StringName = &"vendor_pay"

const PLATFORM_NAMES: Array[String] = ["a", "b", "c", "d"]
const ARENA_COLS: int = 20
const ARENA_ROWS: int = 11
## Alto de la tabla de una via de las plataformas (px).
const PLATFORM_THICK_PX: float = 16.0
const SIDE_LEFT: int = -1
const SIDE_RIGHT: int = 1

## Id del objeto en el nivel (params.id).
@export var object_id: StringName = &""
## Con Isak llegando por el vortice, espera a que termine y dice la intro.
@export var intro_on_arrival: bool = true

var _arena: Dictionary = {}
var _texts: Dictionary = {}
var _lap: Dictionary = {}
var _tokens_cfg: Dictionary = {}
var _tile: float = 64.0
var _intro_state: int = 0
var _defeat_seq: BossDefeat
var _core: WeakPoint
var _machine: StaticBody2D
var _slot_shape: CollisionShape2D
var _tray_shape: CollisionShape2D
var _attacks: Node2D
var _fx: VendorFx
var _body_tex: Texture2D
var _burst: PixelBurst
var _off: bool = false
var _time: float = 0.0
var _rng := RandomNumberGenerator.new()
# Lado al que mira y giro.
var _facing: int = SIDE_LEFT
var _isak_side: int = SIDE_LEFT
var _turn: StringName = TURN_NONE
var _turn_t: float = 0.0
var _behind_open: bool = false
# Fichas.
var _tokens: int = 0
var _phase_tokens: int = 0
var _credit_subs: Array[Subscription] = []
# Linea de tiempo de los ataques.
var _attack: StringName = &""
var _attack_t: float = 0.0
var _attack_index: int = 0
var _gap_left: float = 0.0
var _sweep_side: int = SIDE_LEFT
var _sweep_count: int = 0
var _sweep_hit: bool = false
var _coin_cols: Array[int] = []
var _coin_hit: Array[bool] = []
# Fase 1: plataformas con precio (nombre -> estado).
var _platforms: Dictionary = {}
var _trap_drop_left: float = 0.0
# Fase 2: cajas.
var _boxes: Array[SurpriseBox] = []
var _box_info: Dictionary = {}
var _batch_wait: float = 0.0
var _batch_index: int = 0
var _refund_left: float = 0.0
# Fase 3: oferta, escaparate, vitrinas y ranura.
var _countdown_left: float = 0.0
var _last_tick: int = -1
var _shutter: Shutter
var _showcases: Array[StaticBody2D] = []
var _slot_passing: bool = false
var _slot_entry: int = SIDE_LEFT
var _sign: String = ""
var _sign_left: float = 0.0


func _ready() -> void:
	if boss_id.is_empty():
		boss_id = &"vendor"
	super._ready()
	var cfg: Dictionary = get_config()
	_arena = cfg.get("arena", {})
	_texts = cfg.get("texts", {})
	_tile = float(World5ObjectsConfig.tile_size())
	_lap = _lap_entry()
	_tokens_cfg = _load_tokens_cfg()
	_facing = SIDE_LEFT if int(_arena.get("start_facing", -1)) < 0 else SIDE_RIGHT
	_tokens = int(_tokens_cfg.get("start", 12))
	_build()
	EventBus.pulse_fired.connect(_on_pulse_fired)
	_apply_lap_settings.call_deferred()


func _physics_process(delta: float) -> void:
	if _intro_state == 0 and intro_on_arrival and not is_fighting() and not is_defeated():
		_poll_arrival()
	super._physics_process(delta)


func advance(dt: float) -> void:
	_time += dt
	_sign_left = maxf(_sign_left - dt, 0.0)
	if not is_fighting():
		_refresh()
		return
	super.advance(dt)


# --- Consultas (HUD, bot y pruebas) ---

func get_core() -> WeakPoint:
	return _core


func get_machine_body() -> StaticBody2D:
	return _machine


func get_attack_state() -> StringName:
	if not is_fighting():
		return ATTACK_NONE
	if is_window_open():
		return ATTACK_WINDOW
	return _attack if _attack != &"" else ATTACK_NONE


func lap_value(key: String, fallback: Variant) -> Variant:
	return _lap.get(key, fallback)


func section(key: String) -> Dictionary:
	return get_config().get(key, {})


func phase_data(phase_index: int) -> Dictionary:
	return section("phase%d" % phase_index)


## Aviso de `frames` cuadros a anim_fps (s del mundo).
func frames_s(frames: Variant) -> float:
	return float(frames) / maxf(float(_arena.get("anim_fps", 12.0)), 1.0)


## Rectangulo global de la maquina.
func get_machine_rect() -> Rect2:
	return _cells_rect(_arena.get("machine", [8, 5, 4, 5]))


## Ranura de monedas (fila slot_row de lado a lado de la maquina), global.
func get_slot_rect() -> Rect2:
	var m: Rect2 = get_machine_rect()
	var row: int = int(_arena.get("slot_row", 7))
	return Rect2(m.position.x, _to_global(Vector2(0.0, float(row) * _tile)).y, m.size.x, _tile)


## Bandeja de salida (tunel de la fila tray_row bajo la maquina), global.
func get_tray_tunnel_rect() -> Rect2:
	var m: Rect2 = get_machine_rect()
	var row: int = int(_arena.get("tray_row", 9))
	return Rect2(m.position.x, _to_global(Vector2(0.0, float(row) * _tile)).y, m.size.x, _tile)


## La bandeja que se ve al frente (en el suelo, pegada a la cara de delante).
func get_tray_zone_rect() -> Rect2:
	var t: Rect2 = get_tray_tunnel_rect()
	var w: float = float(_arena.get("tray_zone_tiles", 1)) * _tile
	var x: float = t.position.x - w if _facing == SIDE_LEFT else t.end.x
	return Rect2(x, t.position.y, w, t.size.y)


## Altura del suelo de la arena (los pies de Isak de pie en el suelo), global.
func get_floor_y() -> float:
	return _to_global(Vector2(0.0, float(int(_arena.get("floor_row", 9)) + 1) * _tile)).y


## Lado al que mira (-1 izquierda, +1 derecha).
func get_facing() -> int:
	return _facing


func get_turn_stage() -> StringName:
	return _turn


## S del mundo que faltan para que empiece a girarse (0 si no va a girarse).
func get_turn_left() -> float:
	if _turn == TURN_PENDING or _turn == TURN_WARN:
		return maxf(get_turn_s() - _turn_t, 0.0)
	return 0.0


func get_turn_s() -> float:
	return float(lap_value("turn_s", 1.2))


## Lado de la arena en el que esta `x` respecto a la maquina (0 = sobre ella).
func side_of_x(x: float) -> int:
	var m: Rect2 = get_machine_rect()
	if x < m.position.x:
		return SIDE_LEFT
	if x > m.end.x:
		return SIDE_RIGHT
	return 0


## Isak esta detras (al otro lado de la maquina del que mira).
func is_isak_behind() -> bool:
	return _isak_side == -_facing


## El «Cancelar» en la espalda (global): cara de detras a la altura del celular.
func get_core_point(facing: int = 0) -> Vector2:
	var f: int = facing if facing != 0 else _facing
	var m: Rect2 = get_machine_rect()
	var r: float = WeakPoint.radius_px() - float(_arena.get("core_inset_px", 8.0))
	var x: float = m.end.x + r if f == SIDE_LEFT else m.position.x - r
	return Vector2(x, get_floor_y() - float(_arena.get("core_dy_px", 58.0)))


func get_tokens() -> int:
	return _tokens


## Fichas que tenia al empezar la fase (vuelven al reaparecer).
func get_phase_tokens() -> int:
	return _phase_tokens


func get_platform_cost() -> int:
	return int(_tokens_cfg.get("priced_platform_cost", 2))


func get_credit_subscriptions() -> Array[Subscription]:
	var out: Array[Subscription] = []
	for s: Subscription in _credit_subs:
		if is_instance_valid(s) and not s.is_queued_for_deletion() and not s.is_defeated():
			out.append(s)
	return out


func get_attacks_root() -> Node2D:
	return _attacks


func get_time() -> float:
	return _time


func is_screen_off() -> bool:
	return _off


## Cartel de la maquina en curso («Procesando…», «Te fio»…); "" sin cartel.
func get_sign() -> String:
	return _sign if _sign_left > 0.0 or is_refunding() else ""


# Fase 1

## Plataforma con precio `name` (a-d): rectangulo de su superficie (alto de la tabla), global.
func get_platform_rect(platform: String) -> Rect2:
	var p: Array = (_arena.get("platforms", {}) as Dictionary).get(platform, [0, 0, 1])
	var pos: Vector2 = _to_global(Vector2(float(p[0]) * _tile, float(p[1]) * _tile))
	return Rect2(pos, Vector2(float(p[2]) * _tile, PLATFORM_THICK_PX))


## Etiqueta de la plataforma (centrada bajo la tabla), global.
func get_label_rect(platform: String) -> Rect2:
	var r: Rect2 = get_platform_rect(platform)
	var size: Array = _arena.get("label_px", [56.0, 32.0])
	var s := Vector2(float(size[0]), float(size[1]))
	return Rect2(Vector2(r.get_center().x - s.x * 0.5, r.position.y + 4.0), s)


func is_trap(platform: String) -> bool:
	return (lap_value("traps", ["b", "c"]) as Array).has(platform)


func is_platform_active(platform: String) -> bool:
	return _platforms.has(platform) and bool((_platforms[platform] as Dictionary)["active"])


func is_platform_folded(platform: String) -> bool:
	return _platforms.has(platform) and bool((_platforms[platform] as Dictionary)["folded"])


## La plataforma es solida (activa y sin plegar).
func is_platform_solid(platform: String) -> bool:
	return is_platform_active(platform) and not is_platform_folded(platform)


func get_platform_life_left(platform: String) -> float:
	return float((_platforms[platform] as Dictionary)["life"]) if is_platform_active(platform) else 0.0


# Ataques comunes

## Estante que barre el brazo ahora (Rect2() si no barre): el estante y 2 tiles encima.
func get_sweep_rect() -> Rect2:
	if _attack != ATTACK_ARM_SWEEP:
		return Rect2()
	var shelf: Array = (_arena.get("shelves", {}) as Dictionary).get("left" if _sweep_side == SIDE_LEFT else "right", [2, 8, 4])
	var top: Vector2 = _to_global(Vector2(float(shelf[0]) * _tile, float(int(shelf[1]) - 2) * _tile))
	return Rect2(top, Vector2(float(shelf[2]) * _tile, 2.0 * _tile))


## El brazo ya barre (tras su aviso).
func is_sweeping() -> bool:
	return _attack == ATTACK_ARM_SWEEP and _attack_t >= frames_s(section("arm_sweep").get("warn_frames", 9)) - 0.0001


func get_sweep_side() -> int:
	return _sweep_side


func get_coin_columns() -> Array[int]:
	var out: Array[int] = []
	if _attack == ATTACK_COINS:
		out.assign(_coin_cols)
	return out


func is_coin_falling() -> bool:
	return _attack == ATTACK_COINS and _attack_t >= frames_s(section("coins").get("warn_frames", 9)) - 0.0001


## Moneda de la columna `col` ahora (global; cae de la fila 1 al suelo).
func get_coin_rect(col: int) -> Rect2:
	var c: Dictionary = section("coins")
	var warn: float = frames_s(c.get("warn_frames", 9))
	var f: float = clampf((_attack_t - warn) / maxf(float(c.get("fall_s", 0.5)), 0.01), 0.0, 1.0)
	var top: float = _to_global(Vector2(0.0, _tile)).y
	var bottom: float = get_floor_y() - _tile * 0.5
	var x: float = _to_global(Vector2(float(col) * _tile, 0.0)).x
	return Rect2(Vector2(x + _tile * 0.25, lerpf(top, bottom, f)), Vector2(_tile * 0.5, _tile * 0.5))


# Fase 2

func get_boxes() -> Array[SurpriseBox]:
	var out: Array[SurpriseBox] = []
	for b: SurpriseBox in _boxes:
		if is_instance_valid(b) and not b.is_queued_for_deletion():
			out.append(b)
	return out


## Mecha que le queda a una bomba (s del mundo; -1 si no es bomba o no ha caido).
func get_fuse_left(box: SurpriseBox) -> float:
	if box == null or not _box_info.has(box.get_instance_id()):
		return -1.0
	var info: Dictionary = _box_info[box.get_instance_id()]
	return float(info["fuse"]) if bool(info["landed"]) and box.content == SurpriseBox.CONTENT_BOMB else -1.0


func is_refunding() -> bool:
	return _refund_left > 0.0


func get_refund_left() -> float:
	return _refund_left


func is_tray_open() -> bool:
	return _tray_shape != null and _tray_shape.disabled


# Fase 3

func get_countdown_left() -> float:
	return _countdown_left if get_phase() == 3 and is_fighting() else 0.0


func get_countdown_s() -> float:
	return float(lap_value("countdown_s", 15.0))


func get_shutter() -> Shutter:
	return _shutter if _shutter != null and is_instance_valid(_shutter) and not _shutter.is_queued_for_deletion() else null


func get_showcases() -> Array[StaticBody2D]:
	return _showcases.duplicate()


func is_slot_open() -> bool:
	return _slot_shape != null and _slot_shape.disabled


## Tiron de la oferta (TemptationField, grupo offer_sign; como OfferSign.get_pull_weight):
## en la fase 3, por delante hacia la bandeja y por detras hacia la maquina; 0 sin
## cuenta, con Isak congelado o a menos de `dead_zone_px`.
func get_pull_weight(point: Vector2, dead_zone_px: float = 4.0) -> float:
	if not is_pulling():
		return 0.0
	var m: Rect2 = get_machine_rect()
	var target: float = m.get_center().x
	var side: int = side_of_x(point.x)
	if side == _facing:
		target = get_tray_zone_rect().get_center().x
	elif side != 0:
		target = m.end.x if side == SIDE_RIGHT else m.position.x
	var dx: float = target - point.x
	if absf(dx) < dead_zone_px:
		return 0.0
	return signf(dx) * float(section("offer").get("pull_weight", 1.5))


func is_pulling() -> bool:
	if get_phase() != 3 or not is_fighting() or _off:
		return false
	var isak: Isak = find_isak()
	return isak == null or not isak.is_frozen()


# --- Pelea ---

func begin_intro() -> void:
	if _intro_state != 0:
		return
	var text: String = String(_texts.get("intro", ""))
	if text.is_empty():
		_intro_state = 2
		start()
		return
	_intro_state = 1
	say_line(text, true, _on_intro_finished, &"intro")


func start() -> void:
	_tokens = int(_tokens_cfg.get("start", 12))
	super.start()


## Fija las fichas (pruebas y bot).
func set_tokens(tokens: int) -> void:
	_tokens = maxi(tokens, 0)
	tokens_changed.emit(_tokens)


func _on_phase_started(phase_index: int) -> void:
	_clear_attacks()
	_apply_lap_settings()
	BossBase.apply_phase_nodes(_level_root(), phase_index)
	_rng.seed = 5029 + phase_index
	_phase_tokens = _tokens
	var p: Dictionary = phase_data(phase_index)
	_attack_index = 0
	_attack = ATTACK_GAP
	_gap_left = float(p.get("first_delay_s", 1.0))
	_sweep_count = 0
	_turn = TURN_NONE
	_turn_t = 0.0
	_behind_open = false
	_refund_left = 0.0
	_batch_wait = float(p.get("first_delay_s", 1.0))
	_batch_index = 0
	_trap_drop_left = 0.0
	_slot_passing = false
	_update_isak_side()
	if phase_index == 3:
		# La oferta: mira a Isak y ya no se gira («ocupada vendiendo»).
		if _isak_side != 0 and _isak_side != _facing:
			_set_facing(_isak_side)
		add_to_group(TemptationField.GROUP)
		_build_showcases()
		_reset_countdown()
	elif is_in_group(TemptationField.GROUP):
		remove_from_group(TemptationField.GROUP)
	_set_slot_open(phase_index == 3)
	_set_tray_open(false)
	_update_core()
	if phase_index > 1:
		var line: String = String((_texts.get("phase_lines", {}) as Dictionary).get(str(phase_index), ""))
		if not line.is_empty():
			say_line(line, false, Callable(), &"phase", true)
	_refresh()


func _on_phase_restarted(phase_index: int) -> void:
	for charger: Charger in _chargers():
		charger.make_ready()
	_tokens = _phase_tokens
	tokens_changed.emit(_tokens)
	_on_phase_started(phase_index)


func _on_advance(dt: float) -> void:
	var isak: Isak = find_isak()
	var frozen: bool = isak != null and isak.is_frozen()
	_update_isak_side()
	if not frozen:
		_advance_turn(dt)
		match get_phase():
			1:
				_advance_platforms(dt)
				_advance_attacks(dt)
			2:
				_advance_boxes(dt)
				_advance_attacks(dt)
			3:
				_advance_offer(dt)
				_advance_attacks(dt)
		if is_fighting():
			_check_hazards()
	_advance_tray(dt)
	_check_slot()
	_update_core()
	_refresh()


func _on_window_opened(_duration_s: float) -> void:
	attack_started.emit(ATTACK_WINDOW)


func _on_core_hit(_remaining_hits: int) -> void:
	if is_window_open():
		close_window()
	# Fases 1 y 2: el golpe lo hace girarse ya (un golpe por ventana).
	if can_turn() and is_isak_behind() and _turn != TURN_TURNING:
		_begin_turn_anim()


func _on_defeated() -> void:
	_clear_attacks()
	_attack = &""
	if is_in_group(TemptationField.GROUP):
		remove_from_group(TemptationField.GROUP)
	_core.set_enabled(false)
	_off = true
	_refresh()
	final_blow.emit()
	if defeat_sequence:
		_begin_defeat.call_deferred()


func _begin_defeat() -> void:
	if _defeat_seq != null or not is_inside_tree():
		return
	var root: Node = _level_root()
	var id: String = (root as GeneratedLevel).level_id if root is GeneratedLevel else ""
	if id.is_empty():
		id = String(GameState.current_level)
	_defeat_seq = BossDefeat.begin(self, root, id)


func get_defeat() -> BossDefeat:
	return _defeat_seq if _defeat_seq != null and is_instance_valid(_defeat_seq) else null


## Desarme en pixeles (BossDefeat): la maquina se suelta.
func play_disarm() -> PixelBurst:
	var cfg: Dictionary = section("defeat").get("pixels", {})
	_core.set_enabled(false)
	_set_machine_solid(false)
	var root: Node = _level_root()
	_burst = PixelBurst.spawn(_body_tex, get_machine_rect().get_center(), 1.0, root if root != null else self, cfg)
	disarmed.emit()
	return _burst


func get_pixel_burst() -> PixelBurst:
	return _burst if _burst != null and is_instance_valid(_burst) else null


# --- Giro (siempre te atiende de frente) ---

func _update_isak_side() -> void:
	var isak: Isak = find_isak()
	if isak == null or isak.is_dead():
		return
	var side: int = side_of_x(isak.global_position.x)
	if side != 0:
		_isak_side = side


## Puede girarse ahora: fases 1 y 2, sin procesar una devolucion.
func can_turn() -> bool:
	return is_fighting() and get_phase() < 3 and not is_refunding()


func _advance_turn(dt: float) -> void:
	var behind: bool = is_isak_behind()
	match _turn:
		TURN_NONE:
			if behind and can_turn():
				_turn = TURN_PENDING
				_turn_t = 0.0
				_open_behind_window(get_turn_s() + float(section("turn").get("anim_s", 0.25)))
			elif behind and not _behind_open and (get_phase() == 3 or is_refunding()):
				_open_behind_window(get_countdown_left() if get_phase() == 3 else _refund_left + get_turn_s())
			elif not behind and _behind_open:
				_close_behind_window()
		TURN_PENDING, TURN_WARN:
			if not behind:
				_turn = TURN_NONE
				_close_behind_window()
				return
			if not can_turn():
				_turn = TURN_NONE
				return
			_turn_t += dt
			var warn_s: float = frames_s(section("turn").get("warn_frames", 9))
			if _turn == TURN_PENDING and _turn_t >= get_turn_s() - warn_s - 0.0001:
				_turn = TURN_WARN
				turn_warned.emit()
			if _turn_t >= get_turn_s() - 0.0001:
				_begin_turn_anim()
		TURN_TURNING:
			_turn_t += dt
			if _turn_t >= float(section("turn").get("anim_s", 0.25)) - 0.0001:
				_turn = TURN_NONE
				_set_facing(-_facing)
				_close_behind_window()


func _begin_turn_anim() -> void:
	_turn = TURN_TURNING
	_turn_t = 0.0


func _set_facing(facing: int) -> void:
	_facing = SIDE_LEFT if facing < 0 else SIDE_RIGHT
	_place_core()
	turned.emit(_facing)


func _open_behind_window(duration_s: float) -> void:
	_behind_open = true
	open_window(maxf(duration_s, 0.05))


func _close_behind_window() -> void:
	_behind_open = false
	if is_window_open():
		close_window()


## Boton activo con Isak detras o marcado (la marca no cae al girarse).
func _update_core() -> void:
	if _core == null:
		return
	var want: bool = is_fighting() and (is_isak_behind() or _core.is_marked())
	if want != _core.is_enabled():
		_core.set_enabled(want)


func _place_core() -> void:
	if _core == null:
		return
	_core.global_position = get_core_point()
	var m: Rect2 = get_machine_rect()
	_core.set_shell_rect(Rect2(m.position - _core.global_position, m.size))


# --- Fase 1: plataformas con precio ---

func _build_platforms() -> void:
	for name: String in PLATFORM_NAMES:
		var body := _make_one_way_body("Platform_" + name, get_platform_rect(name))
		_set_body_solid(body, false)
		_platforms[name] = {"body": body, "active": false, "folded": false, "life": 0.0, "stood": 0.0}


## Paga la plataforma `name` (pulso a su etiqueta). Verdadero si aparece.
func pay_platform(platform: String) -> bool:
	if get_phase() != 1 or not is_fighting() or not _platforms.has(platform) or is_platform_active(platform):
		return false
	var cost: int = get_platform_cost()
	var credit: bool = _tokens < cost
	if credit:
		_give_credit()
	else:
		_tokens -= cost
		tokens_changed.emit(_tokens)
	var st: Dictionary = _platforms[platform]
	st["active"] = true
	st["folded"] = false
	st["stood"] = 0.0
	st["life"] = float(section("priced_platforms").get("life_s", 6.0))
	_set_body_solid(st["body"], true)
	platform_paid.emit(StringName(platform), credit)
	return true


func _advance_platforms(dt: float) -> void:
	var pp: Dictionary = section("priced_platforms")
	var isak: Isak = find_isak()
	_trap_drop_left = maxf(_trap_drop_left - dt, 0.0)
	for name: String in _platforms:
		var st: Dictionary = _platforms[name]
		if not bool(st["active"]):
			continue
		st["life"] = float(st["life"]) - dt
		if float(st["life"]) <= 0.0:
			st["active"] = false
			st["folded"] = false
			_set_body_solid(st["body"], false)
			continue
		if is_trap(name) and not bool(st["folded"]):
			if _isak_on_rect(isak, get_platform_rect(name)):
				st["stood"] = float(st["stood"]) + dt
				if float(st["stood"]) >= float(pp.get("fold_s", 0.3)) - 0.0001:
					fold_platform(name)
	if _trap_drop_left > 0.0 and isak != null and isak.is_on_floor() \
			and isak.global_position.y >= get_floor_y() - 2.0:
		_trap_drop_left = 0.0
		var dir: float = -float(_facing) if side_of_x(isak.global_position.x) == 0 else float(side_of_x(isak.global_position.x))
		if _hurt(isak, float(pp.get("trap_damage", 10.0)), dir):
			isak.velocity.x = dir * float(pp.get("trap_push_px_s", 360.0))


## Pliega la trampa `name` (deja caer a Isak a la bandeja).
func fold_platform(platform: String) -> void:
	if not is_platform_active(platform) or is_platform_folded(platform):
		return
	var st: Dictionary = _platforms[platform]
	st["folded"] = true
	_set_body_solid(st["body"], false)
	_trap_drop_left = float(section("priced_platforms").get("land_window_s", 1.5))
	platform_folded.emit(StringName(platform))


## «Te fio»: una Suscripcion de la arena que drena energia, enganchada ya.
func _give_credit() -> void:
	var isak: Isak = find_isak()
	_flash_sign(String((_texts.get("signs", {}) as Dictionary).get("credit", "Te fío")))
	if isak == null:
		return
	var sub := Subscription.spawn(_attacks, isak.global_position)
	if sub == null:
		return
	sub.energy_drain_per_s = float(_tokens_cfg.get("credit_drain_energy_per_s", 2.0))
	sub.attach_to(isak)
	sub.cancelled.connect(_on_credit_cancelled.bind(sub))
	_credit_subs.append(sub)


func _on_credit_cancelled(sub: Subscription) -> void:
	_credit_subs.erase(sub)
	if is_instance_valid(sub):
		sub.queue_free()


# --- Fase 2: cajas ---

func _advance_boxes(dt: float) -> void:
	var bx: Dictionary = section("boxes")
	if not is_refunding():
		_batch_wait -= dt
		if _batch_wait <= 0.0:
			_batch_wait = float(bx.get("interval_s", 5.0))
			launch_batch()
	for box: SurpriseBox in get_boxes():
		var id: int = box.get_instance_id()
		if not _box_info.has(id):
			continue
		var info: Dictionary = _box_info[id]
		if not box.is_closed():
			info["clear"] = float(info["clear"]) - dt
			if float(info["clear"]) <= 0.0:
				_remove_box(box)
			continue
		if box.content == SurpriseBox.CONTENT_BOMB and bool(info["landed"]) and box.get_state() == SurpriseBox.STATE_CLOSED:
			info["fuse"] = float(info["fuse"]) - dt
			if float(info["fuse"]) <= 0.0:
				box.open()
	if is_refunding():
		_refund_left = maxf(_refund_left - dt, 0.0)
		if _refund_left <= 0.0:
			refund_finished.emit()


## Lanza la siguiente tanda de cajas (boxes.batches, en orden). Devuelve las cajas.
func launch_batch() -> Array[SurpriseBox]:
	var bx: Dictionary = section("boxes")
	var batches: Array = bx.get("batches", [])
	var out: Array[SurpriseBox] = []
	if batches.is_empty():
		return out
	var batch: Array = batches[_batch_index % batches.size()]
	_batch_index += 1
	for entry: Variant in batch:
		var e: Array = entry
		var box := spawn_box(int(e[0]), int(e[1]), StringName(String(e[2])))
		if box != null:
			out.append(box)
	var max_boxes: int = int(bx.get("max_boxes", 6))
	var alive: Array[SurpriseBox] = get_boxes()
	while alive.size() > max_boxes:
		_remove_box(alive.pop_front())
	attack_started.emit(ATTACK_BOXES)
	return out


## Lanza una caja de `content` que cae en la columna `col` sobre la superficie de la
## fila `surface_row` (contenido tokens, energy, bomb o ticket).
func spawn_box(col: int, surface_row: int, content: StringName) -> SurpriseBox:
	var bx: Dictionary = section("boxes")
	var box := BOX_SCENE.instantiate() as SurpriseBox
	box.name = "VendorBox%d" % (_boxes.size() + _batch_index * 10)
	box.object_id = StringName(box.name)
	box.content = content
	if content == SurpriseBox.CONTENT_ENERGY:
		box.energy_amount = float(bx.get("energy", 20.0))
	_attacks.add_child(box)
	var to: Vector2 = _to_global(Vector2(float(col) * _tile, float(surface_row - 1) * _tile))
	var m: Rect2 = get_machine_rect()
	var lp: Array = (_arena.get("launch_px", {}) as Dictionary).get("left" if to.x < m.get_center().x else "right", [-64, -80])
	var from: Vector2 = m.position + Vector2(float(lp[0]), float(lp[1]))
	box.global_position = from
	box.launch(_launch_velocity(from, to))
	_boxes.append(box)
	_box_info[box.get_instance_id()] = {"landed": false, "fuse": float(bx.get("fuse_s", 2.5)), "clear": float(bx.get("clear_s", 0.6))}
	box.opened.connect(_on_box_opened.bind(box))
	box.state_changed.connect(_on_box_state.bind(box))
	return box


## Velocidad inicial para que la caja (gravedad y tope de caida de su seccion) vaya
## de `from` a `to` subiendo flight_up_px_s.
func _launch_velocity(from: Vector2, to: Vector2) -> Vector2:
	var cfg: Dictionary = World5ObjectsConfig.section("surprise_box")
	var g: float = float(cfg.get("gravity_px_s2", 2400.0))
	var cap: float = float(cfg.get("max_fall_px_s", 960.0))
	var vy: float = -float(section("boxes").get("flight_up_px_s", 720.0))
	var y: float = from.y
	var t: float = 0.0
	var step: float = 1.0 / 120.0
	while t < 5.0:
		vy = minf(vy + g * step, cap)
		y += vy * step
		t += step
		if vy > 0.0 and y >= to.y:
			break
	return Vector2((to.x - from.x) / maxf(t, 0.05), -float(section("boxes").get("flight_up_px_s", 720.0)))


func _on_box_state(previous: StringName, current: StringName, box: SurpriseBox) -> void:
	if previous == SurpriseBox.STATE_FLYING and current == SurpriseBox.STATE_CLOSED and _box_info.has(box.get_instance_id()):
		(_box_info[box.get_instance_id()] as Dictionary)["landed"] = true


func _on_box_opened(content: StringName, box: SurpriseBox) -> void:
	match content:
		SurpriseBox.CONTENT_TOKENS:
			_tokens += int(_tokens_cfg.get("good_box_bonus", 2))
			tokens_changed.emit(_tokens)
		SurpriseBox.CONTENT_BOMB:
			_explode(box.get_body_rect().get_center())
		SurpriseBox.CONTENT_TICKET:
			start_refund()


func _explode(at: Vector2) -> void:
	var bx: Dictionary = section("boxes")
	bomb_exploded.emit(at)
	var isak: Isak = find_isak()
	if isak == null or isak.is_dead() or isak.is_frozen():
		return
	var body: Rect2 = LevelLookup.isak_body_rect(isak)
	var radius: float = float(bx.get("blast_tiles", 1.5)) * _tile
	var nearest := Vector2(clampf(at.x, body.position.x, body.end.x), clampf(at.y, body.position.y, body.end.y))
	if nearest.distance_to(at) <= radius:
		_hurt(isak, float(bx.get("blast_damage", 10.0)), signf(body.get_center().x - at.x))


## «Procesando devolución…»: refund_s sin girarse y con la bandeja abierta.
func start_refund() -> void:
	if get_phase() != 2 or not is_fighting():
		return
	_refund_left = float(section("boxes").get("refund_s", 4.0))
	_turn = TURN_NONE
	_set_tray_open(true)
	_flash_sign(String((_texts.get("signs", {}) as Dictionary).get("refund", "Procesando devolución…")), _refund_left)
	refund_started.emit()


func _remove_box(box: SurpriseBox) -> void:
	if box == null:
		return
	_boxes.erase(box)
	_box_info.erase(box.get_instance_id())
	if is_instance_valid(box):
		box.queue_free()


## La bandeja se cierra al acabar la devolucion, salvo con Isak dentro.
func _advance_tray(_dt: float) -> void:
	if not is_tray_open() or is_refunding():
		return
	var isak: Isak = find_isak()
	if isak != null and LevelLookup.isak_body_rect(isak).intersects(get_tray_tunnel_rect()):
		return
	_set_tray_open(false)


# --- Fase 3: oferta, escaparate, vitrinas y ranura ---

func _advance_offer(dt: float) -> void:
	_countdown_left = maxf(_countdown_left - dt, 0.0)
	var left: int = ceili(_countdown_left - 0.0001)
	if left != _last_tick:
		_last_tick = left
		countdown_ticked.emit(left)
	var isak: Isak = find_isak()
	if isak != null and not isak.is_dead() and LevelLookup.isak_body_rect(isak).intersects(get_tray_zone_rect()):
		process_payment(true)
	elif _countdown_left <= 0.0:
		process_payment(false)


## «Procesando pago…»: congela a Isak pay_freeze_s (golpe al liberarse, hacia fuera)
## y la cuenta vuelve a empezar con el escaparate repuesto.
func process_payment(by_tray: bool) -> void:
	if get_phase() != 3 or not is_fighting():
		return
	var signs: Dictionary = _texts.get("signs", {})
	var isak: Isak = find_isak()
	if isak != null and not isak.is_dead():
		var dir: float = signf(isak.global_position.x - get_machine_rect().get_center().x)
		isak.freeze(float(section("offer").get("pay_freeze_s", 2.0)), FREEZE_SOURCE_PAY, dir if dir != 0.0 else -float(_facing))
	_flash_sign(String(signs.get("bought" if by_tray else "pay", "Procesando pago…")), 2.0)
	_reset_countdown()
	payment_processed.emit(by_tray)


func _reset_countdown() -> void:
	_countdown_left = get_countdown_s()
	_last_tick = -1
	_place_shutter()


## Escaparate: persiana de pared en el techo de la maquina, pegada a la espalda (nueva en cada cuenta).
func _place_shutter() -> void:
	if _shutter != null and is_instance_valid(_shutter):
		_shutter.queue_free()
	var sc: Dictionary = _arena.get("showcase", {})
	var length: int = int(sc.get("length_tiles", 3))
	var m: Rect2 = get_machine_rect()
	var x: float = m.end.x - _tile if _facing == SIDE_LEFT else m.position.x
	_shutter = SHUTTER_SCENE.instantiate() as Shutter
	_shutter.name = "Showcase"
	_shutter.object_id = &"vendor_showcase"
	_shutter.orientation = Shutter.ORIENT_WALL
	_shutter.length_tiles = length
	_attacks.add_child(_shutter)
	_shutter.global_position = Vector2(x, m.position.y - float(length) * _tile)


func _build_showcases() -> void:
	for body: StaticBody2D in _showcases:
		if is_instance_valid(body):
			body.queue_free()
	_showcases.clear()
	for name: Variant in (_arena.get("showcase", {}) as Dictionary).get("showcases", ["b", "c"]):
		_showcases.append(_make_one_way_body("Showcase_" + String(name), get_platform_rect(String(name))))


## Ranura (fase 3): Isak dentro sin el Filo sale empujado a su lado de entrada; el
## que entro con el Filo sigue hacia la salida (un Filo exacto la cruza).
func _check_slot() -> void:
	if not is_slot_open():
		return
	var isak: Isak = find_isak()
	if isak == null or isak.is_dead() or isak.is_warping():
		return
	var slot: Rect2 = get_slot_rect()
	var body: Rect2 = LevelLookup.isak_body_rect(isak)
	var in_slot: bool = body.intersects(slot)
	if not in_slot:
		_slot_passing = false
		var side: int = side_of_x(body.get_center().x)
		if side != 0:
			_slot_entry = side
		return
	if isak.get_state_name() == PlayerState.COMBO_EDGE:
		if not _slot_passing:
			_slot_passing = true
		return
	var dir: float = float(_slot_entry)
	if _slot_passing:
		# Entro con el Filo: sale por el otro lado.
		dir = -float(_slot_entry)
	push_out_of_slot(isak, dir)


func push_out_of_slot(isak: Isak, dir: float) -> void:
	var slot: Rect2 = get_slot_rect()
	var half: float = isak.get_hitbox_size().x * 0.5
	var state: StringName = isak.get_state_name()
	if state == PlayerState.DASH or state in Isak.COMBO_STATES:
		isak.change_state(PlayerState.FALL)
	isak.global_position.x = slot.position.x - half - 1.0 if dir < 0.0 else slot.end.x + half + 1.0
	isak.velocity = Vector2(dir * float(_arena.get("slot_push_px_s", 240.0)), maxf(isak.velocity.y, 0.0))
	_slot_passing = false
	slot_pushed.emit(dir)


# --- Ataques comunes: brazo que barre y monedas ---

func _advance_attacks(dt: float) -> void:
	if _attack == ATTACK_GAP:
		_gap_left -= dt
		if _gap_left <= 0.0:
			_next_attack()
		return
	_attack_t += dt
	match _attack:
		ATTACK_ARM_SWEEP:
			var a: Dictionary = section("arm_sweep")
			if _attack_t >= frames_s(a.get("warn_frames", 9)) + float(a.get("sweep_s", 0.6)) - 0.0001:
				_sweep_side = -_sweep_side
				_end_attack()
		ATTACK_COINS:
			var c: Dictionary = section("coins")
			if _attack_t >= frames_s(c.get("warn_frames", 9)) + float(c.get("fall_s", 0.5)) - 0.0001:
				_end_attack()
		_:
			_end_attack()


func _next_attack() -> void:
	var order: Array = phase_data(get_phase()).get("attacks", [])
	if order.is_empty():
		_end_attack()
		return
	var kind := StringName(String(order[_attack_index % order.size()]))
	_attack_index += 1
	start_attack(kind)


## Empieza el ataque `kind` ya (pruebas y bot).
func start_attack(kind: StringName) -> void:
	_attack = kind
	_attack_t = 0.0
	var isak: Isak = find_isak()
	match kind:
		ATTACK_ARM_SWEEP:
			_sweep_hit = false
			if _sweep_count == 0 and isak != null:
				var s: int = side_of_x(isak.global_position.x)
				_sweep_side = s if s != 0 else SIDE_LEFT
			_sweep_count += 1
		ATTACK_COINS:
			var c: Dictionary = section("coins")
			var spread: int = maxi(int(c.get("spread_cols", 3)), 1)
			var col: int = _col_of(isak.global_position.x) if isak != null else 3
			var m: Array = _arena.get("machine", [8, 5, 4, 5])
			_coin_cols.clear()
			_coin_hit.clear()
			for cand: int in [col, col - spread, col + spread, col - 2 * spread, col + 2 * spread]:
				var cc: int = clampi(cand, 1, ARENA_COLS - 2)
				if cc >= int(m[0]) and cc < int(m[0]) + int(m[2]):
					continue
				if not _coin_cols.has(cc) and _coin_cols.size() < int(c.get("count", 3)):
					_coin_cols.append(cc)
					_coin_hit.append(false)
	attack_started.emit(kind)


func _end_attack() -> void:
	_attack = ATTACK_GAP
	_attack_t = 0.0
	_gap_left = float(phase_data(get_phase()).get("attack_gap_s", 2.0))
	_coin_cols.clear()
	_coin_hit.clear()


func _check_hazards() -> void:
	var isak: Isak = find_isak()
	if isak == null or isak.is_dead() or isak.is_frozen():
		return
	var body: Rect2 = LevelLookup.isak_body_rect(isak)
	if is_sweeping() and not _sweep_hit and get_sweep_rect().intersects(body):
		if _hurt(isak, float(section("arm_sweep").get("damage", 10.0)), -float(_sweep_side)):
			_sweep_hit = true
	if is_coin_falling():
		var dmg: float = float(section("coins").get("damage", 10.0))
		for i: int in _coin_cols.size():
			var r: Rect2 = get_coin_rect(_coin_cols[i])
			if not _coin_hit[i] and r.intersects(body):
				if _hurt(isak, dmg, signf(body.get_center().x - r.get_center().x)):
					_coin_hit[i] = true


func _hurt(isak: Isak, damage: float, direction: float) -> bool:
	if not isak.take_hit(direction):
		return false
	GameState.apply_sync_damage(damage)
	return true


# --- Pulso ---

func _on_pulse_fired(area: Area2D) -> void:
	receive_pulse(area)


## Pulso de Isak: en la fase 1 paga la etiqueta que alcanza. Verdadero si pago algo.
func receive_pulse(area: Area2D) -> bool:
	if not is_fighting() or area == null or get_phase() != 1:
		return false
	for name: String in PLATFORM_NAMES:
		if not is_platform_active(name) and PulseReceiver.pulse_reaches(area, get_label_rect(name)):
			return pay_platform(name)
	return false


# --- Limpieza ---

func _clear_attacks() -> void:
	for name: String in _platforms:
		var st: Dictionary = _platforms[name]
		st["active"] = false
		st["folded"] = false
		_set_body_solid(st["body"], false)
	for sub: Subscription in _credit_subs:
		if is_instance_valid(sub):
			sub.queue_free()
	_credit_subs.clear()
	for box: SurpriseBox in _boxes:
		if is_instance_valid(box):
			box.queue_free()
	_boxes.clear()
	_box_info.clear()
	for body: StaticBody2D in _showcases:
		if is_instance_valid(body):
			body.queue_free()
	_showcases.clear()
	if _shutter != null and is_instance_valid(_shutter):
		_shutter.queue_free()
	_shutter = null
	_coin_cols.clear()
	_coin_hit.clear()
	_attack = &""
	_attack_t = 0.0
	_refund_left = 0.0
	_countdown_left = 0.0
	_trap_drop_left = 0.0


# --- Construccion ---

func _build() -> void:
	_body_tex = _make_body_texture()
	_machine = StaticBody2D.new()
	_machine.name = "Machine"
	_machine.top_level = true
	_machine.collision_layer = 1
	_machine.collision_mask = 0
	add_child(_machine)
	var m: Rect2 = get_machine_rect()
	_machine.global_position = m.position
	var slot_y: float = get_slot_rect().position.y - m.position.y
	var tray_y: float = get_tray_tunnel_rect().position.y - m.position.y
	_add_machine_shape("Top", Rect2(0.0, 0.0, m.size.x, slot_y))
	_slot_shape = _add_machine_shape("Slot", Rect2(0.0, slot_y, m.size.x, _tile))
	_add_machine_shape("Middle", Rect2(0.0, slot_y + _tile, m.size.x, tray_y - slot_y - _tile))
	_tray_shape = _add_machine_shape("Tray", Rect2(0.0, tray_y, m.size.x, m.size.y - tray_y))
	_core = WEAK_POINT_SCENE.instantiate() as WeakPoint
	_core.name = "CancelButton"
	_core.top_level = true
	add_child(_core)
	set_weak_point(_core)
	_place_core()
	_core.set_enabled(false)
	_attacks = Node2D.new()
	_attacks.name = "Attacks"
	_attacks.top_level = true
	add_child(_attacks)
	_build_platforms()
	_fx = VendorFx.new()
	_fx.name = "VendorFx"
	_fx.top_level = true
	_fx.z_index = 40
	_fx.boss = self
	add_child(_fx)
	_refresh()


func _add_machine_shape(node_name: String, rect: Rect2) -> CollisionShape2D:
	var shape := CollisionShape2D.new()
	shape.name = node_name
	var box := RectangleShape2D.new()
	box.size = rect.size
	shape.shape = box
	shape.position = rect.get_center()
	_machine.add_child(shape)
	return shape


func _make_one_way_body(node_name: String, rect: Rect2) -> StaticBody2D:
	var body := StaticBody2D.new()
	body.name = node_name
	body.top_level = true
	body.collision_layer = 1
	body.collision_mask = 0
	var shape := CollisionShape2D.new()
	shape.name = "Shape"
	var box := RectangleShape2D.new()
	box.size = rect.size
	shape.shape = box
	shape.position = rect.size * 0.5
	shape.one_way_collision = true
	body.add_child(shape)
	add_child(body)
	body.global_position = rect.position
	return body


func _set_body_solid(body: StaticBody2D, solid: bool) -> void:
	if body == null or not is_instance_valid(body):
		return
	body.collision_layer = 1 if solid else 0
	for child: Node in body.get_children():
		if child is CollisionShape2D:
			(child as CollisionShape2D).disabled = not solid


func _set_slot_open(open: bool) -> void:
	if _slot_shape != null:
		_slot_shape.disabled = open


func _set_tray_open(open: bool) -> void:
	if _tray_shape != null:
		_tray_shape.disabled = open


func _set_machine_solid(solid: bool) -> void:
	if _machine != null:
		_machine.collision_layer = 1 if solid else 0


## Isak de pie sobre el rectangulo `rect` (tabla de una via).
func _isak_on_rect(isak: Isak, rect: Rect2) -> bool:
	if isak == null or isak.is_dead() or not isak.is_on_floor():
		return false
	var feet: Vector2 = isak.global_position
	return absf(feet.y - rect.position.y) <= 6.0 and feet.x >= rect.position.x - 8.0 and feet.x <= rect.end.x + 8.0


func _flash_sign(text: String, seconds: float = 1.5) -> void:
	_sign = text
	_sign_left = seconds


func _make_body_texture() -> Texture2D:
	var rect: Rect2 = get_machine_rect()
	var w: int = maxi(int(rect.size.x), 8)
	var h: int = maxi(int(rect.size.y), 8)
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	img.fill(_color("body_color", Color.DIM_GRAY))
	var trim: Color = _color("trim_color", Color.WHEAT)
	img.fill_rect(Rect2i(0, 0, w, 8), trim)
	img.fill_rect(Rect2i(0, h - 8, w, 8), trim)
	img.fill_rect(Rect2i(16, 24, w - 32, h / 2 - 24), _color("ink_color", Color.BLACK))
	return ImageTexture.create_from_image(img)


func _refresh() -> void:
	if _fx != null:
		_fx.queue_redraw()


func _poll_arrival() -> void:
	var isak: Isak = find_isak()
	if isak == null or isak.is_warping() or isak.is_dead():
		return
	begin_intro()


func _on_intro_finished() -> void:
	_intro_state = 2
	start()


func _lap_entry() -> Dictionary:
	var lap: int = lap_override if lap_override > 0 else GameState.lap
	var laps: Dictionary = get_config().get("laps", {})
	return laps.get(str(lap), laps.get("1", {}))


func _apply_lap_settings() -> void:
	apply_charger_cooldown(float(lap_value("charger_cooldown_s", -1.0)))


func _load_tokens_cfg() -> Dictionary:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(ECONOMY_PATH))
	if parsed is Dictionary:
		return (parsed as Dictionary).get("boss_tokens", {})
	return {}


func _col_of(x: float) -> int:
	return int(floor(_from_global(Vector2(x, 0.0)).x / _tile))


func _color(key: String, fallback: Color) -> Color:
	var value: String = String(_arena.get(key, ""))
	if value.is_empty():
		return fallback
	if value.begins_with("#"):
		return Color.html(value)
	return World5ObjectsConfig.color(value, fallback)


func _to_global(p: Vector2) -> Vector2:
	var parent := get_parent() as Node2D
	return parent.to_global(p) if parent != null else p


func _from_global(p: Vector2) -> Vector2:
	var parent := get_parent() as Node2D
	return parent.to_local(p) if parent != null else p


func _cells_rect(cells: Variant) -> Rect2:
	var c: Array = cells
	var pos: Vector2 = _to_global(Vector2(float(c[0]) * _tile, float(c[1]) * _tile))
	return Rect2(pos, Vector2(float(c[2]) * _tile, float(c[3]) * _tile))


## Dibujo PROVISIONAL por codigo: maquina con su cara de delante (sonrisa de neon,
## brazos, bandeja), plataformas con su etiqueta y precio (con el Debug, el icono de
## la trampa), brazo que barre, monedas, cuenta y carteles. Rojo = lo que dana.
class VendorFx extends Node2D:
	var boss: Vendor

	func _draw() -> void:
		if boss == null:
			return
		var font: Font = ThemeDB.fallback_font
		var m: Rect2 = boss.get_machine_rect()
		var body := boss._color("body_color", Color.DIM_GRAY)
		var trim := boss._color("trim_color", Color.WHEAT)
		var neon := boss._color("neon_color", Color.MAGENTA)
		var price := boss._color("price_color", Color.YELLOW)
		var ink := boss._color("ink_color", Color.BLACK)
		var warn := boss._color("warn_color", Color.RED)
		var trap := boss._color("trap_color", Color.WHITE)
		if boss.get_pixel_burst() != null:
			return
		draw_rect(m, body)
		draw_rect(m, trim, false, 4.0)
		var f: int = boss.get_facing()
		# Cara de delante: vitrina, sonrisa de neon y bandeja.
		var front_x: float = m.position.x if f < 0 else m.end.x
		var glass := Rect2(m.position + Vector2(16.0, 24.0), Vector2(m.size.x - 32.0, 96.0))
		draw_rect(glass, ink)
		var off: bool = boss.is_screen_off()
		var blink: bool = boss.get_turn_stage() == Vendor.TURN_WARN and fmod(boss.get_time() * 8.0, 1.0) < 0.5
		if not off and not blink:
			var c := Vector2(m.get_center().x + float(f) * 24.0, m.position.y - 24.0)
			draw_arc(c, 36.0, 0.3, PI - 0.3, 16, neon, 6.0)
			draw_circle(c + Vector2(-18.0, -22.0), 5.0, neon)
			draw_circle(c + Vector2(18.0, -22.0), 5.0, neon)
		# Brazos (no solidos): fuera por la cara de delante; recogidos en el aviso.
		var reach: float = 0.0 if boss.get_turn_stage() in [Vendor.TURN_WARN, Vendor.TURN_TURNING] else 48.0
		draw_line(Vector2(front_x, m.position.y + 160.0), Vector2(front_x + float(f) * reach, m.position.y + 176.0), trim, 6.0)
		var tray: Rect2 = boss.get_tray_zone_rect()
		draw_rect(Rect2(tray.position + Vector2(0.0, tray.size.y - 12.0), Vector2(tray.size.x, 12.0)), trim)
		if boss.is_slot_open():
			draw_rect(boss.get_slot_rect(), Color(ink, 0.9))
		if boss.is_tray_open():
			draw_rect(boss.get_tray_tunnel_rect(), Color(ink, 0.9))
		# Fichas (hasta la barra «ticket» del paso 18).
		if boss.is_fighting():
			draw_string(font, Vector2(m.position.x, m.position.y - 72.0), "Fichas: %d" % boss.get_tokens(),
				HORIZONTAL_ALIGNMENT_CENTER, m.size.x, 16, price)
		var sign: String = boss.get_sign()
		if boss.get_phase() == 3 and boss.is_fighting():
			var signs: Dictionary = boss._texts.get("signs", {})
			sign = "%s %d" % [String(signs.get("offer", "¡SOLO POR HOY!")), ceili(boss.get_countdown_left() - 0.0001)] \
				if sign.is_empty() else sign
		if not sign.is_empty():
			draw_string(font, Vector2(m.position.x - 64.0, m.position.y + 150.0), sign, HORIZONTAL_ALIGNMENT_CENTER,
				m.size.x + 128.0, 16, trim)
		# Plataformas con precio (fase 1).
		if boss.get_phase() == 1 and boss.is_fighting():
			for name: String in Vendor.PLATFORM_NAMES:
				var lr: Rect2 = boss.get_label_rect(name)
				var pr: Rect2 = boss.get_platform_rect(name)
				if boss.is_platform_solid(name):
					draw_rect(pr, trim)
				elif boss.is_platform_folded(name):
					draw_line(pr.position, pr.position + Vector2(8.0, 24.0), trim, 3.0)
				if boss.is_platform_active(name):
					continue
				draw_rect(lr, price)
				draw_rect(lr, ink, false, 2.0)
				draw_string(font, lr.position + Vector2(0.0, lr.size.y - 8.0), str(boss.get_platform_cost()),
					HORIZONTAL_ALIGNMENT_CENTER, lr.size.x, 16, ink)
				if boss.is_trap(name) and DebugMode.is_revealing():
					var ic := lr.end + Vector2(-6.0, -lr.size.y - 6.0)
					draw_circle(ic, 8.0, ink)
					draw_circle(ic, 7.0, trap)
					draw_line(ic + Vector2(-4.0, -4.0), ic + Vector2(4.0, 4.0), ink, 2.0)
		# Brazo que barre: sombra en el aviso, rojo al barrer.
		var sr: Rect2 = boss.get_sweep_rect()
		if sr.has_area():
			if boss.is_sweeping():
				draw_rect(sr, Color(warn, 0.35))
				draw_rect(sr, warn, false, 3.0)
			else:
				draw_rect(Rect2(sr.position.x, sr.end.y - 8.0, sr.size.x, 8.0), Color(0, 0, 0, 0.45))
		for col: int in boss.get_coin_columns():
			var cr: Rect2 = boss.get_coin_rect(col)
			if boss.is_coin_falling():
				draw_circle(cr.get_center(), cr.size.x * 0.5, price)
				draw_arc(cr.get_center(), cr.size.x * 0.5, 0.0, TAU, 16, warn, 3.0)
			else:
				draw_rect(Rect2(cr.position.x, boss.get_floor_y() - 8.0, cr.size.x, 8.0), Color(0, 0, 0, 0.45))
		for box: SurpriseBox in boss.get_boxes():
			var fuse: float = boss.get_fuse_left(box)
			if fuse >= 0.0 and box.is_closed() and fmod(boss.get_time() * 10.0, 1.0) < 0.5:
				var top: Vector2 = box.get_body_rect().position + Vector2(box.get_body_rect().size.x * 0.5, -6.0)
				draw_circle(top, 4.0, warn)
		if off and boss._body_tex != null:
			draw_line(m.position + Vector2(16, 16), m.end - Vector2(16, 16), warn, 8.0)
