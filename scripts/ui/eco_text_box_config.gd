## Ajustes del cuadro de texto de Eco leidos de data/eco_text_box.json (aspecto,
## medidas en pixeles de arte, tiempos y rutas). Ver "_notes" del JSON.
class_name EcoTextBoxConfig
extends RefCounted

const DEFAULT_PATH: String = "res://data/eco_text_box.json"
## Color si falta en el JSON (magenta: se nota).
const MISSING_COLOR: Color = Color.MAGENTA
## Claves del JSON que no son numeros sueltos (se leen aparte).
const SPECIAL_KEYS: Array[String] = ["colors", "assets", "speakers", "speaker_name", "font", "key_swap_shader",
	"confirm_hint_text", "inline_icons", "speaker_styles", "world_icons"]

var layer: int = 11
## Pixeles de pantalla por pixel de arte (entero).
var pixel_scale: int = 2
var top_px: int = 22
## Con un jefe activo (2026-10-22: las lineas por el jefe tapaban su barra y el
## badge) el cuadro va abajo, a boss_bottom_px del borde inferior (px de arte).
var boss_bottom_px: int = 8
## Ancho maximo del panel; el panel se ajusta al texto sin bajar de min_width_px.
var width_px: int = 280
var min_width_px: int = 160
var padding_px: int = 6
var icon_gap_px: int = 6
var panel_margin_px: int = 3
var font_size: int = 12
var chars_per_second: float = 40.0
var default_duration_s: float = 4.0
var hold_base_s: float = 1.5
var hold_per_char_s: float = 0.06
var fade_in_s: float = 0.12
var fade_out_s: float = 0.2
var speaker_name: String = "Eco"
## Indicacion de la tecla que cierra una linea importante (esquina inferior
## derecha del cuadro, parpadea a confirm_hint_blink_hz cuando el texto ya se
## ha escrito). El proyecto aun no distingue teclado y mando: texto generico.
var confirm_hint_text: String = "▼ [Espacio]"
var confirm_hint_blink_hz: float = 2.0
var font_path: String = ""
var key_swap_shader_path: String = ""
var colors: Dictionary[StringName, Color] = {}
## Otros que hablan en el cuadro (2026-10-16: Notas en el hub): id ->
## {name, icon (ruta de un PNG de 16x16), color (hex del nombre)}. Sin id (o
## id vacio) habla Eco con speaker_name, el icono `icon` y colors.speaker.
var speakers: Dictionary[StringName, Dictionary] = {}
## Estilos de texto por interlocutor (2026-10-17, tanda H3 del paso 14 del 1-2;
## `style` de cada entrada de speakers): id -> {font (ruta de otra fuente con las
## mismas metricas), panel (PNG de 16x16 del nine-patch), colors {body,
## confirm_hint} (color del texto y de la indicacion de cierre, por el shader de
## cambio de color), chars_per_second, instant_chars (caracteres que aparecen de
## golpe: una racha seguida de ellos se escribe en un solo paso)}. Lo que falta
## sale del estilo de Eco (el resto del JSON). Sin estilo o desconocido = Eco.
var speaker_styles: Dictionary[StringName, Dictionary] = {}
## Nombre -> {path, frame_size, columns, rows}.
var assets: Dictionary[StringName, Dictionary] = {}
## Iconos en linea (2026-10-17; marcador {icono:<id>}): id -> {glyph (caracter de
## la fuente con el ancho del icono), asset (clave de assets), offset_px ([x, y]
## desde la esquina superior izquierda del glifo)}.
var inline_icons: Dictionary[StringName, Dictionary] = {}
## Icono de Eco por mundo (2026-10-28; Mundo 4: tres puntos, Eco no es la esfera): numero de mundo (texto) ->
## ruta de un PNG de 16x16. Sin entrada, el icono `icon` de assets.
var world_icons: Dictionary[String, String] = {}

static var _cached: EcoTextBoxConfig


