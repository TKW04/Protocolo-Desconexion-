# Calc en el hub real (CalcStation + CalcPanel; paso 8 de
# docs/propuesta-hub-y-guardado.md §6.2): de pie en el dock, conocida y
# despierta (animacion awake desde la tanda H3 del encuentro, 2026-10-17; antes
# dormida), sin voz y sin hablar fuera de su encuentro (tests/test_calc_intro.gd); el pulso abre la tienda con Isak de espaldas;
# tienda por pistas (tanda M1, 2026-10-17): una fila por pista con su chip y 5
# recuadros (lleno, siguiente, vacio, candado por acceso, «Proximamente», «?»),
# saldo de puntos y power banks; arriba y abajo eligen (detalle del SIGUIENTE
# nivel con nombre, descripcion, coste y que falta); el pulso compra con
# GameState.purchase_upgrade y el recuadro nuevo se carga;
# comprar solo marca «sin guardar» (nada se escribe); salto cierra.
# Usa su propia ruta de guardado (nunca user://save.json).
extends GutTest

const EcoProgress = preload("res://tests/support/eco_progress.gd")

const HUB_SCENE: PackedScene = preload("res://scenes/hub/hub.tscn")
const PATH: String = "user://test_calc_station.json"
const T: float = 64.0
const EPS: float = 0.001

var _hub: HubRoom
var _calc: CalcStation
var _panel: CalcPanel
var _isak: Isak
var _saved_path: String
var _saved_level: StringName
var _saved_pulse: bool


func before_each() -> void:
	_saved_path = GameState.save_path
	_saved_level = GameState.current_level
	_saved_pulse = GameState.is_ability_unlocked(GameState.ABILITY_PULSE)
	GameState.use_save_path(PATH, true)
	EcoProgress.meet_eco_with_pulse()
	EcoProgress.meet_notas()
	EcoProgress.meet_calc()
	_hub = HUB_SCENE.instantiate() as HubRoom
	add_child(_hub)
	var vortex: WarpVortex = _hub.get_arrival_vortex()
	if vortex != null:
		vortex.advance(5.0)
	_isak = _hub.get_isak()
	_isak.input = PlayerInput.new()
	_calc = _hub.get_calc()
	_panel = _calc.get_calc_panel() if _calc != null else null


func after_each() -> void:
	if is_instance_valid(_hub):
		_hub.free()
	SaveFile.delete(PATH)
	GameState.reset_progress()
	GameState.save_path = _saved_path
	GameState.current_level = _saved_level
	GameState.set_ability_unlocked(GameState.ABILITY_PULSE, _saved_pulse)
	GameState.set_ability_unlocked(GameState.ABILITY_LASER, false)
	GameState.set_ability_unlocked(GameState.ABILITY_DEBUG, false)
	GameState.sync_rate = GameState.SYNC_RATE_MAX
	GameState.debug_energy = GameState.DEBUG_ENERGY_MAX


func _action(name: StringName) -> InputEventAction:
	var event := InputEventAction.new()
	event.action = name
	event.pressed = true
	return event


func _open() -> void:
	assert_true(_calc.open(_isak), "Se abre")
	_panel.skip_input_delay()


func test_calc_is_an_awake_station_on_the_dock() -> void:
	assert_not_null(_calc, "Calc es una estacion del hub")
	assert_eq(_calc.station_id, &"calc")
	assert_null(_hub.get_dormant(&"calc"), "Ya no es un hueco sin logica")
	assert_eq(_calc.position.x, 7.0 * T, "Columna 7 del dock")
	assert_eq(_calc.position.y + _calc.get_size().y, _hub.get_floor_y(), "Apoyada en el dock")
	var sprite := _calc.get_visual() as AnimatedSprite2D
	assert_not_null(sprite, "Arte final (calc_frames)")
	assert_eq(_calc.get_calc_animation(), &"awake", "Despierta")
	assert_true(sprite.is_playing())
	var height: float = sprite.sprite_frames.get_frame_texture(&"awake", 0).get_size().y
	assert_almost_eq(_calc.position.y + sprite.position.y + height, _hub.get_floor_y(), 0.5, "Pies en el dock")
	assert_eq(sprite.scale, Vector2.ONE, "Sin escalar")
	assert_true(_calc.is_powered(), "Encendida: Calc conocida")
	assert_false(_hub.get_text_box().is_showing(), "Calc no habla")


