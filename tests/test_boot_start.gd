# Arranque del juego (2026-10-16): con una partida guardada cargada al abrir el
# juego (GameState.started_from_save: save.json o su .bak) scenes/main.tscn
# arranca en el HUB real con el flujo de siempre (fundido, vortice, energia y
# Sync Rate llenos, Eco atenuado) sin pasar por el 1-1; sin ella (archivo
# inexistente, vacio o de version desconocida), partida nueva en el 1-1 con el
# encuentro con Eco. R en el hub tras arrancar alli vuelve a resume_level_id();
# F9 borra y empieza en el 1-1. start_level_id y `--start-level=` fuerzan el
# arranque. Usa su propia ruta de guardado: nunca el user://save.json real.
extends GutTest

const EcoProgress = preload("res://tests/support/eco_progress.gd")

const MAIN_SCENE: PackedScene = preload("res://scenes/main.tscn")
const PATH: String = "user://test_boot_start_save.json"
const LONG_STEP_S: float = 5.0

var _main: LevelRunner
var _saved_path: String
var _saved_level: StringName


func before_all() -> void:
	EcoTextBox.pause_important = false


func after_all() -> void:
	EcoTextBox.pause_important = true


func before_each() -> void:
	_saved_path = GameState.save_path
	_saved_level = GameState.current_level
	GameState.current_level = GameState.NO_LEVEL
	GameState.use_save_path(PATH, true)
	DebugMode.input_enabled = false


func after_each() -> void:
	await wait_process_frames(2)
	if is_instance_valid(_main):
		_main.free()
	_main = null
	SaveFile.delete(PATH)
	DebugMode.reset()
	DebugMode.input_enabled = true
	Engine.time_scale = 1.0
	GameState.reset_progress()
	GameState.last_checkpoint.clear()
	GameState.sync_rate = GameState.SYNC_RATE_MAX
	GameState.debug_energy = GameState.DEBUG_ENERGY_MAX
	GameState.current_level = _saved_level
	GameState.save_path = _saved_path


# --- Utilidades ---

## Guarda en PATH una partida que ya llego al hub (Eco y Notas conocidos, 1-1
## completado) y la deja solo en disco (memoria a cero).
func _write_hub_save() -> void:
	EcoProgress.meet_eco_with_pulse()
	EcoProgress.meet_notas()
	GameState.mark_level_completed(&"1-1")
	GameState.unlock_level(&"1-2")
	GameState.attention_points = 12
	assert_true(GameState.save_game(), "Guardado de prueba escrito")
	GameState.reset_progress()


## Simula abrir el juego: GameState carga PATH como al arrancar.
func _boot() -> void:
	GameState.current_level = GameState.NO_LEVEL
	GameState.use_save_path(PATH, false)


## Instancia scenes/main.tscn sin forzar el arranque (como el juego).
func _start_main(forced: String = "") -> void:
	_main = MAIN_SCENE.instantiate() as LevelRunner
	_main.auto_advance = false
	_main.start_level_id = forced
	add_child(_main)


func _finish_fades() -> void:
	_main.advance(LONG_STEP_S)
	_main.advance(LONG_STEP_S)
	assert_eq(_main.get_phase(), LevelRunner.Phase.PLAYING)


func _write_raw(text: String) -> void:
	var file := FileAccess.open(PATH, FileAccess.WRITE)
	file.store_string(text)
	file.close()


func _assert_new_game_in_1_1() -> void:
	assert_false(_main.is_in_hub(), "Partida nueva: no arranca en el hub")
	assert_eq(_main.get_level_id(), "1-1")
	assert_not_null(_main.get_level(), "1-1 cargado")
	var encounter := _main.get_level().get_node(^"Objects/eco_encuentro") as EcoEncounter
	assert_false(encounter.is_done(), "El encuentro con Eco esta por hacer")
	assert_false(GameState.is_ability_unlocked(GameState.ABILITY_PULSE), "Sin pulso hasta el encuentro")


# --- Con partida guardada: hub ---

