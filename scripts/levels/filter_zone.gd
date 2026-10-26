## Filtro (tipo `filter_zone` del catalogo del Mundo 3; 2026-10-26, paso 3 de
## docs/propuesta-mundo-3.md §8, §3.2 y decision 5 de §9: el filtro engana, no
## mata).
## - Rectangulo de width_tiles x height_tiles con una CAPA rosada y suavizada
##   encima, borde de marco dorado y cartel (label_text, por instancia). Sin
##   colision. El borde y el cartel se ven siempre: la zona siempre se lee como zona.
## - Debajo, el nivel real: los pinchos '^' del grid dentro del filtro son
##   hidden_by_filter: tools/build_level.py no los pone en Tiles sino en el hijo
##   «HiddenSpikes» (TileMapLayer oculta que solo sirve de datos) y este nodo los
##   dibuja FUERA de la capa actual (lo que el filtro movil deja al descubierto) y,
##   con el Debug, tambien debajo y en rojo. Su Area de dano (Hazards, SpikeHazard)
##   quita 10 y empuja hacia la entrada (entry_side) sin matar.
## - Suelo falso (fake_floor_rects, solo en filtros fijos): hijo «Cover»
##   (TileMapLayer SIN colision, como el cover de GlitchWall) que dibuja terreno
##   donde el grid tiene un foso; con el Debug se desvanece a fake_floor_debug_alpha
##   y sale con contorno discontinuo.
## - Con el Debug la capa baja a debug_opacity (10 %) con la intensidad de revelado
##   (OverlayPopup.see_through_alpha, la misma regla del pop-up translucido del 1-2).
## - Filtro movil (positions, 2-3 esquinas en celdas; cycle_s, 4 s de tiempo del
##   mundo por sitio): se desliza ida y vuelta entre ellas en slide_s; antes, la
##   cinta del borde parpadea warn_frames cuadros a anim_fps (9 a 12 fps). Los
##   peligros no se mueven: se mueve lo que se ve.
## - Vineta que tiembla con Isak a <= tremble_radius_tiles de un peligro oculto (bajo
##   la capa actual): senal hazard_near_changed para el desafinado de la musica.
## Tiempo del mundo (el Debug lo ralentiza). Aspecto PROVISIONAL por codigo (seccion
## filter_zone de data/world3_objects.json, paleta provisional). El origen del nodo
## es la esquina superior izquierda de su primera celda (la de positions[0]).
class_name FilterZone
extends Node2D

const GROUP: StringName = &"filter_zone"

signal hazard_near_changed(near: bool)
signal slide_warning_started
signal slide_started(to_index: int)
signal slide_finished(index: int)

@export var object_id: StringName = &""
@export_range(2, 40) var width_tiles: int = 6
@export_range(2, 12) var height_tiles: int = 4
## Texto del cartel («Filtro: Orejitas · Brillo +40»).
@export var label_text: String = ""
## Lado por el que se entra: "left" (los pinchos empujan a la izquierda) o "right".
@export var entry_side: String = "left"
## Suelo falso: [[x, y, ancho, alto], ...] en celdas del nivel (lo dibuja el hijo Cover).
@export var fake_floor_rects: Array = []
## Filtro movil: esquinas superiores izquierdas en celdas del nivel (Vector2 o [x, y]);
## vacio o una sola = filtro fijo.
@export var positions: Array = []
## Segundos (tiempo del mundo) en cada sitio, deslizamiento incluido.
@export var cycle_s: float = 4.0

var _cfg: Dictionary = World3ObjectsConfig.section("filter_zone")
var _time: float = 0.0
var _cycle_time: float = 0.0
## Paso de la secuencia de ida y vuelta (indices de positions).
var _step: int = 0
var _sequence: Array[int] = [0]
var _cells: Array[Vector2] = []
var _warned: bool = false
var _sliding: bool = false
var _near: bool = false
var _proximity: float = 0.0
var _intensity: float = 0.0
var _layer: Node2D
var _revealed: Node2D
var _marks: Node2D
var _isak: Isak
var _font: Font


func _ready() -> void:
	add_to_group(GROUP)
	_cells = _normalized_positions()
	_sequence = _build_sequence(_cells.size())
	var hidden: TileMapLayer = get_hidden_spikes()
	if hidden != null:
		hidden.visible = false
		hidden.collision_enabled = false
	var cover: TileMapLayer = get_cover()
	if cover != null:
		cover.collision_enabled = false
	var font_path: String = String(_cfg.get("sign_font", ""))
	if not font_path.is_empty() and ResourceLoader.exists(font_path):
		_font = load(font_path) as Font
	# Orden de dibujo: Cover (suelo falso, bajo la capa) -> capa -> pinchos -> marcas.
	_layer = _canvas("Layer", _draw_layer)
	_revealed = _canvas("Revealed", _draw_revealed)
	_marks = _canvas("Marks", _draw_marks)
	advance(0.0)


