# Pausa de inicio del 1-1. Hasta el 2026-10-15 la bienvenida de Eco salia al
# verse la llegada y pausaba. Desde el encuentro con Eco (2026-10-16, paso 6 de
# docs/propuesta-asistentes-y-vidas.md) el 1-1 ya no tiene linea al empezar: la
# llegada por el vortice no pausa, Isak recupera el control sin pulso y sin Eco,
# y la bienvenida abre la presentacion en el encuentro (columnas 10-12), que
# pausa el juego hasta cerrarla. Con EcoTextBox.pause_important = false
# (interruptor de las pruebas) la presentacion sale igual pero no pausa.
extends GutTest

const MAIN_SCENE: PackedScene = preload("res://scenes/main.tscn")
const WELCOME: String = "Bienvenido. He optimizado tu espacio."
## Mas que cualquier fundido o llegada (data/flow.json, data/warp.json).
const LONG_STEP_S: float = 5.0

var _main: LevelRunner
var _lines: Array[String] = []


func before_each() -> void:
	_lines.clear()
	EventBus.eco_line_requested.connect(_on_line)
	EcoTextBox.pause_important = true


func after_each() -> void:
	EventBus.eco_line_requested.disconnect(_on_line)
	if is_instance_valid(_main):
		_main.free()
	_main = null
	get_tree().paused = false
	EcoTextBox.pause_important = true
	GameState.sync_rate = GameState.SYNC_RATE_MAX
	GameState.debug_energy = GameState.DEBUG_ENERGY_MAX
	GameState.reset_progress()
	GameState.last_checkpoint.clear()


func _on_line(text: String, _duration_s: float, _important: bool) -> void:
	_lines.append(text)


func _start() -> void:
	_main = MAIN_SCENE.instantiate() as LevelRunner
	_main.auto_advance = false
	_main.start_level_id = "1-1"
	add_child(_main)
	_main.get_ability_notices().auto_advance = false


func _box() -> EcoTextBox:
	return _main.get_level().get_node(^"EcoTextBox") as EcoTextBox


func _encounter() -> EcoEncounter:
	return _main.get_level().get_node(^"Objects/eco_encuentro") as EcoEncounter


## Termina el fundido y avanza el vortice de llegada a mano hasta que termina
## (o hasta que algo pause el juego).
func _finish_arrival() -> void:
	_main.advance(LONG_STEP_S)
	var vortex: WarpVortex = _main.get_arrival_vortex()
	var guard: int = 600
	while vortex != null and not vortex.is_done() and not get_tree().paused and guard > 0:
		vortex.advance(1.0 / 60.0)
		guard -= 1


## Lleva a Isak (con control) a la zona del encuentro.
func _walk_into_encounter() -> void:
	var isak: Isak = _main.get_isak()
	isak.global_position = Vector2(11.5 * 64.0, 10.0 * 64.0)
	await wait_physics_frames(3)


func test_arrival_has_no_welcome_and_does_not_pause() -> void:
	_start()
	await wait_physics_frames(20)
	_finish_arrival()
	assert_eq(_main.get_phase(), LevelRunner.Phase.PLAYING)
	assert_eq(_main.get_fade_alpha(), 0.0, "El nivel ya se ve")
	assert_eq(_lines.size(), 0, "Ninguna linea de Eco al empezar el 1-1")
	assert_false(get_tree().paused, "La llegada no pausa")
	var vortex: WarpVortex = _main.get_arrival_vortex()
	assert_true(vortex == null or vortex.is_done(), "El vortice se cierra")
	assert_false(_main.get_isak().is_warping(), "Isak recupera el control")
	assert_false(GameState.is_ability_unlocked(GameState.ABILITY_PULSE), "Sin pulso hasta el encuentro")
	assert_false(GameState.has_met_ally(GameState.ALLY_ECO), "Sin Eco hasta el encuentro")
	assert_false(_encounter().is_running())
	assert_true(_encounter().is_eco_visible(), "Eco flota delante, en el encuentro")


func test_encounter_pauses_with_the_welcome_and_resumes() -> void:
	_start()
	await wait_physics_frames(20)
	_finish_arrival()
	await _walk_into_encounter()
	assert_true(_encounter().is_running(), "Isak entra en la zona del encuentro")
	assert_true(_lines.has(WELCOME), "La bienvenida abre la presentacion")
	assert_true(get_tree().paused, "Y pausa el juego")
	var box: EcoTextBox = _box()
	assert_true(box.is_important())
	# El jugador cierra las lineas y deja el apodo: la pausa se mantiene hasta el final.
	var guard: int = 40
	while _encounter().is_running() and guard > 0:
		guard -= 1
		var entry: NicknameEntry = _encounter().get_nickname_entry()
		if entry != null:
			assert_true(get_tree().paused, "La entrada del apodo tambien pausa")
			entry.activate_selected()
		elif box.is_important():
			box.finish_typing()
			box.confirm()
			box.advance(LONG_STEP_S)
		await wait_process_frames(1)
	assert_true(_encounter().is_done())
	assert_false(get_tree().paused, "Se reanuda al cerrar la ultima linea")
	assert_true(GameState.is_ability_unlocked(GameState.ABILITY_PULSE))


func test_test_switch_shows_the_welcome_without_pausing() -> void:
	EcoTextBox.pause_important = false
	_start()
	await wait_physics_frames(20)
	_finish_arrival()
	await _walk_into_encounter()
	assert_true(_lines.has(WELCOME))
	assert_false(get_tree().paused, "Con el interruptor de pruebas no pausa")
