# Pruebas del paso 14b: pop-up bloqueante (scenes/levels/popup_blocker.tscn),
# puerta de salida (scenes/levels/exit_door.tscn) y escena de prueba del
# Tramo 4, que al cruzar la puerta va al hub real (paso 9; la pantalla
# provisional del hub se retiro). El pop-up es solido hasta que un pulso toca su
# BOTON (no basta con tocar la ventana) y no se reabre; la puerta emite
# level_completed una sola vez; los textos usan solo glifos de la fuente; el
# catalogo apunta a las escenas reales.
extends GutTest

const IsakSim = preload("res://tests/support/isak_sim.gd")
const POPUP_SCENE: PackedScene = preload("res://scenes/levels/popup_blocker.tscn")
const DOOR_SCENE: PackedScene = preload("res://scenes/levels/exit_door.tscn")
const TEST_SCENE: String = "res://scenes/levels/tramo4_test.tscn"
const LEVEL_PATH: String = "res://data/levels/1-1.json"
const DT: float = 1.0 / 60.0
const T: float = 64.0
const POPUP_TEXT: String = "¿Seguro que quieres seguir concentrado? Tenemos ofertas"
## Pop-up de 3x4 tiles apoyado en el suelo (y = 0): esquina en (POPUP_X, -256).
const POPUP_X: float = 512.0

var _pulse_was_unlocked: bool = false


func before_each() -> void:
	_pulse_was_unlocked = GameState.is_ability_unlocked(GameState.ABILITY_PULSE)
	GameState.set_ability_unlocked(GameState.ABILITY_PULSE, true)


func after_each() -> void:
	GameState.set_ability_unlocked(GameState.ABILITY_PULSE, _pulse_was_unlocked)
	DebugMode.reset()


# --- Utilidades ---

func _fake_pulse(center: Vector2, radius: float, parent: Node = null) -> Area2D:
	var area := Area2D.new()
	area.collision_layer = 8
	area.collision_mask = 0
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = radius
	shape.shape = circle
	area.add_child(shape)
	area.position = center
	if parent == null:
		add_child_autofree(area)
	else:
		parent.add_child(area)
	return area


func _popup(parent: Node = null) -> PopupBlocker:
	var p := POPUP_SCENE.instantiate() as PopupBlocker
	p.text = POPUP_TEXT
	p.close_button_position = Vector2(4.0, 192.0)
	p.position = Vector2(POPUP_X, -4.0 * T)
	if parent == null:
		add_child_autofree(p)
	else:
		parent.add_child(p)
	return p


## Mundo llano (suelo en y = 0) con Isak y un pop-up delante.
func _world_with_popup() -> Dictionary:
	var sim := IsakSim.new(DT)
	var world: Node2D = sim.build_flat_world()
	add_child_autofree(world)
	sim.take_manual_control()
	var popup: PopupBlocker = _popup(world)
	sim.isak.global_position = Vector2(POPUP_X - 200.0, 0.0)
	await wait_physics_frames(2)
	sim.settle()
	return {"sim": sim, "popup": popup, "world": world}


func _uses_only_font_glyphs(font: Font, text: String) -> Array[String]:
	var missing: Array[String] = []
	for ch: String in text:
		if ch != "\n" and not font.has_char(ch.unicode_at(0)):
			missing.append(ch)
	return missing


# --- Pop-up ---

func test_popup_blocks_until_pulse_hits_button() -> void:
	var w: Dictionary = await _world_with_popup()
	var sim: IsakSim = w.sim
	var popup: PopupBlocker = w.popup
	sim.input.move_axis = 1.0
	sim.step(sim.steps_for(2.0))
	assert_true(popup.is_solid())
	assert_lt(sim.isak.global_position.x, POPUP_X - 15.0, "El pop-up abierto bloquea el paso")
	# Pulso real de Isak pegado al pop-up (celular a la altura del boton).
	sim.input.move_axis = 0.0
	sim.settle()
	watch_signals(popup)
	sim.input.pulse_pressed = true
	sim.step()
	assert_signal_emitted(popup, "closing_started", "El pulso en el boton empieza el cierre")
	popup.advance(1.0)
	assert_true(popup.is_closed())
	assert_false(popup.is_solid())
	await wait_physics_frames(2)
	sim.input.move_axis = 1.0
	sim.step(sim.steps_for(2.5))
	assert_gt(sim.isak.global_position.x, POPUP_X + 3.0 * T + 16.0, "Cerrado: Isak lo atraviesa")


