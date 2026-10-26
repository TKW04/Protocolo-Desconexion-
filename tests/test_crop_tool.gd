# Herramienta «Recortar» (crop_tool; 2026-10-26, paso 7 de docs/propuesta-mundo-3.md
# §8, §3.6) y marcos pequenos (small_frame, §3.3.2). Un pulso de espaldas a la
# herramienta la usa una sola vez y da Pellizcar (compress) para siempre (se
# guarda); Eco dice «Te queda mejor así.» (importante) y despues sale el aviso
# «Pellizcar: I / RB (mando)»; con el gesto ya obtenido arranca recortada e inerte
# (sin linea, aviso ni Q); un game over sin guardar lo pierde y la herramienta
# vuelve; guardado, va a la Papelera y se recupera. Sin tinte. El marco pequeno es
# solo decorado (sin colision). Ademas la sala recorte_test con el Isak real: sin
# el gesto no se cruza el marco de la pared; comprimido si, y el marco del suelo
# lleva al foso, del que se sale recuperando el tamano.
extends GutTest

const IsakSim = preload("res://tests/support/isak_sim.gd")
const ISAK_SCENE: PackedScene = preload("res://scenes/player/isak.tscn")
const ROOM_SCENE: String = "res://scenes/levels/recorte_test.tscn"
const PATH: String = "user://test_crop_tool_save.json"
const TILE: float = 64.0
const DT: float = 1.0 / 60.0
const COMPRESS: StringName = GameState.ABILITY_COMPRESS
const NOTICE: String = "Pellizcar: I / RB (mando)"
const ECO_LINE: String = "Te queda mejor así."

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
	GameState.set_ability_unlocked(COMPRESS, false)
	_lines.clear()
	EventBus.eco_line_requested.connect(_on_line)
	_root = Node2D.new()
	_root.name = "CropToolTest"
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
	GameState.set_ability_unlocked(COMPRESS, false)
	SaveFile.delete(PATH)
	GameState.save_path = _saved_path


func _on_line(text: String, _duration: float, important: bool) -> void:
	_lines.append({"text": text, "important": important})


func _types() -> Dictionary:
	return World3ObjectsConfig.data().get("types", {})


func _tool(cell: Vector2i = Vector2i(4, 9)) -> CropTool:
	var path: String = String(_types().get("crop_tool", {}).get("scene", ""))
	var node := (load(path) as PackedScene).instantiate() as CropTool
	node.object_id = &"recortar_prueba"
	node.ability = COMPRESS
	node.story_line = "recorte_3_2"
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


# --- Catalogo ---

func test_catalog_gives_only_compress_with_the_world_line() -> void:
	var entry: Dictionary = _types().get("crop_tool", {})
	assert_eq(entry.get("scene"), "res://scenes/levels/crop_tool.tscn")
	assert_eq(entry.get("allowed", {}).get("ability"), ["compress"])
	var section: Dictionary = World3ObjectsConfig.section("crop_tool")
	assert_eq(String(section.get("story_lines", {}).get("recorte_3_2", "")), ECO_LINE, "La frase decidida de Eco")
	assert_false(section.has("room_tint"), "Sin tinte del nivel")
	var eco_line: Dictionary = World1ObjectsConfig.data().get("types", {}).get("eco_line", {})
	assert_true((eco_line.get("allowed", {}).get("unless_ability", []) as Array).has("compress"),
		"eco_line admite unless_ability compress")


# --- Una sola vez ---

func test_one_pulse_gives_compress_then_story_then_notice() -> void:
	var notices := _notices()
	var tool := _tool()
	await wait_process_frames(1)
	assert_false(tool.is_on())
	assert_true(tool.is_help_available())
	assert_eq(tool.get_animation(), CropTool.ANIM_OFF)
	_isak_at(10, 9)
	_fire_pulse()
	assert_false(tool.is_on(), "Lejos: no llega")
	_isak_at(4, 9)
	watch_signals(tool)
	_fire_pulse()
	assert_true(tool.is_on(), "Un pulso de espaldas la usa")
	assert_signal_emitted_with_parameters(tool, "switched_on", [&"recortar_prueba", true])
	assert_true(_isak.is_facing_back(), "Isak de espaldas")
	assert_true(GameState.is_ability_obtained(COMPRESS), "Obtiene Pellizcar para siempre")
	assert_true(GameState.is_ability_unlocked(COMPRESS))
	assert_true(GameState.has_unsaved_changes(), "Queda «sin guardar», como toda habilidad")
	assert_eq(_lines.size(), 2, "Linea de Eco y aviso de control")
	assert_true(_lines[0].important and _lines[1].important, "Las dos importantes (pausan)")
	assert_eq(String(_lines[0].text), ECO_LINE, "Primero la frase de Eco")
	assert_eq(String(_lines[1].text), NOTICE, "Despues el aviso, leido del Input Map")
	assert_true(GameState.is_notice_seen(COMPRESS))
	assert_eq(tool.get_animation(), CropTool.ANIM_HIT)
	assert_false(tool.is_room_tinted(), "No tine el nivel")
	tool.advance(0.5)
	assert_false(_isak.is_facing_back(), "Vuelve de perfil tras pose_s")
	assert_eq(tool.get_animation(), CropTool.ANIM_ON)
	assert_false(tool.is_help_available(), "Usada no ayuda")
	_lines.clear()
	assert_false(tool.receive_pulse(_pulse), "Se usa una sola vez")
	assert_eq(_lines.size(), 0)
	notices.free()


