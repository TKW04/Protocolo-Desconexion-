# Ayuda de Eco con Q por tipo (docs/propuesta-asistentes-y-vidas.md §3, paso 3
# de §10; HelpSystem, HelpPrompt, HelpCatalog y data/help.json): la Q sale solo
# con Eco conocido, cerca de un tipo no aprendido y en pantalla (una a la vez, la
# del mas cercano); pulsar help pausa el juego, Eco explica el tipo en su cuadro
# (linea importante) y el tipo queda aprendido (ninguna otra instancia vuelve a
# mostrar la Q); la pausa se libera al cerrar la linea y siempre al quitar el
# nivel; sin Q, help no hace nada; muerto no hay Q. Datos: cada help_id de los
# datos existe en data/help.json y viceversa, y ningun texto dice vuelta ni
# Easy/Normal/Hard. El 1-1 generado apunta sus objetos a la ayuda.
extends GutTest

const ISAK_SCENE: PackedScene = preload("res://scenes/player/isak.tscn")
const ECO_SCENE: PackedScene = preload("res://scenes/ui/eco_text_box.tscn")
const LEVEL_SCENE: PackedScene = preload("res://scenes/levels/1-1.tscn")
const TILE: float = 64.0
const ISAK_FEET: Vector2 = Vector2(640.0, 400.0)

var _root: Node2D
var _isak: Isak
var _box: EcoTextBox
var _help: HelpSystem
var _shown: Array[StringName] = []
var _saved_pause_important: bool
var _saved_level: StringName


func before_each() -> void:
	_saved_pause_important = EcoTextBox.pause_important
	_saved_level = GameState.current_level
	EcoTextBox.pause_important = true
	GameState.reset_progress()
	_shown.clear()
	_root = Node2D.new()
	_root.name = "HelpTestLevel"
	_isak = ISAK_SCENE.instantiate() as Isak
	_isak.name = "Isak"
	_isak.position = ISAK_FEET
	_root.add_child(_isak)
	_box = ECO_SCENE.instantiate() as EcoTextBox
	_box.name = "EcoTextBox"
	_root.add_child(_box)
	_help = HelpSystem.new()
	_help.name = "Help"
	_root.add_child(_help)
	_help.help_shown.connect(func(id: StringName, _text: String) -> void: _shown.append(id))
	add_child(_root)
	await wait_process_frames(2)


func after_each() -> void:
	if is_instance_valid(_root):
		_root.free()
	get_tree().paused = false
	EcoTextBox.pause_important = _saved_pause_important
	GameState.reset_progress()
	GameState.current_level = _saved_level


## Objeto de prueba del tipo `help_id` con su centro a `offset` px del centro
## de Isak (descuenta el center_px del tipo).
func _target(help_id: StringName, offset: Vector2) -> Node2D:
	var node := Node2D.new()
	node.name = "Target_%s_%d" % [help_id, _root.get_child_count()]
	var center: Vector2 = ISAK_FEET + Vector2(0.0, HelpCatalog.shared().isak_center_y()) + offset
	node.position = center - HelpCatalog.shared().center_offset(help_id)
	HelpCatalog.tag(node, help_id)
	_root.add_child(node)
	return node


func _press_help() -> void:
	var event := InputEventAction.new()
	event.action = &"help"
	event.pressed = true
	get_viewport().push_input(event)
	var release := InputEventAction.new()
	release.action = &"help"
	release.pressed = false
	get_viewport().push_input(release)


func _press_jump() -> void:
	var event := InputEventAction.new()
	event.action = &"jump"
	event.pressed = true
	get_viewport().push_input(event)


# --- Q ---

func test_prompt_uses_help_key_from_input_map() -> void:
	assert_eq(_help.get_prompt().get_key_text(), "Q", "La tecla sale del Input Map")
	assert_eq(PulsePrompt.key_text(&"help"), "Q")


func test_no_prompt_before_meeting_eco() -> void:
	_target(&"receiver", Vector2(TILE, 0.0))
	_help.refresh()
	assert_false(_help.is_prompt_visible(), "Antes de conocer a Eco no hay Q")
	GameState.meet_ally(GameState.ALLY_ECO)
	_help.refresh()
	assert_true(_help.is_prompt_visible(), "Con Eco conocido, si")