func test_pulse_on_window_but_not_button_does_not_close() -> void:
	var popup: PopupBlocker = _popup()
	var window: Rect2 = popup.get_window_rect()
	var button: Rect2 = popup.get_button_rect()
	# Centro de la ventana, barra de titulo y justo encima del boton: tocan la
	# ventana pero no el boton.
	var cases: Array[Area2D] = [
		_fake_pulse(window.get_center(), 60.0),
		_fake_pulse(window.position + Vector2(20.0, 10.0), 40.0),
		_fake_pulse(button.position + Vector2(8.0, -50.0), 40.0),
		_fake_pulse(button.position + Vector2(40.0, 8.0), 20.0),
	]
	for area: Area2D in cases:
		assert_true(window.has_point(area.global_position), "El pulso cae dentro de la ventana")
		EventBus.pulse_fired.emit(area)
	popup.advance(1.0)
	assert_true(popup.is_open(), "Ningun pulso fuera del boton lo cierra")
	assert_true(popup.is_solid())
	EventBus.pulse_fired.emit(_fake_pulse(button.get_center() + Vector2(-30.0, 0.0), 30.0))
	assert_eq(popup.get_state(), PopupBlocker.State.CLOSING, "Un pulso que toca el boton si")


func test_far_isak_pulse_does_not_reach_button() -> void:
	var w: Dictionary = await _world_with_popup()
	var sim: IsakSim = w.sim
	var popup: PopupBlocker = w.popup
	sim.isak.global_position = Vector2(POPUP_X - 3.0 * T, 0.0)
	sim.settle()
	sim.input.pulse_pressed = true
	sim.step()
	popup.advance(1.0)
	assert_true(popup.is_open(), "A 3 tiles el pulso (96 px) no alcanza el boton")


func test_popup_never_reopens_and_closes_once() -> void:
	var popup: PopupBlocker = _popup()
	watch_signals(popup)
	var hit: Area2D = _fake_pulse(popup.get_button_rect().get_center(), 10.0)
	assert_true(popup.receive_pulse(hit))
	assert_false(popup.receive_pulse(hit), "Cerrandose ignora otro pulso")
	for i: int in 30:
		popup.advance(DT)
	assert_true(popup.is_closed())
	assert_false(popup.receive_pulse(hit), "Cerrado ignora el pulso")
	popup.close()
	popup.advance(1.0)
	assert_true(popup.is_closed(), "No se vuelve a abrir")
	assert_signal_emit_count(popup, "closing_started", 1)
	assert_signal_emit_count(popup, "closed", 1)


func test_close_animation_is_discrete_steps() -> void:
	var popup: PopupBlocker = _popup()
	assert_eq(popup.get_window_frame(), 0)
	popup.close()
	var seen: Array[int] = []
	for i: int in 40:
		popup.advance(DT)
		if popup.is_closed():
			break
		if seen.is_empty() or seen.back() != popup.get_window_frame():
			seen.append(popup.get_window_frame())
	assert_eq(seen, [1, 2, 3, 4], "Cuadros de cierre en orden")
	assert_true(popup.is_closed())


func test_button_area_overlap_closes() -> void:
	var popup: PopupBlocker = _popup()
	await wait_physics_frames(1)
	_fake_pulse(popup.get_button_rect().get_center(), 8.0)
	await wait_physics_frames(3)
	assert_ne(popup.get_state(), PopupBlocker.State.OPEN, "Solapamiento fisico con el Area2D del boton")


func test_level_popup_button_at_standing_phone_height() -> void:
	var level: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(LEVEL_PATH))
	var entry: Dictionary = {}
	for o: Dictionary in level["objects"]:
		if o["type"] == "popup_blocker":
			entry = o
	var params: Dictionary = entry["params"]
	var b: Array = params["close_button_px"]
	var size: float = float(params["close_button_size_px"])
	var top_y: float = float(entry["y"]) * T
	var floor_y: float = (float(entry["y"]) + float(params["height_tiles"])) * T
	assert_eq(level["grid"][int(floor_y / T)][int(entry["x"])], "#", "El pop-up se apoya en el suelo")
	var isak := (load("res://scenes/player/isak.tscn") as PackedScene).instantiate() as Isak
	var phone_y: float = floor_y + isak.pulse_effect_origin.y
	isak.free()
	assert_between(phone_y, top_y + float(b[1]), top_y + float(b[1]) + size, "Boton a la altura del celular de pie")
	assert_eq(size, 16.0, "Boton diminuto (16 px)")
	assert_lt(float(b[0]) + size, T * 0.5, "En el borde izquierdo (el lado por el que llega Isak)")


func test_popup_text_wraps_inside_and_uses_font_glyphs() -> void:
	var popup: PopupBlocker = _popup()
	assert_gt(popup.get_text_lines().size(), 1)
	assert_eq(" ".join(popup.get_text_lines()), POPUP_TEXT)
	assert_eq(_uses_only_font_glyphs(popup.get_font(), POPUP_TEXT), [] as Array[String])


# --- Puerta ---

