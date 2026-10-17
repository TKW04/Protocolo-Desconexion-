# Barra de actualizacion del 99 % (update_bar; paso 8 de docs/propuesta-1-2.md
# §10, 2026-10-16) en la sala de prueba data/levels/actualizaciones_test.json
# (escena generada scenes/levels/actualizaciones_test.tscn) con el Isak real:
# se arma al entrar en su zona, se traba en 99 % con textos que cambian, las
# oleadas se anuncian (flecha y sombra) 0,75 s antes y sueltan sus enemigos en
# paquetes, al acabar la espera los que quedan se apagan sin drops y la puerta
# se abre para siempre; si Isak reaparece antes vuelve al principio; tiempo del
# mundo (Debug x0,5, la pausa la para). La barra se avanza a mano.
extends GutTest

const IsakSim = preload("res://tests/support/isak_sim.gd")
const LEVEL_SCENE: PackedScene = preload("res://scenes/levels/actualizaciones_test.tscn")
const TILE: float = 64.0
const DT: float = 1.0 / 60.0

var _level: GeneratedLevel
var _sim: IsakSim
var _isak: Isak
var _bar: UpdateBar


func before_each() -> void:
	DebugMode.input_enabled = false
	DebugMode.reset()
	GameState.reset_progress()
	GameState.sync_rate = GameState.SYNC_RATE_MAX
	_level = LEVEL_SCENE.instantiate() as GeneratedLevel
	_sim = IsakSim.new(DT)
	_sim.attach(_level.get_node(^"Isak") as Isak)
	_isak = _sim.isak
	add_child(_level)
	_sim.take_manual_control()
	_bar = _level.get_node(^"Objects/barra_99") as UpdateBar
	_bar.set_physics_process(false)
	await wait_physics_frames(2)


func after_each() -> void:
	if is_instance_valid(_level):
		_level.free()
	get_tree().paused = false
	GameState.world_time_scale = 1.0
	DebugMode.reset()
	DebugMode.input_enabled = true
	GameState.reset_progress()
	GameState.sync_rate = GameState.SYNC_RATE_MAX


func _advance(seconds: float) -> void:
	for i: int in roundi(seconds / DT):
		_bar.advance(DT)


## Isak en la zona y la barra trabada en el 99 %.
func _arm() -> void:
	_isak.global_position = Vector2(6.5 * TILE, 11.0 * TILE)
	_bar.advance(DT)
	assert_eq(_bar.get_state(), UpdateBar.State.RISING, "Isak en la zona: se arma")
	_advance(_bar.rise_s + 0.05)
	assert_true(_bar.is_waiting())


func _drops() -> int:
	var count: int = 0
	for node: Node in _level.find_children("*", "RechargePickup", true, false):
		if not node.is_queued_for_deletion():
			count += 1
	return count


func test_scene_has_the_bar_with_its_waves() -> void:
	assert_eq(_level.level_id, "actualizaciones_test")
	assert_not_null(_bar)
	assert_eq(_bar.wait_s, 20.0, "20 s de espera (propuesta)")
	assert_eq(_bar.waves.size(), 6, "Tres oleadas de dos")
	assert_eq(_bar.get_arm_rect(), Rect2(4.0 * TILE, 1.0 * TILE, 20.0 * TILE, 10.0 * TILE))
	assert_true(_bar.is_solid())
	assert_eq(_bar.get_text(), "Instalando… 97 %")
	assert_eq(HelpCatalog.help_id_of(_bar), &"update_bar")
	assert_true(HelpCatalog.is_help_live(_bar))
	_bar.advance(DT)
	assert_eq(_bar.get_state(), UpdateBar.State.IDLE, "Fuera de la zona no se arma")


func test_stuck_at_99_with_changing_texts() -> void:
	_arm()
	assert_eq(_bar.get_percent(), 99.0)
	assert_eq(_bar.get_text(), "Instalando… 99 %")
	assert_eq(_bar.get_animation(), &"update_bar_stuck")
	_advance(6.0)
	assert_eq(_bar.get_text(), "99,9 %")
	_advance(5.0)
	assert_eq(_bar.get_text(), "Calculando tiempo restante…")
	_advance(6.0)
	assert_eq(_bar.get_text(), "Casi listo")
	assert_true(_bar.is_solid(), "Trabada, la puerta sigue cerrada")


