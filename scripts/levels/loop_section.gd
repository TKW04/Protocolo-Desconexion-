## Seccion en bucle del Mundo 2 (tipo `loop_section` del catalogo del Mundo 2;
## 2026-10-22, paso 5 de docs/propuesta-mundo-2.md §8, §3.5): «el nivel parece
## repetirse hasta encontrar el atajo, que solo se ve con el Debug».
##
## - band_rows = [fila de arriba, fila de abajo] de la banda (H = abajo - arriba).
##   Con el scroll forzado, cuando el borde de arriba de la camara llega a la fila
##   de arriba de la banda y Isak no ha encontrado la salida, la camara (scroll),
##   Isak y Eco bajan H filas JUNTOS: se ve lo mismo, porque el nivel repite su
##   contenido con periodo H justo debajo de la banda (el esquema lo exige). Lo
##   que esta en la banda (tarjetas fragiles...) vuelve a su estado inicial.
## - exit_rect = [columna, fila, ancho, alto]: la salida (p. ej. tarjetas `h` que
##   solo se ven con el Debug). Con los pies de Isak dentro, el bucle queda
##   resuelto y ya no se repite (hasta que Isak reaparezca).
## - Cartel «Solo uno mas (llevas N)» (sign_text, {n} = veces vistas) en la celda
##   del objeto y en su copia H filas mas abajo; NUNCA dice «vuelta». En la segunda
##   repeticion, hint_rect parpadea con glitch hint_s.
## - PISTA CLARA DE LA SALIDA (2026-10-23, arreglo tras la prueba del usuario:
##   «hay que ser mas especificos de que tienes que subir antes de que se
##   reinicie»): el cartel lleva una segunda linea con QUE hacer (sign_hint, p. ej.
##   «Sube por la derecha antes de que se repita») y una barra que se llena
##   hasta la repeticion (get_repeat_progress: 0 justo tras repetirse, 1 al
##   repetirse); y, mientras no se resuelva, una marca fija sobre hint_rect
##   o marker_rect (esquinas en debug_ambar, flecha hacia marker_dir y placa marker_text, p. ej.
##   «Mantén K y sube por aquí»). Los textos admiten {tecla:<accion>} (tecla del
##   Input Map). Todo se dibuja tambien en la copia H filas mas abajo, como el
##   cartel: el contenido de la banda es periodico.
## - Cada repeticion: senal wrapped y EventBus.loop_wrapped (el reloj del HUD salta
##   +1 h; paso 8). Repetir no dana ni gasta nada.
## - Al reaparecer Isak (EventBus.player_respawned) vuelve a empezar (sin resolver).
## Aspecto PROVISIONAL por codigo (seccion loop_section de data/world2_objects.json).
## El origen del nodo es la esquina superior izquierda de la celda del cartel.
class_name LoopSection
extends Node2D

const GROUP: StringName = &"loop_section"

## La banda se repite (`count` = repeticiones hasta ahora).
signal wrapped(count: int)
## Isak ha encontrado la salida.
signal solved

@export var object_id: StringName = &""
@export var band_rows: Array = [0, 12]
@export var exit_rect: Array = [0, 0, 1, 1]
@export var hint_rect: Array = []
## Celdas de la marca de la salida ([] = hint_rect).
@export var marker_rect: Array = []
@export var sign_text: String = "Solo uno más (llevas {n})"
@export var sign_width_tiles: int = 5
## Segunda linea del cartel: que hacer antes de que se repita ("" = sin ella).
@export var sign_hint: String = ""
## Placa de la marca sobre hint_rect ("" = sin marca) y direccion de su flecha.
@export var marker_text: String = ""
@export_enum("up", "down") var marker_dir: String = "up"

var _cfg: Dictionary = World2ObjectsConfig.section("loop_section")
var _count: int = 0
var _solved: bool = false
var _hint_left: float = 0.0
var _time: float = 0.0
var _isak: Isak
var _font: Font


func _ready() -> void:
	add_to_group(GROUP)
	z_index = int(_cfg.get("z_index", -1))
	_font = load(String(_cfg.get("font", "res://assets/sprites/ui/text_font.fnt"))) as Font
	EventBus.player_respawned.connect(_on_player_respawned)


func _physics_process(delta: float) -> void:
	step(delta)