func test_door_emits_level_completed_once_on_touch() -> void:
	var sim := IsakSim.new(DT)
	var world: Node2D = sim.build_flat_world()
	add_child_autofree(world)
	sim.take_manual_control()
	var door := DOOR_SCENE.instantiate() as ExitDoor
	door.level_id = "1-1"
	door.position = Vector2(300.0, -2.0 * T)
	world.add_child(door)
	await wait_physics_frames(2)
	sim.settle()
	watch_signals(door)
	watch_signals(EventBus)
	sim.input.move_axis = 1.0
	for i: int in 120:
		sim.step()
		await wait_physics_frames(1)
		if door.get_state() != ExitDoor.State.CLOSED:
			break
	assert_signal_emit_count(door, "entered", 1, "Al tocarla Isak entra")
	assert_signal_emit_count(EventBus, "level_completed", 0, "Aun se esta abriendo")
	assert_true(sim.isak.input != sim.input, "La entrada de Isak queda bloqueada")
	for i: int in 60:
		door.advance(DT)
	assert_signal_emit_count(door, "completed", 1)
	assert_signal_emit_count(EventBus, "level_completed", 1)
	assert_signal_emitted_with_parameters(EventBus, "level_completed", ["1-1"])
	assert_almost_eq(sim.isak.modulate.a, 0.0, 0.001, "Isak se ha desvanecido")
	# Tocarla otra vez no repite nada.
	assert_false(door.enter(sim.isak))
	door.advance(1.0)
	sim.isak.global_position = Vector2(-200.0, 0.0)
	await wait_physics_frames(2)
	sim.isak.global_position = Vector2(332.0, 0.0)
	await wait_physics_frames(3)
	door.advance(1.0)
	assert_signal_emit_count(EventBus, "level_completed", 1, "Una sola vez")
	assert_eq(door.get_completed_count(), 1)
	door.release_player()
	assert_eq(sim.isak.input, sim.input, "release_player devuelve el control")


func test_door_ignores_non_player_and_uses_current_level() -> void:
	var door := DOOR_SCENE.instantiate() as ExitDoor
	add_child_autofree(door)
	var previous: StringName = GameState.current_level
	GameState.current_level = &"1-1"
	assert_eq(door.resolved_level_id(), "1-1")
	GameState.current_level = previous
	var other := StaticBody2D.new()
	door._on_body_entered(other)
	other.free()
	assert_eq(door.get_state(), ExitDoor.State.CLOSED)


func test_door_label_uses_existing_glyphs_and_sits_above() -> void:
	var door := DOOR_SCENE.instantiate() as ExitDoor
	add_child_autofree(door)
	assert_eq(door.get_label().text, "Marcar como leído")
	assert_eq(_uses_only_font_glyphs(door.get_font(), door.text), [] as Array[String])
	var label: Rect2 = door.get_label_rect()
	var rect: Rect2 = door.get_door_rect()
	assert_lt(label.end.y, rect.position.y, "Etiqueta encima de la puerta")
	assert_almost_eq(label.get_center().x, rect.get_center().x, 2.0, "Centrada sobre la puerta")


func test_door_glows_while_closed() -> void:
	var door := DOOR_SCENE.instantiate() as ExitDoor
	add_child_autofree(door)
	var frames: Dictionary = {}
	for i: int in 90:
		door.advance(DT)
		frames[door.get_frame()] = true
	assert_eq(frames.keys().size(), 2, "Alterna cerrada y brillo")


# --- Escena de prueba y catalogo ---

func test_tramo4_scene_flow_goes_to_real_hub() -> void:
	var scene := (load(TEST_SCENE) as PackedScene).instantiate()
	add_child_autofree(scene)
	await wait_physics_frames(2)
	var door: ExitDoor = scene.get_node(^"ExitDoor")
	assert_not_null(scene.get_node(^"Hud"))
	assert_not_null(scene.get_node(^"PopupBlocker") as PopupBlocker)
	var switched: Array[String] = []
	scene.set(&"scene_switcher", func(path: String) -> void: switched.append(path))
	door.enter(scene.get_node(^"Isak") as Isak)
	door.advance(2.0)
	assert_eq(scene.call(&"get_completed_level"), "1-1")
	assert_eq(switched, ["res://scenes/hub/hub.tscn"] as Array[String], "level_completed lleva al hub real")
	assert_true(ResourceLoader.exists(switched[0]))
	door.release_player()


func test_catalog_popup_and_door_have_real_scenes() -> void:
	var types: Dictionary = World1ObjectsConfig.data()["types"]
	for type: String in ["popup_blocker", "exit_door"]:
		var entry: Dictionary = types[type]
		assert_false(entry.has("status"), "%s ya no esta pendiente" % type)
		var scene := load(String(entry["scene"])) as PackedScene
		assert_not_null(scene, type)
		var node: Node = scene.instantiate()
		for field: String in entry["fields"]:
			assert_true(String(entry["fields"][field]) in node, "%s.%s" % [type, field])
		for field: String in entry["required"]:
			assert_true(entry["example"]["params"].has(field))
		node.free()
	assert_true(types["popup_blocker"]["fields"].has("close_button_size_px"))


func test_level_json_still_valid() -> void:
	var output: Array = []
	var code: int = OS.execute("python3", [ProjectSettings.globalize_path("res://tools/validate_level_schema.py"),
		ProjectSettings.globalize_path(LEVEL_PATH)], output, true)
	if code == -1:
		pending("python3 no disponible")
		return
	assert_eq(code, 0, "validate_level_schema: %s" % "".join(output))
