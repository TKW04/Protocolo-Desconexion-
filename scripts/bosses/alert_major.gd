## Alerta Mayor, jefe del Mundo 1 (docs/propuesta-jefe-alerta-mayor.md; pasos
## 5-8 de §6, 2026-10-21). Un BossBase con tres fases; datos en
## data/bosses/alert_major.json (arena, phase1-3, laps, texts).
##
## - Llegada: con intro_on_arrival, cuando Isak termina de llegar por el vortice
##   sale la linea de intro (importante: pausa; texto PROPUESTO) y al cerrarla
##   empieza la fase 1 (start()).
## - Cuerpo: flota inflado (4 x 4 tiles) y baja desinflado (2 x 2) a los sitios
##   de la arena (arena.spots, celdas del nivel); el contador («99+», «66»...)
##   va encima con la fuente de textos. No es solido ni hace dano al tocarlo:
##   dañan sus ataques. El nucleo (WeakPoint, con el cuerpo desinflado como
##   cuerpo para la chispa gris) solo esta activo en las ventanas.
## - Fases: la vida es la de BossBase (3/3/3 en Caché). Al empezar cada fase se
##   activan los objetos del nivel con active_in_phase de esa fase (fase 3:
##   metronomo, plataformas que parpadean y campanas, con el compas y el
##   parpadeo de la vuelta: laps.<n>.phase3) y suena su linea (sin pausa).
## - Reaparicion por fase (BossBase.restart_phase): se borran sus ataques, los
##   cargadores vuelven a estar listos y la fase empieza de nuevo.
## - Golpe final: se borran los ataques, se paran el metronomo y las campanas,
##   las plataformas que parpadean quedan encendidas y se emite final_blow (la
##   congelacion, el desarme y la recompensa son del paso 10).
## Todo en tiempo del mundo (advance). Arte PROVISIONAL (_placeholder) de
## tools/gen_boss_alert_major.py. Ataques de cada fase: _phase1_* (paso 6),
## _phase2_* (paso 7) y _phase3_* (paso 8).
class_name AlertMajor
extends BossBase

## Empieza un ataque (para el audio y el bot): spit, sweep, popup, burst,
## shield, split, launch.
signal attack_started(attack: StringName)
## El cuerpo cambia de movimiento (hover, descend, down, ascend...).
signal move_changed(move: StringName)
## Golpe final (contador a 0): gancho del paso 10 (congelacion, desarme y
## recompensa con BossReward).
signal final_blow

const WEAK_POINT_SCENE: PackedScene = preload("res://scenes/bosses/weak_point.tscn")
const BUBBLE_SCENE: PackedScene = preload("res://scenes/enemies/alert_bubble.tscn")
const BANNER_SCENE: PackedScene = preload("res://scenes/enemies/spam_banner.tscn")
const POPUP_SCENE: PackedScene = preload("res://scenes/levels/overlay_popup.tscn")

const MOVE_HOVER: StringName = &"hover"
const MOVE_DESCEND: StringName = &"descend"
const MOVE_DOWN: StringName = &"down"
const MOVE_ASCEND: StringName = &"ascend"
const MOVE_GONE: StringName = &"gone"

const ART_REST: String = "alert_major_rest_placeholder.png"
const ART_INFLATE: String = "alert_major_inflate_placeholder.png"
const ART_DOWN: String = "alert_major_down_placeholder.png"
const ART_SHIELD: String = "alert_major_shield_placeholder.png"

## Id del objeto en el nivel (params.id).
@export var object_id: StringName = &""
## Con Isak llegando por el vortice, espera a que termine y dice la intro.
@export var intro_on_arrival: bool = true

var _arena: Dictionary = {}
var _texts: Dictionary = {}
var _lap: Dictionary = {}
var _tile: float = 64.0
var _move: StringName = MOVE_HOVER
var _move_time: float = 0.0
var _move_from: Vector2 = Vector2.ZERO
var _move_to: Vector2 = Vector2.ZERO
## Centro del cuerpo (global).
var _center: Vector2 = Vector2.ZERO
var _down: bool = false
var _inflated: bool = false
var _hover_dir: float = 1.0
var _body: Sprite2D
var _label: Label
var _core: WeakPoint
## Contenedor de los ataques (top_level: coordenadas globales).
var _attacks: Node2D
var _intro_state: int = 0
var _textures: Dictionary = {}
## Avisos dibujados (flechas, lineas, contornos): {kind, id?, ...} en globales.
var _warnings: Array[Dictionary] = []
var _warn_layer: WarnLayer
# Fase 1.
var _bubbles: Array[AlertBubble] = []
var _banners: Dictionary = {}
var _round_spit_done: bool = false
var _spit_left: float = 0.0
var _spit_cooldown: float = 0.0
var _spit_targets: Array[StringName] = []
var _sweep_t: float = 0.0
var _sweep_index: int = 0
## Ronda de la fase 1 (cada bajada empieza otra): una Burbuja cuenta como
## neutralizada si se aturdio en esta ronda (meta stun_round) o esta derrotada.
var _round_id: int = 0
# Fase 2.
var _rng := RandomNumberGenerator.new()
## Pop-ups de la lluvia: {quarter, t, node} (node null mientras avisa).
var _popups: Array[Dictionary] = []
var _popup_t: float = 0.0
var _popup_button_lane: int = 0
var _burst_state: StringName = &""
var _burst_t: float = 0.0
var _burst_t_next: float = 0.0
var _burst_fired: int = 0
var _burst_dir: int = 1
var _burst_lane: String = "floor"
var _window_t: float = 0.0
var _perch_t: float = 0.0
var _perch_spot: StringName = &""
var _shield: OverlayPopup


