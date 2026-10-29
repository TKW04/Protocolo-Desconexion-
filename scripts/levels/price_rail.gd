## Ranura de precios (tipo `price_rail` del catalogo del Mundo 5; 2026-10-29, paso 6
## de docs/propuesta-mundo-5.md §8, §3.7, §3.9 y patron 26). Ajustes en la seccion
## price_rail de data/world5_objects.json.
##
## Hilera de etiquetas de precio colgadas sobre un foso de width_tiles (4) tiles que
## llena height_tiles filas desde su celda MENOS una ranura de 1 tile de alto (la fila
## slot_row, contando desde arriba). Las etiquetas no son solidas ni danan: Isak cuyo
## cuerpo (LevelLookup.isak_body_rect) toca una etiqueta sale EMPUJADO hacia atras
## (al borde de la hilera por el lado por donde llego, a push_speed_px_s hacia fuera;
## corta el dash y los combos). De pie no cabe por la ranura (80 px > 64); comprimido
## si (40 px), pero el salto comprimido no cruza el foso y en la ranura no hay suelo:
## solo un FILO (dash comprimido de 4 tiles con gravedad 0) la cruza. Las etiquetas se
## apartan inset_px de cada borde para que un Filo que empieza al borde del foso las
## deje atras (4 tiles - 2 x 32 = 192 px de hilera). El pulso, el laser, el golpe al
## suelo y los combos no le hacen nada. Tiempo del mundo (solo el balanceo).
## El origen es la esquina superior izquierda de su primera celda. Aspecto PROVISIONAL.
class_name PriceRail
extends Node2D

const GROUP: StringName = &"price_rail"

## Ha empujado a Isak hacia `direction` (-1 izquierda, +1 derecha).
signal pushed(direction: float)

@export var object_id: StringName = &""
@export var width_tiles: int = 4:
	set(value):
		width_tiles = clampi(value, 1, 8)
		queue_redraw()
@export var height_tiles: int = 4:
	set(value):
		height_tiles = clampi(value, 2, 10)
		queue_redraw()
## Fila de la ranura desde arriba (0 .. height_tiles - 1).
@export var slot_row: int = 2:
	set(value):
		slot_row = maxi(value, 0)
		queue_redraw()

var _cfg: Dictionary = {}
var _time: float = 0.0
## Lado por el que estaba Isak la ultima vez que no tocaba las etiquetas (-1 / +1).
var _side: float = -1.0
var _bump_left: float = 0.0


func _ready() -> void:
	_cfg = World5ObjectsConfig.section("price_rail")
	add_to_group(GROUP)


func _physics_process(delta: float) -> void:
	_time += WorldTime.scaled_delta(delta)
	_bump_left = maxf(_bump_left - delta, 0.0)
	var isak: Isak = LevelLookup.find_isak(self)
	if isak != null:
		check_isak(isak)
	queue_redraw()


# --- Consultas ---

func get_tile() -> float:
	return World5ObjectsConfig.tile_size()


## Toda la hilera (global), con el hueco de los bordes.
func get_rail_rect() -> Rect2:
	var t: float = get_tile()
	var inset: float = float(_cfg.get("inset_px", 32))
	return Rect2(global_position + Vector2(inset, 0.0),
		Vector2(maxf(float(width_tiles) * t - inset * 2.0, 8.0), float(height_tiles) * t))


## La ranura (global): la fila slot_row de la hilera.
func get_slot_rect() -> Rect2:
	var r: Rect2 = get_rail_rect()
	var row: int = clampi(slot_row, 0, height_tiles - 1)
	return Rect2(Vector2(r.position.x, r.position.y + float(row) * get_tile()), Vector2(r.size.x, get_tile()))


## Etiquetas (global): lo de encima y lo de debajo de la ranura.
func get_tag_rects() -> Array[Rect2]:
	var r: Rect2 = get_rail_rect()
	var slot: Rect2 = get_slot_rect()
	var out: Array[Rect2] = []
	if slot.position.y > r.position.y + 0.5:
		out.append(Rect2(r.position, Vector2(r.size.x, slot.position.y - r.position.y)))
	if r.end.y > slot.end.y + 0.5:
		out.append(Rect2(Vector2(r.position.x, slot.end.y), Vector2(r.size.x, r.end.y - slot.end.y)))
	return out


