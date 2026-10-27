# Espejo cazador, Reflejo falso, placa «Posa aqui» y puerta de marco (Mundo 3,
# 2026-10-26, paso 6 de docs/propuesta-mundo-3.md §8, §3.6, patrones 16 y 17):
# - cazador: gira hacia Isak 45 grados cada 0,6 s con brillo de 9 cuadros; el pulso
#   lo congela 3 s y sale reflejado como un haz (activa un receptor, aturde a un
#   enemigo, aturde a Isak 0,5 s sin quitar Sync si le apunta); el laser sale
#   hacia donde mira (a Isak le quita 10).
# - reflejo: sale al cruzar la linea de la pared, repite a Isak con 1 s, dana al
#   contacto, sostiene la placa, el pulso lo aturde y al despertar salta al bufer,
#   desaparece al salir Isak de su sala.
# - placa y puerta: abre mientras se pisa y 0,3 s mas; la puerta tarda 0,2 s.
# Con las escenas reales del catalogo, avanzando paso a paso; al final, la sala
# reflejo_test con el Isak real.
extends GutTest

const IsakSim = preload("res://tests/support/isak_sim.gd")
const REFLECTION_SCENE: PackedScene = preload("res://scenes/enemies/false_reflection.tscn")
const THIEF_SCENE: PackedScene = preload("res://scenes/enemies/like_thief.tscn")
const DT: float = 1.0 / 60.0
const T: float = 64.0
const EPS: float = 0.5

var _sim: IsakSim
var _isak: Isak
var _world: Node2D
var _root: Node2D


func before_each() -> void:
	GameState.sync_rate = GameState.SYNC_RATE_MAX
	DebugMode.input_enabled = false
	DebugMode.reset()
	_sim = IsakSim.new(DT)
	_world = _sim.build_flat_world()
	add_child_autofree(_world)
	_sim.take_manual_control()
	_isak = _sim.isak
	_isak.global_position = Vector2(-3000.0, 0.0)
	await wait_physics_frames(1)
	_sim.settle()


func after_each() -> void:
	if is_instance_valid(_root):
		_root.free()
	DebugMode.reset()
	DebugMode.input_enabled = true
	GameState.sync_rate = GameState.SYNC_RATE_MAX
	get_tree().paused = false


# --- Utilidades ---

func _scene(type: String) -> Node2D:
	var entry: Dictionary = World3ObjectsConfig.data().get("types", {}).get(type, {})
	if entry.is_empty():
		entry = World1ObjectsConfig.type_entry(type)
	return (load(String(entry["scene"])) as PackedScene).instantiate() as Node2D


func _stand_at(x: float) -> void:
	_isak.global_position = Vector2(x, 0.0)
	_isak.velocity = Vector2.ZERO
	_sim.settle()


## Cazador en la celda (col, -1) (apoyado en el suelo y = 0) del mundo de prueba.
func _hunter(col: int, rest: String = "e") -> HunterMirror:
	var h := _scene("hunter_mirror") as HunterMirror
	h.facing = rest
	h.auto_process = false
	h.position = Vector2(col * T, -T)
	_world.add_child(h)
	h.isak = _isak
	return h


func _fake_pulse(center: Vector2, radius: float = 96.0) -> Area2D:
	var area := Area2D.new()
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = radius
	shape.shape = circle
	area.add_child(shape)
	area.position = center
	add_child_autofree(area)
	return area


func _reflection(axis: float, zone: Array = [-40, -12, 80, 24]) -> FalseReflection:
	var r := REFLECTION_SCENE.instantiate() as FalseReflection
	r.auto_process = false
	r.axis_x = axis
	r.zone = zone
	_world.add_child(r)
	r.target = _isak
	return r


func _plate(col: int, door_id: StringName) -> PosePlate:
	var p := _scene("pose_plate") as PosePlate
	p.auto_process = false
	p.target_id = door_id
	p.position = Vector2(col * T, -T)
	_world.add_child(p)
	p.isak = _isak
	return p


