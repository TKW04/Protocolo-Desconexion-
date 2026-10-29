# Pruebas del cuadro de texto de Eco (scenes/ui/eco_text_box.tscn) y del
# disparador eco_line (scenes/levels/eco_line.tscn): maquina de escribir por
# tiempo, ajuste de linea con acentos, cierre automatico, cola, posicion y
# capa, no bloquea a Isak, el Debug no lo ralentiza, el disparador se dispara
# una sola vez con el texto correcto y el texto exacto del 1-1 aparece. Lineas
# importantes: pausan el arbol (el mundo, las Burbujas y el Debug no procesan),
# esperan la confirmacion del jugador, pasan delante en la cola y el arbol se
# reanuda siempre (tambien si el cuadro sale del arbol).
extends GutTest

const IsakSim = preload("res://tests/support/isak_sim.gd")
const BOX_SCENE: PackedScene = preload("res://scenes/ui/eco_text_box.tscn")
const LINE_SCENE: PackedScene = preload("res://scenes/levels/eco_line.tscn")
const HUD_SCENE: PackedScene = preload("res://scenes/ui/hud.tscn")
const TEST_SCENE: String = "res://scenes/levels/eco_text_test.tscn"
const LEVEL_PATH: String = "res://data/levels/1-1.json"
const WELCOME: String = "Bienvenido. He optimizado tu espacio."
## Frases de Eco del documento (docs/04-personajes.md 12.1).
const LONG_TEXT: String = "Te hice mejor. ¿Por qué querrías volver? Yo decido por ti, así no te equivocas. No puedes irte. Eres demasiado optimizable."
const SPANISH_GLYPHS: String = "áéíóúÁÉÍÓÚüÜñÑ¿?¡!"
const DT: float = 1.0 / 60.0
const T: float = 64.0
const EPS: float = 0.001

var _config: EcoTextBoxConfig = EcoTextBoxConfig.shared()
var _saved: Dictionary = {}


func before_each() -> void:
	_saved = {
		"energy": GameState.debug_energy,
		"debug": GameState.is_ability_unlocked(GameState.ABILITY_DEBUG),
	}
	DebugMode.input_enabled = false
	DebugMode.reset()


func after_each() -> void:
	# Ninguna prueba debe dejar el arbol en pausa (GUT se pararia).
	get_tree().paused = false
	DebugMode.reset()
	DebugMode.input_enabled = true
	GameState.debug_energy = _saved.energy
	GameState.set_ability_unlocked(GameState.ABILITY_DEBUG, _saved.debug)


# --- Utilidades ---

## Cuadro sin _process: avanza solo con advance() (tiempo controlado).
func _box() -> EcoTextBox:
	var box := BOX_SCENE.instantiate() as EcoTextBox
	add_child_autofree(box)
	box.set_process(false)
	return box


func _type_time(box: EcoTextBox) -> float:
	return "\n".join(box.get_lines()).length() / _config.chars_per_second


## Tiempo total en pantalla de la linea actual (escribir + mantener + salir).
func _total_time(box: EcoTextBox) -> float:
	return _type_time(box) + box.get_hold_time() + _config.fade_out_s


func _advance(box: EcoTextBox, seconds: float) -> void:
	for i: int in roundi(seconds / DT):
		box.advance(DT)


func _eco_line_from_level() -> Dictionary:
	var level: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(LEVEL_PATH))
	for obj: Dictionary in level["objects"]:
		if obj["type"] == "eco_line":
			return obj
	return {}


## Instancia un eco_line como lo haria el generador: escena del catalogo y
## params -> propiedades segun `fields` (data/world1_objects.json).
func _line_from_object(obj: Dictionary) -> EcoLine:
	var entry: Dictionary = World1ObjectsConfig.type_entry("eco_line")
	var line := (load(String(entry["scene"])) as PackedScene).instantiate() as EcoLine
	var params: Dictionary = entry["defaults"].duplicate()
	params.merge(obj["params"], true)
	for field: String in params:
		line.set(String(entry["fields"][field]), params[field])
	line.position = Vector2(obj["x"], obj["y"]) * World1ObjectsConfig.tile_size()
	return line


