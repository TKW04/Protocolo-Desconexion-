## Capturas a 1:1 (1280x720) del menu de pausa y del ajuste «Ayudas de Eco»
## (PauseMenu, GameSettings; paso 13 de docs/propuesta-asistentes-y-vidas.md)
## con el flujo de juego real (scenes/main.tscn) y el hub real. Usa el guardado
## y los ajustes de herramientas (user://tool_save.json y
## user://tool_settings.cfg, se borran al arrancar; nunca los del jugador):
##   01_pausa_nivel.png   el menu de pausa abierto en el 1-1 (accion pause)
##   02_ajustes.png       la pagina Ajustes con «Ayudas de Eco: Ocultar»
##   03_receptor_sin_q.png con las ayudas ocultas, Isak junto al receptor del
##                         2a (tipo no aprendido): sin Q
##   04_receptor_con_q.png lo mismo con «Mostrar»: vuelve la Q
##   05_hub_icono.png     el hub con el icono de ajustes junto al Modo Avion
##   06_hub_pausa.png     el menu abierto con el icono (clic)
##   07_salir_al_hub.png  en el 1-1 ya completado: «Salir al hub» en la principal
##   08_confirmar_salir.png su confirmacion («¿Salir al hub? Perderas este
##                         intento.», Salir / Volver)
##   09_ajustes.png       Ajustes completo (Ayudas de Eco, Sync bajo, contorno del
##                         Debug, Pantalla, Controles), en el hub
##   10_pantalla.png      Ajustes > Pantalla (modo, tamano, escala entera)
##   11_controles.png     Ajustes > Controles (tecla / boton de cada accion)
##   12_captura.png       «Pulsa una tecla o boton…» para Saltar
##   13_conflicto.png     G ya es de Pulso: Intercambiar / Cancelar
##   14_intercambio.png   tras intercambiar: Saltar con G, Pulso con Espacio
##   15_deslizar.png      Controles con «Deslizar: L / B» elegido (gesto del
##                         dash, 2026-10-19, docs/propuesta-1-3.md §2.4)
##   16_deslizar_e.png    tras reasignar Deslizar a E (sin conflicto)
## Necesita ventana (no funciona con --headless).
## Uso: Godot --path . -s tools/render_pause_menu.gd [-- carpeta_salida]
extends SceneTree

const SCENE: String = "res://scenes/main.tscn"
const HUB_SCENE: String = "res://scenes/hub/hub.tscn"
const DEFAULT_OUT: String = "user://pause_menu_shots"
const TILE: float = 64.0
const RECEIVER_PATH: NodePath = ^"Objects/receiver_56_9"
## Por ruta (no por class_name): un script -s se compila antes de los autoloads.
const SETTINGS_SCRIPT: String = "res://scripts/autoload/game_settings.gd"

