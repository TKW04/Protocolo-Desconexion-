## Capturas a 1:1 (1280x720) de Pausa > Ajustes > Controles con iconos y
## deteccion de dispositivo (2026-10-30, peticion del usuario tras el 5-2;
## docs/05-hub.md §13.7) con el flujo de juego real (scenes/main.tscn, el 1-1).
## Usa el guardado y los ajustes de herramientas (nunca los del jugador):
##   01_teclado.png         Controles con teclado (primera fila elegida)
##   02_teclado_combos.png  la ventana bajada hasta los combos (Embestida elegida)
##   03_mando.png           tras pulsar un boton del mando: titulo y filas cambian
##   04_mando_combos.png    los combos con los botones del mando
##   05_mando_playstation.png con un mando PlayStation (nombres Cruz, Círculo...)
## Necesita ventana (no funciona con --headless).
## Uso: Godot --path . -s tools/render_controls_menu.gd [-- carpeta_salida]
extends SceneTree

const SCENE: String = "res://scenes/main.tscn"
const DEFAULT_OUT: String = "user://controls_menu_shots"
## Por ruta (no por class_name): un script -s se compila antes de los autoloads.
const BINDINGS_SCRIPT: String = "res://scripts/autoload/control_bindings.gd"
const OPTION_SETTINGS: int = 1
const OPTION_CONTROLS: int = 12
const PAGE_CONTROLS: int = 4

var _ok: bool = true


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var out_dir: String = args[0] if args.size() > 0 else ProjectSettings.globalize_path(DEFAULT_OUT)
	DirAccess.make_dir_recursive_absolute(out_dir)
	var game_state: Node = root.get_node(^"GameState")
	game_state.call(&"meet_ally", &"eco")
	game_state.call(&"mark_notice_seen", &"pulse")
	game_state.call(&"obtain_ability", &"pulse")
	var main: Node = (load(SCENE) as PackedScene).instantiate()
	main.set(&"start_level_id", "1-1")
	root.add_child(main)
	var isak: Node2D = main.call(&"get_isak")
	var deadline: int = Time.get_ticks_msec() + 30000
	while Time.get_ticks_msec() < deadline:
		await process_frame
		if not paused and not isak.call(&"is_warping") and int(main.call(&"get_phase")) == 0:
			break
	for i: int in 30:
		await process_frame
	var bindings: Script = load(BINDINGS_SCRIPT)
	var menu: Node = main.call(&"get_pause_menu")
	_check(bool(menu.call(&"request_open")), "el menu se abre")
	menu.call(&"activate", OPTION_SETTINGS)
	menu.call(&"select", OPTION_CONTROLS)
	menu.call(&"activate", OPTION_CONTROLS)
	await create_timer(0.3).timeout
	_check(int(menu.call(&"get_page")) == PAGE_CONTROLS, "pagina Controles")
	_check(String(menu.call(&"get_lines")[0]) == "Controles · teclado", "titulo con teclado")
	await _save(out_dir, "01_teclado.png")
	menu.call(&"select_row", "combo_ram")
	await create_timer(0.2).timeout
	await _save(out_dir, "02_teclado_combos.png")
	menu.call(&"select_row", "move_left")
	var button := InputEventJoypadButton.new()
	button.button_index = JOY_BUTTON_LEFT_SHOULDER
	button.pressed = true
	root.push_input(button)
	button = button.duplicate() as InputEventJoypadButton
	button.pressed = false
	root.push_input(button)
	await create_timer(0.3).timeout
	_check(String(menu.call(&"get_lines")[0]).begins_with("Controles · mando"), "titulo con mando, en vivo")
	await _save(out_dir, "03_mando.png")
	menu.call(&"select_row", "combo_ram")
	await create_timer(0.2).timeout
	await _save(out_dir, "04_mando_combos.png")
	menu.call(&"select_row", "jump")
	bindings.call(&"set_last_device", 1, "playstation")
	await create_timer(0.3).timeout
	_check(String(menu.call(&"get_lines")[0]) == "Controles · mando PlayStation", "mando PlayStation")
	await _save(out_dir, "05_mando_playstation.png")
	bindings.call(&"reset_device")
	menu.call(&"close")
	main.queue_free()
	await process_frame
	print("render_controls_menu: %s" % ("OK" if _ok else "CON ERRORES"))
	quit(0 if _ok else 1)


func _check(cond: bool, what: String) -> void:
	if not cond:
		_ok = false
		push_error("render_controls_menu: falla: " + what)


func _save(out_dir: String, file_name: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	var image: Image = root.get_texture().get_image()
	var path: String = out_dir.path_join(file_name)
	var err: Error = image.save_png(path)
	print("render_controls_menu: %s (%s)" % [path, error_string(err)])
