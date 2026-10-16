## Sprite de los objetos de energia y progreso (drops, power bank, cargador,
## punto de habilidad; docs/estilizacion-energia.md). Usa las animaciones de
## assets/sprites/energy_objects_frames.tres (una por estado, con sus fps) pero
## no se reproduce sola: el objeto la avanza con tiempo del mundo (advance), asi
## que se ralentiza con el Debug y se para con la pausa como el resto del nivel.
## Las animaciones sin bucle (p. ej. charger_cooling) son cuadros de progreso:
## show_progress elige el cuadro.
class_name EnergySprite
extends AnimatedSprite2D

const FRAMES_PATH: String = "res://assets/sprites/energy_objects_frames.tres"

var _time: float = 0.0


## Crea el sprite con la animacion `anim`, centrado en `pos`, y lo anade a `parent`.
## `random_start` empieza el bucle en un punto al azar (dos objetos juntos no
## parpadean a la vez). `frames_path` (vacio = FRAMES_PATH) usa otro
## SpriteFrames con las mismas animaciones (p. ej. el cargador del hub).
static func attach(parent: Node, anim: StringName, pos: Vector2, random_start: bool = false,
		frames_path: String = "") -> EnergySprite:
	var sprite := EnergySprite.new()
	sprite.name = "Sprite"
	sprite.sprite_frames = load(frames_path if not frames_path.is_empty() else FRAMES_PATH) as SpriteFrames
	sprite.centered = true
	sprite.position = pos
	sprite.show_state(anim)
	if random_start:
		sprite._time = randf() * sprite._loop_length()
		sprite._apply_frame()
	parent.add_child(sprite)
	return sprite


## Cambia de estado (animacion); si ya estaba en el, no reinicia el bucle.
func show_state(anim: StringName) -> void:
	if animation == anim:
		return
	animation = anim
	_time = 0.0
	frame = 0


## Cuadro de progreso `progress` (0 a 1) de una animacion sin bucle:
## floor(progress * cuadros), limitado al ultimo.
func show_progress(anim: StringName, progress: float) -> void:
	show_state(anim)
	var count: int = sprite_frames.get_frame_count(animation)
	frame = clampi(floori(clampf(progress, 0.0, 1.0) * count), 0, count - 1)


## Avanza el bucle `dt` segundos de tiempo del mundo (nada si no tiene bucle).
func advance(dt: float) -> void:
	if not sprite_frames.get_animation_loop(animation):
		return
	_time += dt
	var length: float = _loop_length()
	if length > 0.0:
		_time = fmod(_time, length)
	_apply_frame()


func _loop_length() -> float:
	var fps: float = sprite_frames.get_animation_speed(animation)
	return sprite_frames.get_frame_count(animation) / fps if fps > 0.0 else 0.0


func _apply_frame() -> void:
	var fps: float = sprite_frames.get_animation_speed(animation)
	var count: int = sprite_frames.get_frame_count(animation)
	frame = mini(floori(_time * fps), count - 1) if fps > 0.0 else 0