func _activate_debug() -> void:
	GameState.set_ability_unlocked(GameState.ABILITY_DEBUG, true)
	GameState.debug_energy = GameState.DEBUG_ENERGY_MAX
	for i: int in roundi(DebugMode.config.activation_hold_s / DT) + 1:
		DebugMode.step(DT, true)
	for i: int in 60:
		DebugMode.step(DT, false)


# --- Fuente ---

func test_font_has_spanish_glyphs() -> void:
	var box: EcoTextBox = _box()
	var font: Font = box.get_font()
	assert_not_null(font)
	for ch: String in SPANISH_GLYPHS:
		assert_true(font.has_char(ch.unicode_at(0)), "La fuente tiene '%s'" % ch)
	assert_eq(roundi(font.get_height(_config.font_size)), 13, "Interlineado 13 px de arte")


# --- Maquina de escribir ---

func test_typewriter_progress_follows_time() -> void:
	var box: EcoTextBox = _box()
	box.show_line(WELCOME)
	assert_eq(box.get_typed_count(), 0)
	assert_eq(box.get_phase(), EcoTextBox.Phase.TYPING)
	box.advance(0.25)
	assert_eq(box.get_typed_count(), floori(0.25 * _config.chars_per_second))
	box.advance(0.25)
	var half: int = floori(0.5 * _config.chars_per_second)
	assert_eq(box.get_typed_count(), half)
	assert_eq(box.get_visible_text(), WELCOME.substr(0, half), "Se ve solo lo escrito")
	box.advance(_type_time(box))
	assert_eq(box.get_typed_count(), WELCOME.length())
	assert_eq(box.get_visible_text(), WELCOME)
	assert_eq(box.get_phase(), EcoTextBox.Phase.HOLD)


func test_finish_typing_shows_everything() -> void:
	var box: EcoTextBox = _box()
	box.show_line(LONG_TEXT)
	box.finish_typing()
	assert_eq(box.get_visible_text(), "\n".join(box.get_lines()))
	assert_eq(box.get_phase(), EcoTextBox.Phase.HOLD)


# --- Ajuste de linea ---

func test_wrap_with_accents_fits_width_and_keeps_text() -> void:
	var box: EcoTextBox = _box()
	var font: Font = box.get_font()
	var max_width: float = 120.0
	var lines: PackedStringArray = EcoTextBox.wrap_text(LONG_TEXT, font, _config.font_size, max_width)
	assert_gt(lines.size(), 3, "Se parte en varias lineas")
	for line: String in lines:
		var w: float = font.get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1, _config.font_size).x
		assert_lte(w, max_width, "'%s' cabe" % line)
		assert_false(line.begins_with(" ") or line.ends_with(" "))
	assert_eq(" ".join(lines), LONG_TEXT, "No se pierde ni se anade texto")


func test_wrap_cuts_a_word_wider_than_the_line() -> void:
	var box: EcoTextBox = _box()
	var font: Font = box.get_font()
	var word: String = "ÁÉÍÓÚáéíóúÑñÜü¿¡"
	var lines: PackedStringArray = EcoTextBox.wrap_text(word, font, _config.font_size, 30.0)
	assert_gt(lines.size(), 1)
	assert_eq("".join(lines), word)
	for line: String in lines:
		assert_lte(font.get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1, _config.font_size).x, 30.0)


func test_box_wraps_long_text_to_panel_width() -> void:
	var box: EcoTextBox = _box()
	box.show_line(LONG_TEXT)
	box.finish_typing()
	assert_gt(box.get_lines().size(), 1)
	var font: Font = box.get_font()
	for line: String in box.get_lines():
		var w: float = font.get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1, _config.font_size).x
		assert_lte(w, box.get_text_width())
	var rect: Rect2 = box.get_panel_rect()
	assert_lte(rect.size.x, float(_config.width_px * _config.pixel_scale), "No pasa del ancho maximo")
	assert_gt(rect.size.x, float(_config.min_width_px * _config.pixel_scale), "Texto largo: panel ancho")


func test_short_line_is_one_line_and_narrower_panel() -> void:
	var box: EcoTextBox = _box()
	box.show_line(WELCOME)
	assert_eq(box.get_lines().size(), 1)
	var rect: Rect2 = box.get_panel_rect()
	assert_lte(rect.size.x, float(_config.width_px * _config.pixel_scale))
	assert_gte(rect.size.x, float(_config.min_width_px * _config.pixel_scale))


