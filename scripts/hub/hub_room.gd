## Hub REAL del Mundo 1 (docs/propuesta-hub-y-guardado.md §2; paso 5 de §6.2):
## sala 2D caminable de una pantalla (size_tiles 20x11 de 64 px), camara fija
## (limites de la camara de Isak = la pantalla), suelo = dock (filas desde
## floor_row), paredes en los bordes y techo. Todo sale de la seccion room de
## data/hub.json.
## Al entrar:
## - Isak aparece en P (spawn_cell; pies en el borde inferior de la celda) por
##   un vortice de llegada (WarpVortex.arrive): sin control hasta que se cierra
##   (senal arrived).
## - La energia de Debug (y el Sync Rate) se llenan (refill_on_enter).
## - Habilidades del hub (abilities_available: pulso si, Debug no; se restauran
##   al salir, como en GeneratedLevel); las obtenidas no se tocan.
## - El HUD pasa al modo hub (Modo Avion e indicador «sin guardar» en ambar).
## Arte final (assets/sprites/hub/, tools/gen_hub_objects.py): fondo con la foto
## rota (Background: animacion off, pieza 1 con contorno cian que parpadea; on,
## pieza 1 encendida cuando la carpeta del mundo background_on_world esta
## completada), dock de tiles (suelo), indicador de pagina, repisas de una via y
## carpetas. Estaciones (stations: escena HubStation en una celda, con su
## SpriteFrames `frames`) y huecos apagados del dock (dormant: siluetas de
## Notas, Linterna y Papelera; `frames` + `animation` o `texture`) se crean
## desde los datos en un nodo "Visual". Notas (NotasStation, antes «copia
## local») guarda y tiene el album; mientras el hub esta abierto y Notas esta
## encendida, el aviso al salir con cambios ofrece guardar (grupo
## QuitGuard.SAVE_STATION_GROUP). Calc (CalcStation, paso 8) vende las mejoras.
## ASISTENTES (2026-10-16, docs/propuesta-asistentes-y-vidas.md §2.2, §2.3 y §8):
## una estacion con requires_ally esta apagada (HubStation.set_powered) hasta que
## GameState conoce a ese asistente (EventBus.ally_met la enciende al momento):
## Notas hasta su presentacion y Calc hasta su encuentro (final del 1-2, aun sin
## implementar). La primera vez que Isak llega al hub (Notas desconocida), al
## terminar la llegada empieza la presentacion de Notas (NotasIntro) con el
## cuadro de texto del hub (EcoTextBox, hijo "EcoTextBox").
## Carpetas (paso 7; seccion folders y worlds): una FolderStation por mundo
## sobre su repisa (shelf_height_px sobre el dock, alcanzable de un salto). Al
## elegir un subnivel, Isak (de espaldas) se va por el vortice de salida
## (WarpVortex.depart) y se carga level_runner_scene (scenes/main.tscn) con ese
## nivel (LevelRunner.start_level_id), sustituyendo a la escena actual
## (scene_switcher lo cambia en pruebas).
## FLUJO DEL JUEGO (paso 9): LevelRunner (scenes/main.tscn) carga esta escena
## como hija al completar un nivel (hub_scene de data/flow.json), con
## hold_arrival (el vortice de llegada espera a que el fundido deje ver el hub:
## release_arrival) y level_handler (al elegir un subnivel, el propio
## LevelRunner funde y carga el nivel en lugar de sustituir la escena). Abierta
## sola (scenes/hub/hub.tscn) sigue cargando scenes/main.tscn con el nivel.
## Eco companero (EcoCompanion, variante atenuada: sin cobertura) entra y sale
## con Isak si Eco es conocido; no es una estacion.
## GAME OVER Y PAPELERA (2026-10-16, docs/propuesta-asistentes-y-vidas.md §5.2,
## paso 12 de §10): la Papelera (seccion papelera; columna 10 del dock) duerme
## hasta el primer game over; con contenido parpadea y se recupera al acercarse.
## Si LevelRunner trae el informe del rollback (rollback_report), al terminar la
## llegada Eco lo cuenta (GameOverIntro, data/game_over.json). Mientras la
## papelera tenga contenido las carpetas no se abren (HubWorlds.can_enter), Notas
## no guarda y el aviso al salir no ofrece guardar (can_save_now).
class_name HubRoom
extends Node2D

