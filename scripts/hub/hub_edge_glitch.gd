## Glitch del borde derecho de la pagina 1 del hub (2026-10-27, paso 2 de
## docs/propuesta-hub-mundos-4-6.md §1): mientras la pagina 2 esta «en
## instalacion», franjas en los colores de las piezas encendidas (cian, ambar y
## verde acido) sobre la columna 19 (filas 5-8), donde ya no hay pared. Cambia
## de dibujo un cuadro cada `flicker_every_s` s. Solo decorado (sin colision).
## Arte PROVISIONAL por codigo hasta el paso 7 (tools/gen_hub_objects.py).
class_name HubEdgeGlitch
extends Node2D

var size: Vector2 = Vector2(64.0, 256.0)
var colors: Array[Color] = [Color("#3dfff5"), Color("#ffa858"), Color("#a6ff2e")]
var flicker_every_s: float = 1.5

var _t: float = 0.0
var _flicker: bool = false
var _flicker_count: int = 0


func _process(delta: float) -> void:
	if _flicker:
		_flicker = false
		queue_redraw()
		return
	_t += delta
	if _t >= maxf(flicker_every_s, 0.05):
		_t = 0.0
		_flicker = true
		_flicker_count += 1
		queue_redraw()


## Cuadro de parpadeo en curso (pruebas).
func is_flickering() -> bool:
	return _flicker


## Parpadeos hechos desde que se creo (pruebas).
func get_flicker_count() -> int:
	return _flicker_count


func _draw() -> void:
	if colors.is_empty():
		return
	var rows: int = int(size.y / 8.0)
	var shift: int = 3 if _flicker else 0
	for i: int in rows:
		var k: int = (i * 7 + shift * 5) % 11
		if k > 6:
			continue
		var color: Color = colors[(i + shift) % colors.size()]
		var w: float = 8.0 + float((k * 13) % 5) * 8.0
		var x: float = size.x - w - float((k * 3 + shift) % 3) * 4.0
		color.a = 0.55 if k % 2 == 0 else 0.85
		draw_rect(Rect2(x, float(i) * 8.0, w, 4.0 if k % 3 else 8.0), color)
