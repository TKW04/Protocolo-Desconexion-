## Instalacion de una habilidad al recoger su chip (docs/propuesta-1-2.md §4.4:
## «anillo cian que se expande y un parpadeo del tinte del Debug a pantalla
## completa, 0,5 s»). Lo crea AbilityPickup (by_ability.<habilidad>.collect y
## .flash de data/world1_objects.json). Va en TIEMPO REAL y sigue con el arbol
## en pausa (la linea de historia de Eco pausa el juego en el mismo cuadro), y
## se libera solo al terminar. Solo es un efecto: no toca el estado del juego.
class_name InstallEffect
extends Node2D

var _sprite: EnergySprite
var _anim: StringName = &""
var _time: float = 0.0
var _flash_layer: CanvasLayer
var _flash: ColorRect
var _flash_s: float = 0.5
var _flash_alpha: float = 0.35
var _done_ring: bool = false


## `frames`: SpriteFrames; `anim`: animacion sin bucle del anillo; `at`:
## posicion en el padre; `flash`: {color, alpha, duration_s, layer}.
func setup(frames: String, anim: StringName, at: Vector2, flash: Variant) -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	position = at
	_anim = anim
	_sprite = EnergySprite.attach(self, anim, Vector2.ZERO, false, frames)
	var cfg: Dictionary = flash if flash is Dictionary else {}
	_flash_s = float(cfg.get("duration_s", _flash_s))
	_flash_alpha = float(cfg.get("alpha", _flash_alpha))
	if _flash_s > 0.0:
		_flash_layer = CanvasLayer.new()
		_flash_layer.name = "Flash"
		_flash_layer.layer = int(cfg.get("layer", 9))
		_flash = ColorRect.new()
		_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_flash.set_anchors_preset(Control.PRESET_FULL_RECT)
		_flash.color = Color(Color.html(String(cfg.get("color", "#3dfff5"))), _flash_alpha)
		_flash_layer.add_child(_flash)
		add_child(_flash_layer)


func _process(delta: float) -> void:
	advance(delta)


## Avanza `dt` segundos reales. Publico para las pruebas.
func advance(dt: float) -> void:
	_time += dt
	if _sprite != null and not _done_ring:
		var fps: float = _sprite.sprite_frames.get_animation_speed(_anim)
		var count: int = _sprite.sprite_frames.get_frame_count(_anim)
		var f: int = floori(_time * fps)
		if f >= count:
			_done_ring = true
			_sprite.visible = false
		else:
			_sprite.frame = f
	if _flash != null:
		# Parpadeo: encendido, apagado, encendido y se desvanece.
		var t: float = _time / maxf(_flash_s, 0.001)
		var on: float = 0.0
		if t < 0.25 or (t >= 0.5 and t < 1.0):
			on = 1.0 if t < 0.25 else 1.0 - (t - 0.5) * 2.0
		_flash.color.a = _flash_alpha * clampf(on, 0.0, 1.0)
	if _done_ring and _time >= _flash_s:
		queue_free()


func is_flashing() -> bool:
	return _flash != null and _flash.color.a > 0.0
