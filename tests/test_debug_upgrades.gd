# Debug 3-5 (tanda M2 de docs/propuesta-mejoras.md §2, 2026-10-17):
# - Debug 3 «Revelado persistente»: lo revelado (plataformas ocultas h, vista a
#   traves de los pop-ups translucidos) sigue visible y SOLIDO 1,5 s reales tras
#   apagar el Debug, con parpadeo de aviso al final; sin la mejora cae al instante.
# - Debug 4 «Mas ralentizacion»: el mundo va a x0,4 (antes x0,5); el gasto sigue
#   en tiempo real (20/s, 15/s con el Debug 2).
# - Debug 5 «Arranque rapido» (la antigua quick_start): carga de 1,0 a 0,4 s.
extends GutTest

const EcoProgress = preload("res://tests/support/eco_progress.gd")
const OVERLAY_SCENE: PackedScene = preload("res://scenes/levels/overlay_popup.tscn")
const PATH: String = "user://test_debug_upgrades_save.json"
const DT: float = 1.0 / 60.0
const EPS: float = 0.001

var _saved_path: String
var _saved_debug: bool


func before_each() -> void:
	_saved_path = GameState.save_path
	_saved_debug = GameState.is_ability_unlocked(GameState.ABILITY_DEBUG)
	GameState.use_save_path(PATH, true)
	EcoProgress.obtain_debug()
	DebugMode.input_enabled = false
	DebugMode.reset()
	GameState.debug_energy = GameState.DEBUG_ENERGY_MAX


func after_each() -> void:
	DebugMode.reset()
	DebugMode.input_enabled = true
	GameState.reset_progress()
	GameState.set_ability_unlocked(GameState.ABILITY_DEBUG, _saved_debug)
	SaveFile.delete(PATH)
	GameState.save_path = _saved_path
	GameState.debug_energy = GameState.DEBUG_ENERGY_MAX
	GameState.world_time_scale = GameState.WORLD_TIME_SCALE_NORMAL


func _run(seconds: float, held: bool) -> void:
	for i: int in roundi(seconds / DT):
		DebugMode.step(DT, held)


func _activate() -> void:
	_run(DebugMode.get_activation_hold_s() + DT, true)
	DebugMode.step(DT, false)
	assert_true(DebugMode.is_active(), "Debug activo")


func _tap() -> void:
	DebugMode.step(DT, true)
	DebugMode.step(DT, false)


func _platform() -> HiddenPlatform:
	var platform := HiddenPlatform.new()
	add_child_autofree(platform)
	return platform


func test_base_values_unchanged() -> void:
	var c := DebugModeConfig.load_from_file()
	assert_almost_eq(c.reveal_linger_s, 0.0, EPS, "Base: sin persistencia")
	assert_almost_eq(c.world_time_scale, 0.5, EPS)
	assert_almost_eq(c.activation_hold_s, 1.0, EPS)
	assert_almost_eq(DebugMode.get_reveal_linger_s(), 0.0, EPS)


func test_without_debug_3_hidden_platform_drops_at_once() -> void:
	var platform: HiddenPlatform = _platform()
	assert_false(platform.is_solid())
	_activate()
	assert_true(platform.is_solid(), "Con el Debug: solida")
	_tap()
	assert_false(DebugMode.is_active())
	assert_false(platform.is_solid(), "Sin la mejora cae al instante")
	assert_false(DebugMode.is_revealing())