func _door(col: int, id: StringName) -> FrameDoor:
	var d := _scene("frame_door") as FrameDoor
	d.auto_process = false
	d.object_id = id
	d.position = Vector2(col * T, -3.0 * T)
	_world.add_child(d)
	return d


## Un paso de todo: Isak, reflejo, placas y puertas (en ese orden).
func _tick(r: FalseReflection = null, plates: Array = [], doors: Array = []) -> void:
	_sim.step()
	if r != null:
		r.step(DT)
	for p: PosePlate in plates:
		p.advance(DT)
	for d: FrameDoor in doors:
		d.advance(DT)


# --- Catalogo ---

func test_catalog_and_data() -> void:
	var types: Dictionary = World3ObjectsConfig.data().get("types", {})
	for t: String in ["hunter_mirror", "pose_plate", "frame_door"]:
		assert_true(types.has(t), "Tipo %s en data/world3_objects.json" % t)
		assert_eq(String(types[t].get("help_id", "")), t, "Con su Q desde el paso 9 (%s)" % t)
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/enemies/false_reflection.json"))
	assert_true(parsed is Dictionary)
	assert_almost_eq(float(parsed["delay_s"]), 1.0, 0.0001, "Reflejo de hace 1 s")
	assert_almost_eq(float(parsed["contact_damage"]), 10.0, 0.0001)
	assert_eq(String((parsed as Dictionary).get("help_id", "")), "false_reflection", "Con su Q desde el paso 9")


# --- Espejo cazador ---

func test_hunter_turns_toward_isak_every_0_6_s_with_warning() -> void:
	_stand_at(3.0 * T)
	var h: HunterMirror = _hunter(5)
	await wait_physics_frames(1)
	assert_eq(h.get_facing_name(), "e", "Reposo al este")
	assert_eq(h.get_target_index(), HunterMirror.facing_index("w"), "Isak a su izquierda: quiere mirar al oeste")
	watch_signals(h)
	var warn_at: int = -1
	var turn_at: int = -1
	for i: int in 40:
		h.advance(DT)
		if warn_at < 0 and h.is_warning():
			warn_at = i + 1
		if turn_at < 0 and h.get_turn_count() > 0:
			turn_at = i + 1
	assert_eq(warn_at, 27, "Brilla 9 cuadros antes del giro (0,6 s - 0,15 s)")
	assert_eq(turn_at, 36, "Gira a los 0,6 s")
	assert_signal_emitted(h, "turn_warned", "Senal del aviso (sfx_w3_hunter_turn)")
	assert_eq(h.get_facing_name(), "ne", "Un paso de 45 grados (por el lado corto; a 180, antihorario)")
	for i: int in 36 * 3:
		h.advance(DT)
	assert_eq(h.get_facing_name(), "w", "Cuatro giros: ya mira a Isak")
	assert_eq(h.get_turn_count(), 4)
	# Lejos de Isak vuelve a su orientacion de reposo.
	_stand_at(-20.0 * T)
	for i: int in 36 * 4 + 4:
		h.advance(DT)
	assert_eq(h.get_facing_name(), "e", "Sin Isak en su radio, vuelve al reposo")


func test_hunter_world_time_slows_the_turn() -> void:
	_stand_at(3.0 * T)
	var h: HunterMirror = _hunter(5)
	await wait_physics_frames(1)
	h.advance(0.6 * 0.5)
	assert_eq(h.get_turn_count(), 0, "Tiempo del mundo: medio intervalo no gira")
	h.advance(0.3)
	assert_eq(h.get_turn_count(), 1)


