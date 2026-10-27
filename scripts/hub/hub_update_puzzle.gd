## Acertijo «Actualizacion del sistema» de la pagina 2 del hub (2026-10-27,
## paso 3 de docs/propuesta-hub-mundos-4-6.md §2; datos en data/hub_update.json).
## Lo crea HubRoom cuando la pagina 2 esta «en instalacion» (3-boss sin el
## upgrade hub_update_4_6). Monta, con las piezas que ya existen, las tres
## verificaciones (UpdateCheck), que se hacen en cualquier orden:
## - V1 cian «Integridad»: glitch (HubEdgeGlitch) sobre lector1, un
##   LaserReceiver con revealed_only_with_debug (solo se ve y se le apunta con
##   el Debug); su cable sube a RE (RelayReceiver) sobre una repisa de una via
##   de 160 px; laser a lector1 (6 s de corriente) y pulso a RE: V1 se enciende.
## - V2 ambar «Bufer»: golpe al suelo sobre la PoundPlate; su plataforma
##   «Cargando...» sube 3 s (aviso de 0,5 s); de ella, salto con dash aereo al
##   bloque alto (no se llega sin dash) y pulso a V2.
## - V3 verde acido «Recorte»: laser al Mirror «/» del suelo, que lo sube a
##   lector3 (LaserReceiver): el SmallFrame del nicho se ilumina y se quita la
##   barrera de su hueco de 1 tile (permanente en la visita). Comprimido
##   (Pellizcar) se entra al nicho de 2 tiles de alto, se vuelve al tamano y
##   pulso a V3 (comprimido no hay pulso).
## - Instalar: HubInstaller; con 3/3 un pulso PIDE la instalacion
##   (install_requested). La instalacion de verdad es del paso 5.
## Mientras esta activo y no inerte, Isak puede usar en el hub el dash, el golpe
## al suelo y Pellizcar obtenidos (Isak.hub_gestures). INERTE con la Papelera
## llena (GameState.has_trash_pending; se reactiva al recuperarla): las
## verificaciones y la placa no responden y el instalador dice «Recupera tus
## archivos de la papelera». Nada se guarda: el hub se crea de nuevo en cada
## visita y todo vuelve a 0/3 (§2.6). Sin dano ni vidas (el hub no tiene).
## Terreno y arte PROVISIONALES por codigo (paso 7). El origen del nodo es la
## esquina superior izquierda de la pagina (origin = camera_rect de la pagina).
## TEXTOS Y PISTAS (2026-10-27, paso 6 de docs/propuesta-hub-mundos-4-6.md §1 y
## §2.4; seccion hub_update_hints de data/hub.json; textos PROPUESTOS):
## - Linea de Eco al cruzar a la pagina 2 por primera vez (start_intro, la llama
##   HubRoom en page_changed): importante (pausa), historia (sale con las ayudas
##   ocultas), una vez por partida guardada (seen_notices hub_update_intro).
## - Pista 3, Eco a los after_s s (90) de Isak en la pagina 2 sin ninguna
##   verificacion nueva: no importante, una vez por partida guardada
##   (hub_update_hint_eco). No sale con «Ayudas de Eco: Ocultar» ni inerte.
## - Pista 4, la tecla: tras after_fails (2) fallos en una verificacion sin
##   hacer (V1: se acaba la corriente de lector1, power_lost; V2: baja la
##   plataforma, platform_lowered; V3: Isak sin comprimir choca contra el marco
##   del nicho) sale sobre ella la tecla de la accion que falta (Input Map,
##   estilo de la tecla del pulso). Los fallos son de la visita (no se guardan).
##   No sale con las ayudas ocultas ni inerte; se quita al hacer la verificacion.
## - Pista 2 («Actualizacion: n/3» en Notas): get_progress_line, la lee NotasPanel
##   por el grupo GROUP.
class_name HubUpdatePuzzle
extends Node2D

const DATA_PATH: String = "res://data/hub_update.json"
## Grupo del acertijo montado (lo busca NotasPanel para su linea de progreso).
const GROUP: StringName = &"hub_update_puzzle"

