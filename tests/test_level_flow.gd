# Flujo de juego del 1-1 (paso 16) con la escena principal real (scenes/main.tscn,
# LevelRunner): estado inicial, punto de sincronizacion, muerte y reaparicion,
# estado de los objetos al reaparecer, red de seguridad, fosos con fondo, final
# del nivel -> hub provisional -> reinicio desde cero, sin fugas de senales ni
# instancias tras varios ciclos, y el bot de recorrido (tools/play_level_bot.gd).
# El flujo se avanza a mano (auto_advance = false); Isak usa su fisica real con
# una entrada falsa quieta.
extends GutTest

const MAIN_SCENE: PackedScene = preload("res://scenes/main.tscn")
const TILE: float = 64.0
const LAND_FRAMES: int = 90
## Mas que cualquier fundido o espera del flujo (data/flow.json).
const LONG_STEP_S: float = 5.0

var _main: LevelRunner
var _isak: Isak
var _saved_level: StringName
var _saved_pulse: bool
var _saved_debug: bool


## Las lineas importantes de Eco pausarian el nivel esperando al jugador; aqui
## nadie confirma (la pausa se prueba en test_eco_text_box.gd).
func before_all() -> void:
	EcoTextBox.pause_important = false


func after_all() -> void:
	EcoTextBox.pause_important = true


func before_each() -> void:
	_saved_level = GameState.current_level
	_saved_pulse = GameState.is_ability_unlocked(GameState.ABILITY_PULSE)
	_saved_debug = GameState.is_ability_unlocked(GameState.ABILITY_DEBUG)
	DebugMode.input_enabled = false


func after_each() -> void:
	if is_instance_valid(_main):
		_main.free()
	_main = null
	_isak = null
	DebugMode.reset()
	DebugMode.input_enabled = true
	Engine.time_scale = 1.0
	GameState.current_level = _saved_level
	GameState.set_ability_unlocked(GameState.ABILITY_PULSE, _saved_pulse)
	GameState.set_ability_unlocked(GameState.ABILITY_DEBUG, _saved_debug)
	GameState.sync_rate = GameState.SYNC_RATE_MAX
	GameState.debug_energy = GameState.DEBUG_ENERGY_MAX
	GameState.reset_progress()
	GameState.last_checkpoint.clear()


# --- Utilidades ---

func _start() -> void:
	_main = MAIN_SCENE.instantiate() as LevelRunner
	_main.auto_advance = false
	_main.start_level_id = "1-1"
	add_child(_main)
	_main.advance(LONG_STEP_S)
	_hook_isak()
	await wait_physics_frames(LAND_FRAMES)


func _hook_isak() -> void:
	_isak = _main.get_isak()
	_isak.input = PlayerInput.new()


func _level() -> GeneratedLevel:
	return _main.get_level()


func _checkpoint() -> Checkpoint:
	return _level().get_node(^"Checkpoints/sync_1") as Checkpoint


func _bubble() -> AlertBubble:
	return _level().get_node_or_null(^"Enemies/burbuja_1") as AlertBubble


## Pone a Isak de pie en la columna `col` sobre la fila de suelo `floor_row`.
func _teleport(col: float, floor_row: int = 10) -> void:
	_isak.global_position = Vector2((col + 0.5) * TILE, floor_row * TILE)
	_isak.velocity = Vector2.ZERO


## Mata a Isak y avanza el flujo hasta que vuelve a jugar.
func _die_and_respawn() -> void:
	GameState.sync_rate = GameState.SYNC_RATE_MIN
	assert_true(_isak.is_dead(), "Muere con Sync Rate 0")
	assert_eq(_main.get_phase(), LevelRunner.Phase.DYING)
	_main.advance(_main.get_death_wait_s() + 0.01)
	_main.advance(LONG_STEP_S)
	_main.advance(LONG_STEP_S)
	assert_eq(_main.get_phase(), LevelRunner.Phase.PLAYING)


func _complete_level() -> void:
	var terminal: ExitTerminal = _level().get_node(^"Objects/terminal_salida") as ExitTerminal
	assert_true(terminal.activate(_isak), "La terminal se activa")
	terminal.advance(LONG_STEP_S)
	terminal.get_vortex().advance(LONG_STEP_S)
	_main.advance(LONG_STEP_S)
	_main.advance(LONG_STEP_S)