func test_pulse_freezes_and_reflects_a_beam() -> void:
	_stand_at(3.0 * T)
	var h: HunterMirror = _hunter(5)
	var receiver := _scene("receiver") as PulseReceiver
	receiver.position = Vector2(9 * T, -T)
	_world.add_child(receiver)
	var thief := THIEF_SCENE.instantiate() as LikeThief
	thief.position = Vector2(7.5 * T, 0.0)
	_world.add_child(thief)
	thief.set_physics_process(false)
	await wait_physics_frames(2)
	watch_signals(h)
	# Lejos (fuera del radio del pulso) no le hace nada.
	assert_false(h.receive_pulse(_fake_pulse(Vector2(0.0, -40.0))), "Pulso lejos: nada")
	assert_true(h.receive_pulse(_fake_pulse(h.get_center() + Vector2(-90.0, 0.0))), "Pulso a <= 96 px")
	assert_true(h.is_frozen(), "Congelado")
	assert_signal_emitted(h, "beam_fired")
	assert_true(receiver.is_active(), "El haz de 6 tiles al este activa el receptor (a 4 tiles)")
	assert_true(thief.is_stunned(), "El haz aturde al enemigo en su camino")
	var seg: PackedVector2Array = h.get_beam_segment()
	assert_almost_eq(seg[0].distance_to(seg[1]), 6.0 * T, 0.5, "Haz de 6 tiles (sin terreno en medio)")
	assert_eq(_isak.get_state_name(), PlayerState.IDLE, "No apunta a Isak: nada")
	# Congelado no gira aunque Isak este a su izquierda.
	for i: int in roundi(2.9 / DT):
		h.advance(DT)
	assert_eq(h.get_facing_name(), "e", "Congelado en su orientacion")
	assert_true(h.is_frozen())
	for i: int in 8:
		h.advance(DT)
	assert_false(h.is_frozen(), "A los 3 s se descongela")
	assert_signal_emitted(h, "thawed")


func test_beam_stops_at_terrain() -> void:
	_stand_at(-10.0 * T)
	var h: HunterMirror = _hunter(5)
	var wall := StaticBody2D.new()
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(T, 3.0 * T)
	shape.shape = rect
	wall.add_child(shape)
	wall.position = Vector2(8.5 * T, -1.5 * T)
	_world.add_child(wall)
	await wait_physics_frames(2)
	h.fire_beam()
	var seg: PackedVector2Array = h.get_beam_segment()
	assert_almost_eq(seg[1].x, 8.0 * T, 0.5, "El terreno corta el haz")


func test_pulse_returned_to_isak_stuns_without_sync() -> void:
	_stand_at(4.0 * T)
	var h: HunterMirror = _hunter(5, "w")
	await wait_physics_frames(2)
	watch_signals(h)
	var before: float = GameState.sync_rate
	assert_true(h.receive_pulse(_fake_pulse(_isak.global_position + _isak.get_pulse_origin())),
		"Isak pulsa al cazador que le mira")
	assert_signal_emitted(h, "isak_stunned", "Devuelve el pulso")
	assert_eq(_isak.get_state_name(), PlayerState.HURT, "Isak aturdido")
	assert_almost_eq(GameState.sync_rate, before, 0.0001, "Sin quitar Sync")
	_sim.step(roundi(0.45 / DT))
	assert_eq(_isak.get_state_name(), PlayerState.HURT, "Sigue aturdido a los 0,45 s")
	_sim.step(roundi(0.1 / DT) + 2)
	assert_ne(_isak.get_state_name(), PlayerState.HURT, "A los 0,5 s recupera el control")


func _shot(at: Vector2, dir: float) -> LaserProjectile:
	var shot := LaserProjectile.new()
	shot.auto_process = false
	shot.direction = dir
	shot.position = at
	shot.source = _isak
	_world.add_child(shot)
	return shot


