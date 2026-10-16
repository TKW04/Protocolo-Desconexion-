# Calc dormida en el hub real (CalcStation + CalcPanel; paso 8 de
# docs/propuesta-hub-y-guardado.md §6.2): de pie en el dock con su animacion
# dormida, sin voz ni dialogo; el pulso abre la tienda con Isak de espaldas;
# lista de mejoras con coste y estado, saldo de puntos y power banks; arriba y
# abajo eligen (con el detalle de la elegida); el pulso compra con las mismas
# reglas que GameState.purchase_upgrade; falta de puntos o de power bank;
# comprar solo marca «sin guardar» (nada se escribe); salto cierra.
# Usa su propia ruta de guardado (nunca user://save.json).
extends GutTest

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


func test_calc_is_a_sleeping_station_on_the_dock() -> void:
	assert_not_null(_calc, "Calc es una estacion del hub")
	assert_eq(_calc.station_id, &"calc")
	assert_null(_hub.get_dormant(&"calc"), "Ya no es un hueco sin logica")
	assert_eq(_calc.position.x, 7.0 * T, "Columna 7 del dock")
	assert_eq(_calc.position.y + _calc.get_size().y, _hub.get_floor_y(), "Apoyada en el dock")
	var sprite := _calc.get_visual() as AnimatedSprite2D
	assert_not_null(sprite, "Arte final (calc_frames)")
	assert_eq(_calc.get_calc_animation(), &"sleep", "Dormida")
	assert_true(sprite.is_playing())
	var height: float = sprite.sprite_frames.get_frame_texture(&"sleep", 0).get_size().y
	assert_almost_eq(_calc.position.y + sprite.position.y + height, _hub.get_floor_y(), 0.5, "Pies en el dock")
	assert_eq(sprite.scale, Vector2.ONE, "Sin escalar")
	assert_null(_hub.get_node_or_null(^"EcoTextBox"), "En el hub no hay cuadro de Eco: Calc no habla")


func test_pulse_near_calc_opens_the_shop_with_isak_facing_back() -> void:
	_isak.global_position = Vector2(6.6 * T, _hub.get_floor_y())
	_isak.facing = 1.0
	await wait_physics_frames(6)
	_calc.advance(0.1)
	assert_true(_calc.is_key_hint_visible(), "Tecla del pulso junto a Calc")
	assert_eq(_calc.get_calc_animation(), &"sleep", "Con el prompt sigue dormida")
	_isak.set_pulse_area_active(true)
	await wait_physics_frames(2)
	assert_true(_calc.is_panel_open(), "El pulso abre la tienda")
	assert_true(_isak.is_facing_back(), "Isak de espaldas")
	assert_false(_hub.get_station(&"copia_local").is_panel_open(), "Solo la de Calc")
	_panel.skip_input_delay()
	_panel._unhandled_input(_action(&"jump"))
	await wait_physics_frames(4)
	assert_false(_calc.is_panel_open(), "Salto cierra")
	assert_false(_isak.is_facing_back(), "Recupera el control")


func test_shop_lists_upgrades_points_and_power_banks() -> void:
	GameState.attention_points = 30
	_open()
	assert_eq(_panel.get_title(), "Calc - Mejoras")
	assert_eq(_panel.get_upgrade_ids().size(), UpgradeCatalog.shared().entries().size(), "Todas las mejoras")
	assert_eq(_panel.get_option_ids(), _panel.get_upgrade_ids(), "Una opcion por mejora")
	var lines: PackedStringArray = _panel.get_lines()
	assert_eq(lines[0], "Puntos de atención: 30", "Saldo")
	assert_eq(lines[1], "Power banks: 0 (carga 0/%d)" % roundi(GameState.get_power_bank_capacity()))
	assert_eq(lines[2], "Todo guardado")
	assert_eq(_panel.upgrade_text(&"wide_pulse"), "Pulso amplio - 25 pts - Disponible")
	assert_eq(_panel.upgrade_text(&"reinforced_sync"), "Sync reforzado - 45 pts + 1 power bank - Faltan puntos")
	assert_eq(_panel.get_detail(), "Radio del pulso: 96 px a 112 px", "Detalle de la elegida")
	_panel._unhandled_input(_action(&"move_down"))
	assert_eq(_panel.get_selected_upgrade(), &"reinforced_sync")
	assert_eq(_panel.get_detail(), "Sync Rate máximo: 100 % a 120 %", "El detalle sigue a la eleccion")
	_panel._unhandled_input(_action(&"move_up"))
	assert_eq(_panel.get_selected_upgrade(), &"wide_pulse")
	var rect: Rect2 = _panel.get_panel_rect()
	assert_lte(rect.end.y, 720.0, "Cabe en pantalla")
	assert_lte(rect.end.x, 1280.0)


