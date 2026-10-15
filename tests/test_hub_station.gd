# Estacion del hub (HubStation, scenes/hub/hub_station.tscn; paso 4 de
# docs/propuesta-hub-y-guardado.md §6.2): con Isak cerca sale la tecla del pulso
# (Input Map); el pulso la abre: Isak de espaldas (face_back), sin control, y
# el panel abierto; al cerrar el panel (salto o Volver) Isak vuelve de perfil
# (face_side) y recupera el control sin saltar. Arte provisional con la paleta
# del hub (los colores de data/hub.json son los de hub.gpl).
extends GutTest

const STATION_SCENE: PackedScene = preload("res://scenes/hub/hub_station.tscn")
const ISAK_SCENE: PackedScene = preload("res://scenes/player/isak.tscn")
const T: float = 64.0

var _root: Node2D
var _station: HubStation
var _isak: Isak
var _fake: PlayerInput
var _saved_pulse: bool


## Entrada falsa con el salto como flanco de un solo paso de fisica.
class OneShotJumpInput:
	extends PlayerInput
	var _queued: bool = false
	var jumps_seen: int = 0

	func queue_jump() -> void:
		_queued = true

	func poll() -> void:
		jump_pressed = _queued
		jump_held = _queued
		if _queued:
			jumps_seen += 1
		_queued = false


func before_each() -> void:
	_saved_pulse = GameState.is_ability_unlocked(GameState.ABILITY_PULSE)
	GameState.set_ability_unlocked(GameState.ABILITY_PULSE, true)
	_root = Node2D.new()
	add_child_autofree(_root)
	var floor_body := StaticBody2D.new()
	floor_body.collision_layer = 1
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(40.0 * T, T)
	shape.shape = rect
	shape.position = Vector2(20.0 * T, 10.5 * T)
	floor_body.add_child(shape)
	_root.add_child(floor_body)
	_station = STATION_SCENE.instantiate() as HubStation
	_station.station_id = &"prueba"
	_station.text = "Prueba"
	_station.position = Vector2(20.0 * T, 8.0 * T)
	_root.add_child(_station)
	_isak = ISAK_SCENE.instantiate() as Isak
	_fake = PlayerInput.new()
	_isak.input = _fake
	_isak.position = Vector2(5.5 * T, 10.0 * T)
	_root.add_child(_isak)


func after_each() -> void:
	GameState.set_ability_unlocked(GameState.ABILITY_PULSE, _saved_pulse)


func _place_isak(col: float) -> void:
	_isak.global_position = Vector2((col + 0.5) * T, 10.0 * T)
	_isak.velocity = Vector2.ZERO
	_isak.facing = 1.0


func _open_near() -> void:
	_place_isak(19.5)
	await wait_physics_frames(6)
	_station.advance(0.1)
	_isak.set_pulse_area_active(true)


func test_far_isak_sees_the_station_off() -> void:
	await wait_physics_frames(4)
	_station.advance(0.1)
	assert_eq(_station.get_state(), HubStation.State.OFF)
	assert_false(_station.is_key_hint_visible())
	assert_eq(_station.get_visual_state(), HubStation.VISUAL_OFF)


func test_near_isak_sees_the_pulse_key_from_the_input_map() -> void:
	_place_isak(21.4)
	await wait_physics_frames(6)
	_station.advance(0.1)
	assert_true(_station.is_player_near())
	assert_eq(_station.get_state(), HubStation.State.PROMPT)
	assert_true(_station.is_key_hint_visible())
	assert_eq(_station.get_key_hint_text(), PulsePrompt.key_text(&"pulse"), "Tecla de la accion pulse")
	assert_eq(_station.get_key_hint_text(), "G")
	assert_eq(_station.get_visual_state(), HubStation.VISUAL_PROMPT)
	_place_isak(5.0)
	await wait_physics_frames(6)
	_station.advance(0.1)
	assert_eq(_station.get_state(), HubStation.State.OFF, "Al alejarse se apaga")
	assert_false(_station.is_key_hint_visible())


func test_prompt_zone_is_one_and_a_half_tiles_each_side() -> void:
	var zone: Rect2 = _station.get_prompt_zone()
	assert_eq(zone.position.x, -1.5 * T)
	assert_eq(zone.end.x, T + 1.5 * T)


func test_pulse_from_far_away_does_nothing() -> void:
	_place_isak(10.0)
	await wait_physics_frames(2)
	_isak.set_pulse_area_active(true)
	assert_eq(_station.get_state(), HubStation.State.OFF)
	assert_false(_station.is_panel_open())
	assert_false(_isak.is_facing_back())


