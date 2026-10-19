# Interruptor «No molestar» (dnd_switch; 2026-10-19, paso 3 del plan de
# docs/propuesta-1-3.md §7, §3.1 y §5.1): un pulso de espaldas lo enciende una
# sola vez y da el dash para siempre (se guarda), Eco dice su linea de historia
# (importante; texto propuesto) y despues sale el aviso «Deslizar: L / B
# (mando)»; con el dash ya obtenido arranca encendido e inerte (sin linea ni
# aviso ni Q, regla de unless_ability); un game over sin guardar lo pierde y el
# interruptor vuelve; guardado, va a la Papelera y se recupera. Ademas la sala de
# prueba ajustes_test con el Isak real y unless_ability "dash" en eco_line.
extends GutTest

const IsakSim = preload("res://tests/support/isak_sim.gd")
const ISAK_SCENE: PackedScene = preload("res://scenes/player/isak.tscn")
const ROOM_SCENE: String = "res://scenes/levels/ajustes_test.tscn"
const ECO_LINE_SCENE: String = "res://scenes/levels/eco_line.tscn"
const PATH: String = "user://test_dnd_switch_save.json"
const TILE: float = 64.0
const DT: float = 1.0 / 60.0
const DASH_NOTICE: String = "Deslizar: L / B (mando)"

var _root: Node2D
var _isak: Isak
var _pulse: Area2D
var _saved_path: String
var _saved_pause: bool
var _lines: Array[Dictionary] = []


func before_each() -> void:
	_saved_path = GameState.save_path
	_saved_pause = EcoTextBox.pause_important
	EcoTextBox.pause_important = false
	GameState.use_save_path(PATH, true)
	GameState.reset_progress()
	GameState.set_ability_unlocked(GameState.ABILITY_DASH, false)
	_lines.clear()
	EventBus.eco_line_requested.connect(_on_line)
	_root = Node2D.new()
	_root.name = "DndSwitchTest"
	_isak = ISAK_SCENE.instantiate() as Isak
	_isak.name = "Isak"
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
	EventBus.eco_line_requested.disconnect(_on_line)
	if is_instance_valid(_root):
		_root.free()
	get_tree().paused = false
	EcoTextBox.pause_important = _saved_pause
	GameState.reset_progress()
	GameState.set_ability_unlocked(GameState.ABILITY_DASH, false)
	SaveFile.delete(PATH)
	GameState.save_path = _saved_path


func _on_line(text: String, _duration: float, important: bool) -> void:
	_lines.append({"text": text, "important": important})


func _switch(cell: Vector2i = Vector2i(4, 9)) -> DndSwitch:
	var path: String = String(World1ObjectsConfig.type_entry("dnd_switch").get("scene", ""))
	var node := (load(path) as PackedScene).instantiate() as DndSwitch
	node.object_id = &"dnd_prueba"
	node.ability = GameState.ABILITY_DASH
	node.story_line = "dnd_1_3"
	node.position = Vector2(cell) * TILE
	_root.add_child(node)
	return node


func _isak_at(col: int, row: int) -> void:
	_isak.global_position = Vector2((col + 0.5) * TILE, (row + 1) * TILE)


func _fire_pulse() -> void:
	EventBus.pulse_fired.emit(_pulse)


func _notices() -> AbilityNotices:
	var notices := AbilityNotices.new()
	notices.auto_advance = false
	_root.add_child(notices)
	notices.begin_level()
	notices.advance(5.0)
	return notices


# --- Una sola vez ---

func test_catalog_and_story_line_are_marked_as_proposal() -> void:
	var entry: Dictionary = World1ObjectsConfig.type_entry("dnd_switch")
	assert_eq(entry.get("scene"), "res://scenes/levels/dnd_switch.tscn")
	assert_eq(entry.get("allowed", {}).get("ability"), ["dash"])
	var section: Dictionary = World1ObjectsConfig.section("dnd_switch")
	assert_true(String(section.get("_notes", "")).contains("POR DECIDIR"), "Texto propuesto, por decidir")
	assert_false(String(section.get("story_lines", {}).get("dnd_1_3", "")).is_empty())


