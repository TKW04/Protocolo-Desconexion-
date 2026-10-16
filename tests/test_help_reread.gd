# Relectura de ayudas ya aprendidas (2026-10-16, decision del usuario; seccion
# reread de data/help.json, HelpSystem y HelpPrompt estilo REREAD): cerca de
# un objeto de un tipo YA aprendido sale una Q pequena y apagada sobre el
# objeto (no sobre Eco, que no vuela ni brilla) solo con Isak quieto still_s
# dentro del radio; al moverse desaparece; no sale si hay un candidato sin
# aprender en rango (la Q normal va primero); pulsarla abre la misma
# explicacion (pausa, cuadro de Eco, linea importante) sin cambiar
# learned_help; respeta «Ayudas de Eco: Ocultar» y no sale con Isak muerto, en
# un vortice, de espaldas ni con el juego en pausa. Colores de la paleta del
# Mundo 1 sin rojos.
extends GutTest

const ISAK_SCENE: PackedScene = preload("res://scenes/player/isak.tscn")
const ECO_SCENE: PackedScene = preload("res://scenes/ui/eco_text_box.tscn")
const TILE: float = 64.0
const ISAK_FEET: Vector2 = Vector2(640.0, 400.0)
const PALETTE_PATH: String = "res://assets/palettes/mundo1.gpl"
const RED_NAMES: Array[String] = ["alerta", "alerta_sombra", "carmin", "carmin_brillo"]

var _root: Node2D
var _isak: Isak
var _box: EcoTextBox
var _help: HelpSystem
var _reread: Array[StringName] = []
var _shown: Array[StringName] = []
var _saved_pause_important: bool


func before_each() -> void:
	_saved_pause_important = EcoTextBox.pause_important
	EcoTextBox.pause_important = true
	GameState.reset_progress()
	GameSettings.reset_defaults()
	_reread.clear()
	_shown.clear()
	_root = Node2D.new()
	_root.name = "RereadTestLevel"
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
	_help.help_reread.connect(func(id: StringName, _text: String) -> void: _reread.append(id))
	_help.help_shown.connect(func(id: StringName, _text: String) -> void: _shown.append(id))
	add_child(_root)
	await wait_process_frames(2)
	# Control manual del tiempo quieto: sin _process, la prueba decide la velocidad.
	_help.set_process(false)
	GameState.meet_ally(GameState.ALLY_ECO)


func after_each() -> void:
	if is_instance_valid(_root):
		_root.free()
	get_tree().paused = false
	EcoTextBox.pause_important = _saved_pause_important
	GameState.reset_progress()
	GameSettings.use_path(GameSettings.settings_path(), true)


func _target(help_id: StringName, offset: Vector2) -> Node2D:
	var node := Node2D.new()
	node.name = "Target_%s_%d" % [help_id, _root.get_child_count()]
	var center: Vector2 = ISAK_FEET + Vector2(0.0, HelpCatalog.shared().isak_center_y()) + offset
	node.position = center - HelpCatalog.shared().center_offset(help_id)
	HelpCatalog.tag(node, help_id)
	_root.add_child(node)
	return node


## Isak con velocidad `speed` durante `seconds` de juego y refresco.
func _stand(seconds: float, speed: float = 0.0) -> void:
	_isak.velocity = Vector2(speed, 0.0)
	_help.update_still(seconds)
	_help.refresh()


func _palette() -> Dictionary:
	var out: Dictionary = {}
	for line: String in FileAccess.get_file_as_string(PALETTE_PATH).split("\n"):
		var cols: PackedStringArray = line.strip_edges().replace("\t", " ").split(" ", false)
		if cols.size() >= 4 and cols[0].is_valid_int():
			out[cols[3]] = Color8(int(cols[0]), int(cols[1]), int(cols[2]))
	return out


func _color_name(color: Color, palette: Dictionary) -> String:
	for key: Variant in palette:
		if (palette[key] as Color).to_html(false) == color.to_html(false):
			return String(key)
	return ""


# --- Aparicion ---

func test_dim_q_only_when_still_in_range_of_a_learned_type() -> void:
	var receiver: Node2D = _target(&"receiver", Vector2(TILE, 0.0))
	GameState.learn_help(&"receiver")
	_stand(0.1)
	assert_false(_help.is_reread_visible(), "Recien parado: sin Q apagada")
	_stand(HelpCatalog.shared().reread_still_s())
	assert_true(_help.is_reread_visible(), "Quieto still_s: Q apagada")
	assert_eq(_help.get_reread_target(), receiver)
	assert_false(_help.is_prompt_visible(), "No es la Q normal")
	var at: Vector2 = receiver.global_position + HelpCatalog.shared().prompt_offset(&"receiver")
	assert_eq(_help.get_reread_prompt().global_position, at.round(), "Sobre el objeto, no sobre Eco")
	_stand(0.016, 220.0)
	assert_false(_help.is_reread_visible(), "Al moverse desaparece")
	assert_eq(_help.get_still_s(), 0.0, "Y el tiempo quieto vuelve a 0")
	receiver.position.x += TILE * 2.0
	_stand(5.0)
	assert_false(_help.is_reread_visible(), "Fuera del radio: no")


func test_still_time_is_parametrized_in_data() -> void:
	var still: float = HelpCatalog.shared().reread_still_s()
	assert_almost_eq(still, 0.8, 0.001, "still_s de data/help.json")
	assert_gt(HelpCatalog.shared().reread_still_speed(), 0.0)


