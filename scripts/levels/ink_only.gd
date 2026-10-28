## Escrito «en tinta» (tipo `ink_only` del catalogo del Mundo 4; 2026-10-28, paso 4 de
## docs/propuesta-mundo-4.md §8 y §3.6): algo que SOLO EXISTE BAJO LA LUZ de la
## Linterna, dentro de una zona «Modo oscuro» (DarkZone.lit_by_flashlight sobre su
## centro). Dos clases (`kind`):
## - decor: un texto (`text`, una o dos lineas, solo glifos de la fuente) o una flecha
##   en crema, sin colision; marca la entrada de un secreto (4-2 A y 4-3 B).
## - step: un paso de una via de width_tiles x 1 (tarjeta de step_height_px arriba de
##   su celda); solido solo mientras esta bajo la luz (si Isak esta encima, no
##   desaparece hasta que baja: no se cae por apagarse).
## Se dibuja por encima del velo (DarkZone.veil_z() + 1), con alpha que sube al entrar
## en la luz. El esquema exige que este dentro de una dark_zone. Aspecto PROVISIONAL
## por codigo (seccion ink_only de data/world4_objects.json). El origen es la esquina
## superior izquierda de su celda.
class_name InkOnly
extends StaticBody2D

const GROUP: StringName = &"ink_only"
const LAYER_WORLD: int = 1

## Aparece o desaparece bajo la luz.
signal lit_changed(lit: bool)

@export var object_id: StringName = &""
## "decor" o "step".
@export var kind: String = "decor"
@export var text: String = ""
@export_range(1, 4) var width_tiles: int = 1
## Si es false, _physics_process no avanza (las pruebas llaman a refresh()).
var auto_process: bool = true

var _cfg: Dictionary = World4ObjectsConfig.section("ink_only")
var _lit: bool = false
var _alpha: float = 0.0
var _shape: CollisionShape2D
var _font: Font


func _ready() -> void:
	add_to_group(GROUP)
	z_as_relative = false
	z_index = DarkZone.veil_z() + 1
	collision_layer = LAYER_WORLD if kind == "step" else 0
	collision_mask = 0
	var font_path: String = String(_cfg.get("font", "res://assets/sprites/ui/text_font.fnt"))
	if ResourceLoader.exists(font_path):
		_font = load(font_path) as Font
	if kind == "step":
		_shape = CollisionShape2D.new()
		_shape.name = "Shape"
		var rect := RectangleShape2D.new()
		rect.size = get_step_size()
		_shape.shape = rect
		_shape.position = rect.size * 0.5
		_shape.one_way_collision = true
		_shape.disabled = true
		add_child(_shape)
	refresh(0.0)


func _physics_process(delta: float) -> void:
	if auto_process:
		refresh(delta)


## Mira si esta bajo la luz y avanza el fundido (`delta` real). Publico para las pruebas.
func refresh(delta: float) -> void:
	var lit: bool = is_inside_tree() and DarkZone.lit_by_flashlight(get_tree(), get_center())
	if lit != _lit:
		if lit or not _isak_on_step():
			_lit = lit
			lit_changed.emit(lit)
	if _shape != null:
		_shape.disabled = not _lit
	var fade: float = maxf(float(_cfg.get("fade_s", 0.25)), 0.01)
	_alpha = move_toward(_alpha, 1.0 if _lit else 0.0, delta / fade) if delta > 0.0 else (1.0 if _lit else 0.0)
	queue_redraw()


func is_lit() -> bool:
	return _lit


func is_solid() -> bool:
	return _shape != null and not _shape.disabled


func get_step_size() -> Vector2:
	return Vector2(float(width_tiles) * World4ObjectsConfig.tile_size(), float(_cfg.get("step_height_px", 24)))


## Centro (global) que tiene que estar bajo la luz.
func get_center() -> Vector2:
	var t: float = World4ObjectsConfig.tile_size()
	return global_position + Vector2(float(width_tiles) * t * 0.5, t * 0.5)


func is_help_available() -> bool:
	return _lit


func _isak_on_step() -> bool:
	if kind != "step" or _shape == null or _shape.disabled:
		return false
	var isak: Isak = LevelLookup.find_isak(self)
	if isak == null or not isak.is_on_floor():
		return false
	var r := Rect2(global_position, get_step_size())
	return absf(isak.global_position.y - r.position.y) <= 6.0 \
			and isak.global_position.x >= r.position.x - 16.0 and isak.global_position.x <= r.end.x + 16.0


func _draw() -> void:
	if _alpha <= 0.0:
		return
	var cream: Color = World4ObjectsConfig.color("crema", Color("#eee4cc"))
	var t: float = World4ObjectsConfig.tile_size()
	if kind == "step":
		var size: Vector2 = get_step_size()
		draw_rect(Rect2(Vector2.ZERO, size), Color(cream, 0.35 * _alpha))
		draw_rect(Rect2(Vector2.ZERO, size), Color(cream, _alpha), false, 2.0)
		return
	if _font == null or text.is_empty():
		return
	var px: int = int(_cfg.get("font_size", 16))
	var lines: PackedStringArray = text.split("\n")
	var line_h: float = float(_cfg.get("line_height_px", 18))
	for i: int in lines.size():
		var w: float = _font.get_string_size(lines[i], HORIZONTAL_ALIGNMENT_LEFT, -1, px).x
		var at := Vector2((float(width_tiles) * t - w) * 0.5, t * 0.5 + line_h * (float(i) - float(lines.size() - 1) * 0.5) + 5.0)
		draw_string(_font, at, lines[i], HORIZONTAL_ALIGNMENT_LEFT, -1, px, Color(cream, _alpha))