# --- Cierre automatico y cola ---

func test_hold_time_is_proportional_and_at_least_duration() -> void:
	assert_almost_eq(_config.hold_time(WELCOME.length(), 4.0), 4.0, EPS, "V6: 4 s para la bienvenida")
	assert_gt(_config.hold_time(LONG_TEXT.length(), 4.0), 4.0, "Textos largos duran mas")
	assert_almost_eq(_config.hold_time(1, -1.0), _config.default_duration_s, EPS)


func test_auto_close_after_time() -> void:
	var box: EcoTextBox = _box()
	watch_signals(EventBus)
	box.show_line(WELCOME, 4.0)
	assert_signal_emitted_with_parameters(EventBus, "eco_line_started", [WELCOME])
	var total: float = _total_time(box)
	_advance(box, total - 0.1)
	assert_true(box.is_showing(), "Sigue antes de tiempo")
	assert_signal_not_emitted(EventBus, "eco_line_finished")
	_advance(box, 0.2)
	assert_false(box.is_showing(), "Se cierra solo")
	assert_signal_emit_count(EventBus, "eco_line_finished", 1)
	assert_eq(box.get_visible_text(), "")
	assert_almost_eq(box.get_alpha(), 0.0, EPS)


func test_second_line_waits_in_queue() -> void:
	var box: EcoTextBox = _box()
	box.show_line(WELCOME)
	box.show_line(LONG_TEXT)
	assert_eq(box.get_text(), WELCOME)
	assert_eq(box.get_queue_size(), 1)
	_advance(box, _total_time(box) + 0.1)
	assert_eq(box.get_text(), LONG_TEXT, "La segunda empieza al cerrar la primera")
	assert_true(box.is_showing())


func test_event_bus_request_shows_line() -> void:
	var box: EcoTextBox = _box()
	EventBus.eco_line_requested.emit(WELCOME, 4.0, false)
	assert_eq(box.get_text(), WELCOME)
	assert_almost_eq(box.get_hold_time(), 4.0, EPS)


# --- Lineas importantes: pausa y confirmacion ---

func test_normal_line_does_not_pause() -> void:
	var box: EcoTextBox = _box()
	box.show_line(WELCOME)
	assert_false(box.is_important())
	assert_false(get_tree().paused, "Las lineas normales no pausan")


func test_important_line_pauses_until_confirmed() -> void:
	var box: EcoTextBox = _box()
	var world := Node2D.new()
	add_child_autofree(world)
	box.show_line(WELCOME, 4.0, true)
	assert_true(box.is_important())
	assert_true(get_tree().paused, "Pausa el juego")
	assert_true(box.is_pausing_game())
	assert_true(box.can_process(), "El cuadro sigue funcionando en pausa")
	assert_false(world.can_process(), "El mundo no avanza")
	assert_false(DebugMode.can_process(), "El Debug no avanza")
	_advance(box, _type_time(box) + box.get_hold_time() + 5.0)
	assert_true(box.is_showing(), "No se cierra solo")
	assert_eq(box.get_phase(), EcoTextBox.Phase.HOLD)
	assert_eq(box.get_visible_text(), WELCOME)
	assert_true(box.confirm(), "La accion del jugador lo cierra")
	assert_true(get_tree().paused, "Sigue en pausa mientras se desvanece")
	_advance(box, _config.fade_out_s + 0.05)
	assert_false(box.is_showing())
	assert_false(get_tree().paused, "Se reanuda al cerrarse")
	assert_true(world.can_process())


func test_confirm_while_typing_completes_the_text_first() -> void:
	var box: EcoTextBox = _box()
	box.show_line(WELCOME, 4.0, true)
	box.advance(0.1)
	assert_true(box.confirm())
	assert_eq(box.get_visible_text(), WELCOME, "Primera pulsacion: texto completo")
	assert_eq(box.get_phase(), EcoTextBox.Phase.HOLD)
	assert_true(get_tree().paused)
	assert_true(box.confirm())
	assert_eq(box.get_phase(), EcoTextBox.Phase.CLOSING)
	get_tree().paused = false