## La verificacion `check_id` se ha encendido (`done` = cuantas van).
signal check_completed(check_id: StringName, done: int)
## Con 3/3, pulso al instalador: se pide instalar `upgrade_id` (paso 5).
signal install_requested(upgrade_id: StringName)
## Cambio de inerte (Papelera llena).
signal inert_changed(inert: bool)

## Isak del hub (para hub_gestures).
var isak: Isak

var _data: Dictionary = {}
var _checks: Dictionary[StringName, UpdateCheck] = {}
var _done: Array[StringName] = []
var _inert: bool = false
var _installer: HubInstaller
var _reader1: LaserReceiver
var _relay: RelayReceiver
var _plate: PoundPlate
var _mirror: Mirror
var _reader3: LaserReceiver
var _frame: SmallFrame
var _barrier: StaticBody2D
var _glitch: HubEdgeGlitch
var _frame_lit: bool = false
## Cuadro de texto del hub (lineas de Eco; lo da HubRoom).
var text_box: EcoTextBox
var _hints: Dictionary = HubData.section("hub_update_hints")
## Segundos con Isak en la pagina sin verificacion nueva (pista 3).
var _idle_s: float = 0.0
## Fallos por verificacion en esta visita (pista 4).
var _fails: Dictionary[StringName, int] = {}
var _keys: Dictionary[StringName, Node2D] = {}
var _key_base_y: Dictionary[StringName, float] = {}
var _key_shown_action: Dictionary[StringName, StringName] = {}
var _bumping: bool = false
var _time: float = 0.0


static func load_data() -> Dictionary:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(DATA_PATH))
	return parsed if parsed is Dictionary else {}


func _ready() -> void:
	_data = load_data()
	_build_terrain()
	_build_v1()
	_build_v2()
	_build_v3()
	_build_checks()
	_build_installer()
	_build_keys()
	add_to_group(GROUP)
	_reader1.power_lost.connect(func() -> void: register_failure(&"v1"))
	_plate.platform_lowered.connect(func() -> void: register_failure(&"v2"))
	EventBus.trash_changed.connect(func(_pending: bool) -> void: refresh_inert())
	EventBus.trash_recovered.connect(func(_trash: Dictionary) -> void: refresh_inert())
	refresh_inert(true)


func _exit_tree() -> void:
	if isak != null and is_instance_valid(isak):
		isak.hub_gestures = false


# --- Consultas ---

func get_upgrade_id() -> StringName:
	return StringName(String(_data.get("upgrade", "hub_update_4_6")))


func get_check(id: StringName) -> UpdateCheck:
	return _checks.get(id, null)


func get_check_ids() -> Array[StringName]:
	var out: Array[StringName] = []
	for entry: Variant in _data.get("checks", []):
		out.append(StringName(String((entry as Dictionary).get("id", ""))))
	return out


func get_done() -> Array[StringName]:
	return _done.duplicate()


func get_done_count() -> int:
	return _done.size()


func is_complete() -> bool:
	return _done.size() >= get_check_ids().size()


func is_inert() -> bool:
	return _inert


func is_install_requested() -> bool:
	return _installer != null and _installer.is_install_requested()


func is_frame_lit() -> bool:
	return _frame_lit


func get_installer() -> HubInstaller:
	return _installer


func get_reader1() -> LaserReceiver:
	return _reader1


func get_relay() -> RelayReceiver:
	return _relay


func get_plate() -> PoundPlate:
	return _plate


func get_mirror() -> Mirror:
	return _mirror


func get_reader3() -> LaserReceiver:
	return _reader3


func get_frame() -> SmallFrame:
	return _frame


func get_glitch() -> HubEdgeGlitch:
	return _glitch


## La barrera del hueco del marco sigue cerrada (no se ha iluminado el marco).
func is_frame_blocked() -> bool:
	return _barrier != null and is_instance_valid(_barrier)