func _restart_from_hub() -> void:
	var hub: HubPlaceholder = _main.get_hub()
	hub.skip_input_delay()
	assert_true(hub.request_restart(), "El hub acepta salto")
	_main.advance(LONG_STEP_S)
	_main.advance(LONG_STEP_S)
	_hook_isak()


func _eventbus_connections() -> int:
	var total: int = 0
	for info: Dictionary in EventBus.get_signal_list():
		total += EventBus.get_signal_connection_list(StringName(info["name"])).size()
	return total


func _count_in_tree(script_class: String) -> int:
	var count: int = 0
	var stack: Array[Node] = [get_tree().root]
	while not stack.is_empty():
		var node: Node = stack.pop_back()
		if node.is_queued_for_deletion():
			continue
		var script: Script = node.get_script() as Script
		if script != null and script.get_global_name() == script_class:
			count += 1
		stack.append_array(node.get_children())
	return count


# --- Pruebas ---

func test_main_scene_is_project_main_and_loads_1_1_with_initial_state() -> void:
	assert_eq(ProjectSettings.get_setting("application/run/main_scene"), "res://scenes/main.tscn")
	# Estado "sucio" de una partida anterior: el nivel empieza de cero.
	GameState.sync_rate = 30.0
	GameState.debug_energy = 20.0
	GameState.attention_points = 5
	GameState.set_last_checkpoint(&"1-1", &"sync_1")
	Engine.time_scale = 0.5
	await _start()
	assert_eq(_main.get_level_id(), "1-1")
	assert_eq(_level().level_id, "1-1")
	assert_eq(GameState.sync_rate, GameState.SYNC_RATE_MAX)
	assert_eq(GameState.debug_energy, 100.0)
	assert_eq(GameState.attention_points, 5, "Los puntos acumulados se conservan (2026-10-14)")
	assert_eq(GameState.get_last_checkpoint(&"1-1"), &"")
	assert_true(GameState.is_ability_unlocked(GameState.ABILITY_PULSE), "Pulso en el 1-1")
	assert_false(GameState.is_ability_unlocked(GameState.ABILITY_DEBUG), "Sin Debug en el 1-1")
	assert_eq(Engine.time_scale, 1.0)
	assert_eq(GameState.world_time_scale, 1.0)
	assert_eq(_count_in_tree("Hud"), 1)
	assert_eq(_count_in_tree("EcoTextBox"), 1)
	assert_true(_isak.is_on_floor(), "Isak cae desde P al suelo")
	assert_eq(_main.get_fade_alpha(), 0.0, "Fundido de entrada terminado")
	assert_gt(_main.get_transition_layer().layer, 20, "Fundido por encima del HUD y del hub")


func test_checkpoint_saved_on_touch_and_not_before() -> void:
	await _start()
	var checkpoint: Checkpoint = _checkpoint()
	var watcher: Array[StringName] = []
	checkpoint.activated.connect(func(id: StringName) -> void: watcher.append(id))
	assert_false(checkpoint.is_taken())
	assert_eq(checkpoint.get_frame(), 0, "Bandera apagada")
	_teleport(checkpoint.global_position.x / TILE - 4.0)
	await wait_physics_frames(10)
	assert_false(checkpoint.is_taken(), "Lejos no se guarda")
	assert_eq(GameState.get_last_checkpoint(&"1-1"), &"")
	GameState.sync_rate = 50.0
	_teleport(checkpoint.global_position.x / TILE - 0.5)
	await wait_physics_frames(5)
	assert_true(checkpoint.is_taken(), "Al tocarlo se guarda")
	assert_true(checkpoint.is_active())
	assert_eq(GameState.get_last_checkpoint(&"1-1"), &"sync_1")
	assert_eq(GameState.sync_rate, GameState.SYNC_RATE_MAX, "Repone el Sync Rate (V2)")
	assert_ne(checkpoint.get_frame(), 0, "Bandera encendida")
	_teleport(checkpoint.global_position.x / TILE + 3.0)
	await wait_physics_frames(5)
	_teleport(checkpoint.global_position.x / TILE - 0.5)
	await wait_physics_frames(5)
	assert_eq(watcher.size(), 1, "Se guarda una sola vez")