func test_buying_with_the_pulse_spends_points_and_only_marks_unsaved() -> void:
	GameState.attention_points = 30
	_open()
	_panel._unhandled_input(_action(&"pulse"))
	assert_true(GameState.is_upgrade_purchased(&"wide_pulse"), "Pulso compra la elegida")
	assert_eq(GameState.attention_points, 5)
	assert_almost_eq(GameState.effective_value(&"isak_abilities.pulse_radius_px", 96.0), 112.0, EPS,
		"Mismo efecto que antes: radio del pulso 112")
	assert_eq(_panel.get_message(), "Comprada: Pulso amplio")
	assert_eq(_panel.get_lines()[0], "Puntos de atención: 5", "Saldo actualizado")
	assert_eq(_panel.get_lines()[2], "Sin guardar")
	assert_eq(_panel.upgrade_text(&"wide_pulse"), "Pulso amplio - 25 pts - Comprada")
	assert_true(GameState.has_unsaved_changes(), "Comprar marca sin guardar")
	assert_false(FileAccess.file_exists(PATH), "Comprar no guarda (guardado manual)")
	assert_true(_hub.get_hud().is_unsaved_indicator_shown(), "El HUD del hub dice «Sin guardar»")
	_panel._unhandled_input(_action(&"pulse"))
	assert_eq(_panel.get_message(), "Ya la tienes")
	assert_eq(GameState.attention_points, 5, "No cobra dos veces")


func test_not_enough_points_or_power_bank_does_not_buy() -> void:
	GameState.attention_points = 10
	_open()
	_panel._unhandled_input(_action(&"pulse"))
	assert_false(GameState.is_upgrade_purchased(&"wide_pulse"))
	assert_eq(_panel.get_message(), "No tienes puntos suficientes")
	assert_eq(GameState.attention_points, 10)
	assert_false(GameState.has_unsaved_changes(), "Sin compra no hay cambios")
	GameState.attention_points = 100
	_panel.refresh()
	assert_true(_panel.select_option(&"reinforced_sync"))
	_panel._unhandled_input(_action(&"pulse"))
	assert_false(GameState.is_upgrade_purchased(&"reinforced_sync"), "Hace falta un power bank completo")
	assert_eq(_panel.get_message(), "Necesitas un power bank completo")
	assert_eq(_panel.upgrade_text(&"reinforced_sync"), "Sync reforzado - 45 pts + 1 power bank - Falta power bank")
	GameState.power_banks = 1
	_panel._unhandled_input(_action(&"pulse"))
	assert_true(GameState.is_upgrade_purchased(&"reinforced_sync"))
	assert_eq(GameState.power_banks, 0, "Gasta el power bank")
	assert_eq(GameState.attention_points, 55)


func test_input_waits_for_the_panel_delay() -> void:
	GameState.attention_points = 30
	assert_true(_calc.open(_isak))
	_panel._unhandled_input(_action(&"pulse"))
	assert_false(GameState.is_upgrade_purchased(&"wide_pulse"), "El pulso que abre no compra")