## Un paso (tiempo real; el scroll ya va en tiempo del mundo). Publico para las pruebas.
func step(delta: float) -> void:
	_time += delta
	if _hint_left > 0.0:
		_hint_left = maxf(_hint_left - delta, 0.0)
	queue_redraw()
	if _solved:
		return
	var isak: Isak = _find_isak()
	if isak == null or isak.is_dead() or isak.is_warping():
		return
	if is_in_exit(isak.global_position):
		_solved = true
		solved.emit()
		return
	var camera: ScrollCamera = isak.get_scroll_camera()
	if camera == null or camera.get_top() > get_band_top_px():
		return
	_wrap(isak, camera)


# --- Consultas ---

func get_count() -> int:
	return _count


func is_solved() -> bool:
	return _solved


## Filas que baja todo al repetirse (H).
func get_period_rows() -> int:
	return int(band_rows[1]) - int(band_rows[0])


func get_band_top_px() -> float:
	return float(band_rows[0]) * _tile()


## Los pies `feet` estan en la salida.
func is_in_exit(feet: Vector2) -> bool:
	return _cells_rect(exit_rect).has_point(feet - Vector2(0.0, 1.0))


## Texto del cartel ahora («Solo uno mas (llevas N)»: N = veces vistas).
func get_sign_text() -> String:
	return sign_text.replace("{n}", str(_count + 1))


## Segunda linea del cartel, con la tecla del Input Map.
func get_sign_hint() -> String:
	return TextMarkers.apply_keys(sign_hint)


## Placa de la marca de la salida, con la tecla del Input Map.
func get_marker_text() -> String:
	return TextMarkers.apply_keys(marker_text)


## La marca de la salida se ve (sin resolver, con hint_rect y texto).
func is_marker_visible() -> bool:
	return not _solved and _marker_cells().size() == 4 and not marker_text.is_empty()


func _marker_cells() -> Array:
	return marker_rect if marker_rect.size() == 4 else hint_rect


## Cuanto falta para que se repita: 0 justo tras repetirse (o lejos), 1 al
## repetirse (el borde de arriba de la camara llega a la banda).
func get_repeat_progress() -> float:
	if _solved:
		return 0.0
	var isak: Isak = _find_isak()
	var camera: ScrollCamera = isak.get_scroll_camera() if isak != null else null
	if camera == null:
		return 0.0
	var span: float = float(get_period_rows()) * _tile()
	return clampf(1.0 - (camera.get_top() - get_band_top_px()) / span, 0.0, 1.0)


func is_hint_visible() -> bool:
	return _hint_left > 0.0


## Ayuda de Eco: mientras no se ha resuelto.
func is_help_available() -> bool:
	return not _solved


# --- Acciones ---

## Vuelve a empezar (sin resolver, sin repeticiones).
func reset() -> void:
	_count = 0
	_solved = false
	_hint_left = 0.0
	queue_redraw()


# --- Interno ---

func _wrap(isak: Isak, camera: ScrollCamera) -> void:
	var dy: float = float(get_period_rows()) * _tile()
	camera.shift(dy)
	isak.global_position.y += dy
	isak.snap_camera()
	var level: Node = isak.get_parent()
	if level != null:
		for node: Node in level.get_children():
			if node is EcoCompanion and (node as EcoCompanion).get_isak() == isak:
				(node as EcoCompanion).shift_by(Vector2(0.0, dy))
	_reset_band_objects()
	_count += 1
	if _count >= int(_cfg.get("hint_from_repeat", 2)) and hint_rect.size() == 4:
		_hint_left = float(_cfg.get("hint_s", 0.5))
	wrapped.emit(_count)
	EventBus.loop_wrapped.emit(object_id, _count)


## Lo que esta en la banda (o en su copia de abajo) y sabe volver a su estado
## inicial: objetos (reset) y enemigos (reset_patrol) del nivel.
func _reset_band_objects() -> void:
	var holder: Node = get_parent()
	var level: Node = holder.get_parent() if holder != null else null
	if level == null:
		return
	var top: float = get_band_top_px()
	var bottom: float = (float(band_rows[1]) + ceilf(720.0 / _tile()) + 1.0) * _tile()
	for group_name: String in ["Objects", "Enemies"]:
		var group: Node = level.get_node_or_null(NodePath(group_name))
		if group == null:
			continue
		for node: Node in group.get_children():
			if node == self or not node is Node2D:
				continue
			var y: float = (node as Node2D).global_position.y
			if y < top or y >= bottom:
				continue
			if node.has_method(&"reset"):
				node.call(&"reset")
			elif node.has_method(&"reset_patrol"):
				node.call(&"reset_patrol")