func _ready() -> void:
	if boss_id.is_empty():
		boss_id = &"alert_major"
	super._ready()
	var cfg: Dictionary = get_config()
	_arena = cfg.get("arena", {})
	_texts = cfg.get("texts", {})
	_tile = float(World1ObjectsConfig.tile_size())
	_lap = _lap_entry()
	_build()
	_center = get_hover_center(clampf(position.x / _tile + 2.0, _hover_x_min(), _hover_x_max()))
	_set_move(MOVE_HOVER)
	_apply_lap_settings.call_deferred()


func _physics_process(delta: float) -> void:
	if _intro_state == 0 and intro_on_arrival and not is_fighting() and not is_defeated():
		_poll_arrival()
	super._physics_process(delta)


# --- Consultas (HUD, bot y pruebas) ---

func get_move() -> StringName:
	return _move


func get_attack_state() -> StringName:
	return _move


func get_body_center() -> Vector2:
	return _center


func is_down() -> bool:
	return _down


func get_core() -> WeakPoint:
	return _core


func get_counter_text() -> String:
	return _label.text


func get_attacks_root() -> Node2D:
	return _attacks


## Centro global de un sitio de la arena (arena.spots) con el cuerpo desinflado.
func get_spot_center(spot: StringName) -> Vector2:
	var s: Array = (_arena.get("spots", {}) as Dictionary).get(String(spot), [12.0, 10])
	var half: float = _down_size().y * 0.5
	return _to_global(Vector2(float(s[0]) * _tile, float(s[1]) * _tile - half))


## Centro global del cuerpo flotando en la columna (tiles) `x_tiles`.
func get_hover_center(x_tiles: float) -> Vector2:
	var hover: Dictionary = _arena.get("hover", {})
	return _to_global(Vector2(x_tiles * _tile, float(hover.get("y_tiles", 3.0)) * _tile))


## Valor de la vuelta actual (laps.<n>.<section>.<key> o laps.<n>.<key>).
func lap_value(key: String, fallback: Variant, section: String = "") -> Variant:
	var src: Dictionary = _lap
	if section != "":
		src = _lap.get(section, {})
	return src.get(key, fallback)


## Datos de una fase (phase1, phase2, phase3).
func phase_data(phase_index: int) -> Dictionary:
	return get_config().get("phase%d" % phase_index, {})


## Aviso de `frames` cuadros a anim_fps (s del mundo).
func frames_s(frames: Variant) -> float:
	return float(frames) / maxf(float(_arena.get("anim_fps", 12.0)), 1.0)


## Isak del nivel (o null).
func find_isak() -> Isak:
	return LevelLookup.find_isak(self)


# --- Pelea ---

## Empieza la intro ya (sin esperar a la llegada).
func begin_intro() -> void:
	if _intro_state != 0:
		return
	var text: String = String(_texts.get("intro", ""))
	if text.is_empty():
		_intro_state = 2
		start()
		return
	_intro_state = 1
	_inflate(true)
	EventBus.eco_line_finished.connect(_on_intro_finished, CONNECT_ONE_SHOT)
	EventBus.eco_line_requested.emit(text, -1.0, true)


func _on_phase_started(phase_index: int) -> void:
	_clear_attacks()
	_apply_lap_settings()
	BossBase.apply_phase_nodes(_level_root(), phase_index)
	_down = false
	_set_core_enabled(false)
	_set_move(MOVE_HOVER)
	match phase_index:
		1:
			_phase1_start()
		2:
			_phase2_start()
	if phase_index > 1:
		var line: String = String((_texts.get("phase_lines", {}) as Dictionary).get(str(phase_index), ""))
		if not line.is_empty():
			EventBus.eco_line_requested.emit(line, -1.0, false)
	_update_label()


func _on_phase_restarted(phase_index: int) -> void:
	for charger: Charger in _chargers():
		charger.make_ready()
	_on_phase_started(phase_index)


func _on_advance(dt: float) -> void:
	_advance_move(dt)
	if not is_fighting():
		return
	match get_phase():
		1:
			_phase1_advance(dt)
		2:
			_phase2_advance(dt)
	if not _warnings.is_empty():
		_warn_layer.queue_redraw()


func _on_window_closed() -> void:
	match get_phase():
		1:
			_phase1_window_closed()
		2:
			_phase2_window_closed()


func _on_core_hit(_remaining_hits: int) -> void:
	_update_label()


func _on_defeated() -> void:
	_clear_attacks()
	for node: Node in BossBase.phase_nodes(_level_root()):
		if node is BlinkPlatform:
			(node as BlinkPlatform).hold_on()
		else:
			BossBase.set_phase_node_active(node, false)
	_set_core_enabled(false)
	_update_label()
	final_blow.emit()


# --- Movimiento del cuerpo ---

## Empieza a moverse del centro actual a `to` (global) en move_s; down: llega
## desinflado.
func move_body_to(to: Vector2, down: bool) -> void:
	_move_from = _center
	_move_to = to
	_set_move(MOVE_DESCEND if down else MOVE_ASCEND)


