## Desarme en pixeles de un jefe vencido (paso 10 de
## docs/propuesta-jefe-alerta-mayor.md §2.8, 2026-10-21): toma los pixeles
## opacos de la textura del cuerpo (cada `step` px de arte, con su color de la
## paleta) y los suelta como cuadraditos que se separan del centro, caen y se
## apagan en pasos discretos (sin alfa intermedio en el arte: la opacidad baja
## por escalones). Semilla fija (determinista). Tiempo del mundo; advance(dt)
## para las pruebas. Al terminar emite finished y se libera.
class_name PixelBurst
extends Node2D

signal finished

var duration_s: float = 1.6
var speed_px_s: Vector2 = Vector2(60.0, 220.0)
var gravity_px_s2: float = 420.0
var fade_steps: int = 4
var auto_process: bool = true

## {pos, vel, color, size}
var _pixels: Array[Dictionary] = []
var _t: float = 0.0
var _done: bool = false


## Crea el desarme de `texture` (dibujada a `draw_scale`, centrada en `center`
## global) bajo `parent`. `cfg`: step_px, duration_s, speed_px_s [min, max],
## gravity_px_s2, fade_steps, seed.
static func spawn(texture: Texture2D, center: Vector2, draw_scale: float, parent: Node, cfg: Dictionary = {}) -> PixelBurst:
	var burst := PixelBurst.new()
	burst.name = "PixelBurst"
	burst.top_level = true
	burst.z_index = 30
	burst.duration_s = float(cfg.get("duration_s", 1.6))
	var sp: Array = cfg.get("speed_px_s", [60.0, 220.0])
	burst.speed_px_s = Vector2(float(sp[0]), float(sp[1]))
	burst.gravity_px_s2 = float(cfg.get("gravity_px_s2", 420.0))
	burst.fade_steps = maxi(int(cfg.get("fade_steps", 4)), 1)
	parent.add_child(burst)
	burst.global_position = center
	burst._seed_pixels(texture, draw_scale, maxi(int(cfg.get("step_px", 2)), 1), int(cfg.get("seed", 821)))
	return burst


func _physics_process(delta: float) -> void:
	if auto_process:
		advance(WorldTime.scaled_delta(delta))


func get_pixel_count() -> int:
	return _pixels.size()


func is_done() -> bool:
	return _done


## Avanza `dt` segundos del mundo.
func advance(dt: float) -> void:
	if _done:
		return
	_t += dt
	for p: Dictionary in _pixels:
		var v: Vector2 = p["vel"]
		v.y += gravity_px_s2 * dt
		p["vel"] = v
		p["pos"] = (p["pos"] as Vector2) + v * dt
	queue_redraw()
	if _t >= duration_s:
		_done = true
		finished.emit()
		queue_free()


func _seed_pixels(texture: Texture2D, draw_scale: float, step: int, seed_value: int) -> void:
	_pixels.clear()
	if texture == null:
		return
	var image: Image = texture.get_image()
	if image == null:
		return
	if image.is_compressed():
		image.decompress()
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var half := Vector2(image.get_width(), image.get_height()) * 0.5
	for y: int in range(0, image.get_height(), step):
		for x: int in range(0, image.get_width(), step):
			var c: Color = image.get_pixel(x, y)
			if c.a < 0.5:
				continue
			var local := (Vector2(x, y) - half) * draw_scale
			var dir: Vector2 = local.normalized() if local.length() > 0.01 else Vector2.UP
			dir = dir.rotated(rng.randf_range(-0.5, 0.5))
			var speed: float = rng.randf_range(speed_px_s.x, speed_px_s.y)
			_pixels.append({"pos": local, "vel": dir * speed + Vector2(0.0, -speed * 0.5),
				"color": Color(c.r, c.g, c.b, 1.0), "size": float(step) * draw_scale})


func _draw() -> void:
	if _pixels.is_empty():
		return
	var f: float = clampf(_t / maxf(duration_s, 0.001), 0.0, 1.0)
	# Opacidad en escalones (pixel art): 1, 0.75, 0.5, 0.25...
	var alpha: float = 1.0 - floorf(f * float(fade_steps)) / float(fade_steps)
	for p: Dictionary in _pixels:
		var s: float = p["size"]
		var c: Color = p["color"]
		c.a = alpha
		draw_rect(Rect2((p["pos"] as Vector2) - Vector2(s, s) * 0.5, Vector2(s, s)), c)
