## Carpeta de un mundo en el hub (docs/propuesta-hub-y-guardado.md §3.3; paso
## 7 de §6.2): un HubStation de 2x2 tiles sobre su repisa de una via. Valores en
## la seccion folders de data/hub.json; estado de HubWorlds.
## - Arte: SpriteFrames folder_frames (animaciones locked, available y
##   completed segun HubWorlds.folder_state) y el numero del mundo en el hueco
##   central (fuente de textos, color por estado).
## - Miniatura del mundo (2026-10-15): si la entrada del mundo trae `miniature`
##   (icono de 16x16; Mundo 1: campana) y la carpeta no esta bloqueada, sale en
##   miniature_rect_px junto al numero (que pasa a number_rect_with_miniature_px).
##   Bloqueada: sin miniatura, numero centrado. Sin insignia de vuelta.
## - Disponible o completada: con Isak cerca (de pie en la repisa) sale la
##   tecla del pulso; el pulso abre el FolderPanel con Isak de espaldas.
## - Bloqueada: no abre el panel; con Isak cerca sale «Sin descargar» en lugar
##   de la tecla.
## - Papelera llena tras un game over (2026-10-16, propuesta de asistentes
##   §2.5): ninguna carpeta se abre; con Isak cerca sale «Recupera tus archivos
##   de la papelera» (folders.texts.trash_blocked_text) en lugar de la tecla.
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
var _trash_root: Node2D
var _number: Label
var _miniature: Sprite2D
var _shown_state: StringName = &""
var _entering: StringName = &""


func _ready() -> void:
	super._ready()
	_build_folder()
	EventBus.trash_changed.connect(_on_trash_changed)
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


## Bloqueada por la papelera llena (game over pendiente de recuperar).
func is_blocked_by_trash() -> bool:
	return GameState.has_trash_pending()


## Aviso «Recupera tus archivos de la papelera» visible (con Isak cerca).
func is_trash_hint_visible() -> bool:
	return _trash_root != null and _trash_root.visible


func get_trash_hint_text() -> String:
	return (_trash_root.get_node(^"Text") as Label).text if _trash_root != null else ""


## Texto del numero del mundo en el hueco de la carpeta.
func get_number_text() -> String:
	return _number.text if _number != null else ""


## Miniatura del mundo visible (carpeta no bloqueada con `miniature`).
func is_miniature_visible() -> bool:
	return _miniature != null and _miniature.visible


func get_miniature() -> Sprite2D:
	return _miniature


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
	if is_locked() or is_blocked_by_trash() or not is_player_near():
		return false
	return super.receive_pulse(area)


func open(isak: Isak) -> bool:
	if is_locked() or is_blocked_by_trash():
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
	var blocked: bool = not locked and is_blocked_by_trash()
	if locked or blocked:
		_key_root.visible = false
	_locked_root.visible = locked and get_state() == State.PROMPT
	if _trash_root != null:
		_trash_root.visible = blocked and get_state() == State.PROMPT
	var mini: bool = _miniature != null and not locked
	if _miniature != null:
		_miniature.visible = mini
	_place_number(mini)
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

func _on_trash_changed(_pending: bool) -> void:
	refresh_state()


func _on_level_chosen(level_id: StringName) -> void:
	if get_state() != State.OPEN or not _entering.is_empty():
		return
	_entering = level_id
	get_panel().close()
	level_chosen.emit(self, level_id)


## Numero centrado en el hueco o, con miniatura, a su derecha.
func _place_number(with_miniature: bool) -> void:
	if _number == null:
		return
	var key: String = "number_rect_with_miniature_px" if with_miniature else "number_rect_px"
	var r: Array = _folders.get(key, _folders.get("number_rect_px", [24, 44, 78, 38]))
	_number.position = Vector2(float(r[0]), float(r[1]))
	_number.size = Vector2(float(r[2]), float(r[3])) / _number.scale.x


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
	var material := ShaderMaterial.new()
	material.shader = load(String(panel_cfg.get("key_swap_shader", "res://assets/shaders/hud_key_swap.gdshader"))) as Shader
	material.set_shader_parameter(&"key_color", Color.html(String(panel_cfg.get("font_key_color", "#f2f4f8"))))
	material.set_shader_parameter(&"target_color", HubData.color("texto_claro"))
	_number.material = material
	add_child(_number)
	_place_number(false)
	var mini_path: String = String(world_entry.get("miniature", ""))
	if not mini_path.is_empty() and ResourceLoader.exists(mini_path):
		var tex := load(mini_path) as Texture2D
		var mr: Array = _folders.get("miniature_rect_px", [34, 48, 32, 32])
		_miniature = Sprite2D.new()
		_miniature.name = "Miniature"
		_miniature.texture = tex
		_miniature.centered = false
		_miniature.position = Vector2(float(mr[0]), float(mr[1]))
		_miniature.scale = Vector2(float(mr[2]), float(mr[3])) / tex.get_size()
		_miniature.visible = false
		add_child(_miniature)
	var station_cfg: Dictionary = HubData.section("station")
	var top: float = prompt_top_px if prompt_top_px >= 0.0 else 0.0
	_locked_root = PulsePrompt.make_plate(self, "LockedHint",
		String(_folders.get("texts", {}).get("locked_text", "")), font, font_size,
		int(station_cfg.get("font_scale", 2)),
		"#" + HubData.color(String(station_cfg.get("label_plate_color", "fondo_profundo"))).to_html(false),
		"#" + HubData.color(String(station_cfg.get("label_border_color", "borde"))).to_html(false),
		float(station_cfg.get("label_padding_px", 3)), get_size().x, top - float(station_cfg.get("key_gap_px", 8)))
	_locked_root.visible = false
	_trash_root = PulsePrompt.make_plate(self, "TrashHint",
		String(_folders.get("texts", {}).get("trash_blocked_text", "")), font, font_size,
		int(station_cfg.get("font_scale", 2)),
		"#" + HubData.color(String(station_cfg.get("label_plate_color", "fondo_profundo"))).to_html(false),
		"#" + HubData.color(String(station_cfg.get("label_border_color", "borde"))).to_html(false),
		float(station_cfg.get("label_padding_px", 3)), get_size().x, top - float(station_cfg.get("key_gap_px", 8)))
	_trash_root.visible = false
	_shown_state = &""
