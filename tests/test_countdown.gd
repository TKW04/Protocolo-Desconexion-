# Cuenta regresiva del Mundo 5 (paso 5 de docs/propuesta-mundo-5.md §8; §3.7, patron 28
# y pruebas de §7.4): ciclo (5 s solida con 5 segmentos, aviso de 9 cuadros, se pliega
# 1 s sin colision y vuelve con otra cuenta y otro cartel), no se materializa con Isak
# dentro, Isak cae al plegarse, «tercer ciclo» (esperar cerca dos cuentas sin usarla da
# la de verdad: 10 s y «Vale, esta vez es verdad»; usarla o estar lejos no), trigger
# del atajo con trampa countdown y la sala rebajas_test carga.
extends GutTest

const IsakSim = preload("res://tests/support/isak_sim.gd")
const SCENE: PackedScene = preload("res://scenes/levels/countdown_platform.tscn")
const DOOR_SCENE: PackedScene = preload("res://scenes/levels/shortcut_door.tscn")
const ROOM_SCENE: String = "res://scenes/levels/rebajas_test.tscn"
const DT: float = 1.0 / 60.0
const T: float = 64.0

var _sim: IsakSim
var _isak: Isak
var _world: Node2D


func before_each() -> void:
	GameState.sync_rate = GameState.get_sync_rate_max()
	DebugMode.input_enabled = false
	DebugMode.reset()
	_sim = IsakSim.new(DT)
	_world = _sim.build_flat_world()
	add_child_autofree(_world)
	_sim.take_manual_control()
	_isak = _sim.isak
	_isak.global_position = Vector2(-20.0 * T, 0.0)
	await wait_physics_frames(1)
	_sim.settle()


func after_each() -> void:
	DebugMode.reset()
	DebugMode.input_enabled = true
	GameState.sync_rate = GameState.SYNC_RATE_MAX


## Cuenta con la esquina de su primera celda en (col, row) tiles (por defecto en el aire).
func _platform(col: float = 2.0, row: float = -4.0, trigger: StringName = &"") -> CountdownPlatform:
	var p := SCENE.instantiate() as CountdownPlatform
	p.object_id = &"cuenta"
	p.trigger_id = trigger
	p.position = Vector2(col * T, row * T)
	_world.add_child(p)
	p.set_physics_process(false)
	return p


func _advance(p: CountdownPlatform, seconds: float) -> void:
	for i: int in roundi(seconds / DT):
		p.advance(DT)


## Isak de pie sobre la tarjeta.
func _stand_on(p: CountdownPlatform) -> void:
	_isak.global_position = Vector2(p.get_card_rect().get_center().x, p.get_card_rect().position.y)
	_isak.velocity = Vector2.ZERO


# --- Ciclo ---

func test_counts_5_seconds_warns_folds_1_second_and_comes_back() -> void:
	var p: CountdownPlatform = _platform()
	watch_signals(p)
	assert_true(p.is_solid())
	assert_eq(p.get_cycle(), 1)
	assert_eq(p.get_sign_text(), "¡Solo por hoy!")
	assert_almost_eq(p.get_time_left(), 5.0, 0.001)
	assert_eq(p.get_lit_segments(), 5)
	assert_almost_eq(p.get_warn_s(), 0.75, 0.001, "9 cuadros a 12 fps")
	_advance(p, 4.2)
	assert_false(p.is_warning(), "A 0,8 s aun no avisa")
	assert_signal_not_emitted(p, "warning_started")
	_advance(p, 0.1)
	assert_true(p.is_warning(), "Los ultimos 9 cuadros parpadea")
	assert_signal_emitted(p, "warning_started")
	assert_true(p.is_solid())
	_advance(p, 0.75)
	assert_false(p.is_solid(), "A 0 se pliega")
	assert_signal_emitted(p, "folded")
	_advance(p, 0.9)
	assert_false(p.is_solid(), "Plegada 1 s")
	_advance(p, 0.15)
	assert_true(p.is_solid(), "Vuelve")
	assert_eq(p.get_cycle(), 2)
	assert_eq(p.get_sign_text(), "¡Últimas horas!", "Con otra cuenta")
	assert_almost_eq(p.get_time_left(), 5.0, 0.1)
	assert_signal_emit_count(p, "second_ticked", 5, "Un tic por segundo (sonido de accesibilidad)")


func test_isak_falls_when_it_folds() -> void:
	var p: CountdownPlatform = _platform()
	await wait_physics_frames(1)
	_stand_on(p)
	_sim.step(10)
	assert_true(_isak.is_on_floor())
	var top: float = p.get_card_rect().position.y
	assert_almost_eq(_isak.global_position.y, top, 1.5, "De pie sobre la cuenta")
	_advance(p, 5.05)
	assert_false(p.is_solid())
	_sim.step(20)
	assert_gt(_isak.global_position.y, top + 20.0, "Plegada: cae (sin dano)")
	assert_eq(GameState.sync_rate, GameState.get_sync_rate_max())


