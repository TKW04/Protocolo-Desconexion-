# Pausa de inicio del 1-1 (2026-10-15): la bienvenida de Eco (eco_bienvenida,
# linea importante que pausa el juego) no sale mientras el fundido de entrada
# tapa el nivel; sale cuando la llegada de Isak ya se ve (LevelRunner.present_isak
# o, con el vortice, al empezar a materializarse) y entonces pausa. Al cerrarla
# el juego se reanuda. Con EcoTextBox.pause_important = false (interruptor de
# las pruebas) la linea sale igual pero no pausa.
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


func _welcome() -> EcoLine:
	return _main.get_level().get_node(^"Objects/eco_bienvenida") as EcoLine


## Termina el fundido y avanza el vortice de llegada a mano hasta que Isak se
## muestra (y la bienvenida pausa) o hasta que termina.
func _finish_arrival() -> void:
	_main.advance(LONG_STEP_S)
	var vortex: WarpVortex = _main.get_arrival_vortex()
	var guard: int = 600
	while vortex != null and not vortex.is_done() and not get_tree().paused and guard > 0:
		vortex.advance(1.0 / 60.0)
		guard -= 1


func test_welcome_waits_while_the_fade_hides_the_level() -> void:
	_start()
	await wait_physics_frames(20)
	assert_true(_main.get_isak().is_warp_hidden(), "Isak aun no se ha mostrado")
	assert_true(_welcome().is_waiting_for_reveal(), "Isak ya esta en la zona: la linea espera")
	assert_false(_lines.has(WELCOME), "No sale con el nivel tapado por el fundido")
	assert_false(get_tree().paused, "No pausa antes de que se vea el nivel")
	assert_gt(_main.get_fade_alpha(), 0.9, "El fundido sigue en negro")


func test_welcome_pauses_once_the_level_is_visible_and_resumes() -> void:
	_start()
	await wait_physics_frames(20)
	_finish_arrival()
	assert_eq(_main.get_phase(), LevelRunner.Phase.PLAYING)
	assert_eq(_main.get_fade_alpha(), 0.0, "El nivel ya se ve")
	assert_true(_lines.has(WELCOME), "La bienvenida sale al verse a Isak")
	assert_true(get_tree().paused, "Y pausa el juego")
	var vortex: WarpVortex = _main.get_arrival_vortex()
	assert_not_null(vortex, "El vortice sigue en pantalla durante la pausa")
	assert_eq(vortex.get_phase(), WarpVortex.Phase.CLOSE, "Pausa al empezar a cerrarse (Isak ya se ve)")
	assert_true(vortex.get_sprite().visible)
	assert_gt(_main.get_isak().modulate.a, 0.0, "Isak empieza a materializarse")
	assert_true(_main.get_isak().is_warping(), "Aun sin control")
	var box: EcoTextBox = _box()
	assert_true(box.is_important())
	box.finish_typing()
	assert_true(box.confirm(), "El jugador la cierra")
	box.advance(LONG_STEP_S)
	assert_false(get_tree().paused, "Se reanuda al cerrarla")
	vortex.advance(LONG_STEP_S)
	assert_true(vortex.is_done(), "El vortice se cierra")
	assert_false(_main.get_isak().is_warping(), "Isak recupera el control")
	assert_eq(_main.get_isak().modulate.a, 1.0, "Isak materializado")


func test_test_switch_shows_the_welcome_without_pausing() -> void:
	EcoTextBox.pause_important = false
	_start()
	await wait_physics_frames(20)
	_finish_arrival()
	assert_true(_lines.has(WELCOME))
	assert_false(get_tree().paused, "Con el interruptor de pruebas no pausa")
