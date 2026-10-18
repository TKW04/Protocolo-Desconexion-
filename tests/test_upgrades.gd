# Mejoras de Calc POR PISTAS (tanda M1 de docs/propuesta-mejoras.md, 2026-10-17):
# catalogo valido (cinco pistas de 5 niveles, 90 puntos por pista, Pulso
# 25/15/25/25, tope por acceso Cache 3 / Kernel 4 / Raiz 5, todos los niveles
# con efecto desde la tanda M2), compras (puntos, power bank del nivel 5, acceso,
# «Proximamente» solo con un catalogo copiado, habilidad sin obtener, nivel
# maximo; marcan «sin guardar») y
# EFECTOS SIMPLES sobre el valor efectivo: alcance y aturdimiento del pulso,
# enfriamiento, coste y dano del laser, gasto del Debug y maximos de Sync Rate y
# energia (HUD, papelera, hub, cargadores, drops y power banks). Los JSON base
# no cambian. Efectos de la tanda M2 en test_hide_mode.gd, test_pulse_return.gd,
# test_laser_pierce*.gd, test_debug_upgrades.gd, test_passive_regen.gd y
# test_power_bank_cap.gd. Mas pruebas de la tienda en test_calc_station.gd; guardado v4 y
# migracion en test_save_game.gd; papelera en test_game_over.gd.
extends GutTest

const EcoProgress = preload("res://tests/support/eco_progress.gd")

const HUB_SCENE: PackedScene = preload("res://scenes/hub/hub.tscn")
const ISAK_SCENE: PackedScene = preload("res://scenes/player/isak.tscn")
const HUD_SCENE: PackedScene = preload("res://scenes/ui/hud.tscn")
const BUBBLE_SCENE: PackedScene = preload("res://scenes/enemies/alert_bubble.tscn")
const PATH: String = "user://test_upgrades_save.json"
const EPS: float = 0.001
const TRACKS: Array[StringName] = [&"pulso", &"laser", &"debug", &"sync", &"energia"]

var _saved_path: String
var _saved_pulse: bool
var _saved_laser: bool
var _saved_debug: bool
var _hub: HubRoom


func before_each() -> void:
	_saved_path = GameState.save_path
	_saved_pulse = GameState.is_ability_unlocked(GameState.ABILITY_PULSE)
	_saved_laser = GameState.is_ability_unlocked(GameState.ABILITY_LASER)
	_saved_debug = GameState.is_ability_unlocked(GameState.ABILITY_DEBUG)
	GameState.use_save_path(PATH, true)
	EcoProgress.meet_eco_with_pulse()
	EcoProgress.meet_notas()
	EcoProgress.meet_calc()


func after_each() -> void:
	UpgradeCatalog.set_shared(null)
	if _hub != null and is_instance_valid(_hub):
		_hub.free()
	_hub = null
	GameState.reset_progress()
	GameState.set_ability_unlocked(GameState.ABILITY_PULSE, _saved_pulse)
	GameState.set_ability_unlocked(GameState.ABILITY_LASER, _saved_laser)
	GameState.set_ability_unlocked(GameState.ABILITY_DEBUG, _saved_debug)
	SaveFile.delete(PATH)
	GameState.save_path = _saved_path
	GameState.sync_rate = GameState.SYNC_RATE_MAX
	GameState.debug_energy = GameState.DEBUG_ENERGY_MAX


func _action(name: StringName) -> InputEventAction:
	var event := InputEventAction.new()
	event.action = name
	event.pressed = true
	return event


func _obtain(ability: StringName) -> void:
	GameState.obtained_abilities[ability] = true
	GameState.set_ability_unlocked(ability, true)


## Hub real con la tienda de Calc abierta (sin retardo de entrada).
func _open_calc() -> CalcPanel:
	_hub = HUB_SCENE.instantiate() as HubRoom
	add_child(_hub)
	var vortex: WarpVortex = _hub.get_arrival_vortex()
	if vortex != null:
		vortex.advance(5.0)
	_hub.get_isak().input = PlayerInput.new()
	var calc: CalcStation = _hub.get_calc()
	assert_true(calc.open(_hub.get_isak()), "Calc abre la tienda")
	var panel: CalcPanel = calc.get_calc_panel()
	panel.skip_input_delay()
	return panel


