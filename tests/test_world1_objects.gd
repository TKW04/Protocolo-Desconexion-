# Pruebas de los objetos del Mundo 1 (data/world1_objects.json): receptor del
# pulso (dentro/fuera del radio, con la PulseArea real de Isak y con un area
# simulada; se queda activado), puente (estados, extension por pasos, colision:
# Isak solo cruza el hueco con el puente extendido; enlace por id con su
# receptor), pared con glitch (solida, animada, gancho del Debug), fondo con
# parallax (velocidades de data/world1_background.json), catalogo para el
# generador de niveles y assets nuevos (solo colores de mundo1.gpl, alfa 0/255).
extends GutTest

const IsakSim = preload("res://tests/support/isak_sim.gd")
const RECEIVER_SCENE: PackedScene = preload("res://scenes/levels/receiver.tscn")
const BRIDGE_SCENE: PackedScene = preload("res://scenes/levels/bridge.tscn")
const GLITCH_SCENE: PackedScene = preload("res://scenes/levels/glitch_wall.tscn")
const BACKGROUND_SCENE: PackedScene = preload("res://scenes/levels/world1_background.tscn")
const TEST_SCENE: String = "res://scenes/levels/world1_objects_test.tscn"
const OBJECTS_PATH: String = "res://data/world1_objects.json"
const BACKGROUND_PATH: String = "res://data/world1_background.json"
const DT: float = 1.0 / 60.0
const T: float = 64.0
## Hueco de 5 tiles (320 px): mas que el alcance de un salto de Isak.
const GAP_TILES: int = 5
const GAP_START: float = 4.0 * T
const POSITION_TOLERANCE: float = 1.0

var _pulse_was_unlocked: bool = false


func before_each() -> void:
	_pulse_was_unlocked = GameState.is_ability_unlocked(GameState.ABILITY_PULSE)
	GameState.set_ability_unlocked(GameState.ABILITY_PULSE, true)


func after_each() -> void:
	GameState.set_ability_unlocked(GameState.ABILITY_PULSE, _pulse_was_unlocked)
	DebugMode.reset()


# --- Utilidades ---

func _fake_pulse(center: Vector2, radius: float) -> Area2D:
	var area := Area2D.new()
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = radius
	shape.shape = circle
	area.add_child(shape)
	area.position = center
	add_child_autofree(area)
	return area


func _receiver(pos: Vector2, target: StringName = &"b1") -> PulseReceiver:
	var r := RECEIVER_SCENE.instantiate() as PulseReceiver
	r.target_id = target
	r.position = pos
	add_child_autofree(r)
	return r


func _bridge(pos: Vector2, id: StringName = &"b1", length: int = GAP_TILES) -> PulseBridge:
	var b := BRIDGE_SCENE.instantiate() as PulseBridge
	b.object_id = id
	b.length_tiles = length
	b.position = pos
	return b


func _step_s() -> float:
	return float(World1ObjectsConfig.section("bridge")["step_s"])


## Suelo a izquierda y derecha de un hueco de GAP_TILES tiles (superficie en
## y = 0), puente en el hueco e Isak en la columna 1.5.
func _gap_world(sim: IsakSim) -> Dictionary:
	var world := Node2D.new()
	for x_range: Vector2 in [Vector2(-8.0 * T, GAP_START), Vector2(GAP_START + GAP_TILES * T, GAP_START + (GAP_TILES + 12) * T)]:
		var body := StaticBody2D.new()
		var shape := CollisionShape2D.new()
		var rect := RectangleShape2D.new()
		rect.size = Vector2(x_range.y - x_range.x, T)
		shape.shape = rect
		body.add_child(shape)
		body.position = Vector2((x_range.x + x_range.y) * 0.5, T * 0.5)
		world.add_child(body)
	var bridge: PulseBridge = _bridge(Vector2(GAP_START, 0.0))
	world.add_child(bridge)
	var isak: Isak = IsakSim.ISAK_SCENE.instantiate() as Isak
	sim.attach(isak)
	isak.position = Vector2(1.5 * T, -1.0)
	world.add_child(isak)
	add_child_autofree(world)
	return {"world": world, "bridge": bridge, "isak": isak}


