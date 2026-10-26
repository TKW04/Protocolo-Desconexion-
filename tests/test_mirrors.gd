# Espejos del Mundo 3 (2026-10-26, paso 4 de docs/propuesta-mundo-3.md §8, §3.4):
# espejo fijo (mirror: '/' y '\' giran el laser 90 grados, '|' lo devuelve; sigue
# con el alcance que le quedaba; como mucho 3 rebotes; lleva el laser a un lector
# fuera de alcance; el pulso no le hace nada), plataforma del reflejo
# (mirror_only: solida e invisible, dibujada en el reflejo de la pared de espejo;
# con el Debug, contorno) y pared de espejo (mirror_wall: Isak reflejado con 1 s
# de retraso y la variante saturada). Con las escenas reales del catalogo; el
# proyectil y la pared avanzan paso a paso.
extends GutTest

const IsakSim = preload("res://tests/support/isak_sim.gd")
const TILE: float = 64.0
const DT: float = 1.0 / 60.0
const EPS: float = 0.5
## El celular de Isak de pie queda 8 px por debajo del borde de arriba de su celda.
const PHONE_Y: float = 8.0

var _root: Node2D
var _saved_debug: bool
var _saved_laser: bool


func before_each() -> void:
	DebugMode.input_enabled = false
	DebugMode.reset()
	_saved_debug = GameState.is_ability_unlocked(GameState.ABILITY_DEBUG)
	_saved_laser = GameState.is_ability_unlocked(GameState.ABILITY_LASER)
	_root = Node2D.new()
	_root.name = "MirrorsTest"
	add_child(_root)


func after_each() -> void:
	if is_instance_valid(_root):
		_root.free()
	DebugMode.reset()
	DebugMode.input_enabled = true
	GameState.set_ability_unlocked(GameState.ABILITY_DEBUG, _saved_debug)
	GameState.set_ability_unlocked(GameState.ABILITY_LASER, _saved_laser)
	get_tree().paused = false
	GameState.debug_energy = GameState.get_debug_energy_max()


# --- Utilidades ---

func _scene(type: String, parent: Node = null) -> Node2D:
	var entry: Dictionary = World3ObjectsConfig.data().get("types", {}).get(type, {})
	if entry.is_empty():
		entry = World1ObjectsConfig.type_entry(type)
	var node := (load(String(entry["scene"])) as PackedScene).instantiate() as Node2D
	return node


func _mirror(col: int, row: int, orientation: String) -> Mirror:
	var m := _scene("mirror") as Mirror
	m.orientation = orientation
	m.position = Vector2(col, row) * TILE
	_root.add_child(m)
	return m


func _shot(at: Vector2, dir: float = 1.0) -> LaserProjectile:
	var shot := LaserProjectile.new()
	shot.auto_process = false
	shot.direction = dir
	shot.position = at
	_root.add_child(shot)
	return shot


func _fly(shot: LaserProjectile) -> void:
	for i: int in 240:
		if shot.is_finished():
			return
		shot.step(DT)


# --- Espejo fijo ---

func test_catalog_and_laser_target() -> void:
	var types: Dictionary = World3ObjectsConfig.data().get("types", {})
	for t: String in ["mirror", "mirror_wall", "mirror_only"]:
		assert_true(types.has(t), "Tipo %s en data/world3_objects.json" % t)
	assert_eq(Mirror.max_bounces(), 3, "Maximo 3 rebotes (datos)")
	var m: Mirror = _mirror(5, 5, "/")
	await wait_physics_frames(1)
	assert_true(m.is_in_group(LaserProjectile.GROUP_LASER_ACTIVATABLE))
	assert_true(bool(m.collision_layer & LaserProjectile.LAYER_WORLD), "El rayo lo encuentra")
	assert_eq(LaserProjectile.find_reflector(m), m)


