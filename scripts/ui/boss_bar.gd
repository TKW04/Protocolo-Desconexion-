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
	_sync()
	visible = true
	queue_redraw()


## Oculta la barra y suelta el jefe.
func unbind() -> void:
	if _boss != null and is_instance_valid(_boss) and _boss.phase_restarted.is_connected(_on_phase_restarted):
		_boss.phase_restarted.disconnect(_on_phase_restarted)
	_boss = null
	_hide_left = -1.0
	visible = false


func get_boss() -> BossBase:
	return _boss


## Estilo de la barra: "segments" (Alerta Mayor) o "playback" (Autoplay).
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
	queue_redraw()


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
	position = Vector2(roundf((screen.x - size_px.x) * 0.5), float(_cfg.get("top_px", 20)) * _scale)
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
			if lit:
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
