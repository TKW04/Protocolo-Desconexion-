# Presentacion de Notas en el primer hub (NotasIntro; docs/propuesta-asistentes-
# y-vidas.md §2.2, paso 8 de §10): antes de conocerla Notas esta apagada (sin
# prompt, el pulso no la abre, no se puede guardar); al terminar la llegada Eco
# (atenuado) la presenta, Notas se enciende y habla con su nombre; el juego queda
# en pausa de principio a fin; al cerrar la ultima linea "notas" queda en
# allies_met (sin marcar «sin guardar») y no se repite.
# Usa su propia ruta de guardado (nunca user://save.json).
extends GutTest

const HUB_SCENE: PackedScene = preload("res://scenes/hub/hub.tscn")
const EcoProgress = preload("res://tests/support/eco_progress.gd")
const PATH: String = "user://test_notas_intro.json"
const T: float = 64.0

var _hub: HubRoom
var _saved_path: String
var _saved_pulse: bool
var _saved_pause_important: bool


func before_each() -> void:
	_saved_path = GameState.save_path
	_saved_pulse = GameState.is_ability_unlocked(GameState.ABILITY_PULSE)
	_saved_pause_important = EcoTextBox.pause_important
	EcoTextBox.pause_important = true
	GameState.use_save_path(PATH, true)


func after_each() -> void:
	if _hub != null and is_instance_valid(_hub):
		_hub.free()
	_hub = null
	get_tree().paused = false
	EcoTextBox.pause_important = _saved_pause_important
	SaveFile.delete(PATH)
	GameState.reset_progress()
	GameState.save_path = _saved_path
	GameState.set_ability_unlocked(GameState.ABILITY_PULSE, _saved_pulse)


func _spawn() -> void:
	_hub = HUB_SCENE.instantiate() as HubRoom
	add_child(_hub)
	_hub.get_isak().input = PlayerInput.new()


func _arrive() -> void:
	var vortex: WarpVortex = _hub.get_arrival_vortex()
	if vortex != null:
		vortex.advance(5.0)


## Cierra la linea importante en pantalla como el jugador (completa, confirma y
## deja pasar el fundido de salida).
func _close_line() -> void:
	var box: EcoTextBox = _hub.get_text_box()
	box.finish_typing()
	box.confirm()
	box.advance(1.0)
	await get_tree().process_frame
	await get_tree().process_frame


func test_notas_is_powered_off_before_the_first_entry() -> void:
	EcoProgress.meet_eco_with_pulse()
	_spawn()
	var notas: NotasStation = _hub.get_notas()
	assert_false(notas.is_powered(), "Apagada antes de la presentacion")
	assert_eq(notas.get_visual_state(), HubStation.VISUAL_POWERED_OFF)
	assert_eq((notas.get_visual() as AnimatedSprite2D).animation, &"powered_off", "Arte apagado")
	assert_false(notas.open(_hub.get_isak()), "No se abre")
	assert_false(_hub.can_save_now(), "Apagada: el aviso al salir no ofrece guardar")
	_hub.get_isak().global_position = Vector2(2.6 * T, _hub.get_floor_y())
	await wait_physics_frames(4)
	notas.advance(0.1)
	assert_false(notas.is_key_hint_visible(), "Sin tecla del pulso")
	assert_eq(notas.get_state(), HubStation.State.OFF)


