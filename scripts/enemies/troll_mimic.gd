## Troll disfrazado (Mundo 4, 4-3; paso 5 de docs/propuesta-mundo-4.md §8, §3.7).
## Valores en data/enemies/troll_mimic.json (y los del Troll en troll.json).
##
## Disfraz (MASK_HIDDEN): una ChatBubble hija con `text` y el avatar de `friend`
## arriba de su celda E (plataforma de una via); sin cuerpo de Troll (pulso y
## laser no le hacen nada) y sin lanzar. Con el Debug: avatar anonimo y costuras
## rojas. Se descubre con Isak a <= unmask_tiles de la burbuja (MASK_UNMASKING:
## unmask_frames cuadros a anim_fps), al pisarla (MASK_SINKING: se hunde sink_tiles
## en sink_s y despues se descubre) o al instante con Agitar (y queda aturdido).
## Descubierto (MASK_OPEN) es un Troll normal. Al reaparecer Isak vuelve al disfraz.
class_name TrollMimic
extends Troll

signal unmasked

const MIMIC_DATA_PATH: String = "res://data/enemies/troll_mimic.json"
const MASK_HIDDEN: StringName = &"hidden"
const MASK_SINKING: StringName = &"sinking"
const MASK_UNMASKING: StringName = &"unmasking"
const MASK_OPEN: StringName = &"open"

## Texto de la burbuja falsa.
var text: String = "¿vienes?":
	set(value):
		text = value
		_configure_bubble()
## Amigo que imita (&"lia", &"marco", &"tomi").
var friend: String = "lia":
	set(value):
		friend = value
		_configure_bubble()
var unmask_tiles: float = 2.0
var unmask_frames: int = 9
var sink_tiles: int = 1
var sink_s: float = 0.3

var _mask: StringName = MASK_HIDDEN
var _mask_t: float = 0.0
var _bubble: ChatBubble
var _seams: _MimicSeams


func _ready() -> void:
	_bubble = ChatBubble.new()
	_bubble.name = "Disguise"
	_bubble.author_side = &"left"
	add_child(_bubble)
	_seams = _MimicSeams.new()
	_seams.name = "Seams"
	_seams.mimic = self
	_seams.z_as_relative = false
	_seams.z_index = DarkZone.veil_z() + 1
	add_child(_seams)
	super._ready()
	if not _load_mimic_data():
		set_physics_process(false)
		return
	_configure_bubble()
	reset_patrol()


func step(delta: float) -> void:
	if not _ready_ok:
		return
	if _mask == MASK_OPEN:
		super.step(delta)
		return
	var dt: float = WorldTime.scaled_delta(delta)
	_time += dt
	match _mask:
		MASK_HIDDEN:
			_bubble._update_stepping()
			if _bubble.is_stepped_on():
				_mask = MASK_SINKING
				_mask_t = 0.0
			elif _isak_near():
				_begin_unmask()
		MASK_SINKING:
			_mask_t += dt
			var k: float = clampf(_mask_t / maxf(sink_s, 0.001), 0.0, 1.0)
			_bubble.position = _bubble_origin() + Vector2(0.0, k * float(sink_tiles) * TILE)
			if k >= 1.0:
				_begin_unmask()
		MASK_UNMASKING:
			_mask_t += dt
			if _mask_t >= get_unmask_s():
				_open_mask()
	queue_redraw()


# --- Consultas ---

func get_mask_state() -> StringName:
	return _mask


func is_disguised() -> bool:
	return _mask != MASK_OPEN


## Ayuda de Eco: disfrazado no ayuda (la Q delataria el disfraz: las ayudas nunca mienten ni adelantan).
func is_help_available() -> bool:
	return not is_disguised() and super.is_help_available()


func get_unmask_s() -> float:
	return float(unmask_frames) / anim_fps


func get_disguise() -> ChatBubble:
	return _bubble


## Lo descubre el Debug (se ve el avatar anonimo y las costuras rojas).
func is_revealed_by_debug() -> bool:
	return is_disguised() and DebugMode.is_revealing()


func is_combat_active() -> bool:
	return _mask == MASK_OPEN and super.is_combat_active()


# --- Acciones ---

func on_laser_hit(damage: float, source: Node) -> void:
	if _mask != MASK_OPEN:
		return
	super.on_laser_hit(damage, source)


func reset_patrol() -> void:
	if _bubble != null:
		if _state == STATE_DEFEATED:
			_hide_bubble()
		else:
			_mask = MASK_HIDDEN
			_mask_t = 0.0
			_bubble.position = _bubble_origin()
			_bubble.visible = true
			_bubble.modulate.a = 1.0
			_bubble._set_solid(true)
			if _body != null:
				_body.collision_layer = 0
	super.reset_patrol()


# --- Ganchos del Troll ---

func _can_be_hit() -> bool:
	return _mask == MASK_OPEN and super._can_be_hit()


func _on_shockwave_hit() -> void:
	if _mask != MASK_OPEN:
		_open_mask()


func receive_shockwave(center: Vector2, radius: float, wave_stun_s: float) -> bool:
	if _mask != MASK_OPEN and _state != STATE_DEFEATED:
		# Disfrazado la onda mira la burbuja (es lo que se ve).
		if not ShockwaveWave.reaches(center, radius, _bubble.get_card_rect()) \
				and not ShockwaveWave.reaches(center, radius, get_body_rect()):
			return false
		_open_mask()
	return super.receive_shockwave(center, radius, wave_stun_s)