func _advance_move(dt: float) -> void:
	_move_time += dt
	match _move:
		MOVE_HOVER:
			var speed: float = float((_arena.get("hover", {}) as Dictionary).get("speed_tiles_s", 1.5)) * _tile
			var x: float = _from_global(_center).x + _hover_dir * speed * dt
			var lo: float = _hover_x_min() * _tile
			var hi: float = _hover_x_max() * _tile
			if x >= hi:
				x = hi
				_hover_dir = -1.0
			elif x <= lo:
				x = lo
				_hover_dir = 1.0
			_center = _to_global(Vector2(x, _from_global(get_hover_center(0.0)).y))
		MOVE_DESCEND, MOVE_ASCEND:
			var f: float = clampf(_move_time / maxf(_move_s(), 0.001), 0.0, 1.0)
			_center = _move_from.lerp(_move_to, f)
			if f >= 1.0:
				_on_move_finished(_move)
	_place()


## Termina una bajada (queda abajo) o una subida (vuelve a flotar). Los jefes
## de cada fase reaccionan en _on_arrived.
func _on_move_finished(move: StringName) -> void:
	if move == MOVE_DESCEND:
		_set_move(MOVE_DOWN)
	else:
		_set_move(MOVE_HOVER)
	_on_arrived(move)


## Ha terminado de bajar (MOVE_DESCEND) o subir: lo que toque en cada fase.
func _on_arrived(move_done: StringName) -> void:
	if not is_fighting():
		return
	match get_phase():
		1:
			_phase1_arrived(move_done)
		2:
			_phase2_arrived(move_done)


func _set_move(move: StringName) -> void:
	_move = move
	_move_time = 0.0
	_down = move == MOVE_DOWN or move == MOVE_DESCEND
	if move != MOVE_DOWN:
		_set_core_enabled(false)
	_update_body()
	_place()
	move_changed.emit(move)


func _move_s() -> float:
	return float(_arena.get("move_s", 0.6))


func _hover_x_min() -> float:
	return float((_arena.get("hover", {}) as Dictionary).get("x_min", 4.0))


func _hover_x_max() -> float:
	return float((_arena.get("hover", {}) as Dictionary).get("x_max", 20.0))


# --- Nucleo ---

func _set_core_enabled(enabled: bool) -> void:
	if _core != null:
		_core.set_enabled(enabled)
		_place()


# --- Interno ---

func _lap_entry() -> Dictionary:
	var lap: int = lap_override if lap_override > 0 else GameState.lap
	var laps: Dictionary = get_config().get("laps", {})
	return laps.get(str(lap), laps.get("1", {}))


## Ajustes de la vuelta: enfriamiento de los cargadores, compas de la fase 3 y
## parpadeo de sus plataformas.
func _apply_lap_settings() -> void:
	var cooldown: float = float(lap_value("charger_cooldown_s", -1.0))
	if cooldown > 0.0:
		for charger: Charger in _chargers():
			charger.cooldown_s = cooldown
	var p3: Dictionary = _lap.get("phase3", {})
	for node: Node in BossBase.phase_nodes(_level_root()):
		if node is RhythmZone and p3.has("tempo_steps_s"):
			(node as RhythmZone).tempo_steps_s = (p3["tempo_steps_s"] as Array).duplicate()
		elif node is BlinkPlatform and p3.has("blink_on_fraction"):
			(node as BlinkPlatform).on_fraction = float(p3["blink_on_fraction"])


func _chargers() -> Array[Charger]:
	var out: Array[Charger] = []
	var root: Node = _level_root()
	if root == null:
		return out
	var stack: Array[Node] = [root]
	while not stack.is_empty():
		var node: Node = stack.pop_back()
		if node is Charger:
			out.append(node as Charger)
		for child: Node in node.get_children():
			stack.append(child)
	return out


## Raiz del nivel (GeneratedLevel) o el padre.
func _level_root() -> Node:
	var node: Node = get_parent()
	while node != null:
		if node is GeneratedLevel:
			return node
		node = node.get_parent()
	return get_parent()


func _to_global(p: Vector2) -> Vector2:
	var parent := get_parent() as Node2D
	return parent.to_global(p) if parent != null else p


func _from_global(p: Vector2) -> Vector2:
	var parent := get_parent() as Node2D
	return parent.to_local(p) if parent != null else p


func _up_size() -> Vector2:
	var s: Array = _arena.get("body_up_px", [256, 256])
	return Vector2(float(s[0]), float(s[1]))


func _down_size() -> Vector2:
	var s: Array = _arena.get("body_down_px", [128, 128])
	return Vector2(float(s[0]), float(s[1]))


func _texture(file_name: String) -> Texture2D:
	if not _textures.has(file_name):
		var path: String = String(_arena.get("art_dir", "res://assets/sprites/bosses/")) + file_name
		_textures[file_name] = load(path) as Texture2D if ResourceLoader.exists(path) else null
	return _textures[file_name]


