## Placa «Posa aqui» (tipo `pose_plate` del catalogo del Mundo 3; 2026-10-26, paso 6
## de docs/propuesta-mundo-3.md §8, §3.6, patron 17 de §3.5): placa plana de 1 x 1
## en el suelo de su celda. Esta PISADA mientras alguien tiene los pies encima:
## Isak o un Reflejo falso (grupo PRESSER_GROUP, con get_plate_feet()). Sostiene
## su puerta (frame_door con object_id == target_id) mientras esta pisada y
## hold_s (0,3 s) mas: is_holding(). Como los interruptores del 1-3, no es solida
## ni hace dano; no se guarda (vuelve sola al soltarla). Tiempo del mundo.
## Aspecto PROVISIONAL por codigo (seccion pose_plate). El origen es la esquina
## superior izquierda de su celda.
class_name PosePlate
extends Node2D

const GROUP: StringName = &"pose_plate"
## Quien, ademas de Isak, pisa las placas: get_plate_feet() -> Dictionary
## ({"feet": Vector2, "width": float, "on_floor": bool}; {} si no pisa nada).
const PRESSER_GROUP: StringName = &"pose_plate_presser"

## Ha cambiado si alguien la pisa (sonido sfx_w3_pose_plate al pisarla, paso 19).
signal pressed_changed(pressed: bool)
## Ha cambiado si sostiene su puerta (pisada o en los hold_s de despues).
signal holding_changed(holding: bool)

@export var object_id: StringName = &""
## Id de la puerta de marco que abre.
@export var target_id: StringName = &""
## Si es false, _physics_process no avanza (las pruebas llaman a advance()).
var auto_process: bool = true
## Isak que la pisa (si es null se busca con LevelLookup).
var isak: Isak

var _cfg: Dictionary = World3ObjectsConfig.section("pose_plate")
var _pressed: bool = false
var _hold_left: float = 0.0
var _holding: bool = false
var _pressed_by: Array[Node] = []


func _ready() -> void:
	add_to_group(GROUP)
	queue_redraw()


func _physics_process(delta: float) -> void:
	if auto_process:
		advance(WorldTime.scaled_delta(delta))


## Mira quien la pisa y avanza `dt` segundos de tiempo del mundo. Publico para las pruebas.
func advance(dt: float) -> void:
	_pressed_by = _find_pressers()
	var now: bool = not _pressed_by.is_empty()
	if now:
		_hold_left = get_hold_s()
	else:
		_hold_left = maxf(_hold_left - dt, 0.0)
	if now != _pressed:
		_pressed = now
		pressed_changed.emit(now)
	var holding: bool = now or _hold_left > 0.0
	if holding != _holding:
		_holding = holding
		holding_changed.emit(holding)
	queue_redraw()


# --- Consultas ---

func is_pressed() -> bool:
	return _pressed


## Pisada ahora o en los hold_s de despues: la puerta se abre / sigue abierta.
func is_holding() -> bool:
	return _holding


## Quien la pisaba en el ultimo advance (Isak y / o Reflejos falsos).
func get_pressed_by() -> Array[Node]:
	return _pressed_by


func get_hold_s() -> float:
	return float(_cfg.get("hold_s", 0.3))


## Zona de la placa (global): el ancho de la celda menos inset_px por lado y
## press_tolerance_px por encima y por debajo del suelo de la celda.
func get_press_rect() -> Rect2:
	var cell: float = World3ObjectsConfig.tile_size()
	var inset: float = float(_cfg.get("inset_px", 8))
	var tol: float = float(_cfg.get("press_tolerance_px", 12))
	var plate_h: float = float(_cfg.get("plate_height_px", 8))
	return Rect2(global_position + Vector2(inset, cell - plate_h - tol), Vector2(cell - 2.0 * inset, plate_h + 2.0 * tol))


## Verdadero si unos pies en `feet` con ese ancho de cuerpo pisan la placa.
func feet_press(feet: Vector2, width: float, on_floor: bool) -> bool:
	if not on_floor:
		return false
	var r: Rect2 = get_press_rect()
	if feet.y < r.position.y or feet.y > r.end.y:
		return false
	var half: float = width * 0.5 * float(_cfg.get("feet_fraction", 0.5))
	return feet.x + half >= r.position.x and feet.x - half <= r.end.x


func is_help_available() -> bool:
	return true


# --- Interno ---

func _find_pressers() -> Array[Node]:
	var out: Array[Node] = []
	if isak == null or not is_instance_valid(isak) or not isak.is_inside_tree():
		isak = LevelLookup.find_isak(self)
	if isak != null and not isak.is_dead() \
			and feet_press(isak.global_position, isak.get_hitbox_size().x, isak.is_on_floor()):
		out.append(isak)
	if is_inside_tree():
		for node: Node in get_tree().get_nodes_in_group(PRESSER_GROUP):
			if not node.has_method(&"get_plate_feet"):
				continue
			var f: Dictionary = node.call(&"get_plate_feet")
			if f.is_empty():
				continue
			if feet_press(f["feet"], float(f.get("width", 40.0)), bool(f.get("on_floor", true))):
				out.append(node)
	return out


# --- Dibujo PROVISIONAL ---

func _draw() -> void:
	var cell: float = World3ObjectsConfig.tile_size()
	var inset: float = float(_cfg.get("inset_px", 8))
	var h: float = float(_cfg.get("plate_height_px", 8))
	var sink: float = float(_cfg.get("pressed_sink_px", 3)) if _pressed else 0.0
	var base := Rect2(inset - 2.0, cell - h - 2.0, cell - 2.0 * inset + 4.0, h + 2.0)
	draw_rect(base, _c("frame_shadow", "marco_sombra"))
	var top := Rect2(inset, cell - h + sink, cell - 2.0 * inset, h - sink)
	draw_rect(top, _c("lit", "dorado_luz") if _holding else _c("plate", "dorado"))
	# Silueta de dos pies (lo que pide la placa) y el rotulo.
	var foot: Color = _c("feet", "galeria_noche")
	draw_rect(Rect2(cell * 0.5 - 10.0, cell - h + sink + 2.0, 7.0, 3.0), foot)
	draw_rect(Rect2(cell * 0.5 + 3.0, cell - h + sink + 2.0, 7.0, 3.0), foot)
	var label: String = String(_cfg.get("label", "Posa aquí"))
	var font: Font = ThemeDB.fallback_font
	var size: int = int(_cfg.get("label_font", 11))
	var w: float = font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	draw_string(font, Vector2(cell * 0.5 - w * 0.5, cell - h - 6.0), label, HORIZONTAL_ALIGNMENT_LEFT, -1, size,
		_c("label_color", "blanco_brillante") if _holding else _c("label_off", "gris_perla"))
	if _holding and not _pressed:
		# Lo que queda de los hold_s: barra fina bajo el rotulo.
		var frac: float = _hold_left / maxf(get_hold_s(), 0.001)
		draw_rect(Rect2(inset, cell - h - 4.0, (cell - 2.0 * inset) * frac, 2.0), _c("lit", "dorado_luz"))


func _c(key: String, fallback: String) -> Color:
	return World3ObjectsConfig.color(String(_cfg.get(key, fallback)))
