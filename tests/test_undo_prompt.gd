# «¿Deshacer escritura?» (undo_prompt), muro de texto (typed_wall) y la Papelera en
# el nivel (papelera_actor); 2026-10-28, paso 8 de docs/propuesta-mundo-4.md §8, §3.7
# y §4.2.2. Un pulso de espaldas al panel lo usa una sola vez y da Agitar
# (shockwave) para siempre (se guarda); Eco dice «No necesitas a nadie más.»
# (importante) y despues sale el aviso «Agitar: U / LB (mando)»; con el gesto ya
# obtenido arranca deshecho e inerte; un game over sin guardar lo pierde y el panel
# vuelve; guardado, va a la Papelera y se recupera. La Papelera habla al acercarse
# Isak (dos lineas importantes, una sola vez: seen_notices papelera_4_2) y, al
# obtener Agitar, su ultima linea en voz baja (no importante, detras de la de Eco y
# el aviso). El muro de texto solo cae con Agitar (0,4 s, para siempre); el pulso y
# el laser rebotan. Ademas la sala borrados_test con el Isak real.
extends GutTest

const IsakSim = preload("res://tests/support/isak_sim.gd")
const ISAK_SCENE: PackedScene = preload("res://scenes/player/isak.tscn")
const ROOM_SCENE: String = "res://scenes/levels/borrados_test.tscn"
const PATH: String = "user://test_undo_prompt_save.json"
const TILE: float = 64.0
const DT: float = 1.0 / 60.0
const SHAKE: StringName = GameState.ABILITY_SHOCKWAVE
const NOTICE: String = "Agitar: U / LB (mando)"
const ECO_LINE: String = "No necesitas a nadie más."
const STORY_NOTICE: StringName = &"papelera_4_2"

var _root: Node2D
var _isak: Isak
var _pulse: Area2D
var _saved_path: String
var _saved_pause: bool
var _saved_unlocked: Dictionary = {}
var _lines: Array[Dictionary] = []


func before_each() -> void:
	_saved_path = GameState.save_path
	_saved_pause = EcoTextBox.pause_important
	EcoTextBox.pause_important = false
	for ability: StringName in [GameState.ABILITY_PULSE, GameState.ABILITY_DEBUG, SHAKE]:
		_saved_unlocked[ability] = GameState.is_ability_unlocked(ability)
	GameState.use_save_path(PATH, true)
	GameState.reset_progress()
	GameState.set_ability_unlocked(SHAKE, false)
	_lines.clear()
	EventBus.eco_line_requested.connect(_on_line)
	_root = Node2D.new()
	_root.name = "UndoPromptTest"
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
	for ability: StringName in _saved_unlocked:
		GameState.set_ability_unlocked(ability, _saved_unlocked[ability])
	SaveFile.delete(PATH)
	GameState.save_path = _saved_path


func _on_line(text: String, _duration: float, important: bool) -> void:
	_lines.append({"text": text, "important": important})


func _types() -> Dictionary:
	return World4ObjectsConfig.data().get("types", {})


func _scene(kind: String) -> Node:
	return (load(String(_types().get(kind, {}).get("scene", ""))) as PackedScene).instantiate()


func _prompt(cell: Vector2i = Vector2i(4, 9)) -> UndoPrompt:
	var node := _scene("undo_prompt") as UndoPrompt
	node.object_id = &"deshacer_prueba"
	node.ability = SHAKE
	node.story_line = "deshacer_4_2"
	node.position = Vector2(cell) * TILE
	_root.add_child(node)
	return node


func _papelera(cell: Vector2i = Vector2i(6, 9)) -> PapeleraActor:
	var node := _scene("papelera_actor") as PapeleraActor
	node.object_id = &"papelera_prueba"
	node.story = "papelera_4_2"
	node.position = Vector2(cell) * TILE
	_root.add_child(node)
	return node


func _wall(cell: Vector2i = Vector2i(10, 7)) -> TypedWall:
	var node := _scene("typed_wall") as TypedWall
	node.object_id = &"muro_prueba"
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