func _physics_process(delta: float) -> void:
	advance(WorldTime.scaled_delta(delta))


# --- Consultas ---

func get_size_px() -> Vector2:
	var t: float = World3ObjectsConfig.tile_size()
	return Vector2(width_tiles * t, height_tiles * t)


func is_moving_filter() -> bool:
	return _cells.size() > 1


func get_position_count() -> int:
	return maxi(_cells.size(), 1)


## Indice (en positions) del sitio en el que esta o del que sale ahora.
func get_position_index() -> int:
	return _sequence[_step % _sequence.size()]


## Rectangulo local del filtro en el sitio `index` de positions.
func get_local_rect_at(index: int) -> Rect2:
	if _cells.is_empty():
		return Rect2(Vector2.ZERO, get_size_px())
	var t: float = World3ObjectsConfig.tile_size()
	return Rect2((_cells[clampi(index, 0, _cells.size() - 1)] - _cells[0]) * t, get_size_px())


## Rectangulo local que tapa ahora la capa (deslizandose, el intermedio).
func get_current_local_rect() -> Rect2:
	var from: Rect2 = get_local_rect_at(get_position_index())
	if not _sliding:
		return from
	var to: Rect2 = get_local_rect_at(_sequence[(_step + 1) % _sequence.size()])
	return Rect2(from.position.lerp(to.position, smoothstep(0.0, 1.0, get_slide_progress())), from.size)


func get_current_rect() -> Rect2:
	var local: Rect2 = get_current_local_rect()
	return Rect2(global_position + local.position, local.size)


## Rectangulo global que cubren todos sus sitios.
func get_union_rect() -> Rect2:
	var out: Rect2 = get_local_rect_at(0)
	for i: int in _cells.size():
		out = out.merge(get_local_rect_at(i))
	return Rect2(global_position + out.position, out.size)


## 0-1 dentro del deslizamiento (0 quieto).
func get_slide_progress() -> float:
	if not _sliding:
		return 0.0
	var slide: float = _slide_s()
	return clampf((_cycle_time - (cycle_s - slide)) / slide, 0.0, 1.0)


func is_sliding() -> bool:
	return _sliding


## Aviso antes de moverse: warn_frames cuadros a anim_fps (0,75 s).
func get_warn_s() -> float:
	return float(_cfg.get("warn_frames", 9)) / maxf(float(_cfg.get("anim_fps", 12.0)), 1.0)


func is_warning() -> bool:
	if not is_moving_filter() or _sliding:
		return false
	var hold_end: float = cycle_s - _slide_s()
	return _cycle_time >= hold_end - get_warn_s() and _cycle_time < hold_end


## Cuadro del aviso con la cinta encendida (uno de cada dos a anim_fps).
func is_tape_blink_on() -> bool:
	if not is_warning():
		return false
	var fps: float = maxf(float(_cfg.get("anim_fps", 12.0)), 1.0)
	var since: float = _cycle_time - (cycle_s - _slide_s() - get_warn_s())
	return int(floor(since * fps)) % 2 == 0


## -1 si se entra por la izquierda (los pinchos ocultos empujan hacia alli), 1 por la derecha.
func get_entry_direction() -> float:
	return 1.0 if entry_side == "right" else -1.0


## Opacidad de la capa rosada ahora (opacity sin Debug, debug_opacity con el Debug).
func get_layer_alpha() -> float:
	return OverlayPopup.see_through_alpha(float(_cfg.get("opacity", 0.6)), float(_cfg.get("debug_opacity", 0.1)),
			_intensity)


## Intensidad del revelado del Debug que usa (0-1).
func get_reveal_intensity() -> float:
	return _intensity


## Pinchos ocultos (celdas del nivel) que guarda el hijo HiddenSpikes.
func get_hidden_spike_cells() -> Array[Vector2i]:
	var layer: TileMapLayer = get_hidden_spikes()
	var out: Array[Vector2i] = []
	if layer != null:
		out.assign(layer.get_used_cells())
	return out


## Celdas del suelo falso (sin el anillo de bordes que dibuja Cover).
func get_fake_floor_cells() -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for rect: Variant in fake_floor_rects:
		var r: Array = rect as Array
		if r.size() != 4:
			continue
		for j: int in int(r[3]):
			for i: int in int(r[2]):
				out.append(Vector2i(int(r[0]) + i, int(r[1]) + j))
	return out


