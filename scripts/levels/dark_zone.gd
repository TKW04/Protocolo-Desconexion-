## Zona «Modo oscuro» (tipo `dark_zone` del catalogo del Mundo 4; 2026-10-28, paso 4 de
## docs/propuesta-mundo-4.md §8 y §3.6): rectangulo de width_tiles x height_tiles desde
## su celda con un VELO casi negro (chat_noche al veil_alpha; regla 5 de
## tools/palette_mundo4_provisional.py) por encima del mundo (z_index veil_z). Sin
## colision ni dano.
## - Con la Linterna conocida (GameState.has_met_ally("linterna")) y el cuerpo de Isak
##   dentro, el velo abre un CIRCULO DE LUZ de light_radius_tiles (3) alrededor de Isak
##   (shader del velo: hole_center / hole_radius, borde suave hole_soft_px). Sin
##   Linterna (no pasa en el Mundo 4) la zona se recorre igual, a oscuras.
## - Legibilidad (la exige el validador): por encima del velo siempre se ven el
##   contorno de lo que dana (los pinchos: alerta desde el paso 22, dibujado por la capa
##   Outlines), los puntos del «escribiendo…» y el borde de las burbujas al 30 %
##   (ChatBubble crea su DarkOutline) y los checks del «Visto» (SeenZone sube su
##   z_index). Lo que la Linterna anade es el texto, el largo exacto y lo escrito «en
##   tinta» (InkOnly: solo bajo su luz).
## Estatica: DarkZone.covering(tree, punto) y DarkZone.lit_by_flashlight(tree, punto)
## para quien necesite saber si un punto esta a oscuras o bajo la luz. Aspecto
## PROVISIONAL por codigo (seccion dark_zone de data/world4_objects.json). El origen es
## la esquina superior izquierda de su celda.
class_name DarkZone
extends Node2D

const GROUP: StringName = &"dark_zone"
const VEIL_SHADER: String = """
shader_type canvas_item;
uniform vec4 veil_color : source_color = vec4(0.06, 0.08, 0.13, 0.6);
uniform vec2 rect_size = vec2(64.0, 64.0);
uniform vec2 hole_center = vec2(0.0, 0.0);
uniform float hole_radius = 0.0;
uniform float hole_soft = 16.0;
void fragment() {
	vec2 p = UV * rect_size;
	float a = veil_color.a;
	if (hole_radius > 0.0) {
		float d = distance(p, hole_center);
		a *= smoothstep(hole_radius - hole_soft, hole_radius, d);
	}
	COLOR = vec4(veil_color.rgb, a);
}
"""

## Isak entra o sale de la zona (la Linterna se enciende o apaga).
signal isak_inside_changed(inside: bool)

@export var object_id: StringName = &""
@export var width_tiles: int = 8
@export var height_tiles: int = 4
## Si es false, _process no avanza (las pruebas llaman a refresh()).
var auto_process: bool = true
## Isak (si es null se busca con LevelLookup).
var isak: Isak

var _cfg: Dictionary = World4ObjectsConfig.section("dark_zone")
var _veil: ColorRect
var _material: ShaderMaterial
var _outlines: Node2D
var _inside: bool = false
var _hole_on: bool = false


## La zona oscura que cubre el punto global `point` (null si ninguna).
static func covering(tree: SceneTree, point: Vector2) -> DarkZone:
	if tree == null:
		return null
	for node: Node in tree.get_nodes_in_group(GROUP):
		var zone := node as DarkZone
		if zone != null and zone.get_zone_rect().has_point(point):
			return zone
	return null


## Verdadero si el punto global `point` esta bajo la luz de la Linterna (en una zona
## oscura con el circulo abierto y a <= su radio de Isak).
static func lit_by_flashlight(tree: SceneTree, point: Vector2) -> bool:
	var zone: DarkZone = covering(tree, point)
	return zone != null and zone.is_lit_at(point)


## Z del velo (lo de encima: contornos, checks, puntos, tinta).
static func veil_z() -> int:
	return int(World4ObjectsConfig.section("dark_zone").get("veil_z", 40))