## Config compartida (se lee una vez).
static func shared() -> EcoTextBoxConfig:
	if _cached == null:
		_cached = load_from_file()
		if _cached == null:
			_cached = EcoTextBoxConfig.new()
	return _cached


static func load_from_file(path: String = DEFAULT_PATH) -> EcoTextBoxConfig:
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not data is Dictionary:
		push_error("EcoTextBoxConfig: no se pudo leer '%s'" % path)
		return null
	var config := EcoTextBoxConfig.new()
	var dict: Dictionary = data
	for key: String in dict:
		if key.begins_with("_") or key in SPECIAL_KEYS:
			continue
		if not key in config:
			push_error("EcoTextBoxConfig: clave desconocida '%s'" % key)
			continue
		var current: Variant = config.get(key)
		config.set(key, int(dict[key]) if current is int else float(dict[key]))
	config.speaker_name = dict.get("speaker_name", config.speaker_name)
	config.confirm_hint_text = dict.get("confirm_hint_text", config.confirm_hint_text)
	config.font_path = dict.get("font", "")
	config.key_swap_shader_path = dict.get("key_swap_shader", "")
	var raw_colors: Dictionary = dict.get("colors", {})
	for name: String in raw_colors:
		config.colors[StringName(name)] = Color.html(raw_colors[name])
	var raw_speakers: Dictionary = dict.get("speakers", {})
	for id: String in raw_speakers:
		if raw_speakers[id] is Dictionary:
			config.speakers[StringName(id)] = raw_speakers[id]
	var raw_styles: Dictionary = dict.get("speaker_styles", {})
	for id: String in raw_styles:
		if raw_styles[id] is Dictionary:
			config.speaker_styles[StringName(id)] = raw_styles[id]
	var raw_icons: Dictionary = dict.get("inline_icons", {})
	for id: String in raw_icons:
		if raw_icons[id] is Dictionary:
			config.inline_icons[StringName(id)] = raw_icons[id]
	var raw_world_icons: Dictionary = dict.get("world_icons", {})
	for w: String in raw_world_icons:
		config.world_icons[w] = String(raw_world_icons[w])
	var raw_assets: Dictionary = dict.get("assets", {})
	for name: String in raw_assets:
		config.assets[StringName(name)] = raw_assets[name]
	return config


## Estilo de texto del interlocutor `speaker` (vacio = Eco, sin estilo propio).
func style_for(speaker: StringName) -> Dictionary:
	var info: Dictionary = speakers.get(speaker, {})
	return speaker_styles.get(StringName(String(info.get("style", ""))), {})


func color(name: StringName) -> Color:
	return colors.get(name, MISSING_COLOR)


## Icono de Eco en el mundo `world` (world_icons) o el de siempre.
func eco_icon_texture(world: int) -> Texture2D:
	var path: String = world_icons.get(str(world), "")
	if not path.is_empty() and ResourceLoader.exists(path):
		return load(path) as Texture2D
	return asset_texture(&"icon")


func asset_texture(name: StringName) -> Texture2D:
	var info: Dictionary = assets.get(name, {})
	if info.is_empty():
		push_error("EcoTextBoxConfig: asset desconocido '%s'" % name)
		return null
	return load(info.path) as Texture2D


func asset_frame_size(name: StringName) -> Vector2i:
	var frame: Array = assets.get(name, {}).get("frame_size", [0, 0])
	return Vector2i(int(frame[0]), int(frame[1]))


func load_font() -> Font:
	return load(font_path) as Font


## Segundos que el texto completo queda en pantalla tras escribirse: al menos
## `duration_s` (o default_duration_s si es <= 0) y mas para textos largos.
func hold_time(char_count: int, duration_s: float = -1.0) -> float:
	var minimum: float = duration_s if duration_s > 0.0 else default_duration_s
	return maxf(minimum, hold_base_s + hold_per_char_s * char_count)


func new_key_swap_material(key: Color, target: Color) -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.shader = load(key_swap_shader_path) as Shader
	material.set_shader_parameter(&"key_color", key)
	material.set_shader_parameter(&"target_color", target)
	return material