func test_calc_is_powered_off_until_met() -> void:
	_hub.free()
	GameState.allies_met.erase(GameState.ALLY_CALC)
	_hub = HUB_SCENE.instantiate() as HubRoom
	add_child(_hub)
	_hub.get_arrival_vortex().advance(5.0)
	_isak = _hub.get_isak()
	_isak.input = PlayerInput.new()
	_calc = _hub.get_calc()
	assert_false(_calc.is_powered(), "Apagada sin conocer a Calc")
	assert_eq(_calc.get_calc_animation(), &"powered_off", "Pantalla negra, sin animacion")
	_isak.global_position = Vector2(6.6 * T, _hub.get_floor_y())
	_isak.facing = 1.0
	await wait_physics_frames(6)
	_calc.advance(0.1)
	assert_false(_calc.is_key_hint_visible(), "Sin tecla del pulso")
	_isak.set_pulse_area_active(true)
	await wait_physics_frames(2)
	assert_false(_calc.is_panel_open(), "El pulso no abre la tienda")
	assert_false(_calc.open(_isak), "No hay tienda")
	_isak.set_pulse_area_active(false)
	assert_true(GameState.meet_ally(GameState.ALLY_CALC), "Encuentro (helper)")
	assert_true(_calc.is_powered(), "Se enciende al momento")
	assert_eq(_calc.get_calc_animation(), &"awake")
	_calc.advance(0.1)
	assert_true(_calc.is_key_hint_visible(), "Ya sale la tecla")
	assert_true(_calc.open(_isak), "Ya vende")
	_calc.close(true)


func test_pulse_near_calc_opens_the_shop_with_isak_facing_back() -> void:
	_isak.global_position = Vector2(6.6 * T, _hub.get_floor_y())
	_isak.facing = 1.0
	await wait_physics_frames(6)
	_calc.advance(0.1)
	assert_true(_calc.is_key_hint_visible(), "Tecla del pulso junto a Calc")
	assert_eq(_calc.get_calc_animation(), &"awake", "Con el prompt no cambia")
	_isak.set_pulse_area_active(true)
	await wait_physics_frames(2)
	assert_true(_calc.is_panel_open(), "El pulso abre la tienda")
	assert_true(_isak.is_facing_back(), "Isak de espaldas")
	assert_false(_hub.get_station(&"notas").is_panel_open(), "Solo la de Calc")
	_panel.skip_input_delay()
	_panel._unhandled_input(_action(&"jump"))
	await wait_physics_frames(4)
	assert_false(_calc.is_panel_open(), "Salto cierra")
	assert_false(_isak.is_facing_back(), "Recupera el control")


func _obtain(ability: StringName) -> void:
	GameState.obtained_abilities[ability] = true
	GameState.set_ability_unlocked(ability, true)


## Todos los textos que se ven en el panel (titulo, lineas, filas, detalle, mensaje).
func _panel_texts() -> PackedStringArray:
	var out: PackedStringArray = [_panel.get_title(), _panel.get_message(), _panel.get_help()]
	out.append_array(_panel.get_lines())
	out.append_array(_panel.get_detail_lines())
	for track: StringName in _panel.get_track_ids():
		out.append(_panel.track_name(track))
	return out


func _assert_no_lap_words() -> void:
	var regex := RegEx.create_from_string("(?i)\\b(vuelta|vueltas|easy|normal|hard)\\b")
	for text: String in _panel_texts():
		assert_null(regex.search(text), "Sin palabras de vuelta: «%s»" % text)