func test_laser_is_reflected_where_it_looks() -> void:
	_stand_at(-20.0 * T)
	var h: HunterMirror = _hunter(5, "n")
	await wait_physics_frames(2)
	var shot := _shot(Vector2(2.0 * T, h.get_center().y), 1.0)
	await wait_physics_frames(1)
	for i: int in 20:
		shot.step(DT)
		h.advance(DT)
	assert_eq(shot.get_bounce_count(), 1, "Rebota en el cazador")
	assert_almost_eq(shot.get_heading(), Vector2.UP, Vector2(0.001, 0.001), "Sale hacia donde mira (norte)")
	assert_almost_eq(shot.get_bounce_points()[0], h.get_center(), Vector2(EPS, EPS), "Desde su centro")


func test_laser_reflected_at_isak_takes_10() -> void:
	_stand_at(2.0 * T)
	var h: HunterMirror = _hunter(5, "w")
	await wait_physics_frames(2)
	watch_signals(h)
	var shot := _shot(Vector2(4.2 * T, h.get_center().y), 1.0)
	await wait_physics_frames(1)
	for i: int in 60:
		if shot.is_finished():
			break
		shot.step(DT)
		h.advance(DT)
	h.advance(DT)
	assert_eq(shot.get_bounce_count(), 1)
	assert_almost_eq(shot.get_heading(), Vector2.LEFT, Vector2(0.001, 0.001), "Vuelve hacia Isak")
	assert_signal_emitted(h, "isak_hit", "Alcanza a Isak")
	assert_almost_eq(GameState.sync_rate, GameState.SYNC_RATE_MAX - 10.0, 0.0001, "Le quita 10")
	assert_true(shot.is_finished(), "El disparo se apaga en Isak")


# --- Reflejo falso ---

## Isak anda a la derecha desde `from_x`; devuelve la historia de posiciones de
## cada paso desde que sale el reflejo.
func _walk_through(r: FalseReflection, from_x: float, steps: int, plates: Array = [], doors: Array = []) -> Array[Vector2]:
	_stand_at(from_x)
	var history: Array[Vector2] = []
	_sim.input.move_axis = 1.0
	var emerged: bool = false
	for i: int in steps:
		_tick(r, plates, doors)
		if not emerged and r.is_present():
			emerged = true
		if emerged:
			history.append(_isak.global_position)
	_sim.input.move_axis = 0.0
	return history


func test_reflection_emerges_on_the_line_and_repeats_one_second_later() -> void:
	var r: FalseReflection = _reflection(0.0)
	await wait_physics_frames(1)
	_stand_at(-3.0 * T)
	assert_true(r.is_dormant())
	watch_signals(r)
	var history: Array[Vector2] = []
	var flips: Array[bool] = []
	var anims: Array[StringName] = []
	_sim.input.move_axis = 1.0
	var emerged_x: float = NAN
	for i: int in 300:
		_tick(r)
		if r.is_present():
			if is_nan(emerged_x):
				emerged_x = _isak.global_position.x
				assert_almost_eq(r.global_position.x, emerged_x, 0.01, "Sale donde Isak cruza la linea")
			history.append(_isak.global_position)
			anims.append(_isak.get_animation())
			flips.append(_isak.get_sprite().flip_h)
		if history.size() == 30:
			assert_almost_eq(r.global_position.x, emerged_x, 0.01, "El primer segundo se queda en la linea")
		if history.size() >= 90:
			break
	_sim.input.move_axis = 0.0
	assert_signal_emitted(r, "emerged")
	assert_true(emerged_x >= 0.0 and emerged_x < 8.0, "Al cruzar x = 0")
	assert_true(r.is_active(), "Tras el aviso (9 cuadros), activo")
	var now: int = history.size() - 1
	var delay_steps: int = roundi(1.0 / DT)
	assert_almost_eq(r.global_position, history[now - delay_steps], Vector2(EPS, EPS),
		"Esta donde estaba Isak hace 60 cuadros")
	assert_gt(history[now].x - r.global_position.x, 100.0, "Isak se ha alejado de verdad")
	var s: Dictionary = r.get_sample()
	assert_eq(StringName(s["animation"]), anims[now - delay_steps], "Con su pose de entonces")
	assert_eq(r.get_sprite().flip_h, flips[now - delay_steps], "Mirando hacia donde miraba (no espejado)")
	assert_true(r.get_sprite().visible and r.get_sprite().texture != null, "Dibujo = cuadro del sprite de Isak")
	assert_gt(float(r.get_shader_material().get_shader_parameter(&"saturation")), 1.0, "Variante saturada")
	assert_almost_eq(GameState.sync_rate, GameState.SYNC_RATE_MAX, 0.0001, "Siguiendo a 1 s, no le toca")