## Celda local -> posicion global (esquina superior izquierda).
func cell_position(cell: Variant) -> Vector2:
	var t: float = HubData.tile_size()
	var c: Array = cell if cell is Array else [0, 0]
	return global_position + Vector2(float(c[0]) * t, float(c[1]) * t)


## Columna absoluta de la sala de una columna local (cable de LaserReceiver).
func absolute_col(col: int) -> int:
	return col + int(roundf(position.x / HubData.tile_size()))


## Linea de progreso para el resumen de Notas (pista 2, siempre):
## «Actualizacion: n/3 · Falta: …» (notas_progress de hub_update_hints).
func get_progress_line() -> String:
	var cfg: Dictionary = _hint_cfg("notas_progress")
	var text: String = String(cfg.get("text", "Actualización: {n}/{total}")) \
		.replace("{n}", str(get_done_count())).replace("{total}", str(get_check_ids().size()))
	var names: PackedStringArray = []
	for id: StringName in get_check_ids():
		if not _done.has(id):
			names.append(_check_name(id))
	if not names.is_empty():
		text += String(cfg.get("missing", " · Falta: {names}")).replace("{names}",
			String(_cfg("texts").get("names_separator", ", ")).join(names))
	return text


## Fallos de la verificacion `id` en esta visita.
func get_failure_count(id: StringName) -> int:
	return int(_fails.get(id, 0))


## Segundos acumulados de la pista 3 (Isak en la pagina sin verificacion nueva).
func get_idle_seconds() -> float:
	return _idle_s


## La tecla de la pista 4 esta a la vista sobre la verificacion `id`.
func is_key_hint_visible(id: StringName) -> bool:
	var key: Node2D = _keys.get(id, null)
	return key != null and key.visible


## Texto de la tecla de la pista 4 de `id` (aunque este oculta).
func get_key_hint_text(id: StringName) -> String:
	var key: Node2D = _keys.get(id, null)
	var label := key.get_node_or_null(^"Plate/Text") as Label if key != null else null
	return label.text if label != null else ""


## Accion cuya tecla ensena la pista 4 de `id` (V3: el laser mientras el marco
## siga cerrado, Pellizcar despues).
func get_key_hint_action(id: StringName) -> StringName:
	var actions: Dictionary = _hint_cfg("key_hint").get("actions", {})
	var key: String = String(id)
	if id == &"v3" and not _frame_lit and actions.has("v3_blocked"):
		key = "v3_blocked"
	return StringName(String(actions.get(key, "pulse")))


## Isak esta dentro de la pagina del acertijo.
func is_isak_on_page() -> bool:
	if isak == null or not is_instance_valid(isak):
		return false
	var x: float = isak.global_position.x - global_position.x
	return x >= 0.0 and x < float(HubData.section("room").get("size_tiles", [20, 11])[0]) * HubData.tile_size()


# --- Acciones ---

## Linea de Eco al entrar por primera vez en la pagina 2 (importante: pausa).
## Una vez por partida guardada; sale aunque las ayudas esten ocultas (historia).
## Verdadero si salio.
func start_intro() -> bool:
	var cfg: Dictionary = _hint_cfg("intro")
	var notice := StringName(String(cfg.get("notice", "hub_update_intro")))
	var lines: Array = cfg.get("lines", [])
	if text_box == null or lines.is_empty() or GameState.is_notice_seen(notice):
		return false
	GameState.mark_notice_seen(notice)
	for line: Variant in lines:
		text_box.show_line(String(line), float(cfg.get("duration_s", -1.0)), true,
			StringName(String(cfg.get("speaker", ""))))
	return true


## Cuenta un fallo de la verificacion `id` (pista 4). Sin efecto si ya esta
## hecha o el acertijo esta inerte. Devuelve los fallos que lleva.
func register_failure(id: StringName) -> int:
	var check: UpdateCheck = get_check(id)
	if check == null or check.is_completed() or _inert:
		return get_failure_count(id)
	_fails[id] = get_failure_count(id) + 1
	_refresh_keys()
	return _fails[id]