## Estacion donde se guarda (Notas).
const SAVE_STATION_ID: StringName = &"notas"
const TEXT_BOX_SCENE: String = "res://scenes/ui/eco_text_box.tscn"

## Isak termino de llegar (tiene el control).
signal arrived
## Se va a cargar el subnivel `level_id` (Isak ya se fue por el vortice).
signal level_requested(level_id: StringName)

## Si es valido, recibe la raiz preparada (LevelRunner de level_runner_scene con
## start_level_id) en lugar de sustituir la escena actual (pruebas).
var scene_switcher: Callable = Callable()
## Si es valido, se llama con el id del subnivel elegido (tras el vortice de
## salida) en lugar de cargar level_runner_scene: lo usa LevelRunner, que tiene
## el hub como hija. El hub no se quita del arbol: lo quita quien lo llama.
var level_handler: Callable = Callable()
## Si es verdadero (antes de entrar al arbol), el vortice de llegada espera a
## release_arrival() (LevelRunner: al terminar el fundido de entrada).
var hold_arrival: bool = false
## Informe del rollback del game over (GameState.apply_rollback) con el que se
## llega (lo da LevelRunner antes de entrar al arbol); vacio = llegada normal.
var rollback_report: Dictionary = {}

var _room: Dictionary = HubData.section("room")
var _isak: Isak
var _hud: Hud
var _arrival: WarpVortex
var _arrived: bool = false
var _stations: Dictionary[StringName, HubStation] = {}
var _dormant: Dictionary[StringName, Node2D] = {}
var _folders: Dictionary[StringName, FolderStation] = {}
var _background: AnimatedSprite2D
var _departure: WarpVortex
var _entering_level: StringName = &""
var _previous_abilities: Dictionary = {}
var _companion: EcoCompanion
var _text_box: EcoTextBox
var _notas_intro: NotasIntro
var _papelera: Papelera
var _game_over_intro: GameOverIntro


func _enter_tree() -> void:
	GameState.current_world = int(_room.get("world", GameState.FIRST_WORLD))
	_previous_abilities.clear()
	var abilities: Dictionary = _room.get("abilities_available", {})
	for key: Variant in abilities:
		var ability := StringName(String(key))
		if GameState.is_ability_obtained(ability):
			continue
		_previous_abilities[ability] = GameState.is_ability_unlocked(ability)
		GameState.set_ability_unlocked(ability, bool(abilities[key]))
	if not bool(abilities.get(String(GameState.ABILITY_DEBUG), false)):
		DebugMode.reset()


func _exit_tree() -> void:
	for ability: StringName in _previous_abilities:
		if GameState.is_ability_obtained(ability):
			continue
		GameState.set_ability_unlocked(ability, bool(_previous_abilities[ability]))
	_previous_abilities.clear()


func _ready() -> void:
	_isak = get_node(^"Isak") as Isak
	_hud = get_node_or_null(^"Hud") as Hud
	_text_box = (load(TEXT_BOX_SCENE) as PackedScene).instantiate() as EcoTextBox
	_text_box.name = "EcoTextBox"
	add_child(_text_box)
	_build_room()
	_build_dormant()
	_build_papelera()
	_build_stations()
	_build_folders()
	EventBus.ally_met.connect(_on_ally_met)
	if not rollback_report.is_empty():
		_game_over_intro = GameOverIntro.new()
		_game_over_intro.name = "GameOverIntro"
		_game_over_intro.report = rollback_report
		_game_over_intro.text_box = _text_box
		add_child(_game_over_intro)
	elif not GameState.has_met_ally(GameState.ALLY_NOTAS):
		_notas_intro = NotasIntro.new()
		_notas_intro.name = "NotasIntro"
		_notas_intro.station = get_notas()
		_notas_intro.text_box = _text_box
		add_child(_notas_intro)
	add_to_group(QuitGuard.SAVE_STATION_GROUP)
	if bool(_room.get("refill_on_enter", true)):
		GameState.refill_debug_energy()
		GameState.sync_rate = GameState.get_sync_rate_max()
	if _hud != null:
		_hud.enable_hub_mode(HubData.section("hud"))
	_place_isak()
	_papelera.isak = _isak
	# Eco entra con Isak, atenuado (sin cobertura; no guarda ni compra).
	_companion = EcoCompanion.attach(_isak, self, true)
	_start_arrival()


# --- Consultas ---

