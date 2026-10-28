## Burbuja con autocorrector (tipo `autocorrect_bubble` del catalogo del Mundo 4;
## 2026-10-28, paso 3 de docs/propuesta-mundo-4.md §8 y §3.4): una burbuja de chat
## (ChatBubble) con dos textos, `text` (antes) y `corrected` (despues). Al acercarse
## Isak a <= trigger_tiles (3) de la tarjeta o al pisarla, el CURSOR parpadea
## warn_frames cuadros a anim_fps (9 a 12 fps = 0,75 s; «fijarse en el cursor») y el
## texto cambia: la plataforma cambia de LARGO (regla de §3.1: corrected_width_tiles)
## y, segun `anchor`, de sitio dentro de su ranura (left: crece / encoge desde la
## izquierda; right: desde la derecha; por defecto, el lado de su autor).
## Una sola vez por intento; vuelve al estado inicial al reaparecer Isak. Tiempo del
## mundo. «El autocorrector engana, no mata»: el esquema exige que lo que deja al
## descubierto caiga como mucho 3 tiles sobre algo con salida, sin pinchos.
class_name AutocorrectBubble
extends ChatBubble

enum Phase { BEFORE, CURSOR, AFTER }

## Empieza el parpadeo del cursor.
signal cursor_started
## El texto ha cambiado (y el largo).
signal corrected_changed

@export var corrected: String = ""
@export_range(1, 8) var corrected_width_tiles: int = 1
## Lado fijo al cambiar de largo: &"left" o &"right" (&"" = el de `side`).
@export var anchor_side: StringName = &""
## Distancia (tiles) a la que se dispara.
@export var trigger_tiles: float = 3.0
## Si es false, _physics_process no avanza (las pruebas llaman a advance()).
var auto_process: bool = true

var _phase: Phase = Phase.BEFORE
var _t: float = 0.0


func _ready() -> void:
	super._ready()
	EventBus.player_respawned.connect(_on_player_respawned)
	reset()


func _physics_process(delta: float) -> void:
	super._physics_process(delta)
	if auto_process:
		advance(WorldTime.scaled_delta(delta))


func reset() -> void:
	_phase = Phase.BEFORE
	_t = 0.0
	_apply_shape()


func advance(dt: float) -> void:
	match _phase:
		Phase.BEFORE:
			if is_stepped_on() or _isak_near():
				start_cursor()
		Phase.CURSOR:
			_t += dt
			if _t >= get_cursor_s():
				_phase = Phase.AFTER
				_t = 0.0
				_apply_shape()
				corrected_changed.emit()
	queue_redraw()


## Empieza el cursor (sin Isak: pruebas). Una sola vez por intento.
func start_cursor() -> void:
	if _phase != Phase.BEFORE:
		return
	_phase = Phase.CURSOR
	_t = 0.0
	cursor_started.emit()


# --- Consultas ---

func get_phase() -> Phase:
	return _phase


func is_corrected() -> bool:
	return _phase == Phase.AFTER


func get_cursor_s() -> float:
	return float(_cfg.get("warn_frames", 9)) / maxf(float(_cfg.get("anim_fps", 12.0)), 0.01)


func get_shown_text() -> String:
	return corrected if _phase == Phase.AFTER else text


func get_width_tiles() -> int:
	return corrected_width_tiles if _phase == Phase.AFTER else width_tiles


## Lado fijo al cambiar de largo.
func get_anchor() -> StringName:
	return anchor_side if anchor_side != &"" else author_side


## Ranura: el mayor de los dos largos (tiles).
func get_slot_tiles() -> int:
	return maxi(width_tiles, corrected_width_tiles)


## La tarjeta se pega al lado `anchor` de su ranura.
func get_card_offset_x() -> float:
	if get_anchor() == &"left":
		return 0.0
	return float(get_slot_tiles() - get_width_tiles()) * World4ObjectsConfig.tile_size()


# --- Interno ---

func _isak_near() -> bool:
	var isak: Isak = _find_isak()
	if isak == null or isak.is_dead():
		return false
	var reach: float = trigger_tiles * World4ObjectsConfig.tile_size()
	var body: Rect2 = LevelLookup.isak_body_rect(isak)
	var card: Rect2 = get_card_rect()
	var dx: float = maxf(maxf(card.position.x - body.end.x, body.position.x - card.end.x), 0.0)
	var dy: float = maxf(maxf(card.position.y - body.end.y, body.position.y - card.end.y), 0.0)
	return Vector2(dx, dy).length() <= reach


func _on_player_respawned(_at: Vector2, _after_death: bool) -> void:
	reset()


func _draw() -> void:
	draw_bubble(get_shown_text(), _solid, 1.0)
	if _phase != Phase.CURSOR:
		return
	# Cursor que parpadea al final del texto (cada cuadro de anim_fps).
	var fps: float = maxf(float(_cfg.get("anim_fps", 12.0)), 1.0)
	if int(floor(_t * fps)) % 2 == 1:
		return
	var rect: Rect2 = Rect2(Vector2(get_card_offset_x(), 0.0), get_card_size())
	var x: float = rect.position.x + 8.0
	if _font != null:
		var px: int = int(_cfg.get("font_size", 16))
		x += minf(_font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, px).x, rect.size.x - 14.0)
	draw_rect(Rect2(x, 4.0, 2.0, rect.size.y - 8.0), World4ObjectsConfig.color("chat_noche", Color("#0f1422")))