func test_unlearned_candidate_goes_first() -> void:
	_target(&"receiver", Vector2(TILE, 0.0))
	GameState.learn_help(&"receiver")
	var charger: Node2D = _target(&"charger", Vector2(-TILE * 2.0, 0.0))
	_stand(2.0)
	assert_eq(_help.get_target(), charger, "La Q normal del tipo sin aprender")
	assert_false(_help.is_reread_visible(), "Con candidato sin aprender, sin relectura")
	charger.position.x -= TILE * 3.0
	_stand(0.1)
	assert_true(_help.is_reread_visible(), "Sin candidato sin aprender, vuelve la relectura")


func test_only_one_dim_q_on_the_nearest() -> void:
	_target(&"receiver", Vector2(TILE * 2.0, 0.0))
	var near: Node2D = _target(&"charger", Vector2(-TILE * 0.5, 0.0))
	GameState.learn_help(&"receiver")
	GameState.learn_help(&"charger")
	_stand(1.0)
	assert_eq(_help.get_reread_target(), near, "El mas cercano")


func test_pressing_help_rereads_without_learning_or_flying_eco() -> void:
	var companion: EcoCompanion = EcoCompanion.attach(_isak, _root)
	await wait_process_frames(2)
	_target(&"receiver", Vector2(TILE, 0.0))
	GameState.learn_help(&"receiver")
	var learned_before: Dictionary = GameState.learned_help.duplicate()
	_stand(1.0)
	assert_true(_help.is_reread_visible())
	assert_null(companion.get_help_target(), "Eco no va hacia el objeto")
	assert_true(_help.request_help())
	assert_eq(_reread, [&"receiver"] as Array[StringName])
	assert_eq(_shown.size(), 0, "No es un aprendizaje")
	assert_true(get_tree().paused, "Misma pausa")
	assert_true(_box.is_important(), "Mismo cuadro, linea importante")
	assert_eq(_box.get_text(), HelpCatalog.shared().text(&"receiver"), "Misma explicacion")
	assert_eq(GameState.learned_help, learned_before, "learned_help no cambia")
	assert_false(GameState.has_unsaved_changes())
	assert_false(_help.is_reread_visible())
	assert_null(companion.get_help_target(), "Eco sigue sin senalar")
	_box.confirm()
	_box.confirm()
	_box.advance(1.0)
	assert_false(get_tree().paused, "Se cierra igual")


func test_hidden_help_setting_hides_the_dim_q() -> void:
	_target(&"receiver", Vector2(TILE, 0.0))
	GameState.learn_help(&"receiver")
	GameSettings.set_eco_help_shown(false)
	_stand(2.0)
	assert_false(_help.is_reread_visible(), "«Ocultar»: no sale")
	assert_false(_help.request_help())
	GameSettings.set_eco_help_shown(true)
	_stand(0.1)
	assert_true(_help.is_reread_visible())


func test_no_dim_q_in_forbidden_states() -> void:
	_target(&"receiver", Vector2(TILE, 0.0))
	GameState.learn_help(&"receiver")
	_stand(2.0)
	assert_true(_help.is_reread_visible())
	get_tree().paused = true
	_help.refresh()
	assert_false(_help.is_reread_visible(), "En pausa: no")
	assert_false(_help.request_help())
	get_tree().paused = false
	_isak.face_back()
	_stand(2.0)
	assert_false(_help.is_reread_visible(), "De espaldas: no")
	_isak.face_side()
	_stand(2.0)
	assert_true(_help.is_reread_visible())
	_isak.die()
	_stand(2.0)
	assert_false(_help.is_reread_visible(), "Muerto: no")


func test_no_dim_q_while_warping() -> void:
	_target(&"receiver", Vector2(TILE, 0.0))
	GameState.learn_help(&"receiver")
	WarpVortex.arrive(_isak, _root, true)
	_stand(2.0)
	assert_false(_help.is_reread_visible(), "En el vortice: no")


func test_no_dim_q_before_meeting_eco() -> void:
	GameState.reset_progress()
	_target(&"receiver", Vector2(TILE, 0.0))
	GameState.learn_help(&"receiver")
	_stand(2.0)
	assert_false(_help.is_reread_visible())


func test_dim_q_is_small_and_uses_palette_colors_without_red() -> void:
	var prompt: HelpPrompt = _help.get_reread_prompt()
	var normal: HelpPrompt = _help.get_prompt()
	assert_eq(prompt.style, HelpPrompt.Style.REREAD)
	assert_eq(prompt.get_key_text(), "Q", "La tecla del Input Map")
	assert_lt(prompt.get_plate_scale(), normal.get_plate_scale(), "Mas pequena")
	assert_eq(prompt.get_parent(), normal.get_parent(), "En la capa de la Q")
	var palette: Dictionary = _palette()
	var colors: Dictionary = prompt.get_plate_colors()
	for color: Color in [prompt.get_text_color(), colors.border, colors.plate]:
		var color_name: String = _color_name(color, palette)
		assert_ne(color_name, "", "%s en mundo1.gpl" % color.to_html(false))
		assert_false(RED_NAMES.has(color_name), "Sin rojos (%s)" % color_name)
	assert_ne(prompt.get_text_color().to_html(false), Color.html("#f2f4f8").to_html(false), "Glifo atenuado")