func test_waves_are_announced_then_drop_their_enemies() -> void:
	_arm()
	var warned: Array = []
	_bar.wave_warned.connect(func(i: int) -> void: warned.append(i))
	_advance(4.0 - 0.75 - 0.1)
	assert_eq(_bar.get_warning_count(), 0, "Aun sin aviso")
	_advance(0.2)
	assert_eq(_bar.get_warning_count(), 2, "Aviso de 0,75 s (9 cuadros) antes: flecha y sombra")
	assert_eq(warned, [0, 1])
	assert_almost_eq(_bar.get_warn_s() * 12.0, 9.0, 0.001)
	_advance(0.7)
	assert_eq(_bar.get_falling_count(), 2, "Caen los paquetes")
	_advance(1.0)
	var spawned: Array[Node2D] = _bar.get_spawned()
	assert_eq(spawned.size(), 2, "Dos Burbujas")
	for e: Node2D in spawned:
		assert_true(e is AlertBubble)
		assert_almost_eq(e.global_position.y, 11.0 * TILE, 2.0, "En el suelo de la sala")
		assert_eq(HelpCatalog.help_id_of(e), &"alert_bubble", "Con su ayuda Q")
		assert_true(e.is_in_group(AlertBubble.GROUP))
	_advance(6.0)
	var badges: int = 0
	for e: Node2D in _bar.get_spawned():
		if e is NotificationBadge:
			badges += 1
	assert_eq(badges, 2, "Segunda oleada: dos puntos rojos")
	_advance(5.5)
	assert_eq(_bar.get_spawned().size(), 6, "Tercera oleada: una Burbuja y un punto rojo")
	var custom: NotificationBadge = null
	for e: Node2D in _bar.get_spawned():
		if e is NotificationBadge and is_equal_approx(e.global_position.x, 7.5 * TILE):
			custom = e
	assert_not_null(custom)
	assert_eq(custom.chase_speed_px_s, 60.0, "params de la oleada aplicados")


func test_completion_pops_the_rest_without_drops_and_opens_for_good() -> void:
	_arm()
	_advance(12.0)
	assert_eq(_bar.get_spawned().size(), 4)
	var completed: Array = []
	_bar.completed.connect(func() -> void: completed.append(true))
	_advance(8.5)
	assert_eq(completed.size(), 1, "Al 100 %")
	assert_eq(_bar.get_text(), "Reiniciando…")
	assert_eq(_bar.get_percent(), 100.0)
	for e: Node2D in _bar.get_spawned():
		assert_eq(e.call(&"get_state"), &"popped", "%s se apaga con un pop" % e.name)
	await wait_physics_frames(2)
	assert_eq(_drops(), 0, "Sin drops: no es un premio")
	_advance(2.0)
	assert_true(_bar.is_open(), "La puerta se ha recogido")
	assert_false(_bar.is_solid())
	assert_false(HelpCatalog.is_help_live(_bar), "Abierta ya no ayuda")
	EventBus.player_respawned.emit(Vector2(2.5 * TILE, 11.0 * TILE), true)
	assert_true(_bar.is_open(), "Abierta no se reinicia al reaparecer")


func test_respawn_before_opening_starts_over() -> void:
	_arm()
	_advance(10.5)
	assert_gt(_bar.get_spawned().size(), 0)
	EventBus.player_respawned.emit(Vector2(2.5 * TILE, 11.0 * TILE), true)
	await wait_physics_frames(1)
	assert_eq(_bar.get_state(), UpdateBar.State.IDLE, "Vuelve al principio")
	assert_eq(_bar.get_text(), "Instalando… 97 %")
	assert_eq(_bar.get_spawned().size(), 0, "Sin enemigos de las oleadas")
	assert_eq(_bar.get_warning_count() + _bar.get_falling_count(), 0, "Sin avisos ni paquetes")
	assert_true(_bar.is_solid())
	_isak.global_position = Vector2(2.5 * TILE, 11.0 * TILE)
	_bar.advance(DT)
	assert_eq(_bar.get_state(), UpdateBar.State.IDLE, "Fuera de la zona, espera")
	_arm()


func test_wait_runs_in_world_time() -> void:
	_arm()
	GameState.world_time_scale = 0.5
	for i: int in 120:
		_bar._physics_process(DT)
	GameState.world_time_scale = 1.0
	assert_almost_eq(_bar.get_wait_elapsed(), 1.0, 0.05, "Con el Debug, 2 s reales = 1 s de espera")
	var elapsed: float = _bar.get_wait_elapsed()
	_bar.set_physics_process(true)
	get_tree().paused = true
	await wait_physics_frames(10)
	assert_almost_eq(_bar.get_wait_elapsed(), elapsed, 0.0001, "En pausa no avanza")
	get_tree().paused = false
	_bar.set_physics_process(false)


## Ayudas Q y textos de interfaz de los pisos 3 y 4: Eco breve y sin nombres de vueltas.
func test_help_texts_and_ui_texts_without_banned_words() -> void:
	var texts: Array[String] = []
	for id: StringName in [&"reminder_platform", &"snooze_button", &"overlay_popup", &"update_bar"]:
		assert_true(HelpCatalog.shared().has(id), "Ayuda de %s" % id)
		assert_eq(HelpCatalog.shared().world(id), 1)
		var text: String = HelpCatalog.shared().text(id)
		assert_between(text.length(), 20, 170, "%s: breve" % id)
		texts.append(text)
		texts.append(HelpCatalog.shared().title(id))
	var ui: Dictionary = World1ObjectsConfig.section("update_bar")["texts"]
	texts.append(String(ui["installing"]))
	texts.append(String(ui["done"]))
	for entry: Variant in ui["stuck"]:
		texts.append(String(entry[1]))
	for level: String in ["recordatorios_test", "overlay_test", "actualizaciones_test"]:
		var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/levels/%s.json" % level))
		for o: Variant in data["objects"]:
			texts.append(String((o as Dictionary)["params"].get("text", "")))
	for text: String in texts:
		for banned: String in ["Vuelta", "vuelta", "Easy", "Normal", "Hard"]:
			assert_false(text.contains(banned), "«%s» sin %s" % [text, banned])