func test_one_pulse_gives_the_dash_then_story_then_notice() -> void:
	GameState.set_nickname("Pixel")
	var notices := _notices()
	var sw := _switch()
	await wait_process_frames(1)
	assert_false(sw.is_on())
	assert_true(sw.is_help_available())
	_isak_at(10, 9)
	_fire_pulse()
	assert_false(sw.is_on(), "Lejos: no llega")
	_isak_at(4, 9)
	watch_signals(sw)
	_fire_pulse()
	assert_true(sw.is_on(), "Un pulso lo enciende")
	assert_signal_emitted_with_parameters(sw, "switched_on", [&"dnd_prueba", true])
	assert_true(_isak.is_facing_back(), "Isak de espaldas, como en el power_switch")
	assert_true(GameState.is_ability_obtained(GameState.ABILITY_DASH), "Obtiene Deslizar para siempre")
	assert_true(GameState.is_ability_unlocked(GameState.ABILITY_DASH))
	assert_true(GameState.has_unsaved_changes(), "Queda «sin guardar», como toda habilidad")
	assert_true(GameState.to_save_data().get("abilities_obtained", []).has("dash"), "En la copia")
	assert_eq(_lines.size(), 2, "Linea de historia y aviso de control")
	assert_true(_lines[0].important and _lines[1].important, "Las dos importantes (pausan)")
	assert_true(String(_lines[0].text).contains("Pixel"), "Primero la historia, con el apodo")
	assert_eq(String(_lines[1].text), DASH_NOTICE, "Despues el aviso, leido del Input Map")
	assert_true(GameState.is_notice_seen(GameState.ABILITY_DASH))
	assert_eq(sw.get_animation(), &"power_switch_hit")
	sw.advance(0.5)
	assert_false(_isak.is_facing_back(), "Vuelve de perfil tras pose_s")
	assert_eq(sw.get_animation(), &"power_switch_on")
	assert_false(sw.is_help_available(), "Encendido no ayuda")
	_lines.clear()
	assert_false(sw.receive_pulse(_pulse), "Se pulsa una sola vez")
	assert_eq(_lines.size(), 0)
	notices.free()


func test_with_the_dash_already_obtained_it_starts_on_and_inert() -> void:
	GameState.obtain_ability(GameState.ABILITY_DASH)
	GameState.mark_notice_seen(GameState.ABILITY_DASH)
	_lines.clear()
	var sw := _switch()
	await wait_process_frames(1)
	assert_true(sw.is_on(), "Arranca encendido")
	assert_true(sw.is_inert())
	assert_false(HelpCatalog.is_help_live(sw), "Sin Q")
	_isak_at(4, 9)
	_fire_pulse()
	assert_false(_isak.is_facing_back(), "No responde")
	assert_eq(_lines.size(), 0, "Ni historia ni aviso")


# --- Guardado, game over y Papelera ---

func test_saved_and_reloaded() -> void:
	_switch().switch_on()
	assert_true(GameState.save_game())
	assert_true(SaveFile.read(PATH).get("abilities_obtained", []).has("dash"))
	GameState.reset_progress()
	assert_false(GameState.is_ability_unlocked(GameState.ABILITY_DASH))
	assert_true(GameState.load_game())
	assert_true(GameState.is_ability_obtained(GameState.ABILITY_DASH), "Tras cargar sigue obtenido")
	assert_true(GameState.is_ability_unlocked(GameState.ABILITY_DASH))
	var again := _switch(Vector2i(8, 9))
	await wait_process_frames(1)
	assert_true(again.is_inert(), "Con la partida cargada no se repite")


