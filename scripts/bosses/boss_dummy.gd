## Jefe «saco» de la sala de prueba boss_test (paso 3 de
## docs/propuesta-jefe-alerta-mayor.md §6, 2026-10-21). Un BossBase minimo para
## probar el WeakPoint danable con la fisica y los controles reales: flota arriba
## (fuera de alcance) up_s, baja en move_s, se queda abajo window_s (ventana: el
## nucleo carmin se activa a la altura del pecho de Isak; el Debug lo revela, el
## pulso lo marca y el laser lo golpea mientras dura la marca, 2026-10-21) y
## sube (la marca se pierde). Su cuerpo de 2 x 2 tiles es el del WeakPoint
## (set_shell_rect): sin Debug ni marca, el laser se para en el y la chispa gris
## sale en su borde, no en el nucleo. Al cambiar de fase o al
## reaparecer Isak vuelve arriba; con el golpe final desaparece. No ataca ni
## hace dano. Tiempo del mundo (el Debug lo ralentiza).
##
## Posicion del nodo (build_level): esquina superior izquierda de la celda (x, y)
## en la que se apoya abajo (2 x 2 tiles: columnas x y x+1, filas y-1 e y). Datos
## en la seccion boss_dummy de data/world1_objects.json y en
## data/bosses/boss_dummy.json. Arte PROVISIONAL (_placeholder) de
## tools/gen_boss_dummy_placeholder.py.
class_name BossDummy
extends BossBase

const MOVE_UP: StringName = &"up"
const MOVE_DESCEND: StringName = &"descend"
const MOVE_DOWN: StringName = &"down"
const MOVE_ASCEND: StringName = &"ascend"
const MOVE_GONE: StringName = &"gone"
const WEAK_POINT_SCENE: PackedScene = preload("res://scenes/bosses/weak_point.tscn")

## Id del objeto en el nivel (params.id).
@export var object_id: StringName = &""
## Segundos del mundo arriba antes de bajar.
@export var up_s: float = 2.0
## Segundos del mundo que tarda en bajar o subir.
@export var move_s: float = 0.6
## Segundos del mundo abajo (ventana).
@export var window_s: float = 5.0
## Tiles que sube por encima de su sitio de abajo.
@export var drop_tiles: float = 5.0

var _move: StringName = MOVE_UP
var _move_time: float = 0.0
var _cfg: Dictionary = {}
var _body: Sprite2D
var _core: WeakPoint
var _label: Label
var _tex_up: Texture2D
var _tex_down: Texture2D


func _ready() -> void:
	if boss_id.is_empty():
		boss_id = &"boss_dummy"
	_cfg = World1ObjectsConfig.section(&"boss_dummy")
	_build()
	super._ready()
	_set_move(MOVE_UP)


## Movimiento actual (up, descend, down, ascend o gone).
func get_move() -> StringName:
	return _move


func get_attack_state() -> StringName:
	return _move


## Centro del cuerpo abajo y arriba (global).
func get_down_center() -> Vector2:
	return global_position + Vector2(_tile(), 0.0)


func get_up_center() -> Vector2:
	return get_down_center() - Vector2(0.0, drop_tiles * _tile())


func get_body_center() -> Vector2:
	return _body.global_position


func get_core() -> WeakPoint:
	return _core


func get_counter_text() -> String:
	return _label.text


# --- BossBase ---

func _on_phase_started(_phase_index: int) -> void:
	_set_move(MOVE_UP)


func _on_advance(dt: float) -> void:
	_move_time += dt
	match _move:
		MOVE_UP:
			if _move_time >= up_s:
				_set_move(MOVE_DESCEND)
		MOVE_DESCEND:
			if _move_time >= move_s:
				_set_move(MOVE_DOWN)
				open_window(window_s)
		MOVE_ASCEND:
			if _move_time >= move_s:
				_set_move(MOVE_UP)
	_place()


func _on_window_closed() -> void:
	if _move == MOVE_DOWN:
		_set_move(MOVE_ASCEND)


func _on_core_hit(_remaining_hits: int) -> void:
	_update_label()


func _on_defeated() -> void:
	_set_move(MOVE_GONE)


func _on_phase_restarted(phase_index: int) -> void:
	super._on_phase_restarted(phase_index)
	_update_label()


# --- Interno ---

func _tile() -> float:
	return World1ObjectsConfig.tile_size()


func _build() -> void:
	var scale_px: float = float(_cfg.get("draw_scale", 2.0))
	_tex_up = load(String(_cfg.get("texture_up", ""))) as Texture2D
	_tex_down = load(String(_cfg.get("texture_down", ""))) as Texture2D
	_body = Sprite2D.new()
	_body.name = "Body"
	_body.texture = _tex_up
	_body.scale = Vector2(scale_px, scale_px)
	add_child(_body)
	_core = WEAK_POINT_SCENE.instantiate() as WeakPoint
	_core.name = "Core"
	_body.add_child(_core)
	_core.scale = Vector2(1.0 / scale_px, 1.0 / scale_px)
	var offset: Array = _cfg.get("core_offset_px", [0, 20])
	_core.position = Vector2(float(offset[0]), float(offset[1])) / scale_px
	var body_size: Vector2 = (_tex_up.get_size() if _tex_up != null else Vector2(_tile(), _tile())) * scale_px
	# Cuerpo en coordenadas del nucleo (escala global 1): centrado en el cuerpo.
	_core.set_shell_rect(Rect2(-Vector2(float(offset[0]), float(offset[1])) - body_size * 0.5, body_size))
	set_weak_point(_core)
	_label = Label.new()
	_label.name = "Counter"
	var font := load(String(_cfg.get("font", "res://assets/sprites/ui/text_font.fnt"))) as Font
	if font != null:
		_label.add_theme_font_override(&"font", font)
	_label.add_theme_font_size_override(&"font_size", int(_cfg.get("font_size", 12)))
	_label.add_theme_color_override(&"font_color", Color.html(String(_cfg.get("label_color", "#f2f4f8"))))
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.size = Vector2(_tile() * 2.0, 24.0)
	add_child(_label)


func _set_move(move: StringName) -> void:
	_move = move
	_move_time = 0.0
	if _core != null:
		_core.set_enabled(move == MOVE_DOWN)
	if _body != null:
		_body.texture = _tex_down if move == MOVE_DOWN or move == MOVE_DESCEND else _tex_up
		_body.visible = move != MOVE_GONE
		_label.visible = move != MOVE_GONE
	_update_label()
	_place()


func _place() -> void:
	if _body == null:
		return
	var down: Vector2 = Vector2(_tile(), 0.0)
	var up: Vector2 = down - Vector2(0.0, drop_tiles * _tile())
	var f: float = 0.0
	match _move:
		MOVE_DOWN, MOVE_GONE:
			f = 1.0
		MOVE_DESCEND:
			f = clampf(_move_time / maxf(move_s, 0.001), 0.0, 1.0)
		MOVE_ASCEND:
			f = 1.0 - clampf(_move_time / maxf(move_s, 0.001), 0.0, 1.0)
	_body.position = up.lerp(down, f)
	_label.position = _body.position + Vector2(-_tile(), -_tile() - 28.0)


func _update_label() -> void:
	if _label != null:
		_label.text = get_counter_label()