func test_with_compress_already_obtained_it_starts_used_and_inert() -> void:
	GameState.obtain_ability(COMPRESS)
	GameState.mark_notice_seen(COMPRESS)
	_lines.clear()
	var tool := _tool()
	await wait_process_frames(1)
	assert_true(tool.is_on(), "Arranca recortada")
	assert_true(tool.is_inert())
	assert_false(HelpCatalog.is_help_live(tool), "Sin Q")
	assert_false(tool.is_room_tinted())
	_isak_at(4, 9)
	_fire_pulse()
	assert_false(_isak.is_facing_back(), "No responde")
	assert_eq(_lines.size(), 0, "Ni linea ni aviso")


func test_eco_line_with_unless_compress_is_skipped_with_the_gesture() -> void:
	GameState.obtain_ability(COMPRESS)
	var line := EcoLine.new()
	line.text = "Prueba"
	line.unless_ability = COMPRESS
	_root.add_child(line)
	assert_true(line.is_skipped(), "Con Pellizcar ya obtenido la linea no sale")


# --- Guardado, game over y Papelera ---

func test_saved_and_reloaded() -> void:
	_tool().switch_on()
	assert_true(GameState.save_game())
	assert_true(SaveFile.read(PATH).get("abilities_obtained", []).has("compress"))
	GameState.reset_progress()
	assert_false(GameState.is_ability_unlocked(COMPRESS))
	assert_true(GameState.load_game())
	assert_true(GameState.is_ability_obtained(COMPRESS), "Tras cargar sigue obtenido")
	assert_true(GameState.is_ability_unlocked(COMPRESS))
	var again := _tool(Vector2i(8, 9))
	await wait_process_frames(1)
	assert_true(again.is_inert(), "Con la partida cargada no se repite")


func test_game_over_without_saving_loses_the_gesture_and_the_tool_comes_back() -> void:
	assert_true(GameState.save_game(), "Copia sin el gesto")
	_tool().switch_on()
	GameState.apply_rollback(GameState.ROLLBACK_GAME_OVER)
	assert_false(GameState.is_ability_obtained(COMPRESS), "Lo no guardado se pierde")
	assert_false(GameState.is_ability_unlocked(COMPRESS))
	assert_false(GameState.get_trash().get(GameState.TRASH_ABILITIES, []).has("compress"), "No estaba guardado")
	var again := _tool(Vector2i(8, 9))
	await wait_process_frames(1)
	assert_false(again.is_on(), "Tras el rollback sin el gesto, vuelve")
	_lines.clear()
	assert_true(again.switch_on())
	assert_true(GameState.is_ability_obtained(COMPRESS), "Se obtiene otra vez")
	assert_eq(_lines.size(), 1, "Con la linea de Eco")


func test_saved_gesture_goes_to_the_trash_and_comes_back() -> void:
	_tool().switch_on()
	assert_true(GameState.save_game())
	GameState.apply_rollback(GameState.ROLLBACK_GAME_OVER)
	assert_true(GameState.get_trash().get(GameState.TRASH_ABILITIES, []).has("compress"),
		"Eco lo desecha a la Papelera")
	assert_false(GameState.is_ability_unlocked(COMPRESS), "Hasta recuperarlo no hay Pellizcar")
	assert_true(GameState.recover_trash())
	assert_true(GameState.is_ability_obtained(COMPRESS), "Recuperado de la Papelera")
	var again := _tool(Vector2i(8, 9))
	await wait_process_frames(1)
	assert_true(again.is_inert())


# --- Marco pequeno ---

