# Reloj del HUD (C8; decision 10 de docs/propuesta-mundo-2.md, aprobada el
# 2026-10-22; paso 8 de su §8): HudClock en el hueco ClockSlot. Oculto en el
# Mundo 1 y en el hub, visible desde el Mundo 2 con 17:04; avanza despacio en
# tiempo real; salta +1 h al tocar el borde del scroll y en cada repeticion de un
# bucle; solo visual (no toca Sync Rate, energia ni el guardado).
extends GutTest

const HUD_SCENE: PackedScene = preload("res://scenes/ui/hud.tscn")

var _saved_world: int


func before_each() -> void:
	_saved_world = GameState.current_world
	GameState.current_world = GameState.FIRST_WORLD


func after_each() -> void:
	GameState.current_world = _saved_world


func _hud() -> Hud:
	var hud := add_child_autofree(HUD_SCENE.instantiate()) as Hud
	await wait_process_frames(1)
	hud.get_clock().set_process(false)
	return hud


func _slot(hud: Hud) -> Label:
	return hud.get_node(^"Frame/ClockSlot") as Label


func test_config_section() -> void:
	var c: Dictionary = HudConfig.shared().clock
	assert_eq(int(c.get("from_world", 0)), 2, "Desde el Mundo 2")
	assert_eq(int(c.get("start_minutes", 0)), 17 * 60 + 4, "Domingo por la tarde: 17:04")
	assert_eq(int(c.get("skip_minutes", 0)), 60, "+1 h")
	assert_true(String(c.get("_notes", "")).contains("SOLO VISUAL"))
	for glyph: String in "0123456789:":
		assert_true(HudConfig.shared().font_glyphs.contains(glyph), "La fuente del HUD tiene «%s»" % glyph)


func test_hidden_in_world_1_and_shown_from_world_2() -> void:
	var hud: Hud = await _hud()
	var clock: HudClock = hud.get_clock()
	assert_false(clock.is_shown(), "Mundo 1: sin reloj")
	assert_false(_slot(hud).visible)
	GameState.current_world = 2
	assert_true(clock.is_shown(), "Mundo 2: reloj a la vista")
	assert_true(_slot(hud).visible)
	assert_eq(_slot(hud).text, "17:04")
	GameState.current_world = 3
	assert_true(_slot(hud).visible, "Y en los mundos siguientes")


func test_hidden_in_the_hub() -> void:
	GameState.current_world = 2
	var hud: Hud = await _hud()
	assert_true(_slot(hud).visible)
	hud.enable_hub_mode(HubData.section("hud"))
	assert_false(_slot(hud).visible, "En el hub no hay reloj")
	EventBus.scroll_edge_hit.emit(true)
	assert_eq(hud.get_clock().get_skips(), 0, "Ni salta")


func test_advances_slowly_in_real_time() -> void:
	GameState.current_world = 2
	var hud: Hud = await _hud()
	var clock: HudClock = hud.get_clock()
	clock.advance(59.0)
	assert_eq(clock.get_text(), "17:04", "Menos de un minuto")
	clock.advance(1.5)
	assert_eq(clock.get_text(), "17:05", "Un minuto por minuto: parece normal")
	assert_eq(_slot(hud).text, "17:05")


func test_jumps_one_hour_on_the_scroll_edge_and_on_each_loop() -> void:
	GameState.current_world = 2
	var hud: Hud = await _hud()
	var clock: HudClock = hud.get_clock()
	var sync: float = GameState.sync_rate
	var energy: float = GameState.debug_energy
	var unsaved: bool = GameState.has_unsaved_changes()
	watch_signals(clock)
	EventBus.scroll_edge_hit.emit(true)
	assert_eq(_slot(hud).text, "18:04", "Tocar el borde: +1 h de golpe")
	assert_signal_emitted_with_parameters(clock, "skipped", ["18:04", 1])
	assert_true(clock.is_flashing(), "Destello")
	EventBus.scroll_edge_hit.emit(false)
	assert_eq(_slot(hud).text, "19:04", "Cada contacto (tambien en la invulnerabilidad)")
	EventBus.loop_wrapped.emit(&"bucle_prueba", 1)
	assert_eq(_slot(hud).text, "20:04", "Cada repeticion de un bucle: +1 h")
	EventBus.loop_wrapped.emit(&"bucle_prueba", 2)
	assert_eq(clock.get_skips(), 4)
	assert_eq(_slot(hud).text, "21:04")
	clock.advance(1.0)
	assert_false(clock.is_flashing(), "El destello se apaga")
	assert_eq(_slot(hud).scale, Vector2.ONE)
	assert_eq(GameState.sync_rate, sync, "Solo visual: no quita Sync Rate")
	assert_eq(GameState.debug_energy, energy, "Ni energia")
	assert_eq(GameState.has_unsaved_changes(), unsaved, "Ni toca el guardado")


func test_no_jumps_in_world_1() -> void:
	var hud: Hud = await _hud()
	EventBus.scroll_edge_hit.emit(true)
	EventBus.loop_wrapped.emit(&"bucle_prueba", 1)
	assert_eq(hud.get_clock().get_skips(), 0, "Sin reloj, sin saltos")


func test_wraps_past_midnight() -> void:
	GameState.current_world = 2
	var hud: Hud = await _hud()
	var clock: HudClock = hud.get_clock()
	for i: int in 7:
		clock.skip()
	assert_eq(clock.get_text(), "00:04", "Da la vuelta a las 24 h")


func test_a_new_level_starts_again_at_17_04() -> void:
	GameState.current_world = 2
	var first: Hud = await _hud()
	first.get_clock().skip()
	assert_eq(first.get_clock().get_text(), "18:04")
	var second: Hud = await _hud()
	assert_eq(second.get_clock().get_text(), "17:04", "El HUD de cada nivel empieza en 17:04")