func test_prompt_only_near_unlearned_type() -> void:
	GameState.meet_ally(GameState.ALLY_ECO)
	_help.refresh()
	assert_false(_help.is_prompt_visible(), "Sin objetos cerca no hay Q")
	var far: Node2D = _target(&"receiver", Vector2(TILE * 3.0, 0.0))
	_help.refresh()
	assert_false(_help.is_prompt_visible(), "A 3 tiles (radio 2,5) no hay Q")
	far.position.x -= TILE * 1.0
	_help.refresh()
	assert_eq(_help.get_target(), far, "A 2 tiles, si")
	var prompt_at: Vector2 = far.global_position + HelpCatalog.shared().prompt_offset(&"receiver")
	assert_eq(_help.get_prompt().global_position, prompt_at.round(), "La Q sobre el objeto")
	GameState.learn_help(&"receiver")
	_help.refresh()
	assert_false(_help.is_prompt_visible(), "Tipo aprendido: sin Q")


func test_untagged_or_unknown_types_have_no_prompt() -> void:
	GameState.meet_ally(GameState.ALLY_ECO)
	var plain := Node2D.new()
	plain.position = ISAK_FEET
	_root.add_child(plain)
	_target(&"no_existe", Vector2(TILE * 0.5, 0.0))
	_help.refresh()
	assert_false(_help.is_prompt_visible())


func test_only_one_prompt_on_the_nearest() -> void:
	GameState.meet_ally(GameState.ALLY_ECO)
	_target(&"charger", Vector2(TILE * 2.0, 0.0))
	var near: Node2D = _target(&"receiver", Vector2(-TILE * 1.0, 0.0))
	_help.refresh()
	assert_eq(_help.get_target(), near, "La del mas cercano")
	var prompts: int = 0
	for child: Node in _all_children(_help):
		if child is HelpPrompt and (child as HelpPrompt).visible:
			prompts += 1
	assert_eq(prompts, 1, "Una sola Q visible (la apagada de relectura no sale con candidato sin aprender)")


func test_enemies_use_a_wider_radius() -> void:
	GameState.meet_ally(GameState.ALLY_ECO)
	var bubble: Node2D = _target(&"alert_bubble", Vector2(TILE * 3.5, 0.0))
	_help.refresh()
	assert_eq(_help.get_target(), bubble, "Enemigo a 3,5 tiles (radio 4)")
	bubble.position.x += TILE
	_help.refresh()
	assert_false(_help.is_prompt_visible(), "A 4,5 tiles ya no")


func test_offscreen_targets_have_no_prompt() -> void:
	GameState.meet_ally(GameState.ALLY_ECO)
	var bubble: Node2D = _target(&"alert_bubble", Vector2(0.0, TILE * 3.5))
	_help.refresh()
	assert_true(_help.is_prompt_visible())
	var cam: Camera2D = _isak.get_node(^"Camera2D") as Camera2D
	cam.enabled = false
	var plain_cam := Camera2D.new()
	plain_cam.position = ISAK_FEET + Vector2(0.0, -TILE * 20.0)
	_root.add_child(plain_cam)
	plain_cam.make_current()
	await wait_process_frames(2)
	_help.refresh()
	assert_false(_help.is_prompt_visible(), "Fuera de pantalla: sin Q (%s)" % bubble.global_position)


func test_dead_or_warping_isak_has_no_prompt() -> void:
	GameState.meet_ally(GameState.ALLY_ECO)
	_target(&"receiver", Vector2(TILE, 0.0))
	_help.refresh()
	assert_true(_help.is_prompt_visible())
	_isak.die()
	_help.refresh()
	assert_false(_help.is_prompt_visible(), "Muerto no hay Q")
	_press_help()
	await wait_process_frames(1)
	assert_false(get_tree().paused, "Ni pausa")
	assert_true(GameState.learned_help.is_empty())


# --- Pedir ayuda ---

func test_help_without_prompt_does_nothing() -> void:
	GameState.meet_ally(GameState.ALLY_ECO)
	_press_help()
	await wait_process_frames(2)
	assert_false(get_tree().paused)
	assert_false(_box.is_showing())
	assert_eq(_shown.size(), 0)