func test_death_respawns_at_checkpoint_with_full_sync_and_no_debug() -> void:
	await _start()
	var checkpoint: Checkpoint = _checkpoint()
	checkpoint.activate()
	_teleport(154.0)
	await wait_physics_frames(5)
	# Debug encendido (desbloqueado a mano) y escala del motor tocada.
	GameState.set_ability_unlocked(GameState.ABILITY_DEBUG, true)
	DebugMode.step(0.0, false)
	DebugMode.step(LONG_STEP_S, true)
	DebugMode.step(0.5, true)
	assert_true(DebugMode.is_active(), "Debug activo antes de morir")
	assert_lt(GameState.world_time_scale, 1.0)
	Engine.time_scale = 0.5
	GameState.sync_rate = GameState.SYNC_RATE_MIN
	assert_true(_isak.is_dead())
	assert_false(DebugMode.is_active(), "El Debug se apaga al morir")
	assert_eq(_isak.get_animation(), Isak.ANIM_DEATH)
	assert_almost_eq(_main.get_death_wait_s(), 19.0 / 12.0 + 0.5, 0.001, "Animacion death + pausa")
	_main.advance(_main.get_death_wait_s() - 0.05)
	assert_eq(_main.get_phase(), LevelRunner.Phase.DYING, "Espera a que acabe la animacion")
	assert_almost_eq(_isak.global_position.x, 154.5 * TILE, 2.0, "Aun no se ha movido")
	_main.advance(0.1)
	assert_eq(_main.get_phase(), LevelRunner.Phase.FADE_OUT)
	_main.advance(LONG_STEP_S)
	assert_eq(_main.get_phase(), LevelRunner.Phase.FADE_IN)
	assert_false(_isak.is_dead(), "Reaparece")
	assert_true(_isak.global_position.is_equal_approx(checkpoint.get_spawn_position()), "En el checkpoint")
	assert_eq(GameState.sync_rate, GameState.SYNC_RATE_MAX)
	assert_true(_isak.is_invulnerable(), "Invulnerable un momento")
	assert_false(DebugMode.is_active())
	assert_eq(GameState.world_time_scale, 1.0)
	assert_eq(Engine.time_scale, 1.0)
	_main.advance(LONG_STEP_S)
	assert_eq(_main.get_phase(), LevelRunner.Phase.PLAYING)
	assert_eq(_main.get_fade_alpha(), 0.0)
	await wait_physics_frames(5)
	assert_true(_isak.is_on_floor(), "De pie junto al checkpoint")


func test_death_without_checkpoint_respawns_at_start() -> void:
	await _start()
	var start: Vector2 = _main.get_start_position()
	assert_eq(start, Vector2(4.5 * TILE, 10.0 * TILE), "P del grid (4, 9), en el suelo")
	_teleport(30.0)
	await wait_physics_frames(5)
	_die_and_respawn()
	assert_true(_isak.global_position.is_equal_approx(start), "Reaparece en P")
	assert_eq(GameState.sync_rate, GameState.SYNC_RATE_MAX)
	assert_eq(_main.get_death_count(), 1)


func test_level_objects_keep_state_after_respawn() -> void:
	await _start()
	var receiver: PulseReceiver = _level().get_node(^"Objects/receiver_56_9") as PulseReceiver
	var bridge: PulseBridge = _level().get_node(^"Objects/puente_1") as PulseBridge
	var popup: PopupBlocker = _level().get_node(^"Objects/popup_1") as PopupBlocker
	var bubble: AlertBubble = _bubble()
	var spawn := Vector2(132.5 * TILE, 10.0 * TILE)  # celda E (132, 9) del grid
	receiver.activate()
	bridge.advance(LONG_STEP_S)
	popup.close()
	popup.advance(LONG_STEP_S)
	assert_true(bridge.is_extended() and popup.is_closed())
	# Recoge un punto de atencion.
	var point: AttentionPoint = _level().get_node(^"AttentionPoints/Point_8_9") as AttentionPoint
	_teleport(8.0)
	await wait_physics_frames(5)
	assert_true(not is_instance_valid(point) or point.is_taken(), "Punto recogido")
	assert_eq(GameState.attention_points, 1)
	# Burbuja aturdida y desplazada.
	bubble.stun()
	bubble.global_position = spawn + Vector2(100.0, 0.0)
	_teleport(30.0)
	await wait_physics_frames(5)
	_die_and_respawn()
	assert_true(receiver.is_active(), "Receptor activado")
	assert_true(bridge.is_extended(), "Puente extendido")
	assert_true(popup.is_closed(), "Pop-up cerrado")
	assert_null(_level().get_node_or_null(^"AttentionPoints/Point_8_9"), "Punto recogido sigue recogido")
	assert_eq(GameState.attention_points, 1, "Se conservan los puntos")
	assert_eq(bubble.get_state(), AlertBubble.STATE_PATROL, "Burbuja des-aturdida")
	assert_true(bubble.global_position.is_equal_approx(spawn), "Burbuja en su sitio")


