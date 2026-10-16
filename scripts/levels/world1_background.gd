## Fondo del Mundo 1: pantalla de bloqueo con relojes, avisos y edificios en
## parallax (PROPUESTA de V10). Crea un Parallax2D por capa con los valores de
## data/world1_background.json (textura, scroll_scale, repeat_size). Va en el
## lienzo del mundo con z_index negativo, por debajo de los tiles y de la capa
## del Debug (que lo tine).
##
## Modo vertical (`vertical`, 2026-10-16; niveles con camera.vertical "tower",
## lo pone tools/build_level.py): cada capa usa su bloque "tower" del JSON
## (scroll_scale y repeat_size con Y): el fondo se desplaza tambien en Y y se
## repite en vertical. Mismas imagenes (ver _notes del JSON).
class_name World1Background
extends Node2D

const DEFAULT_PATH: String = "res://data/world1_background.json"

@export_file("*.json") var data_path: String = DEFAULT_PATH
## Nivel vertical (torre): capas con desplazamiento y repeticion en Y.
@export var vertical: bool = false

var _layers: Array[Parallax2D] = []


func _ready() -> void:
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(data_path))
	if not data is Dictionary:
		push_error("World1Background: no se pudo leer %s" % data_path)
		return
	z_index = int(data.get("z_index", -100))
	z_as_relative = false
	for layer_data: Dictionary in data.get("layers", []):
		_layers.append(_make_layer(layer_data))


## Capas en orden (de atras hacia delante).
func get_layers() -> Array[Parallax2D]:
	return _layers


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