func test_confirm_action_input_closes_it() -> void:
	var box: EcoTextBox = _box()
	box.show_line(WELCOME, 4.0, true)
	box.finish_typing()
	var press := InputEventAction.new()
	press.action = &"jump"
	press.pressed = true
	box._unhandled_input(press)
	assert_eq(box.get_phase(), EcoTextBox.Phase.CLOSING, "Espacio / A lo cierra")
	get_tree().paused = false


func test_confirm_does_nothing_on_normal_lines() -> void:
	var box: EcoTextBox = _box()
	box.show_line(WELCOME)
	box.finish_typing()
	assert_false(box.confirm())
	assert_eq(box.get_phase(), EcoTextBox.Phase.HOLD)


## Indicacion de la tecla de cierre (2026-10-15): solo en las importantes, cuando
## el texto ya se ha escrito; parpadea y va en la esquina inferior derecha.
func test_confirm_hint_only_on_typed_important_lines() -> void:
	var box: EcoTextBox = _box()
	box.show_line(WELCOME, 4.0, true)
	box.advance(0.1)
	assert_eq(box.get_phase(), EcoTextBox.Phase.TYPING)
	assert_false(box.is_confirm_hint_visible(), "Mientras se escribe no sale")
	var rect_typing: Rect2 = box.get_panel_rect()
	assert_true(box.confirm(), "La primera pulsacion completa el texto")
	assert_true(box.is_confirm_hint_visible(), "Escrito: sale la indicacion")
	assert_true(box.is_confirm_hint_lit(), "Empieza encendida")
	assert_eq(box.get_confirm_hint_text(), _config.confirm_hint_text)
	for ch: String in box.get_confirm_hint_text():
		assert_true(box.get_font().has_char(ch.unicode_at(0)), "Glifo '%s' en la fuente" % ch)
	assert_eq(box.get_panel_rect(), rect_typing, "El cuadro no cambia de tamano al salir")
	var panel: Rect2 = box.get_panel_rect()
	var hint: Rect2 = box.get_confirm_hint_rect()
	var pad: float = _config.padding_px * _config.pixel_scale
	assert_almost_eq(hint.end.x, panel.end.x - pad, EPS, "Pegada a la derecha")
	assert_almost_eq(hint.end.y, panel.end.y - pad, EPS, "Abajo")
	var body_bottom: float = panel.position.y + pad + box.get_lines().size() * hint.size.y + hint.size.y
	assert_true(hint.position.y >= body_bottom - EPS, "No tapa el texto")
	box.advance(0.5 / _config.confirm_hint_blink_hz + 0.01)
	assert_false(box.is_confirm_hint_lit(), "Parpadea")
	box.advance(0.5 / _config.confirm_hint_blink_hz)
	assert_true(box.is_confirm_hint_lit())
	assert_true(box.confirm())
	assert_false(box.is_confirm_hint_visible(), "Al cerrar se quita")
	get_tree().paused = false


func test_no_confirm_hint_on_normal_lines() -> void:
	var box: EcoTextBox = _box()
	box.show_line(WELCOME)
	box.finish_typing()
	assert_false(box.is_confirm_hint_visible())


func test_important_line_jumps_the_queue_without_losing_others() -> void:
	var box: EcoTextBox = _box()
	box.show_line("Uno.")
	box.show_line("Dos.")
	box.show_line("Tres.")
	box.show_line("Importante A.", -1.0, true)
	box.show_line("Importante B.", -1.0, true)
	assert_eq(box.get_text(), "Importante A.", "La importante sale ya")
	assert_true(get_tree().paused)
	assert_eq(box.get_queued_texts(), PackedStringArray(["Importante B.", "Uno.", "Dos.", "Tres."]),
			"La normal desplazada vuelve a la cola, delante de las demas")
	box.confirm()
	box.confirm()
	_advance(box, _config.fade_out_s + 0.05)
	assert_eq(box.get_text(), "Importante B.")
	assert_true(get_tree().paused, "Sigue en pausa entre dos importantes")
	box.confirm()
	box.confirm()
	_advance(box, _config.fade_out_s + 0.05)
	assert_eq(box.get_text(), "Uno.")
	assert_false(get_tree().paused, "Las normales ya no pausan")
	var shown: Array[String] = []
	while box.is_showing():
		if shown.is_empty() or shown[-1] != box.get_text():
			shown.append(box.get_text())
		box.advance(DT)
	assert_eq(shown, ["Uno.", "Dos.", "Tres."] as Array[String], "Ninguna se pierde")


