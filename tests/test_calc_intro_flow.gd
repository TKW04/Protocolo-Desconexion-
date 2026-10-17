# Flujo completo del encuentro con Calc (tanda H3 del paso 14 de
# docs/propuesta-1-2.md, 2026-10-17) con el 1-2 REAL y LevelRunner
# (scenes/main.tscn): la azotea se resuelve (pared, interruptores y panel), Calc
# se carga y se teletransporta de verdad (EventBus.ally_teleported), Isak sale
# por la terminal con corriente y al llegar al hub se encuentra con Calc: pausa,
# lineas de Calc (LCD) con la de Eco entre medias, meet_ally("calc") y tienda.
# Tambien: un game over tras teletransportar a Calc y antes de llegar al hub no
# rompe nada (sin escena, Calc desconocida y el 1-2 repite el acertijo), y del
# 1-1 al hub no hay Calc. Usa sus propias rutas de guardado y ajustes.
extends GutTest

const EcoProgress = preload("res://tests/support/eco_progress.gd")
const MAIN_SCENE: PackedScene = preload("res://scenes/main.tscn")
const PATH: String = "user://test_calc_intro_flow.json"
const TILE: float = 64.0
const DT: float = 1.0 / 60.0
const LONG_STEP_S: float = 5.0

var _main: LevelRunner
var _isak: Isak
var _saved_pause: bool
var _saved_path: String
var _settings_path: String
var _teleported: Array[StringName] = []


func before_each() -> void:
	_saved_pause = EcoTextBox.pause_important
	EcoTextBox.pause_important = true
	_saved_path = GameState.save_path
	GameState.use_save_path(PATH, true)
	_settings_path = GameSettings.settings_path()
	GameSettings.use_path(_settings_path, true)
	DebugMode.input_enabled = false
	DebugMode.reset()
	GameState.reset_progress()
	EcoProgress.meet_eco_with_pulse()
	EcoProgress.meet_notas()
	EcoProgress.obtain_debug()
	GameState.obtained_abilities[GameState.ABILITY_LASER] = true
	GameState.seen_notices[GameState.ABILITY_LASER] = true
	GameState.set_ability_unlocked(GameState.ABILITY_LASER, true)
	GameState.mark_level_completed(&"1-1")
	GameState.unlock_level(&"1-2")
	GameState.attention_points = 17
	GameState.sync_rate = GameState.SYNC_RATE_MAX
	_teleported.clear()
	EventBus.ally_teleported.connect(_on_teleported)


func after_each() -> void:
	EventBus.ally_teleported.disconnect(_on_teleported)
	if is_instance_valid(_main):
		_main.free()
	_main = null
	get_tree().paused = false
	EcoTextBox.pause_important = _saved_pause
	DebugMode.reset()
	DebugMode.input_enabled = true
	SaveFile.delete(PATH)
	GameState.reset_progress()
	GameState.last_checkpoint.clear()
	GameState.save_path = _saved_path
	GameState.sync_rate = GameState.SYNC_RATE_MAX
	GameState.debug_energy = GameState.DEBUG_ENERGY_MAX
	GameSettings.use_path(_settings_path, true)


func _on_teleported(ally: StringName) -> void:
	_teleported.append(ally)


func _start(level_id: String) -> void:
	_main = MAIN_SCENE.instantiate() as LevelRunner
	_main.auto_advance = false
	_main.start_level_id = level_id
	add_child(_main)
	_main.advance(LONG_STEP_S)
	var vortex: WarpVortex = _main.get_arrival_vortex()
	for i: int in 600:
		if vortex == null or not is_instance_valid(vortex) or vortex.is_done():
			break
		vortex.advance(DT)
	_isak = _main.get_isak()
	if _isak != null:
		_isak.input = PlayerInput.new()
	await wait_physics_frames(10)


func _obj(id: String) -> Node:
	return _main.get_level().get_node_or_null(NodePath("Objects/" + id))


func _teleport_isak(col: int, row: int) -> void:
	_isak.global_position = Vector2((col + 0.5) * TILE, (row + 1) * TILE)
	_isak.velocity = Vector2.ZERO
	_isak.snap_camera()


## La azotea completa como el jugador: el Debug abre la pared, los tres pulsos,
## el laser y el panel oculto; despues Calc entra, se carga y se teletransporta.
func _solve_rooftop() -> void:
	_teleport_isak(14, 9)
	var wall := _obj("pared_glitch") as GlitchWall
	wall.open_with_debug()
	wall.advance(2.0)
	(_obj("interruptor_luz") as PowerSwitch).activate()
	(_obj("interruptor_laser") as LaserSwitch).activate()
	(_obj("panel_oculto") as PowerSwitch).activate()
	var dock := _obj("dock_calc") as ChargeDock
	for i: int in 1800:
		if dock.is_power_on():
			break
		for id: String in ["dock_calc", "calc", "pared_glitch", "terminal_azotea"]:
			_obj(id).call(&"advance", DT)
	assert_true(dock.is_power_on(), "Calc se cargo y se fue")


