## Logica de tools/render_hub_lives.gd (ver su cabecera).
extends Node

const MAIN_SCENE: String = "res://scenes/main.tscn"
const SAVE_PATH: String = "user://render_hub_lives_save.json"
const DEFAULT_OUT: String = "user://hub_lives"
const TILE: float = 64.0
const WAIT_S: float = 30.0

var _ok: bool = true
var _out: String = ""


signal finished(code: int)


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	_out = args[0] if args.size() > 0 else ProjectSettings.globalize_path(DEFAULT_OUT)
	DirAccess.make_dir_recursive_absolute(_out)
	GameState.use_save_path(SAVE_PATH, true)
	GameState.meet_ally(GameState.ALLY_ECO)
	GameState.obtained_abilities[GameState.ABILITY_PULSE] = true
	GameState.seen_notices[GameState.ABILITY_PULSE] = true
	GameState.set_ability_unlocked(GameState.ABILITY_PULSE, true)
	GameState.meet_ally(GameState.ALLY_NOTAS)
	GameState.obtain_ability(GameState.ABILITY_LASER)
	GameState.mark_notice_seen(GameState.ABILITY_LASER)
	GameState.mark_level_completed(&"1-1")
	GameState.lives_max = 5
	GameState.refill_lives()
	_check(GameState.save_game(), "no se pudo guardar")
	var runner := (load(MAIN_SCENE) as PackedScene).instantiate() as LevelRunner
	runner.start_level_id = "1-1"
	get_tree().root.add_child(runner)
	_check(await _wait(func() -> bool: return runner.get_isak() != null and runner.get_phase() == LevelRunner.Phase.PLAYING),
		"el 1-1 no empieza")
	var isak: Isak = runner.get_isak()
	isak.input = PlayerInput.new()
	_check(await _wait(func() -> bool: return not isak.is_warping() and isak.is_on_floor()), "Isak no llega")
	await _frames(20)
	await _save("01_nivel_5_vidas.png")
	for i: int in 2:
		GameState.sync_rate = GameState.SYNC_RATE_MIN
		await _frames(4)
		_check(await _wait(func() -> bool: return runner.get_phase() == LevelRunner.Phase.PLAYING \
			and not isak.is_dead() and not isak.is_warping()), "no reaparece")
	await _frames(10)
	await _save("02_nivel_3_vidas.png")
	_check(GameState.lives == 3, "deberian quedar 3 vidas (hay %d)" % GameState.lives)
	EventBus.level_completed.emit("1-1")
	_check(await _wait(func() -> bool: return runner.is_in_hub() and runner.get_phase() == LevelRunner.Phase.PLAYING),
		"no llega al hub")
	var hub: HubRoom = runner.get_hub()
	_check(await _wait(func() -> bool: return hub.get_isak() != null and not hub.get_isak().is_warping()), "Isak no llega al hub")
	hub.get_isak().input = PlayerInput.new()
	await _frames(40)
	_check(GameState.lives == 3, "el hub debe conservar 3 vidas (hay %d)" % GameState.lives)
	_check(hub.get_hud().is_lives_shown() and hub.get_hud().get_lives_lit() == 3, "el HUD del hub no muestra 3 vidas")
	await _save("03_hub_3_vidas.png")
	var folder: FolderStation = hub.get_folder(&"m1")
	hub.get_isak().global_position = Vector2(folder.position.x + TILE, hub.get_shelf_top_y())
	await _frames(60)
	await _save("04_hub_repisa_eco.png")
	print("render_hub_lives: %s" % ("OK" if _ok else "FALLO"))
	runner.queue_free()
	await _frames(2)
	SaveFile.delete(SAVE_PATH)
	finished.emit(0 if _ok else 1)


func _wait(cond: Callable) -> bool:
	var end: int = Time.get_ticks_msec() + int(WAIT_S * 1000.0)
	while Time.get_ticks_msec() < end:
		if cond.call():
			return true
		await get_tree().process_frame
	return false


func _frames(n: int) -> void:
	for i: int in n:
		await get_tree().process_frame


func _check(ok: bool, why: String) -> void:
	if not ok:
		_ok = false
		push_error("render_hub_lives: " + why)


func _save(file_name: String) -> void:
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var path: String = _out.path_join(file_name)
	var err: Error = get_viewport().get_texture().get_image().save_png(path)
	print("render_hub_lives: %s (%s)" % [path, error_string(err)])