func test_does_not_come_back_with_isak_inside() -> void:
	var p: CountdownPlatform = _platform()
	_advance(p, 5.05)
	assert_false(p.is_solid())
	_isak.global_position = Vector2(p.get_card_rect().get_center().x, p.get_card_rect().end.y + 40.0)
	_advance(p, 1.5)
	assert_false(p.is_solid(), "Con Isak dentro no se materializa")
	_isak.global_position = Vector2(-20.0 * T, 0.0)
	p.advance(DT)
	assert_true(p.is_solid(), "Al salir, vuelve")
	assert_eq(p.get_cycle(), 2)


# --- Tercer ciclo ---

func test_waiting_two_counts_nearby_makes_the_third_one_true() -> void:
	var p: CountdownPlatform = _platform()
	watch_signals(p)
	_isak.global_position = Vector2(p.get_card_rect().position.x - 2.0 * T, 0.0)
	_advance(p, 6.05)
	assert_eq(p.get_unused_streak(), 1)
	assert_false(p.is_truth())
	_advance(p, 6.0)
	assert_eq(p.get_cycle(), 3)
	assert_true(p.is_truth(), "El tercer ciclo es el de verdad")
	assert_eq(p.get_sign_text(), "Vale, esta vez es verdad")
	assert_almost_eq(p.get_time_left(), 10.0, 0.1, "Se queda 10 s")
	assert_signal_emitted_with_parameters(p, "count_started", [3, true])
	_advance(p, 9.5)
	assert_true(p.is_solid(), "A los 9,5 s sigue")
	_advance(p, 0.6)
	assert_false(p.is_solid(), "Despues se pliega como siempre")
	_advance(p, 1.05 + 6.0 * 3.0)
	assert_false(p.is_truth(), "Una vez por intento")


func test_using_it_or_being_far_does_not_count_as_waiting() -> void:
	var used: CountdownPlatform = _platform(2.0)
	var far: CountdownPlatform = _platform(40.0)
	_stand_on(used)
	_advance(used, 5.5)
	assert_false(used.is_solid())
	assert_eq(used.get_unused_streak(), 0, "Usada: no cuenta como esperada")
	_isak.global_position = Vector2(used.get_card_rect().position.x - 2.0 * T, 0.0)
	_advance(used, 6.6)
	assert_eq(used.get_cycle(), 3)
	assert_eq(used.get_unused_streak(), 1, "Solo una esperada seguida")
	assert_false(used.is_truth(), "Todavia no")
	_advance(far, 12.1)
	assert_eq(far.get_unused_streak(), 0, "Lejos no se cuenta")
	assert_false(far.is_truth())


func test_truth_cycle_zero_turns_it_off() -> void:
	var p: CountdownPlatform = _platform()
	p.truth_cycle = 0
	_isak.global_position = Vector2(p.get_card_rect().position.x - T, 0.0)
	_advance(p, 18.2)
	assert_false(p.is_truth())


# --- Trigger del atajo ---

func test_countdown_trap_starts_the_exit_countdown() -> void:
	var exit: CountdownPlatform = _platform(10.0, -1.0, &"atajo_cuenta")
	var other: CountdownPlatform = _platform(14.0, -1.0, &"otro")
	assert_true(exit.is_waiting(), "Espera al atajo")
	assert_true(exit.is_solid(), "Solida mientras espera")
	assert_eq(exit.get_sign_text(), "")
	_advance(exit, 8.0)
	assert_true(exit.is_waiting(), "Sin cuenta hasta que salte la trampa")
	var door := DOOR_SCENE.instantiate() as ShortcutDoor
	door.object_id = &"atajo_cuenta"
	door.trap = ShortcutDoor.TRAP_COUNTDOWN
	door.position = Vector2(6.0 * T, -3.0 * T)
	_world.add_child(door)
	door.set_process(false)
	door.open()
	assert_true(door.spring_trap(_isak))
	assert_eq(exit.get_state(), CountdownPlatform.STATE_COUNTING, "La salida es una cuenta regresiva")
	assert_eq(exit.get_cycle(), 1)
	assert_true(other.is_waiting(), "Solo la de su atajo")


# --- Sala de prueba ---

func test_rebajas_test_room_loads() -> void:
	var scene := load(ROOM_SCENE) as PackedScene
	assert_not_null(scene)
	var room: Node = scene.instantiate()
	add_child_autofree(room)
	await wait_physics_frames(1)
	var counts: Array = get_tree().get_nodes_in_group(CountdownPlatform.GROUP).filter(
		func(n: Node) -> bool: return room.is_ancestor_of(n))
	assert_eq(counts.size(), 2, "Dos cuentas")
	var triggered: Array = counts.filter(func(n: Node) -> bool: return (n as CountdownPlatform).trigger_id != &"")
	assert_eq(triggered.size(), 1, "Una espera al atajo")
	assert_true((triggered[0] as CountdownPlatform).is_waiting())
	var gates: Array = get_tree().get_nodes_in_group(TermsGate.GROUP).filter(
		func(n: Node) -> bool: return room.is_ancestor_of(n))
	assert_eq(gates.size(), 1, "Terminos y condiciones")