## Avanza las pistas `dt` s (lo llama _physics_process; util en pruebas).
func advance_hints(dt: float) -> void:
	_time += dt
	if is_isak_on_page() and not is_complete():
		_idle_s += dt
		_try_eco_hint()
	_check_frame_bump()
	_refresh_keys()


## Recalcula «inerte» (Papelera llena) y lo aplica a todas las piezas y a los
## gestos del hub.
func refresh_inert(force: bool = false) -> void:
	var value: bool = GameState.has_trash_pending()
	var changed: bool = value != _inert
	_inert = value
	for check: UpdateCheck in _checks.values():
		check.set_inert(_inert)
	if _plate != null:
		_plate.set_inert(_inert)
	if _installer != null:
		_installer.set_inert(_inert)
	if isak != null and is_instance_valid(isak):
		isak.hub_gestures = not _inert
	if changed or force:
		inert_changed.emit(_inert)


## Isak del hub: activa sus gestos (dash, golpe, Pellizcar) mientras no este inerte.
func set_isak(value: Isak) -> void:
	isak = value
	refresh_inert()


func _physics_process(delta: float) -> void:
	advance_hints(delta)


# --- Montaje ---

func _cfg(key: String) -> Dictionary:
	var value: Variant = _data.get(key, {})
	return value if value is Dictionary else {}


func _color(key: String) -> Color:
	return Color(String(_cfg("colors").get(key, "#3dfff5")))


func _build_terrain() -> void:
	var t: float = HubData.tile_size()
	var terrain: Dictionary = _cfg("terrain")
	var dock: Dictionary = HubData.section("room").get("dock", {})
	var body := StaticBody2D.new()
	body.name = "Terrain"
	body.collision_layer = 1
	body.collision_mask = 0
	add_child(body)
	for key: String in ["block", "niche_wall"]:
		var r: Array = terrain.get(key, [])
		if r.size() < 4:
			continue
		var rect := Rect2(float(r[0]) * t, float(r[1]) * t, float(r[2]) * t, float(r[3]) * t)
		_add_box(body, key.to_pascal_case(), rect)
		for cx: int in int(r[2]):
			for cy: int in int(r[3]):
				var top: bool = key == "block" and cy == 0
				_add_tile(body, String(dock.get("top_center" if top else "fill", "")),
					rect.position + Vector2(cx * t, cy * t))
	# Repisa de una via de RE (tiles de las repisas de las carpetas).
	var v1: Dictionary = _cfg("v1")
	var cols: Array = v1.get("shelf_cols", [3, 6])
	var shelf_y: float = float(HubData.section("room").get("floor_row", 9)) * t - float(v1.get("shelf_height_px", 160))
	var tiles: Dictionary = HubData.section("folders").get("shelf", {})
	var shelf := StaticBody2D.new()
	shelf.name = "ShelfRE"
	shelf.collision_layer = 1
	shelf.collision_mask = 0
	add_child(shelf)
	var first: int = int(cols[0])
	var last: int = int(cols[1])
	for c: int in range(first, last + 1):
		var k: String = "left" if c == first else ("right" if c == last else "center")
		_add_tile(shelf, String(tiles.get(k, "")), Vector2(c * t, shelf_y))
	var shape := CollisionShape2D.new()
	shape.name = "Shape"
	var box := RectangleShape2D.new()
	box.size = Vector2((last - first + 1) * t, float(HubData.section("folders").get("shelf_collision_px", 12)))
	shape.shape = box
	shape.one_way_collision = true
	shape.position = Vector2(first * t + box.size.x * 0.5, shelf_y + box.size.y * 0.5)
	shelf.add_child(shape)


