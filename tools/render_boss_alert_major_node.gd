## Logica de tools/render_boss_alert_major.gd (capturas del arte final de Alerta Mayor).
extends Node

signal finished(code: int)

const SCENE: String = "res://scenes/levels/1-boss.tscn"
const DEFAULT_OUT: String = "user://render_boss_alert_major"
const DT: float = 1.0 / 60.0

var _out: String
var _level: Node
var _boss: AlertMajor


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	GameState.use_save_path("user://tool_save.json", true)
	var args: PackedStringArray = OS.get_cmdline_user_args()
	_out = args[0] if args.size() > 0 else ProjectSettings.globalize_path(DEFAULT_OUT)
	DirAccess.make_dir_recursive_absolute(_out)
	_level = (load(SCENE) as PackedScene).instantiate()
	_boss = _level.get_node(^"Objects/alerta_mayor") as AlertMajor
	_boss.intro_on_arrival = false
	_boss.defeat_sequence = false
	_boss.auto_process = false
	get_tree().root.add_child(_level)
	for i: int in 30:
		await get_tree().physics_frame
	_boss.start()
	await _steps(1.0)
	await _save("01_hover.png")
	_boss.call(&"_inflate", true)
	await _steps(0.5)
	await _save("02_inflate.png")
	_boss.call(&"_inflate", false)
	_boss.move_body_to(_boss.get_spot_center(&"floor_center"), true)
	await _steps(0.12)
	await _save("03_descend.png")
	await _steps(1.0)
	await _save("04_window.png")
	_boss.move_body_to(_boss.get_hover_center(12.0), false)
	await _steps(0.2)
	await _save("05_ascend.png")
	await _steps(1.0)
	while _boss.get_phase() < 3:
		_boss.take_core_hit(1)
	for node: Node in BossBase.phase_nodes(_level):
		node.set_physics_process(true)
	await _until(func() -> bool: return _boss.get_round_state() == &"split", 3.0)
	await _steps(0.4)
	await _save("06_split.png")
	await _until(func() -> bool: return _boss.get_round_state() == &"land", 3.0)
	await _steps(0.1)
	await _save("07_clones_land.png")
	await _until(func() -> bool: return _boss.get_round_state() == &"launch", 4.0)
	await _steps(0.5)
	await _save("08_launch_warn.png")
	await _until(func() -> bool: return _boss.get("_launch_phase") == &"lunge", 2.0)
	await _steps(0.12)
	await _save("09_lunge.png")
	_boss.play_disarm()
	for i: int in 18:
		await get_tree().physics_frame
	await _save("10_disarm.png")
	finished.emit(0)


## Avanza el jefe `seconds` del mundo a mano (con un cuadro de dibujo por paso).
func _steps(seconds: float) -> void:
	for i: int in ceili(seconds / DT):
		_boss.advance(DT)
		if not _boss.is_fighting():
			_boss.call(&"_advance_move", DT)
		await get_tree().physics_frame


func _until(cond: Callable, max_s: float) -> void:
	var t: float = 0.0
	while not bool(cond.call()) and t < max_s:
		_boss.advance(DT)
		t += DT
		await get_tree().physics_frame


func _save(file_name: String) -> void:
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var image: Image = get_tree().root.get_texture().get_image()
	var path: String = _out.path_join(file_name)
	var err: Error = image.save_png(path)
	print("render_boss_alert_major: %s (%s) move=%s ronda=%s" % [path, error_string(err), _boss.get_move(),
		_boss.get_round_state()])