func test_slash_turns_90_degrees() -> void:
	_mirror(5, 5, "/")
	_mirror(5, 9, "/")
	_mirror(12, 5, "\\")
	await wait_physics_frames(1)
	var up := _shot(Vector2(100.0, 5 * TILE + PHONE_Y))
	var left_down := _shot(Vector2(10 * TILE, 9 * TILE + PHONE_Y), -1.0)
	var right_down := _shot(Vector2(9 * TILE, 5 * TILE + PHONE_Y))
	await wait_physics_frames(1)
	for i: int in 30:
		up.step(DT)
		left_down.step(DT)
		right_down.step(DT)
	assert_eq(up.get_bounce_count(), 1)
	assert_almost_eq(up.get_heading(), Vector2.UP, Vector2(0.001, 0.001), "'/' a la derecha -> sube")
	assert_almost_eq(up.get_bounce_points()[0], Vector2(5 * TILE + 56.0, 5 * TILE + PHONE_Y), Vector2(EPS, EPS),
		"Rebota donde el haz cruza la diagonal (x = 56 de la celda)")
	assert_almost_eq(left_down.get_heading(), Vector2.DOWN, Vector2(0.001, 0.001), "'/' a la izquierda -> baja")
	assert_almost_eq(right_down.get_heading(), Vector2.DOWN, Vector2(0.001, 0.001), "'\\' a la derecha -> baja")


func test_vertical_mirror_sends_it_back() -> void:
	var m: Mirror = _mirror(6, 5, "|")
	await wait_physics_frames(1)
	var shot := _shot(Vector2(100.0, 5 * TILE + PHONE_Y))
	await wait_physics_frames(1)
	_fly(shot)
	assert_eq(shot.get_bounce_count(), 1)
	assert_almost_eq(shot.get_heading(), Vector2.LEFT, Vector2(0.001, 0.001), "'|' vuelve por donde vino")
	assert_almost_eq(shot.get_bounce_points()[0].x, m.get_center().x, EPS, "Por la vertical del centro")
	assert_eq(m.get_bounce_count(), 1)


func test_reflect_heading_api_works_for_diagonals() -> void:
	var diag := Vector2(1.0, -1.0).normalized()
	assert_almost_eq(Mirror.reflect_heading(Vector2(1.0, 1.0).normalized(), "/"), -Vector2(1.0, 1.0).normalized(),
		Vector2(0.001, 0.001), "Perpendicular al cristal: vuelve")
	assert_almost_eq(Mirror.reflect_heading(Vector2.UP, "\\"), Vector2.LEFT, Vector2(0.001, 0.001))
	assert_almost_eq(Mirror.reflect_heading(diag, "|"), -diag, Vector2(0.001, 0.001))


func test_keeps_the_remaining_range() -> void:
	var m: Mirror = _mirror(5, 9, "/")
	await wait_physics_frames(1)
	var start := Vector2(100.0, 9 * TILE + PHONE_Y)
	var shot := _shot(start)
	await wait_physics_frames(1)
	watch_signals(shot)
	_fly(shot)
	assert_signal_emitted(shot, "expired", "Se apaga por alcance, no choca")
	assert_almost_eq(shot.get_traveled(), shot.range_px, EPS, "Recorre 768 px en total")
	var bounce: Vector2 = shot.get_bounce_points()[0]
	var before: float = start.distance_to(bounce)
	assert_almost_eq(shot.global_position, bounce + Vector2.UP * (shot.range_px - before), Vector2(EPS, EPS),
		"Tras el espejo solo le queda lo que no recorrio antes")
	assert_almost_eq(m.get_center().x + 24.0, bounce.x, EPS)


