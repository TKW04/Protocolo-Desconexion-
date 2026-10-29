## Tachon (tipo `wish_strike` del catalogo del Mundo 5; 2026-10-29, paso 7 de
## docs/propuesta-mundo-5.md §8, §3.7 y §4.3.1; secreto A del 5-3). Ajustes en la
## seccion wish_strike de data/world5_objects.json (y los de la pared en glitch_wall de
## data/world1_objects.json).
##
## Es una pared con glitch (GlitchWall) SOLO VISIBLE CON EL DEBUG
## (visible_only_with_debug siempre activo): sin nada revelado parece terreno normal;
## con el Debug activo e Isak cerca se disuelve y deja ver lo de detras (en el 5-3, el
## memory_pickup msg_5_3 y un punto). Encima, la linea de la lista de deseos escrita
## por Isak y tachada a mano por Eco (`text`, por defecto «arreglar la radio del
## Abuelito», PROPUESTO): solo se lee con el Debug (DebugMode.is_revealing) y, una vez
## abierta la pared, se queda a la vista el resto del intento (Isak ya la ha
## encontrado). La linea la dibuja un hermano (StrikeLine): la pared abierta se oculta.
## El origen es la esquina superior izquierda de su primera celda.
class_name WishStrike
extends GlitchWall

const STRIKE_GROUP: StringName = &"wish_strike"


## La linea tachada (hermana de la pared).
class StrikeLine:
	extends Node2D

	var strike: WishStrike

	func _process(_delta: float) -> void:
		var shown: bool = strike != null and is_instance_valid(strike) and strike.is_text_shown()
		if visible != shown:
			visible = shown
		queue_redraw()

	func _draw() -> void:
		if strike == null or not is_instance_valid(strike):
			return
		strike.draw_strike_line(self)


## Texto de la linea (params.text; vacio = el de la seccion wish_strike).
@export var text: String = ""

var _strike_cfg: Dictionary = {}
var _line: StrikeLine


func _init() -> void:
	visible_only_with_debug = true


func _ready() -> void:
	visible_only_with_debug = true
	super._ready()
	add_to_group(STRIKE_GROUP)
	_strike_cfg = World5ObjectsConfig.section("wish_strike")
	_line = StrikeLine.new()
	_line.name = "StrikeLine_%s" % (String(object_id) if object_id != &"" else str(get_instance_id()))
	_line.strike = self
	_line.z_index = int(_strike_cfg.get("z_index", 2))
	_line.visible = false
	var parent: Node = get_parent()
	if parent != null:
		parent.add_child.call_deferred(_line)
		_line.set_deferred(&"global_position", global_position)


func _exit_tree() -> void:
	if _line != null and is_instance_valid(_line):
		_line.queue_free()


# --- Consultas ---

func get_strike_text() -> String:
	return text if not text.is_empty() else String(_strike_cfg.get("text", "arreglar la radio del Abuelito"))


## La linea se lee: con el Debug revelando o con la pared ya abierta.
func is_text_shown() -> bool:
	return is_open() or DebugMode.is_revealing()


func get_strike_line() -> Node2D:
	return _line


# --- Dibujo (PROVISIONAL, paleta provisional del Mundo 5) ---

## Dibuja la linea tachada en `canvas` (StrikeLine; origen en la esquina de la pared).
func draw_strike_line(canvas: CanvasItem) -> void:
	var font: Font = ThemeDB.fallback_font
	var size: int = int(_strike_cfg.get("font_size", 12))
	var msg: String = get_strike_text()
	var w: float = font.get_string_size(msg, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	var t: float = World5ObjectsConfig.tile_size()
	var cx: float = float(width_tiles) * t * 0.5
	var y: float = float(_strike_cfg.get("text_y_px", -12))
	var ink: Color = World5ObjectsConfig.color(String(_strike_cfg.get("ink", "negro_medio")))
	var paper: Color = World5ObjectsConfig.color(String(_strike_cfg.get("paper", "crema_cartel")))
	var strike_col: Color = World5ObjectsConfig.color(String(_strike_cfg.get("strike", "magenta_neon")))
	var box := Rect2(Vector2(cx - w * 0.5 - 6.0, y - float(size) - 2.0), Vector2(w + 12.0, float(size) + 8.0))
	canvas.draw_rect(box, paper)
	canvas.draw_string(font, Vector2(box.position.x + 6.0, y), msg, HORIZONTAL_ALIGNMENT_LEFT, -1, size, ink)
	# Tachon a mano: dos trazos algo torcidos.
	var mid: float = y - float(size) * 0.35
	canvas.draw_line(Vector2(box.position.x + 2.0, mid + 2.0), Vector2(box.end.x - 2.0, mid - 2.0), strike_col, 2.0)
	canvas.draw_line(Vector2(box.position.x + 4.0, mid - 1.0), Vector2(box.end.x - 4.0, mid + 3.0), strike_col, 2.0)
