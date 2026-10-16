## Camara de torre (2026-10-16, paso 2 de docs/propuesta-1-2.md §10): calcula el
## centro de la Camera2D de Isak en los niveles verticales (camera.vertical
## "tower" del JSON del nivel; parametros en data/camera_tower.json). No es un
## nodo: Isak la avanza en cada step() (tambien con el simulador de las pruebas)
## y coloca su Camera2D (top_level, sin el suavizado propio) en el centro que
## devuelve. El 1-1 no la usa.
##
## Eje vertical tipo plataforma-torre:
## - Ancla: el ultimo suelo en el que Isak estuvo apoyado. En el aire no cambia,
##   asi que saltar no mueve la camara; al aterrizar a otra altura se desliza
##   suavizada hasta la nueva.
## - Centro deseado = ancla + anchor_offset_px (negativo: mira mas arriba).
##   Dentro de una banda (tramo con y_from/y_to: un piso) se encaja en ella: si
##   el piso cabe en pantalla queda centrado; si no, la vista no se sale de el.
##   Nunca deja a Isak de pie fuera de standing_zone_px.
## - Zona muerta: Isak (centro del cuerpo) nunca sale de air_zone_px; en el aire
##   es lo unico que empuja la camara (caer por un hueco, subir por encima).
## - Suavizado exponencial con tope de velocidad; limites del grid.
## El eje horizontal sigue a Isak con suavizado, como la camara del 1-1.
class_name TowerCamera
extends RefCounted

const DEFAULT_PATH: String = "res://data/camera_tower.json"

var anchor_offset_px: float = -96.0
var body_center_px: float = 40.0
## Isak de pie: px desde el borde de arriba de la vista al centro de su cuerpo (min, max).
var standing_zone_px: Vector2 = Vector2(272.0, 620.0)
## Zona muerta en el aire (borde duro), mismo criterio.
var air_zone_px: Vector2 = Vector2(64.0, 680.0)
var vertical_speed: float = 5.0
var max_vertical_speed_px_s: float = 1400.0
var horizontal_speed: float = 8.0

var _view: Vector2 = Vector2(1280.0, 720.0)
## Limites en px (sin area = sin limites).
var _limits: Rect2 = Rect2()
## Bandas (pisos) en px: x = borde de arriba, y = borde de abajo.
var _bands: PackedVector2Array = PackedVector2Array()
var _center: Vector2 = Vector2.ZERO
var _ground_y: float = 0.0
var _snapped: bool = false


static func load_from_file(path: String = DEFAULT_PATH) -> TowerCamera:
	var camera := TowerCamera.new()
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not data is Dictionary:
		push_error("TowerCamera: no se pudo leer %s; se usan los valores por defecto." % path)
		return camera
	camera.anchor_offset_px = float(data.get("anchor_offset_px", camera.anchor_offset_px))
	camera.body_center_px = float(data.get("body_center_px", camera.body_center_px))
	camera.standing_zone_px = _vec(data.get("standing_zone_px"), camera.standing_zone_px)
	camera.air_zone_px = _vec(data.get("air_zone_px"), camera.air_zone_px)
	camera.vertical_speed = float(data.get("vertical_speed", camera.vertical_speed))
	camera.max_vertical_speed_px_s = float(data.get("max_vertical_speed_px_s", camera.max_vertical_speed_px_s))
	camera.horizontal_speed = float(data.get("horizontal_speed", camera.horizontal_speed))
	return camera


static func _vec(value: Variant, fallback: Vector2) -> Vector2:
	if value is Array and (value as Array).size() == 2:
		return Vector2(float(value[0]), float(value[1]))
	return fallback


## Tamano de la vista (px del mundo), limites (Rect2 sin area = sin limites) y
## bandas de los pisos (x = arriba, y = abajo, en px).
func configure(view_size: Vector2, limits: Rect2, bands: PackedVector2Array) -> void:
	_view = view_size
	_limits = limits
	_bands = bands


## Coloca la camara sin suavizado con Isak de pie en `feet` (al empezar y al reaparecer).
func snap(feet: Vector2) -> Vector2:
	_ground_y = feet.y
	_center = Vector2(_clamp_x(feet.x), _target_y())
	_snapped = true
	return _center


## Un paso: `feet` = pies de Isak, `on_floor` = apoyado. Devuelve el centro de la camara.
func update(feet: Vector2, on_floor: bool, delta: float) -> Vector2:
	if not _snapped:
		return snap(feet)
	if on_floor:
		_ground_y = feet.y
	var target: float = _target_y()
	var step_y: float = (target - _center.y) * (1.0 - exp(-vertical_speed * delta))
	var max_step: float = max_vertical_speed_px_s * delta
	_center.y += clampf(step_y, -max_step, max_step)
	var body: float = feet.y - body_center_px
	_center.y = clampf(_center.y, body + _view.y * 0.5 - air_zone_px.y, body + _view.y * 0.5 - air_zone_px.x)
	_center.y = _clamp_y(_center.y)
	_center.x += (feet.x - _center.x) * (1.0 - exp(-horizontal_speed * delta))
	_center.x = _clamp_x(_center.x)
	return _center


func get_center() -> Vector2:
	return _center


## Altura de los pies en el ultimo suelo (el ancla).
func get_ground_y() -> float:
	return _ground_y


## Centro vertical al que va la camara con el ancla actual.
func get_target_y() -> float:
	return _target_y()


## Banda (piso) que contiene la altura `y` (Vector2.ZERO si ninguna).
func band_at(y: float) -> Vector2:
	for band: Vector2 in _bands:
		if y >= band.x and y <= band.y:
			return band
	return Vector2.ZERO


func get_view_size() -> Vector2:
	return _view


func _target_y() -> float:
	var half: float = _view.y * 0.5
	var desired: float = _ground_y + anchor_offset_px
	var band: Vector2 = band_at(_ground_y)
	if band.y > band.x:
		var lo: float = band.x + half
		var hi: float = band.y - half
		if lo > hi:
			lo = (band.x + band.y) * 0.5
			hi = lo
		desired = clampf(desired, lo, hi)
	var body: float = _ground_y - body_center_px
	desired = clampf(desired, body + half - standing_zone_px.y, body + half - standing_zone_px.x)
	return _clamp_y(desired)


func _clamp_x(x: float) -> float:
	if not _limits.has_area():
		return x
	var half: float = _view.x * 0.5
	if _limits.size.x <= _view.x:
		return _limits.get_center().x
	return clampf(x, _limits.position.x + half, _limits.end.x - half)


func _clamp_y(y: float) -> float:
	if not _limits.has_area():
		return y
	var half: float = _view.y * 0.5
	if _limits.size.y <= _view.y:
		return _limits.get_center().y
	return clampf(y, _limits.position.y + half, _limits.end.y - half)