# --- Catalogo ---

func test_catalog_tracks_costs_and_caps() -> void:
	var catalog := UpgradeCatalog.load_from_file()
	assert_true(catalog.is_valid(), "Catalogo valido: %s" % ", ".join(catalog.errors))
	assert_eq(catalog.track_ids(), TRACKS)
	var costs: Dictionary = {
		&"pulso": [0, 25, 15, 25, 25], &"laser": [0, 15, 20, 30, 25], &"debug": [0, 15, 20, 30, 25],
		&"sync": [0, 15, 20, 30, 25], &"energia": [0, 15, 20, 30, 25],
	}
	var implemented: Dictionary = {
		&"pulso": [true, true, true, true, true], &"laser": [true, true, true, true, true],
		&"debug": [true, true, true, true, true], &"sync": [true, true, true, true, true],
		&"energia": [true, true, true, true, true],
	}
	for track: UpgradeCatalog.Track in catalog.tracks():
		assert_eq(track.levels.size(), 5, String(track.id))
		assert_eq(track.total_points(), 90, "90 puntos por pista: %s" % track.id)
		var got_costs: Array = []
		var got_impl: Array = []
		var banks: Array = []
		for level: UpgradeCatalog.Level in track.levels:
			got_costs.append(level.cost_points)
			got_impl.append(level.implemented)
			banks.append(level.cost_power_banks)
			assert_false(level.name.is_empty(), "%s %d: nombre" % [track.id, level.level])
			assert_false(level.description.is_empty(), "%s %d: descripcion" % [track.id, level.level])
			if level.level > 1:
				assert_false(level.effects.is_empty(), "%s %d: efecto" % [track.id, level.level])
		assert_eq(got_costs, costs[track.id], String(track.id))
		assert_eq(got_impl, implemented[track.id], String(track.id))
		assert_eq(banks, [0, 0, 0, 0, 1], "Solo el nivel 5 pide un power bank")
		assert_eq([catalog.access_cap(track.id, 1), catalog.access_cap(track.id, 2), catalog.access_cap(track.id, 3)],
			[3, 4, 5], "Cache 3 / Kernel 4 / Raiz 5: %s" % track.id)
	assert_eq(catalog.total_points(), 450)
	assert_eq(catalog.total_power_banks(), 5)
	assert_eq(catalog.resolve_legacy(&"wide_pulse"), [&"pulso", 2])
	assert_eq(catalog.get_track(&"debug").requires_ability, GameState.ABILITY_DEBUG, "Debug con chip «?»")
	assert_eq(catalog.get_track(&"sync").requires_ability, &"", "Sync siempre")


func test_catalog_rejects_broken_data() -> void:
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(UpgradeCatalog.DEFAULT_PATH))
	var broken: Dictionary = data.duplicate(true)
	(broken["tracks"][0]["levels"] as Array).pop_back()
	assert_false(UpgradeCatalog.from_dict(broken).is_valid(), "Menos de 5 niveles")
	broken = data.duplicate(true)
	broken["tracks"][1]["levels"][2]["description"] = ""
	assert_false(UpgradeCatalog.from_dict(broken).is_valid(), "Sin descripcion")
	broken = data.duplicate(true)
	broken["tracks"][2]["levels"][3]["effects"] = []
	assert_false(UpgradeCatalog.from_dict(broken).is_valid(), "Sin efecto")
	broken = data.duplicate(true)
	broken["tracks"][3]["levels"][0]["cost"]["attention_points"] = 5
	assert_false(UpgradeCatalog.from_dict(broken).is_valid(), "El nivel 1 es gratis")
	assert_true(UpgradeCatalog.from_dict(data).is_valid())
	assert_push_error_count(4, "Cada catalogo roto avisa con un error")