func _ready() -> void:
	add_to_group(GROUP)
	var size: Vector2 = get_zone_rect().size
	_material = ShaderMaterial.new()
	var shader := Shader.new()
	shader.code = VEIL_SHADER
	_material.shader = shader
	_veil = ColorRect.new()
	_veil.name = "Veil"
	_veil.size = size
	_veil.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_veil.material = _material
	_veil.z_as_relative = false
	_veil.z_index = veil_z()
	add_child(_veil)
	var veil_color: Color = World4ObjectsConfig.color("chat_noche", Color("#0f1422"))
	veil_color.a = get_veil_alpha()
	_material.set_shader_parameter("veil_color", veil_color)
	_material.set_shader_parameter("rect_size", size)
	_material.set_shader_parameter("hole_soft", float(_cfg.get("hole_soft_px", 16)))
	_outlines = _DarkOutlines.new()
	_outlines.name = "Outlines"
	(_outlines as _DarkOutlines).zone = self
	_outlines.z_as_relative = false
	_outlines.z_index = veil_z() + 1
	add_child(_outlines)
	refresh()


func _process(_delta: float) -> void:
	if auto_process:
		refresh()


## Recalcula si Isak esta dentro y el circulo de luz. Publico para las pruebas.
func refresh() -> void:
	if isak == null or not is_instance_valid(isak) or not isak.is_inside_tree():
		isak = LevelLookup.find_isak(self)
	var inside: bool = isak != null and not isak.is_dead() \
			and LevelLookup.isak_body_rect(isak).intersects(get_zone_rect())
	if inside != _inside:
		_inside = inside
		isak_inside_changed.emit(inside)
	_hole_on = inside and has_flashlight()
	if _material != null:
		if _hole_on:
			_material.set_shader_parameter("hole_center", get_light_center() - global_position)
			_material.set_shader_parameter("hole_radius", get_light_radius())
		else:
			_material.set_shader_parameter("hole_radius", 0.0)
	if _outlines != null:
		_outlines.queue_redraw()


# --- Consultas ---

func get_zone_rect() -> Rect2:
	var t: float = World4ObjectsConfig.tile_size()
	return Rect2(global_position, Vector2(float(width_tiles) * t, float(height_tiles) * t))


func get_veil_alpha() -> float:
	return float(_cfg.get("veil_alpha", 0.6))


## La Linterna esta conocida (aliada de registro).
func has_flashlight() -> bool:
	return GameState.has_met_ally(GameState.ALLY_LINTERNA)


func is_isak_inside() -> bool:
	return _inside


## El circulo de luz esta abierto (Isak dentro con la Linterna).
func is_hole_open() -> bool:
	return _hole_on


## Radio de la luz: light_radius_tiles (3) tiles.
func get_light_radius() -> float:
	return float(_cfg.get("light_radius_tiles", 3.0)) * World4ObjectsConfig.tile_size()


## Centro de la luz (global): el centro del cuerpo de Isak.
func get_light_center() -> Vector2:
	if isak == null:
		return global_position
	return LevelLookup.isak_body_rect(isak).get_center()


## El punto global esta bajo la luz de la Linterna.
func is_lit_at(point: Vector2) -> bool:
	return _hole_on and point.distance_to(get_light_center()) <= get_light_radius()


func is_help_available() -> bool:
	return true


## Contornos de lo que dana dentro de la zona (rectangulos globales de los pinchos).
func get_hazard_rects() -> Array[Rect2]:
	var out: Array[Rect2] = []
	if not is_inside_tree():
		return out
	var zone: Rect2 = get_zone_rect()
	for node: Node in get_tree().get_nodes_in_group(SpikeHazard.GROUP):
		var area := node as Area2D
		if area == null:
			continue
		for child: Node in area.get_children():
			var shape_node := child as CollisionShape2D
			if shape_node == null or not (shape_node.shape is RectangleShape2D):
				continue
			var size: Vector2 = (shape_node.shape as RectangleShape2D).size
			var rect := Rect2(shape_node.global_position - size * 0.5, size)
			if rect.intersects(zone):
				out.append(rect)
	return out


## Color del contorno de lo que dana por encima del velo: `alerta` (2026-10-28,
## paso 22: con alerta_sombra quedaba a 1,6:1 sobre el velo en las capturas; la
## regla 5 de tools/palette_mundo4_provisional.py ya media el 3:1 con alerta).
func get_hazard_outline_color() -> Color:
	return World4ObjectsConfig.color(String(_cfg.get("hazard_outline_color", "alerta")), Color("#ff4a2a"))


## Capa por encima del velo: contorno de lo que dana (alerta), siempre visible.
class _DarkOutlines:
	extends Node2D
	var zone: DarkZone

	func _draw() -> void:
		if zone == null:
			return
		var color: Color = zone.get_hazard_outline_color()
		var width: float = float(zone._cfg.get("hazard_outline_px", 2.0))
		for rect: Rect2 in zone.get_hazard_rects():
			draw_rect(Rect2(rect.position - zone.global_position, rect.size), color, false, width)