## Se puede guardar aqui (QuitGuard: el aviso al salir ofrece «Guardar y
## salir»): el hub tiene Notas y esta encendida.
func can_save_now() -> bool:
	var station: HubStation = get_station(SAVE_STATION_ID)
	return is_inside_tree() and station != null and station.is_powered() and not GameState.has_trash_pending()


## Papelera del dock.
func get_papelera() -> Papelera:
	return _papelera


## Lineas de Eco tras el game over (null si se llego sin rollback).
func get_game_over_intro() -> GameOverIntro:
	return _game_over_intro if _game_over_intro != null and is_instance_valid(_game_over_intro) else null


## Notas (guardar y album).
func get_notas() -> NotasStation:
	return get_station(SAVE_STATION_ID) as NotasStation


## Presentacion de Notas (null si Notas ya era conocida al entrar).
func get_notas_intro() -> NotasIntro:
	return _notas_intro if _notas_intro != null and is_instance_valid(_notas_intro) else null


## Cuadro de texto del hub (presentacion de Notas).
func get_text_box() -> EcoTextBox:
	return _text_box


func get_isak() -> Isak:
	return _isak


## Eco companero (atenuado en el hub).
func get_eco_companion() -> EcoCompanion:
	return _companion if _companion != null and is_instance_valid(_companion) else null


func get_hud() -> Hud:
	return _hud


## Suelta el vortice de llegada retenido (hold_arrival). Falso si no habia.
func release_arrival() -> bool:
	var vortex: WarpVortex = get_arrival_vortex()
	return vortex != null and vortex.release()


## Calc (tienda de mejoras; apagada hasta conocerla).
func get_calc() -> CalcStation:
	return get_station(&"calc") as CalcStation


func get_arrival_vortex() -> WarpVortex:
	return _arrival if _arrival != null and is_instance_valid(_arrival) else null


func has_arrived() -> bool:
	return _arrived


func get_station(id: StringName) -> HubStation:
	return _stations.get(id, null)


func get_station_ids() -> Array[StringName]:
	return _stations.keys()


## Hueco apagado del dock `id` (notas, linterna, papelera).
func get_dormant(id: StringName) -> Node2D:
	return _dormant.get(id, null)


func get_dormant_ids() -> Array[StringName]:
	return _dormant.keys()


## Carpeta del mundo `id` (m1, m2, m3).
func get_folder(id: StringName) -> FolderStation:
	return _folders.get(id, null)


func get_folder_ids() -> Array[StringName]:
	return _folders.keys()


## Borde superior de las repisas (y de su colision) en px.
func get_shelf_top_y() -> float:
	return get_floor_y() - float(HubData.section("folders").get("shelf_height_px", 160))


## Animacion del fondo: off (pieza 1 con contorno) u on (encendida).
func get_background_state() -> StringName:
	return _background.animation if _background != null else &""


## Subnivel al que se esta entrando (vacio si ninguno).
func get_entering_level() -> StringName:
	return _entering_level


func get_departure_vortex() -> WarpVortex:
	return _departure if _departure != null and is_instance_valid(_departure) else null


## Tamano de la sala en tiles y en px.
func get_size_tiles() -> Vector2i:
	var s: Array = _room.get("size_tiles", [20, 11])
	return Vector2i(int(s[0]), int(s[1]))


func get_size_px() -> Vector2:
	return Vector2(get_size_tiles()) * HubData.tile_size()


## Rectangulo que ve la camara (fijo).
func get_camera_rect() -> Rect2i:
	var r: Array = _room.get("camera_rect_px", [0, 0, 1280, 720])
	return Rect2i(int(r[0]), int(r[1]), int(r[2]), int(r[3]))


## Altura del suelo (borde superior del dock) en px.
func get_floor_y() -> float:
	return float(_room.get("floor_row", 9)) * HubData.tile_size()


## Posicion de P (pies de Isak).
func get_spawn_position() -> Vector2:
	var cell: Array = _room.get("spawn_cell", [5, 8])
	var t: float = HubData.tile_size()
	return Vector2((float(cell[0]) + 0.5) * t, (float(cell[1]) + 1.0) * t)


# --- Interno ---

