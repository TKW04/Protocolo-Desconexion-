## Bufer de posiciones y poses de Isak (2026-10-26, paso 4 de
## docs/propuesta-mundo-3.md §3.4; lo reutilizara el Reflejo falso del paso 6,
## §3.6): guarda cada paso los pies de Isak y el cuadro de su AnimatedSprite2D
## con su marca de tiempo y devuelve el de hace `delay_s`. Sin historia
## suficiente devuelve la muestra mas antigua (al empezar, Isak quieto donde
## estaba). Tiempo: el que se le pase a record() (la pared de espejo usa tiempo
## real, como Isak).
class_name IsakPoseBuffer
extends RefCounted

## Segundos de historia que se conservan (algo mas que el retraso pedido).
var capacity_s: float = 1.5

var _samples: Array[Dictionary] = []
var _time: float = 0.0


func _init(keep_s: float = 1.5) -> void:
	capacity_s = keep_s


func clear() -> void:
	_samples.clear()
	_time = 0.0


func is_empty() -> bool:
	return _samples.is_empty()


func size() -> int:
	return _samples.size()


## Apunta el estado de `isak` tras `dt` segundos.
func record(isak: Isak, dt: float) -> void:
	if isak == null or not is_instance_valid(isak):
		return
	_time += dt
	_samples.append(snapshot(isak, _time))
	while _samples.size() > 2 and _time - float(_samples[1]["t"]) > capacity_s:
		_samples.pop_front()


## Muestra de hace `delay_s` (la ultima con t <= ahora - delay_s); {} sin muestras.
func sample(delay_s: float) -> Dictionary:
	if _samples.is_empty():
		return {}
	var target: float = _time - delay_s
	var best: Dictionary = _samples[0]
	for s: Dictionary in _samples:
		if float(s["t"]) <= target + 0.0001:
			best = s
		else:
			break
	return best


## Estado actual de `isak`: pies (global), animacion, cuadro, textura del cuadro,
## flip_h, y posicion / escala / rotacion / offset del sprite respecto a los pies.
static func snapshot(isak: Isak, t: float = 0.0) -> Dictionary:
	var out: Dictionary = {"t": t, "position": isak.global_position, "texture": null,
		"animation": &"", "frame": 0, "flip_h": false,
		"sprite_position": Vector2.ZERO, "sprite_scale": Vector2.ONE, "sprite_rotation": 0.0,
		"sprite_offset": Vector2.ZERO, "centered": true}
	var sprite := isak.get_node_or_null(^"AnimatedSprite2D") as AnimatedSprite2D
	if sprite == null:
		return out
	out["animation"] = sprite.animation
	out["frame"] = sprite.frame
	out["flip_h"] = sprite.flip_h
	out["sprite_position"] = sprite.position
	out["sprite_scale"] = sprite.scale
	out["sprite_rotation"] = sprite.rotation
	out["sprite_offset"] = sprite.offset
	out["centered"] = sprite.centered
	var frames: SpriteFrames = sprite.sprite_frames
	if frames != null and frames.has_animation(sprite.animation) \
			and sprite.frame < frames.get_frame_count(sprite.animation):
		out["texture"] = frames.get_frame_texture(sprite.animation, sprite.frame)
	return out