func test_popped_bubble_stays_popped_after_respawn() -> void:
	await _start()
	var bubble: AlertBubble = _bubble()
	bubble.free_on_pop = false
	bubble.stun()
	bubble.pop()
	_die_and_respawn()
	assert_eq(bubble.get_state(), AlertBubble.STATE_POPPED, "Sigue reventada")


func test_safety_net_respawns_without_sync_penalty() -> void:
	await _start()
	GameState.sync_rate = 60.0
	_isak.global_position = Vector2(30.0 * TILE, _main.get_fall_limit_y() + 10.0)
	await wait_physics_frames(1)
	assert_eq(_main.get_phase(), LevelRunner.Phase.FADE_OUT, "Salta la red de seguridad")
	assert_eq(_main.get_fall_count(), 1)
	_main.advance(LONG_STEP_S)
	assert_true(_isak.global_position.is_equal_approx(_main.get_start_position()), "Sin checkpoint: P")
	assert_eq(GameState.sync_rate, 60.0, "No quita Sync Rate (PROPUESTA)")
	assert_false(_isak.is_dead())
	_main.advance(LONG_STEP_S)
	assert_eq(_main.get_phase(), LevelRunner.Phase.PLAYING)
	_checkpoint().activate()
	_isak.global_position = Vector2(80.0 * TILE, _main.get_fall_limit_y() + 10.0)
	await wait_physics_frames(1)
	_main.advance(LONG_STEP_S)
	assert_true(_isak.global_position.is_equal_approx(_checkpoint().get_spawn_position()), "Con checkpoint: alli")
	assert_eq(_main.get_death_count(), 0, "No cuenta como muerte")


func test_pits_have_floor_and_do_not_kill() -> void:
	await _start()
	# Foso del Tramo 1 (columnas 22-23, fondo en la fila 12) y foso del puente
	# retraido (columnas 60-64, fondo en la fila 13).
	for spot: Vector2i in [Vector2i(22, 12), Vector2i(61, 13)]:
		_isak.global_position = Vector2((spot.x + 0.5) * TILE, (spot.y - 2) * TILE)
		_isak.velocity = Vector2.ZERO
		await wait_physics_frames(60)
		assert_true(_isak.is_on_floor(), "Fondo del foso en la columna %d" % spot.x)
		assert_almost_eq(_isak.global_position.y, spot.y * TILE, 1.0)
		assert_false(_isak.is_dead())
		assert_eq(GameState.sync_rate, GameState.SYNC_RATE_MAX, "Caer al foso no quita Sync Rate")
		assert_eq(_main.get_fall_count(), 0, "No salta la red de seguridad")
		assert_eq(_main.get_phase(), LevelRunner.Phase.PLAYING)