# --- Interno ---

func _bubble_origin() -> Vector2:
	return Vector2(-TILE * 0.5, -TILE)


func _configure_bubble() -> void:
	if _bubble == null:
		return
	_bubble.text = text
	_bubble.friend_id = StringName(friend)
	_bubble.width_tiles = ChatBubble.width_for_text(text)
	_bubble._apply_shape()
	_bubble.queue_redraw()


func _isak_near() -> bool:
	var isak: Isak = _find_player()
	if isak == null or isak.is_dead():
		return false
	var r: Rect2 = LevelLookup.isak_body_rect(isak)
	var card: Rect2 = _bubble.get_card_rect()
	var dx: float = maxf(maxf(card.position.x - r.end.x, r.position.x - card.end.x), 0.0)
	var dy: float = maxf(maxf(card.position.y - r.end.y, r.position.y - card.end.y), 0.0)
	return Vector2(dx, dy).length() <= unmask_tiles * TILE


func _begin_unmask() -> void:
	_mask = MASK_UNMASKING
	_mask_t = 0.0


func _open_mask() -> void:
	if _mask == MASK_OPEN:
		return
	_mask = MASK_OPEN
	_hide_bubble()
	_body.collision_layer = LAYER_ENEMY
	_rest_left = 0.0
	unmasked.emit()
	queue_redraw()


func _hide_bubble() -> void:
	_mask = MASK_OPEN
	_bubble.visible = false
	_bubble._set_solid(false)


func _load_mimic_data() -> bool:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(MIMIC_DATA_PATH))
	if not parsed is Dictionary:
		push_error("TrollMimic: no se pudo leer '%s'." % MIMIC_DATA_PATH)
		return false
	var d: Dictionary = parsed
	text = String(d.get("text", text))
	friend = String(d.get("friend", friend))
	unmask_tiles = float(d.get("unmask_tiles", 2.0))
	unmask_frames = int(d.get("unmask_frames", 9))
	sink_tiles = int(d.get("sink_tiles", 1))
	sink_s = float(d.get("sink_s", 0.3))
	return true


# --- Dibujo ---

func _draw() -> void:
	if _mask == MASK_OPEN:
		super._draw()
		return
	if _mask == MASK_UNMASKING:
		# Aviso: el disfraz se borra y la silueta aparece (unmask_frames cuadros).
		var k: float = clampf(_mask_t / maxf(get_unmask_s(), 0.001), 0.0, 1.0)
		var body := Rect2(Vector2(-body_size.x * 0.5, -body_size.y), body_size)
		_draw_avatar(self, body, k)
		_bubble.modulate.a = 1.0 - 0.7 * k


## Disfrazado no ensena nada (la burbuja dibuja su borde); al quitarse el disfraz,
## su aviso: los ojos que se encienden (sin contorno rojo desde el 2026-10-28).
func get_dark_look() -> StringName:
	if _mask == MASK_OPEN:
		return super.get_dark_look()
	if _mask == MASK_UNMASKING and is_in_dark() and not DarkOverlay.lit_at(self, get_body_rect().get_center()):
		return DarkOverlay.LOOK_WARN
	return DarkOverlay.LOOK_NONE


func draw_dark_overlay(canvas: CanvasItem) -> void:
	if _mask == MASK_OPEN:
		super.draw_dark_overlay(canvas)
	elif get_dark_look() == DarkOverlay.LOOK_WARN:
		var k: float = clampf(_mask_t / maxf(get_unmask_s(), 0.001), 0.0, 1.0)
		var vr: Rect2 = get_visual_rect()
		DarkOverlay.draw_enemy_eyes(canvas, Vector2(0.0, vr.position.y + vr.size.y * 0.3), _dir, _time, k)


## Costuras rojas y avatar anonimo sobre la burbuja (solo con el Debug), por
## encima del velo del Modo oscuro.
func draw_seams(canvas: CanvasItem) -> void:
	if not is_revealed_by_debug() or not _bubble.visible:
		return
	var red: Color = World4ObjectsConfig.color("alerta", Color("#e8473c"))
	var card := Rect2(_bubble.position, _bubble.get_card_size())
	var step_px: float = 10.0
	var x: float = card.position.x + 4.0
	while x < card.end.x - 4.0:
		canvas.draw_line(Vector2(x, card.position.y - 3.0), Vector2(x + 4.0, card.position.y + 3.0), red, 2.0)
		canvas.draw_line(Vector2(x, card.end.y + 3.0), Vector2(x + 4.0, card.end.y - 3.0), red, 2.0)
		x += step_px
	canvas.draw_rect(card.grow(1.0), red, false, 1.0)
	# Avatar anonimo en lugar del del amigo.
	var r: float = 10.0
	var center := Vector2(card.position.x - r - 4.0, card.position.y + card.size.y * 0.5)
	canvas.draw_circle(center, r, World4ObjectsConfig.color("gris_medio", Color("#6b7080")))
	canvas.draw_arc(center, r + 1.0, 0.0, TAU, 20, red, 2.0)


class _MimicSeams:
	extends Node2D
	var mimic: TrollMimic

	func _process(_delta: float) -> void:
		queue_redraw()

	func _draw() -> void:
		if mimic != null:
			mimic.draw_seams(self)
