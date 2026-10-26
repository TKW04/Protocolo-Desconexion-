## Contador de likes del HUD (2026-10-26, paso 2 de docs/propuesta-mundo-3.md §2.3
## y §8): corazon rosa con borde blanco y la cifra («♥ 12»: el corazon se dibuja,
## la fuente del HUD solo tiene cifras) a la DERECHA de los puntos de atencion
## (ultimo hijo de la fila del HUD), solo en los niveles del Mundo 3 (seccion likes
## de data/hud.json, `world`); oculto en el hub y en los demas mundos.
## Al terminar el nivel (EventBus.level_completed) se vacia (GameState.reset_likes)
## y sale el aviso del sistema «Los likes no se guardan.» (MemoryNotice.show_lines,
## seccion likes.notice de data/world3_objects.json) por encima del fundido de
## salida. La Q de Eco (`hud_likes`) llega con las ayudas (paso 9).
class_name HudLikes
extends HBoxContainer

var _config: Dictionary = {}
var _hud_config: HudConfig
var _icon: Control
var _label: Label
var _world: int = GameState.FIRST_WORLD
var _hub: bool = false
var _likes: int = 0
var _notice: MemoryNotice


## Crea el contador como ultimo hijo de `row` (la fila del HUD) y lo devuelve.
static func attach(row: Container, hud_config: HudConfig) -> HudLikes:
	var node := HudLikes.new()
	node.name = "Likes"
	node.setup(hud_config)
	row.add_child(node)
	return node


func setup(hud_config: HudConfig) -> void:
	_hud_config = hud_config
	_config = hud_config.likes
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_theme_constant_override("separation", int(_config.get("spacing_px", 2)))
	_icon = Control.new()
	_icon.name = "Heart"
	_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var r: float = float(_config.get("heart_px", 4))
	_icon.custom_minimum_size = Vector2(r * 2.0 + 2.0, r * 2.0 + 2.0)
	_icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_icon.draw.connect(_draw_heart)
	add_child(_icon)
	_label = Label.new()
	_label.name = "Count"
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var font: Font = hud_config.load_font()
	if font != null:
		_label.add_theme_font_override("font", font)
	_label.add_theme_font_size_override("font_size", hud_config.font_size)
	_label.add_theme_color_override("font_color", Color.WHITE)
	_label.material = hud_config.new_key_swap_material(
			Color.html(String(_config.get("font_key_color", "#f2f4f8"))), hud_config.color(&"text"))
	_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	add_child(_label)
	_refresh()


func _ready() -> void:
	EventBus.likes_changed.connect(_on_likes_changed)
	EventBus.world_changed.connect(_on_world_changed)
	EventBus.level_completed.connect(_on_level_completed)
	_world = GameState.current_world
	_likes = GameState.likes
	_refresh()


# --- Consultas ---

func is_shown() -> bool:
	return not _hub and _world == int(_config.get("world", 3))


func get_text() -> String:
	return _label.text if _label != null else ""


## Aviso del sistema al terminar el nivel (null si no ha salido).
func get_notice() -> MemoryNotice:
	return _notice if _notice != null and is_instance_valid(_notice) else null


# --- Acciones ---

func set_hub_mode(hub: bool) -> void:
	_hub = hub
	_refresh()


## Fin del nivel: vacia el contador y saca el aviso (publico para las pruebas).
## Devuelve el aviso o null si el contador no se ve (otro mundo, hub).
func finish_level() -> MemoryNotice:
	if not is_shown():
		return null
	GameState.reset_likes()
	var cfg: Dictionary = World3ObjectsConfig.section("likes").get("notice", {}).duplicate(true)
	for key: String in ["text_color", "fill_color", "border_color"]:
		if cfg.has(key) and not String(cfg[key]).begins_with("#"):
			cfg[key] = "#" + World3ObjectsConfig.color(String(cfg[key])).to_html(false)
	var lines := PackedStringArray()
	for line: Variant in cfg.get("lines", []):
		lines.append(String(line))
	_notice = MemoryNotice.show_lines(lines, cfg, _notice_host())
	return _notice


# --- Interno ---

## El aviso sobrevive al nivel (que se libera tras el fundido): va al padre del
## nivel generado (el LevelRunner) si lo hay.
func _notice_host() -> Node:
	var node: Node = get_parent()
	while node != null:
		if node is GeneratedLevel:
			return node.get_parent() if node.get_parent() != null else node
		node = node.get_parent()
	return get_tree().root


func _on_likes_changed(likes: int, _likes_max: int) -> void:
	_likes = likes
	_refresh()


func _on_world_changed(world: int) -> void:
	_world = world
	_refresh()


func _on_level_completed(_level_id: String) -> void:
	finish_level()


func _refresh() -> void:
	visible = is_shown()
	if _label != null:
		_label.text = str(_likes)
	if _icon != null:
		_icon.queue_redraw()


func _draw_heart() -> void:
	var r: float = float(_config.get("heart_px", 4))
	var center: Vector2 = _icon.size * 0.5
	HeartPickup.draw_heart(_icon, center, r + 1.0,
			World3ObjectsConfig.color(String(_config.get("heart_border", "blanco_brillante"))))
	HeartPickup.draw_heart(_icon, center, r, World3ObjectsConfig.color(String(_config.get("heart", "corazon_rosa"))))
