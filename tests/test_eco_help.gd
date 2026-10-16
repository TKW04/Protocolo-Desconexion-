# Eco lleva la Q (2026-10-16, decision del usuario; HelpSystem + EcoCompanion,
# data/eco_companion.json): con un objeto candidato (HelpSystem sigue siendo la
# fuente de verdad), Eco vuela junto a el sin tapar a Isak, la Q se dibuja sobre
# Eco (no sobre el objeto) y lo sigue, y Eco brilla en ambar (glow_in ->
# _amber -> glow_out). Al pedir la ayuda conserva el brillo y anima con el juego
# en pausa; al cerrar vuelve a Isak con su color. Vuelve siempre: tipo aprendido,
# fuera de rango, objeto liberado, nivel quitado, muerte, vortice, menu de
# pausa y ajuste «Ocultar» (este ultimo: ni se acerca ni brilla ni hay Q).
extends GutTest

const ISAK_SCENE: PackedScene = preload("res://scenes/player/isak.tscn")
const BOX_SCENE: PackedScene = preload("res://scenes/ui/eco_text_box.tscn")
const TILE: float = 64.0
const FEET: Vector2 = Vector2(640.0, 400.0)
const STEP: float = 1.0 / 60.0

var _root: Node2D
var _isak: Isak
var _box: EcoTextBox
var _help: HelpSystem
var _eco: EcoCompanion
var _data: Dictionary = EcoCompanion.load_data()
var _saved_pause_important: bool
var _settings_path: String


func before_each() -> void:
	_saved_pause_important = EcoTextBox.pause_important
	EcoTextBox.pause_important = true
	_settings_path = GameSettings.settings_path()
	GameSettings.use_path(_settings_path, true)
	GameState.reset_progress()
	GameState.meet_ally(GameState.ALLY_ECO)
	_root = Node2D.new()
	_root.name = "EcoHelpLevel"
	var enemies := Node2D.new()
	enemies.name = "Enemies"
	_root.add_child(enemies)
	_isak = ISAK_SCENE.instantiate() as Isak
	_isak.name = "Isak"
	_isak.position = FEET
	_root.add_child(_isak)
	_box = BOX_SCENE.instantiate() as EcoTextBox
	_box.name = "EcoTextBox"
	_root.add_child(_box)
	_help = HelpSystem.new()
	_help.name = "Help"
	_root.add_child(_help)
	add_child(_root)
	_eco = EcoCompanion.attach(_isak, _root)
	_eco.auto_advance = false
	_help.set_process(false)
	await wait_process_frames(2)
	_run(1.0)


func after_each() -> void:
	if is_instance_valid(_root):
		_root.free()
	get_tree().paused = false
	EcoTextBox.pause_important = _saved_pause_important
	GameState.reset_progress()
	GameSettings.use_path(_settings_path, true)


## Avanza Eco y refresca la ayuda (como un cuadro: Eco primero, la Q despues).
func _run(seconds: float) -> void:
	var t: float = 0.0
	while t < seconds:
		_eco.advance(STEP)
		_help.refresh()
		t += STEP


func _target(help_id: StringName, offset: Vector2) -> Node2D:
	var node := Node2D.new()
	node.name = "Target_%s_%d" % [help_id, _root.get_child_count()]
	var center: Vector2 = FEET + Vector2(0.0, HelpCatalog.shared().isak_center_y()) + offset
	node.position = center - HelpCatalog.shared().center_offset(help_id)
	HelpCatalog.tag(node, help_id)
	_root.add_child(node)
	return node


func _object_prompt(target: Node2D) -> Vector2:
	return target.global_position + HelpCatalog.shared().prompt_offset(HelpCatalog.help_id_of(target))


func _assert_back_with_isak(why: String) -> void:
	assert_false(_eco.is_helping(), "%s: Eco suelta el objeto" % why)
	_run(2.0)
	assert_eq(_eco.get_glow(), EcoCompanion.Glow.OFF, "%s: recupera su color" % why)
	assert_false(String(_eco.get_shown_animation()).ends_with(EcoCompanion.AMBER_SUFFIX), why)
	assert_lt(_eco.get_anchor().distance_to(_eco.get_follow_position()), 8.0, "%s: vuelve a seguir a Isak" % why)


