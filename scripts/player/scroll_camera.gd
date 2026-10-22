## Camara de scroll forzado del Mundo 2 (2026-10-22, paso 2 de
## docs/propuesta-mundo-2.md §8; reglas de §3.1-§3.2, parametros en
## data/camera_scroll.json y la seccion scroll del nivel). Como TowerCamera, no es
## un nodo: Isak la avanza en cada step() con el delta del MUNDO (el Debug la
## ralentiza) y coloca su Camera2D en el centro que devuelve.
##
## El estado es el borde de abajo de la vista (`_bottom`, px). Sube solo (la y
## disminuye) a la velocidad del tramo (scroll.stages, por la fila del borde de
## abajo; default_speed_tiles_s fuera) y se para:
##   - en la sala de inicio hasta que los pies de Isak suben por encima de
##     start_resume_row (arranque on_enter);
##   - en cada parada (scroll.stops: at_row = fila del borde de abajo parado)
##     hasta que los pies suben por encima de su resume_row;
##   - arriba del todo (la vista no sale del nivel).
## scroll.reverses: al llegar a su at_row, el scroll baja duration_s (tiempo del
## mundo) a su velocidad y el borde que dana pasa a ser el de arriba.
## La vista ocupa todo el ancho del nivel (20 tiles): x fija en el centro.
class_name ScrollCamera
extends RefCounted

const DEFAULT_PATH: String = "res://data/camera_scroll.json"
const EDGE_NONE: StringName = &""
const EDGE_BOTTOM: StringName = &"bottom"
const EDGE_TOP: StringName = &"top"

var edge_damage: float = 10.0
var edge_invulnerability_s: float = 1.0
var safe_margin_px: float = 128.0
var ceiling_above_view_px: float = 128.0
var warn_s: float = 0.75
var reverse_warn_s: float = 1.0
## Datos de data/camera_scroll.json (colores y medidas del aviso).
var data: Dictionary = {}

var _view: Vector2 = Vector2(1280.0, 720.0)
var _limits: Rect2 = Rect2()
var _tile: float = 64.0
var _default_speed: float = 32.0
## Tramos: {top, bottom (px, lineas de las filas), speed (px/s)}.
var _stages: Array[Dictionary] = []
## Paradas: {id, line (px del borde de abajo parado), resume (px), done}.
var _stops: Array[Dictionary] = []
## Inversiones: {line, duration, speed (px/s), done}.
var _reverses: Array[Dictionary] = []
## Tarjetas seguras: pies (px).
var _safe: PackedVector2Array = PackedVector2Array()
var _start_line: float = 0.0
var _start_resume: float = 0.0

var _bottom: float = 0.0
## Parada en curso: indice en _stops, -1 = la de inicio, -2 = ninguna.
var _parked: int = -2
## Inversion en curso (indice en _reverses, -1 = ninguna) y tiempo que le queda.
var _reversing: int = -1
var _reverse_left: float = 0.0
var _speed_now: float = 0.0


static func load_from_file(path: String = DEFAULT_PATH) -> ScrollCamera:
	var camera := ScrollCamera.new()
	var raw: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not raw is Dictionary:
		push_error("ScrollCamera: no se pudo leer %s; se usan los valores por defecto." % path)
		return camera
	camera.data = raw
	camera.edge_damage = float(raw.get("edge_damage", camera.edge_damage))
	camera.edge_invulnerability_s = float(raw.get("edge_invulnerability_s", camera.edge_invulnerability_s))
	camera.safe_margin_px = float(raw.get("safe_margin_px", camera.safe_margin_px))
	camera.ceiling_above_view_px = float(raw.get("ceiling_above_view_px", camera.ceiling_above_view_px))
	camera.warn_s = float(raw.get("warn_frames", 9)) / maxf(float(raw.get("anim_fps", 12.0)), 0.001)
	camera.reverse_warn_s = float(raw.get("reverse_warn_s", camera.reverse_warn_s))
	return camera