func test_texts_never_say_lap_words() -> void:
	var regex := RegEx.create_from_string("(?i)\\b(vuelta|vueltas|easy|normal|hard)\\b")
	for track: UpgradeCatalog.Track in UpgradeCatalog.shared().tracks():
		assert_null(regex.search(track.name), track.name)
		for level: UpgradeCatalog.Level in track.levels:
			assert_null(regex.search(level.name), level.name)
			assert_null(regex.search(level.description), level.description)


# --- Compras ---

func test_purchase_rules_and_reasons() -> void:
	GameState.attention_points = 14
	assert_eq(GameState.purchase_upgrade(&"laser"), GameState.PurchaseResult.ABILITY_MISSING, "Sin el laser")
	_obtain(GameState.ABILITY_LASER)
	assert_eq(GameState.check_purchase(&"laser"), GameState.PurchaseResult.NOT_ENOUGH_POINTS)
	assert_eq(GameState.purchase_upgrade(&"laser"), GameState.PurchaseResult.NOT_ENOUGH_POINTS)
	assert_eq(GameState.attention_points, 14, "No gasta")
	assert_eq(GameState.get_upgrade_level(&"laser"), 1)
	assert_false(GameState.has_unsaved_changes(), "Sin compra no hay cambios")
	assert_eq(GameState.purchase_upgrade(&"no_existe"), GameState.PurchaseResult.UNKNOWN)
	assert_eq(GameState.purchase_upgrade(&"debug"), GameState.PurchaseResult.ABILITY_MISSING, "Debug: chip «?»")
	GameState.attention_points = 200
	assert_eq(GameState.purchase_upgrade(&"laser"), GameState.PurchaseResult.OK)
	assert_true(GameState.has_unsaved_changes(), "Comprar marca sin guardar")
	assert_eq(GameState.purchase_upgrade(&"laser"), GameState.PurchaseResult.OK)
	assert_eq(GameState.get_upgrade_level(&"laser"), 3)
	assert_eq(GameState.attention_points, 200 - 15 - 20)
	# Cache (vuelta 1): tope 3. El 4 pide Kernel.
	assert_eq(GameState.get_upgrade_access_cap(&"laser"), 3)
	assert_eq(GameState.purchase_upgrade(&"laser"), GameState.PurchaseResult.ACCESS_LOCKED)
	GameState.lap = GameState.LAP_NORMAL
	assert_eq(GameState.get_upgrade_access_cap(&"laser"), 4)
	assert_eq(GameState.purchase_upgrade(&"laser"), GameState.PurchaseResult.OK, "Kernel abre el nivel 4")
	assert_eq(GameState.purchase_upgrade(&"laser"), GameState.PurchaseResult.ACCESS_LOCKED, "El 5 pide Raiz")
	GameState.lap = GameState.LAP_HARD
	GameState.power_banks = 1
	GameState.attention_points = 25
	assert_eq(GameState.purchase_upgrade(&"laser"), GameState.PurchaseResult.OK, "Laser 5 (perfora, tanda M2) en Raiz")
	assert_eq(GameState.power_banks, 0, "Gasta el power bank")
	# Un nivel sin efecto (implemented false) no se compra: «Proximamente».
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(UpgradeCatalog.DEFAULT_PATH))
	data["tracks"][4]["levels"][1]["implemented"] = false
	UpgradeCatalog.set_shared(UpgradeCatalog.from_dict(data))
	GameState.attention_points = 100
	assert_eq(GameState.purchase_upgrade(&"energia"), GameState.PurchaseResult.NOT_IMPLEMENTED)
	UpgradeCatalog.set_shared(null)
	# Debug 2 y 3 (revelado persistente, tanda M2) se compran en Cache; el 4 pide Kernel.
	_obtain(GameState.ABILITY_DEBUG)
	GameState.lap = GameState.LAP_EASY
	GameState.attention_points = 200
	assert_eq(GameState.purchase_upgrade(&"debug"), GameState.PurchaseResult.OK, "Debug 2 (Debug eficiente)")
	assert_eq(GameState.purchase_upgrade(&"debug"), GameState.PurchaseResult.OK, "Debug 3 (revelado persistente)")
	assert_eq(GameState.purchase_upgrade(&"debug"), GameState.PurchaseResult.ACCESS_LOCKED)
	# Nivel maximo.
	GameState.upgrade_levels[&"sync"] = 5
	assert_eq(GameState.purchase_upgrade(&"sync"), GameState.PurchaseResult.MAX_LEVEL)
	assert_null(GameState.get_next_upgrade_level(&"sync"))