func test_pressing_help_pauses_explains_and_learns_the_type() -> void:
	GameState.meet_ally(GameState.ALLY_ECO)
	var first: Node2D = _target(&"receiver", Vector2(TILE, 0.0))
	_target(&"receiver", Vector2(-TILE * 1.5, 0.0))
	var other: Node2D = _target(&"charger", Vector2(0.0, TILE * 2.0))
	_help.refresh()
	assert_eq(_help.get_target(), first)
	_press_help()
	await wait_process_frames(1)
	assert_eq(_shown, [&"receiver"] as Array[StringName])
	assert_true(get_tree().paused, "Pedir ayuda pausa el juego")
	assert_true(_box.is_important(), "Linea importante del cuadro de Eco")
	assert_eq(_box.get_speaker_text(), "Eco")
	assert_eq(_box.get_text(), HelpCatalog.shared().text(&"receiver"), "El texto del tipo")
	assert_true(GameState.is_help_learned(&"receiver"), "Queda aprendido")
	assert_false(GameState.has_unsaved_changes(), "Aprender no marca «sin guardar»")
	assert_false(_help.is_prompt_visible(), "La Q se va (ni sobre otro tipo durante la pausa)")
	_help.refresh()
	assert_false(_help.is_prompt_visible(), "Con el juego en pausa no hay Q")
	# El juego sigue en pausa hasta cerrar: primera pulsacion completa, la segunda cierra.
	_press_jump()
	await wait_process_frames(1)
	assert_true(get_tree().paused, "La primera pulsacion solo completa el texto")
	assert_eq(_box.get_typed_count(), _box.get_text().length())
	_press_jump()
	await wait_process_frames(1)
	_box.advance(1.0)
	assert_false(get_tree().paused, "Cerrada la linea, el juego sigue")
	assert_false(_box.is_showing())
	_help.refresh()
	assert_eq(_help.get_target(), other, "Ningun otro receptor muestra la Q; el cargador, si")


func test_learning_one_type_keeps_prompts_of_other_types() -> void:
	GameState.meet_ally(GameState.ALLY_ECO)
	_target(&"receiver", Vector2(TILE, 0.0))
	var other: Node2D = _target(&"charger", Vector2(-TILE * 2.0, 0.0))
	_help.refresh()
	assert_true(_help.request_help())
	_box.confirm()
	_box.confirm()
	_box.advance(1.0)
	assert_false(get_tree().paused)
	_help.refresh()
	assert_eq(_help.get_target(), other, "Otro tipo sigue con su Q")


func test_help_pause_is_released_when_the_level_goes_away() -> void:
	GameState.meet_ally(GameState.ALLY_ECO)
	_target(&"glitch_wall", Vector2(TILE, 0.0))
	_help.refresh()
	assert_true(_help.request_help())
	assert_true(get_tree().paused)
	_root.free()
	assert_false(get_tree().paused, "Quitar el nivel (cambio de escena, reinicio) libera la pausa")


func test_help_is_ignored_while_paused() -> void:
	GameState.meet_ally(GameState.ALLY_ECO)
	_target(&"receiver", Vector2(TILE, 0.0))
	_target(&"charger", Vector2(-TILE, 0.0))
	_help.refresh()
	assert_true(_help.request_help())
	_help.refresh()
	assert_false(_help.request_help(), "Con el juego en pausa no se encadena otra ayuda")
	assert_eq(_shown.size(), 1)


func test_an_eco_line_alone_does_not_meet_eco() -> void:
	# Se retiro la regla provisional (paso 6): Eco solo se conoce en el encuentro del 1-1.
	assert_false(GameState.has_met_ally(GameState.ALLY_ECO))
	EventBus.eco_line_requested.emit("Bienvenido. He optimizado tu espacio.", 1.0, false)
	await wait_process_frames(1)
	assert_false(GameState.has_met_ally(GameState.ALLY_ECO), "Hablar no basta: hace falta el encuentro")
	_target(&"receiver", Vector2(TILE, 0.0))
	_help.refresh()
	assert_null(_help.get_target(), "Sin Eco conocido no hay Q")


func test_drops_are_tagged_with_their_help_type() -> void:
	var drops: Array[RechargePickup] = RechargePickup.spawn_drops(_root, ISAK_FEET,
		{"debug_energy": 25.0, "sync_rate": 10.0})
	assert_eq(drops.size(), 2)
	assert_eq(HelpCatalog.help_id_of(drops[0]), &"energy_drop")
	assert_eq(HelpCatalog.help_id_of(drops[1]), &"sync_drop")
	assert_true(drops[0].is_in_group(HelpCatalog.TARGET_GROUP))


# --- Datos ---