## Camina a la derecha (corriendo) y, al llegar al borde, salta. Devuelve la
## posicion final tras `seconds`.
func _run_and_jump_across(sim: IsakSim, seconds: float) -> Vector2:
	sim.input.move_axis = 1.0
	sim.input.run_held = true
	var jumped: bool = false
	for i: int in sim.frames(seconds):
		if not jumped and sim.isak.global_position.x >= GAP_START - 8.0 and sim.isak.is_on_floor():
			sim.input.jump_pressed = true
			sim.input.jump_held = true
			jumped = true
		sim.step()
		if sim.isak.global_position.y > 4.0 * T:
			break
	sim.input.move_axis = 0.0
	sim.input.run_held = false
	sim.input.jump_held = false
	return sim.isak.global_position


# --- Receptor ---

func test_receiver_activates_only_inside_pulse_radius() -> void:
	var radius: float = 96.0
	var near := _receiver(Vector2(100.0, -32.0))
	var far := _receiver(Vector2(400.0, -32.0))
	# Zona de golpe del cercano: x desde 112. Pulso en x = 20: distancia 92 < 96.
	var area := _fake_pulse(Vector2(20.0, 0.0), radius)
	watch_signals(near)
	watch_signals(far)
	EventBus.pulse_fired.emit(area)
	assert_true(near.is_active(), "Dentro del radio: se activa")
	assert_false(far.is_active(), "Fuera del radio: no se activa")
	assert_signal_emitted_with_parameters(near, "activated", [&"b1"])
	assert_signal_not_emitted(far, "activated")


func test_receiver_edge_of_radius() -> void:
	var r := _receiver(Vector2(0.0, 0.0))
	var hit: Rect2 = r.get_hit_rect()
	var center := Vector2(hit.position.x - 50.0, hit.get_center().y)
	assert_false(r.receive_pulse(_fake_pulse(center, 49.0)), "A 50 px con radio 49: no llega")
	assert_true(r.receive_pulse(_fake_pulse(center, 50.0)), "A 50 px con radio 50: llega")


func test_receiver_with_real_isak_pulse_area() -> void:
	var sim := IsakSim.new(DT)
	var world: Node2D = sim.build_flat_world()
	add_child_autofree(world)
	sim.take_manual_control()
	await wait_physics_frames(1)
	sim.settle()
	var radius: float = sim.isak.abilities.pulse_radius_px
	var phone: Vector2 = sim.isak.global_position + sim.isak.get_pulse_origin()
	var offset: Array = World1ObjectsConfig.section("receiver")["hit_rect"]
	# Receptor cuya zona de golpe empieza justo dentro (y justo fuera) del radio.
	var inside := _receiver(Vector2(phone.x + radius - 4.0 - float(offset[0]), phone.y - 32.0))
	var outside := _receiver(Vector2(phone.x + radius + 4.0 - float(offset[0]), phone.y - 32.0))
	sim.input.pulse_pressed = true
	sim.step()
	assert_eq(sim.state(), PlayerState.PULSE, "Isak dispara el pulso")
	assert_true(inside.is_active(), "La PulseArea real alcanza al receptor dentro del radio")
	assert_false(outside.is_active(), "No alcanza al que esta fuera")


func test_isak_relays_pulse_on_event_bus() -> void:
	var sim := IsakSim.new(DT)
	add_child_autofree(sim.build_flat_world())
	sim.take_manual_control()
	await wait_physics_frames(1)
	sim.settle()
	watch_signals(EventBus)
	sim.input.pulse_pressed = true
	sim.step()
	assert_signal_emitted_with_parameters(EventBus, "pulse_fired", [sim.isak.get_node("PulseArea")])


func test_receiver_stays_active_and_emits_once() -> void:
	var r := _receiver(Vector2.ZERO)
	watch_signals(r)
	var area := _fake_pulse(r.get_hit_rect().get_center(), 32.0)
	assert_true(r.receive_pulse(area))
	assert_false(r.receive_pulse(area), "Un segundo pulso no lo reactiva")
	r.activate()
	assert_signal_emit_count(r, "activated", 1)
	await wait_seconds(0.2)
	assert_true(r.is_active(), "Se queda activado")


# --- Puente ---

func test_bridge_starts_retracted_without_collision() -> void:
	var b := _bridge(Vector2.ZERO)
	add_child_autofree(b)
	assert_eq(b.get_state(), PulseBridge.State.RETRACTED)
	assert_eq(b.get_solid_count(), 0)
	for i: int in GAP_TILES:
		assert_false(b.is_tile_solid(i), "Tile %d sin colision" % i)