func _texts() -> Array[String]:
	var out: Array[String] = []
	for line: Dictionary in _lines:
		out.append(String(line.text))
	return out


# --- Catalogo ---

func test_catalog_entries() -> void:
	var entry: Dictionary = _types().get("undo_prompt", {})
	assert_eq(entry.get("scene"), "res://scenes/levels/undo_prompt.tscn")
	assert_eq(entry.get("allowed", {}).get("ability"), ["shockwave"])
	var section: Dictionary = World4ObjectsConfig.section("undo_prompt")
	assert_eq(String(section.get("story_lines", {}).get("deshacer_4_2", "")), ECO_LINE, "La frase del doc")
	assert_false(section.has("room_tint"), "Sin tinte del nivel")
	assert_eq(_types().get("typed_wall", {}).get("scene"), "res://scenes/levels/typed_wall.tscn")
	assert_eq(_types().get("papelera_actor", {}).get("scene"), "res://scenes/levels/papelera_actor.tscn")
	var eco_line: Dictionary = World1ObjectsConfig.data().get("types", {}).get("eco_line", {})
	assert_true((eco_line.get("allowed", {}).get("unless_ability", []) as Array).has("shockwave"),
		"eco_line admite unless_ability shockwave")
	var box_data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/eco_text_box.json"))
	var papelera: Dictionary = box_data.get("speakers", {}).get("papelera", {})
	assert_eq(String(papelera.get("name", "")), "Papelera", "Interlocutor nuevo papelera")
	assert_eq(String(papelera.get("style", "")), "panel")
	assert_true(ResourceLoader.exists(String(papelera.get("icon", ""))), "Con su icono propio")


# --- «¿Deshacer escritura?»: una sola vez ---

func test_one_pulse_gives_shockwave_then_eco_then_notice() -> void:
	var notices := _notices()
	var prompt := _prompt()
	await wait_process_frames(1)
	assert_false(prompt.is_on())
	assert_true(prompt.is_help_available())
	assert_eq(prompt.get_animation(), UndoPrompt.ANIM_OFF)
	_isak_at(10, 9)
	_fire_pulse()
	assert_false(prompt.is_on(), "Lejos: no llega")
	_isak_at(4, 9)
	watch_signals(prompt)
	_fire_pulse()
	assert_true(prompt.is_on(), "Un pulso de espaldas lo usa")
	assert_signal_emitted_with_parameters(prompt, "switched_on", [&"deshacer_prueba", true])
	assert_true(_isak.is_facing_back(), "Isak de espaldas")
	assert_true(GameState.is_ability_obtained(SHAKE), "Obtiene Agitar para siempre")
	assert_true(GameState.is_ability_unlocked(SHAKE))
	assert_true(GameState.has_unsaved_changes(), "Queda «sin guardar», como toda habilidad")
	assert_eq(_texts(), [ECO_LINE, NOTICE], "Primero la frase de Eco y despues el aviso")
	assert_true(_lines[0].important and _lines[1].important, "Las dos importantes (pausan)")
	assert_true(GameState.is_notice_seen(SHAKE))
	assert_eq(prompt.get_animation(), UndoPrompt.ANIM_HIT)
	assert_false(prompt.is_room_tinted(), "No tine el nivel")
	prompt.advance(0.5)
	assert_false(_isak.is_facing_back(), "Vuelve de perfil tras pose_s")
	assert_eq(prompt.get_animation(), UndoPrompt.ANIM_ON)
	assert_false(prompt.is_help_available(), "Usado no ayuda")
	_lines.clear()
	assert_false(prompt.receive_pulse(_pulse), "Se usa una sola vez")
	assert_eq(_lines.size(), 0)
	notices.free()


