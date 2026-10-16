## Capturas a 1:1 (1280x720) del encuentro con Eco del 1-1 (EcoEncounter,
## data/eco_encounter.json; docs/propuesta-asistentes-y-vidas.md §7.1, paso 6
## de §10) con el flujo real (scenes/main.tscn) y un guardado vacio de
## herramientas (user://tool_save.json; nunca el guardado del jugador):
##   01_llegada_sin_eco.png     Isak ya llego por el vortice y camina: sin pulso ni companero; Eco flota delante
##   02_eco_se_presenta.png     primera linea de la presentacion (pausa)
##   03_apodo.png               la entrada del apodo, tras escribir APODO
##   04_eco_dice_apodo.png      Eco llama a Isak por el apodo y le regala el pulso
##   05_aviso_pulso.png         el aviso de control del pulso («Pulso: G / X (mando)»)
##   06_eco_acompana.png        tras el encuentro, Eco sigue a Isak (companero)
## Necesita ventana (no funciona con --headless).
## Uso: Godot --path . -s tools/render_eco_encounter.gd [-- carpeta_salida]
extends SceneTree

const SCENE: String = "res://scenes/main.tscn"
const DEFAULT_OUT: String = "user://eco_encounter_shots"
const TILE: float = 64.0
const NICKNAME: String = "Nova"
## Fase HOLD de EcoTextBox (texto escrito).
const PHASE_HOLD: int = 2
## Paso DONE de EcoEncounter.
const STEP_DONE: int = 5
## Limite de espera de cada fase (ms de tiempo real).
const WAIT_MS: int = 30000

var _main: Node
var _out: String
var _shots: Array[String] = []


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	_out = args[0] if args.size() > 0 else ProjectSettings.globalize_path(DEFAULT_OUT)
	DirAccess.make_dir_recursive_absolute(_out)
	var game_state: Node = root.get_node(^"GameState")
	_main = (load(SCENE) as PackedScene).instantiate()
	_main.set(&"start_level_id", "1-1")
	root.add_child(_main)
	var level: Node = _main.call(&"get_level")
	var isak: Node2D = _main.call(&"get_isak")
	var box: Node = level.get_node(^"EcoTextBox")
	var encounter: Node = level.get_node(^"Objects/eco_encuentro")
	var data: Dictionary = encounter.call(&"load_data")
	var intro: String = String((data["intro"] as Array)[0])
	var gift: String = String((data["gift"] as Array)[0]).replace("{apodo}", NICKNAME)
	var notice: String = encounter.call(&"get_notice_text")
	# Llegada: camina a la derecha en cuanto tiene el control.
	Input.action_press(&"move_right")
	var ok_arrival: bool = false
	var deadline: int = Time.get_ticks_msec() + WAIT_MS
	while Time.get_ticks_msec() < deadline:
		await process_frame
		if isak.global_position.x >= 7.5 * TILE:
			ok_arrival = not game_state.call(&"is_ability_unlocked", &"pulse") \
					and not game_state.call(&"has_met_ally", &"eco") and encounter.call(&"is_eco_visible")
			break
	Input.action_release(&"move_right")
	await _save("01_llegada_sin_eco.png")
	# Termina de entrar en la zona del encuentro.
	Input.action_press(&"move_right")
	deadline = Time.get_ticks_msec() + WAIT_MS
	while Time.get_ticks_msec() < deadline:
		await process_frame
		if paused:
			break
	Input.action_release(&"move_right")
	# Presentacion: fotos de las lineas pedidas, apodo y cierre como el jugador.
	var typed: bool = false
	deadline = Time.get_ticks_msec() + WAIT_MS
	while Time.get_ticks_msec() < deadline:
		await process_frame
		if int(encounter.call(&"get_step")) == STEP_DONE:
			break
		var entry: Node = encounter.call(&"get_nickname_entry")
		if entry != null and entry.call(&"is_open"):
			if not typed:
				typed = true
				await create_timer(0.3).timeout
				entry.call(&"type_text", NICKNAME)
				await create_timer(0.4).timeout
				await _save("03_apodo.png")
				entry.call(&"activate_selected")
			continue
		if not box.call(&"is_important") or int(box.call(&"get_phase")) != PHASE_HOLD:
			continue
		var text: String = box.call(&"get_text")
		if text == intro:
			await _save("02_eco_se_presenta.png")
		elif text == gift:
			await _save("04_eco_dice_apodo.png")
		elif text == notice:
			await _save("05_aviso_pulso.png")
		await create_timer(0.2).timeout
		box.call(&"confirm")
	var ok_done: bool = int(encounter.call(&"get_step")) == STEP_DONE \
			and game_state.call(&"is_ability_unlocked", &"pulse") and game_state.call(&"has_met_ally", &"eco") \
			and game_state.call(&"get_nickname") == NICKNAME
	await create_timer(0.3).timeout
	Input.action_press(&"move_right")
	await create_timer(1.0).timeout
	Input.action_release(&"move_right")
	await create_timer(0.8).timeout
	var eco: Node2D = _main.call(&"get_eco_companion")
	var ok_follow: bool = eco != null and eco.call(&"is_shown") \
			and eco.global_position.distance_to(isak.global_position) < 200.0
	await _save("06_eco_acompana.png")
	var ok: bool = ok_arrival and ok_done and ok_follow and _shots.size() == 6
	print("render_eco_encounter: llegada=%s encuentro=%s companero=%s capturas=%d" % [
		ok_arrival, ok_done, ok_follow, _shots.size()])
	_main.queue_free()
	await process_frame
	quit(0 if ok else 1)


func _save(file_name: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	var image: Image = root.get_texture().get_image()
	var path: String = _out.path_join(file_name)
	var err: Error = image.save_png(path)
	if err == OK and not _shots.has(file_name):
		_shots.append(file_name)
	print("render_eco_encounter: %s (%s)" % [path, error_string(err)])