func _build_v1() -> void:
	var t: float = HubData.tile_size()
	var v1: Dictionary = _cfg("v1")
	var g: Array = v1.get("glitch_size_tiles", [1, 2])
	_glitch = HubEdgeGlitch.new()
	_glitch.name = "WallGlitch"
	_glitch.position = cell_position(v1.get("glitch_cell", [1, 7])) - global_position
	_glitch.size = Vector2(float(g[0]) * t, float(g[1]) * t)
	var glitch_colors: Array[Color] = [_color("v1"), HubData.color("cian_tenue"), HubData.color("borde")]
	_glitch.colors = glitch_colors
	add_child(_glitch)
	var relay_col: int = int(v1.get("relay_col", 4))
	var shelf_y: float = float(HubData.section("room").get("floor_row", 9)) * t - float(v1.get("shelf_height_px", 160))
	_relay = RelayReceiver.new()
	_relay.name = "RE"
	_relay.object_id = &"hub_update_re"
	_relay.position = Vector2(relay_col * t, shelf_y - t)
	add_child(_relay)
	_relay.activated.connect(func(_target: StringName) -> void: _complete(&"v1"))
	_reader1 = LaserReceiver.new()
	_reader1.name = "Lector1"
	_reader1.object_id = &"hub_update_lector1"
	_reader1.target_id = _relay.object_id
	_reader1.revealed_only_with_debug = true
	_reader1.window_s = float(v1.get("window_s", 6.0))
	var cells: Array = []
	for cell: Variant in v1.get("cable_cells", []):
		cells.append([absolute_col(int((cell as Array)[0])), int((cell as Array)[1])])
	_reader1.cable_cells = cells
	_reader1.position = cell_position(v1.get("reader_cell", [1, 8])) - global_position
	add_child(_reader1)


func _build_v2() -> void:
	var t: float = HubData.tile_size()
	var v2: Dictionary = _cfg("v2")
	_plate = PoundPlate.new()
	_plate.name = "Placa"
	_plate.plate_id = &"hub_update_placa"
	_plate.plate_color = _color("v2")
	_plate.position = cell_position(v2.get("plate_cell", [9, 8])) - global_position
	var cols: Array = v2.get("platform_cols", [10, 11])
	var top: float = float(v2.get("platform_top_px", 448))
	_plate.platform_rect = Rect2(float(cols[0]) * t - _plate.position.x, top - _plate.position.y,
		float(int(cols[1]) - int(cols[0]) + 1) * t, float(v2.get("platform_thickness_px", 16)))
	_plate.up_s = float(v2.get("up_s", 3.0))
	_plate.warn_s = float(v2.get("warn_s", 0.5))
	add_child(_plate)


func _build_v3() -> void:
	var t: float = HubData.tile_size()
	var v3: Dictionary = _cfg("v3")
	_mirror = Mirror.new()
	_mirror.name = "Espejo"
	_mirror.object_id = &"hub_update_espejo"
	_mirror.orientation = String(v3.get("mirror_orientation", "/"))
	_mirror.position = cell_position(v3.get("mirror_cell", [16, 8])) - global_position
	add_child(_mirror)
	_reader3 = LaserReceiver.new()
	_reader3.name = "Lector3"
	_reader3.object_id = &"hub_update_lector3"
	_reader3.position = cell_position(v3.get("reader_cell", [16, 5])) - global_position
	add_child(_reader3)
	_reader3.powered.connect(func(_w: float) -> void: _light_frame())
	var frame_pos: Vector2 = cell_position(v3.get("frame_cell", [17, 8])) - global_position
	_frame = SmallFrame.new()
	_frame.name = "Marco"
	_frame.object_id = &"hub_update_marco"
	_frame.position = frame_pos
	_frame.modulate = Color(0.55, 0.55, 0.6)
	add_child(_frame)
	_barrier = StaticBody2D.new()
	_barrier.name = "Barrera"
	_barrier.collision_layer = 1
	_barrier.collision_mask = 0
	add_child(_barrier)
	_add_box(_barrier, "Shape", Rect2(frame_pos, Vector2(t, t)))
	var bars := _BarrierArt.new()
	bars.name = "Art"
	bars.position = frame_pos
	bars.color = _color("v3")
	_barrier.add_child(bars)


func _build_checks() -> void:
	for entry: Variant in _data.get("checks", []):
		var spec: Dictionary = entry
		var id := StringName(String(spec.get("id", "")))
		var check := UpdateCheck.new()
		check.name = "Check_%s" % id
		check.check_id = id
		check.mode = StringName(String(spec.get("mode", "pulse")))
		check.frame_color = _color(String(spec.get("color", String(id))))
		check.label_text = String(spec.get("name", ""))
		check.position = cell_position(spec.get("cell", [0, 0])) - global_position
		add_child(check)
		check.completed.connect(_on_check_completed)
		_checks[id] = check


