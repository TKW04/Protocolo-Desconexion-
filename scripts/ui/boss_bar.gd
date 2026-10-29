## Barra del jefe en el HUD (paso 9 de docs/propuesta-jefe-alerta-mayor.md §6,
## 2026-10-21; §2.3). Arriba en el centro, bajo la barra de estado: el icono
## del jefe, su nombre, el contador («99+», «88»... «0», el que lleva el propio
## jefe: BossBase.get_counter_label) y una fila de segmentos, uno por golpe al
## nucleo, agrupados por fase con una muesca entre fases.
## LEGIBLE SIN COLOR: los golpes que quedan son segmentos llenos y los dados,
## huecos (solo el contorno); el numero del contador dice lo mismo; la muesca
## de una fase ya pasada se queda hueca. Al cambiar de fase la barra destella y
## el contador da un bote; cada golpe hace destellar el segmento perdido.
## No dice vuelta ni acceso (la UI nunca dice vuelta/Easy/Normal/Hard).
## Se muestra con EventBus.boss_started (busca el jefe del grupo boss con ese
## id) y se oculta sola tras el golpe final (hide_after_defeat_s, desvanecida)
## o si el jefe sale del arbol. Todo en pixeles de arte x pixel_scale; aspecto
## en la seccion boss_bar de data/hud.json; arte por script de
## tools/gen_boss_alert_major.py (definitivo desde el 2026-10-22). Tiempo real.
## ESTILOS por jefe (2026-10-23, paso 18 de docs/propuesta-mundo-2.md): la
## seccion boss_bar.styles.<boss_id> sustituye claves de la base al enlazar ese
## jefe. style "playback" (Autoplay): una BARRA DE REPRODUCCION en vez de
## segmentos: pista con un capitulo por fase (separados por un hueco), relleno
## desde la izquierda hasta lo que queda (quedan / total), cabezal redondo al
## final del relleno e icono de play dibujado por codigo (sin textura); legible
## sin color: relleno macizo frente a pista hueca, posicion del cabezal y el
## contador. Arte PROVISIONAL por codigo con la paleta B del Mundo 2.
## style "portrait" (La Curadora, 2026-10-27, paso 17 de docs/propuesta-mundo-3.md
## §5.3): los segmentos de siempre dentro de un MARCO DE RETRATO dorado dibujado
## por codigo (sombra, dorado y bisel) que SE AGRIETA POR TERCIOS: una grieta por
## fase pasada en el tercio de esa fase (las fases se vacian de derecha a
## izquierda) y las tres en el golpe final (99 -> 66 -> 33 -> 0); icono de camara
## por codigo (icon_shape "camera"). Legible sin color: segmentos llenos frente a
## huecos, grietas (forma, no color) y el contador. Paleta B del Mundo 3.
## style "conversation" (El Visto, 2026-10-28, paso 18 de docs/propuesta-mundo-4.md
## §5.3): BARRA DE MENSAJES: cada golpe es una burbuja de chat (esquinas
## recortadas y cola abajo a la izquierda) agrupadas por fase con la muesca de
## siempre; las que quedan, llenas (mensajes sin leer) y las dadas, huecas con un
## doble check (leidas): se vacia por tercios (99 -> 66 -> 33 -> 0). Icono de
## doble check por codigo (icon_shape "checks"). Legible sin color: llenas frente
## a huecas con checks (forma) y el contador. Paleta B del Mundo 4.
## style "ticket" (El Vendedor, 2026-10-29, paso 18 de docs/propuesta-mundo-5.md
## §5.3): TICKET DE COMPRA: papel crema con el borde de abajo dentado; cada golpe
## es una linea del ticket (renglon de tinta) agrupadas por fase con la muesca de
## siempre; las que quedan, enteras, y las dadas, TACHADAS en magenta (el precio
## tachado del Mundo 5; se tacha por tercios 99 -> 66 -> 33 -> 0). Al lado, las
## FICHAS del jefe (Vendor.get_tokens / tokens_changed): una ficha amarilla con
## contorno de tinta y su numero. Icono de ticket por codigo (icon_shape
## "receipt"). Legible sin color: lineas enteras frente a tachadas (forma), el
## numero de fichas y el contador. Paleta B del Mundo 5.
class_name BossBar
extends Control

const SECTION: String = "boss_bar"