func get_hidden_spikes() -> TileMapLayer:
	return get_node_or_null(^"HiddenSpikes") as TileMapLayer


func get_cover() -> TileMapLayer:
	return get_node_or_null(^"Cover") as TileMapLayer


## Rectangulo global de una celda del nivel (las capas hijas van en coordenadas del nivel).
func get_cell_rect(cell: Vector2i) -> Rect2:
	var t: float = World3ObjectsConfig.tile_size()
	return Rect2(global_position + _level_offset() + Vector2(cell) * t, Vector2.ONE * t)


## La capa actual tapa (aunque sea en parte) esa celda.
func covers_cell(cell: Vector2i) -> bool:
	return get_current_rect().intersects(get_cell_rect(cell))


## El jugador ve lo que hay en la celda: fuera de la capa, o debajo con el Debug del todo.
func is_cell_revealed(cell: Vector2i) -> bool:
	return not covers_cell(cell) or _intensity >= 1.0


## Tinte de los pinchos ocultos (blanco sin Debug, rojo de dano con el Debug).
func get_spike_tint() -> Color:
	return Color.WHITE.lerp(_c("spike_debug", "alerta"), _intensity)


## Opacidad del suelo falso (1 sin Debug).
func get_fake_floor_alpha() -> float:
	return lerpf(1.0, float(_cfg.get("fake_floor_debug_alpha", 0.3)), _intensity)


## Isak a <= tremble_radius_tiles de un peligro oculto bajo la capa actual.
func is_trembling() -> bool:
	return _near


## 0 lejos, 1 encima (sube al acercarse; para el desafinado).
func get_hazard_proximity() -> float:
	return _proximity


## Desplazamiento de la vineta ahora (cero sin temblar).
func get_tremble_offset() -> Vector2:
	if not _near:
		return Vector2.ZERO
	var px: float = float(_cfg.get("tremble_px", 2))
	var phase: float = _time * float(_cfg.get("tremble_hz", 18.0)) * TAU
	var offset := Vector2(roundf(sin(phase) * px), roundf(cos(phase * 1.37) * px * 0.5))
	return offset if offset != Vector2.ZERO else Vector2(px, 0.0)


func get_label_text() -> String:
	return label_text


## Ayuda de Eco (cuando la tenga): siempre.
func is_help_available() -> bool:
	return true


# --- Acciones ---

## Avanza `dt` segundos de tiempo del mundo (publico para las pruebas).
func advance(dt: float) -> void:
	dt = maxf(dt, 0.0)
	_time += dt
	_intensity = DebugMode.get_reveal_intensity()
	if is_moving_filter():
		_advance_motion(dt)
	_update_proximity()
	var cover: TileMapLayer = get_cover()
	if cover != null:
		cover.modulate.a = get_fake_floor_alpha()
	if _layer != null:
		_layer.position = get_tremble_offset()
		_layer.queue_redraw()
		_revealed.queue_redraw()
		_marks.queue_redraw()


# --- Interno ---

func _advance_motion(dt: float) -> void:
	_cycle_time += dt
	var hold_end: float = cycle_s - _slide_s()
	while true:
		if not _warned and _cycle_time >= hold_end - get_warn_s():
			_warned = true
			slide_warning_started.emit()
		if not _sliding and _cycle_time >= hold_end:
			_sliding = true
			slide_started.emit(_sequence[(_step + 1) % _sequence.size()])
		if _cycle_time < cycle_s:
			break
		_cycle_time -= cycle_s
		_step = (_step + 1) % _sequence.size()
		_sliding = false
		_warned = false
		slide_finished.emit(get_position_index())


func _slide_s() -> float:
	return clampf(float(_cfg.get("slide_s", 0.5)), 0.01, maxf(cycle_s - get_warn_s() - 0.01, 0.01))


func _update_proximity() -> void:
	if _isak == null or not is_instance_valid(_isak):
		_isak = LevelLookup.find_isak(self)
	var near: bool = false
	var proximity: float = 0.0
	if _isak != null and _isak.is_inside_tree():
		var radius: float = float(_cfg.get("tremble_radius_tiles", 3)) * World3ObjectsConfig.tile_size()
		var body: Rect2 = LevelLookup.isak_body_rect(_isak)
		var best: float = INF
		for cell: Vector2i in get_hidden_spike_cells() + get_fake_floor_cells():
			if covers_cell(cell):
				best = minf(best, _rect_distance(body, get_cell_rect(cell)))
		if best <= radius:
			near = true
			proximity = 1.0 - best / maxf(radius, 1.0)
	_proximity = proximity
	if near != _near:
		_near = near
		hazard_near_changed.emit(near)