func test_with_shockwave_already_obtained_it_starts_used_and_inert() -> void:
	GameState.obtain_ability(SHAKE)
	GameState.mark_notice_seen(SHAKE)
	_lines.clear()
	var prompt := _prompt()
	await wait_process_frames(1)
	assert_true(prompt.is_on(), "Arranca deshecho")
	assert_true(prompt.is_inert())
	assert_false(HelpCatalog.is_help_live(prompt), "Sin Q")
	_isak_at(4, 9)
	_fire_pulse()
	assert_false(_isak.is_facing_back(), "No responde")
	assert_eq(_lines.size(), 0, "Ni linea ni aviso")


# --- Guardado, game over y Papelera ---

func test_saved_and_reloaded() -> void:
	_prompt().switch_on()
	assert_true(GameState.save_game())
	assert_true(SaveFile.read(PATH).get("abilities_obtained", []).has("shockwave"))
	GameState.reset_progress()
	assert_false(GameState.is_ability_unlocked(SHAKE))
	assert_true(GameState.load_game())
	assert_true(GameState.is_ability_obtained(SHAKE), "Tras cargar sigue obtenido")
	var again := _prompt(Vector2i(8, 9))
	await wait_process_frames(1)
	assert_true(again.is_inert(), "Con la partida cargada no se repite")


func test_game_over_without_saving_loses_the_gesture_and_the_prompt_comes_back() -> void:
	assert_true(GameState.save_game(), "Copia sin el gesto")
	_prompt().switch_on()
	GameState.apply_rollback(GameState.ROLLBACK_GAME_OVER)
	assert_false(GameState.is_ability_obtained(SHAKE), "Lo no guardado se pierde")
	assert_false(GameState.get_trash().get(GameState.TRASH_ABILITIES, []).has("shockwave"), "No estaba guardado")
	var again := _prompt(Vector2i(8, 9))
	await wait_process_frames(1)
	assert_false(again.is_on(), "Tras el rollback sin el gesto, vuelve")
	_lines.clear()
	assert_true(again.switch_on())
	assert_true(GameState.is_ability_obtained(SHAKE), "Se obtiene otra vez")
	assert_eq(_texts(), [ECO_LINE], "Con la linea de Eco")


func test_saved_gesture_goes_to_the_trash_and_comes_back() -> void:
	_prompt().switch_on()
	assert_true(GameState.save_game())
	GameState.apply_rollback(GameState.ROLLBACK_GAME_OVER)
	assert_true(GameState.get_trash().get(GameState.TRASH_ABILITIES, []).has("shockwave"),
		"Eco lo desecha a la Papelera")
	assert_false(GameState.is_ability_unlocked(SHAKE), "Hasta recuperarlo no hay Agitar")
	assert_true(GameState.recover_trash())
	assert_true(GameState.is_ability_obtained(SHAKE), "Recuperado de la Papelera")
	var again := _prompt(Vector2i(8, 9))
	await wait_process_frames(1)
	assert_true(again.is_inert())


# --- La Papelera en el nivel ---

func test_papelera_speaks_when_isak_comes_close_then_whispers_after_the_gesture() -> void:
	var notices := _notices()
	_isak_at(20, 9)
	var papelera := _papelera()
	var prompt := _prompt()
	await wait_process_frames(1)
	assert_eq(papelera.get_state(), PapeleraActor.State.WAITING)
	assert_eq(papelera.get_animation(), &"active", "Se tambalea: tiene algo que decir")
	assert_eq(HelpCatalog.help_id_of(papelera), &"", "Es historia: sin Q")
	assert_false(HelpCatalog.is_help_live(papelera))
	papelera.advance(0.1)
	assert_eq(_lines.size(), 0, "Lejos: calla")
	_isak_at(4, 9)
	watch_signals(papelera)
	papelera.advance(0.1)
	assert_eq(papelera.get_state(), PapeleraActor.State.TOLD)
	assert_eq(_lines.size(), 2, "Las dos lineas de la presentacion")
	assert_true(_lines[0].important and _lines[1].important, "Importantes: pausan")
	assert_string_starts_with(String(_lines[0].text), "Aquí llega lo que él tira.")
	assert_string_starts_with(String(_lines[1].text), "Si quieres deshacer algo, agita.")
	assert_true(GameState.is_notice_seen(STORY_NOTICE), "Un solo uso (seen_notices)")
	papelera.advance(1.0)
	assert_eq(_lines.size(), 2, "No se repite")
	_lines.clear()
	_fire_pulse()
	assert_true(prompt.is_on())
	assert_eq(_texts(), [ECO_LINE, NOTICE, "Él no soporta el silencio. Acuérdate."],
		"Eco, el aviso y despues la Papelera en voz baja")
	assert_false(_lines[2].important, "La ultima no pausa")
	assert_eq(papelera.get_state(), PapeleraActor.State.DONE)
	papelera.advance(0.1)
	assert_eq(papelera.get_animation(), &"empty")
	notices.free()