var _main: Node
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
	_main = main
	var isak: Node2D = main.call(&"get_isak")
	var deadline: int = Time.get_ticks_msec() + 30000
	while Time.get_ticks_msec() < deadline:
		await process_frame
		if not paused and not isak.call(&"is_warping") and int(main.call(&"get_phase")) == 0:
			break
	for i: int in 30:
		await process_frame
	var level: Node = main.call(&"get_level")
	var help: Node = level.get_node(^"Help")
	var receiver: Node2D = level.get_node(RECEIVER_PATH)
	# Entre el receptor y el foso del puente, lejos de la Burbuja del 2a.
	isak.global_position = Vector2(57.6 * TILE, 10.0 * TILE)
	isak.set(&"velocity", Vector2.ZERO)
	for i: int in 30:
		await process_frame
	var menu: Node = main.call(&"get_pause_menu")
	_press(&"pause")
	await create_timer(0.3).timeout
	_check(menu.call(&"is_open") and paused, "el menu se abre con pause en el nivel")
	await _save(out_dir, "01_pausa_nivel.png")
	_press(&"ui_down")
	_press(&"ui_accept")
	_press(&"ui_accept")
	await create_timer(0.3).timeout
	var settings: Script = load(SETTINGS_SCRIPT)
	_check(not settings.call(&"is_eco_help_shown"), "Ajustes: Ocultar")
	await _save(out_dir, "02_ajustes.png")
	# Esc en Ajustes vuelve a la principal; la segunda pulsacion reanuda.
	_press(&"pause")
	await create_timer(0.2).timeout
	_check(paused and int(menu.call(&"get_page")) == 0, "pause en Ajustes vuelve una pagina")
	_press(&"pause")
	await create_timer(0.5).timeout
	_check(not paused, "pause reanuda")
	_check(help.call(&"get_target") == null, "ayudas ocultas: sin Q")
	await _save(out_dir, "03_receptor_sin_q.png")
	settings.call(&"set_eco_help_shown", true)
	await create_timer(0.5).timeout
	_check(help.call(&"get_target") == receiver, "ayudas visibles: Q sobre el receptor")
	await _save(out_dir, "04_receptor_con_q.png")
	# Salir al hub: solo con el nivel completado en la partida actual.
	var completed: Dictionary = game_state.get(&"completed_levels")
	completed[&"1-1"] = true
	_press(&"pause")
	await create_timer(0.3).timeout
	menu.call(&"select", 5)  # PauseMenu.Option.EXIT_TO_HUB
	await create_timer(0.1).timeout
	_check(menu.call(&"get_options").has(5), "Salir al hub en un nivel completado")
	await _save(out_dir, "07_salir_al_hub.png")
	_press(&"ui_accept")
	await create_timer(0.3).timeout
	_check(int(menu.call(&"get_page")) == 2, "confirmacion de Salir al hub")
	await _save(out_dir, "08_confirmar_salir.png")
	_press(&"pause")
	_press(&"pause")
	await create_timer(0.3).timeout
	_check(not paused, "Esc vuelve de la confirmacion y despues reanuda")
	completed.erase(&"1-1")
	main.queue_free()
	await process_frame
	await process_frame
	# Hub real abierto solo (con Notas conocida: sin presentacion).
	game_state.call(&"meet_ally", &"notas")
	var hub: Node = (load(HUB_SCENE) as PackedScene).instantiate()
	root.add_child(hub)
	deadline = Time.get_ticks_msec() + 15000
	while Time.get_ticks_msec() < deadline and not hub.call(&"has_arrived"):
		await process_frame
	await create_timer(0.5).timeout
	await _save(out_dir, "05_hub_icono.png")
	var icon: Control = hub.call(&"get_hud").call(&"get_settings_icon")
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	icon.gui_input.emit(click)
	await create_timer(0.3).timeout
	var hub_menu: Node = get_first_node_in_group(&"pause_menu")
	_check(hub_menu != null and hub_menu.call(&"is_open"), "el icono del hub abre el menu")
	await _save(out_dir, "06_hub_pausa.png")
	# Ajustes con todos sus apartados, Pantalla y Controles (con un conflicto).
	hub_menu.call(&"activate", 1)  # SETTINGS
	hub_menu.call(&"select", 7)  # LOW_SYNC
	await _save(out_dir, "09_ajustes.png")
	hub_menu.call(&"activate", 9)  # DISPLAY
	await _save(out_dir, "10_pantalla.png")
	_press(&"pause")
	hub_menu.call(&"activate", 12)  # CONTROLS
	hub_menu.call(&"select_action", &"jump")
	await _save(out_dir, "11_controles.png")
	_press(&"ui_accept")
	await create_timer(0.4).timeout
	_check(int(hub_menu.call(&"get_page")) == 5, "captura abierta")
	await _save(out_dir, "12_captura.png")
	_key(KEY_G)
	await create_timer(0.1).timeout
	_check(int(hub_menu.call(&"get_page")) == 6, "conflicto con el pulso")
	await _save(out_dir, "13_conflicto.png")
	hub_menu.call(&"activate", 16)  # SWAP
	await create_timer(0.1).timeout
	_check(InputMap.event_is_action(_key_event(KEY_G), &"jump", true), "Saltar con G tras intercambiar")
	await _save(out_dir, "14_intercambio.png")
	# Deslizar (gesto del dash, 2026-10-19): fila propia y reasignable.
	_check(int(hub_menu.call(&"get_page")) == 4, "vuelve a Controles tras intercambiar")
	hub_menu.call(&"select_action", &"gesture_swipe")
	await create_timer(0.1).timeout
	var lines: PackedStringArray = hub_menu.call(&"get_lines")
	_check(lines.has("– Deslizar: L / B"), "fila Deslizar: L / B elegida (%s)" % [lines])
	await _save(out_dir, "15_deslizar.png")
	_press(&"ui_accept")
	await create_timer(0.4).timeout
	_check(int(hub_menu.call(&"get_page")) == 5, "captura de Deslizar abierta")
	_key(KEY_E)
	await create_timer(0.1).timeout
	_check(InputMap.event_is_action(_key_event(KEY_E), &"gesture_swipe", true), "Deslizar con E")
	await _save(out_dir, "16_deslizar_e.png")
	load("res://scripts/autoload/control_bindings.gd").call(&"restore_defaults")
	hub_menu.call(&"close")
	hub.queue_free()
	await process_frame
	print("render_pause_menu: %s" % ("OK" if _ok else "FALLO"))
	quit(0 if _ok else 1)


func _press(action: StringName) -> void:
	for pressed: bool in [true, false]:
		var event := InputEventAction.new()
		event.action = action
		event.pressed = pressed
		root.push_input(event)


func _key_event(code: Key) -> InputEventKey:
	var event := InputEventKey.new()
	event.physical_keycode = code
	return event


func _key(code: Key) -> void:
	for pressed: bool in [true, false]:
		var event := _key_event(code)
		event.pressed = pressed
		root.push_input(event)


func _check(cond: bool, what: String) -> void:
	if not cond:
		_ok = false
		print("render_pause_menu: FALLA: %s" % what)


func _save(out_dir: String, file_name: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	var image: Image = root.get_texture().get_image()
	var path: String = out_dir.path_join(file_name)
	var err: Error = image.save_png(path)
	print("render_pause_menu: %s (%s)" % [path, error_string(err)])