## Sale por la terminal de la azotea y llega al hub (llegada terminada).
func _exit_to_hub() -> HubRoom:
	_teleport_isak(10, 9)
	var terminal := _obj("terminal_azotea") as ExitTerminal
	assert_true(terminal.is_powered(), "La terminal tiene corriente")
	assert_true(terminal.activate(_isak), "El pulso activa la terminal")
	terminal.advance(LONG_STEP_S)
	terminal.get_vortex().advance(LONG_STEP_S)
	_main.advance(LONG_STEP_S)
	assert_true(_main.is_in_hub(), "Vuelve al hub")
	var hub: HubRoom = _main.get_hub()
	for i: int in 20:
		if hub.has_arrived():
			break
		_main.advance(LONG_STEP_S)
		var vortex: WarpVortex = hub.get_arrival_vortex()
		if vortex != null:
			vortex.advance(LONG_STEP_S)
	assert_true(hub.has_arrived(), "Isak llega al hub")
	return hub


func _close_line(hub: HubRoom) -> void:
	var box: EcoTextBox = hub.get_text_box()
	box.finish_typing()
	box.confirm()
	box.advance(1.0)
	await get_tree().process_frame
	await get_tree().process_frame


func test_rooftop_terminal_and_the_encounter_in_the_hub() -> void:
	await _start("1-2")
	_solve_rooftop()
	assert_eq(_teleported, [GameState.ALLY_CALC] as Array[StringName], "Calc se teletransporto al hub")
	assert_true(CalcIntro.is_pending(), "Llegada pendiente (sesion)")
	assert_false(GameState.has_met_ally(GameState.ALLY_CALC), "Aun no es conocida")
	var hub: HubRoom = _exit_to_hub()
	assert_true(GameState.is_level_completed(&"1-2"), "1-2 completado")
	var intro: CalcIntro = hub.get_calc_intro()
	assert_not_null(intro, "Encuentro con Calc en el hub")
	assert_true(intro.is_running(), "Empieza al terminar la llegada")
	assert_true(get_tree().paused, "Pausa")
	assert_true(hub.get_calc().is_arrived(), "Calc ya esta en su estacion")
	assert_eq(hub.get_calc().get_calc_animation(), &"awake", "Despierta")
	assert_false(hub.get_calc().is_powered(), "Sin tienda durante la escena")
	assert_false(_main.get_pause_menu().request_open(), "El menu de pausa no se abre")
	var box: EcoTextBox = hub.get_text_box()
	var texts: Array[String] = []
	var speakers: Array[StringName] = []
	for i: int in 12:
		if not intro.is_running():
			break
		texts.append(box.get_text())
		speakers.append(box.get_speaker_id())
		await _close_line(hub)
	assert_true(intro.is_done())
	assert_true(texts.has("Has recogido 17 ◆. Crees que son ganancia."), "Saldo actual (17) con el icono")
	var eco_at: int = speakers.find(&"")
	assert_gt(eco_at, 0, "Eco habla tras Calc")
	assert_eq(speakers[eco_at + 1], &"calc", "Y Calc le responde")
	assert_eq(speakers.count(&""), 1, "Una sola linea de Eco")
	assert_true(GameState.has_met_ally(GameState.ALLY_CALC), "Calc conocida")
	assert_true(GameState.has_unsaved_changes(), "Sin guardar")
	assert_false(get_tree().paused, "Pausa liberada")
	var calc: CalcStation = hub.get_calc()
	assert_true(calc.is_powered(), "Estacion encendida")
	assert_true(calc.open(hub.get_isak()), "Tienda abierta")
	calc.close(true)


func test_game_over_after_the_teleport_breaks_nothing() -> void:
	GameState.save_game()
	await _start("1-2")
	_solve_rooftop()
	assert_true(CalcIntro.is_pending())
	GameState.lives = 1
	GameState.sync_rate = GameState.SYNC_RATE_MIN
	assert_true(_main.is_game_over_pending(), "Ultima vida: game over")
	_main.advance(_main.get_death_wait_s() + 0.01)
	_main.advance(LONG_STEP_S)
	assert_true(_main.is_in_hub(), "Eco lleva a Isak al hub")
	var hub: HubRoom = _main.get_hub()
	assert_null(hub.get_calc_intro(), "Sin encuentro tras el game over")
	assert_false(CalcIntro.is_pending(), "La llegada se perdio con el rollback")
	assert_false(GameState.has_met_ally(GameState.ALLY_CALC))
	assert_false(hub.get_calc().is_powered(), "Calc sigue apagada")
	assert_eq(hub.get_calc().get_calc_animation(), &"powered_off")
	await wait_frames(2)


func test_from_1_1_to_the_hub_there_is_no_calc() -> void:
	await _start("hub")
	var hub: HubRoom = _main.get_hub()
	assert_not_null(hub)
	assert_null(hub.get_calc_intro(), "Sin teletransporte no hay Calc")
	assert_false(hub.get_calc().is_powered())
