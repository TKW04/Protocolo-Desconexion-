## Logica de tools/render_game_over.gd (capturas de vidas, game over, papelera y
## carpetas bloqueadas). Ver la cabecera de ese script.
extends Node

const MAIN_SCENE: String = "res://scenes/main.tscn"
const HUB_SCENE: String = "res://scenes/hub/hub.tscn"
const SAVE_PATH: String = "user://render_game_over_save.json"
const DEFAULT_OUT: String = "user://game_over"
const TILE: float = 64.0
const WAIT_S: float = 20.0

signal finished(code: int)

var _ok: bool = true
var _out: String = ""
var _input := PlayerInput.new()


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	_out = args[0] if args.size() > 0 else ProjectSettings.globalize_path(DEFAULT_OUT)
	DirAccess.make_dir_recursive_absolute(_out)
	GameState.use_save_path(SAVE_PATH, true)
	# Partida que ya paso por el primer hub: Eco, pulso y Notas; 1-1 completado
	# con 6 puntos y el laser, GUARDADA en Notas.
	GameState.meet_ally(GameState.ALLY_ECO)
	GameState.obtained_abilities[GameState.ABILITY_PULSE] = true
	GameState.seen_notices[GameState.ABILITY_PULSE] = true
	GameState.set_ability_unlocked(GameState.ABILITY_PULSE, true)
	GameState.meet_ally(GameState.ALLY_NOTAS)
	GameState.obtain_ability(GameState.ABILITY_LASER)
	GameState.mark_notice_seen(GameState.ABILITY_LASER)
	for i: int in 6:
		GameState.capture_attention_point(&"1-1", StringName("punto_%d" % i), 1)
	GameState.mark_level_completed(&"1-1")
	_check(GameState.save_game(), "no se pudo guardar la copia de partida")
	await _lives_and_game_over()
	await _no_copy()
	print("render_game_over: %s" % ("OK" if _ok else "FALLO"))
	GameState.use_save_path(SAVE_PATH, true)
	finished.emit(0 if _ok else 1)


func _lives_and_game_over() -> void:
	var runner := (load(MAIN_SCENE) as PackedScene).instantiate() as LevelRunner
	runner.start_level_id = "1-1"
	get_tree().root.add_child(runner)
	_check(await _wait(func() -> bool: return runner.get_isak() != null and runner.get_phase() == LevelRunner.Phase.PLAYING),
		"el 1-1 no empieza")
	var isak: Isak = runner.get_isak()
	isak.input = _input
	_check(await _wait(func() -> bool: return not isak.is_warping() and isak.is_on_floor()), "Isak no llega")
	await _frames(20)
	await _save("01_hud_vidas.png")
	# Primera muerte: un telefono se apaga.
	GameState.sync_rate = GameState.SYNC_RATE_MIN
	await _frames(8)
	await _save("02_vida_perdida.png")
	_check(await _wait(func() -> bool: return runner.get_phase() == LevelRunner.Phase.PLAYING and not isak.is_dead() \
		and not isak.is_warping()), "no reaparece")
	await _frames(10)
	await _save("02b_reaparicion.png")
	# Dos muertes mas: game over.
	for i: int in 2:
		_check(await _wait(func() -> bool: return runner.is_in_hub() or (runner.get_phase() == LevelRunner.Phase.PLAYING \
			and not isak.is_dead() and not isak.is_warping())), "no reaparece")
		GameState.sync_rate = GameState.SYNC_RATE_MIN
		await _frames(2)
	_check(await _wait(func() -> bool: return runner.is_in_hub()), "el game over no lleva al hub")
	var hub: HubRoom = runner.get_hub()
	var box: EcoTextBox = hub.get_text_box()
	_check(await _wait(func() -> bool: return box.is_showing()), "Eco no habla tras el game over")
	box.finish_typing()
	await _frames(4)
	await _save("03_game_over_eco.png")
	var lines: int = hub.get_game_over_intro().get_lines().size()
	for i: int in lines - 1:
		await _close_line(box)
	box.finish_typing()
	await _frames(4)
	await _save("03b_game_over_papelera.png")
	await _close_line(box)
	_check(await _wait(func() -> bool: return not get_tree().paused), "la pausa no se libera")
	hub.get_isak().input = _input
	await _frames(20)
	await _save("04_papelera_parpadea.png")
	# Carpeta bloqueada: Isak de pie en la repisa de M1.
	var folder: FolderStation = hub.get_folder(&"m1")
	hub.get_isak().global_position = Vector2(folder.position.x + TILE, hub.get_shelf_top_y())
	_check(await _wait(func() -> bool: return folder.is_trash_hint_visible()), "la carpeta no avisa")
	await _frames(6)
	await _save("05_carpeta_bloqueada.png")
	# Notas no guarda.
	var notas: NotasStation = hub.get_notas()
	hub.get_isak().global_position = Vector2(notas.position.x + 2.6 * TILE - 64.0, hub.get_floor_y())
	await _frames(6)
	notas.open(hub.get_isak())
	(notas.get_panel() as NotasPanel).save_now()
	await _frames(6)
	await _save("05b_notas_no_guarda.png")
	notas.close(true)
	# Recuperar: Isak junto a la papelera.
	var papelera: Papelera = hub.get_papelera()
	hub.get_isak().global_position = Vector2(papelera.get_center().x - 1.2 * TILE, hub.get_floor_y())
	_check(await _wait(func() -> bool: return papelera.get_state() == Papelera.State.EMPTYING), "no recupera")
	await _frames(12)
	await _save("06_recuperando.png")
	_check(await _wait(func() -> bool: return papelera.get_state() == Papelera.State.EMPTY), "no se vacia")
	hub.get_isak().global_position = Vector2(folder.position.x + TILE, hub.get_shelf_top_y())
	_check(await _wait(func() -> bool: return folder.is_key_hint_visible()), "la carpeta no se desbloquea")
	await _frames(6)
	await _save("07_tras_recuperar.png")
	runner.queue_free()
	await _frames(2)