func test_bridge_extends_tile_by_tile() -> void:
	var b := _bridge(Vector2.ZERO)
	add_child_autofree(b)
	b.set_physics_process(false)
	watch_signals(b)
	b.activate()
	assert_eq(b.get_state(), PulseBridge.State.EXTENDING)
	assert_eq(b.get_solid_count(), 1, "El primer tile aparece al activarse")
	assert_true(b.is_tile_solid(0))
	assert_false(b.is_tile_solid(1))
	b.advance(_step_s() * 0.5)
	assert_eq(b.get_solid_count(), 1, "Medio paso: nada nuevo")
	b.advance(_step_s() * 0.5)
	assert_eq(b.get_solid_count(), 2, "Un paso: un tile mas (de izquierda a derecha)")
	b.advance(_step_s() * GAP_TILES)
	assert_eq(b.get_state(), PulseBridge.State.EXTENDED)
	assert_eq(b.get_solid_count(), GAP_TILES)
	assert_signal_emit_count(b, "extended", 1)
	assert_signal_emit_count(b, "state_changed", 2)
	b.activate()
	b.advance(10.0)
	assert_eq(b.get_state(), PulseBridge.State.EXTENDED, "Se queda extendido")
	assert_signal_emit_count(b, "extended", 1)


func test_bridge_left_direction_grows_left() -> void:
	var b := _bridge(Vector2(640.0, 0.0), &"l", 3)
	b.direction = "left"
	add_child_autofree(b)
	var span: Rect2 = b.get_span_rect()
	assert_eq(span.position.x, 640.0 - 2.0 * T)
	assert_eq(span.size.x, 3.0 * T)


func test_bridge_collision_is_solid_plank() -> void:
	var b := _bridge(Vector2.ZERO)
	add_child_autofree(b)
	var cfg: Dictionary = World1ObjectsConfig.section("bridge")
	var shape: CollisionShape2D = null
	for child: Node in b.get_children():
		if child is CollisionShape2D:
			shape = child
			break
	assert_not_null(shape)
	assert_eq((shape.shape as RectangleShape2D).size, Vector2(T, float(cfg["collision_height_px"])))
	assert_eq(shape.one_way_collision, bool(cfg["one_way"]), "Solida (one_way segun datos)")


func test_receiver_links_bridge_by_id() -> void:
	var b := _bridge(Vector2.ZERO, &"puente_x")
	add_child_autofree(b)
	var other := _bridge(Vector2(0.0, 200.0), &"otro")
	add_child_autofree(other)
	var r := _receiver(Vector2(-128.0, -64.0), &"puente_x")
	await wait_physics_frames(1)
	r.activate()
	assert_eq(b.get_state(), PulseBridge.State.EXTENDING, "El receptor extiende su puente")
	assert_eq(other.get_state(), PulseBridge.State.RETRACTED, "No toca otros puentes")
	await wait_seconds(_step_s() * (GAP_TILES + 2))
	assert_true(b.is_extended(), "Termina de extenderse con el tiempo")


func test_bridge_links_receiver_already_active() -> void:
	var r := _receiver(Vector2.ZERO, &"tarde")
	r.activate()
	var b := _bridge(Vector2(64.0, 0.0), &"tarde")
	add_child_autofree(b)
	await wait_physics_frames(1)
	assert_ne(b.get_state(), PulseBridge.State.RETRACTED, "Estado persistente: receptor ya activo")


func test_isak_cannot_cross_gap_without_bridge() -> void:
	var sim := IsakSim.new(DT)
	var w: Dictionary = _gap_world(sim)
	sim.take_manual_control()
	await wait_physics_frames(1)
	sim.settle()
	var end: Vector2 = _run_and_jump_across(sim, 4.0)
	assert_gt(end.y, 2.0 * T, "Cae al hueco con el puente retraido")
	assert_false((w["bridge"] as PulseBridge).is_extended())


