# Piezas del acertijo de la azotea del 1-2 por separado (2026-10-17, tanda H1 del
# paso 14 de docs/propuesta-1-2.md; docs/propuesta-calc-encuentro.md):
# interruptor de pulso y panel oculto (PowerSwitch), interruptor laser
# (LaserSwitch), pared con glitch que se vuelve puerta (GlitchWall.door_when,
# sin cambiar la pared del 1-1), cuarto a oscuras (DarkRoom), punto de carga
# (ChargeDock), Calc (CalcActor), terminal con corriente
# (ExitTerminal.requires_power), guion de Eco (EcoGuide) y el punto del guion
# del companero (EcoCompanion.set_guide_point).
extends GutTest

const ISAK_SCENE: PackedScene = preload("res://scenes/player/isak.tscn")
const TILE: float = 64.0
const DT: float = 1.0 / 60.0

var _root: Node2D
var _isak: Isak
var _pulse: Area2D
var _settings_path: String


func before_each() -> void:
	_settings_path = GameSettings.settings_path()
	GameSettings.use_path(_settings_path, true)
	GameState.reset_progress()
	DebugMode.input_enabled = false
	DebugMode.reset()
	_root = Node2D.new()
	_root.name = "CalcRoomObjects"
	_isak = ISAK_SCENE.instantiate() as Isak
	_isak.name = "Isak"
	_isak.position = Vector2(4.5 * TILE, 10 * TILE)
	_root.add_child(_isak)
	add_child(_root)
	_isak.set_physics_process(false)
	_pulse = Area2D.new()
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 96.0
	shape.shape = circle
	shape.position = Vector2(0, -56)
	_pulse.add_child(shape)
	_isak.add_child(_pulse)
	await wait_process_frames(1)


func after_each() -> void:
	if is_instance_valid(_root):
		_root.free()
	get_tree().paused = false
	DebugMode.reset()
	DebugMode.input_enabled = true
	GameState.reset_progress()
	GameSettings.use_path(_settings_path, true)


func _add(type: String, cell: Vector2i, props: Dictionary = {}) -> Node2D:
	var path: String = String(World1ObjectsConfig.type_entry(type).get("scene", ""))
	var node := (load(path) as PackedScene).instantiate() as Node2D
	node.position = Vector2(cell) * TILE
	for key: String in props:
		node.set(key, props[key])
	_root.add_child(node)
	return node


func _isak_at(col: int, row: int) -> void:
	_isak.global_position = Vector2((col + 0.5) * TILE, (row + 1) * TILE)


func _fire_pulse() -> void:
	EventBus.pulse_fired.emit(_pulse)


# --- PowerSwitch ---

func test_power_switch_counts_pulses_with_back_pose() -> void:
	var sw := _add("power_switch", Vector2i(4, 9), {"object_id": &"luz", "pulses_required": 3}) as PowerSwitch
	assert_eq(sw.get_lit_lamps(), 0)
	_isak_at(10, 9)
	_fire_pulse()
	assert_eq(sw.get_count(), 0, "Lejos: no cuenta")
	_isak_at(4, 9)
	watch_signals(sw)
	_fire_pulse()
	assert_eq(sw.get_count(), 1)
	assert_true(_isak.is_facing_back(), "De espaldas")
	assert_eq(sw.get_animation(), &"power_switch_hit")
	sw.advance(0.5)
	assert_false(_isak.is_facing_back(), "Vuelve de perfil tras pose_s")
	_fire_pulse()
	sw.advance(0.5)
	_fire_pulse()
	sw.advance(0.5)
	assert_true(sw.is_activated())
	assert_signal_emitted(sw, "activated")
	assert_eq(sw.get_lit_lamps(), 3)
	assert_almost_eq(sw.get_progress(), 1.0, 0.001)
	assert_eq(sw.get_animation(), &"power_switch_on")
	assert_false(sw.receive_pulse(_pulse), "Activado: inerte")
	assert_false(sw.is_help_available())


func test_power_switch_done_if_ally() -> void:
	GameState.meet_ally(GameState.ALLY_CALC)
	var sw := _add("power_switch", Vector2i(4, 9), {"object_id": &"luz", "done_if_ally": &"calc"}) as PowerSwitch
	assert_true(sw.is_activated(), "Calc conocida: ya activado")
	_fire_pulse()
	assert_false(_isak.is_facing_back(), "Sin pose")