func _build_installer() -> void:
	var cfg: Dictionary = _cfg("installer")
	var size: Array = cfg.get("size_tiles", [2, 3])
	_installer = HubInstaller.new()
	_installer.name = "Instalador"
	_installer.station_id = &"hub_installer"
	_installer.collision_layer = 0
	_installer.collision_mask = 2
	_installer.monitorable = false
	_installer.width_tiles = int(size[0])
	_installer.height_tiles = int(size[1])
	_installer.upgrade_id = get_upgrade_id()
	_installer.check_ids = get_check_ids()
	_installer.texts = _cfg("texts")
	for entry: Variant in _data.get("checks", []):
		var spec: Dictionary = entry
		_installer.check_names[StringName(String(spec.get("id", "")))] = String(spec.get("name", ""))
	_installer.position = cell_position(cfg.get("cell", [7, 6])) - global_position
	add_child(_installer)
	_installer.set_done(_done)
	_installer.install_requested.connect(func(id: StringName) -> void: install_requested.emit(id))


## Placas de la tecla de la pista 4 (una por verificacion, ocultas), con el
## estilo de la tecla del pulso de las estaciones (seccion station).
func _build_keys() -> void:
	var station: Dictionary = HubData.section("station")
	var cfg: Dictionary = _hint_cfg("key_hint")
	var font: Font = load(String(station.get("font", "res://assets/sprites/ui/text_font.fnt"))) as Font
	for id: StringName in _checks:
		var check: UpdateCheck = _checks[id]
		var holder := Node2D.new()
		holder.name = "KeyHint_%s" % id
		holder.position = check.position
		holder.visible = false
		holder.z_index = 5
		add_child(holder)
		var plate: Node2D = PulsePrompt.make_plate(holder, "Plate", PulsePrompt.key_text(get_key_hint_action(id), "?"),
			font, int(station.get("font_size", 12)), int(station.get("font_scale", 2)),
			"#" + HubData.color(String(station.get("key_plate_color", "fondo_profundo"))).to_html(false),
			"#" + HubData.color(String(station.get("key_border_color", "acento_cian"))).to_html(false),
			float(station.get("key_padding_px", 3)), check.size.x, -float(cfg.get("gap_px", 24)))
		_keys[id] = holder
		_key_base_y[id] = plate.position.y


func _hint_cfg(key: String) -> Dictionary:
	var value: Variant = _hints.get(key, {})
	return value if value is Dictionary else {}


func _check_name(id: StringName) -> String:
	for entry: Variant in _data.get("checks", []):
		if StringName(String((entry as Dictionary).get("id", ""))) == id:
			return String((entry as Dictionary).get("name", String(id)))
	return String(id)


## Pista 3: Eco a los after_s s sin verificacion nueva (no importante).
func _try_eco_hint() -> void:
	var cfg: Dictionary = _hint_cfg("eco_hint")
	if _idle_s < float(cfg.get("after_s", 90.0)) or _inert or text_box == null:
		return
	if not GameSettings.is_eco_help_shown():
		return
	var notice := StringName(String(cfg.get("notice", "hub_update_hint_eco")))
	var text: String = String(cfg.get("text", ""))
	if text.is_empty() or GameState.is_notice_seen(notice):
		return
	GameState.mark_notice_seen(notice)
	text_box.show_line(text, float(cfg.get("duration_s", -1.0)), false, StringName(String(cfg.get("speaker", ""))))


