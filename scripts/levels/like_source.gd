## Publicacion (tipo `like_source` del catalogo del Mundo 3; 2026-10-26, paso 2 de
## docs/propuesta-mundo-3.md §8, §3.1): marco de una foto en la pared del fondo
## (sin colision). Un PULSO que alcanza su marco (hit_rect, misma prueba que
## PulseReceiver) da `gain` likes (5, sin pasar del tope) y la publicacion se
## enfria `cooldown_s` (8 s de TIEMPO DEL MUNDO: el Debug lo ralentiza) con el
## anillo de carga visible; despues vuelve a estar lista. Reutilizable: es la regla
## anti-atasco (cerca de cada umbral obligatorio hay una). Al reaparecer Isak
## vuelve lista. Aspecto PROVISIONAL por codigo (seccion like_source de
## data/world3_objects.json, paleta provisional). El origen es la esquina superior
## izquierda de su celda.
class_name LikeSource
extends Node2D

const GROUP: StringName = &"like_source"

## Ha dado likes (`gained` = los que entraron de verdad).
signal liked(gained: int)

@export var object_id: StringName = &""
## Likes que da cada pulso (level_params: 1-10).
@export var gain: int = 5
## Enfriamiento en s de tiempo del mundo (level_params: 2-20).
@export var cooldown_s: float = 8.0

var _cfg: Dictionary = World3ObjectsConfig.section("like_source")
var _cooldown_left: float = 0.0
var _flash_left: float = 0.0


func _ready() -> void:
	add_to_group(GROUP)
	EventBus.pulse_fired.connect(receive_pulse)
	EventBus.player_respawned.connect(_on_player_respawned)
	queue_redraw()


func _process(delta: float) -> void:
	advance(WorldTime.scaled_delta(delta))


# --- Consultas ---

func is_ready() -> bool:
	return _cooldown_left <= 0.0


func get_cooldown_left() -> float:
	return _cooldown_left


## Carga del anillo: 1 lista, 0 recien usada.
func get_charge_ratio() -> float:
	if cooldown_s <= 0.0:
		return 1.0
	return clampf(1.0 - _cooldown_left / cooldown_s, 0.0, 1.0)


func get_hit_rect() -> Rect2:
	var r: Array = _cfg.get("hit_rect", [4, 4, 56, 48])
	return Rect2(global_position + Vector2(float(r[0]), float(r[1])), Vector2(float(r[2]), float(r[3])))


## Ayuda de Eco: reutilizable (siempre ayuda, como el cargador).
func is_help_available() -> bool:
	return true


# --- Acciones ---

## Pulso de Isak (EventBus.pulse_fired). Verdadero si ha dado likes.
func receive_pulse(area: Area2D) -> bool:
	if not PulseReceiver.pulse_reaches(area, get_hit_rect()):
		return false
	return like()


## Da los likes y empieza el enfriamiento (lo usan el pulso y las pruebas).
## Falso si se esta enfriando.
func like() -> bool:
	if not is_ready():
		return false
	var gained: int = GameState.add_likes(gain)
	_cooldown_left = maxf(cooldown_s, 0.0)
	_flash_left = float(_cfg.get("flash_s", 0.3))
	liked.emit(gained)
	queue_redraw()
	return true


## Avanza `dt` segundos de tiempo del mundo (publico para las pruebas).
func advance(dt: float) -> void:
	dt = maxf(dt, 0.0)
	if _cooldown_left > 0.0:
		_cooldown_left = maxf(_cooldown_left - dt, 0.0)
	if _flash_left > 0.0:
		_flash_left = maxf(_flash_left - dt, 0.0)
	queue_redraw()


# --- Interno ---

func _on_player_respawned(_at: Vector2, _after_death: bool) -> void:
	_cooldown_left = 0.0
	_flash_left = 0.0
	queue_redraw()


func _c(key: String, fallback: String) -> Color:
	return World3ObjectsConfig.color(String(_cfg.get(key, fallback)))


func _draw() -> void:
	var fr: Array = _cfg.get("frame_rect", [4, 4, 56, 48])
	var frame := Rect2(float(fr[0]), float(fr[1]), float(fr[2]), float(fr[3]))
	draw_rect(frame, _c("frame_shadow", "marco_sombra"))
	draw_rect(frame.grow(-2.0), _c("frame", "dorado"))
	draw_rect(Rect2(frame.position + Vector2(2.0, 2.0), Vector2(frame.size.x - 4.0, 2.0)), _c("frame_light", "dorado_luz"))
	var photo: Rect2 = frame.grow(-6.0)
	var available: bool = is_ready()
	draw_rect(photo, _c("photo", "rosa_pastel") if available else _c("photo_shade", "rosa_sombra"))
	var heart_r: float = 8.0 + (2.0 if _flash_left > 0.0 else 0.0)
	var center: Vector2 = photo.get_center()
	HeartPickup.draw_heart(self, center, heart_r + 2.0, _c("heart_border", "blanco_brillante"))
	HeartPickup.draw_heart(self, center, heart_r, _c("heart", "corazon_rosa"))
	# Anillo de carga del enfriamiento (lleno = lista).
	var rc: Array = _cfg.get("ring_center_px", [54, 8])
	var ring_c := Vector2(float(rc[0]), float(rc[1]))
	var ring_r: float = float(_cfg.get("ring_radius_px", 7))
	draw_circle(ring_c, ring_r + 1.0, _c("ring_back", "galeria_noche"))
	var ratio: float = get_charge_ratio()
	if ratio >= 1.0:
		draw_arc(ring_c, ring_r - 1.0, 0.0, TAU, 24, _c("ring", "blanco_brillante"), 2.0)
	elif ratio > 0.0:
		draw_arc(ring_c, ring_r - 1.0, -PI * 0.5, -PI * 0.5 + TAU * ratio, 24, _c("ring", "blanco_brillante"), 2.0)
