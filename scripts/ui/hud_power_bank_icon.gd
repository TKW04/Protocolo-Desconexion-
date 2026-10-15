## Icono PROVISIONAL del contador de power banks del HUD (2026-10-14): una pila
## con contorno (color de texto del HUD) rellena de abajo arriba segun la carga
## parcial del siguiente power bank, en el color del Debug del mundo. Se dibuja
## en pixeles de arte (el Frame del HUD escala x2). Sin asset propio todavia.
class_name HudPowerBankIcon
extends Control

## Carga parcial del siguiente power bank (0-1).
var charge_ratio: float = 0.0
var outline_color: Color = Color.WHITE
var fill_color: Color = Color.CYAN


func _draw() -> void:
	var w: float = size.x
	var h: float = size.y
	if w < 3.0 or h < 4.0:
		return
	# Borne arriba (1 px) y cuerpo con contorno de 1 px.
	draw_rect(Rect2(floorf(w * 0.5) - 1.0, 0.0, 2.0, 1.0), outline_color)
	var body := Rect2(0.0, 1.0, w, h - 1.0)
	draw_rect(body, outline_color, false, 1.0)
	var inner := body.grow(-1.0)
	var filled: float = roundf(inner.size.y * clampf(charge_ratio, 0.0, 1.0))
	if filled > 0.0:
		draw_rect(Rect2(inner.position.x, inner.end.y - filled, inner.size.x, filled), fill_color)