func test_at_most_three_bounces_the_fourth_mirror_stops_it() -> void:
	_mirror(3, 6, "/")
	_mirror(3, 2, "/")
	_mirror(6, 2, "\\")
	var fourth: Mirror = _mirror(6, 6, "\\")
	await wait_physics_frames(1)
	watch_signals(EventBus)
	watch_signals(fourth)
	var shot := _shot(Vector2(170.0, 6 * TILE + PHONE_Y))
	await wait_physics_frames(1)
	_fly(shot)
	assert_true(shot.is_finished())
	assert_eq(shot.get_bounce_count(), 3, "Tres rebotes")
	assert_eq(shot.get_hit_target(), fourth, "El cuarto espejo lo para")
	assert_signal_emitted(fourth, "absorbed")
	assert_eq(fourth.get_bounce_count(), 0, "No lo desvia")
	assert_signal_emit_count(EventBus, "mirror_bounced", 3, "Una senal (sonido) por rebote")
	assert_lt(shot.get_traveled(), shot.range_px, "Dentro del alcance")


func test_bounce_flashes() -> void:
	var m: Mirror = _mirror(5, 5, "/")
	await wait_physics_frames(1)
	var shot := _shot(Vector2(100.0, 5 * TILE + PHONE_Y))
	await wait_physics_frames(1)
	_fly(shot)
	assert_true(m.is_flashing(), "Destello al rebotar")
	m.advance(1.0)
	assert_false(m.is_flashing())


func test_reader_out_of_reach_is_powered_through_the_mirror() -> void:
	_mirror(5, 9, "/")
	var reader := _scene("laser_receiver") as LaserReceiver
	reader.object_id = &"lector_techo"
	reader.target_id = &"nadie"
	reader.position = Vector2(5, 2) * TILE
	_root.add_child(reader)
	await wait_physics_frames(2)
	var shot := _shot(Vector2(2.5 * TILE, 9 * TILE + PHONE_Y))
	await wait_physics_frames(1)
	_fly(shot)
	assert_eq(shot.get_bounce_count(), 1)
	assert_eq(shot.get_hit_target(), reader, "El haz reflejado llega al lector del techo")
	assert_true(reader.is_powered())


func test_three_bounce_chain_of_the_test_room_reaches_its_reader() -> void:
	_mirror(17, 9, "/")
	_mirror(17, 5, "/")
	_mirror(19, 5, "/")
	var reader := _scene("laser_receiver") as LaserReceiver
	reader.target_id = &"nadie"
	reader.position = Vector2(19, 2) * TILE
	_root.add_child(reader)
	await wait_physics_frames(2)
	var shot := _shot(Vector2(15.5 * TILE + 20.0, 9 * TILE + PHONE_Y))
	await wait_physics_frames(1)
	_fly(shot)
	assert_eq(shot.get_bounce_count(), 3)
	assert_eq(shot.get_hit_target(), reader)
	assert_lt(shot.get_traveled(), 768.0)


func test_pulse_does_nothing() -> void:
	var m: Mirror = _mirror(5, 5, "/")
	await wait_physics_frames(1)
	var area := Area2D.new()
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 96.0
	shape.shape = circle
	area.add_child(shape)
	area.position = m.get_center()
	_root.add_child(area)
	await wait_physics_frames(1)
	watch_signals(m)
	EventBus.pulse_fired.emit(area)
	assert_signal_not_emitted(m, "bounced")
	assert_eq(m.get_bounce_count(), 0)
	assert_false(m.is_flashing())
	assert_eq(m.orientation, "/")
	assert_false(m.has_method(&"receive_pulse"), "No responde al pulso")


# --- Plataforma del reflejo y pared de espejo ---

## Mundo llano de IsakSim (suelo en y = 0, Isak en el origen) con una pared de
## espejo de 6 x 4 tiles con el centro en x = 0 y una plataforma del reflejo.
func _mirror_room() -> Dictionary:
	var sim := IsakSim.new(DT)
	var world: Node2D = sim.build_flat_world()
	_root.add_child(world)
	sim.take_manual_control()
	var wall := _scene("mirror_wall") as MirrorWall
	wall.width_tiles = 6
	wall.height_tiles = 4
	wall.auto_process = false
	wall.position = Vector2(-3.0 * TILE, -4.0 * TILE)
	world.add_child(wall)
	var platform := _scene("mirror_only") as MirrorOnlyPlatform
	platform.width_tiles = 1
	platform.position = Vector2(-2.0 * TILE, -2.0 * TILE)
	world.add_child(platform)
	await wait_physics_frames(1)
	sim.settle()
	return {"sim": sim, "wall": wall, "platform": platform}


