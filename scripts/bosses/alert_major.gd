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

const MOVE_HOVER: StringName = &"hover"
const MOVE_DESCEND: StringName = &"descend"
const MOVE_DOWN: StringName = &"down"
const MOVE_ASCEND: StringName = &"ascend"
const MOVE_GONE: StringName = &"gone"

const ART_REST: String = "alert_major_rest_placeholder.png"
const ART_INFLATE: String = "alert_major_inflate_placeholder.png"
const ART_DOWN: String = "alert_major_down_placeholder.png"

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


## Virtual de las fases: ha terminado de bajar (MOVE_DESCEND) o subir.
func _on_arrived(_move_done: StringName) -> void:
	pass


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
