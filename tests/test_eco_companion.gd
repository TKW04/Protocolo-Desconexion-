# Eco como companero visible (EcoCompanion, data/eco_companion.json;
# docs/propuesta-asistentes-y-vidas.md §2.1, paso 4 de §10): sin Eco conocido no
# aparece; conocido, aparece y sigue a Isak a distancia acotada (y se recoloca si
# se aleja); entra con el vortice de llegada (despues de que Isak se vea) y se va
# con el de salida (despues de que Isak sea absorbido); si Eco pasa a conocido a
# mitad de nivel aparece entonces; se dibuja detras de los enemigos y de Isak
# (tambien de espaldas) y en el lienzo del mundo, por debajo de la Q; reacciona
# al hablar y al salir una Q; mira hacia donde mira Isak; sin colision. En el
# hub, variante atenuada (no es una estacion). En el 1-1 de la escena principal
# lo crea LevelRunner.
extends GutTest

const EcoProgress = preload("res://tests/support/eco_progress.gd")

const ISAK_SCENE: PackedScene = preload("res://scenes/player/isak.tscn")
const HUB_SCENE: PackedScene = preload("res://scenes/hub/hub.tscn")
const MAIN_SCENE: PackedScene = preload("res://scenes/main.tscn")
const FEET: Vector2 = Vector2(640.0, 400.0)
const STEP: float = 1.0 / 60.0
const LONG_STEP_S: float = 5.0
const HUB_PATH: String = "user://test_eco_companion_hub.json"

var _root: Node2D
var _isak: Isak
var _eco: EcoCompanion
var _data: Dictionary = EcoCompanion.load_data()


func before_each() -> void:
	GameState.reset_progress()
	_root = Node2D.new()
	_root.name = "EcoTestLevel"
	add_child(_root)
	var enemies := Node2D.new()
	enemies.name = "Enemies"
	_root.add_child(enemies)
	_isak = ISAK_SCENE.instantiate() as Isak
	_isak.name = "Isak"
	_isak.position = FEET
	_root.add_child(_isak)


func after_each() -> void:
	if is_instance_valid(_root):
		_root.free()
	get_tree().paused = false
	GameState.reset_progress()


func _attach(dim: bool = false) -> EcoCompanion:
	_eco = EcoCompanion.attach(_isak, _root, dim)
	_eco.auto_advance = false
	return _eco


func _run(seconds: float) -> void:
	var t: float = 0.0
	while t < seconds:
		_eco.advance(STEP)
		t += STEP


func _shown_eco() -> EcoCompanion:
	GameState.meet_ally(GameState.ALLY_ECO)
	_attach()
	_run(1.0)
	return _eco


func test_not_shown_while_eco_is_unknown() -> void:
	_attach()
	_run(2.0)
	assert_false(_eco.is_shown(), "Sin Eco conocido no hay companero")
	assert_false(_eco.visible)


func test_appears_and_follows_when_known() -> void:
	_shown_eco()
	assert_eq(_eco.get_state(), EcoCompanion.State.FOLLOW)
	assert_true(_eco.visible)
	var offset: Array = _data["offset_px"]
	# Detras de Isak (mira a la derecha) y encima de sus pies.
	assert_lt(_eco.get_anchor().x, FEET.x, "Detras de Isak")
	assert_almost_eq(_eco.get_anchor().y, FEET.y - float(offset[1]), 2.0, "A la altura del hombro")


func test_follow_distance_stays_bounded_while_isak_runs() -> void:
	_shown_eco()
	var worst: float = 0.0
	for i: int in 240:
		_isak.global_position.x += 360.0 * STEP  # Correr
		_eco.advance(STEP)
		worst = maxf(worst, _eco.get_anchor().distance_to(_isak.global_position))
	var bound: float = Vector2(_data["offset_px"][0], _data["offset_px"][1]).length() + 128.0
	assert_lt(worst, bound, "Nunca se queda muy atras (%.0f px)" % worst)
	assert_eq(_eco.get_state(), EcoCompanion.State.FOLLOW)


func test_far_jump_relocates_with_a_flash() -> void:
	_shown_eco()
	_isak.global_position += Vector2(2000.0, 0.0)
	_eco.advance(STEP)
	assert_eq(_eco.get_state(), EcoCompanion.State.APPEARING, "Destello al recolocarse")
	assert_lt(_eco.get_anchor().distance_to(_eco.get_target_position()), 1.0)


func test_faces_isak_direction_and_crosses_over_him() -> void:
	_shown_eco()
	assert_false(_eco.get_sprite().flip_h)
	_isak.facing = -1.0
	var top: float = INF
	for i: int in 60:
		_eco.advance(STEP)
		top = minf(top, _eco.get_anchor().y)
	assert_true(_eco.get_sprite().flip_h, "Mira a la izquierda con Isak")
	assert_gt(_eco.get_anchor().x, FEET.x, "Ahora va por el otro lado")
	assert_lt(top, FEET.y - float(_data["offset_px"][1]) - 4.0, "Cruza por encima de Isak")