func _place_isak() -> void:
	_isak.global_position = get_spawn_position()
	_isak.velocity = Vector2.ZERO
	_isak.facing = signf(float(_room.get("spawn_facing", 1.0)))
	var sprite := _isak.get_node_or_null(^"AnimatedSprite2D") as AnimatedSprite2D
	if sprite != null:
		sprite.flip_h = _isak.facing < 0.0
	var camera := _isak.get_node_or_null(^"Camera2D") as Camera2D
	if camera != null:
		var rect: Rect2i = get_camera_rect()
		camera.limit_left = rect.position.x
		camera.limit_top = rect.position.y
		camera.limit_right = rect.end.x
		camera.limit_bottom = rect.end.y
		camera.reset_smoothing()


func _start_arrival() -> void:
	_arrival = WarpVortex.arrive(_isak, self, hold_arrival)
	_arrival.finished.connect(_on_arrival_finished)


func _on_arrival_finished() -> void:
	_arrived = true
	arrived.emit()
	var game_over: GameOverIntro = get_game_over_intro()
	if game_over != null:
		game_over.start()
		return
	var intro: NotasIntro = get_notas_intro()
	if intro != null:
		intro.start()


## Un asistente recien conocido enciende sus estaciones (requires_ally).
func _on_ally_met(ally: StringName) -> void:
	for entry: Dictionary in _room.get("stations", []):
		if StringName(String(entry.get("requires_ally", ""))) == ally:
			var station: HubStation = get_station(StringName(String(entry.get("id", ""))))
			if station != null:
				station.set_powered(true)


func _build_room() -> void:
	var t: float = HubData.tile_size()
	var size: Vector2 = get_size_px()
	var screen: Rect2 = Rect2(get_camera_rect())
	var floor_y: float = get_floor_y()
	var room := Node2D.new()
	room.name = "Room"
	add_child(room)
	move_child(room, 0)
	_background = AnimatedSprite2D.new()
	_background.name = "Background"
	_background.centered = false
	_background.sprite_frames = load(String(_room.get("background", ""))) as SpriteFrames
	room.add_child(_background)
	refresh_background()
	_build_dock(room, screen, floor_y)
	var dot_path: String = String(_room.get("page_dot", ""))
	if not dot_path.is_empty():
		var dot := Sprite2D.new()
		dot.name = "PageDot"
		dot.texture = load(dot_path) as Texture2D
		dot.position = Vector2(size.x * 0.5, (float(_room.get("page_dot_row", 10)) + 0.5) * t)
		room.add_child(dot)
	var bodies := StaticBody2D.new()
	bodies.name = "Collision"
	bodies.collision_layer = 1
	bodies.collision_mask = 0
	room.add_child(bodies)
	var thick: float = t
	var height: float = maxf(size.y, screen.size.y)
	# Suelo (dock), paredes a los lados de la pantalla y techo.
	_add_box(bodies, "Floor", Rect2(-thick, floor_y, size.x + thick * 2.0, height - floor_y + thick))
	_add_box(bodies, "WallLeft", Rect2(-thick, -thick, thick, height + thick * 2.0))
	_add_box(bodies, "WallRight", Rect2(size.x, -thick, thick, height + thick * 2.0))
	_add_box(bodies, "Ceiling", Rect2(0.0, -thick, size.x, thick))


## Fondo: pieza 1 encendida si la carpeta de background_on_world esta completada.
func refresh_background() -> void:
	if _background == null or _background.sprite_frames == null:
		return
	var on_world: int = int(_room.get("background_on_world", 1))
	var lit: bool = false
	for entry: Dictionary in HubWorlds.worlds():
		if int(entry.get("world", 0)) == on_world:
			lit = HubWorlds.folder_state(entry) == HubWorlds.STATE_COMPLETED
	var anim: StringName = &"on" if lit else &"off"
	if _background.sprite_frames.has_animation(anim) and (_background.animation != anim or not _background.is_playing()):
		_background.play(anim)


## Dock de tiles: fila del suelo (bordes y centro) y relleno hasta el borde de
## la pantalla.
func _build_dock(room: Node2D, screen: Rect2, floor_y: float) -> void:
	var dock: Dictionary = _room.get("dock", {})
	if dock.is_empty():
		return
	var t: float = HubData.tile_size()
	var holder := Node2D.new()
	holder.name = "Dock"
	room.add_child(holder)
	var cols: int = get_size_tiles().x
	var every: int = maxi(1, int(dock.get("fill_alt_every", 5)))
	var offset: int = int(dock.get("fill_alt_offset", 2))
	for c: int in cols:
		var top_key: String = "top_left" if c == 0 else ("top_right" if c == cols - 1 else "top_center")
		_add_tile(holder, String(dock.get(top_key, "")), Vector2(c * t, floor_y))
		var y: float = floor_y + t
		while y < screen.end.y:
			var fill_key: String = "fill_alt" if c % every == offset else "fill"
			_add_tile(holder, String(dock.get(fill_key, "")), Vector2(c * t, y))
			y += t