func test_level_5_spends_a_power_bank() -> void:
	# Tanda M2: los niveles 5 tienen efecto (Sync 5, Resincronizacion).
	GameState.upgrade_levels[&"sync"] = 4
	GameState.lap = GameState.LAP_HARD
	GameState.attention_points = 30
	GameState.empty_power_banks = 2
	assert_eq(GameState.purchase_upgrade(&"sync"), GameState.PurchaseResult.NOT_ENOUGH_POWER_BANKS,
		"Los vacios no cuentan: hace falta uno completo")
	assert_eq(GameState.attention_points, 30)
	GameState.power_banks = 1
	GameState.attention_points = 24
	assert_eq(GameState.purchase_upgrade(&"sync"), GameState.PurchaseResult.NOT_ENOUGH_POINTS, "25 puntos")
	GameState.attention_points = 25
	assert_eq(GameState.purchase_upgrade(&"sync"), GameState.PurchaseResult.OK)
	assert_eq(GameState.power_banks, 0, "El power bank se gasta")
	assert_eq(GameState.empty_power_banks, 2)
	assert_eq(GameState.attention_points, 0)
	assert_eq(GameState.get_upgrade_level(&"sync"), 5)


func test_legacy_and_track_level_ids() -> void:
	assert_false(GameState.is_upgrade_purchased(&"wide_pulse"))
	GameState.upgrade_levels[&"pulso"] = 3
	assert_true(GameState.is_upgrade_purchased(&"wide_pulse"), "wide_pulse = pulso 2")
	assert_true(GameState.is_upgrade_purchased(&"pulso:3"))
	assert_false(GameState.is_upgrade_purchased(&"pulso:4"))
	assert_false(GameState.is_upgrade_purchased(&"efficient_debug"))
	assert_false(GameState.is_upgrade_purchased(&"nada:2"))


# --- Efectos simples ---