func test_isak_crosses_on_extended_bridge() -> void:
	var sim := IsakSim.new(DT)
	var w: Dictionary = _gap_world(sim)
	var bridge: PulseBridge = w["bridge"]
	bridge.activate()
	bridge.advance(_step_s() * (GAP_TILES + 1))
	assert_true(bridge.is_extended())
	sim.take_manual_control()
	await wait_physics_frames(2)
	sim.settle()
	sim.input.move_axis = 1.0
	var target_x: float = GAP_START + (GAP_TILES + 1) * T
	sim.step_until(func() -> bool: return sim.isak.global_position.x >= target_x or sim.isak.global_position.y > T)
	sim.input.move_axis = 0.0
	assert_almost_eq(sim.isak.global_position.y, 0.0, POSITION_TOLERANCE, "Camina sobre el puente sin caer")
	assert_gt(sim.isak.global_position.x, target_x - 1.0, "Llega al otro lado")


func test_full_flow_in_test_scene() -> void:
	var scene: Node = (load(TEST_SCENE) as PackedScene).instantiate()
	var sim := IsakSim.new(DT)
	sim.attach(scene.get_node("Isak") as Isak)
	add_child_autofree(scene)
	sim.take_manual_control()
	await wait_physics_frames(2)
	var receiver := scene.get_node("Receiver") as PulseReceiver
	var bridge := scene.get_node("Bridge") as PulseBridge
	sim.isak.global_position = Vector2(550.0, 575.0)
	sim.settle()
	assert_false(receiver.is_active())
	sim.input.pulse_pressed = true
	sim.step()
	assert_true(receiver.is_active(), "El pulso (G) activa el receptor")
	assert_ne(bridge.get_state(), PulseBridge.State.RETRACTED, "y el receptor el puente")
	await wait_seconds(_step_s() * (bridge.length_tiles + 2))
	assert_true(bridge.is_extended())


# --- Pared con glitch ---

func test_glitch_wall_is_solid_and_blocks_isak() -> void:
	var sim := IsakSim.new(DT)
	var world: Node2D = sim.build_flat_world()
	var wall := GLITCH_SCENE.instantiate() as GlitchWall
	wall.position = Vector2(4.0 * T, -2.0 * T)
	world.add_child(wall)
	add_child_autofree(world)
	sim.take_manual_control()
	await wait_physics_frames(1)
	sim.settle()
	assert_true(wall.is_solid())
	assert_true(wall.is_in_group(GlitchWall.GROUP))
	assert_true(wall.is_in_group(GlitchWall.DEBUG_SECRET_GROUP), "Gancho: grupo debug_secret")
	sim.input.move_axis = 1.0
	sim.step(sim.frames(3.0))
	assert_lt(sim.isak.global_position.x, 4.0 * T, "No atraviesa la pared")


func test_glitch_wall_emits_debug_hook() -> void:
	var wall := GLITCH_SCENE.instantiate() as GlitchWall
	add_child_autofree(wall)
	watch_signals(wall)
	EventBus.debug_mode_changed.emit(true)
	EventBus.debug_mode_changed.emit(false)
	assert_signal_emit_count(wall, "debug_revealed", 2)
	assert_signal_emitted_with_parameters(wall, "debug_revealed", [false])
	assert_true(wall.is_solid(), "Sigue solida: el secreto no esta implementado")


func test_glitch_wall_animates_in_discrete_frames() -> void:
	var wall := GLITCH_SCENE.instantiate() as GlitchWall
	wall.width_tiles = 2
	wall.height_tiles = 2
	wall.solid_neighbors = GlitchWall.E
	add_child_autofree(wall)
	wall.set_process(false)
	assert_eq(wall.get_cell_count(), 4)
	assert_eq(wall.cell_mask(0, 0), GlitchWall.E | GlitchWall.S, "Arriba-izquierda: vecinos dentro del bloque")
	assert_eq(wall.cell_mask(1, 1), GlitchWall.N | GlitchWall.E | GlitchWall.W, "Abajo-derecha con terreno al este")
	var seen: Dictionary = {}
	for i: int in 600:
		wall.advance(DT)
		for c: int in wall.get_cell_count():
			seen[wall.get_cell_frame(c)] = true
	assert_eq(seen.size(), int(World1ObjectsConfig.section("glitch_wall")["frames"]), "Usa todos los cuadros")


# --- Fondo ---