var _cfg: Dictionary = {}
var _base_cfg: Dictionary = {}
var _boss: BossBase
var _font: Font
var _icon: Texture2D
var _frame_box: StyleBoxTexture
var _scale: float = 2.0
var _hits: Array[int] = []
var _remaining: int = 0
var _label: String = ""
var _phase: int = 0
var _hit_flash: float = 0.0
var _phase_flash: float = 0.0
var _lost_segment: int = -1
var _hide_left: float = -1.0
var _fade: float = 1.0
## Fichas del jefe (style "ticket"; -1 si el jefe no tiene fichas).
var _tokens: int = -1
var _token_flash: float = 0.0


func _ready() -> void:
	name = "BossBar"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_base_cfg = load_config()
	_apply_style(&"")
	visible = false
	EventBus.boss_started.connect(_on_boss_started)
	EventBus.boss_weak_point_hit.connect(_on_boss_hit)
	EventBus.boss_healed.connect(_on_boss_healed)
	EventBus.boss_phase_changed.connect(_on_boss_phase_changed)
	EventBus.boss_defeated.connect(_on_boss_defeated)
	_layout()
	get_viewport().size_changed.connect(_layout)


## Configuracion de la base con el estilo del jefe `boss_id` (styles.<id>) encima.
func _apply_style(boss_id: StringName) -> void:
	_cfg = _base_cfg.duplicate(true)
	var styles: Dictionary = _base_cfg.get("styles", {})
	var over: Variant = styles.get(String(boss_id), {})
	if over is Dictionary:
		for key: Variant in over:
			if key == "colors":
				var colors: Dictionary = (_cfg.get("colors", {}) as Dictionary).duplicate()
				colors.merge(over[key] as Dictionary, true)
				_cfg["colors"] = colors
			elif not String(key).begins_with("_"):
				_cfg[key] = over[key]
	_scale = float(_cfg.get("pixel_scale", 2))
	_font = _load(String(_cfg.get("font", ""))) as Font
	_icon = _load(String(_cfg.get("icon", ""))) as Texture2D
	_frame_box = null
	var frame_tex := _load(String(_cfg.get("frame", ""))) as Texture2D
	if frame_tex != null:
		var m: float = float(_cfg.get("frame_margin_px", 4))
		_frame_box = StyleBoxTexture.new()
		_frame_box.texture = frame_tex
		_frame_box.texture_margin_left = m
		_frame_box.texture_margin_top = m
		_frame_box.texture_margin_right = m
		_frame_box.texture_margin_bottom = m
	if is_inside_tree():
		_layout()


## Seccion boss_bar de data/hud.json.
static func load_config() -> Dictionary:
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/hud.json"))
	return (data as Dictionary).get(SECTION, {}) if data is Dictionary else {}


func _process(delta: float) -> void:
	if visible and not is_instance_valid(_boss):
		unbind()
		return
	if not visible:
		return
	var changed: bool = false
	if _hit_flash > 0.0:
		_hit_flash = maxf(_hit_flash - delta, 0.0)
		changed = true
	if _phase_flash > 0.0:
		_phase_flash = maxf(_phase_flash - delta, 0.0)
		changed = true
	if _token_flash > 0.0:
		_token_flash = maxf(_token_flash - delta, 0.0)
		changed = true
	if _hide_left >= 0.0:
		_hide_left -= delta
		var fade_s: float = maxf(float(_cfg.get("fade_s", 0.4)), 0.001)
		_fade = clampf(_hide_left / fade_s, 0.0, 1.0)
		modulate.a = _fade
		if _hide_left <= 0.0:
			unbind()
			return
	if changed:
		queue_redraw()


# --- API ---

## Muestra la barra de `boss` (desde su estado actual).
func bind(boss: BossBase) -> void:
	_boss = boss
	_apply_style(boss.boss_id)
	_hits = boss.get_hits_per_phase()
	_hide_left = -1.0
	_fade = 1.0
	modulate.a = 1.0
	_hit_flash = 0.0
	_phase_flash = 0.0
	_lost_segment = -1
	if not boss.phase_restarted.is_connected(_on_phase_restarted):
		boss.phase_restarted.connect(_on_phase_restarted)
	_tokens = -1
	_token_flash = 0.0
	if boss.has_signal(&"tokens_changed") and boss.has_method(&"get_tokens"):
		_tokens = int(boss.call(&"get_tokens"))
		if not boss.is_connected(&"tokens_changed", _on_tokens_changed):
			boss.connect(&"tokens_changed", _on_tokens_changed)
	_sync()
	visible = true
	queue_redraw()