func test_shop_rows_chips_boxes_and_next_level_detail() -> void:
	_obtain(GameState.ABILITY_LASER)
	GameState.attention_points = 30
	_open()
	assert_eq(_panel.get_title(), "Calc - Mejoras")
	assert_eq(_panel.get_track_ids(), [&"pulso", &"laser", &"debug", &"sync", &"energia"] as Array[StringName])
	assert_eq(_panel.get_option_ids(), _panel.get_track_ids(), "Una fila por pista")
	var lines: PackedStringArray = _panel.get_lines()
	assert_eq(lines[0], "◆ 30 puntos de atención", "Saldo con el icono")
	assert_eq(lines[1], "Power banks: 0 (encontrados 0, gastados 0)")
	assert_eq(lines[2], "Todo guardado")
	assert_eq([_panel.track_name(&"pulso"), _panel.track_name(&"laser"), _panel.track_name(&"debug"),
		_panel.track_name(&"sync"), _panel.track_name(&"energia")], ["Pulso", "Láser", "???", "Sync Rate", "Energía"])
	# Recuadros: el 1 lleno, el siguiente late, el 3 vacio y el 4-5 con candado (Cache).
	assert_eq(_panel.box_states(&"pulso"), [&"full", &"next", &"empty", &"locked", &"locked"] as Array[StringName])
	assert_eq(_panel.filled_count(&"pulso"), 1, "El primero activo (nivel 1 gratis)")
	assert_true(_panel.get_box_frame(&"pulso", 1) in ["next_a", "next_b"], "El siguiente late")
	assert_eq(_panel.get_box_frame(&"pulso", 3), "locked")
	# Debug sin obtener: chip «?» y recuadros grises.
	assert_eq(_panel.box_states(&"debug"), [&"unknown", &"unknown", &"unknown", &"unknown", &"unknown"] as Array[StringName])
	assert_eq(_panel.get_chip_frame(&"debug"), "unknown")
	assert_eq(_panel.get_chip_frame(&"pulso"), "pulse_selected", "Elegida: marco cian")
	assert_eq(_panel.get_chip_frame(&"laser"), "laser")
	assert_true((_panel.get_row_nodes(&"pulso")["chip"] as TextureRect).visible)
	# Detalle del SIGUIENTE nivel: nombre, descripcion, coste y estado.
	assert_eq(_panel.get_detail_lines(), PackedStringArray(["Pulso - Nivel 1 de 5",
		"Siguiente, nivel 2: Pulso amplio", "Más alcance: radio del pulso de 96 px a 112 px.",
		"Coste: 25 puntos", "Disponible"]))
	_panel._unhandled_input(_action(&"move_down"))
	assert_eq(_panel.get_selected_track(), &"laser")
	assert_eq(_panel.get_chip_frame(&"laser"), "laser_selected")
	assert_eq(_panel.get_detail_lines()[1], "Siguiente, nivel 2: Láser rápido", "El detalle sigue a la eleccion")
	assert_eq(_panel.get_detail_lines()[3], "Coste: 15 puntos")
	_panel._unhandled_input(_action(&"move_down"))
	assert_eq(_panel.get_detail_lines(), PackedStringArray(["???", "Aún no tienes esta habilidad."]),
		"Chip «?»: sin nombre ni efecto")
	_panel._unhandled_input(_action(&"pulse"))
	assert_eq(_panel.get_message(), "Aún no tienes esta habilidad.")
	assert_eq(GameState.attention_points, 30)
	_panel._unhandled_input(_action(&"move_down"))
	assert_eq(_panel.get_detail_lines()[1], "Siguiente, nivel 2: Sync reforzado")
	_panel._unhandled_input(_action(&"move_down"))
	_panel._unhandled_input(_action(&"move_down"))
	assert_eq(_panel.get_selected_track(), &"pulso", "Da la vuelta a la lista")
	var rect: Rect2 = _panel.get_panel_rect()
	assert_lte(rect.end.y, 720.0, "Cabe en pantalla")
	assert_lte(rect.end.x, 1280.0)
	assert_gte(rect.position.x, 0.0)
	_assert_no_lap_words()