func test_small_frame_is_only_decor() -> void:
	var entry: Dictionary = _types().get("small_frame", {})
	assert_eq(entry.get("scene"), "res://scenes/levels/small_frame.tscn")
	assert_eq(entry.get("_help_id_planned"), "small_frame", "Lleva su help_id previsto (la Q, mas adelante)")
	var frame := (load(String(entry.get("scene"))) as PackedScene).instantiate() as SmallFrame
	frame.orientation = SmallFrame.WALL
	frame.length_tiles = 2
	_root.add_child(frame)
	assert_false((frame as Node) is CollisionObject2D, "No es un cuerpo")
	assert_eq(frame.find_children("*", "CollisionObject2D", true, false).size(), 0, "Sin colision")
	assert_eq(frame.get_hole_rect(), Rect2(0, 0, 128, 64), "Pared: hueco horizontal")
	frame.orientation = SmallFrame.FLOOR
	frame.length_tiles = 1
	assert_true(frame.is_vertical())
	assert_eq(frame.get_hole_rect(), Rect2(0, 0, 64, 64))


# --- Sala de prueba ---

func _walk(sim: IsakSim, axis: float, seconds: float) -> void:
	sim.input.move_axis = axis
	sim.step(sim.steps_for(seconds))
	sim.input.move_axis = 0.0


## Salto completo (saltar mantenido) hacia la derecha durante `seconds`.
func _jump_right(sim: IsakSim, seconds: float) -> void:
	sim.input.move_axis = 1.0
	sim.input.jump_pressed = true
	sim.input.jump_held = true
	sim.step(sim.steps_for(seconds))
	sim.input.jump_held = false
	sim.input.move_axis = 0.0


func _pinch(sim: IsakSim) -> void:
	sim.input.pinch_pressed = true
	sim.step()


func test_recorte_test_room_with_the_real_isak() -> void:
	_root.free()
	var room := (load(ROOM_SCENE) as PackedScene).instantiate()
	var sim := IsakSim.new(DT)
	sim.attach(room.get_node(^"Isak") as Isak)
	add_child_autofree(room)
	sim.take_manual_control()
	await wait_physics_frames(1)
	var tool := room.get_node(^"Objects/recortar_prueba") as CropTool
	assert_not_null(tool, "La herramienta de la sala")
	var wall_frame := room.get_node(^"Objects/marco_pared") as SmallFrame
	var floor_frame := room.get_node(^"Objects/marco_suelo") as SmallFrame
	assert_not_null(wall_frame, "Marco de la pared")
	assert_not_null(floor_frame, "Marco del suelo")
	assert_true(floor_frame.is_vertical())
	assert_false(GameState.is_ability_unlocked(COMPRESS), "La sala empieza sin Pellizcar")
	# Sin el gesto, el marco de la pared no se cruza.
	sim.isak.global_position = Vector2(8.5 * TILE, 10 * TILE)
	sim.settle()
	_walk(sim, 1.0, 2.5)
	assert_lt(sim.isak.global_position.x, 12.0 * TILE, "Sin comprimir no cabe por el marco")
	_pinch(sim)
	assert_false(sim.isak.is_compressed(), "Sin la habilidad no se comprime")
	# Pulso de espaldas a «Recortar».
	sim.isak.global_position = Vector2(5.5 * TILE, 10 * TILE)
	sim.settle()
	sim.input.pulse_pressed = true
	sim.step()
	assert_true(tool.is_on(), "El pulso de espaldas la usa")
	assert_true(GameState.is_ability_obtained(COMPRESS))
	tool.advance(0.5)
	sim.step_until(func() -> bool: return sim.state() == PlayerState.IDLE and not sim.isak.is_facing_back(),
		sim.steps_for(1.5))
	# Comprimido cruza el marco de la pared (columnas 12-13, fila 9).
	_pinch(sim)
	assert_true(sim.isak.is_compressed(), "Ya se comprime")
	_walk(sim, 1.0, 3.5)
	assert_gt(sim.isak.global_position.x, 14.0 * TILE, "Comprimido cruza el marco de la pared")
	# Sigue comprimido: cae por el marco del suelo (columna 17) a la galeria y llega al foso.
	_walk(sim, 1.0, 5.0)
	assert_gt(sim.isak.global_position.x, 24.0 * TILE, "Por la galeria de 1 fila hasta el foso")
	assert_lt(sim.isak.global_position.x, 27.0 * TILE)
	assert_gt(sim.isak.global_position.y, 11.5 * TILE, "En el fondo del foso")
	# Comprimido no sube a la repisa (2 tiles).
	_jump_right(sim, 1.2)
	assert_gt(sim.isak.global_position.y, 11.5 * TILE, "El salto comprimido no llega a la repisa")
	# Recupera el tamano y sube.
	_pinch(sim)
	assert_false(sim.isak.is_compressed(), "En el foso hay sitio para recuperar el tamano")
	sim.settle()
	sim.isak.global_position.x = 26.5 * TILE
	sim.settle()
	_jump_right(sim, 1.5)
	assert_gt(sim.isak.global_position.x, 27.0 * TILE, "Con su tamano sube a la repisa de la terminal")
	assert_lt(sim.isak.global_position.y, 10.5 * TILE)
