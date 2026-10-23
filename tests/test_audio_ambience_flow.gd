# Ambiente de fondo en el flujo real del Mundo 2 (arreglo 2026-10-23 tras la
# prueba del usuario: «la musica del ambiente de cada mapa se esta mezclando»).
# Con el LevelRunner real: 2-1 -> muerte -> hub -> 2-2 -> 2-3 -> 2-boss (con
# la musica del jefe) -> hub. En cada momento suena como mucho UN bucle de
# fondo (AudioManager.loop_count), el que toca, y nada se acumula. Antes, la
# musica del feed (mus_w2_level, segundo ambiente del ScrollEdgeOverlay) no se
# paraba al salir del nivel y se sumaba nivel tras nivel.
extends GutTest

const MAIN_SCENE: PackedScene = preload("res://scenes/main.tscn")
const PATH: String = "user://test_audio_ambience_flow.json"

var _saved_path: String
var _main: LevelRunner


func before_all() -> void:
	EcoTextBox.pause_important = false


func after_all() -> void:
	EcoTextBox.pause_important = true


func before_each() -> void:
	_saved_path = GameState.save_path
	GameState.use_save_path(PATH, true)
	GameState.reset_progress()
	AudioManager.set_external_dir("")
	AudioManager.load_catalog(AudioManager.DATA_PATH)


func after_each() -> void:
	if is_instance_valid(_main):
		_main.free()
	_main = null
	get_tree().paused = false
	DebugMode.reset()
	Engine.time_scale = 1.0
	SaveFile.delete(PATH)
	GameState.reset_progress()
	GameState.save_path = _saved_path
	GameState.sync_rate = GameState.SYNC_RATE_MAX
	GameState.debug_energy = GameState.DEBUG_ENERGY_MAX
	AudioManager.set_external_dir(null)
	AudioManager.load_catalog(AudioManager.DATA_PATH)


func _expect(id: StringName, moment: String) -> void:
	assert_eq(AudioManager.loop_count(), 1, "%s: un solo bucle de fondo" % moment)
	assert_eq(AudioManager.ambience_id(), id, "%s: suena %s" % [moment, id])


func _find(node: Node, cls: Script) -> Node:
	if is_instance_of(node, cls):
		return node
	for child: Node in node.get_children():
		var found: Node = _find(child, cls)
		if found != null:
			return found
	return null


func test_one_background_loop_through_the_world_2_flow() -> void:
	_main = MAIN_SCENE.instantiate() as LevelRunner
	_main.start_level_id = "2-1"
	add_child(_main)
	await wait_physics_frames(10)
	_expect(&"mus_w2_level", "2-1")
	_main.get_isak().die()
	await wait_seconds(2.5)
	_expect(&"mus_w2_level", "2-1 tras reaparecer")
	_main._show_hub("2-1", 0)
	await wait_physics_frames(5)
	_expect(&"amb_hub", "hub")
	for level: String in ["2-2", "2-3"]:
		assert_true(_main.start_level(level), level)
		await wait_physics_frames(5)
		_expect(&"mus_w2_level", level)
	assert_true(_main.start_level("2-boss"), "2-boss")
	await wait_physics_frames(5)
	assert_eq(AudioManager.loop_count(), 0, "Arena antes de la pelea: sin musica del feed")
	var boss: Node = _find(_main.get_level(), Autoplay)
	assert_not_null(boss, "Autoplay en la arena")
	boss.call(&"_start_music")
	await wait_physics_frames(2)
	_expect(&"mus_boss2", "pelea con Autoplay")
	_main._show_hub("2-boss", 0)
	await wait_physics_frames(5)
	_expect(&"amb_hub", "hub otra vez")
	await wait_seconds(AudioManager.ambience_fade_s() + 0.3)
	assert_eq(AudioManager.fading_count(), 0, "Los fundidos terminan")
	var playing: int = 0
	for child: Node in AudioManager.get_children():
		if child is AudioStreamPlayer and (child as AudioStreamPlayer).playing \
				and bool(AudioManager.get_entry(child.get_meta(&"sound_id", &"")).get("loop", false)):
			playing += 1
	assert_eq(playing, 1, "Un solo reproductor de bucle sonando de verdad")
