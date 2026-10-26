## Espejo fijo (tipo `mirror` del catalogo del Mundo 3; 2026-10-26, paso 4 de
## docs/propuesta-mundo-3.md §8, §3.4): objeto de 1 x 1 en un pie con el cristal
## en `orientation`:
## - "/" y "\\": el laser que le llega gira 90 grados (con "/", el que va a la
##   derecha sube y el que va a la izquierda baja; con "\\", al reves).
## - "|": el laser vuelve por donde vino (siempre, venga de donde venga).
## El haz sigue con el ALCANCE QUE LE QUEDABA (768 px en total; lo recorrido
## hasta el cristal cuenta). Como mucho max_bounces (3) rebotes por disparo: un
## espejo mas PARA el disparo (lo «consume», con su destello gris). Cada rebote
## hace un destello y emite EventBus.mirror_bounced (sonido sfx_w3_mirror_bounce,
## paso 19). El pulso no le hace nada.
##
## Punto de rebote: donde el haz cruza la linea del cristal (la diagonal de la
## celda para "/" y "\\", la vertical del centro para "|"). El celular de Isak
## de pie en la misma fila del espejo queda 8 px por debajo del borde de arriba
## de la celda, asi que con "/" el haz sube por x = 56 px de la columna del espejo
## (dentro de la diana de un lector laser de esa columna, x 32-64) y con "\\" por
## x = 8 px. Decision tomada: geometria real (no se centra el haz en la celda);
## asi un mismo calculo vale para las 8 direcciones del espejo cazador.
##
## API reutilizable (espejo cazador, paso 6):
## - reflect_heading(heading, orientation) y reflection_point(...) (estaticas):
##   cualquier vector, tambien diagonales (reflexion respecto a la linea del
##   cristal; "|" invierte).
## - max_bounces() (estatica): el limite comun por disparo.
## - laser_reflection(projectile, hit_position) -> Dictionary: la interfaz de
##   reflector de LaserProjectile (ver su cabecera); {} = lo para.
##
## Objetivo del laser: Area2D en la capa world y en el grupo laser_activatable;
## no es solido para Isak. Aspecto PROVISIONAL por codigo (seccion mirror de
## data/world3_objects.json, paleta provisional). El origen es la esquina
## superior izquierda de su celda.
class_name Mirror
extends Area2D

const GROUP: StringName = &"mirror"
const LAYER_WORLD: int = 1
const ORIENTATIONS: PackedStringArray = ["/", "\\", "|"]

## Ha desviado un disparo (`at` global, `new_heading` unitario).
signal bounced(at: Vector2, new_heading: Vector2)
## Ha parado un disparo que ya llevaba max_bounces rebotes.
signal absorbed

@export var object_id: StringName = &""
## "/", "\\" o "|".
@export var orientation: String = "/"

var _cfg: Dictionary = World3ObjectsConfig.section("mirror")
var _flash_left: float = 0.0
var _flash_absorbed: bool = false
var _bounce_count: int = 0


func _ready() -> void:
	add_to_group(GROUP)
	add_to_group(LaserProjectile.GROUP_LASER_ACTIVATABLE)
	collision_layer = LAYER_WORLD
	collision_mask = 0
	monitoring = false
	if not ORIENTATIONS.has(orientation):
		push_warning("Mirror %s: orientation '%s' no valida; se usa '/'" % [object_id, orientation])
		orientation = "/"
	var r: Rect2 = get_local_hit_rect()
	var shape := CollisionShape2D.new()
	shape.name = "Shape"
	var rect := RectangleShape2D.new()
	rect.size = r.size
	shape.shape = rect
	shape.position = r.get_center()
	add_child(shape)
	queue_redraw()


func _process(delta: float) -> void:
	advance(WorldTime.scaled_delta(delta))


## Avanza `dt` segundos de tiempo del mundo (el destello). Publico para las pruebas.
func advance(dt: float) -> void:
	if _flash_left > 0.0:
		_flash_left = maxf(_flash_left - dt, 0.0)
		queue_redraw()


# --- Consultas ---

## Rebotes maximos por disparo (data/world3_objects.json mirror.max_bounces).
static func max_bounces() -> int:
	return int(World3ObjectsConfig.section("mirror").get("max_bounces", 3))


## Direccion de la linea del cristal (unitaria) para "/" y "\\"; "|" vertical.
static func line_direction(orient: String) -> Vector2:
	match orient:
		"/":
			return Vector2(1.0, -1.0).normalized()
		"\\":
			return Vector2(1.0, 1.0).normalized()
	return Vector2.DOWN