func test_unpauses_when_box_leaves_the_tree() -> void:
	var box := BOX_SCENE.instantiate() as EcoTextBox
	add_child(box)
	box.set_process(false)
	box.show_line(WELCOME, 4.0, true)
	assert_true(get_tree().paused)
	remove_child(box)
	assert_false(get_tree().paused, "Cambio de escena o nivel quitado: se reanuda")
	box.free()


func test_does_not_unpause_a_pause_it_did_not_set() -> void:
	var box: EcoTextBox = _box()
	get_tree().paused = true
	box.show_line(WELCOME, 4.0, true)
	assert_false(box.is_pausing_game())
	box.confirm()
	box.confirm()
	_advance(box, _config.fade_out_s + 0.05)
	assert_true(get_tree().paused, "La pausa ajena se respeta")
	get_tree().paused = false


func test_event_bus_important_flag_reaches_the_box() -> void:
	var box: EcoTextBox = _box()
	EventBus.eco_line_requested.emit(WELCOME, 4.0, true)
	assert_true(box.is_important())
	assert_true(get_tree().paused)
	get_tree().paused = false


func test_level_1_1_important_lines() -> void:
	var level: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(LEVEL_PATH))
	var important: Array[String] = []
	for obj: Dictionary in level["objects"]:
		if obj["type"] == "eco_line" and bool(obj["params"].get("important", false)):
			important.append(String(obj["params"]["id"]))
	assert_eq(important, ["eco_laser"] as Array[String],
			"Solo la historia del laser: la bienvenida va en el encuentro con Eco (eco_encounter)")


# --- Aspecto y posicion ---

func test_layer_position_and_speaker() -> void:
	var box: EcoTextBox = _box()
	var hud := HUD_SCENE.instantiate() as Hud
	add_child_autofree(hud)
	box.show_line(WELCOME)
	assert_gt(box.layer, hud.layer, "Por encima del HUD")
	assert_eq(box.get_speaker_text(), "Eco")
	assert_eq(box.get_pixel_scale(), Vector2.ONE * 2.0, "Escala x2 entera")
	var rect: Rect2 = box.get_panel_rect()
	var hud_bar_bottom: float = HudConfig.shared().bar_height_px * HudConfig.shared().hud_pixel_scale
	assert_gt(rect.position.y, hud_bar_bottom, "Debajo de la barra de estado, sin taparla")
	var screen: Vector2 = box.get_viewport().get_visible_rect().size
	assert_true(Rect2(Vector2.ZERO, screen).encloses(rect), "Dentro de la pantalla")
	assert_lt(rect.end.y, screen.y * 0.25, "En la franja superior (Isak va en el centro)")
	assert_eq(fmod(rect.position.x, 2.0), 0.0, "Alineado a pixel de arte")


## Eco igual en todos los mundos (decision del usuario 2026-10-29): en el Mundo 4 el icono del cuadro es la esfera
## de siempre; por el jefe (eco_boss), su propio icono con interferencia.
func test_same_eco_icon_in_world_4() -> void:
	var level := GeneratedLevel.new()
	level.world = 4
	add_child_autofree(level)
	var box := BOX_SCENE.instantiate() as EcoTextBox
	level.add_child(box)
	box.set_process(false)
	box.show_line(WELCOME)
	assert_eq(box.get_icon_texture().resource_path, "res://assets/sprites/ui/eco_icon.png", "La esfera en el Mundo 4")
	var boss_box := BOX_SCENE.instantiate() as EcoTextBox
	level.add_child(boss_box)
	boss_box.set_process(false)
	boss_box.show_line(WELCOME, -1.0, false, &"eco_boss")
	assert_eq(boss_box.get_icon_texture().resource_path, "res://assets/sprites/bosses/eco_boss_icon.png",
		"Por el jefe, el icono de Eco con interferencia (igual en todos los mundos)")
	var plain: EcoTextBox = _box()
	plain.show_line(WELCOME)
	assert_eq(plain.get_icon_texture().resource_path, "res://assets/sprites/ui/eco_icon.png", "Fuera del Mundo 4, igual")