static func _rect_distance(a: Rect2, b: Rect2) -> float:
	var dx: float = maxf(0.0, maxf(b.position.x - a.end.x, a.position.x - b.end.x))
	var dy: float = maxf(0.0, maxf(b.position.y - a.end.y, a.position.y - b.end.y))
	return Vector2(dx, dy).length()


## Partes de `a` fuera de `b` (hasta 4 rectangulos).
static func subtract_rect(a: Rect2, b: Rect2) -> Array[Rect2]:
	var out: Array[Rect2] = []
	if not a.intersects(b):
		out.append(a)
		return out
	var i: Rect2 = a.intersection(b)
	var pieces: Array[Rect2] = [
		Rect2(a.position.x, a.position.y, a.size.x, i.position.y - a.position.y),
		Rect2(a.position.x, i.end.y, a.size.x, a.end.y - i.end.y),
		Rect2(a.position.x, i.position.y, i.position.x - a.position.x, i.size.y),
		Rect2(i.end.x, i.position.y, a.end.x - i.end.x, i.size.y),
	]
	for piece: Rect2 in pieces:
		if piece.size.x > 0.01 and piece.size.y > 0.01:
			out.append(piece)
	return out


func _level_offset() -> Vector2:
	var hidden: TileMapLayer = get_hidden_spikes()
	if hidden != null:
		return hidden.position
	var cover: TileMapLayer = get_cover()
	if cover != null:
		return cover.position
	# Sin capas hijas: el nodo cuelga de Objects, que esta en el origen del nivel.
	return -position


func _normalized_positions() -> Array[Vector2]:
	var out: Array[Vector2] = []
	for p: Variant in positions:
		if p is Vector2 or p is Vector2i:
			out.append(Vector2(p))
		elif p is Array and (p as Array).size() == 2:
			out.append(Vector2(float(p[0]), float(p[1])))
	return out


## Ida y vuelta: 0, 1, 2, 1, 0... (con dos sitios, 0, 1, 0...).
static func _build_sequence(count: int) -> Array[int]:
	var seq: Array[int] = []
	for i: int in maxi(count, 1):
		seq.append(i)
	for i: int in range(count - 2, 0, -1):
		seq.append(i)
	return seq


func _canvas(node_name: String, painter: Callable) -> Node2D:
	var node := Node2D.new()
	node.name = node_name
	add_child(node)
	node.draw.connect(painter.bind(node))
	return node


func _c(key: String, fallback: String) -> Color:
	return World3ObjectsConfig.color(String(_cfg.get(key, fallback)))


func _draw_layer(canvas: Node2D) -> void:
	var rect: Rect2 = get_current_local_rect()
	var alpha: float = get_layer_alpha()
	var base: float = maxf(float(_cfg.get("opacity", 0.6)), 0.01)
	canvas.draw_rect(rect, Color(_c("fill", "rosa_pastel"), alpha))
	# Suavizado: bandas claras hacia el borde (brillo de filtro de belleza).
	var steps: int = int(_cfg.get("glow_steps", 4))
	var glow_px: float = float(_cfg.get("glow_px", 6))
	var frame_px: float = float(_cfg.get("frame_px", 6))
	for i: int in steps:
		var band: Rect2 = rect.grow(-frame_px - glow_px * (i + 0.5))
		if band.size.x <= 0.0 or band.size.y <= 0.0:
			break
		var a: float = alpha / base * 0.16 * float(steps - i) / float(steps)
		canvas.draw_rect(band, Color(_c("glow", "blanco_brillante"), a), false, glow_px)
	# Marco y cinta: se ven siempre (la zona siempre se lee como zona).
	canvas.draw_rect(rect.grow(-frame_px * 0.5), _c("frame", "dorado"), false, frame_px)
	canvas.draw_rect(rect.grow(-1.0), _c("frame_light", "dorado_luz"), false, 2.0)
	var tape_px: float = float(_cfg.get("tape_px", 3))
	var tape: Color = _c("tape_warn", "blanco_brillante") if is_tape_blink_on() else _c("tape", "rosa_sombra")
	canvas.draw_rect(rect.grow(-frame_px - tape_px * 0.5), tape, false, tape_px)
	_draw_sign(canvas, rect, frame_px)