func test_mirror_only_is_solid_invisible_and_drawn_in_the_reflection() -> void:
	var r: Dictionary = await _mirror_room()
	var wall: MirrorWall = r.wall
	var platform: MirrorOnlyPlatform = r.platform
	assert_true(platform.is_solid(), "Solida sin el Debug")
	assert_false(platform.is_visible_in_world(), "Invisible en el mundo")
	assert_eq(platform.get_mirror_wall(), wall, "Su pared es la mas cercana")
	wall.advance(DT)
	var rects: Array[Rect2] = wall.get_reflected_platform_rects()
	assert_eq(rects.size(), 1, "Se dibuja en el reflejo")
	var expected := Rect2(TILE, -2.0 * TILE, TILE, 32.0)
	assert_almost_eq(rects[0].position, expected.position, Vector2(EPS, EPS), "En su posicion reflejada")
	assert_almost_eq(rects[0].size, expected.size, Vector2(EPS, EPS))
	# Con el Debug se ve tambien con contorno, y sigue solida.
	GameState.set_ability_unlocked(GameState.ABILITY_DEBUG, true)
	GameState.debug_energy = GameState.get_debug_energy_max()
	for i: int in roundi(DebugMode.get_activation_hold_s() / DT) + 1:
		DebugMode.step(DT, true)
	for i: int in 30:
		DebugMode.step(DT, false)
	assert_true(DebugMode.is_active())
	platform._process(DT)
	assert_true(platform.is_visible_in_world(), "Con el Debug, contorno")
	assert_true(platform.is_solid())


func test_isak_stands_on_the_invisible_platform() -> void:
	var r: Dictionary = await _mirror_room()
	var sim: IsakSim = r.sim
	var platform: MirrorOnlyPlatform = r.platform
	sim.isak.global_position = Vector2(platform.get_rect().get_center().x, platform.get_rect().position.y - 40.0)
	sim.isak.velocity = Vector2.ZERO
	sim.step(30)
	assert_true(sim.isak.is_on_floor(), "La pisa")
	assert_almost_eq(sim.isak.global_position.y, platform.get_rect().position.y, 1.0, "Encima de ella, sin caer")


func test_isak_is_reflected_with_one_second_delay_and_saturated() -> void:
	var r: Dictionary = await _mirror_room()
	var sim: IsakSim = r.sim
	var wall: MirrorWall = r.wall
	sim.isak.global_position = Vector2(-2.5 * TILE, 0.0)
	sim.settle()
	var history: Array[Vector2] = []
	var flips: Array[bool] = []
	sim.input.move_axis = 1.0
	var delay_steps: int = roundi(wall.get_delay_s() / DT)
	for i: int in delay_steps + 30:
		sim.step()
		wall.advance(DT)
		history.append(sim.isak.global_position)
		flips.append((sim.isak.get_node(^"AnimatedSprite2D") as AnimatedSprite2D).flip_h)
	sim.input.move_axis = 0.0
	var now: int = history.size() - 1
	var then: Vector2 = history[now - delay_steps]
	assert_gt(history[now].x - then.x, 100.0, "Isak se ha movido de verdad en ese segundo")
	assert_almost_eq(wall.get_reflected_isak_position(), wall.reflect_point(then), Vector2(EPS, EPS),
		"El reflejo esta donde estaba Isak hace 1 s, espejado")
	assert_almost_eq(wall.get_reflected_isak_position().x, -then.x, EPS, "Eje en el centro del marco (x = 0)")
	assert_true(wall.is_isak_reflected(), "Se ve en el marco")
	var sprite: Sprite2D = wall.get_reflected_isak_sprite()
	assert_eq(sprite.flip_h, not flips[now - delay_steps], "Mirando al otro lado")
	assert_not_null(sprite.texture, "Con el cuadro de su sprite")
	assert_gt(float(wall.get_isak_material().get_shader_parameter(&"saturation")), 1.0, "Algo mas saturado")
	EventBus.player_respawned.emit(sim.isak.global_position, true)
	wall.advance(DT)
	assert_almost_eq(wall.get_reflected_isak_position(), wall.reflect_point(sim.isak.global_position),
		Vector2(EPS, EPS), "Al reaparecer el bufer empieza de nuevo")


