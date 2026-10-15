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
## SpriteFrames `frames`) y huecos apagados del dock (dormant: Calc dormida sin
## logica aun y siluetas de Notas, Linterna y Papelera; `frames` + `animation`
## o `texture`) se crean desde los datos en un nodo "Visual". La copia local
## (CopyLocalStation) guarda; mientras el hub esta abierto, el aviso al salir
## con cambios ofrece guardar (grupo QuitGuard.SAVE_STATION_GROUP).
## AUN NO esta en el flujo del juego (paso 9): LevelRunner sigue llevando a
## hub_placeholder. Se prueba abriendo scenes/hub/hub.tscn
## o con tools/render_hub.gd.
class_name HubRoom
extends Node2D

## Estacion donde se guarda (copia local).
const SAVE_STATION_ID: StringName = &"copia_local"

## Isak termino de llegar (tiene el control).
signal arrived

var _room: Dictionary = HubData.section("room")
var _isak: Isak
var _hud: Hud
var _arrival: WarpVortex
var _arrived: bool = false
var _stations: Dictionary[StringName, HubStation] = {}
var _dormant: Dictionary[StringName, Node2D] = {}
var _background: AnimatedSprite2D
var _previous_abilities: Dictionary = {}


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
	_build_room()
	_build_dormant()
	_build_stations()
	add_to_group(QuitGuard.SAVE_STATION_GROUP)
	if bool(_room.get("refill_on_enter", true)):
		GameState.refill_debug_energy()
		GameState.sync_rate = GameState.get_sync_rate_max()
	if _hud != null:
		_hud.enable_hub_mode(HubData.section("hud"))
	_place_isak()
	_start_arrival()


# --- Consultas ---

## Se puede guardar aqui (QuitGuard: el aviso al salir ofrece «Guardar y
## salir»): el hub tiene la estacion copia local.
func can_save_now() -> bool:
	return is_inside_tree() and get_station(SAVE_STATION_ID) != null


func get_isak() -> Isak:
	return _isak


func get_hud() -> Hud:
	return _hud


func get_arrival_vortex() -> WarpVortex:
	return _arrival if _arrival != null and is_instance_valid(_arrival) else null


func has_arrived() -> bool:
	return _arrived


func get_station(id: StringName) -> HubStation:
	return _stations.get(id, null)


func get_station_ids() -> Array[StringName]:
	return _stations.keys()


## Hueco apagado del dock `id` (calc, notas, linterna, papelera).
func get_dormant(id: StringName) -> Node2D:
	return _dormant.get(id, null)


func get_dormant_ids() -> Array[StringName]:
	return _dormant.keys()


## Animacion del fondo: off (pieza 1 con contorno) u on (encendida).
func get_background_state() -> StringName:
	return _background.animation if _background != null else &""


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
	_arrival = WarpVortex.arrive(_isak, self)
	_arrival.finished.connect(_on_arrival_finished)


func _on_arrival_finished() -> void:
	_arrived = true
	arrived.emit()


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