func test_eco_flies_to_the_candidate_and_carries_the_q() -> void:
	var start: Vector2 = _eco.get_anchor()
	var target: Node2D = _target(&"receiver", Vector2(TILE * 1.5, 0.0))
	_help.refresh()
	assert_eq(_help.get_target(), target, "HelpSystem sigue eligiendo el candidato")
	assert_eq(_eco.get_help_target(), target, "Y se lo pasa a Eco")
	assert_eq(_eco.get_glow(), EcoCompanion.Glow.IN, "Empieza a brillar")
	var prompt: HelpPrompt = _help.get_prompt()
	var positions: Array[Vector2] = []
	for i: int in 90:
		_eco.advance(STEP)
		_help.refresh()
		assert_true(_help.is_prompt_on_eco())
		assert_eq(prompt.global_position, _eco.get_prompt_position().round(), "La Q sigue a Eco (cuadro %d)" % i)
		positions.append(prompt.global_position)
	assert_ne(positions[0], positions[positions.size() - 1], "La Q se ha movido con Eco")
	assert_ne(prompt.global_position, _object_prompt(target).round(), "No va sobre el objeto")
	assert_gt(_eco.get_anchor().distance_to(start), 40.0, "Eco ha dejado su sitio")
	assert_lt(_eco.get_anchor().distance_to(_eco.get_target_position()), 6.0, "Ha llegado junto al objeto")
	assert_lt(_eco.get_anchor().y, _object_prompt(target).y - 20.0, "Encima del objeto, sin taparlo")
	var clear: Array = _data["help_isak_clear_px"]
	var body := Rect2(FEET.x - float(clear[0]), FEET.y - float(clear[1]), float(clear[0]) * 2.0, float(clear[1]))
	assert_false(body.has_point(_eco.get_anchor()), "No tapa a Isak")
	assert_eq(_eco.get_glow(), EcoCompanion.Glow.ON)
	assert_eq(_eco.get_shown_animation(), &"idle_amber", "Brilla en ambar")
	assert_lt(_eco.get_index(), _isak.get_index(), "Sigue detras de Isak")


func test_glow_frames_use_the_amber_of_the_palette() -> void:
	var frames: SpriteFrames = _eco.get_sprite().sprite_frames
	for anim: StringName in [&"idle_amber", &"talk_amber", &"notice_amber", &"glow_in", &"glow_out"]:
		assert_true(frames.has_animation(anim), String(anim))
	var image: Image = frames.get_frame_texture(&"idle_amber", 2).get_image()
	var found: bool = false
	for y: int in image.get_height():
		for x: int in image.get_width():
			if image.get_pixel(x, y).to_html(false) == "ffa000":
				found = true
	assert_true(found, "ambar #ffa000 de mundo1.gpl")
	assert_eq(frames.get_frame_count(&"glow_in"), 3, "Transicion de 3 cuadros")
	assert_eq(frames.get_frame_texture(&"glow_out", 0), frames.get_frame_texture(&"glow_in", 2), "glow_out al reves")


func test_leaving_the_range_sends_eco_back() -> void:
	var target: Node2D = _target(&"receiver", Vector2(TILE * 1.5, 0.0))
	_run(1.0)
	assert_eq(_eco.get_help_target(), target)
	target.position.x += TILE * 4.0
	_run(STEP)
	assert_false(_help.is_prompt_visible(), "Fuera de rango: sin Q")
	assert_eq(_eco.get_glow(), EcoCompanion.Glow.OUT, "Se apaga el brillo")
	_assert_back_with_isak("Fuera de rango")


func test_learning_the_type_elsewhere_sends_eco_back() -> void:
	_target(&"receiver", Vector2(TILE * 1.5, 0.0))
	_run(1.0)
	GameState.learn_help(&"receiver")
	_eco.advance(STEP)
	_assert_back_with_isak("Aprendido por otra via")


func test_freed_target_or_level_never_leaves_eco_stuck() -> void:
	var target: Node2D = _target(&"receiver", Vector2(TILE * 1.5, 0.0))
	_run(1.0)
	target.free()
	_eco.advance(STEP)  # Sin refrescar la ayuda: Eco lo detecta solo.
	_assert_back_with_isak("Objeto liberado")
	var hidden: Node2D = _target(&"charger", Vector2(-TILE * 1.5, 0.0))
	_run(1.0)
	assert_eq(_eco.get_help_target(), hidden)
	hidden.visible = false
	_eco.advance(STEP)
	_assert_back_with_isak("Objeto oculto")
	_help.free()  # Nivel a medio descargar: Eco sigue sin atascarse.
	_target(&"bridge", Vector2(TILE, 0.0))
	for i: int in 30:
		_eco.advance(STEP)
	assert_false(_eco.is_helping())
	_root.free()
	assert_false(get_tree().paused, "Quitar el nivel no deja nada en pausa")