func test_papelera_speaks_through_the_level_text_box_as_papelera() -> void:
	var box := (load("res://scenes/ui/eco_text_box.tscn") as PackedScene).instantiate() as EcoTextBox
	box.name = "EcoTextBox"
	_root.add_child(box)
	_isak_at(4, 9)
	var papelera := _papelera()
	await wait_process_frames(1)
	papelera.advance(0.1)
	assert_eq(papelera.get_state(), PapeleraActor.State.TOLD)
	assert_eq(_lines.size(), 0, "No va por Eco (EventBus)")
	assert_eq(box.get_speaker_id(), &"papelera", "Habla la Papelera en el cuadro del nivel")
	assert_eq(box.get_speaker_text(), "Papelera")


func test_papelera_is_silent_when_already_told_or_with_the_gesture() -> void:
	GameState.mark_notice_seen(STORY_NOTICE)
	_isak_at(4, 9)
	var told := _papelera()
	await wait_process_frames(1)
	told.advance(0.1)
	assert_eq(told.get_state(), PapeleraActor.State.DONE, "Aviso visto: calla")
	assert_eq(told.get_animation(), &"empty")
	told.free()
	GameState.reset_progress()
	GameState.obtain_ability(SHAKE)
	_lines.clear()
	var owned := _papelera()
	await wait_process_frames(1)
	owned.advance(0.1)
	assert_eq(owned.get_state(), PapeleraActor.State.DONE, "Con Agitar ya obtenido: calla")
	assert_eq(_lines.size(), 0)


# --- Muro de texto ---

func test_typed_wall_only_falls_to_shockwave_and_for_good() -> void:
	var wall := _wall()
	await wait_process_frames(1)
	assert_true(wall.is_solid())
	assert_eq(wall.get_wall_rect(), Rect2(640, 448, 64, 192), "1 x 3 desde su celda de arriba")
	assert_eq(wall.get_lines(), ["y entonces", "le dije", "que…"] as Array[String], "Las lineas por defecto")
	watch_signals(wall)
	# Pulso y laser rebotan.
	_isak_at(9, 9)
	_fire_pulse()
	assert_signal_emitted(wall, "deflected", "El pulso rebota")
	wall.on_laser_hit(10.0, _isak)
	assert_signal_emit_count(wall, "deflected", 2, "El laser rebota")
	assert_true(wall.is_solid())
	# Agitar lejos (a mas de 2,5 tiles) no lo toca.
	var center := Vector2(640.0 - 170.0, 600.0)
	assert_false(wall.receive_shockwave(center, 160.0), "Fuera del radio")
	EventBus.shockwave_fired.emit(center, 160.0, _isak)
	assert_false(wall.is_erasing())
	# A 2,5 tiles o menos lo deshace: se borra de atras adelante en 0,4 s.
	EventBus.shockwave_fired.emit(Vector2(640.0 - 150.0, 600.0), 160.0, _isak)
	assert_true(wall.is_erasing(), "Agitar lo alcanza")
	assert_signal_emitted(wall, "erased")
	assert_true(wall.is_solid(), "Mientras se borra sigue siendo pared")
	assert_false(wall.is_help_available())
	wall.advance(0.2)
	assert_almost_eq(wall.get_text_left(), 0.5, 0.01, "A mitad del borrado")
	assert_true(wall.is_solid())
	wall.advance(0.21)
	assert_true(wall.is_cleared(), "A los 0,4 s ya no queda texto")
	assert_false(wall.is_solid())
	assert_signal_emitted(wall, "cleared")
	await wait_physics_frames(1)
	assert_eq(wall.collision_layer, 0, "Sin colision")
	EventBus.player_respawned.emit(Vector2.ZERO, true)
	assert_true(wall.is_cleared(), "No vuelve al reaparecer")


