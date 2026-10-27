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
## - Icono grande del mundo (2026-10-26, peticion del usuario): si la entrada del
##   mundo trae `folder_frames`, el arte es ese icono (campana, tarjeta de video,
##   foto) en lugar de la carpeta generica, sin miniatura y con el numero en la
##   placa de abajo a la izquierda (world_number_rect_px). Animacion segun
##   HubWorlds.folder_art_state: locked, available, completed (subniveles
##   superados, sin check) y all_done (TODO obtenido: con check).
## - Disponible o completada: con Isak cerca (de pie en la repisa) sale la
##   tecla del pulso; el pulso abre el FolderPanel con Isak de espaldas.
## - Bloqueada: no abre el panel; con Isak cerca sale «Sin descargar» en lugar
##   de la tecla.
## - Papelera llena tras un game over (2026-10-16, propuesta de asistentes
##   §2.5): ninguna carpeta se abre; con Isak cerca sale «Recupera tus archivos
##   de la papelera» (folders.texts.trash_blocked_text) en lugar de la tecla.
## - Mundos 4-6 (2026-10-27, paso 5 de docs/propuesta-hub-mundos-4-6.md §3.3):
##   un mundo con requires_upgrade bloqueado muestra con Isak cerca una segunda
##   placa bajo «Sin descargar» con la condicion, sin nombres
##   (folders.texts.locked_condition_text, «Completa el mundo anterior»). Con
##   lock_slots (M6 «La Nube»), mientras esta bloqueado lleva encima el candado de
##   5 ranuras (CloudLock), una encendida por cada recuerdo de esa lista obtenido
##   (las capas Cache de los jefes 1-5; solo visual: la disponibilidad es
##   unlocked_by). Sin folder_frames usa la carpeta generica (locked: gris con
##   candado y sin miniatura). Arte del candado PROVISIONAL por codigo (paso 7).
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
var _condition_root: Node2D
var _cloud_lock: _CloudLock
var _number: Label
var _miniature: Sprite2D
var _shown_state: StringName = &""
var _entering: StringName = &""


func _ready() -> void:
	var world_frames: String = String(world_entry.get("folder_frames", ""))
	if not world_frames.is_empty() and ResourceLoader.exists(world_frames):
		frames = world_frames
	super._ready()
	_build_folder()
	EventBus.trash_changed.connect(_on_trash_changed)
	EventBus.memory_obtained.connect(_on_memory_obtained)
	refresh_state()


# --- Consultas ---

## Estado de la carpeta (HubWorlds.STATE_*).
func get_folder_state() -> StringName:
	return HubWorlds.folder_state(world_entry)


## Estado del arte: el de la carpeta o all_done (con check; HubWorlds.folder_art_state).
func get_art_state() -> StringName:
	return HubWorlds.folder_art_state(world_entry)


## Con el check de TODO obtenido.
func is_check_shown() -> bool:
	return get_folder_animation() == HubWorlds.STATE_ALL_DONE


## Usa el icono grande del mundo (folder_frames de worlds).
func has_world_art() -> bool:
	var world_frames: String = String(world_entry.get("folder_frames", ""))
	return not world_frames.is_empty() and frames == world_frames


func is_locked() -> bool:
	return get_folder_state() == HubWorlds.STATE_LOCKED


func get_folder_panel() -> FolderPanel:
	return get_panel() as FolderPanel


## Aviso «Sin descargar» visible (carpeta bloqueada con Isak cerca).
func is_locked_hint_visible() -> bool:
	return _locked_root != null and _locked_root.visible


func get_locked_hint_text() -> String:
	return (_locked_root.get_node(^"Text") as Label).text if _locked_root != null else ""


## Segunda linea con la condicion (mundo con requires_upgrade bloqueado, Isak cerca).
func is_locked_condition_visible() -> bool:
	return _condition_root != null and _condition_root.visible


func get_locked_condition_text() -> String:
	return (_condition_root.get_node(^"Text") as Label).text if _condition_root != null else ""


## Candado de ranuras (lock_slots; M6) visible: la carpeta esta bloqueada.
func is_cloud_lock_visible() -> bool:
	return _cloud_lock != null and _cloud_lock.visible


## Ranuras del candado (tamano de lock_slots; 0 sin candado).
func get_lock_slot_count() -> int:
	return (world_entry.get("lock_slots", []) as Array).size()


## Ranuras encendidas: recuerdos de lock_slots obtenidos.
func get_lock_slots_lit() -> int:
	var lit: int = 0
	for id: Variant in world_entry.get("lock_slots", []):
		if GameState.has_memory(StringName(String(id))):
			lit += 1
	return lit


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
	if _condition_root != null:
		_condition_root.visible = _locked_root.visible
	if _cloud_lock != null:
		_cloud_lock.visible = locked
		_cloud_lock.queue_redraw()
	if _trash_root != null:
		_trash_root.visible = blocked and get_state() == State.PROMPT
	var mini: bool = _miniature != null and not locked
	if _miniature != null:
		_miniature.visible = mini
	_place_number(mini)
	var state: StringName = get_art_state()
	if state != _shown_state:
		_shown_state = state
		var colors: Dictionary = _folders.get("number_colors", {})
		(_number.material as ShaderMaterial).set_shader_parameter(&"target_color",
			HubData.color(String(colors.get(String(state), "texto_claro"))))