func test_buying_fills_the_next_box_and_only_marks_unsaved() -> void:
	GameState.attention_points = 30
	_open()
	_panel._unhandled_input(_action(&"pulse"))
	assert_eq(GameState.get_upgrade_level(&"pulso"), 2, "Pulso compra el siguiente nivel")
	assert_eq(GameState.attention_points, 5)
	assert_almost_eq(GameState.effective_value(&"isak_abilities.pulse_radius_px", 96.0), 112.0, EPS,
		"Pulso amplio: radio 112")
	assert_eq(_panel.get_message(), "Nivel 2 instalado: Pulso amplio.")
	assert_eq(_panel.filled_count(&"pulso"), 2, "2 de 5 recuadros cargados")
	assert_true(_panel.is_buy_animating(), "El recuadro nuevo se carga")
	assert_true(_panel.get_box_frame(&"pulso", 1).begins_with("fill_"), "Animacion de carga")
	_panel.advance_for_tests(0.25)
	assert_true(_panel.get_box_frame(&"pulso", 1) in ["fill_3", "flash"])
	_panel.finish_buy_animation()
	assert_eq(_panel.get_box_frame(&"pulso", 1), "full")
	assert_eq(_panel.get_lines()[0], "◆ 5 puntos de atención", "Saldo actualizado")
	assert_eq(_panel.get_lines()[2], "Sin guardar")
	assert_eq(_panel.get_detail_lines()[0], "Pulso - Nivel 2 de 5")
	assert_eq(_panel.get_detail_lines()[1], "Siguiente, nivel 3: Pulso aturdidor")
	assert_eq(_panel.get_detail_lines()[3], "Coste: 15 puntos")
	assert_eq(_panel.get_detail_lines()[4], "Faltan 10 puntos", "Que falta")
	assert_true(GameState.has_unsaved_changes(), "Comprar marca sin guardar")
	assert_false(FileAccess.file_exists(PATH), "Comprar no guarda (guardado manual)")
	assert_true(_hub.get_hud().is_unsaved_indicator_shown(), "El HUD del hub dice «Sin guardar»")
	_panel._unhandled_input(_action(&"pulse"))
	assert_eq(_panel.get_message(), "Faltan 10 puntos.")
	assert_eq(GameState.attention_points, 5, "No cobra")
	assert_eq(GameState.get_upgrade_level(&"pulso"), 2)


func test_access_locks_and_max_level() -> void:
	_obtain(GameState.ABILITY_LASER)
	GameState.attention_points = 100
	GameState.upgrade_levels[&"pulso"] = 3
	GameState.upgrade_levels[&"sync"] = 5
	_open()
	# Cache: el nivel 4 pide Kernel (candado y texto de acceso, sin la palabra vuelta).
	assert_eq(_panel.box_states(&"pulso"), [&"full", &"full", &"full", &"locked", &"locked"] as Array[StringName])
	assert_eq(_panel.get_detail_lines()[1], "Siguiente, nivel 4: Ocultarte")
	assert_eq(_panel.get_detail_lines()[4], "Requiere acceso Kernel")
	_panel._unhandled_input(_action(&"pulse"))
	assert_eq(_panel.get_message(), "Disponible con acceso Kernel.")
	assert_eq(GameState.get_upgrade_level(&"pulso"), 3)
	_assert_no_lap_words()
	# Kernel: el 4 del Pulso (Ocultarte, tanda M2) ya se compra (sin «Próximamente»).
	GameState.lap = GameState.LAP_NORMAL
	_panel.refresh()
	assert_eq(_panel.box_states(&"pulso"), [&"full", &"full", &"full", &"next", &"locked"] as Array[StringName])
	assert_eq(_panel.get_detail_lines()[4], "Disponible")
	_panel._unhandled_input(_action(&"pulse"))
	assert_eq(_panel.get_message(), "Nivel 4 instalado: Ocultarte.")
	assert_eq(GameState.get_upgrade_level(&"pulso"), 4)
	assert_eq(GameState.attention_points, 75)
	# El 5 del Laser pide Raiz y un power bank.
	GameState.upgrade_levels[&"laser"] = 4
	_panel.select_option(&"laser")
	assert_eq(_panel.get_detail_lines()[4], "Requiere acceso Raíz")
	assert_eq(_panel.get_detail_lines()[3], "Coste: 25 puntos + 1 power bank", "El nivel 5 pide un power bank")
	_assert_no_lap_words()
	# Debug 3 (revelado persistente) ya se compra en Cache.
	GameState.lap = GameState.LAP_EASY
	_obtain(GameState.ABILITY_DEBUG)
	GameState.upgrade_levels[&"debug"] = 2
	_panel.refresh()
	assert_eq(_panel.box_states(&"debug"), [&"full", &"full", &"next", &"locked", &"locked"] as Array[StringName])
	# Nivel maximo: 5 de 5.
	_panel.select_option(&"sync")
	assert_eq(_panel.box_states(&"sync"), [&"full", &"full", &"full", &"full", &"full"] as Array[StringName])
	assert_eq(_panel.get_detail_lines()[1], "Nivel máximo")
	_panel._unhandled_input(_action(&"pulse"))
	assert_eq(_panel.get_message(), "Esta mejora está completa.")