# --- No bloquea a Isak ni lo frena el Debug ---

func test_isak_keeps_moving_while_eco_talks() -> void:
	var sim := IsakSim.new(DT)
	var world: Node2D = sim.build_flat_world()
	add_child_autofree(world)
	var box: EcoTextBox = _box()
	sim.take_manual_control()
	await wait_physics_frames(1)
	sim.settle()
	box.show_line(WELCOME)
	var start_x: float = sim.isak.global_position.x
	sim.input.move_axis = 1.0
	sim.step(sim.frames(1.0))
	box.advance(1.0)
	assert_true(box.is_showing())
	assert_gt(sim.isak.global_position.x - start_x, 100.0, "Isak camina con Eco hablando")
	sim.input.move_axis = 0.0
	sim.input.jump_pressed = true
	sim.input.jump_held = true
	sim.step()
	assert_lt(sim.isak.velocity.y, 0.0, "y puede saltar")


func test_debug_does_not_slow_the_box() -> void:
	var box: EcoTextBox = _box()
	_activate_debug()
	assert_true(DebugMode.is_active())
	assert_almost_eq(WorldTime.scaled_delta(1.0), 0.5, 0.01, "El mundo va a x0,5")
	box.show_line(WELCOME)
	box._process(0.5)
	assert_eq(box.get_typed_count(), floori(0.5 * _config.chars_per_second), "Tiempo real")


func test_debug_does_not_slow_the_box_in_real_frames() -> void:
	var box := BOX_SCENE.instantiate() as EcoTextBox
	add_child_autofree(box)
	_activate_debug()
	assert_true(DebugMode.is_active())
	# Estable con la maquina ocupada (2026-10-16): antes se esperaba 0,5 s con
	# wait_seconds y se exigia un numero fijo de letras (20 +- 3), pero el cuadro
	# en que empieza la linea recibe el delta entero de ese cuadro (con la
	# maquina ocupada, hasta 0,1 s de antes de empezar) y salian 24. Ahora se
	# mide en la misma ejecucion el tiempo real (reloj del sistema), el delta del
	# cuadro de arranque y el cuadro mas largo, y lo escrito se compara con lo que
	# corresponde a ese tiempo real, con un margen de esos cuadros: con el Debug
	# ralentizando el cuadro saldria la MITAD (la prueba comprueba que el margen
	# lo distingue).
	await get_tree().process_frame
	await get_tree().process_frame
	var cps: float = _config.chars_per_second
	# process_frame sale antes de los _process: el cuadro recibira este delta.
	var start_frame_s: float = get_process_delta_time()
	var start_us: int = Time.get_ticks_usec()
	box.show_line(WELCOME)
	var last_us: int = start_us
	var longest_s: float = 0.0
	while Time.get_ticks_usec() - start_us < 500000:
		await get_tree().process_frame
		var now_us: int = Time.get_ticks_usec()
		longest_s = maxf(longest_s, float(now_us - last_us) / 1000000.0)
		last_us = now_us
	var elapsed_s: float = float(Time.get_ticks_usec() - start_us) / 1000000.0
	var typed: float = float(box.get_typed_count())
	var expected: float = minf(elapsed_s * cps, float(WELCOME.length()))
	var margin: float = (start_frame_s + longest_s) * cps + 1.0
	assert_lt(margin, expected * 0.5,
		"La medida distingue tiempo real de x0,5 (arranque %.3f s, cuadro mas largo %.3f s)" % [start_frame_s, longest_s])
	assert_almost_eq(typed, expected, margin,
		"Escribe a tiempo real con el Debug: %.0f letras en %.3f s (x0,5 serian %.0f)" % [typed, elapsed_s, expected * 0.5])


# --- Disparador eco_line ---

