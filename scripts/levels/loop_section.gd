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
@export var sign_text: String = "Solo uno más (llevas {n})"
@export var sign_width_tiles: int = 5

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
	var size := Vector2(float(sign_width_tiles) * t, t * 0.75)
	for copy: float in [0.0, period]:
		var rect := Rect2(Vector2(0.0, copy + t * 0.125), size)
		FeedCardDraw.card(self, rect)
		if _font != null:
			var px: int = int(_cfg.get("font_size", 16))
			var text: String = get_sign_text()
			var width: float = _font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, px).x
			var baseline := Vector2(rect.position.x + (rect.size.x - width) * 0.5,
					rect.position.y + (rect.size.y + _font.get_ascent(px)) * 0.5 - 2.0)
			draw_string(_font, baseline, text, HORIZONTAL_ALIGNMENT_LEFT, -1, px, World2ObjectsConfig.color("blanco"))
		if _hint_left > 0.0 and hint_rect.size() == 4:
			_draw_hint(_cells_rect(hint_rect), copy)


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
