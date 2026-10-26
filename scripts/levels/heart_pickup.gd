## Corazon suelto (tipo `heart_pickup` del catalogo del Mundo 3; 2026-10-26, paso 2
## de docs/propuesta-mundo-3.md §8, §3.1): al tocarlo Isak suma `value` likes (1)
## al contador del intento (GameState.add_likes; no se guarda).
## - No reaparece en el intento; si se cogio DESPUES del ultimo punto de
##   sincronizacion (GameState.likes_checkpoint_serial), vuelve al reaparecer Isak
##   tras morir (el contador vuelve tambien al valor de ese punto).
## - Soltado por un golpe (`dropped`, LikesSystem.drop_hearts): parpadea
##   drop_blink_s de tiempo del mundo y desaparece; se puede recoger pasado
##   drop_pickup_delay_s; nunca vuelve (y desaparece al reaparecer Isak).
## Rosa con borde blanco brillante, nunca rojo (regla 2 de §6.1). Aspecto
## PROVISIONAL por codigo (seccion heart_pickup de data/world3_objects.json, paleta
## provisional). El origen del nodo es la esquina superior izquierda de su celda
## (el corazon va centrado); el de uno soltado, su centro.
class_name HeartPickup
extends Node2D

const GROUP: StringName = &"heart_pickup"

## Isak lo ha recogido (`amount` = likes que entraron de verdad).
signal collected(amount: int)

@export var object_id: StringName = &""
## Likes que suma (level_params: 1-5).
@export var value: int = 1
## Soltado por un golpe: parpadea y desaparece (lo pone LikesSystem antes de anadirlo).
var dropped: bool = false

var _cfg: Dictionary = World3ObjectsConfig.section("heart_pickup")
var _likes_cfg: Dictionary = World3ObjectsConfig.section("likes")
var _taken: bool = false
var _taken_serial: int = -1
var _life_left: float = 0.0
var _delay_left: float = 0.0
var _time: float = 0.0
var _isak: Isak


func _ready() -> void:
	add_to_group(GROUP)
	if dropped:
		_life_left = float(_likes_cfg.get("drop_blink_s", 2.0))
		_delay_left = float(_likes_cfg.get("drop_pickup_delay_s", 0.35))
	EventBus.player_respawned.connect(_on_player_respawned)
	queue_redraw()


func _physics_process(delta: float) -> void:
	advance(WorldTime.scaled_delta(delta))
	if not _taken and _delay_left <= 0.0 and _isak_overlaps():
		collect()


# --- Consultas ---

func is_taken() -> bool:
	return _taken


func is_dropped() -> bool:
	return dropped


## Segundos (tiempo del mundo) que le quedan a un corazon soltado.
func get_life_left() -> float:
	return _life_left


## Ya se puede recoger (los soltados esperan drop_pickup_delay_s).
func can_be_collected() -> bool:
	return not _taken and _delay_left <= 0.0


## Centro del corazon (px globales).
func get_center() -> Vector2:
	return global_position + _local_center()


func get_rect() -> Rect2:
	var r: float = get_radius()
	return Rect2(get_center() - Vector2(r, r), Vector2(r, r) * 2.0)


func get_radius() -> float:
	return float(_cfg.get("radius_px", 14))


## Ayuda de Eco (HelpCatalog.is_help_live): recogido, no.
func is_help_available() -> bool:
	return not _taken and not dropped


# --- Acciones ---

## Recoge el corazon (lo usan el contacto y las pruebas). Falso si ya estaba
## recogido o si aun no se puede (soltado hace menos de drop_pickup_delay_s).
func collect() -> bool:
	if not can_be_collected():
		return false
	_taken = true
	_taken_serial = GameState.likes_checkpoint_serial
	var gained: int = GameState.add_likes(value)
	collected.emit(gained)
	if dropped:
		queue_free()
	else:
		visible = false
	return true


## Avanza `dt` segundos de tiempo del mundo (publico para las pruebas).
func advance(dt: float) -> void:
	dt = maxf(dt, 0.0)
	_time += dt
	if dropped:
		_delay_left = maxf(_delay_left - dt, 0.0)
		_life_left -= dt
		if _life_left <= 0.0:
			_life_left = 0.0
			queue_free()
			return
	queue_redraw()


# --- Interno ---

func _local_center() -> Vector2:
	if dropped:
		return Vector2.ZERO
	var tile: float = World3ObjectsConfig.tile_size()
	return Vector2(tile, tile) * 0.5


func _on_player_respawned(_at: Vector2, after_death: bool) -> void:
	if dropped:
		queue_free()
		return
	if after_death and _taken and _taken_serial == GameState.likes_checkpoint_serial:
		_taken = false
		_taken_serial = -1
		visible = true
		queue_redraw()


func _isak_overlaps() -> bool:
	if _isak == null or not is_instance_valid(_isak):
		_isak = LevelLookup.find_isak(self)
	if _isak == null or _isak.is_dead():
		return false
	return LevelLookup.isak_body_rect(_isak).intersects(get_rect())


func _draw() -> void:
	if _taken:
		return
	var alpha: float = 1.0
	if dropped and int(floor(_time * float(_likes_cfg.get("drop_blink_hz", 8.0)))) % 2 == 1:
		alpha = 0.3
	var bob: float = 0.0 if dropped else roundf(sin(_time * TAU * float(_cfg.get("bob_hz", 1.2)))
			* float(_cfg.get("bob_px", 2.0)))
	var center: Vector2 = _local_center() + Vector2(0.0, bob)
	var r: float = get_radius()
	HeartPickup.draw_heart(self, center, r + 2.0, Color(World3ObjectsConfig.color(String(_cfg.get("border", "blanco_brillante"))), alpha))
	HeartPickup.draw_heart(self, center, r, Color(World3ObjectsConfig.color(String(_cfg.get("fill", "corazon_rosa"))), alpha))
	draw_rect(Rect2(center + Vector2(-r * 0.55, -r * 0.45), Vector2(3.0, 3.0)),
			Color(World3ObjectsConfig.color(String(_cfg.get("shine", "blanco_brillante"))), alpha))


## Dibuja un corazon de radio `r` centrado en `center` (lo usan la plataforma, la
## publicacion, «Borrar publicaciones» y el HUD).
static func draw_heart(canvas: CanvasItem, center: Vector2, r: float, color: Color) -> void:
	var lobe: float = r * 0.5
	canvas.draw_circle(center + Vector2(-lobe, -r * 0.2), lobe, color)
	canvas.draw_circle(center + Vector2(lobe, -r * 0.2), lobe, color)
	canvas.draw_colored_polygon(PackedVector2Array([center + Vector2(-r, -r * 0.1),
			center + Vector2(r, -r * 0.1), center + Vector2(0.0, r * 0.9)]), color)