func _show_visual_state(_value: StringName) -> void:
	var sprite := _visual as AnimatedSprite2D
	if sprite == null or sprite.sprite_frames == null:
		return
	var state: StringName = get_art_state()
	if not sprite.sprite_frames.has_animation(state):
		state = get_folder_state()
	if sprite.sprite_frames.has_animation(state) and (sprite.animation != state or not sprite.is_playing()):
		sprite.play(state)


# --- Interno ---

func _on_trash_changed(_pending: bool) -> void:
	refresh_state()


func _on_memory_obtained(_id: StringName) -> void:
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
	if has_world_art():
		key = "world_number_rect_px"
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
	# Con el icono grande del mundo no hay miniatura (el icono ya es el mundo).
	if not mini_path.is_empty() and ResourceLoader.exists(mini_path) and not has_world_art():
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
	var hint_bottom: float = top - float(station_cfg.get("key_gap_px", 8))
	var condition: String = String(_folders.get("texts", {}).get("locked_condition_text", ""))
	if not HubWorlds.required_upgrade(world_entry).is_empty() and not condition.is_empty():
		# Segunda linea (debajo): la condicion; «Sin descargar» sube encima.
		_condition_root = PulsePrompt.make_plate(self, "LockedCondition", condition, font, font_size,
			int(station_cfg.get("font_scale", 2)),
			"#" + HubData.color(String(station_cfg.get("label_plate_color", "fondo_profundo"))).to_html(false),
			"#" + HubData.color(String(station_cfg.get("label_border_color", "borde"))).to_html(false),
			float(station_cfg.get("label_padding_px", 3)), get_size().x, hint_bottom)
		_condition_root.visible = false
		(_condition_root.get_node(^"Text") as Label).add_theme_color_override(&"font_color",
			HubData.color("texto_tenue"))
		hint_bottom = _condition_root.position.y - 6.0
	_locked_root = PulsePrompt.make_plate(self, "LockedHint",
		String(_folders.get("texts", {}).get("locked_text", "")), font, font_size,
		int(station_cfg.get("font_scale", 2)),
		"#" + HubData.color(String(station_cfg.get("label_plate_color", "fondo_profundo"))).to_html(false),
		"#" + HubData.color(String(station_cfg.get("label_border_color", "borde"))).to_html(false),
		float(station_cfg.get("label_padding_px", 3)), get_size().x, hint_bottom)
	_locked_root.visible = false
	if get_lock_slot_count() > 0:
		_cloud_lock = _CloudLock.new()
		_cloud_lock.name = "CloudLock"
		_cloud_lock.station = self
		_cloud_lock.position = Vector2(get_size().x * 0.5, 60.0)
		_cloud_lock.visible = false
		add_child(_cloud_lock)
	_trash_root = PulsePrompt.make_plate(self, "TrashHint",
		String(_folders.get("texts", {}).get("trash_blocked_text", "")), font, font_size,
		int(station_cfg.get("font_scale", 2)),
		"#" + HubData.color(String(station_cfg.get("label_plate_color", "fondo_profundo"))).to_html(false),
		"#" + HubData.color(String(station_cfg.get("label_border_color", "borde"))).to_html(false),
		float(station_cfg.get("label_padding_px", 3)), get_size().x, top - float(station_cfg.get("key_gap_px", 8)))
	_trash_root.visible = false
	_shown_state = &""


## Candado de La Nube PROVISIONAL por codigo (paso 7): placa con una ranura por
## recuerdo de lock_slots (encendida en acento_cian si se obtuvo, apagada en
## gris_apagado), centrada en su posicion.
class _CloudLock:
	extends Node2D
	var station: FolderStation

	func _draw() -> void:
		if station == null:
			return
		var n: int = station.get_lock_slot_count()
		var slot: float = 14.0
		var gap: float = 6.0
		var w: float = float(n) * slot + float(n - 1) * gap
		var panel := Rect2(Vector2(-w * 0.5 - 5.0, -slot * 0.5 - 5.0), Vector2(w + 10.0, slot + 10.0))
		draw_rect(panel.grow(2.0), HubData.color("borde"))
		draw_rect(panel, HubData.color("fondo_profundo"))
		var i: int = 0
		for id: Variant in station.world_entry.get("lock_slots", []):
			var on: bool = GameState.has_memory(StringName(String(id)))
			var r := Rect2(Vector2(-w * 0.5 + float(i) * (slot + gap), -slot * 0.5), Vector2(slot, slot))
			draw_rect(r, HubData.color("acento_cian") if on else HubData.color("gris_apagado"))
			if not on:
				draw_rect(r.grow(-3.0), HubData.color("fondo_profundo"))
			i += 1