## V3: Isak sin comprimir, en el suelo, contra el marco del nicho = un fallo
## (al empezar el contacto; se rearma al alejarse bump_reset_px).
func _check_frame_bump() -> void:
	if isak == null or not is_instance_valid(isak) or _inert:
		_bumping = false
		return
	var t: float = HubData.tile_size()
	var frame_left: float = cell_position(_cfg("v3").get("frame_cell", [17, 8])).x
	var frame_bottom: float = cell_position(_cfg("v3").get("frame_cell", [17, 8])).y + t
	var right: float = isak.global_position.x + isak.get_hitbox_size().x * 0.5
	var gap: float = frame_left - right
	var touching: bool = not isak.is_compressed() and isak.is_on_floor() and gap <= 2.0 and gap > -t * 0.5 \
		and absf(isak.global_position.y - frame_bottom) < 4.0 and isak.facing > 0.0
	if touching and not _bumping:
		_bumping = true
		register_failure(&"v3")
	elif not touching and gap > float(_hint_cfg("key_hint").get("bump_reset_px", 24)):
		_bumping = false


func _refresh_keys() -> void:
	var shown: bool = GameSettings.is_eco_help_shown() and not _inert
	var after: int = int(_hint_cfg("key_hint").get("after_fails", 2))
	var station: Dictionary = HubData.section("station")
	for id: StringName in _keys:
		var holder: Node2D = _keys[id]
		var check: UpdateCheck = get_check(id)
		var was_visible: bool = holder.visible
		holder.visible = shown and check != null and not check.is_completed() and get_failure_count(id) >= after
		var plate := holder.get_node_or_null(^"Plate") as Node2D
		if plate == null or not holder.visible:
			continue
		# La tecla se lee del Input Map al aparecer y si cambia la accion (V3).
		var action: StringName = get_key_hint_action(id)
		if not was_visible or _key_shown_action.get(id, &"") != action:
			_key_shown_action[id] = action
			PulsePrompt.set_plate_text(plate, PulsePrompt.key_text(action, "?"),
				load(String(station.get("font", "res://assets/sprites/ui/text_font.fnt"))) as Font,
				int(station.get("font_size", 12)), float(station.get("key_padding_px", 3)))
		plate.position.y = PulsePrompt.bob_y(_key_base_y[id], _time, float(station.get("key_bob_s", 0.35)),
				float(station.get("key_bob_px", 2)))


# --- Interno ---

func _complete(id: StringName) -> void:
	var check: UpdateCheck = get_check(id)
	if check != null:
		check.complete()


func _on_check_completed(id: StringName) -> void:
	if _done.has(id):
		return
	_done.append(id)
	_idle_s = 0.0
	_refresh_keys()
	if _installer != null:
		_installer.set_done(_done)
	check_completed.emit(id, _done.size())


## lector3 recibe el laser (por el espejo): el marco se ilumina y se abre el hueco.
func _light_frame() -> void:
	if _frame_lit or _inert:
		return
	_frame_lit = true
	if _reader3 != null:
		_reader3.complete()
	if _frame != null:
		_frame.modulate = Color(1.25, 1.25, 1.1)
	if _barrier != null and is_instance_valid(_barrier):
		_barrier.queue_free()
		_barrier = null


func _add_box(body: StaticBody2D, node_name: String, rect: Rect2) -> void:
	var shape := CollisionShape2D.new()
	shape.name = node_name
	var box := RectangleShape2D.new()
	box.size = rect.size
	shape.shape = box
	shape.position = rect.get_center()
	body.add_child(shape)


func _add_tile(parent: Node, path: String, pos: Vector2) -> void:
	if path.is_empty():
		return
	var tile := Sprite2D.new()
	tile.centered = false
	tile.texture = load(path) as Texture2D
	tile.position = pos
	parent.add_child(tile)


## Barrera PROVISIONAL del hueco del marco (barras finas en su color).
class _BarrierArt:
	extends Node2D
	var color: Color = Color("#a6ff2e")

	func _draw() -> void:
		var t: float = 64.0
		draw_rect(Rect2(Vector2.ZERO, Vector2(t, t)), Color(HubData.color("fondo_profundo"), 0.7))
		for i: int in 4:
			var x: float = 8.0 + float(i) * 16.0
			draw_line(Vector2(x, 2.0), Vector2(x, t - 2.0), Color(color, 0.55), 3.0)