func _build() -> void:
	_body = Sprite2D.new()
	_body.name = "Body"
	_body.top_level = true
	add_child(_body)
	_label = Label.new()
	_label.name = "Counter"
	_label.top_level = true
	var font := load(String(_arena.get("font", "res://assets/sprites/ui/text_font.fnt"))) as Font
	if font != null:
		_label.add_theme_font_override(&"font", font)
	_label.add_theme_font_size_override(&"font_size", int(_arena.get("font_size", 12)))
	_label.add_theme_color_override(&"font_color", Color.html(String(_arena.get("label_color", "#f2f4f8"))))
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.size = Vector2(_tile * 2.0, 24.0)
	_label.scale = Vector2(2.0, 2.0)
	add_child(_label)
	_core = WEAK_POINT_SCENE.instantiate() as WeakPoint
	_core.name = "Core"
	_core.top_level = true
	add_child(_core)
	var size: Vector2 = _down_size()
	var off: Array = _arena.get("core_offset_px", [0, -56])
	var core_from_center := Vector2(float(off[0]), float(off[1]) + size.y * 0.5)
	_core.set_shell_rect(Rect2(-core_from_center - size * 0.5, size))
	set_weak_point(_core)
	_core.set_enabled(false)
	_attacks = Node2D.new()
	_attacks.name = "Attacks"
	_attacks.top_level = true
	add_child(_attacks)
	_warn_layer = WarnLayer.new()
	_warn_layer.name = "Warnings"
	_warn_layer.top_level = true
	_warn_layer.z_index = 40
	_warn_layer.boss = self
	add_child(_warn_layer)


func _update_body() -> void:
	if _body == null:
		return
	var scale_px: float = float(_arena.get("draw_scale", 2.0))
	if _move == MOVE_GONE:
		_body.visible = false
		_label.visible = false
		return
	_body.visible = true
	_label.visible = true
	if _down:
		_body.texture = _texture(ART_DOWN)
	else:
		_body.texture = _texture(ART_INFLATE if _inflated else ART_REST)
	_body.scale = Vector2(scale_px, scale_px)


func _place() -> void:
	if _body == null:
		return
	_body.global_position = _center
	var size: Vector2 = _down_size() if _down else _up_size()
	_label.global_position = _center + Vector2(-_tile * 2.0, -size.y * 0.5 - 52.0) if _down \
		else _center + Vector2(-_tile * 2.0, -24.0)
	var off: Array = _arena.get("core_offset_px", [0, -56])
	_core.global_position = _center + Vector2(float(off[0]), _down_size().y * 0.5 + float(off[1]))


func _inflate(on: bool) -> void:
	_inflated = on
	_update_body()


func _update_label() -> void:
	if _label != null:
		_label.text = get_counter_label()


## Borra todos los ataques en curso (cambio de fase, reaparicion, golpe final).
func _clear_attacks() -> void:
	_inflate(false)
	_clear_warnings()
	_bubbles.clear()
	_banners.clear()
	_popups.clear()
	_burst_state = &""
	_shield = null
	if _attacks == null:
		return
	for child: Node in _attacks.get_children():
		_attacks.remove_child(child)
		child.queue_free()


func _poll_arrival() -> void:
	var isak: Isak = find_isak()
	if isak == null:
		return
	if isak.is_warping() or isak.is_dead():
		return
	begin_intro()


func _on_intro_finished() -> void:
	_intro_state = 2
	_inflate(false)
	start()


# --- Avisos (telegrafiado: 9 cuadros, regla de 6-12) ---

func get_warnings() -> Array[Dictionary]:
	return _warnings


func _clear_warnings() -> void:
	_warnings.clear()
	if _warn_layer != null:
		_warn_layer.queue_redraw()


func _remove_warning(id: String) -> void:
	_warnings = _warnings.filter(func(w: Dictionary) -> bool: return String(w.get("id", "")) != id)
	_warn_layer.queue_redraw()


func _set_warning_line(id: String, from: Vector2, to: Vector2) -> void:
	for w: Dictionary in _warnings:
		if String(w.get("id", "")) == id:
			w["from"] = from
			w["to"] = to


## Capa de los avisos (arte provisional por codigo, colores de mundo1.gpl):
## arrow_down (flecha alerta que cae en un sitio), lane (flecha en el muro de
## entrada y linea discontinua por el carril), outline (contorno punteado
## banner_blanco donde saldra un pop-up) y line (linea alerta de un
## lanzamiento). Parpadean a anim_fps / 2.
class WarnLayer extends Node2D:
	var boss: AlertMajor
	var _t: float = 0.0

	func _process(delta: float) -> void:
		_t += WorldTime.scaled_delta(delta)
		if boss != null and not boss.get_warnings().is_empty():
			queue_redraw()

	func _draw() -> void:
		if boss == null:
			return
		var cfg: Dictionary = boss.get_config().get("arena", {})
		var warn := Color.html(String(cfg.get("warn_color", "#ff4a2a")))
		var shade := Color.html(String(cfg.get("warn_shadow", "#a3221c")))
		var white := Color.html(String(cfg.get("outline_color", "#f2f4f8")))
		var on: bool = int(floor(_t * float(cfg.get("anim_fps", 12.0)) / 2.0)) % 2 == 0
		for w: Dictionary in boss.get_warnings():
			match String(w.get("kind", "")):
				"arrow_down":
					var at: Vector2 = w["at"]
					var c: Color = warn if on else shade
					draw_colored_polygon(PackedVector2Array([at + Vector2(-20, -40), at + Vector2(20, -40), at]), c)
					draw_rect(Rect2(at + Vector2(-6, -64), Vector2(12, 24)), c)
				"lane":
					var y: float = float(w["y"])
					var x0: float = float(w["x0"])
					var x1: float = float(w["x1"])
					var x: float = x0
					while x < x1 and on:
						draw_rect(Rect2(Vector2(x, y - 2.0), Vector2(16.0, 4.0)), warn)
						x += 32.0
					var e: float = float(w["entry"])
					var d: float = float(w["dir"])
					draw_colored_polygon(PackedVector2Array([Vector2(e, y - 20.0), Vector2(e, y + 20.0),
						Vector2(e + d * 32.0, y)]), warn if on else shade)
				"outline":
					var r: Rect2 = w["rect"]
					var step: float = 16.0
					if on:
						var xx: float = r.position.x
						while xx < r.end.x:
							draw_rect(Rect2(Vector2(xx, r.position.y), Vector2(8.0, 3.0)), white)
							draw_rect(Rect2(Vector2(xx, r.end.y - 3.0), Vector2(8.0, 3.0)), white)
							xx += step
						var yy: float = r.position.y
						while yy < r.end.y:
							draw_rect(Rect2(Vector2(r.position.x, yy), Vector2(3.0, 8.0)), white)
							draw_rect(Rect2(Vector2(r.end.x - 3.0, yy), Vector2(3.0, 8.0)), white)
							yy += step
				"line":
					if on:
						draw_dashed_line(w["from"], w["to"], warn, 4.0, 12.0)