func _data_help_ids() -> Dictionary:
	var used: Dictionary = {}
	var world: Dictionary = World1ObjectsConfig.data()
	for type: String in world["types"]:
		var id: Variant = (world["types"][type] as Dictionary).get("help_id")
		if id is String and not (id as String).is_empty():
			used[id] = "world1_objects.types.%s" % type
	for section: String in ["attention_point", "checkpoint"]:
		used[String(world[section]["help_id"])] = "world1_objects.%s" % section
	# Mundo 2 (2026-10-22): tipos de data/world2_objects.json.
	var world2: Dictionary = World2ObjectsConfig.data()
	for type: String in world2.get("types", {}):
		var id2: Variant = (world2["types"][type] as Dictionary).get("help_id")
		if id2 is String and not (id2 as String).is_empty():
			used[id2] = "world2_objects.types.%s" % type
	# Mundo 3 (2026-10-26, paso 9 de docs/propuesta-mundo-3.md): tipos de data/world3_objects.json.
	var world3: Dictionary = World3ObjectsConfig.data()
	for type: String in world3.get("types", {}):
		var id3: Variant = (world3["types"][type] as Dictionary).get("help_id")
		if id3 is String and not (id3 as String).is_empty():
			used[id3] = "world3_objects.types.%s" % type
	# Mundo 4 (2026-10-28, paso 10 de docs/propuesta-mundo-4.md): tipos de data/world4_objects.json.
	var world4: Dictionary = World4ObjectsConfig.data()
	for type: String in world4.get("types", {}):
		var id4: Variant = (world4["types"][type] as Dictionary).get("help_id")
		if id4 is String and not (id4 as String).is_empty():
			used[id4] = "world4_objects.types.%s" % type
	# Chip de una habilidad con ayuda propia (2026-10-16: debug_chip).
	var by_ability: Dictionary = (world["ability_pickup"] as Dictionary).get("by_ability", {})
	for ability: String in by_ability:
		var own_id: Variant = (by_ability[ability] as Dictionary).get("help_id")
		if own_id is String and not (own_id as String).is_empty():
			used[own_id] = "world1_objects.ability_pickup.by_ability.%s" % ability
	for file: String in DirAccess.get_files_at("res://data/enemies"):
		if file.ends_with(".json"):
			var enemy: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/enemies/" + file))
			if enemy.has("help_id"):
				used[String(enemy["help_id"])] = "enemies/" + file
	# Jefes (2026-10-21): seccion help de data/bosses/<id>.json (piezas -> help_id).
	for file: String in DirAccess.get_files_at("res://data/bosses"):
		if file.ends_with(".json"):
			var boss: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/bosses/" + file))
			var help: Dictionary = boss.get("help", {})
			for key: String in help:
				used[String(help[key])] = "bosses/%s help.%s" % [file, key]
	var recharge: Dictionary = RechargePickup.data()
	for kind: String in recharge["kinds"]:
		used[String(recharge["kinds"][kind]["help_id"])] = "recharge_pickup.kinds.%s" % kind
	for file: String in DirAccess.get_files_at("res://data/levels"):
		if not file.ends_with(".json"):
			continue
		var level: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/levels/" + file))
		for list: String in ["objects", "enemies", "checkpoints"]:
			for item: Dictionary in level.get(list, []):
				var own: Variant = item.get("help_id", "")
				if own is String and not (own as String).is_empty():
					used[own] = "levels/%s %s" % [file, list]
	return used


func test_every_help_id_in_data_exists_in_help_json() -> void:
	var catalog := HelpCatalog.shared()
	var used: Dictionary = _data_help_ids()
	assert_gt(used.size(), 0)
	for id: String in used:
		assert_true(catalog.has(StringName(id)), "%s (%s) esta en data/help.json" % [id, used[id]])


func test_help_json_has_no_orphan_types() -> void:
	var used: Dictionary = _data_help_ids()
	for id: StringName in HelpCatalog.shared().ids():
		assert_true(used.has(String(id)), "El tipo %s lo usa algun objeto de los datos" % id)


func test_help_entries_are_complete() -> void:
	var catalog := HelpCatalog.shared()
	var required: Array[StringName] = [&"alert_bubble", &"popup_blocker", &"receiver", &"bridge", &"charger",
		&"power_bank_pickup", &"attention_point", &"energy_drop", &"sync_drop", &"sync_point",
		&"exit_terminal", &"glitch_wall", &"ability_pickup"]
	for id: StringName in required:
		assert_true(catalog.has(id), "Tipo del 1-1: %s" % id)
	for id: StringName in catalog.ids():
		assert_false(catalog.title(id).is_empty(), "%s tiene titulo" % id)
		assert_false(catalog.text(id).is_empty(), "%s tiene texto" % id)
		assert_has([HelpCatalog.CATEGORY_ENEMY, HelpCatalog.CATEGORY_OBJECT], catalog.category(id))
	assert_eq(catalog.text(&"glitch_wall"), "Eso es un error de visualización. Ignóralo, por favor.")
	assert_eq(catalog.category(&"alert_bubble"), HelpCatalog.CATEGORY_ENEMY)


