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
## Estaciones (stations: escena HubStation en una celda) y huecos apagados del
## dock (dormant: Calc dormida sin logica aun y siluetas de Notas, Linterna y
## Papelera) se crean desde los datos, con arte PROVISIONAL (HubProvisionalArt)
## en un nodo "Visual" sustituible por el arte final (`frames`).
## AUN NO esta en el flujo del juego (paso 9): LevelRunner sigue llevando a
## hub_placeholder. Se prueba abriendo scenes/hub/hub.tscn o con
## tools/render_hub.gd.
class_name HubRoom
extends Node2D

## Isak termino de llegar (tiene el control).
signal arrived

var _room: Dictionary = HubData.section("room")
var _isak: Isak
var _hud: Hud
var _arrival: WarpVortex
var _arrived: bool = false
var _stations: Dictionary[StringName, HubStation] = {}
var _dormant: Dictionary[StringName, Node2D] = {}
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
	if bool(_room.get("refill_on_enter", true)):
		GameState.refill_debug_energy()
		GameState.sync_rate = GameState.get_sync_rate_max()
	if _hud != null:
		_hud.enable_hub_mode(HubData.section("hud"))
	_place_isak()
	_start_arrival()


# --- Consultas ---

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
	var art := HubProvisionalArt.new()
	art.name = "Visual"
	art.kind = &"room"
	art.size = screen.size
	art.room_floor_y = floor_y
	art.room_photo = _rect_from_cells(_room.get("photo_cells", [6, 1, 8, 5]))
	art.room_page_dot = Vector2(size.x * 0.5, (float(_room.get("page_dot_row", 10)) + 0.5) * t)
	room.add_child(art)
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


func _add_box(body: StaticBody2D, node_name: String, rect: Rect2) -> void:
	var shape := CollisionShape2D.new()
	shape.name = node_name
	var box := RectangleShape2D.new()
	box.size = rect.size
	shape.shape = box
	shape.position = rect.get_center()
	body.add_child(shape)


func _rect_from_cells(cells: Array) -> Rect2:
	var t: float = HubData.tile_size()
	return Rect2(float(cells[0]) * t, float(cells[1]) * t, float(cells[2]) * t, float(cells[3]) * t)


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


## Arte final si la entrada trae `frames` que existan (animacion off); si no,
## el provisional de `kind`.
func _visual_for(entry: Dictionary, size: Vector2) -> Node2D:
	var frames_path: String = String(entry.get("frames", ""))
	if not frames_path.is_empty() and ResourceLoader.exists(frames_path):
		var sprite := AnimatedSprite2D.new()
		sprite.sprite_frames = load(frames_path) as SpriteFrames
		sprite.centered = false
		if sprite.sprite_frames.has_animation(&"off"):
			sprite.play(&"off")
		return sprite
	var art := HubProvisionalArt.new()
	art.kind = StringName(String(entry.get("kind", "slot")))
	art.size = size
	return art