func test_no_level_is_coming_soon_anymore() -> void:
	_obtain(GameState.ABILITY_LASER)
	_obtain(GameState.ABILITY_DEBUG)
	_open()
	for lap: int in [GameState.LAP_EASY, GameState.LAP_NORMAL, GameState.LAP_HARD]:
		GameState.lap = lap
		for owned: int in range(1, 6):
			for track: StringName in [&"pulso", &"laser", &"debug", &"sync", &"energia"]:
				GameState.upgrade_levels[track] = owned
			_panel.refresh()
			for track: StringName in [&"pulso", &"laser", &"debug", &"sync", &"energia"]:
				assert_false(_panel.box_states(track).has(&"soon"), "Sin «Próximamente»: %s %d (acceso %d)" % [
					track, owned, lap])
				_panel.select_option(track)
				assert_false("\n".join(_panel.get_detail_lines()).contains("Próximamente"))


func test_level_5_in_root_needs_and_spends_a_power_bank() -> void:
	GameState.lap = GameState.LAP_HARD
	GameState.attention_points = 30
	GameState.upgrade_levels[&"energia"] = 4
	_open()
	_panel.select_option(&"energia")
	assert_eq(_panel.box_states(&"energia"), [&"full", &"full", &"full", &"full", &"next"] as Array[StringName])
	assert_eq(_panel.get_detail_lines()[4], "Falta un power bank completo")
	GameState.power_banks = 1
	_panel.refresh()
	assert_eq(_panel.get_detail_lines()[4], "Disponible")
	_panel._unhandled_input(_action(&"pulse"))
	assert_eq(_panel.get_message(), "Nivel 5 instalado: Recarga pasiva.")
	assert_eq(GameState.power_banks, 0, "El power bank se gasta")
	assert_eq(_panel.power_banks_text(), "Power banks: 0 (encontrados 1, gastados 1)")
	assert_eq(GameState.attention_points, 5)
	assert_eq(GameState.get_upgrade_level(&"energia"), 5)


func test_soon_state_still_works_for_future_levels() -> void:
	# La tienda conserva «Próximamente» para niveles futuros sin efecto (implemented false).
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(UpgradeCatalog.DEFAULT_PATH))
	data["tracks"][3]["levels"][1]["implemented"] = false
	UpgradeCatalog.set_shared(UpgradeCatalog.from_dict(data))
	_open()
	_panel.select_option(&"sync")
	assert_eq(_panel.box_states(&"sync")[1], &"soon")
	assert_eq(_panel.get_detail_lines()[4], "Próximamente")
	UpgradeCatalog.set_shared(null)


func test_debug_chip_unknown_until_obtained() -> void:
	_open()
	assert_eq(_panel.track_name(&"debug"), "???")
	assert_eq(_panel.get_chip_frame(&"debug"), "unknown")
	_obtain(GameState.ABILITY_DEBUG)
	_panel.refresh()
	assert_eq(_panel.track_name(&"debug"), "Debug")
	assert_eq(_panel.get_chip_frame(&"debug"), "debug")
	assert_eq(_panel.box_states(&"debug")[1], &"next")


func test_no_points_shows_what_is_missing() -> void:
	GameState.attention_points = 10
	_open()
	assert_eq(_panel.get_detail_lines()[4], "Faltan 15 puntos")
	_panel._unhandled_input(_action(&"pulse"))
	assert_eq(_panel.get_message(), "Faltan 15 puntos.")
	assert_eq(GameState.attention_points, 10)
	assert_false(GameState.has_unsaved_changes(), "Sin compra no hay cambios")
	_panel.select_option(&"sync")
	_panel._unhandled_input(_action(&"pulse"))
	assert_eq(_panel.get_message(), "Faltan 5 puntos.")


func test_input_waits_for_the_panel_delay() -> void:
	GameState.attention_points = 30
	assert_true(_calc.open(_isak))
	_panel._unhandled_input(_action(&"pulse"))
	assert_false(GameState.is_upgrade_purchased(&"wide_pulse"), "El pulso que abre no compra")