func test_pulse_opens_the_panel_with_isak_facing_back() -> void:
	var opened: Array = []
	_station.opened.connect(func(s: HubStation) -> void: opened.append(s))
	await _open_near()
	assert_eq(opened, [_station], "Senal opened")
	assert_eq(_station.get_state(), HubStation.State.OPEN)
	assert_true(_station.is_panel_open(), "Panel abierto")
	assert_true(_station.get_panel().visible)
	assert_true(_isak.is_facing_back(), "Isak de espaldas (face_back)")
	assert_eq(_isak.get_animation(), Isak.ANIM_BACK_IDLE)
	assert_false(_station.is_key_hint_visible(), "Sin tecla con el panel abierto")
	assert_eq(_station.get_visual_state(), HubStation.VISUAL_ACTIVE)
	assert_true(_station.is_flashing(), "Destello al abrir")
	assert_eq(_station.get_panel().get_title(), "Prueba")


func test_isak_does_not_move_while_the_panel_is_open() -> void:
	await _open_near()
	var x: float = _isak.global_position.x
	_fake.move_axis = 1.0
	_fake.pulse_pressed = true
	await wait_physics_frames(10)
	_fake.move_axis = 0.0
	_fake.pulse_pressed = false
	assert_almost_eq(_isak.global_position.x, x, 0.5, "Sin control con el panel abierto")
	_isak.set_pulse_area_active(true)
	assert_eq(_station.get_open_count(), 1, "Un pulso con el panel abierto no la reabre")


func test_closing_with_jump_returns_control_without_jumping() -> void:
	var closed: Array = []
	_station.closed.connect(func(s: HubStation) -> void: closed.append(s))
	var one_shot := OneShotJumpInput.new()
	_isak.input = one_shot
	await _open_near()
	await wait_physics_frames(2)
	# El salto que cierra el panel le llega a Isak en el paso de fisica
	# siguiente, como Input.is_action_just_pressed (un solo paso).
	one_shot.queue_jump()
	_station.get_panel().cancel()
	assert_false(_station.is_panel_open(), "El salto cierra el panel")
	assert_eq(_station.get_state(), HubStation.State.RETURNING)
	assert_true(_isak.is_facing_back(), "Sigue de espaldas mientras llega el salto")
	await wait_physics_frames(6)
	assert_eq(one_shot.jumps_seen, 1, "Isak leyo el salto en un paso")
	_fake = one_shot
	assert_false(_isak.is_facing_back(), "face_side al volver")
	assert_ne(_isak.get_animation(), Isak.ANIM_BACK_IDLE)
	assert_true(_isak.is_on_floor(), "El salto que cierra no le hace saltar")
	assert_eq(closed, [_station], "Senal closed")
	assert_eq(_station.get_state(), HubStation.State.PROMPT, "Sigue cerca: vuelve el prompt")
	var x: float = _isak.global_position.x
	_fake.move_axis = -1.0
	await wait_physics_frames(10)
	_fake.move_axis = 0.0
	assert_lt(_isak.global_position.x, x - 1.0, "Recupera el control")


func test_station_can_be_reopened_after_closing() -> void:
	await _open_near()
	_station.close(true)
	assert_false(_isak.is_facing_back())
	await wait_physics_frames(2)
	_station.advance(0.1)
	_isak.set_pulse_area_active(true)
	assert_eq(_station.get_state(), HubStation.State.OPEN)
	assert_eq(_station.get_open_count(), 2)


func test_back_option_closes_the_default_panel() -> void:
	await _open_near()
	var panel: HubPanel = _station.get_panel()
	assert_eq(panel.get_option_ids(), [&"back"] as Array[StringName])
	panel.confirm()
	assert_eq(_station.get_state(), HubStation.State.RETURNING)


func test_provisional_visual_is_replaceable_and_follows_the_state() -> void:
	var visual: Node2D = _station.get_visual()
	assert_not_null(visual)
	assert_eq(visual.name, &"Visual")
	assert_true(visual is HubProvisionalArt, "Sin frames: arte provisional")
	_place_isak(19.5)
	await wait_physics_frames(6)
	_station.advance(0.1)
	assert_eq((visual as HubProvisionalArt).state, HubProvisionalArt.STATE_PROMPT)


func test_hub_colors_are_the_hub_palette() -> void:
	var gpl: String = FileAccess.get_file_as_string("res://assets/palettes/hub.gpl")
	var from_gpl: Dictionary = {}
	for line: String in gpl.split("\n"):
		var tokens: PackedStringArray = line.replace("\t", " ").strip_edges().split(" ", false)
		if tokens.size() == 4 and tokens[0].is_valid_int():
			from_gpl[tokens[3]] = Color8(int(tokens[0]), int(tokens[1]), int(tokens[2]))
	assert_eq(from_gpl.size(), 16, "16 colores en hub.gpl")
	var colors: Dictionary = HubData.section("colors")
	assert_eq(colors.size(), from_gpl.size())
	for role: String in from_gpl:
		assert_eq(HubData.color(role), from_gpl[role], role)