# --- Fase 1 «99+»: Burbujas y barridos (paso 6, §2.5) ---

## Burbujas vivas de la fase 1 (sin reventar).
func get_bubbles() -> Array[AlertBubble]:
	var out: Array[AlertBubble] = []
	for b: AlertBubble in _bubbles:
		if is_instance_valid(b) and b.get_state() != AlertBubble.STATE_POPPED:
			out.append(b)
	return out


## Banners de la fase 1 por carril ({"floor": SpamBanner, "high": SpamBanner}).
func get_banners() -> Dictionary:
	return _banners


## Escupiendo Burbujas: segundos del mundo de aviso que quedan (0 si no).
func get_spit_left() -> float:
	return _spit_left


## Las Burbujas de la ronda ya salieron y ninguna viva patrulla (todas aturdidas o
## derrotadas a la vez): el jefe puede bajar.
func are_bubbles_neutralized() -> bool:
	if not _round_spit_done:
		return false
	for b: AlertBubble in get_bubbles():
		if not b.is_stunned() or int(b.get_meta(&"stun_round", -1)) != _round_id:
			return false
	return true


## Fuerza un barrido del carril `lane` (pruebas y bot). Falso si ese banner ya barre.
func trigger_sweep(lane: String) -> bool:
	var banner := _banners.get(lane) as SpamBanner
	if banner == null or not banner.trigger():
		return false
	attack_started.emit(&"sweep")
	return true


func _phase1_start() -> void:
	var p1: Dictionary = phase_data(1)
	_bubbles.clear()
	_round_id += 1
	_round_spit_done = false
	_spit_left = 0.0
	_spit_cooldown = 0.0
	_sweep_t = float(p1.get("sweep_interval_s", 3.0)) - float(p1.get("sweep_first_s", 2.0))
	_sweep_index = 0
	_banners.clear()
	var lanes: Dictionary = _arena.get("lanes", {})
	for sw: Dictionary in p1.get("sweeps", []):
		var lane: Dictionary = lanes.get(String(sw.get("lane", "")), {})
		if lane.is_empty():
			continue
		var banner := BANNER_SCENE.instantiate() as SpamBanner
		banner.name = "Banner_%s" % sw["lane"]
		_attacks.add_child(banner)
		var span: int = int(lane["to_col"]) - int(lane["from_col"]) + 1
		banner.manual = true
		banner.corridor_tiles = span
		banner.direction = int(sw.get("direction", 1))
		banner.interval_s = 0.0
		banner.global_position = Vector2((float(sw.get("entry_col", lane["from_col"])) + 0.5) * _tile,
			float(lane["surface_row"]) * _tile)
		banner.reset_patrol()
		_banners[String(sw["lane"])] = banner


func _phase1_advance(dt: float) -> void:
	var p1: Dictionary = phase_data(1)
	if _move != MOVE_HOVER:
		return
	_spit_cooldown = maxf(_spit_cooldown - dt, 0.0)
	# Escupir: aviso (se infla y marca donde caeran) y despues las Burbujas.
	if _spit_left > 0.0:
		_spit_left -= dt
		if _spit_left <= 0.0:
			_spit_now()
		return
	if not _round_spit_done and _spit_cooldown <= 0.0:
		var targets: Array[StringName] = _free_spit_spots()
		if targets.is_empty():
			_round_spit_done = true
		else:
			_spit_targets = targets
			_spit_left = frames_s(p1.get("spit_warn_frames", 9))
			_inflate(true)
			_set_warnings_spit(targets)
			attack_started.emit(&"spit")
			return
	# Barridos alternos (uno cada sweep_interval_s).
	_sweep_t += dt
	var interval: float = float(p1.get("sweep_interval_s", 3.0))
	if _sweep_t >= interval:
		var sweeps: Array = p1.get("sweeps", [])
		if not sweeps.is_empty():
			var lane: String = String((sweeps[_sweep_index % sweeps.size()] as Dictionary).get("lane", ""))
			if trigger_sweep(lane):
				_sweep_index += 1
				_sweep_t = 0.0
	# Ventana: Burbujas neutralizadas y ningun barrido en curso.
	if are_bubbles_neutralized() and not _any_banner_busy():
		move_body_to(get_spot_center(StringName(String(p1.get("window_spot", "floor_center")))), true)