func test_level_completed_goes_to_hub_and_restart_resets_everything() -> void:
	await _start()
	_level().get_node(^"Objects/receiver_56_9").call(&"activate")
	(_level().get_node(^"Objects/puente_1") as PulseBridge).advance(LONG_STEP_S)
	var popup: PopupBlocker = _level().get_node(^"Objects/popup_1") as PopupBlocker
	popup.close()
	popup.advance(LONG_STEP_S)
	_bubble().stun()
	_bubble().pop()
	_checkpoint().activate()
	GameState.add_attention_points(7)
	var shown: Array = []
	_main.hub_shown.connect(func(id: String, points: int) -> void: shown.append([id, points]))
	_complete_level()
	assert_true(_main.is_in_hub(), "Pantalla provisional del hub")
	assert_null(_main.get_level(), "El nivel se descarga")
	assert_eq(shown, [["1-1", 7]])
	var hub: HubPlaceholder = _main.get_hub()
	assert_eq(hub.get_line_text(&"points"), "Puntos de atención: 7")
	assert_eq(hub.get_line_text(&"completed"), "Nivel completado: Bandeja de entrada")
	assert_true(GameState.is_level_completed(&"1-1"), "1-1 completado")
	assert_true(GameState.is_level_unlocked(&"1-2"), "1-2 desbloqueado (unlocks del JSON)")
	assert_false(ResourceLoader.exists("res://scenes/levels/1-2.tscn"), "El 1-2 no existe ni se carga")
	assert_eq(_main.get_phase(), LevelRunner.Phase.PLAYING)
	_restart_from_hub()
	assert_false(_main.is_in_hub())
	assert_eq(_main.get_level_id(), "1-1")
	await wait_physics_frames(5)
	assert_eq(GameState.sync_rate, GameState.SYNC_RATE_MAX)
	assert_eq(GameState.attention_points, 7, "Los puntos acumulados se conservan (2026-10-14)")
	assert_eq(GameState.get_last_checkpoint(&"1-1"), &"", "Sin checkpoint")
	assert_false((_level().get_node(^"Objects/puente_1") as PulseBridge).is_extended(), "Puente retraido")
	assert_true((_level().get_node(^"Objects/popup_1") as PopupBlocker).is_open(), "Pop-up abierto")
	assert_not_null(_bubble(), "Burbuja viva")
	assert_eq(_bubble().get_state(), AlertBubble.STATE_PATROL)
	assert_false(_checkpoint().is_taken())
	assert_eq(_checkpoint().get_frame(), 0)
	assert_true(GameState.is_level_completed(&"1-1"), "El registro de completado se conserva")


func test_no_leaks_after_three_death_and_three_restart_cycles() -> void:
	await _start()
	await wait_process_frames(2)
	var base_connections: int = _eventbus_connections()
	for i: int in 3:
		_teleport(20.0 + i)
		await wait_physics_frames(3)
		_die_and_respawn()
		await wait_physics_frames(3)
	assert_eq(_eventbus_connections(), base_connections, "Sin conexiones nuevas tras morir 3 veces")
	assert_eq(_isak.died.get_connections().size(), 1, "Una sola conexion a died")
	for i: int in 3:
		_complete_level()
		await wait_process_frames(2)
		_restart_from_hub()
		await wait_process_frames(2)
	assert_eq(_eventbus_connections(), base_connections, "Sin conexiones colgadas tras 3 reinicios")
	assert_eq(_count_in_tree("Hud"), 1, "Un solo HUD")
	assert_eq(_count_in_tree("EcoTextBox"), 1, "Un solo cuadro de Eco")
	assert_eq(_count_in_tree("GeneratedLevel"), 1, "Un solo nivel")
	assert_eq(_count_in_tree("HubPlaceholder"), 0, "Sin hub")
	assert_eq(Engine.time_scale, 1.0)
	assert_eq(GameState.world_time_scale, 1.0)
	assert_eq(_main.get_transition_layer().get_child_count(), 1, "Un solo fundido")


func test_bot_plays_the_level_to_the_end() -> void:
	var output: Array = []
	var args := PackedStringArray(["--headless", "--fixed-fps", "60", "--path",
		ProjectSettings.globalize_path("res://"), "-s", "res://tools/play_level_bot.gd"])
	var code: int = OS.execute(OS.get_executable_path(), args, output, true)
	var text: String = "\n".join(PackedStringArray(output))
	assert_eq(code, 0, "El bot termina el nivel:\n" + text)
	assert_string_contains(text, "play_level_bot: OK")
	assert_string_contains(text, "pulso: receptor")
	assert_string_contains(text, "pulso: burbuja")
	assert_string_contains(text, "pulso: pop-up")
	assert_string_contains(text, "reaparece en el checkpoint")