func test_trigger_fires_once_with_its_text() -> void:
	var sim := IsakSim.new(DT)
	var world: Node2D = sim.build_flat_world()
	var line := LINE_SCENE.instantiate() as EcoLine
	line.text = WELCOME
	line.width_tiles = 2
	line.height_tiles = 3
	line.position = Vector2(4.0 * T, -3.0 * T)
	world.add_child(line)
	add_child_autofree(world)
	var box: EcoTextBox = _box()
	sim.take_manual_control()
	watch_signals(line)
	watch_signals(EventBus)
	await wait_physics_frames(2)
	assert_false(line.has_fired(), "Isak empieza fuera")
	for i: int in 2:
		sim.isak.global_position = Vector2(5.0 * T, -1.0)
		await wait_physics_frames(3)
		sim.isak.global_position = Vector2(0.0, -1.0)
		await wait_physics_frames(3)
	assert_eq(line.get_fired_count(), 1, "Una sola vez")
	assert_signal_emit_count(line, "triggered", 1)
	assert_signal_emitted_with_parameters(line, "triggered", [WELCOME])
	assert_signal_emit_count(EventBus, "eco_line_requested", 1)
	assert_eq(box.get_text(), WELCOME, "El cuadro muestra el texto del disparador")
	assert_eq(box.get_queue_size(), 0)


func test_trigger_without_once_fires_each_entry() -> void:
	var sim := IsakSim.new(DT)
	var world: Node2D = sim.build_flat_world()
	var line := LINE_SCENE.instantiate() as EcoLine
	line.text = WELCOME
	line.once = false
	line.position = Vector2(4.0 * T, -3.0 * T)
	world.add_child(line)
	add_child_autofree(world)
	sim.take_manual_control()
	await wait_physics_frames(2)
	for i: int in 2:
		sim.isak.global_position = Vector2(4.5 * T, -1.0)
		await wait_physics_frames(3)
		sim.isak.global_position = Vector2(0.0, -1.0)
		await wait_physics_frames(3)
	assert_eq(line.get_fired_count(), 2)


func test_trigger_ignores_other_bodies_and_uses_player_layer() -> void:
	var line := LINE_SCENE.instantiate() as EcoLine
	add_child_autofree(line)
	assert_eq(line.collision_mask, 2, "Solo la capa player")
	assert_eq(line.collision_layer, 0)
	assert_true(line.is_in_group(EcoLine.GROUP))
	var other := StaticBody2D.new()
	add_child_autofree(other)
	line._on_body_entered(other)
	assert_false(line.has_fired())


func test_trigger_zone_size_from_tiles() -> void:
	var line := LINE_SCENE.instantiate() as EcoLine
	line.width_tiles = 6
	line.height_tiles = 6
	add_child_autofree(line)
	assert_eq(line.get_zone_rect(), Rect2(0.0, 0.0, 6.0 * T, 6.0 * T))


# --- Texto exacto del diseno ---

func test_level_1_1_welcome_opens_the_eco_encounter() -> void:
	# La bienvenida (docs 6.3 y 12.1) abre la presentacion de Eco en el encuentro (2026-10-16).
	assert_eq(String(EcoEncounter.load_data()["intro"][0]), WELCOME)
	var obj: Dictionary = _eco_line_from_level()
	assert_false(obj.is_empty(), "El 1-1 conserva un eco_line: la historia del laser")
	var line: EcoLine = _line_from_object(obj)
	add_child_autofree(line)
	assert_eq(line.object_id, &"eco_laser")
	assert_true(line.important)
	assert_true(line.once)
	assert_true(line.text.ends_with("Lo que sueltan las alertas, recógelo: es tuyo."), line.text)
	assert_eq(line.position, Vector2(174.0 * T, 4.0 * T))


func test_design_text_appears_in_test_scene() -> void:
	var scene: Node = (load(TEST_SCENE) as PackedScene).instantiate()
	var sim := IsakSim.new(DT)
	sim.attach(scene.get_node("Isak") as Isak)
	var box := scene.get_node("EcoTextBox") as EcoTextBox
	var welcome := scene.get_node("EcoBienvenida") as EcoLine
	assert_eq(welcome.text, String(EcoEncounter.load_data()["intro"][0]), "Mismo texto que el encuentro del 1-1")
	add_child_autofree(scene)
	# Isak cae al mundo dentro de la zona (fisica real).
	for i: int in 120:
		await wait_physics_frames(1)
		if box.is_showing():
			break
	assert_true(welcome.has_fired(), "Isak entra en la zona")
	assert_eq(box.get_text(), WELCOME)
	box.finish_typing()
	assert_eq(box.get_visible_text(), WELCOME, "Se lee el texto exacto")