func test_effective_values_per_level_and_base_data_unchanged() -> void:
	var cases: Array = [
		[&"pulso", &"isak_abilities.pulse_radius_px", [96.0, 112.0, 112.0]],
		[&"pulso", &"game_state.pulse_stun_multiplier", [1.0, 1.0, 1.5]],
		[&"laser", &"isak_abilities.laser_cooldown_s", [0.4, 0.3, 0.3, 0.3]],
		[&"laser", &"isak_abilities.laser_energy_cost", [10.0, 10.0, 8.0, 8.0]],
		[&"laser", &"isak_abilities.laser_damage", [1.0, 1.0, 1.0, 2.0]],
		[&"debug", &"debug_mode.drain_per_second", [20.0, 15.0, 15.0, 15.0, 15.0]],
		[&"debug", &"debug_mode.reveal_linger_s", [0.0, 0.0, 1.5, 1.5, 1.5]],
		[&"debug", &"debug_mode.world_time_scale", [0.5, 0.5, 0.5, 0.4, 0.4]],
		[&"debug", &"debug_mode.activation_hold_s", [1.0, 1.0, 1.0, 1.0, 0.4]],
		[&"sync", &"game_state.sync_rate_max", [100.0, 110.0, 120.0, 130.0, 130.0]],
		[&"energia", &"game_state.debug_energy_max", [100.0, 110.0, 120.0, 130.0, 130.0]],
	]
	for c: Array in cases:
		var values: Array = c[2]
		for i: int in values.size():
			GameState.upgrade_levels[c[0]] = i + 1
			var target: StringName = c[1]
			assert_almost_eq(GameState.effective_value(target, GameState.base_value(target)), float(values[i]), EPS,
				"%s nivel %d: %s" % [c[0], i + 1, target])
		GameState.upgrade_levels.erase(c[0])
	# Un nivel alto conserva los efectos de los anteriores (Debug 5 = 2 + 3 + 4 + 5).
	GameState.upgrade_levels[&"debug"] = 5
	assert_almost_eq(DebugMode.get_activation_hold_s(), 0.4, EPS, "Arranque rapido (Debug 5)")
	assert_almost_eq(DebugMode.get_drain_per_second(), 15.0, EPS, "Debug 2 si")
	assert_almost_eq(DebugMode.get_world_time_scale(), 0.4, EPS, "Debug 4 si")
	assert_almost_eq(DebugMode.get_reveal_linger_s(), 1.5, EPS, "Debug 3 si")
	# Los datos base no cambian.
	assert_almost_eq(DebugModeConfig.load_from_file().drain_per_second, 20.0, EPS)
	assert_almost_eq(PlayerAbilities.load_from_file().laser_energy_cost, 10.0, EPS)
	assert_almost_eq(GameState.SYNC_RATE_MAX, 100.0, EPS)
	assert_almost_eq(GameState.DEBUG_ENERGY_MAX, 100.0, EPS)


func test_isak_uses_pulse_and_laser_levels() -> void:
	GameState.upgrade_levels[&"pulso"] = 3
	GameState.upgrade_levels[&"laser"] = 4
	var isak := ISAK_SCENE.instantiate() as Isak
	add_child_autofree(isak)
	assert_almost_eq(isak.abilities.pulse_radius_px, 112.0, EPS, "Pulso 2: alcance")
	assert_almost_eq(isak.abilities.laser_cooldown_s, 0.3, EPS, "Laser 2: enfriamiento")
	assert_almost_eq(isak.abilities.laser_energy_cost, 8.0, EPS, "Laser 3: coste")
	assert_almost_eq(isak.abilities.laser_damage, 2.0, EPS, "Laser 4: dano")
	assert_almost_eq(GameState.get_laser_energy_cost(), 8.0, EPS, "El HUD usa el mismo coste")
	var shot := LaserProjectile.new()
	shot.setup(isak.abilities, 1.0, isak)
	assert_almost_eq(shot.damage, 2.0, EPS, "El disparo lleva el dano mejorado")
	shot.free()
	assert_almost_eq(PlayerAbilities.load_from_file().pulse_radius_px, 96.0, EPS)


func test_laser_4_pops_a_bubble_in_one_shot() -> void:
	var bubble := BUBBLE_SCENE.instantiate() as AlertBubble
	add_child_autofree(bubble)
	bubble.on_laser_hit(1.0, null)
	assert_ne(bubble.get_state(), AlertBubble.STATE_POPPED, "Base: la Burbuja (vida 2) aguanta un disparo")
	var second := BUBBLE_SCENE.instantiate() as AlertBubble
	add_child_autofree(second)
	GameState.upgrade_levels[&"laser"] = 4
	var isak := ISAK_SCENE.instantiate() as Isak
	add_child_autofree(isak)
	second.on_laser_hit(isak.abilities.laser_damage, isak)
	assert_eq(second.get_state(), AlertBubble.STATE_POPPED, "Laser 4: la Burbuja cae de un disparo")


func test_pulse_3_stuns_longer() -> void:
	var bubble := BUBBLE_SCENE.instantiate() as AlertBubble
	add_child_autofree(bubble)
	var area := Area2D.new()
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 200.0
	shape.shape = circle
	area.add_child(shape)
	add_child_autofree(area)
	area.global_position = bubble.global_position
	assert_true(bubble.receive_pulse(area))
	assert_almost_eq(bubble.get_stun_left(), bubble.stun_duration_s, EPS, "Base: 3 s")
	GameState.upgrade_levels[&"pulso"] = 3
	assert_true(bubble.receive_pulse(area))
	assert_almost_eq(bubble.get_stun_left(), bubble.stun_duration_s * 1.5, EPS, "Pulso 3: x1,5 (4,5 s)")
	assert_almost_eq(bubble.stun_duration_s, 3.0, EPS, "El dato base no cambia")


