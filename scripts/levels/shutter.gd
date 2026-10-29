## Persiana «Cerrado por inventario» (tipo `shutter` del catalogo del Mundo 5;
## 2026-10-29, paso 6 de docs/propuesta-mundo-5.md §8, §3.7, §3.9 y patron 25).
## Ajustes en la seccion shutter de data/world5_objects.json.
##
## Persiana metalica SOLIDA de length_tiles (2-4) tiles: de suelo (orientation floor:
## length_tiles x 1, se pisa) o de pared (wall: 1 x length_tiles, apoyada en el suelo).
## El golpe al suelo (EventBus.ground_pound_landed), el pulso, el laser y el Sismo
## REBOTAN (chispa gris, `deflected`; el disparo se consume). SOLO una EMBESTIDA
## (EventBus.combo_landed con Isak.COMBO_RAM) cuya onda la alcanza la rompe PARA
## SIEMPRE (el resto del intento: reaparecer no la repone; el nivel se crea de nuevo
## en cada intento). La de suelo, al romperse, deja caer a Isak a lo de debajo y la
## onda SIGUE hasta la planta de abajo (break_wave_depth_tiles bajo la persiana, el
## ancho de la onda de la Embestida): «rompe una barrera y limpia a los enemigos de
## debajo» (doc). El origen es la esquina superior izquierda de su primera celda.
## Aspecto PROVISIONAL por codigo (lamas, candado y el cartel).
class_name Shutter
extends StaticBody2D

const GROUP: StringName = &"shutter"
const LAYER_WORLD: int = 1
const ORIENT_FLOOR: StringName = &"floor"
const ORIENT_WALL: StringName = &"wall"
## Por que ha rebotado algo (deflected).
const BY_PULSE: StringName = &"pulse"
const BY_LASER: StringName = &"laser"
const BY_POUND: StringName = &"ground_pound"
const BY_QUAKE: StringName = &"quake"

## Algo que no es la Embestida la ha alcanzado (chispa gris).
signal deflected(by: StringName)
## La Embestida la ha roto.
signal broken

@export var object_id: StringName = &""
@export var length_tiles: int = 2:
	set(value):
		length_tiles = clampi(value, 1, 8)
		_update_shape()
@export var orientation: StringName = ORIENT_FLOOR:
	set(value):
		var o := StringName(value)
		if o != ORIENT_FLOOR and o != ORIENT_WALL:
			push_warning("Shutter: orientation '%s' desconocida; floor" % o)
			o = ORIENT_FLOOR
		orientation = o
		_update_shape()

var _cfg: Dictionary = {}
var _broken: bool = false
var _deflect_left: float = 0.0
var _break_left: float = 0.0
var _shape: CollisionShape2D


func _ready() -> void:
	_cfg = World5ObjectsConfig.section("shutter")
	add_to_group(GROUP)
	collision_layer = LAYER_WORLD
	collision_mask = 0
	_shape = CollisionShape2D.new()
	_shape.name = "Shape"
	_shape.shape = RectangleShape2D.new()
	add_child(_shape)
	_update_shape()
	EventBus.ground_pound_landed.connect(_on_ground_pound_landed)
	EventBus.combo_landed.connect(_on_combo_landed)
	EventBus.pulse_fired.connect(receive_pulse)


func _process(delta: float) -> void:
	advance(WorldTime.scaled_delta(delta))


# --- Consultas ---

func get_size() -> Vector2:
	var t: float = World5ObjectsConfig.tile_size()
	if orientation == ORIENT_WALL:
		return Vector2(t, t * float(length_tiles))
	return Vector2(t * float(length_tiles), t)


## Persiana (global).
func get_shutter_rect() -> Rect2:
	return Rect2(global_position, get_size())


func is_broken() -> bool:
	return _broken


func is_solid() -> bool:
	return not _broken


func is_deflecting() -> bool:
	return _deflect_left > 0.0


func is_help_available() -> bool:
	return not _broken


# --- Acciones ---

## Pulso: rebota. Verdadero si la alcanzaba.
func receive_pulse(area: Area2D) -> bool:
	if _broken or not PulseReceiver.pulse_reaches(area, get_shutter_rect()):
		return false
	_deflect(BY_PULSE)
	return true


## Interfaz del laser: rebota (el disparo se consume).
func on_laser_hit(_damage: float, _source: Node) -> void:
	if not _broken:
		_deflect(BY_LASER)


## La rompe (Embestida; tambien las pruebas). Falso si ya estaba rota.
func break_open(wave_rect: Rect2 = Rect2(), source: Node2D = null) -> bool:
	if _broken:
		return false
	_broken = true
	_break_left = float(_cfg.get("break_s", 0.35))
	collision_layer = 0
	if _shape != null:
		_shape.set_deferred(&"disabled", true)
	broken.emit()
	if orientation == ORIENT_FLOOR and wave_rect.has_area() and is_inside_tree():
		var below: Rect2 = get_below_wave_rect(wave_rect)
		var damage: float = float(_cfg.get("break_wave_damage", 2.0))
		var stun_s: float = float(_cfg.get("break_wave_stun_s", 3.0))
		var isak := source as Isak
		if isak != null and is_instance_valid(isak) and isak.abilities != null:
			damage = isak.abilities.combo_ram_damage
			stun_s = isak.abilities.combo_ram_stun_s
		ComboWave.apply_to_enemies(get_tree(), Isak.COMBO_RAM, below, damage, stun_s)
	queue_redraw()
	return true