func test_eco_presents_notas_after_arrival_and_it_does_not_repeat() -> void:
	EcoProgress.meet_eco_with_pulse()
	GameState.set_nickname("Kai")
	GameState.save_game()
	_spawn()
	var intro: NotasIntro = _hub.get_notas_intro()
	assert_not_null(intro, "Hay presentacion")
	assert_eq(intro.get_step(), NotasIntro.Step.WAITING, "Espera a la llegada")
	assert_false(get_tree().paused)
	_arrive()
	var box: EcoTextBox = _hub.get_text_box()
	assert_eq(intro.get_step(), NotasIntro.Step.ECO, "Eco habla primero")
	assert_true(get_tree().paused, "Momento de historia: pausa")
	assert_eq(box.get_speaker_id(), &"", "Habla Eco")
	assert_eq(box.get_speaker_text(), "Eco")
	assert_true(box.get_text().contains("Notas"), "Eco presenta a Notas")
	assert_true(box.is_important())
	assert_false(_hub.get_notas().is_powered(), "Notas sigue apagada mientras Eco habla")
	await _close_line()
	assert_eq(intro.get_step(), NotasIntro.Step.NOTAS)
	assert_true(_hub.get_notas().is_powered(), "Notas se enciende")
	assert_true(get_tree().paused, "Sigue en pausa entre lineas")
	assert_eq(box.get_speaker_id(), &"notas")
	assert_eq(box.get_speaker_text(), "Notas", "Habla Notas con su nombre")
	assert_true(box.get_text().contains("Kai"), "Notas llama al jugador por su apodo")
	await _close_line()
	assert_true(box.get_text().contains("guardar"), "Explica que sin guardar se pierde")
	assert_false(GameState.has_met_ally(GameState.ALLY_NOTAS), "Aun no hasta cerrar la ultima")
	await _close_line()
	assert_true(intro.is_done())
	assert_true(GameState.has_met_ally(GameState.ALLY_NOTAS), "Notas conocida")
	assert_false(get_tree().paused, "Se reanuda")
	assert_false(GameState.has_unsaved_changes(), "Conocer a Notas no marca «sin guardar»")
	assert_true(_hub.can_save_now())
	assert_true(_hub.get_notas().open(_hub.get_isak()), "Ya se abre")
	_hub.get_notas().close(true)
	_hub.free()
	_spawn()
	_arrive()
	assert_null(_hub.get_notas_intro(), "La segunda vez no hay presentacion")
	assert_true(_hub.get_notas().is_powered())
	assert_false(get_tree().paused)


func test_eco_lines_go_through_the_event_bus_but_notas_lines_do_not() -> void:
	EcoProgress.meet_eco_with_pulse()
	_spawn()
	var eco_lines: Array[String] = []
	var record := func(text: String) -> void: eco_lines.append(text)
	EventBus.eco_line_started.connect(record)
	_arrive()
	await _close_line()
	await _close_line()
	await _close_line()
	EventBus.eco_line_started.disconnect(record)
	assert_eq(eco_lines.size(), 1, "Solo la linea de Eco: el companero no «dice» las de Notas")


func test_without_eco_notas_presents_itself() -> void:
	_spawn()
	_arrive()
	var intro: NotasIntro = _hub.get_notas_intro()
	assert_eq(intro.get_step(), NotasIntro.Step.NOTAS, "Sin Eco conocido se omite su linea")
	assert_true(_hub.get_notas().is_powered())
	await _close_line()
	await _close_line()
	assert_true(GameState.has_met_ally(GameState.ALLY_NOTAS))


func test_leaving_the_hub_mid_presentation_releases_the_pause() -> void:
	EcoProgress.meet_eco_with_pulse()
	_spawn()
	_arrive()
	assert_true(get_tree().paused)
	_hub.free()
	_hub = null
	assert_false(get_tree().paused, "La pausa se libera al salir del arbol")
	assert_false(GameState.has_met_ally(GameState.ALLY_NOTAS), "No se dio por vista")


func test_intro_texts_use_the_proposal_voice_and_font_glyphs() -> void:
	var data: Dictionary = HubData.section("notas_intro")
	var font: Font = load("res://assets/sprites/ui/text_font.fnt") as Font
	for key: String in ["eco", "notas"]:
		for text: String in data.get(key, []):
			for word: String in ["Vuelta", "vuelta", "Easy", "Normal", "Hard"]:
				assert_false(text.contains(word), "«%s» no dice «%s»" % [text, word])
			for ch: String in GameState.apply_nickname(text, "Isak"):
				assert_true(font.has_char(ch.unicode_at(0)), "La fuente tiene «%s»" % ch)