func _find_isak() -> Isak:
	if _isak == null or not is_instance_valid(_isak):
		_isak = LevelLookup.find_isak(self)
	return _isak


func _tile() -> float:
	return World2ObjectsConfig.tile_size()


func _cells_rect(cells: Array) -> Rect2:
	if cells.size() != 4:
		return Rect2()
	var t: float = _tile()
	return Rect2(float(cells[0]) * t, float(cells[1]) * t, float(cells[2]) * t, float(cells[3]) * t)


func _on_player_respawned(_at: Vector2, _after_death: bool) -> void:
	reset()


func _draw() -> void:
	var t: float = _tile()
	var period: float = float(get_period_rows()) * t
	var px: int = int(_cfg.get("font_size", 16))
	var hint: String = get_sign_hint()
	# Con la segunda linea y la barra el cartel crece hacia arriba: su borde de
	# abajo no se mueve (no tapa la tarjeta de debajo).
	var extra: float = 0.0 if hint.is_empty() else float(_cfg.get("hint_line_px", 18)) + float(_cfg.get("bar_px", 6)) + 8.0
	var size := Vector2(float(sign_width_tiles) * t, t * 0.75 + extra)
	if _font != null:
		# El cartel crece a lo ancho (centrado) si una linea no cabe.
		for line: String in [get_sign_text(), hint]:
			size.x = maxf(size.x, _font.get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1, px).x + 24.0)
	var shift_x: float = (float(sign_width_tiles) * t - size.x) * 0.5
	var progress: float = get_repeat_progress()
	for copy: float in [0.0, period]:
		var rect := Rect2(Vector2(shift_x, copy + t * 0.125 - extra), size)
		FeedCardDraw.card(self, rect)
		if _font != null:
			var lines: PackedStringArray = [get_sign_text()]
			if not hint.is_empty():
				lines.append(hint)
			var line_h: float = float(_cfg.get("hint_line_px", 18))
			var top: float = rect.position.y + (t * 0.75 - _font.get_ascent(px)) * 0.5 + _font.get_ascent(px) - 2.0
			for i: int in lines.size():
				var width: float = _font.get_string_size(lines[i], HORIZONTAL_ALIGNMENT_LEFT, -1, px).x
				var color: Color = World2ObjectsConfig.color("blanco") if i == 0 else World2ObjectsConfig.color("debug_ambar")
				draw_string(_font, Vector2(rect.position.x + (rect.size.x - width) * 0.5, top + line_h * float(i)),
						lines[i], HORIZONTAL_ALIGNMENT_LEFT, -1, px, color)
		if not hint.is_empty():
			_draw_bar(Rect2(rect.position.x + 12.0, rect.end.y - float(_cfg.get("bar_px", 6)) - 8.0,
					rect.size.x - 24.0, float(_cfg.get("bar_px", 6))), progress)
		if is_marker_visible():
			_draw_marker(_cells_rect(_marker_cells()), copy, px)
		if _hint_left > 0.0 and hint_rect.size() == 4:
			_draw_hint(_cells_rect(hint_rect), copy)


## Barra «hasta que se repita»: se llena en ambar y en el ultimo cuarto parpadea
## en rojo de alerta.
func _draw_bar(rect: Rect2, progress: float) -> void:
	draw_rect(rect, World2ObjectsConfig.color("feed_noche"))
	var fill: Color = World2ObjectsConfig.color("debug_ambar")
	if progress >= float(_cfg.get("bar_warn_from", 0.75)) and fmod(_time * 4.0, 1.0) < 0.5:
		fill = World2ObjectsConfig.color("alerta")
	if progress > 0.0:
		draw_rect(Rect2(rect.position, Vector2(rect.size.x * progress, rect.size.y)), fill)
	draw_rect(rect, World2ObjectsConfig.color("tarjeta_borde"), false, 1.0)