## Direccion tras reflejarse `heading` en un cristal `orient`: reflexion respecto a
## la linea del cristal ("/", "\\"; vale para diagonales) o vuelta atras ("|").
static func reflect_heading(heading: Vector2, orient: String) -> Vector2:
	var h: Vector2 = heading.normalized()
	if orient == "|":
		return -h
	var d: Vector2 = line_direction(orient)
	return (2.0 * h.dot(d) * d - h).normalized()


## Punto en que el rayo `from` + s * `heading` cruza la linea del cristal que pasa
## por `center`; si son paralelos (cristal de canto), el punto del rayo mas
## cercano a `center`. Nunca por detras de `from`.
static func reflection_point(from: Vector2, heading: Vector2, center: Vector2, orient: String) -> Vector2:
	var h: Vector2 = heading.normalized()
	var d: Vector2 = line_direction(orient)
	var denom: float = h.cross(d)
	var s: float
	if absf(denom) < 0.0001:
		s = (center - from).dot(h)
	else:
		s = (center - from).cross(d) / denom
	return from + h * maxf(s, 0.0)


func get_local_hit_rect() -> Rect2:
	var r: Array = _cfg.get("hit_rect", [0, 0, 64, 64])
	return Rect2(float(r[0]), float(r[1]), float(r[2]), float(r[3]))


func get_hit_rect() -> Rect2:
	var r: Rect2 = get_local_hit_rect()
	return Rect2(global_position + r.position, r.size)


## Centro del cristal (global).
func get_center() -> Vector2:
	return get_hit_rect().get_center()


## Rebotes que ha hecho este espejo (todas las veces).
func get_bounce_count() -> int:
	return _bounce_count


func is_flashing() -> bool:
	return _flash_left > 0.0


# --- Interfaz del laser ---

## Reflector de LaserProjectile: desvia el haz o, si ya lleva max_bounces
## rebotes, devuelve {} (el proyectil choca y llama on_laser_hit).
func laser_reflection(projectile: Node, hit_position: Vector2) -> Dictionary:
	var heading := Vector2.RIGHT
	var bounces: int = 0
	if projectile != null:
		heading = projectile.get(&"heading") as Vector2
		bounces = int(projectile.call(&"get_bounce_count")) if projectile.has_method(&"get_bounce_count") else 0
	if bounces >= max_bounces():
		return {}
	var at: Vector2 = reflection_point(hit_position, heading, get_center(), orientation)
	var out: Vector2 = reflect_heading(heading, orientation)
	_bounce_count += 1
	_flash(false)
	bounced.emit(at, out)
	EventBus.mirror_bounced.emit(self, at)
	return {"heading": out, "position": at}


## El disparo llega con los rebotes agotados: lo para (destello apagado, sin dano).
func on_laser_hit(_damage: float, _source: Node) -> void:
	_flash(true)
	absorbed.emit()


func _flash(was_absorbed: bool) -> void:
	_flash_left = float(_cfg.get("flash_s", 0.15))
	_flash_absorbed = was_absorbed
	queue_redraw()


# --- Dibujo PROVISIONAL ---

func _draw() -> void:
	var cell: float = World3ObjectsConfig.tile_size()
	var c := Vector2(cell, cell) * 0.5
	var half: float = float(_cfg.get("glass_half_px", 26))
	var width: float = float(_cfg.get("glass_width_px", 6))
	# Pie (abajo, hasta el suelo de la celda).
	var foot_w: float = float(_cfg.get("stand_width_px", 6))
	draw_rect(Rect2(c.x - foot_w * 0.5, c.y, foot_w, cell * 0.5), _c("stand", "marco_sombra"))
	draw_rect(Rect2(c.x - 12.0, cell - 4.0, 24.0, 4.0), _c("stand", "marco_sombra"))
	var d: Vector2 = line_direction(orientation)
	var a: Vector2 = c - d * half
	var b: Vector2 = c + d * half
	draw_line(a, b, _c("frame", "dorado"), width + 4.0)
	draw_line(a, b, _c("glass", "gris_perla"), width)
	draw_line(a + d.orthogonal() * 1.0, b + d.orthogonal() * 1.0, _c("glass_light", "blanco_brillante"), 1.0)
	if _flash_left > 0.0:
		var t: float = _flash_left / maxf(float(_cfg.get("flash_s", 0.15)), 0.001)
		var col: Color = _c("absorbed", "gris_perla") if _flash_absorbed else _c("flash", "blanco_brillante")
		draw_circle(c, float(_cfg.get("flash_radius_px", 14)) * (0.6 + 0.4 * t), Color(col, 0.85 * t))


func _c(key: String, fallback: String) -> Color:
	return World3ObjectsConfig.color(String(_cfg.get(key, fallback)))