func test_debug_switch_hidden_until_debug_then_marked() -> void:
	var sw := _add("debug_switch", Vector2i(4, 9), {"object_id": &"panel"}) as PowerSwitch
	sw.advance(0.0)
	assert_false(sw.visible, "Oculto")
	_fire_pulse()
	assert_eq(sw.get_count(), 0, "Oculto: no responde")
	GameState.set_ability_unlocked(GameState.ABILITY_DEBUG, true)
	GameState.debug_energy = GameState.DEBUG_ENERGY_MAX
	for i: int in roundi(DebugModeConfig.shared().activation_hold_s / DT) + 1:
		DebugMode.step(DT, true)
	DebugMode.step(DT, false)
	sw.advance(DT)
	assert_true(sw.is_revealed(), "El Debug lo descubre")
	DebugMode.reset()
	sw.advance(DT)
	assert_true(sw.visible, "Marcado sin el Debug")
	assert_lt(sw.modulate.a, 1.0, "Tenue")
	_fire_pulse()
	assert_true(sw.is_activated(), "Un pulso basta")
	assert_eq(sw.get_animation(), &"debug_switch_hit")


# --- LaserSwitch ---

func test_laser_switch_is_permanent_and_ignores_pulse() -> void:
	var sw := _add("laser_switch", Vector2i(4, 9), {"object_id": &"laser"}) as LaserSwitch
	assert_true(sw.is_in_group(LaserProjectile.GROUP_LASER_ACTIVATABLE))
	_fire_pulse()
	assert_false(sw.is_activated(), "El pulso no le hace nada")
	sw.on_laser_hit(1.0, null)
	assert_true(sw.is_activated())
	sw.advance(30.0)
	assert_true(sw.is_activated(), "Sin ventana: para siempre")
	assert_eq(sw.get_animation(), &"laser_switch_on")
	assert_false(sw.activate())


# --- GlitchWall ---

func test_glitch_wall_without_door_is_unchanged() -> void:
	var wall := _add("glitch_wall", Vector2i(6, 8)) as GlitchWall
	var sw := _add("power_switch", Vector2i(4, 9), {"object_id": &"luz", "pulses_required": 1}) as PowerSwitch
	sw.activate()
	wall.advance(1.0)
	assert_false(wall.is_door(), "Sin door_when nunca es puerta (1-1)")
	assert_true(wall.is_solid())
	assert_true(wall.is_help_available())
	assert_false(wall.is_activated())


func test_glitch_wall_becomes_a_door_with_lamps() -> void:
	var sw := _add("power_switch", Vector2i(4, 9), {"object_id": &"luz", "pulses_required": 1}) as PowerSwitch
	var laser := _add("laser_switch", Vector2i(2, 9), {"object_id": &"laser"}) as LaserSwitch
	var wall := _add("glitch_wall", Vector2i(6, 8), {"object_id": &"puerta", "door_when": &"luz",
		"door_lamps": ["luz", "laser"]}) as GlitchWall
	wall.advance(0.1)
	assert_true(wall.is_solid(), "Antes, solida aunque no se haya disuelto")
	sw.activate()
	wall.advance(DT)
	assert_true(wall.is_door())
	assert_false(wall.is_solid(), "La puerta se atraviesa")
	assert_eq(wall.get_door_animation(), &"power_door_appear")
	assert_false(wall.is_help_available(), "Ya puerta: sin la Q de la pared")
	wall.advance(1.0)
	assert_eq(wall.get_door_animation(), &"power_door_idle")
	assert_eq(wall.get_lit_lamps(), 1)
	laser.activate()
	wall.advance(DT)
	assert_eq(wall.get_lit_lamps(), 2)
	assert_eq(wall.get_door_animation(), &"power_door_open", "Todas las luces")
	assert_eq(CalcRoom.find(_isak, &"puerta"), wall)


# --- DarkRoom ---

func test_dark_room_light_by_thirds_and_debug_outlines() -> void:
	var sw := _add("power_switch", Vector2i(4, 9), {"object_id": &"luz", "pulses_required": 3}) as PowerSwitch
	var room := _add("dark_room", Vector2i(0, 0), {"width_tiles": 12, "height_tiles": 10, "switch_id": &"luz"}) as DarkRoom
	room.advance(DT)
	assert_almost_eq(room.get_veil_alpha(), 0.9, 0.001)
	for i: int in 3:
		_isak_at(4, 9)
		_fire_pulse()
		sw.advance(0.5)
		room.advance(1.0)
		assert_almost_eq(room.get_light(), (i + 1) / 3.0, 0.001, "Tercio %d" % (i + 1))
	assert_true(room.is_lit())
	assert_almost_eq(room.get_veil_alpha(), 0.0, 0.001)