func test_background_uses_parallax_speeds_from_data() -> void:
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(BACKGROUND_PATH))
	var bg := BACKGROUND_SCENE.instantiate() as World1Background
	add_child_autofree(bg)
	var layers: Array[Parallax2D] = bg.get_layers()
	assert_eq(layers.size(), (data["layers"] as Array).size())
	var previous: float = -1.0
	for i: int in layers.size():
		var d: Dictionary = data["layers"][i]
		var layer: Parallax2D = layers[i]
		assert_eq(String(layer.name), String(d["name"]))
		assert_eq(layer.scroll_scale, Vector2(float(d["scroll_scale"][0]), float(d["scroll_scale"][1])))
		assert_eq(layer.repeat_size, Vector2(float(d["repeat_size"][0]), float(d["repeat_size"][1])))
		assert_gt(layer.scroll_scale.x, previous, "Las capas de delante se mueven mas")
		previous = layer.scroll_scale.x
		var tex: Texture2D = (layer.get_node("Sprite2D") as Sprite2D).texture
		assert_eq(tex.get_size(), Vector2(1280, 720), "Cubre la pantalla de 1280x720")
		assert_eq(float(tex.get_width()), layer.repeat_size.x, "Se repite al ancho de la imagen")
	assert_lt(bg.z_index, 0, "Por debajo del nivel")
	assert_false(bg.z_as_relative)


# --- Catalogo y assets ---

func test_catalog_types_have_scene_fields_and_example() -> void:
	var types: Dictionary = World1ObjectsConfig.data()["types"]
	for type: String in ["bridge_inactive", "receiver", "glitch_wall", "eco_line"]:
		assert_true(types.has(type), "Tipo %s en el catalogo" % type)
		var entry: Dictionary = types[type]
		var scene := load(String(entry["scene"])) as PackedScene
		assert_not_null(scene, "Escena de %s" % type)
		var node: Node = scene.instantiate()
		for field: String in entry["fields"]:
			var prop: String = entry["fields"][field]
			assert_true(prop in node, "%s.%s -> propiedad %s" % [type, field, prop])
		for field: String in entry["required"]:
			assert_true(entry["fields"].has(field), "Campo obligatorio %s mapeado" % field)
			assert_true(entry["example"]["params"].has(field), "El ejemplo de %s trae %s" % [type, field])
		assert_eq(entry["example"]["type"], type)
		assert_true(entry["example"].has("x") and entry["example"].has("y"))
		node.free()


func test_new_assets_only_use_palette_and_binary_alpha() -> void:
	var data: Dictionary = World1ObjectsConfig.data()
	var palette: Array[Color] = _load_gpl(String(data["palette"]), data["palette_exclude"])
	assert_eq(palette.size(), 16, "Los 16 colores del mundo (sin debug_cian)")
	for entry: Dictionary in data["assets"]:
		# palette_allow: colores excluidos que este asset si puede usar (checkpoint: debug_cian).
		var allowed: Array = (data["palette_exclude"] as Array).filter(
			func(name: Variant) -> bool: return not entry.get("palette_allow", []).has(name))
		var entry_palette: Array[Color] = _load_gpl(String(data["palette"]), allowed)
		var image := Image.load_from_file(ProjectSettings.globalize_path(String(entry["path"])))
		assert_not_null(image, entry["path"])
		image.convert(Image.FORMAT_RGBA8)
		var size := Vector2i(int(entry["frame_size"][0]) * int(entry["columns"]),
			int(entry["frame_size"][1]) * int(entry["rows"]))
		assert_eq(image.get_size(), size, "Tamano de %s" % entry["path"])
		var bad: int = 0
		for y: int in range(0, image.get_height()):
			for x: int in range(0, image.get_width()):
				var c: Color = image.get_pixel(x, y)
				if c.a8 == 0:
					continue
				if c.a8 != 255 or not entry_palette.has(Color8(c.r8, c.g8, c.b8)):
					bad += 1
		assert_eq(bad, 0, "Solo colores de mundo1.gpl y alfa 0/255: %s" % entry["path"])


func _load_gpl(path: String, exclude: Array) -> Array[Color]:
	var colors: Array[Color] = []
	for line: String in FileAccess.get_file_as_string(path).split("\n"):
		var s: String = line.strip_edges()
		if s.is_empty() or s.begins_with("#") or s.begins_with("GIMP") or s.contains(":"):
			continue
		var fields: PackedStringArray = s.replace("\t", " ").split(" ", false)
		if fields.size() >= 4 and fields[0].is_valid_int() and not exclude.has(fields[3]):
			colors.append(Color8(fields[0].to_int(), fields[1].to_int(), fields[2].to_int()))
	return colors
