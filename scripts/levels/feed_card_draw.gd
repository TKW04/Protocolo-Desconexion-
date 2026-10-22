## Dibujo PROVISIONAL por codigo de las tarjetas del Mundo 2 (2026-10-22,
## docs/propuesta-mundo-2.md §6; colores de la paleta provisional,
## World2ObjectsConfig.color). Lo usan la tarjeta fragil y la Historia hasta que
## llegue el arte por script del mundo (paso 10). Familia de formas «tarjeta»:
## rectangulo con las esquinas recortadas, bisel arriba y borde claro.
class_name FeedCardDraw
extends RefCounted


## Tarjeta en `rect` (coordenadas locales de `canvas`) con opacidad `alpha`;
## `thin` = de una via (borde punteado abajo).
static func card(canvas: CanvasItem, rect: Rect2, alpha: float = 1.0, thin: bool = false,
		fill_name: String = "tarjeta_base") -> void:
	var fill: Color = Color(World2ObjectsConfig.color(fill_name), alpha)
	var light: Color = Color(World2ObjectsConfig.color("tarjeta_luz"), alpha)
	var edge: Color = Color(World2ObjectsConfig.color("tarjeta_borde"), alpha)
	var shadow: Color = Color(World2ObjectsConfig.color("tarjeta_sombra"), alpha)
	var r: float = 4.0
	canvas.draw_rect(Rect2(rect.position + Vector2(r, 0.0), Vector2(rect.size.x - r * 2.0, rect.size.y)), fill)
	canvas.draw_rect(Rect2(rect.position + Vector2(0.0, r), Vector2(rect.size.x, rect.size.y - r * 2.0)), fill)
	canvas.draw_rect(Rect2(rect.position + Vector2(r, 0.0), Vector2(rect.size.x - r * 2.0, 2.0)), edge)
	canvas.draw_rect(Rect2(rect.position + Vector2(2.0, 2.0), Vector2(rect.size.x - 4.0, 4.0)), light)
	canvas.draw_rect(Rect2(rect.position + Vector2(r, rect.size.y - 2.0), Vector2(rect.size.x - r * 2.0, 2.0)),
			shadow)
	if thin:
		var x: float = rect.position.x + r
		while x < rect.end.x - r:
			canvas.draw_rect(Rect2(x, rect.end.y - 2.0, 4.0, 2.0), edge)
			x += 8.0


## Grieta que crece de 0 a 1 desde el centro de la tarjeta.
static func crack(canvas: CanvasItem, rect: Rect2, amount: float, color: Color) -> void:
	if amount <= 0.0:
		return
	var center := rect.position + Vector2(rect.size.x * 0.5, rect.size.y * 0.5)
	var reach: float = rect.size.x * 0.45 * clampf(amount, 0.0, 1.0)
	var zig: float = minf(rect.size.y * 0.3, 6.0)
	for side: float in [-1.0, 1.0]:
		var prev := center
		var steps: int = maxi(ceili(reach / 12.0), 1)
		for i: int in steps:
			var t: float = float(i + 1) / float(steps)
			var next := center + Vector2(side * reach * t, zig * (1.0 if i % 2 == 0 else -1.0) * t)
			canvas.draw_line(prev, next, color, 2.0)
			prev = next


## Barra de progreso de `count` segmentos (los `lit` primeros llenos) arriba de la tarjeta.
static func segments(canvas: CanvasItem, rect: Rect2, lit: int, count: int, blink: bool) -> void:
	var on: Color = World2ObjectsConfig.color("gris" if blink else "blanco")
	var off: Color = World2ObjectsConfig.color("tarjeta_sombra")
	var margin: float = 8.0
	var gap: float = 2.0
	var width: float = (rect.size.x - margin * 2.0 - gap * float(count - 1)) / float(count)
	for i: int in count:
		var x: float = rect.position.x + margin + float(i) * (width + gap)
		canvas.draw_rect(Rect2(x, rect.position.y + 8.0, width, 3.0), on if i < lit else off)
