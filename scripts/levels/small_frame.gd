## Marco pequeno (tipo `small_frame` del catalogo del Mundo 3; 2026-10-26, paso 7
## de docs/propuesta-mundo-3.md §8 y §3.3.2). Ajustes en la seccion small_frame de
## data/world3_objects.json.
##
## SOLO DECORADO, como DecorSprite (`decor`): el hueco de 1 tile de alto es del
## grid ('.'); este nodo dibuja un marco de foto dorado alrededor de sus celdas
## para que se lea como «marco pequeno» (y la Q lo explique, mas adelante: help_id
## previsto small_frame). Sin colision, sin estado y sin efecto en el validador.
## orientation: wall (paso horizontal por una pared: length_tiles celdas hacia la
## derecha) o floor / ceiling (paso vertical por un suelo o un techo: length_tiles
## celdas hacia abajo). El marco se dibuja FUERA del hueco (sobre el terreno de
## alrededor) para no tapar a Isak al pasar. Aspecto PROVISIONAL por codigo.
## El origen es la esquina superior izquierda de su primera celda.
class_name SmallFrame
extends Node2D

const GROUP: StringName = &"small_frame"
const WALL: String = "wall"
const FLOOR: String = "floor"
const CEILING: String = "ceiling"

@export var object_id: StringName = &""
## wall, floor o ceiling.
@export var orientation: String = WALL
## Grosor de la pared o del suelo que atraviesa (celdas del hueco).
@export_range(1, 4) var length_tiles: int = 1

var _config: Dictionary = World3ObjectsConfig.section("small_frame")


func _ready() -> void:
	add_to_group(GROUP)
	z_index = int(_config.get("z_index", 1))
	queue_redraw()


## Paso vertical (suelo o techo) en vez de horizontal (pared).
func is_vertical() -> bool:
	return orientation == FLOOR or orientation == CEILING


## Rectangulo del hueco en coordenadas locales (px).
func get_hole_rect() -> Rect2:
	var t: float = World3ObjectsConfig.tile_size()
	var n: float = float(maxi(length_tiles, 1))
	return Rect2(Vector2.ZERO, Vector2(t, n * t) if is_vertical() else Vector2(n * t, t))


## Ayuda de Eco (HelpCatalog.is_help_live): el marco siempre explica.
func is_help_available() -> bool:
	return true


func _col(key: String, fallback: String) -> Color:
	return World3ObjectsConfig.color(String(_config.get(key, fallback)))


func _draw() -> void:
	var hole: Rect2 = get_hole_rect()
	var b: float = float(_config.get("border_px", 10))
	var lip: float = float(_config.get("lip_px", 4))
	var corner: float = float(_config.get("corner_px", 6))
	var frame: Color = _col("frame", "dorado")
	var light: Color = _col("frame_light", "dorado_luz")
	var shadow: Color = _col("frame_shadow", "marco_sombra")
	# Dos listones a lo largo del paso (encima y debajo en una pared; a los lados
	# en un suelo) y dos remates finos en sus extremos abiertos.
	var bars: Array[Rect2] = []
	if is_vertical():
		bars = [Rect2(hole.position.x - b, hole.position.y - lip, b, hole.size.y + lip * 2.0),
			Rect2(hole.end.x, hole.position.y - lip, b, hole.size.y + lip * 2.0)]
	else:
		bars = [Rect2(hole.position.x - lip, hole.position.y - b, hole.size.x + lip * 2.0, b),
			Rect2(hole.position.x - lip, hole.end.y, hole.size.x + lip * 2.0, b)]
	for bar: Rect2 in bars:
		draw_rect(bar, frame)
		draw_rect(bar, shadow, false, 1.0)
		# Filo de luz del lado del hueco.
		if is_vertical():
			var x: float = bar.end.x - 2.0 if bar.position.x < hole.position.x else bar.position.x
			draw_rect(Rect2(x, bar.position.y, 2.0, bar.size.y), light)
		else:
			var y: float = bar.end.y - 2.0 if bar.position.y < hole.position.y else bar.position.y
			draw_rect(Rect2(bar.position.x, y, bar.size.x, 2.0), light)
	# Remates de los extremos (las «esquinas» del marco de foto).
	var ends: Array[Vector2] = []
	if is_vertical():
		ends = [Vector2(hole.position.x - b, hole.position.y - lip), Vector2(hole.end.x + b - corner, hole.position.y - lip),
			Vector2(hole.position.x - b, hole.end.y + lip - corner), Vector2(hole.end.x + b - corner, hole.end.y + lip - corner)]
	else:
		ends = [Vector2(hole.position.x - lip, hole.position.y - b), Vector2(hole.end.x + lip - corner, hole.position.y - b),
			Vector2(hole.position.x - lip, hole.end.y + b - corner), Vector2(hole.end.x + lip - corner, hole.end.y + b - corner)]
	for p: Vector2 in ends:
		draw_rect(Rect2(p, Vector2(corner, corner)), _col("corner", "dorado_luz"))