## Un cuerpo `body` (global) toca alguna etiqueta.
func touches_tags(body: Rect2) -> bool:
	for tag: Rect2 in get_tag_rects():
		if tag.intersects(body):
			return true
	return false


func is_help_available() -> bool:
	return true


# --- Acciones ---

## Mira a Isak este paso (lo llama _physics_process; publico para las pruebas):
## si toca las etiquetas, lo empuja. Verdadero si lo ha empujado.
func check_isak(isak: Isak) -> bool:
	if isak == null or not is_instance_valid(isak) or isak.is_dead() or isak.is_warping():
		return false
	var body: Rect2 = LevelLookup.isak_body_rect(isak)
	if not touches_tags(body):
		_side = -1.0 if body.get_center().x < get_rail_rect().get_center().x else 1.0
		return false
	push(isak)
	return true


## Empuja a Isak hacia atras: al borde de la hilera por su lado y hacia fuera.
func push(isak: Isak) -> void:
	var rail: Rect2 = get_rail_rect()
	var half: float = isak.get_hitbox_size().x * 0.5
	var dir: float = _side
	var state: StringName = isak.get_state_name()
	if state == PlayerState.DASH or state in Isak.COMBO_STATES:
		isak.change_state(PlayerState.FALL)
	isak.global_position.x = rail.position.x - half - 1.0 if dir < 0.0 else rail.end.x + half + 1.0
	isak.velocity = Vector2(dir * float(_cfg.get("push_speed_px_s", 240.0)), maxf(isak.velocity.y, 0.0))
	_bump_left = float(_cfg.get("bump_s", 0.3))
	pushed.emit(dir)


# --- Dibujo (PROVISIONAL, paleta provisional del Mundo 5) ---

func _c(key: String, fallback: String) -> Color:
	return World5ObjectsConfig.color(String(_cfg.get(key, fallback)), Color.MAGENTA)


func _draw() -> void:
	var rail := Rect2(get_rail_rect().position - global_position, get_rail_rect().size)
	var slot := Rect2(get_slot_rect().position - global_position, get_slot_rect().size)
	var string_col: Color = _c("string", "gris_etiqueta")
	var tag_col: Color = _c("tag", "crema_cartel")
	var price_col: Color = _c("price", "magenta_neon")
	var ink: Color = _c("ink", "negro_medio")
	var spacing: float = float(_cfg.get("tag_spacing_px", 16))
	var sway: float = sin(_time * 2.0) * 2.0 + (sin(_time * 30.0) * 3.0 if _bump_left > 0.0 else 0.0)
	# Barras de arriba y de abajo de la ranura.
	draw_rect(Rect2(rail.position.x - 4.0, slot.position.y - 3.0, rail.size.x + 8.0, 3.0), string_col)
	draw_rect(Rect2(rail.position.x - 4.0, slot.end.y, rail.size.x + 8.0, 3.0), string_col)
	var x: float = rail.position.x + spacing * 0.5
	var i: int = 0
	while x < rail.end.x:
		var dx: float = sway * (1.0 if i % 2 == 0 else -1.0)
		for tag: Rect2 in [Rect2(rail.position.x, rail.position.y, rail.size.x, slot.position.y - rail.position.y),
				Rect2(rail.position.x, slot.end.y, rail.size.x, rail.end.y - slot.end.y)]:
			if tag.size.y <= 1.0:
				continue
			# Hilo y etiquetas colgadas una tras otra.
			draw_line(Vector2(x, tag.position.y), Vector2(x + dx, tag.end.y), string_col, 1.0)
			var y: float = tag.position.y + 6.0 + float(i % 3) * 5.0
			while y + 14.0 <= tag.end.y:
				var label := Rect2(Vector2(x + dx - 6.0, y), Vector2(12.0, 14.0))
				draw_rect(label, tag_col)
				draw_rect(label, ink, false, 1.0)
				draw_line(label.position + Vector2(2.0, 9.0), label.position + Vector2(10.0, 5.0), price_col, 1.0)
				y += 22.0
		x += spacing
		i += 1