func test_death_sends_eco_back() -> void:
	_target(&"receiver", Vector2(TILE * 1.5, 0.0))
	_run(1.0)
	_isak.die()
	_eco.advance(STEP)
	assert_false(_eco.is_helping(), "Muerto: Eco suelta el objeto")
	_help.refresh()
	assert_false(_help.is_prompt_visible(), "Muerto: sin Q")


func test_vortex_sends_eco_back() -> void:
	_target(&"receiver", Vector2(TILE * 1.5, 0.0))
	_run(1.0)
	_isak.face_back()
	var vortex: WarpVortex = WarpVortex.depart(_isak, _root)
	vortex.set_process(false)
	_eco.advance(STEP)
	assert_false(_eco.is_helping(), "Vortice: suelta el objeto")
	assert_eq(_eco.get_state(), EcoCompanion.State.DEPARTING, "Y se va con Isak")
	assert_ne(_eco.get_glow(), EcoCompanion.Glow.ON)


func test_pause_menu_sends_eco_back_and_it_returns_after() -> void:
	var target: Node2D = _target(&"receiver", Vector2(TILE * 1.5, 0.0))
	_run(1.0)
	get_tree().paused = true  # Menu de pausa (no explica ninguna ayuda).
	_run(STEP)
	assert_false(_help.is_prompt_visible(), "En pausa no hay Q")
	_assert_back_with_isak("Menu de pausa")
	get_tree().paused = false
	_run(STEP)
	assert_eq(_eco.get_help_target(), target, "Al reanudar vuelve a senalarlo")


func test_hidden_help_setting_no_approach_no_glow_no_q() -> void:
	GameSettings.set_eco_help_shown(false)
	var start: Vector2 = _eco.get_anchor()
	_target(&"receiver", Vector2(TILE * 1.5, 0.0))
	_run(1.0)
	assert_false(_help.is_prompt_visible(), "Ocultar: sin Q")
	assert_false(_eco.is_helping(), "Ni se acerca")
	assert_false(_eco.is_glowing(), "Ni brilla")
	assert_lt(_eco.get_anchor().distance_to(start), 8.0)
	GameSettings.set_eco_help_shown(true)
	_run(0.5)
	assert_true(_eco.is_helping())
	GameSettings.set_eco_help_shown(false)
	_run(STEP)
	_assert_back_with_isak("Ajuste Ocultar")


func test_explaining_keeps_the_glow_and_animates_while_paused() -> void:
	var target: Node2D = _target(&"receiver", Vector2(TILE * 1.5, 0.0))
	_run(1.0)
	var spot: Vector2 = _eco.get_anchor()
	assert_true(_help.request_help())
	assert_true(get_tree().paused, "La ayuda pausa el juego")
	assert_true(_eco.is_explaining())
	assert_false(_help.is_prompt_visible(), "La Q se va al pedirla")
	var frames_seen: Dictionary = {}
	for i: int in 60:
		_eco.advance(STEP)
		_help.refresh()
		frames_seen[_eco.get_sprite().frame] = true
		assert_eq(_eco.get_glow(), EcoCompanion.Glow.ON, "Conserva el brillo durante la explicacion")
	assert_true(String(_eco.get_shown_animation()).ends_with(EcoCompanion.AMBER_SUFFIX), "Habla en ambar")
	assert_gt(frames_seen.size(), 1, "Sigue animandose en pausa (tiempo real)")
	assert_lt(_eco.get_anchor().distance_to(spot), 8.0, "Se queda junto al objeto")
	assert_eq(_eco.get_help_target(), target)
	_box.confirm()
	_box.confirm()
	_box.advance(1.0)
	assert_false(get_tree().paused)
	_eco.advance(STEP)
	assert_false(_eco.is_explaining())
	assert_eq(_eco.get_glow(), EcoCompanion.Glow.OUT, "Al cerrar, vuelve a su color")
	_assert_back_with_isak("Ayuda cerrada")
	assert_null(_help.get_target(), "Tipo aprendido: ya no hay candidato")


func test_explanation_that_never_shows_does_not_stick() -> void:
	_target(&"receiver", Vector2(TILE * 1.5, 0.0))
	_run(1.0)
	_box.free()  # Sin cuadro de Eco, la linea no llega a decirse.
	assert_true(_help.request_help())
	get_tree().paused = false
	_run(float(_data["help_explain_grace_s"]) + 0.1)
	assert_false(_eco.is_explaining(), "Sin linea, Eco no se queda esperando")
