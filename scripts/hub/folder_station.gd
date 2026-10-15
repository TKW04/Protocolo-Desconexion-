## Carpeta de un mundo en el hub (docs/propuesta-hub-y-guardado.md §3.3; paso
## 7 de §6.2): un HubStation de 2x2 tiles sobre su repisa de una via. Valores en
## la seccion folders de data/hub.json; estado de HubWorlds.
## - Arte: SpriteFrames folder_frames (animaciones locked, available y
##   completed segun HubWorlds.folder_state) y el numero del mundo en el hueco
##   central (fuente de textos, color por estado).
## - Disponible o completada: con Isak cerca (de pie en la repisa) sale la
##   tecla del pulso; el pulso abre el FolderPanel con Isak de espaldas.
## - Bloqueada: no abre el panel; con Isak cerca sale «Sin descargar» en lugar
##   de la tecla.
## - Al elegir un subnivel: cierra el panel, Isak sigue de espaldas (la estacion
##   queda OPEN) y emite level_chosen; HubRoom hace el resto (vortice de salida
##   y carga del nivel).
class_name FolderStation
extends HubStation

## Se eligio entrar al subnivel `level_id` desde esta carpeta.
signal level_chosen(station: FolderStation, level_id: StringName)

## Mundo de la carpeta (entrada de worlds de data/hub.json). Se da antes de
## anadirla al arbol.
var world_entry: Dictionary = {}

var _folders: Dictionary = HubData.section("folders")
var _locked_root: Node2D
var _number: Label
var _shown_state: StringName = &""
var _entering: StringName = &""


func _ready() -> void:
	super._ready()
	_build_folder()
	refresh_state()


# --- Consultas ---

## Estado de la carpeta (HubWorlds.STATE_*).
func get_folder_state() -> StringName:
	return HubWorlds.folder_state(world_entry)


func is_locked() -> bool:
	return get_folder_state() == HubWorlds.STATE_LOCKED


func get_folder_panel() -> FolderPanel:
	return get_panel() as FolderPanel


## Aviso «Sin descargar» visible (carpeta bloqueada con Isak cerca).
func is_locked_hint_visible() -> bool:
	return _locked_root != null and _locked_root.visible


func get_locked_hint_text() -> String:
	return (_locked_root.get_node(^"Text") as Label).text if _locked_root != null else ""


## Texto del numero del mundo en el hueco de la carpeta.
func get_number_text() -> String:
	return _number.text if _number != null else ""


## Subnivel elegido al que se esta entrando (vacio si ninguno).
func get_entering_level() -> StringName:
	return _entering


## Animacion mostrada por el arte (estado de la carpeta).
func get_folder_animation() -> StringName:
	var sprite := _visual as AnimatedSprite2D
	return sprite.animation if sprite != null else &""


# --- Acciones ---

## Vuelve a leer el estado (tras cambiar el progreso) y actualiza el arte.
func refresh_state() -> void:
	_apply_visuals()


## Bloqueada: el pulso no la abre. Ademas, solo con Isak cerca (de pie en la
## repisa), para que un pulso desde el dock no la abra.
func receive_pulse(area: Area2D) -> bool:
	if is_locked() or not is_player_near():
		return false
	return super.receive_pulse(area)


func open(isak: Isak) -> bool:
	if is_locked():
		return false
	_entering = &""
	return super.open(isak)


# --- HubStation ---

func _create_panel() -> HubPanel:
	var panel := FolderPanel.new()
	panel.world_entry = world_entry
	panel.level_chosen.connect(_on_level_chosen)
	return panel


func _apply_visuals() -> void:
	super._apply_visuals()
	if _locked_root == null:
		return
	var locked: bool = is_locked()
	if locked:
		_key_root.visible = false
	_locked_root.visible = locked and get_state() == State.PROMPT
	var state: StringName = get_folder_state()
	if state != _shown_state:
		_shown_state = state
		var colors: Dictionary = _folders.get("number_colors", {})
		(_number.material as ShaderMaterial).set_shader_parameter(&"target_color",
			HubData.color(String(colors.get(String(state), "texto_claro"))))


func _show_visual_state(_value: StringName) -> void:
	var sprite := _visual as AnimatedSprite2D
	if sprite == null or sprite.sprite_frames == null:
		return
	var state: StringName = get_folder_state()
	if sprite.sprite_frames.has_animation(state) and (sprite.animation != state or not sprite.is_playing()):
		sprite.play(state)


# --- Interno ---

func _on_level_chosen(level_id: StringName) -> void:
	if get_state() != State.OPEN or not _entering.is_empty():
		return
	_entering = level_id
	get_panel().close()
	level_chosen.emit(self, level_id)


func _build_folder() -> void:
	var panel_cfg: Dictionary = HubData.section("panel")
	var font: Font = load(String(panel_cfg.get("font", "res://assets/sprites/ui/text_font.fnt"))) as Font
	var font_size: int = int(panel_cfg.get("font_size", 12))
	var r: Array = _folders.get("number_rect_px", [24, 44, 78, 38])
	var scale_n: float = float(_folders.get("number_scale", 2))
	_number = Label.new()
	_number.name = "Number"
	_number.text = str(int(world_entry.get("world", 0)))
	_number.add_theme_font_override(&"font", font)
	_number.add_theme_font_size_override(&"font_size", font_size)
	_number.add_theme_color_override(&"font_color", Color.WHITE)
	_number.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_number.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_number.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_number.scale = Vector2.ONE * scale_n
	_number.position = Vector2(float(r[0]), float(r[1]))
	_number.size = Vector2(float(r[2]), float(r[3])) / scale_n
	var material := ShaderMaterial.new()
	material.shader = load(String(panel_cfg.get("key_swap_shader", "res://assets/shaders/hud_key_swap.gdshader"))) as Shader
	material.set_shader_parameter(&"key_color", Color.html(String(panel_cfg.get("font_key_color", "#f2f4f8"))))
	material.set_shader_parameter(&"target_color", HubData.color("texto_claro"))
	_number.material = material
	add_child(_number)
	var station_cfg: Dictionary = HubData.section("station")
	var top: float = prompt_top_px if prompt_top_px >= 0.0 else 0.0
	_locked_root = PulsePrompt.make_plate(self, "LockedHint",
		String(_folders.get("texts", {}).get("locked_text", "")), font, font_size,
		int(station_cfg.get("font_scale", 2)),
		"#" + HubData.color(String(station_cfg.get("label_plate_color", "fondo_profundo"))).to_html(false),
		"#" + HubData.color(String(station_cfg.get("label_border_color", "borde"))).to_html(false),
		float(station_cfg.get("label_padding_px", 3)), get_size().x, top - float(station_cfg.get("key_gap_px", 8)))
	_locked_root.visible = false
	_shown_state = &""