func test_dark_room_debug_lowers_veil_and_shows_outlines() -> void:
	_add("power_switch", Vector2i(4, 9), {"object_id": &"luz"})
	var hidden := _add("debug_switch", Vector2i(8, 9), {"object_id": &"panel"}) as PowerSwitch
	var room := _add("dark_room", Vector2i(0, 0), {"width_tiles": 12, "height_tiles": 10, "switch_id": &"luz"}) as DarkRoom
	var dark: float = room.get_veil_alpha()
	GameState.set_ability_unlocked(GameState.ABILITY_DEBUG, true)
	GameState.debug_energy = GameState.DEBUG_ENERGY_MAX
	for i: int in roundi(DebugModeConfig.shared().activation_hold_s / DT) + 60:
		DebugMode.step(DT, i < roundi(DebugModeConfig.shared().activation_hold_s / DT) + 1)
	assert_true(DebugMode.is_active())
	assert_lt(room.get_veil_alpha(), dark, "Con el Debug se ve algo mas")
	var outlined: Array[Node2D] = room.get_outlined_nodes()
	assert_eq(outlined.size(), 1, "El interruptor; el panel aun no descubierto")
	_isak_at(8, 9)
	hidden.advance(DT)
	assert_eq(room.get_outlined_nodes().size(), 2, "Descubierto: tambien su contorno")


func test_dark_room_has_halos_and_done_if_ally() -> void:
	_add("power_switch", Vector2i(4, 9), {"object_id": &"luz"})
	var room := _add("dark_room", Vector2i(0, 0), {"width_tiles": 12, "height_tiles": 10, "switch_id": &"luz"}) as DarkRoom
	assert_eq(room.get_lights().size(), 1, "Halo del interruptor sin activar")
	GameState.meet_ally(GameState.ALLY_CALC)
	var lit := _add("dark_room", Vector2i(0, 0), {"width_tiles": 4, "height_tiles": 4, "switch_id": &"luz",
		"done_if_ally": &"calc"}) as DarkRoom
	assert_true(lit.is_lit(), "Calc conocida: con luz")


# --- ChargeDock y CalcActor ---

func test_dock_and_calc_charge_and_teleport_without_meeting() -> void:
	var sw := _add("laser_switch", Vector2i(1, 9), {"object_id": &"a"}) as LaserSwitch
	var dock := _add("charge_dock", Vector2i(8, 9), {"object_id": &"dock", "required_ids": ["a"]}) as ChargeDock
	var calc := _add("calc_actor", Vector2i(3, 9), {"object_id": &"calc", "dock_id": &"dock",
		"path_cells": [Vector2(3, 9), Vector2(8, 9)]}) as CalcActor
	var teleported: Array = []
	var on_tp := func(ally: StringName) -> void: teleported.append(ally)
	EventBus.ally_teleported.connect(on_tp)
	dock.advance(DT)
	calc.advance(DT)
	assert_false(dock.is_armed())
	assert_eq(calc.get_state(), CalcActor.State.OFF)
	assert_eq(dock.get_lit_segments(), 1, "3 %: el primer segmento")
	assert_false(dock.finish(), "No se puede terminar sin cargar")
	sw.activate()
	dock.advance(DT)
	assert_eq(dock.get_state(), ChargeDock.State.READY)
	assert_eq(dock.get_animation(), &"charge_dock_ready")
	for i: int in 600:
		calc.advance(DT)
		dock.advance(DT)
		if calc.get_state() == CalcActor.State.CHARGING:
			break
	assert_eq(calc.get_state(), CalcActor.State.CHARGING)
	assert_true(calc.get_feet().is_equal_approx(dock.get_calc_feet()))
	assert_eq(dock.get_state(), ChargeDock.State.CHARGING)
	dock.advance(dock.charge_s * 0.5)
	assert_almost_eq(calc.get_battery(), lerpf(3.0, 100.0, 0.5), 1.5, "Mitad de la carga")
	assert_true(dock.are_sparks_visible())
	dock.advance(dock.charge_s)
	assert_eq(calc.get_state(), CalcActor.State.CHARGED)
	assert_false(dock.is_power_on())
	for i: int in 600:
		calc.advance(DT)
		if calc.get_state() == CalcActor.State.GONE:
			break
	assert_eq(calc.get_state(), CalcActor.State.GONE)
	assert_true(dock.is_power_on(), "Calc se fue: hay corriente")
	assert_eq(teleported, [&"calc"])
	assert_false(GameState.has_met_ally(GameState.ALLY_CALC), "No la conoce hasta el hub (H3)")
	EventBus.ally_teleported.disconnect(on_tp)


func test_calc_known_dock_powered_and_calc_absent() -> void:
	GameState.meet_ally(GameState.ALLY_CALC)
	var dock := _add("charge_dock", Vector2i(8, 9), {"object_id": &"dock", "required_ids": ["x"],
		"done_if_ally": &"calc"}) as ChargeDock
	var calc := _add("calc_actor", Vector2i(3, 9), {"object_id": &"calc", "dock_id": &"dock",
		"path_cells": [Vector2(3, 9), Vector2(8, 9)], "done_if_ally": &"calc"}) as CalcActor
	assert_true(dock.is_power_on())
	assert_false(calc.visible)
	assert_true(calc.is_activated())


