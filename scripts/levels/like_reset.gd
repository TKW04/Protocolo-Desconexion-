## «Borrar publicaciones» (tipo `like_reset` del catalogo del Mundo 3; 2026-10-26,
## paso 2 de docs/propuesta-mundo-3.md §8, §3.1): panel en la pared del fondo.
## Un PULSO DE ESPALDAS (como DndSwitch / PausePlayer: el pulso alcanza su
## hit_rect e Isak se pone de espaldas pose_s con Isak.face_back) pone el contador
## de likes a 0 (GameState.set_likes). Reutilizable. Solo en secretos (§4.1.1),
## junto a plataformas inversas (`like_platform` con invert): el mensaje de Mama
## se encuentra soltando los likes. Aspecto PROVISIONAL por codigo (seccion
## like_reset de data/world3_objects.json, paleta provisional). El origen es la
## esquina superior izquierda de su celda (Isak de pie en ella).
class_name LikeReset
extends Node2D

const GROUP: StringName = &"like_reset"

## Ha borrado el contador (`cleared` = likes que habia).
signal reset_done(cleared: int)

@export var object_id: StringName = &""

var _cfg: Dictionary = World3ObjectsConfig.section("like_reset")
var _pose_left: float = 0.0
var _posed: Isak
var _flash_left: float = 0.0


func _ready() -> void:
	add_to_group(GROUP)
	EventBus.pulse_fired.connect(receive_pulse)
	queue_redraw()


func _process(delta: float) -> void:
	advance(WorldTime.scaled_delta(delta))


# --- Consultas ---

func get_hit_rect() -> Rect2:
	var r: Array = _cfg.get("hit_rect", [8, -14, 48, 48])
	return Rect2(global_position + Vector2(float(r[0]), float(r[1])), Vector2(float(r[2]), float(r[3])))


func is_posing() -> bool:
	return _pose_left > 0.0


## Ayuda de Eco: reutilizable.
func is_help_available() -> bool:
	return true


# --- Acciones ---

## Pulso de Isak (EventBus.pulse_fired). Verdadero si lo ha alcanzado.
func receive_pulse(area: Area2D) -> bool:
	if not PulseReceiver.pulse_reaches(area, get_hit_rect()):
		return false
	var isak := area.get_parent() as Isak if area != null else null
	if isak != null and is_instance_valid(isak) and not isak.is_dead() and isak.face_back():
		_posed = isak
		_pose_left = float(_cfg.get("pose_s", 0.45))
	clear_likes()
	return true


## Pone el contador a 0 (lo usan el pulso y las pruebas). Devuelve los que habia.
func clear_likes() -> int:
	var had: int = GameState.likes
	GameState.set_likes(0)
	_flash_left = float(_cfg.get("flash_s", 0.4))
	reset_done.emit(had)
	queue_redraw()
	return had


## Avanza `dt` segundos de tiempo del mundo.
func advance(dt: float) -> void:
	dt = maxf(dt, 0.0)
	if _pose_left > 0.0:
		_pose_left -= dt
		if _pose_left <= 0.0:
			_pose_left = 0.0
			if _posed != null and is_instance_valid(_posed) and _posed.is_facing_back():
				_posed.face_side()
			_posed = null
	if _flash_left > 0.0:
		_flash_left = maxf(_flash_left - dt, 0.0)
		queue_redraw()


# --- Interno ---

func _c(key: String, fallback: String) -> Color:
	return World3ObjectsConfig.color(String(_cfg.get(key, fallback)))


func _draw() -> void:
	var pr: Array = _cfg.get("panel_rect", [6, 0, 52, 44])
	var panel := Rect2(float(pr[0]), float(pr[1]), float(pr[2]), float(pr[3]))
	draw_rect(panel, _c("frame", "dorado"))
	draw_rect(panel.grow(-3.0), _c("panel", "galeria_noche"))
	# Papelera con un corazon dentro (se vacia al borrar).
	var c: Vector2 = panel.get_center() + Vector2(0.0, 4.0)
	var bin_c: Color = _c("bin", "gris_perla")
	draw_rect(Rect2(c + Vector2(-10.0, -10.0), Vector2(20.0, 3.0)), bin_c)
	draw_rect(Rect2(c + Vector2(-3.0, -13.0), Vector2(6.0, 3.0)), bin_c)
	draw_rect(Rect2(c + Vector2(-8.0, -6.0), Vector2(16.0, 16.0)), bin_c, false, 2.0)
	if _flash_left <= 0.0:
		HeartPickup.draw_heart(self, c + Vector2(0.0, 2.0), 5.0, _c("heart", "corazon_rosa"))
	else:
		draw_rect(panel.grow(-3.0), Color(_c("text", "blanco_brillante"), 0.35 * _flash_left / maxf(float(_cfg.get("flash_s", 0.4)), 0.01)))