func _no_copy() -> void:
	GameState.use_save_path(SAVE_PATH, true)
	GameState.meet_ally(GameState.ALLY_ECO)
	GameState.obtained_abilities[GameState.ABILITY_PULSE] = true
	GameState.seen_notices[GameState.ABILITY_PULSE] = true
	GameState.set_ability_unlocked(GameState.ABILITY_PULSE, true)
	GameState.meet_ally(GameState.ALLY_NOTAS)
	GameState.attention_points = 4
	var report: Dictionary = GameState.apply_rollback(GameState.ROLLBACK_GAME_OVER)
	_check(not bool(report.get("had_copy", true)), "habia copia")
	var hub := (load(HUB_SCENE) as PackedScene).instantiate() as HubRoom
	hub.rollback_report = report
	get_tree().root.add_child(hub)
	hub.get_isak().input = _input
	var box: EcoTextBox = hub.get_text_box()
	_check(await _wait(func() -> bool: return box.is_showing()), "Eco no habla sin copia")
	box.finish_typing()
	await _frames(4)
	await _save("08_nada_guardado.png")
	for i: int in hub.get_game_over_intro().get_lines().size():
		await _close_line(box)
	_check(await _wait(func() -> bool: return not get_tree().paused), "la pausa no se libera")
	var papelera: Papelera = hub.get_papelera()
	hub.get_isak().global_position = Vector2(papelera.get_center().x - 1.5 * TILE, hub.get_floor_y())
	await _frames(20)
	_check(papelera.get_state() == Papelera.State.EMPTY, "la papelera deberia estar activada y vacia")
	await _save("08b_papelera_vacia.png")
	hub.queue_free()
	await _frames(2)


func _close_line(box: EcoTextBox) -> void:
	var text: String = box.get_text()
	box.finish_typing()
	box.confirm()
	await _wait(func() -> bool: return box.get_text() != text or not box.is_showing())
	await _frames(2)


## Espera (como mucho WAIT_S segundos reales) a que `cond` sea verdadera.
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
		push_error("render_game_over: " + why)


func _save(file_name: String) -> void:
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var path: String = _out.path_join(file_name)
	var err: Error = get_viewport().get_texture().get_image().save_png(path)
	print("render_game_over: %s (%s)" % [path, error_string(err)])
