## Pared de espejo (tipo `mirror_wall` del catalogo del Mundo 3; 2026-10-26, paso 4
## de docs/propuesta-mundo-3.md §8, §3.4): marco dorado grande en la pared del
## fondo (decorado: sin colision) que muestra el REFLEJO de su lado de la sala.
##
## Geometria (decision tomada): reflejo horizontal respecto a un eje vertical
## `axis` (side): "center" = el centro del marco (lo que hay delante del espejo
## se ve invertido dentro de el), "left" = su borde izquierdo (el marco muestra
## la franja de su mismo ancho que queda a su izquierda) y "right" = su borde
## derecho. La altura no cambia. Solo se ve lo que cae dentro del marco
## (clip_children del cristal).
##
## Que se refleja (decision tomada, por coste): NO todo el nivel (seria un
## SubViewport con una segunda camara por pared), solo lo que el jugador tiene
## que leer:
## - Isak, con el cuadro de su sprite de hace delay_s (1 s; IsakPoseBuffer en
##   tiempo real, como Isak), espejado y con la variante SATURADA (shader de
##   saturacion `saturation` > 1 y un tinte leve: el aviso de lo que es Isak
##   Optimizado, §6.2). Al reaparecer Isak el bufer se vacia.
## - Las plataformas del reflejo (MirrorOnlyPlatform) cuya pared mas cercana es
##   esta, en su posicion reflejada.
## El cristal es un tinte de la paleta provisional (el fondo y el terreno no se
## reflejan). Aspecto PROVISIONAL por codigo (seccion mirror_wall de
## data/world3_objects.json). El origen es la esquina superior izquierda de su
## primera celda.
class_name MirrorWall
extends Node2D

const GROUP: StringName = &"mirror_wall"
const SIDES: PackedStringArray = ["center", "left", "right"]
const SATURATION_SHADER: String = """
shader_type canvas_item;
uniform float saturation = 1.35;
uniform vec4 tint : source_color = vec4(1.0);
void fragment() {
	vec4 c = texture(TEXTURE, UV);
	float l = dot(c.rgb, vec3(0.299, 0.587, 0.114));
	vec3 s = mix(vec3(l), c.rgb, saturation);
	COLOR = vec4(clamp(s, 0.0, 1.0) * tint.rgb, c.a * tint.a) * COLOR;
}
"""

@export var object_id: StringName = &""
@export_range(1, 20) var width_tiles: int = 6
@export_range(1, 11) var height_tiles: int = 4
## "center", "left" o "right" (ver la cabecera).
@export var side: String = "center"
## Si es false, _physics_process no graba (las pruebas llaman a advance()).
var auto_process: bool = true
## Isak que se refleja (si es null se busca con LevelLookup).
var isak: Isak

var _cfg: Dictionary = World3ObjectsConfig.section("mirror_wall")
var _buffer: IsakPoseBuffer
var _glass: Polygon2D
var _platform_layer: Node2D
var _frame_layer: Node2D
var _isak_sprite: Sprite2D
var _material: ShaderMaterial


func _ready() -> void:
	add_to_group(GROUP)
	if not SIDES.has(side):
		push_warning("MirrorWall %s: side '%s' no valido; se usa 'center'" % [object_id, side])
		side = "center"
	z_index = int(_cfg.get("z_index", -1))
	_buffer = IsakPoseBuffer.new(get_delay_s() + 0.5)
	var size: Vector2 = get_frame_size()
	var inset: float = float(_cfg.get("frame_px", 8))
	_glass = Polygon2D.new()
	_glass.name = "Glass"
	_glass.polygon = PackedVector2Array([Vector2(inset, inset), Vector2(size.x - inset, inset),
		Vector2(size.x - inset, size.y - inset), Vector2(inset, size.y - inset)])
	_glass.color = Color(_c("glass", "trastienda_fondo"), float(_cfg.get("glass_alpha", 0.85)))
	_glass.clip_children = CanvasItem.CLIP_CHILDREN_AND_DRAW
	add_child(_glass)
	_platform_layer = Node2D.new()
	_platform_layer.name = "ReflectedPlatforms"
	_platform_layer.draw.connect(_draw_platforms)
	_glass.add_child(_platform_layer)
	_isak_sprite = Sprite2D.new()
	_isak_sprite.name = "ReflectedIsak"
	_material = ShaderMaterial.new()
	var shader := Shader.new()
	shader.code = SATURATION_SHADER
	_material.shader = shader
	_material.set_shader_parameter(&"saturation", get_saturation())
	_material.set_shader_parameter(&"tint", _c("isak_tint", "blanco_brillante"))
	_isak_sprite.material = _material
	_isak_sprite.visible = false
	_glass.add_child(_isak_sprite)
	_frame_layer = Node2D.new()
	_frame_layer.name = "Frame"
	_frame_layer.draw.connect(_draw_frame)
	add_child(_frame_layer)
	EventBus.player_respawned.connect(_on_player_respawned)


func _physics_process(delta: float) -> void:
	if auto_process:
		advance(delta)


## Graba el estado de Isak tras `dt` segundos reales y actualiza el reflejo.
## Publico para las pruebas.
func advance(dt: float) -> void:
	if isak == null or not is_instance_valid(isak):
		isak = LevelLookup.find_isak(self)
	if isak != null:
		_buffer.record(isak, dt)
	_update_isak_sprite()
	_platform_layer.queue_redraw()


# --- Consultas ---

func get_delay_s() -> float:
	return float(_cfg.get("delay_s", 1.0))


func get_saturation() -> float:
	return float(_cfg.get("saturation", 1.35))


func get_frame_size() -> Vector2:
	return Vector2(width_tiles, height_tiles) * World3ObjectsConfig.tile_size()