func _add_tile(parent: Node, path: String, pos: Vector2) -> Sprite2D:
	var tile := Sprite2D.new()
	tile.centered = false
	tile.texture = load(path) as Texture2D if not path.is_empty() else null
	tile.position = pos
	parent.add_child(tile)
	return tile


func _add_box(body: StaticBody2D, node_name: String, rect: Rect2) -> void:
	var shape := CollisionShape2D.new()
	shape.name = node_name
	var box := RectangleShape2D.new()
	box.size = rect.size
	shape.shape = box
	shape.position = rect.get_center()
	body.add_child(shape)


## Huecos apagados del dock, de pie sobre el suelo en su columna.
func _build_dormant() -> void:
	var holder := Node2D.new()
	holder.name = "Dormant"
	add_child(holder)
	move_child(holder, 1)
	var t: float = HubData.tile_size()
	for entry: Dictionary in _room.get("dormant", []):
		var id := StringName(String(entry.get("id", "")))
		var size_px: Array = entry.get("size_px", [64, 96])
		var size := Vector2(float(size_px[0]), float(size_px[1]))
		var node := Node2D.new()
		node.name = String(entry.get("node", String(id).capitalize()))
		node.position = Vector2(float(entry.get("col", 0)) * t + (t - size.x) * 0.5, get_floor_y() - size.y)
		node.set_meta(&"dormant_id", id)
		holder.add_child(node)
		var visual: Node2D = _visual_for(entry, size)
		visual.name = "Visual"
		node.add_child(visual)
		_dormant[id] = node


## Papelera (seccion papelera), de pie sobre el dock en su columna.
func _build_papelera() -> void:
	var cfg: Dictionary = HubData.section("papelera")
	var t: float = HubData.tile_size()
	_papelera = Papelera.new()
	_papelera.name = String(cfg.get("node", "Papelera"))
	var size: Vector2 = _papelera.get_size()
	_papelera.position = Vector2(float(cfg.get("col", 10)) * t + (t - size.x) * 0.5, get_floor_y() - size.y)
	add_child(_papelera)
	move_child(_papelera, 2)


func _build_stations() -> void:
	var holder := Node2D.new()
	holder.name = "Stations"
	add_child(holder)
	move_child(holder, 2)
	var t: float = HubData.tile_size()
	for entry: Dictionary in _room.get("stations", []):
		var scene := load(String(entry.get("scene", "res://scenes/hub/hub_station.tscn"))) as PackedScene
		var station := scene.instantiate() as HubStation
		var id := StringName(String(entry.get("id", "")))
		station.name = String(entry.get("node", String(id).capitalize()))
		station.station_id = id
		var cell: Array = entry.get("cell", [0, 0])
		station.position = Vector2(float(cell[0]) * t, float(cell[1]) * t)
		if entry.has("text"):
			station.text = String(entry["text"])
		if entry.has("frames"):
			station.frames = String(entry["frames"])
		var ally: String = String(entry.get("requires_ally", ""))
		if not ally.is_empty():
			station.set_powered(GameState.has_met_ally(StringName(ally)))
		holder.add_child(station)
		_stations[id] = station


## Arte final: `frames` (SpriteFrames; animacion `animation`, por defecto off)
## o `texture`. Si no hay ninguno, el provisional de `kind`.
func _visual_for(entry: Dictionary, size: Vector2) -> Node2D:
	var frames_path: String = String(entry.get("frames", ""))
	if not frames_path.is_empty() and ResourceLoader.exists(frames_path):
		var sprite := AnimatedSprite2D.new()
		sprite.sprite_frames = load(frames_path) as SpriteFrames
		sprite.centered = false
		var anim := StringName(String(entry.get("animation", "off")))
		if sprite.sprite_frames.has_animation(anim):
			sprite.play(anim)
		return sprite
	var texture_path: String = String(entry.get("texture", ""))
	if not texture_path.is_empty() and ResourceLoader.exists(texture_path):
		var image := Sprite2D.new()
		image.centered = false
		image.texture = load(texture_path) as Texture2D
		return image
	var art := HubProvisionalArt.new()
	art.kind = StringName(String(entry.get("kind", "slot")))
	art.size = size
	return art