func test_help_texts_never_name_laps_or_difficulties() -> void:
	var regex := RegEx.create_from_string("(?i)\\b(vuelta|vueltas|easy|normal|hard)\\b")
	var catalog := HelpCatalog.shared()
	for id: StringName in catalog.ids():
		for text: String in [catalog.title(id), catalog.text(id)]:
			assert_null(regex.search(text), "%s: «%s»" % [id, text])


func test_types_of_1_1_match_its_objects() -> void:
	var level: Node = LEVEL_SCENE.instantiate()
	var in_level: Dictionary = {}
	for node: Node in _all_children(level):
		var id: StringName = HelpCatalog.help_id_of(node)
		if id != &"":
			in_level[id] = true
	# Las Burbujas sueltan energia y Sync Rate al morir.
	in_level[&"energy_drop"] = true
	in_level[&"sync_drop"] = true
	level.free()
	var of_level: Array[StringName] = HelpCatalog.shared().types_of_level(&"1-1")
	assert_eq(of_level.size(), in_level.size(), "first_level 1-1 = tipos presentes en el 1-1")
	for id: StringName in of_level:
		assert_true(in_level.has(id), "%s esta en el 1-1" % id)


func test_generated_1_1_tags_objects_and_has_help_system() -> void:
	var level: Node = LEVEL_SCENE.instantiate()
	assert_true(level.get_node_or_null(^"Help") is HelpSystem, "El nivel generado trae la ayuda")
	var expect: Dictionary = {
		^"Objects/receiver_56_9": &"receiver",
		^"Objects/puente_1": &"bridge",
		^"Objects/popup_1": &"popup_blocker",
		^"Objects/cargador_1": &"charger",
		^"Objects/power_bank_pulso_amplio": &"power_bank_pickup",
		^"Objects/laser_1_1": &"ability_pickup",
		^"Objects/terminal_salida": &"exit_terminal",
		^"Objects/glitch_wall_298_8": &"glitch_wall",
		^"AttentionPoints/Point_8_9": &"attention_point",
		^"Checkpoints/sync_1": &"sync_point",
		^"Enemies/burbuja_t1a": &"alert_bubble",
	}
	for path: NodePath in expect:
		var node: Node = level.get_node_or_null(path)
		assert_not_null(node, String(path))
		if node != null:
			assert_eq(HelpCatalog.help_id_of(node), expect[path], String(path))
			assert_true(node.is_in_group(HelpCatalog.TARGET_GROUP), String(path))
	assert_eq(HelpCatalog.help_id_of(level.get_node(^"Objects/eco_laser")), &"", "Las lineas de Eco no")
	assert_eq(HelpCatalog.help_id_of(level.get_node(^"Objects/eco_encuentro")), &"", "El encuentro con Eco no")
	level.free()


func test_generated_1_1_shows_q_near_a_receiver() -> void:
	_root.free()
	# Las lineas importantes de Eco pausarian el arbol: aqui no interesan.
	EcoTextBox.pause_important = false
	var level: Node2D = LEVEL_SCENE.instantiate() as Node2D
	add_child(level)
	await wait_process_frames(2)
	GameState.meet_ally(GameState.ALLY_ECO)
	GameState.learn_help(&"alert_bubble")  # La Burbuja del 2a patrulla cerca.
	var isak := level.get_node(^"Isak") as Isak
	var receiver := level.get_node(^"Objects/receiver_56_9") as Node2D
	isak.global_position = receiver.global_position + Vector2(-TILE * 1.5, TILE)
	var cam := isak.get_node(^"Camera2D") as Camera2D
	await wait_process_frames(1)
	cam.reset_smoothing()
	cam.force_update_scroll()
	await wait_process_frames(2)
	var help := level.get_node(^"Help") as HelpSystem
	help.refresh()
	assert_eq(help.get_target(), receiver, "Q sobre el receptor del 2a")
	GameState.learn_help(&"receiver")
	help.refresh()
	assert_ne(help.get_target(), receiver)
	level.free()


static func _all_children(node: Node) -> Array[Node]:
	var out: Array[Node] = []
	for child: Node in node.get_children():
		out.append(child)
		out.append_array(_all_children(child))
	return out