## Marca de la salida: esquinas sobre hint_rect, flecha hacia marker_dir y placa
## con marker_text encima (dentro del nivel).
func _draw_marker(cells: Rect2, copy: float, px: int) -> void:
	var amber: Color = World2ObjectsConfig.color("debug_ambar")
	var dark: Color = World2ObjectsConfig.color("feed_noche")
	var rect := Rect2(cells.position - global_position + Vector2(0.0, copy), cells.size).grow(4.0)
	var arm: float = 14.0
	for corner: Vector2 in [rect.position, Vector2(rect.end.x, rect.position.y), Vector2(rect.position.x, rect.end.y), rect.end]:
		var sx: float = 1.0 if corner.x == rect.position.x else -1.0
		var sy: float = 1.0 if corner.y == rect.position.y else -1.0
		draw_rect(Rect2(Vector2(minf(corner.x, corner.x + sx * arm), corner.y - (0.0 if sy > 0.0 else 3.0)), Vector2(arm, 3.0)), amber)
		draw_rect(Rect2(Vector2(corner.x - (0.0 if sx > 0.0 else 3.0), minf(corner.y, corner.y + sy * arm)), Vector2(3.0, arm)), amber)
	var bob: float = roundf(sin(_time * TAU * 1.2) * 2.0)
	var cx: float = rect.get_center().x
	var up: bool = marker_dir != "down"
	var h: float = 16.0
	# Hacia arriba: una flecha justo encima de las celdas y la placa encima.
	# Hacia abajo (un suelo): dos flechas en los extremos, justo encima del suelo
	# (Isak de pie en el centro no las tapa), y la placa a la derecha, a la
	# altura de las flechas (encima puede haber otra tarjeta).
	var arrow_y: float = rect.position.y - 6.0 + bob
	var xs: PackedFloat32Array = PackedFloat32Array([cx]) if up else PackedFloat32Array([rect.position.x + 18.0, rect.end.x - 18.0])
	for x: float in xs:
		var points: PackedVector2Array
		if up:
			points = [Vector2(x, arrow_y - h), Vector2(x + 12.0, arrow_y), Vector2(x - 12.0, arrow_y)]
		else:
			points = [Vector2(x, arrow_y), Vector2(x + 12.0, arrow_y - h), Vector2(x - 12.0, arrow_y - h)]
		# Contorno oscuro de 3 px (se lee sobre tarjetas y fondo).
		var center := Vector2(x, arrow_y - h * 0.5)
		var outline: PackedVector2Array = []
		for p: Vector2 in points:
			outline.append(p + (p - center).normalized() * 3.0)
		draw_colored_polygon(outline, dark)
		draw_colored_polygon(points, amber)
	var plate_bottom: float = arrow_y - h - 6.0 if up else arrow_y + 4.0
	if _font == null:
		return
	var text: String = get_marker_text()
	var width: float = _font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, px).x
	var plate := Rect2(cx - width * 0.5 - 8.0 if up else rect.end.x + 8.0, plate_bottom - 24.0, width + 16.0, 24.0)
	var level_w: float = float(_cfg.get("level_width_px", 1280.0))
	var left: float = -global_position.x + _tile()
	var right: float = level_w - global_position.x - _tile()
	plate.position.x = clampf(plate.position.x, left, maxf(left, right - plate.size.x))
	draw_rect(plate, dark)
	draw_rect(plate, amber, false, 2.0)
	draw_string(_font, Vector2(plate.position.x + 8.0, plate.position.y + (plate.size.y + _font.get_ascent(px)) * 0.5 - 2.0),
			text, HORIZONTAL_ALIGNMENT_LEFT, -1, px, World2ObjectsConfig.color("blanco"))


## Glitch de la pista: barras horizontales que saltan sobre la salida.
func _draw_hint(cells: Rect2, copy: float) -> void:
	var rect := Rect2(cells.position - global_position + Vector2(0.0, copy), cells.size)
	var colors: Array[Color] = [World2ObjectsConfig.color("debug_ambar"), World2ObjectsConfig.color("magenta"),
		World2ObjectsConfig.color("blanco")]
	var bars: int = 6
	for i: int in bars:
		var k: int = int(floorf(_time * 30.0)) + i * 7
		var y: float = rect.position.y + rect.size.y * float((k * 37) % 97) / 97.0
		var w: float = rect.size.x * (0.3 + 0.7 * float((k * 53) % 89) / 89.0)
		var x: float = rect.position.x + (rect.size.x - w) * float((k * 29) % 83) / 83.0
		draw_rect(Rect2(x, y, w, 4.0), Color(colors[i % colors.size()], 0.8))