func test_reflection_damages_on_contact() -> void:
	var r: FalseReflection = _reflection(0.0)
	await wait_physics_frames(1)
	_walk_through(r, -2.0 * T, 50)
	assert_true(r.is_present())
	watch_signals(r)
	# Isak se para: a 1 s el reflejo llega a donde esta y le toca.
	var hit_at: int = -1
	for i: int in 120:
		_tick(r)
		if hit_at < 0 and GameState.sync_rate < GameState.SYNC_RATE_MAX:
			hit_at = i
	assert_signal_emitted(r, "hit_player")
	assert_almost_eq(GameState.sync_rate, GameState.SYNC_RATE_MAX - 10.0, 0.0001, "Dana al contacto: -10")
	assert_true(hit_at > 0, "No al instante: cuando el reflejo le alcanza")


func test_pulse_stuns_reflection_and_it_jumps_to_the_buffer() -> void:
	var r: FalseReflection = _reflection(0.0)
	await wait_physics_frames(1)
	_walk_through(r, -2.0 * T, 130)
	assert_true(r.is_active())
	assert_true(r.receive_pulse(_fake_pulse(r.get_body_rect_now().get_center())), "El pulso lo alcanza")
	assert_true(r.is_stunned(), "Aturdido")
	var frozen_at: Vector2 = r.global_position
	var history: Array[Vector2] = []
	_sim.input.move_axis = 1.0
	for i: int in roundi(2.9 / DT):
		_tick(r)
		history.append(_isak.global_position)
	assert_true(r.is_stunned(), "Sigue aturdido a los 2,9 s")
	assert_almost_eq(r.global_position, frozen_at, Vector2(0.01, 0.01), "Quieto mientras esta aturdido")
	var woke: bool = false
	for i: int in 12:
		_tick(r)
		history.append(_isak.global_position)
		if not woke and r.is_active():
			woke = true
			assert_almost_eq(r.global_position, history[history.size() - 1 - roundi(1.0 / DT)], Vector2(EPS, EPS),
				"Al despertar salta al punto actual del bufer (Isak de hace 1 s)")
	_sim.input.move_axis = 0.0
	assert_true(woke, "Despierta a los 3 s")
	assert_gt(r.global_position.x - frozen_at.x, 200.0, "Ha saltado hacia delante")


func test_reflection_is_indestructible() -> void:
	var r: FalseReflection = _reflection(0.0)
	await wait_physics_frames(1)
	_walk_through(r, -2.0 * T, 130)
	watch_signals(r)
	r.on_laser_hit(5.0, _isak)
	assert_signal_emitted(r, "deflected")
	assert_true(r.is_active(), "El laser no le hace nada")
	assert_false(r.is_laser_vulnerable())


func test_reflection_vanishes_when_isak_leaves_its_room() -> void:
	var r: FalseReflection = _reflection(0.0, [-6, -4, 12, 6])
	await wait_physics_frames(1)
	_walk_through(r, -2.0 * T, 60)
	assert_true(r.is_present())
	watch_signals(r)
	_stand_at(10.0 * T)
	_tick(r)
	assert_true(r.is_dormant(), "Isak fuera de la sala: desaparece")
	assert_signal_emitted(r, "vanished")
	assert_false(r.get_sprite().visible)
	assert_eq(r.get_plate_feet(), {}, "Dormido no pisa placas")


