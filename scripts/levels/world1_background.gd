## Fondo del Mundo 1: pantalla de bloqueo con relojes, avisos y edificios en
## parallax (PROPUESTA de V10). Crea un Parallax2D por capa con los valores de
## data/world1_background.json (textura, scroll_scale, repeat_size). Va en el
## lienzo del mundo con z_index negativo, por debajo de los tiles y de la capa
## del Debug (que lo tine).
##
## Modo vertical (`vertical`, 2026-10-16; niveles con camera.vertical "tower",
## lo pone tools/build_level.py): cada capa usa su bloque "tower" del JSON
## (scroll_scale y repeat_size con Y): el fondo se desplaza tambien en Y y se
## repite en vertical (ver _notes del JSON). Desde el 2026-10-16 (paso 13 del
## 1-2) las capas lejanas quedan fijas en Y y la capa «Fachada» (tower_only,
## tools/gen_world1_facade.py) se mueve con el nivel y se repite sin costura;
## encima, una pestana con su rotulo en lo alto de cada piso (tab_labels /
## tab_bands, que pone tools/build_level.py desde los tramos «Piso N: <rotulo>»).
class_name World1Background
extends Node2D

const DEFAULT_PATH: String = "res://data/world1_background.json"

@export_file("*.json") var data_path: String = DEFAULT_PATH
## Nivel vertical (torre): capas con desplazamiento y repeticion en Y.
@export var vertical: bool = false
## Rotulos de las pestanas de la fachada (modo torre), uno por piso.
@export var tab_labels: PackedStringArray = PackedStringArray()
## Bandas de los pisos de cada pestana: (borde de arriba, borde de abajo) en px.
@export var tab_bands: PackedVector2Array = PackedVector2Array()
## Centro horizontal de las pestanas (px; el centro del nivel).
@export var tab_center_x: float = 0.0

var _layers: Array[Parallax2D] = []
var _tabs: Parallax2D = null


func _ready() -> void:
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(data_path))
	if not data is Dictionary:
		push_error("World1Background: no se pudo leer %s" % data_path)
		return
	z_index = int(data.get("z_index", -100))
	z_as_relative = false
	for layer_data: Dictionary in data.get("layers", []):
		if bool(layer_data.get("tower_only", false)) and not vertical:
			continue
		_layers.append(_make_layer(layer_data))
	if vertical and not tab_labels.is_empty():
		_make_tabs(data.get("tabs", {}) as Dictionary)


## Capas en orden (de atras hacia delante).
func get_layers() -> Array[Parallax2D]:
	return _layers


## Capa de las pestanas (null si no hay).
func get_tabs_layer() -> Parallax2D:
	return _tabs


## Pestanas creadas (Sprite2D con metadata label), de abajo arriba segun tab_labels.
func get_tabs() -> Array[Sprite2D]:
	var out: Array[Sprite2D] = []
	if _tabs != null:
		for child: Node in _tabs.get_children():
			out.append(child as Sprite2D)
	return out


func get_layer(layer_name: String) -> Parallax2D:
	for layer: Parallax2D in _layers:
		if layer.name == layer_name:
			return layer
	return null


func _make_layer(layer_data: Dictionary) -> Parallax2D:
	var layer := Parallax2D.new()
	layer.name = String(layer_data["name"])
	if vertical and layer_data.get("tower") is Dictionary:
		layer_data = layer_data.merged(layer_data["tower"], true)
	var s: Array = layer_data.get("scroll_scale", [1, 1])
	layer.scroll_scale = Vector2(float(s[0]), float(s[1]))
	var r: Array = layer_data.get("repeat_size", [0, 0])
	layer.repeat_size = Vector2(float(r[0]), float(r[1]))
	layer.repeat_times = int(layer_data.get("repeat_times", 1))
	var sprite := Sprite2D.new()
	sprite.name = "Sprite2D"
	sprite.texture = load(String(layer_data["texture"])) as Texture2D
	sprite.centered = false
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	layer.add_child(sprite)
	add_child(layer)
	return layer


## Pestanas: un Parallax2D que se mueve con el nivel (scroll 1) con una pestana
## centrada en lo alto de la banda de cada piso con imagen para su rotulo.
func _make_tabs(tabs_data: Dictionary) -> void:
	var textures: Dictionary = tabs_data.get("textures", {}) as Dictionary
	var top: float = float(tabs_data.get("top_px", 8.0))
	_tabs = Parallax2D.new()
	_tabs.name = "Pestanas"
	_tabs.scroll_scale = Vector2.ONE
	for i: int in mini(tab_labels.size(), tab_bands.size()):
		var label: String = tab_labels[i]
		if not textures.has(label):
			continue
		var sprite := Sprite2D.new()
		sprite.name = "Tab%d" % i
		sprite.texture = load(String(textures[label])) as Texture2D
		sprite.centered = false
		sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		sprite.position = Vector2(roundf(tab_center_x - sprite.texture.get_width() * 0.5), tab_bands[i].x + top)
		sprite.set_meta(&"label", label)
		_tabs.add_child(sprite)
	add_child(_tabs)