func test_debug_2_drains_less() -> void:
	assert_almost_eq(DebugMode.get_drain_per_second(), 20.0, EPS)
	_obtain(GameState.ABILITY_DEBUG)
	GameState.attention_points = 15
	assert_eq(GameState.purchase_upgrade(&"debug"), GameState.PurchaseResult.OK)
	assert_almost_eq(DebugMode.get_drain_per_second(), 15.0, EPS, "Debug eficiente: 15/s")


func test_sync_and_energy_maxima_everywhere() -> void:
	GameState.attention_points = 100
	assert_eq(GameState.purchase_upgrade(&"sync"), GameState.PurchaseResult.OK)
	assert_eq(GameState.purchase_upgrade(&"energia"), GameState.PurchaseResult.OK)
	assert_eq(GameState.purchase_upgrade(&"energia"), GameState.PurchaseResult.OK)
	GameState.lap = GameState.LAP_NORMAL
	GameState.attention_points = 100
	assert_eq(GameState.purchase_upgrade(&"sync"), GameState.PurchaseResult.OK)
	assert_eq(GameState.purchase_upgrade(&"sync"), GameState.PurchaseResult.OK)
	assert_eq(GameState.purchase_upgrade(&"energia"), GameState.PurchaseResult.OK)
	assert_almost_eq(GameState.get_sync_rate_max(), 130.0, EPS)
	assert_almost_eq(GameState.get_debug_energy_max(), 130.0, EPS)
	GameState.sync_rate = 500.0
	assert_almost_eq(GameState.sync_rate, 130.0, EPS, "Sync Rate hasta 130")
	# HUD: porcentaje real y barras por fraccion del maximo.
	var hud := HUD_SCENE.instantiate() as Hud
	add_child_autofree(hud)
	assert_eq(hud.get_sync_text(), "130 %")
	assert_almost_eq(hud.get_sync_ratio(), 1.0, EPS)
	GameState.debug_energy = 130.0
	hud.finish_animations()
	assert_eq(hud.get_battery_segments(), 5, "Barra llena con 130")
	GameState.debug_energy = 65.0
	hud.finish_animations()
	assert_almost_eq(hud.get_energy_ratio(), 0.5, EPS, "65 de 130 = mitad")
	# Cargador: suma hasta el maximo nuevo, sin desbordar.
	GameState.debug_energy = 100.0
	assert_almost_eq(GameState.recharge_debug_energy(50.0), 30.0, EPS, "Cargador hasta 130")
	assert_almost_eq(GameState.debug_energy, 130.0, EPS)
	# Drops: el sobrante por encima del maximo nuevo carga los power banks vacios.
	GameState.empty_power_banks = 1
	GameState.debug_energy = 120.0
	assert_almost_eq(GameState.add_debug_energy(50.0), 40.0, EPS, "Sobran 40 sobre 130")
	assert_almost_eq(GameState.power_bank_charge, 40.0, EPS)
	# Hub: al entrar llena hasta los maximos nuevos.
	GameState.debug_energy = 10.0
	GameState.sync_rate = 10.0
	_hub = HUB_SCENE.instantiate() as HubRoom
	add_child(_hub)
	assert_almost_eq(GameState.debug_energy, 130.0, EPS, "El hub llena la energia hasta 130")
	assert_almost_eq(GameState.sync_rate, 130.0, EPS, "y el Sync Rate hasta 130")