## Vista (px del mundo), limites del nivel (el grid) y seccion scroll del nivel
## (filas y tiles/s, como en el JSON; tools/build_level.py la pasa tal cual).
func configure(view_size: Vector2, limits: Rect2, config: Dictionary, tile_px: float = 64.0) -> void:
	_view = view_size
	_limits = limits
	_tile = tile_px
	_default_speed = float(config.get("default_speed_tiles_s", 0.5)) * _tile
	_stages.clear()
	for raw: Variant in config.get("stages", []):
		if raw is Dictionary:
			_stages.append({"top": float(raw.get("y_from", 0)) * _tile,
					"bottom": (float(raw.get("y_to", 0)) + 1.0) * _tile,
					"speed": float(raw.get("speed_tiles_s", 0.5)) * _tile})
	_stops.clear()
	for raw: Variant in config.get("stops", []):
		if raw is Dictionary:
			_stops.append({"id": StringName(String(raw.get("id", ""))),
					"line": (float(raw.get("at_row", 0)) + 1.0) * _tile,
					"resume": float(raw.get("resume_row", 0)) * _tile, "done": false})
	_stops.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a["line"] > b["line"])
	_reverses.clear()
	for raw: Variant in config.get("reverses", []):
		if raw is Dictionary:
			_reverses.append({"line": (float(raw.get("at_row", 0)) + 1.0) * _tile,
					"duration": float(raw.get("duration_s", 0.0)),
					"speed": float(raw.get("speed_tiles_s", 0.5)) * _tile, "done": false})
	_safe = PackedVector2Array()
	for raw: Variant in config.get("safe_respawn", []):
		var cell: Vector2 = Vector2.ZERO
		if raw is Array and (raw as Array).size() == 2:
			cell = Vector2(float(raw[0]), float(raw[1]))
		elif raw is Vector2:
			cell = raw
		else:
			continue
		_safe.append(Vector2((cell.x + 0.5) * _tile, (cell.y + 1.0) * _tile))
	var bottom_limit: float = _limits.end.y if _limits.has_area() else _view.y
	_start_line = minf((float(config.get("start_bottom_row", -1)) + 1.0) * _tile, bottom_limit) \
			if config.has("start_bottom_row") else bottom_limit
	_start_resume = float(config.get("start_resume_row", 0)) * _tile
	restart()


## Vuelve al principio: abajo, parado en la sala de inicio, nada consumido.
func restart() -> void:
	for stop: Dictionary in _stops:
		stop["done"] = false
	for rev: Dictionary in _reverses:
		rev["done"] = false
	_bottom = _start_line
	_parked = -1
	_reversing = -1
	_reverse_left = 0.0
	_speed_now = 0.0


## Reaparecer en `feet` (muerte: punto de sincronizacion o vortice): el scroll
## vuelve a la parada de esa seccion (la mas alta cuya vista parada contiene los
## pies; si ninguna, el inicio). Lo de encima de la parada vuelve a estar pendiente.
func reset_for(feet: Vector2) -> void:
	restart()
	var best: int = -1
	for i: int in _stops.size():
		var line: float = _stops[i]["line"]
		if feet.y <= line and feet.y >= line - _view.y and (best < 0 or line < float(_stops[best]["line"])):
			best = i
	if best < 0:
		return
	_bottom = float(_stops[best]["line"])
	_parked = best
	for i: int in _stops.size():
		_stops[i]["done"] = float(_stops[i]["line"]) > _bottom
	for rev: Dictionary in _reverses:
		rev["done"] = float(rev["line"]) >= _bottom


## Desplaza el scroll `dy` px (una seccion en bucle lo baja con Isak): las
## paradas, tramos e inversiones siguen siendo por posicion.
func shift(dy: float) -> void:
	_bottom = clampf(_bottom + dy, _top_limit(), _bottom_limit())


## Centro de la vista sin avanzar (al empezar y al reaparecer).
func snap(_feet: Vector2) -> Vector2:
	return get_center()


## Un paso: `feet` = pies de Isak, `world_delta` = delta del mundo (real x
## escala del Debug). Devuelve el centro de la camara.
func update(feet: Vector2, world_delta: float) -> Vector2:
	_speed_now = 0.0
	if _parked != -2:
		var resume: float = _start_resume if _parked == -1 else float(_stops[_parked]["resume"])
		if feet.y < resume:
			if _parked >= 0:
				_stops[_parked]["done"] = true
			_parked = -2
		else:
			return get_center()
	if _reversing >= 0:
		_speed_now = -float(_reverses[_reversing]["speed"])
		_bottom = minf(_bottom + float(_reverses[_reversing]["speed"]) * world_delta, _bottom_limit())
		_reverse_left -= world_delta
		if _reverse_left <= 0.0:
			_reversing = -1
		return get_center()
	var speed: float = speed_at(_bottom)
	var next: float = maxf(_bottom - speed * world_delta, _top_limit())
	# Paradas e inversiones que se cruzan en este paso.
	for i: int in _stops.size():
		var stop: Dictionary = _stops[i]
		if not stop["done"] and next <= float(stop["line"]) and _bottom >= float(stop["line"]):
			next = float(stop["line"])
			_parked = i
			break
	for i: int in _reverses.size():
		var rev: Dictionary = _reverses[i]
		if not rev["done"] and next <= float(rev["line"]) and _bottom >= float(rev["line"]):
			next = float(rev["line"])
			rev["done"] = true
			_reversing = i
			_reverse_left = float(rev["duration"])
			_parked = -2
			break
	_speed_now = speed if next < _bottom else 0.0
	_bottom = next
	return get_center()


