## Decorado por script (tipo `decor` del catalogo del Mundo 1; 2026-10-22,
## defectos visuales de las capturas del 1-3: sala «Ajustes» sin sus paneles,
## ranura del banner obligatorio fuera de pantalla desde la entrada y reloj de la
## pantalla de bloqueo del cierre). Dibuja decor_<art>_00.png de
## tools/gen_world1_dnd.py con su esquina superior izquierda en el origen del nodo.
##
## Solo decorado: sin colision, sin Q ni ficha del album, sin estado y sin efecto
## en el validador. z_index de la seccion decor (por art si lo tiene).
class_name DecorSprite
extends Sprite2D

const GROUP: StringName = &"decor"

## Id propio (opcional).
@export var object_id: StringName = &""
## Dibujo (allowed del catalogo: settings_wifi, banner_slot, lock_clock...).
@export var art: StringName = &""

var _config: Dictionary = World1ObjectsConfig.section("decor")


func _ready() -> void:
	add_to_group(GROUP)
	centered = false
	var by_art: Dictionary = _config.get("z_index_by_art", {})
	z_index = int(by_art.get(String(art), _config.get("z_index", -2)))
	texture = load(get_texture_path()) as Texture2D


## Ruta del PNG del dibujo.
func get_texture_path() -> String:
	return "%sdecor_%s_00.png" % [String(_config.get("texture_dir", "res://assets/sprites/props/dnd/")), art]