func test_laser_3_keeps_hud_empty_rule_coherent() -> void:
	_obtain(GameState.ABILITY_LASER)
	var hud := HUD_SCENE.instantiate() as Hud
	add_child_autofree(hud)
	GameState.debug_energy = 9.0
	hud.finish_animations()
	assert_eq(hud.get_battery_segments(), 0, "Base: 9 < 10 se ve vacia")
	GameState.upgrade_levels[&"laser"] = 3
	EventBus.upgrade_purchased.emit(&"laser")
	assert_gt(hud.get_battery_segments(), 0, "Laser 3: 9 >= 8, aun se puede disparar")
	GameState.debug_energy = 7.5
	hud.finish_animations()
	assert_eq(hud.get_battery_segments(), 0, "7,5 < 8: vacia")
	assert_true(Hud.is_energy_shown_empty(7.5))
	assert_false(Hud.is_energy_shown_empty(8.0))


# --- Tienda del hub real ---

func test_hub_purchase_changes_effective_pulse_radius() -> void:
	GameState.attention_points = 30
	var panel: CalcPanel = _open_calc()
	assert_eq(panel.get_track_ids(), TRACKS, "Una fila por pista")
	panel._unhandled_input(_action(&"move_down"))
	assert_eq(panel.get_selected_index(), 1)
	panel._unhandled_input(_action(&"move_up"))
	assert_eq(panel.get_selected_track(), &"pulso")
	assert_string_contains(panel.get_detail(), "Pulso amplio")
	assert_string_contains(panel.get_detail(), "96 px a 112 px")
	panel._unhandled_input(_action(&"pulse"))
	assert_eq(GameState.get_upgrade_level(&"pulso"), 2, "Pulso compra el siguiente nivel")
	assert_eq(GameState.attention_points, 5)
	assert_eq(panel.get_lines()[0], "◆ 5 puntos de atención")
	assert_eq(panel.filled_count(&"pulso"), 2, "2 de 5")
	var isak := ISAK_SCENE.instantiate() as Isak
	add_child_autofree(isak)
	assert_almost_eq(isak.abilities.pulse_radius_px, 112.0, EPS, "El Isak siguiente usa el radio mejorado")


func test_hub_purchase_only_marks_unsaved_and_notas_writes_levels() -> void:
	GameState.attention_points = 30
	var panel: CalcPanel = _open_calc()
	assert_eq(panel.get_lines()[2], "Todo guardado")
	panel._unhandled_input(_action(&"pulse"))
	assert_true(GameState.is_upgrade_purchased(&"wide_pulse"))
	assert_false(FileAccess.file_exists(PATH), "Comprar no guarda")
	assert_true(GameState.has_unsaved_changes())
	assert_eq(panel.get_lines()[2], "Sin guardar", "Indicador al comprar")
	assert_true(QuitGuard.can_save_here(get_tree()), "El aviso al salir ofrece guardar en el hub")
	var notas := (_hub.get_station(&"notas") as NotasStation).get_notas_panel()
	assert_true(notas.save_now(), "Notas guarda")
	assert_false(GameState.has_unsaved_changes())
	assert_eq(panel.get_lines()[2], "Todo guardado", "El panel de Calc se entera")
	var data: Dictionary = SaveFile.read(PATH)
	assert_eq(int(data["upgrade_levels"]["pulso"]), 2)


# La accion save_game (C / R3) se retiro (2026-10-15): se guarda en la copia
# local del hub. C queda libre; R3 lo usa ahora solo la ayuda (`help`).
func test_save_action_removed_and_keys_free() -> void:
	assert_false(InputMap.has_action(&"save_game"), "Ya no hay accion save_game")
	var key := InputEventKey.new()
	key.physical_keycode = KEY_C
	var r3 := InputEventJoypadButton.new()
	r3.button_index = JOY_BUTTON_RIGHT_STICK
	for action: StringName in InputMap.get_actions():
		if String(action).begins_with("ui_") or action == &"help":
			continue
		assert_false(InputMap.event_is_action(key, action), "C libre (%s)" % action)
		assert_false(InputMap.event_is_action(r3, action), "R3 libre (%s)" % action)