func _phase1_arrived(move_done: StringName) -> void:
	if move_done == MOVE_DESCEND:
		_set_core_enabled(true)
		open_window(float(phase_data(1).get("window_s", 5.0)))
	else:
		_round_id += 1
		_round_spit_done = false
		_spit_cooldown = float(phase_data(1).get("spit_cooldown_s", 1.0))
		_sweep_t = 0.0


func _phase1_window_closed() -> void:
	move_body_to(get_hover_center(_from_global(_center).x / _tile), false)


## Sitios de escupir sin Burbuja viva (como mucho bubble_max - vivas).
func _free_spit_spots() -> Array[StringName]:
	var p1: Dictionary = phase_data(1)
	var alive: Array[AlertBubble] = get_bubbles()
	var room: int = int(p1.get("bubble_max", 2)) - alive.size()
	var out: Array[StringName] = []
	for spot: Variant in p1.get("spit_spots", []):
		if out.size() >= room:
			break
		var taken: bool = false
		var center: Vector2 = get_spot_center(StringName(String(spot)))
		for b: AlertBubble in alive:
			if absf(b.global_position.x - center.x) < _tile * 2.5 and absf(b.global_position.y - (center.y + _down_size().y * 0.5)) < _tile * 1.5:
				taken = true
		if not taken:
			out.append(StringName(String(spot)))
	return out


func _spit_now() -> void:
	_spit_left = 0.0
	_inflate(false)
	_clear_warnings()
	var p1: Dictionary = phase_data(1)
	var bottom: float = _center.y + _up_size().y * 0.5
	for spot: StringName in _spit_targets:
		var bubble := BUBBLE_SCENE.instantiate() as AlertBubble
		bubble.patrol_range_px = float(p1.get("bubble_patrol_range_px", 256.0))
		var spot_center: Vector2 = get_spot_center(spot)
		bubble.position = Vector2(spot_center.x, minf(bottom, spot_center.y))
		bubble.add_to_group(&"help_target")
		bubble.set_meta(&"help_id", "alert_bubble")
		_attacks.add_child(bubble)
		_track_bubble(bubble)
	_spit_targets.clear()
	_round_spit_done = true


func _track_bubble(bubble: AlertBubble) -> void:
	_bubbles.append(bubble)
	bubble.stunned.connect(func() -> void: bubble.set_meta(&"stun_round", _round_id))


func _any_banner_busy() -> bool:
	for banner: Variant in _banners.values():
		if is_instance_valid(banner) and (banner as SpamBanner).is_busy():
			return true
	return false


## Flecha alerta sobre cada sitio donde caera una Burbuja.
func _set_warnings_spit(targets: Array[StringName]) -> void:
	_warnings.clear()
	for spot: StringName in targets:
		var c: Vector2 = get_spot_center(spot)
		_warnings.append({"kind": "arrow_down", "at": c + Vector2(0.0, -_tile * 0.25)})
	_warn_layer.queue_redraw()


# --- Fase 2 «66»: pop-ups, rafagas y escudo (paso 7, §2.6) ---

## Pop-ups de la lluvia abiertos (sin el escudo).
func get_popups() -> Array[OverlayPopup]:
	var out: Array[OverlayPopup] = []
	for p: Dictionary in _popups:
		var node: Variant = p.get("node")
		if node != null and is_instance_valid(node) and (node as OverlayPopup).is_open():
			out.append(node as OverlayPopup)
	return out


## Notificaciones de la rafaga en vuelo.
func get_shots() -> Array[NotificationShot]:
	var out: Array[NotificationShot] = []
	for child: Node in _attacks.get_children():
		if child is NotificationShot and not (child as NotificationShot).is_done():
			out.append(child as NotificationShot)
	return out


## Pop-up escudo (null fuera de la fase 2).
func get_shield() -> OverlayPopup:
	return _shield if _shield != null and is_instance_valid(_shield) else null


## Rafaga en curso: aviso (warn) o disparando (fire); &"" si no hay.
func get_burst_state() -> StringName:
	return _burst_state


## Carril de la rafaga en curso (o la ultima).
func get_burst_lane() -> String:
	return _burst_lane


## Cuarto de la arena (indice de phase2.popup_quarters) que contiene `point` o -1.
func quarter_of(point: Vector2) -> int:
	var quarters: Array = phase_data(2).get("popup_quarters", [])
	for i: int in quarters.size():
		if _quarter_rect(i).grow(0.5).has_point(point):
			return i
	return -1