# --- ExitTerminal ---

func test_terminal_without_requires_power_is_unchanged() -> void:
	var terminal := _add("exit_terminal", Vector2i(4, 8)) as ExitTerminal
	assert_false(terminal.requires_power)
	assert_true(terminal.is_powered())
	_isak_at(4, 9)
	assert_true(terminal.receive_pulse(_pulse), "Como siempre")


func test_terminal_gets_power_from_the_dock() -> void:
	var dock := _add("charge_dock", Vector2i(8, 9), {"object_id": &"dock", "required_ids": ["x"]}) as ChargeDock
	var terminal := _add("exit_terminal", Vector2i(4, 8), {"requires_power": true, "power_source": &"dock"}) as ExitTerminal
	watch_signals(terminal)
	_isak_at(4, 9)
	terminal.advance(DT)
	assert_false(terminal.is_powered())
	assert_false(terminal.receive_pulse(_pulse), "Sin corriente no se activa")
	assert_false(terminal.is_help_available())
	dock.set(&"_state", ChargeDock.State.DONE)
	terminal.advance(DT)
	assert_signal_emitted(terminal, "powered")
	assert_true(terminal.is_help_available())
	assert_true(terminal.receive_pulse(_pulse), "Con corriente se activa")


# --- EcoGuide y EcoCompanion ---

func test_guide_is_inert_without_eco_or_with_calc_known() -> void:
	var guide := _add("eco_guide", Vector2i(0, 0), {"guide_id": &"calc_rooftop"}) as EcoGuide
	assert_true(guide.is_inert(), "Sin Eco conocido no hay guion")
	GameState.meet_ally(GameState.ALLY_ECO)
	var g2 := _add("eco_guide", Vector2i(0, 0), {"guide_id": &"calc_rooftop"}) as EcoGuide
	assert_false(g2.is_inert())
	assert_eq(g2.get_step_count(), EcoGuide.steps_of(&"calc_rooftop").size())
	GameState.meet_ally(GameState.ALLY_CALC)
	var g3 := _add("eco_guide", Vector2i(0, 0), {"guide_id": &"calc_rooftop", "done_if_ally": &"calc"}) as EcoGuide
	assert_true(g3.is_inert(), "Calc conocida: no se repite")


func test_guide_steps_from_data() -> void:
	for step: Variant in EcoGuide.steps_of(&"calc_rooftop"):
		assert_true(EcoGuide.ACTIONS.has(String((step as Dictionary)["do"])), "Accion conocida")
		if (step as Dictionary).has("text"):
			assert_false(String(step["text"]).contains("Debug"), "Eco nunca dice «usa el Debug»")
			for word: String in ["Vuelta", "vuelta", "Easy", "Normal", "Hard"]:
				assert_false(String(step["text"]).contains(word), "La UI no nombra las vueltas")
			assert_false(bool((step as Dictionary).get("important", false)), "Lineas no importantes")


func test_companion_guide_point_and_help_priority() -> void:
	GameState.meet_ally(GameState.ALLY_ECO)
	var eco := EcoCompanion.attach(_isak, _root)
	eco.auto_advance = false
	for i: int in 60:
		eco.advance(DT)
	var point: Vector2 = _isak.global_position + Vector2(200, -100)
	assert_true(eco.set_guide_point(point))
	for i: int in 120:
		eco.advance(DT)
	assert_lt(eco.get_anchor().distance_to(point), 8.0, "Eco va al punto del guion")
	assert_false(eco.is_glowing(), "Sin brillo (no es la ayuda)")
	var target := Node2D.new()
	target.position = _isak.global_position + Vector2(-100, 0)
	_root.add_child(target)
	HelpCatalog.tag(target, &"power_switch")
	eco.set_help_target(target, &"power_switch")
	for i: int in 120:
		eco.advance(DT)
	assert_true(eco.is_helping())
	assert_gt(eco.get_anchor().distance_to(point), 64.0, "La ayuda Q tiene prioridad")
	eco.set_help_target(null)
	for i: int in 120:
		eco.advance(DT)
	assert_lt(eco.get_anchor().distance_to(point), 8.0, "Vuelve al punto del guion")
	_isak.global_position += Vector2(-900, 0)
	eco.advance(DT)
	assert_false(eco.is_guiding(), "Isak lejos: lo suelta")
	_isak.global_position += Vector2(900, 0)
	assert_true(eco.set_guide_point(point))
	GameSettings.set_eco_help_shown(false)
	eco.advance(DT)
	assert_true(eco.is_guiding(), "Con las ayudas ocultas el guion sigue (historia)")
	eco.clear_guide_point()
	assert_false(eco.is_guiding())