## Oculta la barra y suelta el jefe.
func unbind() -> void:
	if _boss != null and is_instance_valid(_boss) and _boss.phase_restarted.is_connected(_on_phase_restarted):
		_boss.phase_restarted.disconnect(_on_phase_restarted)
	if _boss != null and is_instance_valid(_boss) and _boss.has_signal(&"tokens_changed") \
			and _boss.is_connected(&"tokens_changed", _on_tokens_changed):
		_boss.disconnect(&"tokens_changed", _on_tokens_changed)
	_tokens = -1
	_boss = null
	_hide_left = -1.0
	visible = false


func get_boss() -> BossBase:
	return _boss


## Estilo de la barra: "segments" (Alerta Mayor), "playback" (Autoplay), "portrait" (La Curadora),
## "conversation" (El Visto) o "ticket" (El Vendedor).
func get_style() -> String:
	return String(_cfg.get("style", "segments"))


## Parte llena de la barra de reproduccion (quedan / total; 0 a 1).
func get_playback_fraction() -> float:
	var n: int = get_segment_count()
	return float(_remaining) / float(n) if n > 0 else 0.0


## Texto del contador que se ve («99+», «66», «0»).
func get_counter_text() -> String:
	return _label


## Segmentos llenos (golpes que quedan).
func get_lit_segments() -> int:
	return _remaining


func get_segment_count() -> int:
	var n: int = 0
	for h: int in _hits:
		n += h
	return n


## Muescas de fase ya pasadas (0 en la fase 1; 2 en la 3).
func get_passed_notches() -> int:
	return clampi(_phase - 1, 0, maxi(_hits.size() - 1, 0))


func get_phase() -> int:
	return _phase


func is_phase_flashing() -> bool:
	return _phase_flash > 0.0


func is_hiding() -> bool:
	return _hide_left >= 0.0


## Rectangulo de la barra en pantalla (px).
func get_screen_rect() -> Rect2:
	return Rect2(position, _size_px() * _scale)


# --- Senales ---

func _on_boss_started(boss_id: StringName) -> void:
	for node: Node in get_tree().get_nodes_in_group(BossBase.GROUP):
		var boss := node as BossBase
		if boss != null and boss.boss_id == boss_id and boss.is_fighting():
			bind(boss)
			return


func _on_boss_hit(boss_id: StringName, _remaining_hits: int) -> void:
	if not _is_mine(boss_id):
		return
	_lost_segment = _boss.get_remaining_hits()
	_hit_flash = float(_cfg.get("hit_flash_s", 0.25))
	_sync()
	queue_redraw()


## El jefe recupera golpes (Autoplay, fase 2): la barra se rellena.
func _on_boss_healed(boss_id: StringName, _remaining_hits: int) -> void:
	if not _is_mine(boss_id):
		return
	_lost_segment = -1
	_sync()
	queue_redraw()


func _on_boss_phase_changed(boss_id: StringName, _new_phase: int) -> void:
	if not _is_mine(boss_id):
		return
	_phase_flash = float(_cfg.get("phase_flash_s", 0.6))
	_sync()
	queue_redraw()


func _on_phase_restarted(_phase_index: int) -> void:
	_lost_segment = -1
	_hit_flash = 0.0
	_sync()
	if _tokens >= 0 and _boss != null and is_instance_valid(_boss) and _boss.has_method(&"get_tokens"):
		_tokens = int(_boss.call(&"get_tokens"))
	queue_redraw()


## Cambian las fichas del jefe (El Vendedor): el numero late token_flash_s.
func _on_tokens_changed(tokens: int) -> void:
	_tokens = tokens
	_token_flash = float(_cfg.get("token_flash_s", 0.3))
	queue_redraw()


## Fichas que se ven en la barra (-1 si el jefe no tiene).
func get_tokens_shown() -> int:
	return _tokens


func _on_boss_defeated(boss_id: StringName) -> void:
	if not _is_mine(boss_id):
		return
	_sync()
	_phase_flash = float(_cfg.get("phase_flash_s", 0.6))
	_hide_left = float(_cfg.get("hide_after_defeat_s", 1.2))
	queue_redraw()


func _is_mine(boss_id: StringName) -> bool:
	return _boss != null and is_instance_valid(_boss) and _boss.boss_id == boss_id


func _sync() -> void:
	if _boss == null or not is_instance_valid(_boss):
		return
	_remaining = _boss.get_remaining_hits()
	_label = _boss.get_counter_label()
	_phase = maxi(_boss.get_phase(), 1)


# --- Dibujo ---