## Fuerza una rafaga ya (pruebas y bot). Falso si hay una en curso.
func start_burst() -> bool:
	if _burst_state != &"":
		return false
	var isak: Isak = find_isak()
	var lanes: Dictionary = _arena.get("lanes", {})
	_burst_lane = "floor"
	if isak != null:
		var floor_feet: float = float((lanes.get("floor", {}) as Dictionary).get("surface_row", 10)) * _tile
		_burst_lane = "floor" if isak.global_position.y > floor_feet - _tile * 1.5 else "high"
	var lane: Dictionary = lanes.get(_burst_lane, {})
	var x0: float = float(lane.get("from_col", 1)) * _tile
	var x1: float = (float(lane.get("to_col", 22)) + 1.0) * _tile
	var ix: float = isak.global_position.x if isak != null else (x0 + x1) * 0.5
	# Entra por el muro mas lejano de Isak (le da tiempo a reaccionar).
	_burst_dir = 1 if ix - x0 > x1 - ix else -1
	_burst_state = &"warn"
	_burst_t = 0.0
	_burst_fired = 0
	var y: float = float(lane.get("surface_row", 10)) * _tile + _phone_y()
	var entry_x: float = x0 if _burst_dir > 0 else x1
	_warnings.append({"kind": "lane", "id": "burst", "x0": x0, "x1": x1, "y": y, "dir": _burst_dir,
		"entry": entry_x})
	_warn_layer.queue_redraw()
	attack_started.emit(&"burst")
	return true


func _phase2_start() -> void:
	var p2: Dictionary = phase_data(2)
	_rng.seed = int(p2.get("seed", 1021))
	_popups.clear()
	_popup_t = float(p2.get("popup_every_s", 6.0)) - float(p2.get("popup_first_s", 1.5))
	_burst_t_next = float(p2.get("burst_every_s", 4.5)) - float(p2.get("burst_first_s", 3.0))
	_burst_state = &""
	_window_t = 0.0
	_perch_t = 0.0
	_perch_spot = &""
	_popup_button_lane = 0
	_build_shield()


func _phase2_advance(dt: float) -> void:
	var p2: Dictionary = phase_data(2)
	_advance_popups(dt, p2)
	_advance_burst(dt, p2)
	match _move:
		MOVE_HOVER:
			_window_t += dt
			if _window_t >= float(p2.get("window_every_s", 12.0)) and _burst_state == &"":
				_perch_spot = _far_perch_spot()
				_shield.reopen()
				_shield.visible = true
				move_body_to(get_spot_center(_perch_spot), true)
		MOVE_DOWN:
			if not is_window_open():
				_perch_t += dt
				if _perch_t >= float(p2.get("perch_s", 7.0)):
					_phase2_leave()


func _phase2_arrived(move_done: StringName) -> void:
	if move_done == MOVE_DESCEND:
		_perch_t = 0.0
		attack_started.emit(&"shield")
		if not _shield.is_open():
			_on_shield_closing()
	else:
		_window_t = 0.0
		_shield.visible = false


func _phase2_window_closed() -> void:
	_phase2_leave()


func _phase2_leave() -> void:
	_set_core_enabled(false)
	_shield.reopen()
	move_body_to(get_hover_center(_from_global(_center).x / _tile), false)


## El escudo se cierra con el pulso: abre la ventana.
func _on_shield_closing() -> void:
	if get_phase() != 2 or _move != MOVE_DOWN or is_window_open():
		return
	_set_core_enabled(true)
	open_window(float(phase_data(2).get("window_s", 4.0)))


func _build_shield() -> void:
	if _shield != null and is_instance_valid(_shield):
		return
	var p2: Dictionary = phase_data(2)
	var sh: Dictionary = p2.get("shield", {})
	_shield = POPUP_SCENE.instantiate() as OverlayPopup
	_shield.name = "Shield"
	_shield.object_id = &"escudo"
	_shield.text = ""
	_shield.width_tiles = int(sh.get("width_tiles", 2))
	_shield.height_tiles = int(sh.get("height_tiles", 2))
	var b: Array = sh.get("close_button_px", [52, 96])
	_shield.close_button_position = Vector2(float(b[0]), float(b[1]))
	_shield.close_button_size = int(sh.get("close_button_size_px", 24))
	_shield.opaque = true
	_shield.icon_texture = _texture(ART_SHIELD)
	var size: Vector2 = Vector2(_shield.width_tiles, _shield.height_tiles) * _tile
	_shield.follow_offset = -size * 0.5
	_attacks.add_child(_shield)
	_shield.follow_target = _body
	_shield.closing_started.connect(_on_shield_closing)
	_shield.visible = false


func _advance_popups(dt: float, p2: Dictionary) -> void:
	# Caducan (popup_life_s) y avisos que se convierten en pop-up.
	for p: Dictionary in _popups:
		p["t"] = float(p["t"]) + dt
		var node: Variant = p.get("node")
		if node == null:
			if float(p["t"]) >= frames_s(p2.get("popup_warn_frames", 9)):
				_open_popup(p, p2)
		elif is_instance_valid(node) and float(p["t"]) >= frames_s(p2.get("popup_warn_frames", 9)) \
				+ float(p2.get("popup_life_s", 8.0)):
			(node as OverlayPopup).close()
	_popups = _popups.filter(func(p: Dictionary) -> bool:
		var node: Variant = p.get("node")
		return node == null or (is_instance_valid(node) and not (node as OverlayPopup).is_closed()))
	_popup_t += dt
	if _popup_t < float(p2.get("popup_every_s", 6.0)):
		return
	var max_n: int = int(lap_value("popup_max", 2, "phase2"))
	if _popups.size() >= max_n:
		return
	var q: int = _pick_quarter()
	if q < 0:
		return
	_popup_t = 0.0
	_popups.append({"quarter": q, "t": 0.0, "node": null})
	_warnings.append({"kind": "outline", "id": "popup_%d" % q, "rect": _quarter_rect(q)})
	_warn_layer.queue_redraw()
	attack_started.emit(&"popup")