func test_valid_save_starts_in_hub() -> void:
	_write_hub_save()
	_boot()
	assert_true(GameState.started_from_save, "Se cargo una partida al arrancar")
	GameState.debug_energy = 5.0
	GameState.sync_rate = 30.0
	_start_main()
	assert_true(_main.is_in_hub(), "Con guardado arranca en el hub")
	assert_null(_main.get_level(), "Sin pasar por el 1-1")
	var hub: HubRoom = _main.get_hub()
	assert_eq(hub.get_scene_file_path(), "res://scenes/hub/hub.tscn")
	assert_eq(_main.get_fade_alpha(), 1.0, "Empieza fundido a negro")
	assert_eq(hub.get_arrival_vortex().get_phase(), WarpVortex.Phase.HELD, "El vortice espera al fundido")
	assert_almost_eq(GameState.debug_energy, GameState.get_debug_energy_max(), 0.001, "Energia llena")
	assert_almost_eq(GameState.sync_rate, GameState.get_sync_rate_max(), 0.001, "Sync Rate lleno")
	assert_eq(GameState.lives, GameState.lives_max, "Vidas al maximo")
	assert_false(GameState.has_trash_pending(), "Nada en la papelera")
	assert_eq(GameState.attention_points, 12, "Progreso de la copia")
	assert_not_null(hub.get_eco_companion(), "Eco acompana")
	assert_true(hub.get_eco_companion().is_dim(), "Eco atenuado en el hub")
	assert_true(hub.get_notas().is_powered(), "Notas encendida")
	assert_null(hub.get_notas_intro(), "Notas ya conocida: sin presentacion")
	_finish_fades()
	assert_ne(hub.get_arrival_vortex().get_phase(), WarpVortex.Phase.HELD, "Al acabar el fundido Isak llega")
	hub.get_arrival_vortex().advance(LONG_STEP_S)
	assert_true(hub.has_arrived())
	assert_null(hub.get_notas_intro(), "Tampoco tras la llegada")
	assert_false(GameState.has_unsaved_changes(), "El arranque no marca «sin guardar»")
	assert_eq(QuitGuard.decide(GameState.has_unsaved_changes(), QuitGuard.can_save_here(get_tree())),
		QuitGuard.Decision.QUIT, "Cerrar no pregunta")
	assert_eq(_main.get_level_id(), "1-1", "Ultimo nivel para R: el mas avanzado (1-1)")


func test_corrupt_save_with_valid_backup_starts_in_hub() -> void:
	_write_hub_save()
	_boot()
	assert_true(GameState.save_game(), "Segunda copia: la primera queda en .bak")
	GameState.reset_progress()
	_write_raw("{ esto no es json")
	_boot()
	assert_true(FileAccess.file_exists(PATH + SaveFile.CORRUPT_SUFFIX), "El principal se aparta")
	assert_true(GameState.started_from_save, "Se cargo la copia .bak")
	_start_main()
	assert_true(_main.is_in_hub(), "Con la copia .bak arranca en el hub")
	assert_false(GameState.has_unsaved_changes())


func test_migrated_save_without_notas_shows_notas_intro() -> void:
	# Guardado v1 de antes de llegar al hub (sin 1-1 completado ni tutorial):
	# Notas es desconocida y el hub la presenta, como en la primera llegada.
	_write_raw(JSON.stringify({"version": 1, "attention_points": 3}))
	_boot()
	assert_true(GameState.started_from_save)
	assert_false(GameState.has_met_ally(GameState.ALLY_NOTAS))
	_start_main()
	assert_true(_main.is_in_hub())
	assert_not_null(_main.get_hub().get_notas_intro(), "Se presenta a Notas")
	assert_false(_main.get_hub().get_notas().is_powered(), "Notas apagada hasta su presentacion")


func test_migrated_veteran_save_skips_notas_intro() -> void:
	_write_raw(JSON.stringify({"version": 2, "completed_levels": ["1-1"], "unlocked_levels": ["1-2"]}))
	_boot()
	_start_main()
	assert_true(_main.is_in_hub())
	assert_null(_main.get_hub().get_notas_intro(), "Veterano: Notas ya conocida")
	assert_not_null(_main.get_hub().get_eco_companion(), "Eco conocido acompana")


# --- Sin partida guardada: 1-1 ---

func test_no_save_starts_new_game_in_1_1() -> void:
	_boot()
	assert_false(GameState.started_from_save)
	_start_main()
	_assert_new_game_in_1_1()


