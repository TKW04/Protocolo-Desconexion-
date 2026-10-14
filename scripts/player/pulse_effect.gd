## Efecto visual del pulso de datos: onda pixelada que nace del celular de
## Isak y crece hasta pulse_radius_px en pulse_duration_s. Solo presentacion.
## Los cuadros se rasterizan en Image (pixeles exactos, sin interpolacion) a
## partir del radio, asi que el tamano escala si cambian los datos.
## Avanza con advance(delta), que llama PulseState en cada paso de fisica.
class_name PulseEffect
extends Node2D

## Velocidad de los efectos (pixel-art-pipeline).
const FPS: float = 24.0
## Lado del lienzo: multiplo de este valor.
const CANVAS_STEP: int = 8
## Colores de assets/palettes/effects_pulse.gpl (PROPUESTA: cian del Mundo 1).
const COLOR_CORE: Color = Color8(200, 250, 255)
const COLOR_MID: Color = Color8(79, 227, 255)
const COLOR_DIM: Color = Color8(30, 116, 140)
const PALETTE: Array[Color] = [COLOR_CORE, COLOR_MID, COLOR_DIM]
## Opacidad maxima de la onda (deja ver lo que hay detras).
const BASE_ALPHA: float = 0.85
## Opacidad del ultimo cuadro; se llega en escalones desde la mitad.
const END_ALPHA: float = 0.25
## Segmentos de la onda principal y grados de hueco de cada uno.
const SEGMENTS: int = 12
const GAP_DEG: float = 7.0
## Giro de los huecos por cuadro, en grados.
const SPIN_DEG: float = 7.5
## Exponente de la frenada de la onda (2 = muy brusca al final).
const EASE_POWER: float = 1.5
## Radio de la onda secundaria respecto a la principal.
const TRAIL_RATIO: float = 0.55

## Termina por si solo (el estado ya lo libera al salir).
signal finished

var radius_px: float = 0.0
var duration_s: float = 0.0

var _frames: Array[ImageTexture] = []
var _elapsed: float = 0.0
var _frame: int = -1
var _done: bool = false

## Cache por radio: los cuadros solo dependen del radio y del numero de cuadros.
static var _cache: Dictionary[String, Array] = {}

@onready var _sprite: Sprite2D = $Sprite2D


## Configura el efecto. Llamar antes de anadirlo al arbol o justo despues.
func setup(radius: float, duration: float) -> void:
	radius_px = radius
	duration_s = duration
	_frames = get_frames(radius, frame_count_for(duration))
	_elapsed = 0.0
	_frame = -1
	_done = false
	if is_node_ready():
		_show_frame(0)


func _ready() -> void:
	_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_sprite.centered = false
	if not _frames.is_empty():
		_show_frame(0)


## Avanza el tiempo; cambia de cuadro solo en multiplos de 1/24 s.
func advance(delta: float) -> void:
	if _frames.is_empty():
		return
	_elapsed += delta
	if _elapsed >= duration_s:
		_show_frame(_frames.size() - 1)
		if not _done:
			_done = true
			finished.emit()
		return
	_show_frame(mini(floori(_elapsed * FPS), _frames.size() - 1))


func get_frame_index() -> int:
	return _frame


func get_frame_count() -> int:
	return _frames.size()


## Lado del lienzo en px (multiplo de 8).
func get_canvas_size() -> int:
	return canvas_size_for(radius_px)


## Radio del anillo exterior del ultimo cuadro.
func get_max_radius_px() -> int:
	return roundi(radius_px)


# --- Rasterizado (estatico: lo usan tambien las pruebas y la vista previa) ---

static func frame_count_for(duration: float) -> int:
	return maxi(1, roundi(duration * FPS))


static func canvas_size_for(radius: float) -> int:
	var side: int = 2 * roundi(radius) + 2
	return ceili(float(side) / CANVAS_STEP) * CANVAS_STEP