func test_game_over_without_saving_loses_the_dash_and_the_switch_comes_back() -> void:
	assert_true(GameState.save_game(), "Copia sin el dash")
	_switch().switch_on()
	GameState.apply_rollback(GameState.ROLLBACK_GAME_OVER)
	assert_false(GameState.is_ability_obtained(GameState.ABILITY_DASH), "Lo no guardado se pierde")
	assert_false(GameState.is_ability_unlocked(GameState.ABILITY_DASH))
	assert_false(GameState.get_trash().get(GameState.TRASH_ABILITIES, []).has("dash"), "No estaba guardado")
	var again := _switch(Vector2i(8, 9))
	await wait_process_frames(1)
	assert_false(again.is_on(), "Tras el rollback sin el dash, vuelve apagado")
	_lines.clear()
	assert_true(again.switch_on())
	assert_true(GameState.is_ability_obtained(GameState.ABILITY_DASH), "Se obtiene otra vez")
	assert_eq(_lines.size(), 1, "Con su linea de historia")


func test_saved_dash_goes_to_the_trash_and_comes_back() -> void:
	_switch().switch_on()
	assert_true(GameState.save_game())
	GameState.apply_rollback(GameState.ROLLBACK_GAME_OVER)
	assert_true(GameState.get_trash().get(GameState.TRASH_ABILITIES, []).has("dash"), "Eco lo desecha a la Papelera")
	assert_false(GameState.is_ability_unlocked(GameState.ABILITY_DASH), "Hasta recuperarlo no hay dash")
	assert_true(GameState.recover_trash())
	assert_true(GameState.is_ability_obtained(GameState.ABILITY_DASH), "Recuperado de la Papelera")
	assert_true(GameState.is_ability_unlocked(GameState.ABILITY_DASH))
	var again := _switch(Vector2i(8, 9))
	await wait_process_frames(1)
	assert_true(again.is_inert())


func test_eco_line_unless_ability_dash() -> void:
	var line := (load(ECO_LINE_SCENE) as PackedScene).instantiate()
	line.set(&"text", "Linea de prueba")
	line.set(&"unless_ability", GameState.ABILITY_DASH)
	assert_false(bool(line.call(&"is_skipped")) if line.has_method(&"is_skipped") else false,
		"Sin el dash la linea sale")
	GameState.obtain_ability(GameState.ABILITY_DASH)
	_root.add_child(line)
	await wait_process_frames(1)
	assert_true(bool(line.call(&"is_skipped")), "Con el dash ya obtenido no sale (unless_ability: dash)")


# --- Sala de prueba ---

func test_ajustes_test_room_with_the_real_isak() -> void:
	_root.free()
	var room := (load(ROOM_SCENE) as PackedScene).instantiate()
	var sim := IsakSim.new(DT)
	sim.attach(room.get_node(^"Isak") as Isak)
	add_child_autofree(room)
	sim.take_manual_control()
	await wait_physics_frames(1)
	var sw := room.get_node(^"Objects/dnd_ajustes") as DndSwitch
	assert_not_null(sw, "El interruptor de la sala")
	assert_false(GameState.is_ability_unlocked(GameState.ABILITY_DASH), "La sala empieza sin el dash")
	assert_true(GameState.is_ability_unlocked(GameState.ABILITY_PULSE))
	sim.isak.global_position = Vector2((7 + 0.5) * TILE, 11 * TILE)
	sim.settle()
	sim.input.dash_pressed = true
	sim.step()
	assert_ne(sim.state(), PlayerState.DASH, "Sin el gesto no hay dash")
	sim.input.pulse_pressed = true
	sim.step()
	assert_true(sw.is_on(), "El pulso de espaldas lo enciende")
	assert_true(GameState.is_ability_obtained(GameState.ABILITY_DASH))
	sw.advance(0.5)
	sim.step_until(func() -> bool: return sim.state() == PlayerState.IDLE and not sim.isak.is_facing_back(),
		sim.steps_for(1.0))
	var x: float = sim.isak.global_position.x
	var ends: Array[float] = []
	sim.isak.dash_ended.connect(func() -> void: ends.append(sim.isak.global_position.x))
	sim.input.dash_pressed = true
	sim.step()
	assert_eq(sim.state(), PlayerState.DASH, "Ya puede deslizarse")
	sim.step_until(func() -> bool: return not sim.isak.is_dashing(), sim.steps_for(1.0))
	assert_eq(ends.size(), 1)
	assert_almost_eq(ends[0] - x, 192.0, 1.0, "3 tiles")