func test_empty_file_starts_in_1_1() -> void:
	_write_raw("")
	_boot()
	assert_false(GameState.started_from_save)
	_start_main()
	_assert_new_game_in_1_1()


func test_unknown_version_starts_in_1_1_and_quarantines() -> void:
	_write_raw(JSON.stringify({"version": 99, "attention_points": 50}))
	_boot()
	assert_false(GameState.started_from_save)
	assert_true(FileAccess.file_exists(PATH + SaveFile.CORRUPT_SUFFIX), "Guardado apartado como .corrupt")
	assert_false(FileAccess.file_exists(PATH))
	_start_main()
	_assert_new_game_in_1_1()
	assert_eq(GameState.attention_points, 0)


# --- R y F9 tras arrancar en el hub ---

func test_restart_in_hub_after_booting_in_hub() -> void:
	_write_hub_save()
	_boot()
	_start_main()
	_finish_fades()
	_main.get_hub().get_arrival_vortex().advance(LONG_STEP_S)
	GameState.lives = 1
	assert_true(_main.request_restart(), "R se acepta en el hub")
	_finish_fades()
	assert_false(_main.is_in_hub())
	assert_eq(_main.get_level_id(), "1-1")
	assert_not_null(_main.get_level())
	assert_eq(GameState.lives, GameState.lives_max, "Empezar un intento repone las vidas")
	var encounter := _main.get_level().get_node(^"Objects/eco_encuentro") as EcoEncounter
	assert_true(encounter.is_done(), "Con Eco conocido el encuentro no se repite")
	assert_false(GameState.has_unsaved_changes())


func test_wipe_in_hub_starts_new_game_in_1_1() -> void:
	_write_hub_save()
	_boot()
	_start_main()
	_finish_fades()
	_main.wipe_enabled = true
	assert_true(_main.wipe_save_and_restart())
	assert_false(FileAccess.file_exists(PATH), "Guardado borrado")
	assert_false(GameState.started_from_save)
	_finish_fades()
	_assert_new_game_in_1_1()
	assert_false(GameState.has_met_ally(GameState.ALLY_ECO))


# --- Arranque forzado ---

func test_start_level_id_overrides_save() -> void:
	_write_hub_save()
	_boot()
	_start_main("1-1")
	assert_false(_main.is_in_hub(), "start_level_id fuerza el nivel")
	assert_eq(_main.get_level_id(), "1-1")


func test_start_level_id_hub_forces_hub() -> void:
	_start_main(LevelRunner.START_HUB)
	assert_true(_main.is_in_hub(), "start_level_id = hub fuerza el hub")
	assert_eq(_main.get_level_id(), "1-1", "Sin progreso, R vuelve al 1-1")


func test_start_target_rules() -> void:
	_start_main("1-1")
	assert_eq(_main.start_target("", true), LevelRunner.START_HUB)
	assert_eq(_main.start_target("", false), "1-1", "current_level del 1-1 cargado")
	GameState.current_level = GameState.NO_LEVEL
	assert_eq(_main.start_target("", false), "1-1", "default_level")
	assert_eq(_main.start_target("tower_test", true), "tower_test", "Forzado gana")
	assert_eq(LevelRunner.debug_start_arg(PackedStringArray(["--x", "--start-level=hub"])), "hub")
	assert_eq(LevelRunner.debug_start_arg(PackedStringArray(["--start-level=1-1"])), "1-1")
	assert_eq(LevelRunner.debug_start_arg(PackedStringArray(["--meet-ally=calc"])), "")


func test_resume_level_id_rule() -> void:
	_start_main("1-1")
	GameState.current_level = GameState.NO_LEVEL
	assert_eq(HubWorlds.most_advanced_level(), &"1-1", "Mundo 1 abierto: el 1-1")
	assert_eq(_main.resume_level_id(), "1-1")
	GameState.unlock_level(&"1-2")
	assert_eq(_main.resume_level_id(), "1-1", "El 1-2 aun no es jugable")
	GameState.current_level = &"tower_test"
	assert_eq(_main.resume_level_id(), "tower_test", "El ultimo nivel jugado en la sesion manda")
	GameState.current_level = &"9-9"
	assert_eq(_main.resume_level_id(), "1-1", "Sin escena: el mas avanzado")