func _draw_sign(canvas: Node2D, rect: Rect2, frame_px: float) -> void:
	if label_text.is_empty() or _font == null:
		return
	var size_px: int = _font.get_fixed_size() if _font is FontFile and _font.get_fixed_size() > 0 else 12
	var pad: float = float(_cfg.get("sign_padding_px", 4))
	var text_size: Vector2 = _font.get_string_size(label_text, HORIZONTAL_ALIGNMENT_LEFT, -1, size_px)
	var box := Rect2(rect.position + Vector2(frame_px + 4.0, frame_px + 4.0),
			Vector2(minf(text_size.x + pad * 2.0, rect.size.x - frame_px * 2.0 - 8.0), _font.get_height(size_px) + pad * 2.0))
	canvas.draw_rect(box, Color(_c("sign_back", "galeria_noche"), 0.85))
	canvas.draw_rect(box, _c("frame", "dorado"), false, 1.0)
	canvas.draw_string(_font, box.position + Vector2(pad, pad + _font.get_ascent(size_px)), label_text,
			HORIZONTAL_ALIGNMENT_LEFT, box.size.x - pad * 2.0, size_px, _c("sign_text", "blanco_brillante"))


## Pinchos ocultos: lo que la capa no tapa, entero; lo tapado, solo con el Debug.
func _draw_revealed(canvas: Node2D) -> void:
	var layer: TileMapLayer = get_hidden_spikes()
	if layer == null or layer.tile_set == null:
		return
	var t: float = World3ObjectsConfig.tile_size()
	var cover: Rect2 = get_current_local_rect()
	var tint: Color = get_spike_tint()
	for cell: Vector2i in layer.get_used_cells():
		var source := layer.tile_set.get_source(layer.get_cell_source_id(cell)) as TileSetAtlasSource
		if source == null or source.texture == null:
			continue
		var region: Rect2 = source.get_tile_texture_region(layer.get_cell_atlas_coords(cell))
		var dest := Rect2(layer.position + Vector2(cell) * t, Vector2.ONE * t)
		var pieces: Array[Rect2] = subtract_rect(dest, cover)
		for piece: Rect2 in pieces:
			_draw_piece(canvas, source.texture, region, dest, piece, tint)
		if _intensity > 0.0 and dest.intersects(cover):
			_draw_piece(canvas, source.texture, region, dest, dest.intersection(cover), Color(tint, _intensity))


static func _draw_piece(canvas: Node2D, tex: Texture2D, region: Rect2, dest: Rect2, piece: Rect2, color: Color) -> void:
	var k: Vector2 = region.size / dest.size
	var src := Rect2(region.position + (piece.position - dest.position) * k, piece.size * k)
	canvas.draw_texture_rect_region(tex, piece, src, color)


## Con el Debug: contorno rojo de los pinchos tapados y discontinuo del suelo falso.
func _draw_marks(canvas: Node2D) -> void:
	if _intensity <= 0.0:
		return
	var t: float = World3ObjectsConfig.tile_size()
	var offset: Vector2 = _level_offset()
	var width: float = float(_cfg.get("outline_px", 2))
	var red := Color(_c("spike_debug", "alerta"), _intensity)
	for cell: Vector2i in get_hidden_spike_cells():
		if covers_cell(cell):
			canvas.draw_rect(Rect2(offset + Vector2(cell) * t, Vector2.ONE * t).grow(-width * 0.5), red, false, width)
	var green := Color(_c("fake_floor_debug", "debug_verde"), _intensity)
	for rect: Variant in fake_floor_rects:
		var r: Array = rect as Array
		if r.size() == 4:
			_dashed_rect(canvas, Rect2(offset + Vector2(float(r[0]), float(r[1])) * t,
					Vector2(float(r[2]), float(r[3])) * t).grow(-width * 0.5), green, width)


func _dashed_rect(canvas: Node2D, rect: Rect2, color: Color, width: float) -> void:
	var dash: float = float(_cfg.get("dash_px", 6))
	var step: float = dash + float(_cfg.get("gap_px", 6))
	var x: float = 0.0
	while x < rect.size.x:
		var w: float = minf(dash, rect.size.x - x)
		canvas.draw_rect(Rect2(rect.position.x + x, rect.position.y, w, width), color)
		canvas.draw_rect(Rect2(rect.position.x + x, rect.end.y - width, w, width), color)
		x += step
	var y: float = 0.0
	while y < rect.size.y:
		var h: float = minf(dash, rect.size.y - y)
		canvas.draw_rect(Rect2(rect.position.x, rect.position.y + y, width, h), color)
		canvas.draw_rect(Rect2(rect.end.x - width, rect.position.y + y, width, h), color)
		y += step