func test_appears_after_isak_with_the_arrival_vortex() -> void:
	GameState.meet_ally(GameState.ALLY_ECO)
	_attach()
	var vortex: WarpVortex = WarpVortex.arrive(_isak, _root, true)
	vortex.set_process(false)
	_run(1.0)
	assert_false(_eco.is_shown(), "Isak aun no se ve: Eco tampoco")
	vortex.release()
	var revealed_at: float = -1.0
	var shown_at: float = -1.0
	var t: float = 0.0
	while t < 4.0 and shown_at < 0.0:
		if is_instance_valid(vortex):
			vortex.advance(STEP)
		_eco.advance(STEP)
		t += STEP
		if revealed_at < 0.0 and not _isak.is_warp_hidden():
			revealed_at = t
		if _eco.is_shown():
			shown_at = t
	assert_gt(revealed_at, 0.0, "Isak se ve")
	assert_almost_eq(shown_at - revealed_at, float(_data["appear_delay_s"]), 0.05,
		"Eco aparece appear_delay_s despues de Isak")
	assert_eq(_eco.get_animation(), EcoCompanion.ANIM_APPEAR)


func test_leaves_after_isak_with_the_departure_vortex() -> void:
	_shown_eco()
	_isak.face_back()
	var vortex: WarpVortex = WarpVortex.depart(_isak, _root)
	vortex.set_process(false)
	_eco.advance(STEP)
	assert_eq(_eco.get_state(), EcoCompanion.State.DEPARTING)
	var t: float = 0.0
	var gone_isak_at: float = -1.0
	var hidden_at: float = -1.0
	while t < 5.0 and hidden_at < 0.0:
		if is_instance_valid(vortex):
			vortex.advance(STEP)
		_eco.advance(STEP)
		t += STEP
		if gone_isak_at < 0.0 and _isak.modulate.a <= 0.0:
			gone_isak_at = t
		if not _eco.is_shown():
			hidden_at = t
	assert_gt(gone_isak_at, 0.0, "Isak absorbido")
	assert_gt(hidden_at, gone_isak_at - STEP, "Eco se va despues que Isak")
	_run(2.0)
	assert_false(_eco.is_shown(), "No vuelve hasta la siguiente llegada")


func test_appears_when_eco_becomes_known_mid_level() -> void:
	_attach()
	_run(0.5)
	assert_false(_eco.is_shown())
	GameState.meet_ally(GameState.ALLY_ECO)
	_eco.advance(STEP)
	assert_eq(_eco.get_state(), EcoCompanion.State.APPEARING, "Aparece con la animacion de aparecer")


func test_drawn_behind_enemies_and_isak_and_below_the_help_prompt() -> void:
	_shown_eco()
	var enemies: Node = _root.get_node(^"Enemies")
	assert_lt(_eco.get_index(), enemies.get_index(), "Detras de los enemigos")
	assert_lt(_eco.get_index(), _isak.get_index(), "Detras de Isak")
	assert_lte(_eco.z_index, _isak.z_index)
	_isak.face_back()
	_run(0.5)
	assert_lt(_eco.get_index(), _isak.get_index(), "Tambien con Isak de espaldas")
	var node: Node = _eco
	while node != null:
		assert_false(node is CanvasLayer, "En el lienzo del mundo (la Q va en la capa %d)" % HelpSystem.DEFAULT_LAYER)
		node = node.get_parent()
	for child: Node in _eco.get_children():
		assert_false(child is CollisionObject2D or child is CollisionShape2D, "Sin colision")


func test_reacts_when_eco_speaks_and_when_a_q_appears() -> void:
	_shown_eco()
	assert_eq(_eco.get_animation(), EcoCompanion.ANIM_IDLE)
	EventBus.eco_line_started.emit("Hola")
	_eco.advance(STEP)
	assert_eq(_eco.get_animation(), EcoCompanion.ANIM_NOTICE, "Destello al empezar a hablar")
	_run(1.0)
	assert_eq(_eco.get_animation(), EcoCompanion.ANIM_TALK, "Habla mientras dura la linea")
	EventBus.eco_line_finished.emit()
	_eco.advance(STEP)
	assert_eq(_eco.get_animation(), EcoCompanion.ANIM_IDLE)
	EventBus.help_prompt_shown.emit(_isak)
	_eco.advance(STEP)
	assert_eq(_eco.get_animation(), EcoCompanion.ANIM_NOTICE, "Reacciona a la Q")


func test_animates_with_the_game_paused() -> void:
	_shown_eco()
	assert_eq(_eco.process_mode, Node.PROCESS_MODE_ALWAYS, "Tiempo real: anima al hablar en pausa")


