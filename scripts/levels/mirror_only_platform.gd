## Plataforma del reflejo (tipo `mirror_only` del catalogo del Mundo 3; 2026-10-26,
## paso 4 de docs/propuesta-mundo-3.md §8, §3.4): SOLIDA siempre pero INVISIBLE en
## el mundo. Solo se dibuja en el reflejo de la pared de espejo (MirrorWall) mas
## cercana, en su posicion reflejada; el jugador lee el espejo para saber donde
## pisar. Con el Debug tambien se ve con contorno (regla general de lo oculto:
## el mismo dibujo que la plataforma oculta `h`, HiddenPlatform, de la que
## hereda; a diferencia de ella no deja de ser solida sin el Debug).
##
## width_tiles x height_px (seccion mirror_only de data/world3_objects.json; 32
## px, arriba de su celda, como las plataformas de likes); el grid deja sus
## celdas en '.'. one_way: de una via. El origen es la esquina superior
## izquierda de su primera celda.
class_name MirrorOnlyPlatform
extends HiddenPlatform

const MIRROR_ONLY_GROUP: StringName = &"mirror_only"

@export var object_id: StringName = &""
@export_range(1, 6) var width_tiles: int = 2


func _ready() -> void:
	var cfg: Dictionary = World3ObjectsConfig.section("mirror_only")
	size = Vector2(width_tiles * World3ObjectsConfig.tile_size(), float(cfg.get("height_px", 32)))
	add_to_group(MIRROR_ONLY_GROUP)
	super._ready()
	_shape.position = size * 0.5


## Rectangulo solido en coordenadas globales.
func get_rect() -> Rect2:
	return Rect2(global_position, size)


## Pared de espejo mas cercana (por el centro) en la que se dibuja; null si no hay.
func get_mirror_wall() -> MirrorWall:
	var best: MirrorWall = null
	var best_d: float = INF
	if not is_inside_tree():
		return null
	var center: Vector2 = get_rect().get_center()
	for node: Node in get_tree().get_nodes_in_group(MirrorWall.GROUP):
		var wall := node as MirrorWall
		if wall == null:
			continue
		var d: float = wall.get_frame_rect().get_center().distance_squared_to(center)
		if d < best_d:
			best_d = d
			best = wall
	return best


## Sin Debug no se ve en el mundo (solo en el reflejo).
func is_visible_in_world() -> bool:
	return is_shown()


func _update_solid(_revealing: bool) -> void:
	_shape.disabled = false


func _draw() -> void:
	if _drawn_intensity <= 0.0 or _drawn_blink_off:
		return
	var rect := Rect2(Vector2.ZERO, size)
	var color: Color = get_outline_color()
	draw_rect(rect, Color(color, _config.hidden_fill_alpha * _drawn_intensity))
	var halo: float = _config.hidden_halo_width_px
	if halo > 0.0:
		draw_rect(rect.grow(halo * 0.5), Color(_config.hidden_halo_color, _drawn_intensity), false, halo)
	var width: float = get_outline_width()
	draw_rect(rect.grow(-width * 0.5), Color(color, _drawn_intensity), false, width)