## Marco en coordenadas globales.
func get_frame_rect() -> Rect2:
	return Rect2(global_position, get_frame_size())


## Eje vertical del reflejo (x global).
func get_axis_x() -> float:
	var r: Rect2 = get_frame_rect()
	match side:
		"left":
			return r.position.x
		"right":
			return r.end.x
	return r.get_center().x


func reflect_point(p: Vector2) -> Vector2:
	return Vector2(2.0 * get_axis_x() - p.x, p.y)


func reflect_rect(r: Rect2) -> Rect2:
	return Rect2(2.0 * get_axis_x() - r.end.x, r.position.y, r.size.x, r.size.y)


## Region del mundo que se ve en el marco (la reflejada del marco).
func get_source_rect() -> Rect2:
	return reflect_rect(get_frame_rect())


## Muestra de Isak de hace delay_s ({} sin Isak).
func get_delayed_sample() -> Dictionary:
	return _buffer.sample(get_delay_s()) if _buffer != null else {}


## Pies del Isak reflejado (global; Vector2.INF sin muestra).
func get_reflected_isak_position() -> Vector2:
	var s: Dictionary = get_delayed_sample()
	if s.is_empty():
		return Vector2.INF
	return reflect_point(s["position"])


## Verdadero si el Isak reflejado cae (al menos en parte) dentro del marco.
func is_isak_reflected() -> bool:
	return _isak_sprite != null and _isak_sprite.visible


func get_reflected_isak_sprite() -> Sprite2D:
	return _isak_sprite


func get_isak_material() -> ShaderMaterial:
	return _material


## Plataformas del reflejo que dibuja esta pared (las que la tienen por la mas cercana).
func get_mirror_only_platforms() -> Array[MirrorOnlyPlatform]:
	var out: Array[MirrorOnlyPlatform] = []
	if not is_inside_tree():
		return out
	for node: Node in get_tree().get_nodes_in_group(MirrorOnlyPlatform.MIRROR_ONLY_GROUP):
		var p := node as MirrorOnlyPlatform
		if p != null and p.get_mirror_wall() == self:
			out.append(p)
	return out


## Rectangulos (globales) de las plataformas del reflejo dibujadas en el marco:
## su posicion reflejada recortada al cristal; vacio si no caen dentro.
func get_reflected_platform_rects() -> Array[Rect2]:
	var out: Array[Rect2] = []
	var glass: Rect2 = get_frame_rect().grow(-float(_cfg.get("frame_px", 8)))
	for p: MirrorOnlyPlatform in get_mirror_only_platforms():
		var r: Rect2 = reflect_rect(p.get_rect())
		if r.intersects(glass):
			out.append(r.intersection(glass))
	return out


# --- Dibujo ---

func _update_isak_sprite() -> void:
	var s: Dictionary = get_delayed_sample()
	var texture: Texture2D = s.get("texture") as Texture2D if not s.is_empty() else null
	if texture == null:
		_isak_sprite.visible = false
		return
	var feet: Vector2 = reflect_point(s["position"])
	var sp: Vector2 = s["sprite_position"]
	_isak_sprite.texture = texture
	_isak_sprite.centered = bool(s["centered"])
	_isak_sprite.flip_h = not bool(s["flip_h"])
	_isak_sprite.scale = s["sprite_scale"]
	_isak_sprite.rotation = -float(s["sprite_rotation"])
	var off: Vector2 = s["sprite_offset"]
	_isak_sprite.offset = Vector2(-off.x, off.y)
	_isak_sprite.global_position = feet + Vector2(-sp.x, sp.y)
	var half: Vector2 = texture.get_size() * (s["sprite_scale"] as Vector2).abs() * 0.5
	var box := Rect2(_isak_sprite.global_position - half, half * 2.0)
	_isak_sprite.visible = box.intersects(get_frame_rect())


func _draw_platforms() -> void:
	var fill: Color = _c("platform_fill", "rosa_pastel")
	var edge: Color = _c("platform_edge", "blanco_brillante")
	var origin: Vector2 = _platform_layer.global_position
	for r: Rect2 in get_reflected_platform_rects():
		var local := Rect2(r.position - origin, r.size)
		_platform_layer.draw_rect(local, Color(fill, float(_cfg.get("platform_alpha", 0.9))))
		_platform_layer.draw_rect(Rect2(local.position, Vector2(local.size.x, 2.0)), edge)


func _draw_frame() -> void:
	var size: Vector2 = get_frame_size()
	var w: float = float(_cfg.get("frame_px", 8))
	var rect := Rect2(Vector2.ZERO, size)
	_frame_layer.draw_rect(rect.grow(-w * 0.5), _c("frame_shadow", "marco_sombra"), false, w)
	_frame_layer.draw_rect(rect.grow(-w * 0.5 + 1.0), _c("frame", "dorado"), false, w - 2.0)
	_frame_layer.draw_rect(Rect2(Vector2(w, w), Vector2(size.x - 2.0 * w, 2.0)), _c("frame_light", "dorado_luz"))
	# Brillo diagonal del cristal (decorado).
	var shine: Color = Color(_c("shine", "blanco_brillante"), float(_cfg.get("shine_alpha", 0.18)))
	var x0: float = size.x * 0.2
	_frame_layer.draw_line(Vector2(x0, w + 4.0), Vector2(x0 - 24.0, size.y - w - 4.0), shine, 3.0)


func _on_player_respawned(_position: Vector2, _after_death: bool) -> void:
	if _buffer != null:
		_buffer.clear()
	_update_isak_sprite()


func _c(key: String, fallback: String) -> Color:
	return World3ObjectsConfig.color(String(_cfg.get(key, fallback)))