## Radio del anillo principal en el cuadro `index` (sale rapido y frena).
static func ring_radius(radius: float, index: int, count: int) -> int:
	var t: float = float(index + 1) / float(count)
	var eased: float = 1.0 - pow(1.0 - t, EASE_POWER)
	return maxi(1, roundi(radius * eased))


## Opacidad del cuadro: fija hasta la mitad y luego baja en escalones.
static func frame_alpha(index: int, count: int) -> float:
	var t: float = float(index + 1) / float(count)
	if t <= 0.5:
		return BASE_ALPHA
	return lerpf(BASE_ALPHA, END_ALPHA, (t - 0.5) / 0.5)


static func get_frames(radius: float, count: int) -> Array[ImageTexture]:
	var key: String = "%d:%d" % [roundi(radius), count]
	if not _cache.has(key):
		var textures: Array[ImageTexture] = []
		for image: Image in build_images(radius, count):
			textures.append(ImageTexture.create_from_image(image))
		_cache[key] = textures
	var typed: Array[ImageTexture] = []
	typed.assign(_cache[key])
	return typed


static func build_images(radius: float, count: int) -> Array[Image]:
	var images: Array[Image] = []
	for i: int in count:
		images.append(build_image(radius, i, count))
	return images


## Un cuadro opaco sobre fondo transparente; el centro es el pixel (c, c).
static func build_image(radius: float, index: int, count: int) -> Image:
	var side: int = canvas_size_for(radius)
	var c: int = side >> 1
	var image := Image.create_empty(side, side, false, Image.FORMAT_RGBA8)
	image.fill(Color(0, 0, 0, 0))
	var r: int = ring_radius(radius, index, count)
	var trail: int = roundi(r * TRAIL_RATIO)
	var spin: float = SPIN_DEG * index
	for y: int in side:
		for x: int in side:
			var dx: int = x - c
			var dy: int = y - c
			var d: int = roundi(sqrt(float(dx * dx + dy * dy)))
			var color: Variant = _ring_color(d, r, trail, rad_to_deg(atan2(dy, dx)), spin)
			if color != null:
				image.set_pixel(x, y, color)
	_draw_spark(image, c, index)
	return image


static func _ring_color(d: int, r: int, trail: int, angle: float, spin: float) -> Variant:
	# onda principal: borde brillante y un px interior, con huecos que giran
	if d == r or (d == r - 1 and r >= 4):
		var seg: float = fposmod(angle + spin, 360.0 / SEGMENTS)
		if seg < GAP_DEG:
			return null
		return COLOR_CORE if d == r else COLOR_MID
	# bits de datos sueltos dentro de la onda
	if (d == r - 4 or d == r - 5) and r >= 10:
		if fposmod(angle - spin * 2.0, 45.0) < 5.0:
			return COLOR_MID
	# onda secundaria tenue y punteada
	if trail >= 3 and d == trail:
		if fposmod(angle + spin, 360.0 / SEGMENTS) < 360.0 / SEGMENTS * 0.5:
			return COLOR_DIM
	return null


## Destello del celular en los dos primeros cuadros.
static func _draw_spark(image: Image, c: int, index: int) -> void:
	if index > 1:
		return
	var arm: int = 2 if index == 0 else 1
	for k: int in range(-arm, arm + 1):
		image.set_pixel(c + k, c, COLOR_CORE)
		image.set_pixel(c, c + k, COLOR_CORE)
	if index == 0:
		for p: Vector2i in [Vector2i(1, 1), Vector2i(-1, 1), Vector2i(1, -1), Vector2i(-1, -1)]:
			image.set_pixel(c + p.x, c + p.y, COLOR_MID)


func _show_frame(index: int) -> void:
	if index == _frame or _sprite == null:
		return
	_frame = index
	var side: int = get_canvas_size()
	_sprite.texture = _frames[index]
	# el pixel central del lienzo queda sobre el origen del nodo
	_sprite.position = -Vector2(side >> 1, side >> 1)
	_sprite.modulate.a = frame_alpha(index, _frames.size())