func _pick_quarter() -> int:
	var quarters: Array = phase_data(2).get("popup_quarters", [])
	var isak: Isak = find_isak()
	var isak_q: int = quarter_of(isak.global_position - Vector2(0.0, 40.0)) if isak != null else -1
	var free: Array[int] = []
	for i: int in quarters.size():
		if i == isak_q:
			continue
		var used: bool = false
		for p: Dictionary in _popups:
			if int(p["quarter"]) == i:
				used = true
		if not used:
			free.append(i)
	if free.is_empty():
		return -1
	return free[_rng.randi_range(0, free.size() - 1)]


func _quarter_rect(i: int) -> Rect2:
	var q: Array = phase_data(2).get("popup_quarters", [])[i]
	return Rect2(_to_global(Vector2(float(q[0]), float(q[1])) * _tile), Vector2(float(q[2]), float(q[3])) * _tile)


func _open_popup(p: Dictionary, p2: Dictionary) -> void:
	_remove_warning("popup_%d" % int(p["quarter"]))
	var rect: Rect2 = _quarter_rect(int(p["quarter"]))
	var popup := POPUP_SCENE.instantiate() as OverlayPopup
	var texts: Array = _texts.get("popups", [])
	popup.text = String(texts[_rng.randi_range(0, texts.size() - 1)]) if not texts.is_empty() else "99+"
	popup.width_tiles = roundi(rect.size.x / _tile)
	popup.height_tiles = roundi(rect.size.y / _tile)
	popup.opacity = float(p2.get("popup_opacity", 0.7))
	popup.debug_opacity = float(p2.get("popup_debug_opacity", 0.15))
	# Boton de 24 px a la altura del celular de Isak en un carril (alterna suelo / alto).
	var lanes: Dictionary = _arena.get("lanes", {})
	var lane: String = "floor" if _popup_button_lane % 2 == 0 else "high"
	_popup_button_lane += 1
	var phone_y: float = float((lanes.get(lane, {}) as Dictionary).get("surface_row", 10)) * _tile + _phone_y()
	var size: int = popup.close_button_size
	popup.close_button_position = Vector2(rect.size.x * 0.5 - size * 0.5, phone_y - rect.position.y - size * 0.5)
	popup.add_to_group(&"help_target")
	popup.set_meta(&"help_id", "overlay_popup")
	_attacks.add_child(popup)
	popup.global_position = rect.position
	p["node"] = popup


func _advance_burst(dt: float, p2: Dictionary) -> void:
	if _burst_state == &"":
		if is_window_open():
			return
		_burst_t_next += dt
		if _burst_t_next >= float(p2.get("burst_every_s", 4.5)):
			_burst_t_next = 0.0
			start_burst()
		return
	_burst_t += dt
	var warn: float = frames_s(p2.get("burst_warn_frames", 9))
	if _burst_state == &"warn":
		if _burst_t >= warn:
			_burst_state = &"fire"
			_burst_t = 0.0
			_remove_warning("burst")
		return
	var shots: int = int(p2.get("burst_shots", 3))
	var spacing: float = float(p2.get("burst_spacing_s", 0.5))
	while _burst_fired < shots and _burst_t >= float(_burst_fired) * spacing:
		_fire_shot(p2, _burst_t - float(_burst_fired) * spacing)
		_burst_fired += 1
	if _burst_fired >= shots and get_shots().is_empty():
		_burst_state = &""


func _fire_shot(p2: Dictionary, late_s: float) -> void:
	var lanes: Dictionary = _arena.get("lanes", {})
	var lane: Dictionary = lanes.get(_burst_lane, {})
	var x0: float = float(lane.get("from_col", 1)) * _tile
	var x1: float = (float(lane.get("to_col", 22)) + 1.0) * _tile
	var s: Array = p2.get("shot_size_px", [64, 32])
	var shot := NotificationShot.new()
	shot.direction = _burst_dir
	shot.speed_px_s = float(p2.get("shot_speed_px_s", 640.0))
	shot.size_px = Vector2(float(s[0]), float(s[1]))
	shot.contact_damage = float(p2.get("contact_damage", 10.0))
	shot.travel_px = (x1 - x0) - shot.size_px.x
	var y: float = float(lane.get("surface_row", 10)) * _tile + _phone_y()
	var start_x: float = (x0 + shot.size_px.x * 0.5) if _burst_dir > 0 else (x1 - shot.size_px.x * 0.5)
	_attacks.add_child(shot)
	shot.global_position = _to_global(Vector2(start_x, y))
	if late_s > 0.0:
		shot.step(late_s)


## Plataforma de phase2.perch_spots mas lejana de Isak.
func _far_perch_spot() -> StringName:
	var spots: Array = phase_data(2).get("perch_spots", ["platform_left", "platform_right"])
	var isak: Isak = find_isak()
	var best: StringName = StringName(String(spots[0]))
	var best_d: float = -1.0
	for spot: Variant in spots:
		var d: float = absf(get_spot_center(StringName(String(spot))).x - (isak.global_position.x if isak != null else 0.0))
		if d > best_d:
			best_d = d
			best = StringName(String(spot))
	return best


func _phone_y() -> float:
	var off: Array = _arena.get("core_offset_px", [0, -56])
	return float(off[1])