# --- Sala de prueba con el Isak real ---

## Carga scenes/levels/espejos_test.tscn, pone a Isak de pie en (col, 9) mirando a
## la derecha y dispara el laser real; devuelve el proyectil ya terminado.
func _room_shot(col: float) -> Dictionary:
	var saved_pause: bool = EcoTextBox.pause_important
	EcoTextBox.pause_important = false
	GameState.set_ability_unlocked(GameState.ABILITY_LASER, true)
	GameState.debug_energy = GameState.get_debug_energy_max()
	var level := (load("res://scenes/levels/espejos_test.tscn") as PackedScene).instantiate() as Node2D
	var sim := IsakSim.new(DT)
	sim.attach(level.get_node(^"Isak") as Isak)
	_root.add_child(level)
	sim.take_manual_control()
	await wait_physics_frames(2)
	sim.isak.global_position = Vector2(col * TILE, 10.0 * TILE)
	sim.isak.velocity = Vector2.ZERO
	sim.settle()
	var fired: Array[LaserProjectile] = []
	sim.isak.laser_fired.connect(func(p: LaserProjectile) -> void: fired.append(p))
	sim.input.laser_pressed = true
	sim.step(ceili(sim.isak.abilities.laser_windup_s / DT) + 3)
	EcoTextBox.pause_important = saved_pause
	if fired.is_empty():
		return {"level": level}
	var shot: LaserProjectile = fired[0]
	shot.auto_process = false
	_fly(shot)
	return {"level": level, "shot": shot}


func test_room_real_laser_climbs_to_the_ceiling_reader() -> void:
	var r: Dictionary = await _room_shot(3.0)
	assert_true(r.has("shot"), "Isak dispara")
	var reader := (r.level as Node).get_node(^"Objects/lector_techo") as LaserReceiver
	assert_eq((r.shot as LaserProjectile).get_hit_target(), reader, "Desde el suelo, por el espejo, al techo")
	assert_true(reader.is_powered())


func test_room_real_laser_three_bounce_chain() -> void:
	var r: Dictionary = await _room_shot(15.6)
	assert_true(r.has("shot"))
	var reader := (r.level as Node).get_node(^"Objects/lector_cadena") as LaserReceiver
	assert_eq((r.shot as LaserProjectile).get_bounce_count(), 3)
	assert_eq((r.shot as LaserProjectile).get_hit_target(), reader, "Tres rebotes hasta el lector")


func test_room_wall_shows_its_platforms_reflected() -> void:
	var level := (load("res://scenes/levels/espejos_test.tscn") as PackedScene).instantiate() as Node2D
	_root.add_child(level)
	await wait_physics_frames(2)
	var wall := level.get_node(^"Objects/pared_espejo") as MirrorWall
	var cols: Array[int] = []
	for rect: Rect2 in wall.get_reflected_platform_rects():
		cols.append(roundi(rect.position.x / TILE))
	cols.sort()
	assert_eq(cols, [28, 30] as Array[int], "Las plataformas de las columnas 27 y 29 se ven en la 30 y la 28")
