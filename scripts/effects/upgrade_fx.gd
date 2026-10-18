## Efecto corto de las mejoras de Calc (tanda M2): «+4» del Pulso de retorno,
## destello del laser que perfora y «?» del perseguidor que pierde el rastro con
## el Ocultarte. Hoja de tools/gen_upgrade_fx.py y datos en data/upgrade_fx.json
## (fila, fps y desplazamiento por animacion). Tiempo real; se libera al acabar.
## Uso: UpgradeFx.spawn(padre, &"energy_return", posicion_global).
class_name UpgradeFx
extends Node2D

const DATA_PATH: String = "res://data/upgrade_fx.json"
const ENERGY_RETURN: StringName = &"energy_return"
const PIERCE_SPARK: StringName = &"pierce_spark"
const LOST_TRAIL: StringName = &"lost_trail"

static var _data: Dictionary = {}
static var _texture: Texture2D

var kind: StringName
## Si es false, _process no avanza (las pruebas llaman a advance).
var auto_process: bool = true
## Seguir a este nodo (p. ej. el perseguidor que pierde el rastro); null = quieto.
var follow: Node2D

var _sprite: Sprite2D
var _time: float = 0.0
var _fps: float = 10.0
var _row: int = 0
var _columns: int = 6
var _offset := Vector2.ZERO


static func load_data() -> Dictionary:
	if _data.is_empty():
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(DATA_PATH))
		_data = parsed if parsed is Dictionary else {}
	return _data


## Crea el efecto `effect` en `at` (global) como hijo de `parent`. Null sin padre
## o si la animacion no existe.
static func spawn(parent: Node, effect: StringName, at: Vector2, follow_node: Node2D = null) -> UpgradeFx:
	if parent == null or not is_instance_valid(parent):
		return null
	if not (load_data().get("animations", {}) as Dictionary).has(String(effect)):
		return null
	var fx := UpgradeFx.new()
	fx.kind = effect
	fx.follow = follow_node
	fx.name = "UpgradeFx_%s" % effect
	parent.add_child(fx)
	fx.global_position = at
	return fx


func _ready() -> void:
	var d: Dictionary = load_data()
	var anim: Dictionary = (d.get("animations", {}) as Dictionary).get(String(kind), {})
	_row = int(anim.get("row", 0))
	_fps = maxf(float(anim.get("fps", 10.0)), 0.01)
	var off: Array = anim.get("offset_px", [0.0, 0.0])
	_offset = Vector2(float(off[0]), float(off[1]))
	_columns = int(d.get("columns", 6))
	z_index = int(d.get("z_index", 6))
	if _texture == null:
		_texture = load(String(d.get("texture", ""))) as Texture2D
	_sprite = Sprite2D.new()
	_sprite.name = "Sprite"
	_sprite.texture = _texture
	_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_sprite.hframes = _columns
	_sprite.vframes = maxi(1, int(_texture.get_height() / float((d.get("frame_size", [24, 24]) as Array)[1]))) if _texture != null else 1
	_sprite.scale = Vector2.ONE * float(d.get("scale", 2))
	_sprite.position = _offset
	add_child(_sprite)
	_show_frame()


func _process(delta: float) -> void:
	if auto_process:
		advance(delta)


## Avanza `delta` segundos reales; al pasar el ultimo cuadro se libera.
func advance(delta: float) -> void:
	_time += delta
	if follow != null and is_instance_valid(follow):
		global_position = follow.global_position
	if get_frame() >= _columns:
		queue_free()
		return
	_show_frame()


## Cuadro actual (0 a columns - 1; columns o mas = acabado).
func get_frame() -> int:
	return floori(_time * _fps)


## Duracion total (s).
func get_duration_s() -> float:
	return float(_columns) / _fps


func _show_frame() -> void:
	if _sprite != null:
		_sprite.frame = _row * _columns + clampi(get_frame(), 0, _columns - 1)