func test_reflection_holds_the_plate() -> void:
	var r: FalseReflection = _reflection(0.0)
	var plate: PosePlate = _plate(3, &"puerta_r")
	var door: FrameDoor = _door(8, &"puerta_r")
	await wait_physics_frames(1)
	_stand_at(-2.0 * T)
	_sim.input.move_axis = 1.0
	var isak_left_at: int = -1
	var reflection_pressed: bool = false
	for i: int in 200:
		_tick(r, [plate], [door])
		if plate.get_pressed_by().has(_isak):
			isak_left_at = -1
		elif isak_left_at < 0 and _isak.global_position.x > 4.0 * T:
			isak_left_at = i
		if isak_left_at >= 0 and i - isak_left_at > 40 and plate.get_pressed_by().has(r):
			reflection_pressed = true
			assert_true(plate.is_holding(), "La placa sigue sostenida por el reflejo")
			break
		if _isak.global_position.x > 7.0 * T:
			_sim.input.move_axis = 0.0
	_sim.input.move_axis = 0.0
	assert_true(reflection_pressed, "El reflejo pisa la placa 1 s despues que Isak")


# --- Placa y puerta ---

func test_plate_opens_door_while_pressed_and_0_3_s_more() -> void:
	var plate: PosePlate = _plate(3, &"puerta_a")
	var door: FrameDoor = _door(8, &"puerta_a")
	await wait_physics_frames(2)
	assert_true(door.is_solid(), "Cerrada y solida")
	_stand_at(3.5 * T)
	plate.advance(DT)
	assert_true(plate.is_pressed(), "Isak la pisa")
	assert_true(plate.is_holding())
	watch_signals(door)
	var opened_at: int = -1
	for i: int in 30:
		door.advance(DT)
		if opened_at < 0 and door.is_open():
			opened_at = i + 1
	assert_signal_emitted(door, "opening_started", "Aviso al empezar a abrirse")
	assert_between(opened_at, 12, 13, "Se abre en 0,2 s")
	assert_false(door.is_solid(), "Abierta: se pasa")
	# Isak se baja: 0,3 s mas.
	_stand_at(0.5 * T)
	plate.advance(DT)
	assert_false(plate.is_pressed())
	assert_true(plate.is_holding(), "Sigue sosteniendo")
	var released_at: int = -1
	for i: int in 30:
		plate.advance(DT)
		door.advance(DT)
		if released_at < 0 and not plate.is_holding():
			released_at = i + 2
	assert_between(released_at, 18, 19, "Suelta a los 0,3 s")
	for i: int in 30:
		door.advance(DT)
	assert_signal_emitted(door, "close_warned", "Aviso antes de cerrarse")
	assert_true(door.is_solid(), "Cerrada otra vez")
	assert_almost_eq(door.get_open_fraction(), 0.0, 0.001)


func test_door_does_not_close_on_isak() -> void:
	var plate: PosePlate = _plate(3, &"puerta_b")
	var door: FrameDoor = _door(8, &"puerta_b")
	await wait_physics_frames(2)
	_stand_at(3.5 * T)
	for i: int in 20:
		plate.advance(DT)
		door.advance(DT)
	assert_false(door.is_solid())
	_isak.global_position = Vector2(8.5 * T, 0.0)
	for i: int in 60:
		plate.advance(DT)
		door.advance(DT)
	assert_false(door.is_solid(), "Con Isak en el hueco no se cierra")
	assert_true(door.is_blocked())


# --- Sala reflejo_test con el Isak real ---

func _load_room() -> Dictionary:
	GameState.set_ability_unlocked(GameState.ABILITY_LASER, true)
	GameState.debug_energy = GameState.get_debug_energy_max()
	_root = Node2D.new()
	_root.name = "ReflectionRoom"
	add_child(_root)
	var level := (load("res://scenes/levels/reflejo_test.tscn") as PackedScene).instantiate() as Node2D
	var sim := IsakSim.new(DT)
	sim.attach(level.get_node(^"Isak") as Isak)
	_root.add_child(level)
	sim.take_manual_control()
	await wait_physics_frames(2)
	return {"level": level, "sim": sim}


