## Icono PROVISIONAL del HUD en el hub (2026-10-15), dibujado con _draw en
## pixeles de arte: el avion de Modo Avion (kind airplane) o el punto del
## indicador «sin guardar» (kind dot). Se sustituira por los iconos de
## assets/sprites/hub/icons/ (arte final, siguiente tanda).
class_name HudHubIcon
extends Control

@export var kind: StringName = &"airplane"
@export var color: Color = Color.WHITE


func _draw() -> void:
	var s: Vector2 = size
	if kind == &"dot":
		var d: float = minf(s.x, s.y)
		var r := Rect2((s - Vector2(d, d)) * 0.5, Vector2(d, d))
		# Punto de 4x4 con las esquinas recortadas.
		draw_rect(r.grow_individual(-1.0, 0.0, -1.0, 0.0), color)
		draw_rect(r.grow_individual(0.0, -1.0, 0.0, -1.0), color)
		return
	# Avion visto desde arriba, morro hacia arriba (10x10 de arte).
	var cx: float = floorf(s.x * 0.5)
	draw_rect(Rect2(cx - 1.0, 0.0, 2.0, s.y), color)  # fuselaje
	draw_rect(Rect2(0.0, floorf(s.y * 0.4), s.x, 2.0), color)  # alas
	draw_rect(Rect2(cx - 3.0, s.y - 2.0, 6.0, 2.0), color)  # cola