func _size_px() -> Vector2:
	var s: Array = _cfg.get("size_px", [180, 30])
	return Vector2(float(s[0]), float(s[1]))


func _layout() -> void:
	var screen: Vector2 = get_viewport().get_visible_rect().size if is_inside_tree() else Vector2(1280, 720)
	var size_px: Vector2 = _size_px() * _scale
	var x: float = roundf((screen.x - size_px.x) * 0.5)
	# align right (2026-10-28, El Visto): pegada a la derecha a side_px del borde, para no tapar el cuerpo del jefe
	# que flota arriba en el centro de la arena.
	if String(_cfg.get("align", "center")) == "right":
		x = screen.x - size_px.x - float(_cfg.get("side_px", 32)) * _scale
	position = Vector2(x, float(_cfg.get("top_px", 20)) * _scale)
	size = size_px


func _color(key: String, fallback: String) -> Color:
	return Color.html(String((_cfg.get("colors", {}) as Dictionary).get(key, fallback)))


func _draw() -> void:
	var s: float = _scale
	var size_px: Vector2 = _size_px()
	var flash: bool = _phase_flash > 0.0 and int(_phase_flash * 12.0) % 2 == 0
	var back: Color = _color("back", "#0b0e1a")
	var border: Color = _color("border", "#aeb8d2")
	var text_c: Color = _color("text", "#f2f4f8")
	var fill: Color = _color("fill", "#ff4a2a")
	var shade: Color = _color("fill_shadow", "#a3221c")
	var empty: Color = _color("empty", "#aeb8d2")
	var notch_c: Color = _color("notch", "#f2f4f8")
	# Marco (nine-patch de frame_margin_px; sin textura, un rectangulo).
	if _frame_box != null:
		draw_set_transform(Vector2.ZERO, 0.0, Vector2(s, s))
		draw_style_box(_frame_box, Rect2(Vector2.ZERO, size_px))
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	elif get_style() == "portrait":
		_draw_portrait_frame(size_px, back)
	elif get_style() == "ticket":
		_draw_ticket_paper(size_px)
	else:
		draw_rect(Rect2(Vector2.ZERO, size_px * s), back)
		draw_rect(Rect2(Vector2.ZERO, size_px * s), border, false, s)
	if flash:
		draw_rect(Rect2(Vector2.ZERO, size_px * s), Color(text_c, 0.35))
	# Icono.
	var icon_at: Array = _cfg.get("icon_px", [3, 7])
	if _icon != null:
		draw_texture_rect(_icon, Rect2(Vector2(float(icon_at[0]), float(icon_at[1])) * s, _icon.get_size() * s), false)
	elif String(_cfg.get("icon_shape", "")) == "play":
		var ix: float = float(icon_at[0])
		var iy: float = float(icon_at[1])
		var isz: float = float(_cfg.get("icon_size_px", 14))
		draw_colored_polygon(PackedVector2Array([Vector2(ix, iy) * s, Vector2(ix + isz, iy + isz * 0.5) * s,
				Vector2(ix, iy + isz) * s]), _color("icon", "#ff5cfa"))
	elif String(_cfg.get("icon_shape", "")) == "camera":
		_draw_camera_icon(Vector2(float(icon_at[0]), float(icon_at[1])), float(_cfg.get("icon_size_px", 12)))
	elif String(_cfg.get("icon_shape", "")) == "receipt":
		_draw_receipt_icon(Vector2(float(icon_at[0]), float(icon_at[1])), float(_cfg.get("icon_size_px", 14)))
	elif String(_cfg.get("icon_shape", "")) == "checks":
		var isz2: float = float(_cfg.get("icon_size_px", 14))
		var ink: Color = _color("icon", "#a6abb8")
		_draw_check(Vector2(float(icon_at[0]), float(icon_at[1])), isz2 * 0.5, ink, 2.0)
		_draw_check(Vector2(float(icon_at[0]) + isz2 * 0.4, float(icon_at[1])), isz2 * 0.5, ink, 2.0)
	# Nombre y contador (fila de arriba).
	if _font != null:
		var fs: int = int(_cfg.get("font_size", 12))
		var text_y: float = float(_cfg.get("text_baseline_px", 12))
		var name_x: float = float(_cfg.get("bar_x_px", 22))
		var boss_name: String = String(_boss.get_config().get("name", "")) if _boss != null and is_instance_valid(_boss) else ""
		draw_set_transform(Vector2(name_x, text_y) * s, 0.0, Vector2(s, s))
		draw_string(_font, Vector2.ZERO, boss_name, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, text_c)
		var w: float = _font.get_string_size(_label, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		var bump: float = 1.0
		if _phase_flash > 0.0 or _hit_flash > 0.0:
			bump = float(_cfg.get("counter_bump", 1.25))
		var right: float = size_px.x - float(_cfg.get("counter_right_px", 4))
		draw_set_transform(Vector2(right - w * bump, text_y) * s, 0.0, Vector2(s, s) * bump)
		draw_string(_font, Vector2.ZERO, _label, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, text_c)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	# Segmentos (fila de abajo), por fase, con muescas.
	var n: int = get_segment_count()
	if n <= 0:
		return
	if get_style() == "playback":
		_draw_playback(n, fill, shade, empty, text_c, back)
		return
	var x0: float = float(_cfg.get("bar_x_px", 22))
	var bar_w: float = float(_cfg.get("bar_width_px", 150))
	var y: float = float(_cfg.get("bar_y_px", 18))
	var h: float = float(_cfg.get("segment_height_px", 6))
	var gap: float = float(_cfg.get("segment_gap_px", 2))
	var notch_w: float = float(_cfg.get("notch_gap_px", 8))
	var phases: int = _hits.size()
	var seg_w: float = floorf((bar_w - float(n - phases) * gap - float(phases - 1) * notch_w) / float(n))
	var x: float = x0
	# Segmento i (de izquierda a derecha) cuenta golpes desde el final: el de la
	# derecha es el ultimo golpe. Llenos: i < quedan.
	var seg_i: int = 0
	for p: int in phases:
		for k: int in _hits[p]:
			var lit: bool = seg_i < _remaining
			var r := Rect2(Vector2(x, y) * s, Vector2(seg_w, h) * s)
			if get_style() == "conversation":
				var lost: bool = not lit and seg_i == _lost_segment and _hit_flash > 0.0
				_draw_message(Vector2(x, y), Vector2(seg_w, h), lit, fill, shade, text_c if lost else empty)
			elif get_style() == "ticket":
				var struck_now: bool = not lit and seg_i == _lost_segment and _hit_flash > 0.0
				_draw_ticket_line(Vector2(x, y), Vector2(seg_w, h), lit, fill, shade, struck_now)
			elif lit:
				draw_rect(r, fill)
				draw_rect(Rect2(Vector2(x, y + h - 1) * s, Vector2(seg_w, 1) * s), shade)
			else:
				var lost_now: bool = seg_i == _lost_segment and _hit_flash > 0.0
				draw_rect(r, text_c if lost_now else empty, false, s)
			x += seg_w + gap
			seg_i += 1
		x -= gap
		if p < phases - 1:
			# Muesca: un trazo alto; hueca si la fase ya paso.
			var nx: float = x + notch_w * 0.5 - 1.0
			var nr := Rect2(Vector2(nx, y - 2) * s, Vector2(2, h + 4) * s)
			# Las fases se vacian de derecha a izquierda: la muesca p separa la
			# fase (phases - 1 - p) de la siguiente.
			if p >= phases - 1 - get_passed_notches():
				draw_rect(nr, notch_c, false, s * 0.5)
			else:
				draw_rect(nr, notch_c)
			x += notch_w
	if get_style() == "portrait":
		_draw_cracks(size_px)
	if get_style() == "ticket":
		_draw_tokens()


## Lineas tachadas (style "ticket"): una por golpe dado. 0 en los demas estilos.
func get_struck_lines() -> int:
	if get_style() != "ticket":
		return 0
	return maxi(get_segment_count() - _remaining, 0)


## Papel del ticket (style "ticket") en px de arte: fondo `back` con el borde
## `border`, y encima el papel `paper` con el borde de abajo dentado (dientes de
## tooth_px) y la sombra `paper_shadow` de 1 px.
func _draw_ticket_paper(size_px: Vector2) -> void:
	var s: float = _scale
	var paper: Color = _color("paper", "#ece4cc")
	var paper_shadow: Color = _color("paper_shadow", "#b2aa92")
	draw_rect(Rect2(Vector2.ZERO, size_px * s), _color("back", "#0f0d16"))
	draw_rect(Rect2(Vector2.ZERO, size_px * s), _color("border", "#757087"), false, s)
	var tooth: float = maxf(float(_cfg.get("tooth_px", 4)), 2.0)
	var inner := Rect2(Vector2(2, 2), size_px - Vector2(4, 4 + tooth * 0.5))
	draw_rect(Rect2(inner.position * s, inner.size * s), paper)
	var x: float = inner.position.x
	var bottom: float = inner.end.y
	while x < inner.end.x - 0.5:
		var w: float = minf(tooth, inner.end.x - x)
		draw_colored_polygon(PackedVector2Array([Vector2(x, bottom) * s, Vector2(x + w, bottom) * s,
				Vector2(x + w * 0.5, bottom + tooth * 0.5) * s]), paper)
		x += tooth
	draw_rect(Rect2(Vector2(inner.position.x, inner.position.y) * s, Vector2(inner.size.x, 1) * s), paper_shadow)


## Una linea del ticket (style "ticket") en px de arte: renglon de tinta de 2 px
## (entera) con un punto a la izquierda; dada, mas tenue y tachada en `strike`
## (magenta) de lado a lado; recien tachada, el tachon es mas grueso.
func _draw_ticket_line(at: Vector2, sz: Vector2, lit: bool, ink: Color, faded: Color, fresh: bool) -> void:
	var s: float = _scale
	var mid: float = at.y + floorf(sz.y * 0.5) - 1.0
	var c: Color = ink if lit else faded
	draw_rect(Rect2(Vector2(at.x, mid) * s, Vector2(1, 2) * s), c)
	if sz.x > 4.0:
		draw_rect(Rect2(Vector2(at.x + 2, mid) * s, Vector2(sz.x - 2, 2) * s), c)
	if not lit:
		var strike: Color = _color("strike", "#ff40f2")
		var thick: float = 2.0 if fresh else 1.0
		draw_rect(Rect2(Vector2(at.x - 1, mid + 1.0 - thick * 0.5) * s, Vector2(sz.x + 2, thick) * s), strike)


## Icono de ticket (icon_shape "receipt"): rectangulo de papel con dos renglones
## y el borde de abajo dentado, de `size` px de arte de alto.
func _draw_receipt_icon(at: Vector2, size_px: float) -> void:
	var s: float = _scale
	var w: float = floorf(size_px * 0.7)
	var h: float = size_px - 2.0
	var paper: Color = _color("icon", "#ece4cc")
	var ink: Color = _color("fill", "#1b1626")
	draw_rect(Rect2(at * s, Vector2(w, h) * s), paper)
	for k: int in 3:
		var tx: float = at.x + float(k) * w / 3.0
		draw_colored_polygon(PackedVector2Array([Vector2(tx, at.y + h) * s, Vector2(tx + w / 3.0, at.y + h) * s,
				Vector2(tx + w / 6.0, at.y + h + 2.0) * s]), paper)
	draw_rect(Rect2((at + Vector2(2, 3)) * s, Vector2(w - 4, 1) * s), ink)
	draw_rect(Rect2((at + Vector2(2, 6)) * s, Vector2(w - 4, 1) * s), ink)
	draw_rect(Rect2((at + Vector2(2, 9)) * s, Vector2(w - 6, 1) * s), ink)


## Fichas del jefe (style "ticket"): ficha `token` con contorno `ink` y el numero
## a su derecha, en tokens_px (px de arte); late token_flash_s al cambiar.
func _draw_tokens() -> void:
	if _tokens < 0:
		return
	var s: float = _scale
	var at: Array = _cfg.get("tokens_px", [180, 14])
	var center := Vector2(float(at[0]), float(at[1]))
	var r: float = float(_cfg.get("token_radius_px", 5))
	var bump: float = float(_cfg.get("counter_bump", 1.25)) if _token_flash > 0.0 else 1.0
	draw_circle(center * s, (r + 1.0) * bump * s, _color("token_ink", "#1b1626"))
	draw_circle(center * s, r * bump * s, _color("token", "#ffe600"))
	draw_circle(center * s, (r - 2.0) * bump * s, _color("token_shadow", "#a69200"), false, s)
	if _font == null:
		return
	var fs: int = int(_cfg.get("font_size", 12))
	var txt: String = str(_tokens)
	var tx: float = center.x + r + 3.0
	var ty: float = center.y + float(_cfg.get("tokens_text_dy_px", 4))
	draw_set_transform(Vector2(tx, ty) * s, 0.0, Vector2(s, s))
	draw_string(_font, Vector2.ZERO, txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, _color("tokens_text", "#ece4cc"))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## Mensajes leidos (style "conversation"): burbujas huecas con doble check, una
## por golpe dado. 0 en los demas estilos.
func get_read_messages() -> int:
	if get_style() != "conversation":
		return 0
	return maxi(get_segment_count() - _remaining, 0)


## Burbuja de mensaje (style "conversation") en px de arte: esquinas recortadas y
## cola de 2 px abajo a la izquierda. Llena = sin leer (fill con la sombra abajo);
## hueca = leida (contorno `outline` y doble check en tick).
func _draw_message(at: Vector2, sz: Vector2, lit: bool, fill: Color, shade: Color, outline: Color) -> void:
	var s: float = _scale
	if lit:
		draw_rect(Rect2((at + Vector2(1, 0)) * s, Vector2(sz.x - 2, sz.y) * s), fill)
		draw_rect(Rect2((at + Vector2(0, 1)) * s, Vector2(sz.x, sz.y - 2) * s), fill)
		draw_rect(Rect2((at + Vector2(1, sz.y - 1)) * s, Vector2(sz.x - 2, 1) * s), shade)
		draw_rect(Rect2((at + Vector2(0, sz.y)) * s, Vector2(2, 1) * s), fill)
		return
	# Contorno con las esquinas recortadas y la cola.
	draw_rect(Rect2((at + Vector2(1, 0)) * s, Vector2(sz.x - 2, 1) * s), outline)
	draw_rect(Rect2((at + Vector2(1, sz.y - 1)) * s, Vector2(sz.x - 2, 1) * s), outline)
	draw_rect(Rect2((at + Vector2(0, 1)) * s, Vector2(1, sz.y - 2) * s), outline)
	draw_rect(Rect2((at + Vector2(sz.x - 1, 1)) * s, Vector2(1, sz.y - 2) * s), outline)
	draw_rect(Rect2((at + Vector2(0, sz.y)) * s, Vector2(2, 1) * s), outline)
	# Doble check dentro (leido), centrado.
	var tick: Color = _color("tick", "#7f9a84")
	var w: float = minf(sz.y - 2.0, 4.0)
	var cx: float = at.x + floorf((sz.x - w * 1.75) * 0.5)
	var cy: float = at.y + 1.0
	_draw_check(Vector2(cx, cy), w, tick, 1.0)
	_draw_check(Vector2(cx + w * 0.75, cy), w, tick, 1.0)


## Un check de `w` px de arte de alto en `at` (esquina de arriba a la izquierda).
func _draw_check(at: Vector2, w: float, color: Color, width_px: float) -> void:
	var s: float = _scale
	var pts := PackedVector2Array([(at + Vector2(0, w * 0.55)) * s, (at + Vector2(w * 0.35, w)) * s,
			(at + Vector2(w, 0)) * s])
	draw_polyline(pts, color, width_px * s)


## Grietas del marco «retrato» (style "portrait"): una por fase pasada y todas
## con el jefe a 0 golpes (golpe final). 0 en los demas estilos.
func get_frame_cracks() -> int:
	if get_style() != "portrait" or _hits.is_empty():
		return 0
	if _remaining <= 0 and get_segment_count() > 0:
		return _hits.size()
	return get_passed_notches()


## Marco de retrato dorado (style "portrait"): sombra exterior, dorado con bisel
## claro arriba y a la izquierda, de frame_thickness_px, y el fondo dentro.
func _draw_portrait_frame(size_px: Vector2, back: Color) -> void:
	var s: float = _scale
	var t: float = float(_cfg.get("frame_thickness_px", 3))
	var outer: Color = _color("frame_shadow", "#54442a")
	var gold: Color = _color("frame", "#b0a064")
	var light: Color = _color("frame_light", "#d6c896")
	draw_rect(Rect2(Vector2.ZERO, size_px * s), outer)
	draw_rect(Rect2(Vector2(1, 1) * s, (size_px - Vector2(2, 2)) * s), gold)
	draw_rect(Rect2(Vector2(1, 1) * s, Vector2(size_px.x - 2, 1) * s), light)
	draw_rect(Rect2(Vector2(1, 1) * s, Vector2(1, size_px.y - 2) * s), light)
	draw_rect(Rect2(Vector2(t, t) * s, (size_px - Vector2(t, t) * 2.0) * s), outer)
	draw_rect(Rect2(Vector2(t + 1, t + 1) * s, (size_px - Vector2(t + 1, t + 1) * 2.0) * s), back)


## Grietas: en el tercio (de las fases) de cada fase pasada, de derecha a
## izquierda, un zigzag que baja desde el borde de arriba y otro que sube desde
## el de abajo (sin tapar el texto ni los segmentos).
func _draw_cracks(size_px: Vector2) -> void:
	var s: float = _scale
	var crack: Color = _color("crack", "#180f20")
	var light: Color = _color("frame_light", "#d6c896")
	var t: float = float(_cfg.get("frame_thickness_px", 3))
	var depth: float = float(_cfg.get("crack_depth_px", 4))
	var phases: int = maxi(_hits.size(), 1)
	for k: int in get_frame_cracks():
		var third: int = phases - 1 - k
		var cx: float = roundf(size_px.x * (float(third) + 0.5) / float(phases))
		var top := PackedVector2Array([Vector2(cx, 0), Vector2(cx + 2, t * 0.5), Vector2(cx - 1, t),
				Vector2(cx + 1, t + depth * 0.5), Vector2(cx - 1, t + depth)])
		var bottom := PackedVector2Array([Vector2(cx + 3, size_px.y), Vector2(cx + 1, size_px.y - t * 0.5),
				Vector2(cx + 4, size_px.y - t), Vector2(cx + 2, size_px.y - t - depth * 0.5)])
		for line: PackedVector2Array in [top, bottom]:
			var pts := PackedVector2Array()
			for v: Vector2 in line:
				pts.append(v * s)
			draw_polyline(pts, crack, s)
			# Canto roto: un pixel claro junto a la grieta, sobre el dorado.
			draw_rect(Rect2((line[1] + Vector2(1, 0)) * s, Vector2(1, 1) * s), light)


## Camara (style "portrait", icon_shape "camera"): visor, cuerpo y lente.
func _draw_camera_icon(at: Vector2, w: float) -> void:
	var s: float = _scale
	var body: Color = _color("icon", "#d6c896")
	var lens: Color = _color("back", "#180f20")
	var h: float = roundf(w * 0.7)
	draw_rect(Rect2((at + Vector2(roundf(w * 0.25), 0)) * s, Vector2(roundf(w * 0.35), 2) * s), body)
	draw_rect(Rect2((at + Vector2(0, 2)) * s, Vector2(w, h - 2) * s), body)
	draw_circle((at + Vector2(w * 0.5, 2.0 + (h - 2.0) * 0.5)) * s, (h - 2.0) * 0.32 * s, lens)


## Barra de reproduccion (style "playback"): capitulos por fase, relleno hasta
## lo que queda y cabezal redondo.
func _draw_playback(n: int, fill: Color, shade: Color, empty: Color, text_c: Color, back: Color) -> void:
	var s: float = _scale
	var x0: float = float(_cfg.get("bar_x_px", 22))
	var bar_w: float = float(_cfg.get("bar_width_px", 150))
	var y: float = float(_cfg.get("bar_y_px", 18))
	var h: float = float(_cfg.get("segment_height_px", 4))
	var gap: float = float(_cfg.get("chapter_gap_px", 2))
	var knob: float = float(_cfg.get("knob_radius_px", 4))
	var fill_x: float = x0 + bar_w * get_playback_fraction()
	var lost_x: float = x0 + bar_w * float(_remaining + 1) / float(n)
	var start: int = 0
	for p: int in _hits.size():
		var a: float = x0 + bar_w * float(start) / float(n)
		var b: float = x0 + bar_w * float(start + _hits[p]) / float(n)
		if p < _hits.size() - 1:
			b -= gap
		start += _hits[p]
		# Pista hueca del capitulo.
		draw_rect(Rect2(Vector2(a, y) * s, Vector2(b - a, h) * s), empty, false, s * 0.5)
		# Relleno (lo que queda por reproducir), con su sombra abajo.
		var fb: float = minf(b, fill_x)
		if fb > a:
			draw_rect(Rect2(Vector2(a, y) * s, Vector2(fb - a, h) * s), fill)
			draw_rect(Rect2(Vector2(a, y + h - 1.0) * s, Vector2(fb - a, 1.0) * s), shade)
		# El golpe recien dado destella en blanco.
		if _hit_flash > 0.0 and _lost_segment >= 0:
			var la: float = maxf(a, fill_x)
			var lb: float = minf(b, lost_x)
			if lb > la:
				draw_rect(Rect2(Vector2(la, y) * s, Vector2(lb - la, h) * s), text_c)
	# Cabezal: circulo con borde oscuro al final del relleno.
	var center := Vector2(fill_x, y + h * 0.5) * s
	draw_circle(center, (knob + 1.0) * s, back)
	draw_circle(center, knob * s, text_c)


func _load(path: String) -> Resource:
	if path.is_empty() or not ResourceLoader.exists(path):
		return null
	return load(path)