func test_room_hunter_frozen_toward_the_relay_extends_the_bridge() -> void:
	var saved_pause: bool = EcoTextBox.pause_important
	EcoTextBox.pause_important = false
	var room: Dictionary = await _load_room()
	var level: Node2D = room.level
	var sim: IsakSim = room.sim
	var reader := level.get_node(^"Objects/lector_techo") as LaserReceiver
	var relay := level.get_node(^"Objects/receptor_cazador") as RelayReceiver
	var hunter := level.get_node(^"Objects/cazador") as HunterMirror
	# Laser al espejo '/': sube al lector del techo, que da corriente al receptor.
	sim.isak.global_position = Vector2(2.5 * T, 10.0 * T)
	sim.isak.velocity = Vector2.ZERO
	sim.settle()
	var fired: Array[LaserProjectile] = []
	sim.isak.laser_fired.connect(func(p: LaserProjectile) -> void: fired.append(p))
	sim.input.laser_pressed = true
	sim.step(ceili(sim.isak.abilities.laser_windup_s / DT) + 3)
	assert_false(fired.is_empty(), "Isak dispara")
	if not fired.is_empty():
		var shot: LaserProjectile = fired[0]
		shot.auto_process = false
		for i: int in 120:
			if shot.is_finished():
				break
			shot.step(DT)
	assert_true(reader.is_powered(), "El lector del techo da corriente")
	# Junto al cazador, que aun mira al este (al receptor): pulso.
	sim.isak.global_position = Vector2(9.7 * T, 10.0 * T)
	sim.isak.velocity = Vector2.ZERO
	sim.step(2)
	assert_eq(hunter.get_facing_name(), "e")
	sim.input.pulse_pressed = true
	sim.step(4)
	await wait_physics_frames(1)
	EcoTextBox.pause_important = saved_pause
	assert_true(hunter.is_frozen(), "El pulso lo congela")
	assert_true(relay.is_active(), "El haz llega al receptor enlazado del otro lado del foso")
	var bridge := level.get_node(^"Objects/puente_cazador")
	assert_not_null(bridge)


## Isak anda a la derecha desde la columna 21 con la fisica real (todo el nivel
## avanza a la vez, cuadro a cuadro); devuelve hasta donde llega en 6 s.
func _room_walk(level: Node2D, sim: IsakSim, keep_reflection: bool) -> float:
	if not keep_reflection:
		var r := level.get_node(^"Enemies/reflejo_falso") as FalseReflection
		r.get_parent().remove_child(r)
		r.free()
	sim.isak.global_position = Vector2(21.5 * T, 10.0 * T)
	sim.isak.velocity = Vector2.ZERO
	sim.settle()
	sim.isak.set_physics_process(true)
	sim.input.move_axis = 1.0
	for i: int in roundi(6.0 / DT):
		await wait_physics_frames(1)
		if sim.isak.global_position.x > 31.0 * T:
			break
	sim.input.move_axis = 0.0
	return sim.isak.global_position.x


func test_room_reflection_holds_the_plate_so_isak_gets_through() -> void:
	var room: Dictionary = await _load_room()
	var x: float = await _room_walk(room.level, room.sim, true)
	assert_gt(x, 31.0 * T, "Con el reflejo pisando la placa 1 s despues, la puerta sigue abierta")
	assert_almost_eq(GameState.sync_rate, GameState.SYNC_RATE_MAX, 0.0001, "Sin que el reflejo le toque")


func test_room_without_reflection_the_door_closes_first() -> void:
	var room: Dictionary = await _load_room()
	var x: float = await _room_walk(room.level, room.sim, false)
	assert_lt(x, 30.0 * T, "Solo, la puerta se cierra antes de llegar")