# --- Sala de prueba ---

func _walk(sim: IsakSim, axis: float, seconds: float) -> void:
	sim.input.move_axis = axis
	sim.step(sim.steps_for(seconds))
	sim.input.move_axis = 0.0


func test_borrados_test_room_with_the_real_isak() -> void:
	_root.free()
	var room := (load(ROOM_SCENE) as PackedScene).instantiate()
	var sim := IsakSim.new(DT)
	sim.attach(room.get_node(^"Isak") as Isak)
	add_child_autofree(room)
	sim.take_manual_control()
	await wait_physics_frames(1)
	GameState.debug_energy = GameState.get_debug_energy_max()
	var prompt := room.get_node(^"Objects/deshacer_prueba") as UndoPrompt
	var wall := room.get_node(^"Objects/muro_prueba") as TypedWall
	var papelera := room.get_node(^"Objects/papelera_prueba") as PapeleraActor
	assert_not_null(prompt, "El panel de la sala")
	assert_not_null(wall, "El muro de la sala")
	assert_not_null(papelera, "La Papelera de la sala")
	assert_false(GameState.is_ability_unlocked(SHAKE), "La sala empieza sin Agitar")
	# Sin el gesto, el muro no se cruza.
	sim.isak.global_position = Vector2(18.5 * TILE, 10 * TILE)
	sim.settle()
	_walk(sim, 1.0, 2.0)
	assert_lt(sim.isak.global_position.x, 22.0 * TILE, "El muro de texto corta el paso")
	sim.input.shake_pressed = true
	sim.step()
	sim.step(sim.steps_for(0.5))
	assert_true(wall.is_solid(), "Sin la habilidad no hay Agitar")
	# La Papelera habla al acercarse.
	sim.isak.global_position = Vector2(5.5 * TILE, 10 * TILE)
	sim.settle()
	papelera.advance(0.1)
	assert_eq(papelera.get_state(), PapeleraActor.State.TOLD, "Junto a la Papelera, su presentacion")
	# Pulso de espaldas al panel.
	sim.isak.global_position = Vector2(12.5 * TILE, 10 * TILE)
	sim.settle()
	sim.input.pulse_pressed = true
	sim.step()
	assert_true(prompt.is_on(), "El pulso de espaldas lo usa")
	assert_true(GameState.is_ability_obtained(SHAKE))
	assert_eq(papelera.get_state(), PapeleraActor.State.DONE, "La Papelera ya dijo todo")
	prompt.advance(0.5)
	sim.step_until(func() -> bool: return sim.state() == PlayerState.IDLE and not sim.isak.is_facing_back(),
		sim.steps_for(1.5))
	# Agitar junto al muro lo deshace y se pasa.
	sim.isak.global_position = Vector2(20.5 * TILE, 10 * TILE)
	sim.settle()
	sim.input.shake_pressed = true
	sim.step()
	sim.step(sim.steps_for(0.8))
	assert_true(wall.is_erasing(), "Agitar a menos de 2,5 tiles lo alcanza")
	wall.advance(0.5)
	assert_true(wall.is_cleared(), "Y lo deshace")
	await wait_physics_frames(1)
	_walk(sim, 1.0, 3.0)
	assert_gt(sim.isak.global_position.x, 24.0 * TILE, "Ya se pasa")
