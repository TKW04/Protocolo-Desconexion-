## Mensaje del Troll (2026-10-28, paso 5 de docs/propuesta-mundo-4.md §8, §3.7):
## proyectil de texto horizontal («ok.», «¿y?», «jajaja») que cruza a speed_px_s.
## Es un NotificationShot (mismas reglas: tiempo del mundo, -contact_damage con el
## retroceso, el dash lo atraviesa, el laser no lo para) con otro dibujo: bocadillo
## crema con el texto y CONTORNO ROJO (lo que dana). Agitar lo borra (lo hace su
## Troll en receive_shockwave). Se dibuja siempre por encima del velo del Modo
## oscuro (regla de §3.6: lo que dana se ve siempre). Aspecto PROVISIONAL por codigo.
class_name TrollMessage
extends NotificationShot

const FONT_PATH: String = "res://assets/sprites/ui/text_font.fnt"
const FONT_SIZE: int = 16
const CHAR_PX: float = 9.0
const PAD_PX: float = 12.0

var text: String = "ok."

static var _font: Font


## Ancho del bocadillo para `value` (alto fijo `height`).
static func size_for(value: String, min_width: float, height: float) -> Vector2:
	return Vector2(maxf(min_width, float(value.length()) * CHAR_PX + PAD_PX), height)


func _ready() -> void:
	# Sin el sprite de la notificacion: se dibuja el bocadillo.
	if _font == null and ResourceLoader.exists(FONT_PATH):
		_font = load(FONT_PATH) as Font
	z_as_relative = false
	z_index = DarkZone.veil_z() + 1


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	var rect := Rect2(-size_px * 0.5, size_px)
	draw_rect(rect, World4ObjectsConfig.color("crema", Color("#eee4cc")))
	draw_rect(rect, World4ObjectsConfig.color("alerta", Color("#e8473c")), false, 2.0)
	if _font != null:
		draw_string(_font, rect.position + Vector2(0.0, rect.size.y * 0.5 + 5.0), text,
			HORIZONTAL_ALIGNMENT_CENTER, rect.size.x, FONT_SIZE,
			World4ObjectsConfig.color("chat_noche", Color("#0f1422")))