func test_hub_variant_is_dimmed_and_is_not_a_station() -> void:
	var saved_path: String = GameState.save_path
	GameState.use_save_path(HUB_PATH, true)
	EcoProgress.meet_notas()
	GameState.meet_ally(GameState.ALLY_ECO)
	var hub := HUB_SCENE.instantiate() as HubRoom
	add_child(hub)
	hub.get_arrival_vortex().advance(LONG_STEP_S)
	var eco: EcoCompanion = hub.get_eco_companion()
	assert_not_null(eco, "Eco entra en el hub")
	eco.auto_advance = false
	for i: int in 60:
		eco.advance(STEP)
	assert_true(eco.is_shown())
	assert_true(eco.is_dim(), "Atenuada: sin cobertura")
	assert_lt(eco.modulate.a, 1.0)
	assert_true(String(eco.get_sprite().animation).ends_with(EcoCompanion.DIM_SUFFIX), "Arte atenuado")
	assert_eq(hub.get_tree().get_nodes_in_group(HubStation.GROUP).count(eco), 0, "No es una estacion")
	assert_false(eco.is_in_group(QuitGuard.SAVE_STATION_GROUP), "No ofrece guardar")
	assert_lt(eco.get_index(), hub.get_isak().get_index(), "Detras de Isak")
	hub.free()
	SaveFile.delete(HUB_PATH)
	GameState.save_path = saved_path


func test_level_runner_adds_the_companion_to_the_level() -> void:
	var saved: bool = EcoTextBox.pause_important
	EcoTextBox.pause_important = false
	GameState.meet_ally(GameState.ALLY_ECO)
	var main := MAIN_SCENE.instantiate() as LevelRunner
	main.auto_advance = false
	main.start_level_id = "1-1"
	add_child(main)
	var eco: EcoCompanion = main.get_eco_companion()
	assert_not_null(eco)
	assert_true(main.get_level().is_ancestor_of(eco))
	assert_false(eco.is_dim())
	var enemies: Node = main.get_level().get_node(^"Enemies")
	assert_lt(eco.get_index(), enemies.get_index(), "Detras de los enemigos del nivel")
	assert_false(eco.is_shown(), "Isak aun no ha llegado")
	main.free()
	EcoTextBox.pause_important = saved


# --- Marco dorado del Mundo 3 (paso 9 de docs/propuesta-mundo-3.md §6.3) ---

func _eco_in_level(scene_path: String) -> EcoCompanion:
	var level := (load(scene_path) as PackedScene).instantiate() as GeneratedLevel
	_root.add_child(level)
	GameState.meet_ally(GameState.ALLY_ECO)
	_eco = EcoCompanion.attach(_isak, level)
	_eco.auto_advance = false
	_run(1.0)
	return _eco


func test_world_3_eco_wears_a_gold_frame_only_with_the_whole_sphere() -> void:
	var eco := _eco_in_level("res://scenes/levels/likes_test.tscn")
	var frame: Sprite2D = eco.get_world_frame()
	assert_not_null(frame, "En el Mundo 3 Eco lleva su marco")
	assert_eq(frame.texture.resource_path, String((_data["world_frames"] as Dictionary)["3"]))
	assert_eq(frame.scale, (eco.get_node(^"Sprite") as Node2D).scale, "A la escala de la esfera")
	assert_true(frame.visible, "Siguiendo a Isak (idle) se ve")
	assert_true(String(eco.get_shown_animation()).begins_with("idle"))


func test_other_worlds_and_hub_have_no_frame() -> void:
	assert_null(_eco_in_level("res://scenes/levels/correo_test.tscn").get_world_frame(), "Mundo 1: sin marco")
	assert_null(_attach(true).get_world_frame(), "Hub: sin marco")


# --- Eco igual en todos los mundos (decision del usuario 2026-10-29; docs/04-personajes.md §12.1) ---

func test_eco_is_the_same_sphere_in_every_world() -> void:
	var sphere: String = String(_data["frames"])
	for scene_path: String in ["res://scenes/levels/correo_test.tscn", "res://scenes/levels/scroll_test.tscn",
			"res://scenes/levels/likes_test.tscn", "res://scenes/levels/burbujas_test.tscn",
			"res://scenes/levels/tienda_test.tscn"]:
		var eco := _eco_in_level(scene_path)
		assert_eq(eco.get_sprite_frames().resource_path, sphere, "La esfera de siempre en %s" % scene_path)
		eco.queue_free()
	assert_eq(_attach(true).get_sprite_frames().resource_path, sphere, "Y en el hub (atenuada, mismas frames)")


func test_no_world_declares_its_own_eco() -> void:
	assert_false(_data.has("world_sprite_frames"), "Sin cuerpo de Eco por mundo (world_sprite_frames)")
	assert_eq((_data.get("world_frames", {}) as Dictionary).keys(), ["3"],
		"Solo el marco del Mundo 3 (referencia de los Mundos 1-3)")
	var box: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/eco_text_box.json"))
	assert_false(box.has("world_icons"), "Sin icono de Eco por mundo en el cuadro de texto")
	for id: String in box["speakers"]:
		assert_false((box["speakers"][id] as Dictionary).has("world_icon"), "Sin world_icon en %s" % id)
	assert_false(ResourceLoader.exists("res://assets/sprites/eco_companion_w4_frames.tres"), "Sin los tres puntos")
	assert_false(ResourceLoader.exists("res://assets/sprites/eco/eco_icon_w4.png"), "Sin el icono de tres puntos")