## Zona de la onda que sigue bajo la persiana de suelo rota: el ancho de la onda de
## la Embestida y break_wave_depth_tiles por debajo de la persiana.
func get_below_wave_rect(wave_rect: Rect2) -> Rect2:
	var r: Rect2 = get_shutter_rect()
	var depth: float = float(_cfg.get("break_wave_depth_tiles", 3.0)) * World5ObjectsConfig.tile_size()
	return Rect2(wave_rect.position.x, r.end.y, wave_rect.size.x, depth)


## Avanza `dt` segundos del mundo (solo efectos).
func advance(dt: float) -> void:
	_deflect_left = maxf(_deflect_left - dt, 0.0)
	_break_left = maxf(_break_left - dt, 0.0)
	queue_redraw()


# --- Interno ---

func _deflect(by: StringName) -> void:
	_deflect_left = float(_cfg.get("deflect_s", 0.25))
	deflected.emit(by)
	queue_redraw()


func _on_ground_pound_landed(rect: Rect2, _source: Node2D) -> void:
	if not _broken and rect.intersects(get_shutter_rect()):
		_deflect(BY_POUND)


func _on_combo_landed(kind: StringName, rect: Rect2, source: Node2D) -> void:
	if _broken or not rect.intersects(get_shutter_rect()):
		return
	if kind == Isak.COMBO_RAM:
		break_open(rect, source)
	else:
		_deflect(BY_QUAKE)


func _update_shape() -> void:
	if _shape == null:
		return
	(_shape.shape as RectangleShape2D).size = get_size()
	_shape.position = get_size() * 0.5
	queue_redraw()


# --- Dibujo (PROVISIONAL, paleta provisional del Mundo 5) ---

func _c(key: String, fallback: String) -> Color:
	return World5ObjectsConfig.color(String(_cfg.get(key, fallback)), Color.MAGENTA)


func _draw() -> void:
	var size: Vector2 = get_size()
	var rect := Rect2(Vector2.ZERO, size)
	if _broken:
		if _break_left <= 0.0:
			return
		# Lamas que caen y se abren.
		var k: float = _break_left / maxf(float(_cfg.get("break_s", 0.35)), 0.001)
		var slat: Color = Color(_c("slat", "gris_etiqueta"), k)
		for i: int in 4:
			var y: float = rect.position.y + (1.0 - k) * 40.0 * float(i + 1)
			draw_rect(Rect2(Vector2(rect.position.x + float(i) * 6.0, y), Vector2(rect.size.x - float(i) * 12.0, 6.0)), slat)
		return
	draw_rect(rect, _c("metal", "gris_escaparate"))
	var slat_color: Color = _c("slat", "gris_etiqueta")
	var step: float = float(_cfg.get("slat_px", 8))
	if orientation == ORIENT_WALL:
		var x: float = 4.0
		while x < size.x - 2.0:
			draw_line(Vector2(x, 2.0), Vector2(x, size.y - 2.0), slat_color, 2.0)
			x += step
	else:
		var y: float = 4.0
		while y < size.y - 2.0:
			draw_line(Vector2(2.0, y), Vector2(size.x - 2.0, y), slat_color, 2.0)
			y += step
	draw_rect(rect, _c("ink", "negro_medio"), false, 2.0)
	# Cartel «Cerrado por inventario» y candado.
	var font: Font = ThemeDB.fallback_font
	var sign_w: float = minf(size.x - 8.0, 120.0)
	var sign_rect := Rect2(Vector2((size.x - sign_w) * 0.5, minf(size.y * 0.5 - 9.0, 18.0)), Vector2(sign_w, 18.0))
	draw_rect(sign_rect, _c("sign", "crema_cartel"))
	draw_string(font, Vector2(sign_rect.position.x, sign_rect.end.y - 5.0),
		String(_cfg.get("text_sign", "Cerrado por inventario")), HORIZONTAL_ALIGNMENT_CENTER, sign_rect.size.x, 8,
		_c("ink", "negro_medio"))
	var lock := Vector2(size.x * 0.5, sign_rect.end.y + 10.0)
	if lock.y < size.y - 6.0:
		draw_rect(Rect2(lock + Vector2(-5.0, -2.0), Vector2(10.0, 8.0)), _c("lock", "amarillo_rebajas"))
		draw_arc(lock + Vector2(0.0, -2.0), 4.0, PI, TAU, 8, _c("lock", "amarillo_rebajas"), 2.0)
	if _deflect_left > 0.0:
		var grey: Color = _c("spark", "gris_etiqueta")
		var c: Vector2 = size * 0.5
		for deg: float in [0.0, 45.0, 90.0, 135.0]:
			var d := Vector2(14.0, 0.0).rotated(deg_to_rad(deg))
			draw_line(c - d, c + d, grey, 2.0)