## Repisas de una via y carpetas de los mundos (secciones folders y worlds).
func _build_folders() -> void:
	var cfg: Dictionary = HubData.section("folders")
	var t: float = HubData.tile_size()
	var shelves := Node2D.new()
	shelves.name = "Shelves"
	add_child(shelves)
	move_child(shelves, 1)
	var holder := Node2D.new()
	holder.name = "Folders"
	add_child(holder)
	move_child(holder, 2)
	var body := StaticBody2D.new()
	body.name = "Collision"
	body.collision_layer = 1
	body.collision_mask = 0
	shelves.add_child(body)
	var size_tiles: Array = cfg.get("size_tiles", [2, 2])
	var width: int = int(size_tiles[0])
	var extra: int = int(cfg.get("shelf_extra_tiles", 1))
	var shelf_y: float = get_shelf_top_y()
	var tiles: Dictionary = cfg.get("shelf", {})
	var scene := load(String(cfg.get("scene", "res://scenes/hub/folder_station.tscn"))) as PackedScene
	for entry: Dictionary in HubWorlds.worlds():
		var id := StringName(String(entry.get("id", "")))
		var col: int = int(entry.get("col", 0))
		var first: int = col - extra
		var last: int = col + width - 1 + extra
		for c: int in range(first, last + 1):
			var key: String = "left" if c == first else ("right" if c == last else "center")
			_add_tile(shelves, String(tiles.get(key, "")), Vector2(c * t, shelf_y)).name = "Shelf_%s_%d" % [id, c]
		var shape := CollisionShape2D.new()
		shape.name = "Shelf_%s" % id
		var box := RectangleShape2D.new()
		box.size = Vector2((last - first + 1) * t, float(cfg.get("shelf_collision_px", 12)))
		shape.shape = box
		shape.one_way_collision = true
		shape.position = Vector2(first * t + box.size.x * 0.5, shelf_y + box.size.y * 0.5)
		body.add_child(shape)
		var folder := scene.instantiate() as FolderStation
		folder.name = "Folder_%s" % id
		folder.station_id = id
		folder.world_entry = entry
		folder.position = Vector2(col * t, shelf_y - folder.height_tiles * t + float(cfg.get("folder_sink_px", 0)))
		holder.add_child(folder)
		folder.level_chosen.connect(_on_folder_level_chosen)
		_folders[id] = folder


# --- Entrar a un subnivel ---

## Entra al subnivel `level_id` (si HubWorlds.can_enter): Isak se va por el
## vortice de salida y despues se carga el nivel. Falso si no se puede o si ya
## se esta entrando a otro.
func enter_level(level_id: StringName) -> bool:
	if not _entering_level.is_empty() or not HubWorlds.can_enter(level_id):
		return false
	_entering_level = level_id
	if _isak == null or not is_instance_valid(_isak):
		_load_level()
		return true
	if not _isak.is_facing_back():
		_isak.face_back()
	_departure = WarpVortex.depart(_isak, self)
	_departure.finished.connect(_load_level)
	return true


func _on_folder_level_chosen(_station: FolderStation, level_id: StringName) -> void:
	enter_level(level_id)


## Carga level_runner_scene con el subnivel elegido y sustituye al hub. El hub
## sale del arbol ANTES de que entre el nivel: asi restaura sus habilidades
## (_exit_tree) sin pisar las que aplica el nivel.
func _load_level() -> void:
	_swap_to_level.call_deferred()


func _swap_to_level() -> void:
	var id: StringName = _entering_level
	level_requested.emit(id)
	if level_handler.is_valid():
		level_handler.call(id)
		return
	var path: String = String(HubData.section("folders").get("level_runner_scene", "res://scenes/main.tscn"))
	var runner := (load(path) as PackedScene).instantiate()
	if runner is LevelRunner:
		(runner as LevelRunner).start_level_id = String(id)
	var tree: SceneTree = get_tree()
	if get_parent() != null:
		get_parent().remove_child(self)
	if scene_switcher.is_valid():
		scene_switcher.call(runner)
		return
	tree.root.add_child(runner)
	tree.current_scene = runner
	queue_free()