func test_debug_3_keeps_revealed_solid_for_1_5_s() -> void:
	GameState.upgrade_levels[&"debug"] = 3
	assert_almost_eq(DebugMode.get_reveal_linger_s(), 1.5, EPS)
	var platform: HiddenPlatform = _platform()
	watch_signals(EventBus)
	_activate()
	_tap()
	assert_false(DebugMode.is_active(), "Debug apagado")
	assert_true(DebugMode.is_revealing(), "Lo revelado sigue")
	assert_true(platform.is_solid(), "Y solido")
	_run(1.0, false)
	platform._process(DT)
	assert_true(platform.is_solid(), "A 1 s sigue")
	assert_true(platform.is_shown(), "Y visible")
	assert_true(DebugMode.is_reveal_warning(), "Ultimo medio segundo: aviso (parpadeo)")
	_run(0.55, false)
	assert_false(DebugMode.is_revealing(), "Pasados 1,5 s se acaba")
	assert_false(platform.is_solid(), "Y deja de ser solida")
	assert_signal_emitted_with_parameters(EventBus, "debug_reveal_changed", [false])
	_run(1.0, false)
	platform._process(DT)
	assert_false(platform.is_shown(), "Y se apaga del todo")


func test_debug_3_linger_also_when_energy_runs_out_but_not_on_death() -> void:
	GameState.upgrade_levels[&"debug"] = 3
	var platform: HiddenPlatform = _platform()
	_activate()
	GameState.debug_energy = 0.01
	_run(0.1, false)
	assert_false(DebugMode.is_active(), "Sin energia se apaga")
	assert_true(platform.is_solid(), "Pero lo revelado persiste")
	EventBus.player_died.emit()
	assert_false(DebugMode.is_revealing(), "Al morir no hay persistencia")
	assert_false(platform.is_solid())


func test_debug_3_overlay_popup_stays_see_through() -> void:
	GameState.upgrade_levels[&"debug"] = 3
	var popup := OVERLAY_SCENE.instantiate() as OverlayPopup
	add_child_autofree(popup)
	popup.advance(0.0)
	var opaque: float = popup.get_current_opacity()
	_activate()
	_run(0.3, false)
	_tap()
	_run(0.5, false)
	assert_almost_eq(DebugMode.get_reveal_intensity(), 1.0, EPS, "Durante la persistencia se ve a traves del todo")
	popup.advance(0.0)
	assert_almost_eq(popup.get_current_opacity(), popup.debug_opacity, EPS, "Pop-up translucido aun transparente")
	assert_lt(popup.get_current_opacity(), opaque)
	_run(1.5, false)
	popup.advance(0.0)
	assert_almost_eq(popup.get_current_opacity(), opaque, EPS, "Despues vuelve a tapar")


func test_debug_4_slows_world_more_with_same_real_drain() -> void:
	assert_almost_eq(DebugMode.time_scale_for(1.0), 0.5, EPS)
	GameState.upgrade_levels[&"debug"] = 4
	assert_almost_eq(DebugMode.get_world_time_scale(), 0.4, EPS, "Debug 4: x0,4")
	assert_almost_eq(DebugMode.time_scale_for(1.0), 0.4, EPS)
	_activate()
	_run(0.5, false)
	assert_almost_eq(GameState.world_time_scale, 0.4, EPS, "El mundo va a x0,4")
	assert_almost_eq(WorldTime.scaled_delta(1.0), 0.4, EPS)
	var before: float = GameState.debug_energy
	_run(1.0, false)
	assert_almost_eq(before - GameState.debug_energy, DebugMode.get_drain_per_second(), 0.2,
		"Gasto en tiempo real: 15/s con el Debug 2 (incluido)")
	assert_almost_eq(DebugMode.get_drain_per_second(), 15.0, EPS)


func test_debug_5_quick_start() -> void:
	assert_almost_eq(DebugMode.get_activation_hold_s(), 1.0, EPS)
	GameState.upgrade_levels[&"debug"] = 5
	assert_almost_eq(DebugMode.get_activation_hold_s(), 0.4, EPS, "Arranque rapido: 0,4 s")
	_run(0.35, true)
	assert_false(DebugMode.is_active(), "A 0,35 s aun carga")
	_run(0.07, true)
	assert_true(DebugMode.is_active(), "A 0,4 s entra")
	# El 5 conserva el revelado persistente y la ralentizacion de los niveles 3 y 4.
	assert_almost_eq(DebugMode.get_reveal_linger_s(), 1.5, EPS)
	assert_almost_eq(DebugMode.get_world_time_scale(), 0.4, EPS)