## Velocidad de subida (px/s, tiempo del mundo) con el borde de abajo en `bottom`.
func speed_at(bottom: float) -> float:
	var row_line: float = bottom - 0.5
	for stage: Dictionary in _stages:
		if row_line >= float(stage["top"]) and row_line <= float(stage["bottom"]):
			return float(stage["speed"])
	return _default_speed


## Cambio de velocidad en los proximos `warn_s` (tiempo del mundo): +1 mas rapido,
## -1 mas lento, 0 ninguno (o parado / invirtiendo).
func upcoming_change() -> int:
	if _parked != -2 or _reversing >= 0:
		return 0
	var now: float = speed_at(_bottom)
	var ahead: float = speed_at(maxf(_bottom - now * warn_s, _top_limit()))
	if is_equal_approx(ahead, now):
		return 0
	return 1 if ahead > now else -1


## Una inversion empieza en menos de reverse_warn_s (tiempo del mundo).
func reverse_soon() -> bool:
	if _parked != -2 or _reversing >= 0:
		return false
	var reach: float = _bottom - speed_at(_bottom) * reverse_warn_s
	for rev: Dictionary in _reverses:
		if not rev["done"] and float(rev["line"]) >= reach and float(rev["line"]) <= _bottom:
			return true
	return false


## Borde que dana ahora: abajo al subir o parado, arriba al invertir.
func damaging_edge() -> StringName:
	return EDGE_TOP if _reversing >= 0 else EDGE_BOTTOM


## Isak toca el borde que dana: pies por debajo del de abajo o cabeza por
## encima del de arriba (al invertir).
func touches_edge(feet: Vector2, head_y: float) -> bool:
	if damaging_edge() == EDGE_TOP:
		return head_y < get_top()
	return feet.y > _bottom


## Tarjeta segura donde reaparecer tras tocar el borde: la mas baja a la vista a
## safe_margin_px o mas del borde que dana (y del otro); si no hay, la mas
## cercana a la vista. Sin tarjetas: `fallback`.
func safe_point(fallback: Vector2) -> Vector2:
	var low: float = _bottom - safe_margin_px
	var high: float = get_top() + safe_margin_px
	var best := Vector2.INF
	for point: Vector2 in _safe:
		if point.y <= low and point.y >= high and (best == Vector2.INF or point.y > best.y):
			best = point
	if best != Vector2.INF:
		return best
	var nearest := Vector2.INF
	var middle: float = (low + high) * 0.5
	for point: Vector2 in _safe:
		if nearest == Vector2.INF or absf(point.y - middle) < absf(nearest.y - middle):
			nearest = point
	return nearest if nearest != Vector2.INF else fallback


## Techo de carga: y minima de la cabeza (solo mientras el scroll sube o esta parado).
func ceiling_y() -> float:
	if _reversing >= 0:
		return -INF
	return get_top() - ceiling_above_view_px


func get_center() -> Vector2:
	var x: float = _limits.get_center().x if _limits.has_area() else _view.x * 0.5
	return Vector2(x, _bottom - _view.y * 0.5)


func get_bottom() -> float:
	return _bottom


func get_top() -> float:
	return _bottom - _view.y


func get_view_size() -> Vector2:
	return _view


## Velocidad del ultimo paso (px/s del mundo; negativa = bajando; 0 = parado).
func get_speed() -> float:
	return _speed_now


func is_parked() -> bool:
	return _parked != -2


## Id de la parada en curso (&"start" en la sala de inicio, &"" si no hay).
func get_parked_id() -> StringName:
	if _parked == -1:
		return &"start"
	if _parked >= 0:
		return _stops[_parked]["id"]
	return &""


func is_reversing() -> bool:
	return _reversing >= 0


func get_safe_points() -> PackedVector2Array:
	return _safe


func _top_limit() -> float:
	return (_limits.position.y if _limits.has_area() else 0.0) + _view.y


func _bottom_limit() -> float:
	return _limits.end.y if _limits.has_area() else _start_line
