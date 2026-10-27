## Capturas a 1:1 (1280x720) de los iconos de los menus del hub y del check de
## las carpetas (2026-10-26, peticion del usuario). Hub real (scenes/hub/hub.tscn)
## con su propio guardado (user://render_hub_icons_save.json, se borra al terminar).
##   01_carpetas_estados.png   M1 con los subniveles superados (sin check), M2
##                             disponible (tarjeta de video) y M3 bloqueada (foto)
##   02_carpeta_check.png      M1 con TODO obtenido (check), M2 y M3 disponibles
##   03_notas_iconos.png       panel de Notas: disquete, album, credencial y volver
##   04_notas_confirmar.png    «¿Guardar en Notas?» con check y aspa
##   05_m1_panel_mixto.png     panel del Mundo 1: 1-1 completado, 1-2 nuevo, 1-3 y jefe
##                             bloqueados (iconos en gris) y lo que falta para el check
##   06_m1_panel_falta.png     Mundo 1 superado: «Para el check: puntos, recuerdos»
##   07_m1_panel_todo.png      Mundo 1 con todo: «Todo obtenido»
##   08_m2_panel.png           panel del Mundo 2 (iconos del feed)
##   09_confirmar_sin_guardar.png «¿Seguro?» con Entrar sin guardar / Volver
##   10_notas_guardado.png     cabecera de Notas tras guardar (2026-10-26: rombo de
##                             puntos, icono del acceso, «Guardado en: aaaa-mm-dd hh:mm»)
##   11_notas_kernel_sin_guardar.png  acceso Kernel con su icono y «Sin guardar» bajo la fecha
##   12_m3_panel.png           panel del Mundo 3 con sus iconos (2026-10-27: antes «?»)
##   13_pausa_principal.png    menu de pausa (ESC) con un icono por opcion (2026-10-27)
##   14_pausa_ajustes.png      pagina Ajustes del menu de pausa con sus iconos
## Necesita ventana (no funciona con --headless).
## Uso: Godot --path . -s tools/render_hub_icons.gd [-- carpeta_salida]
extends SceneTree

const SCENE: String = "res://scenes/hub/hub.tscn"
const SAVE_PATH: String = "user://render_hub_icons_save.json"
const M1: Array[StringName] = [&"1-1", &"1-2", &"1-3", &"1-boss"]

var _ok: bool = true
var _hub: Node
var _state: Node


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var out_dir: String = args[0] if args.size() > 0 else ProjectSettings.globalize_path("user://hub_icons")
	DirAccess.make_dir_recursive_absolute(out_dir)
	_state = root.get_node(^"GameState")
	_state.call(&"use_save_path", SAVE_PATH, true)
	for ally: StringName in [&"eco", &"notas", &"calc"]:
		_state.call(&"meet_ally", ally)
	_state.call(&"obtain_ability", &"pulse")
	_state.call(&"mark_level_completed", &"1-1")
	for i: int in 7:
		_state.call(&"capture_attention_point", &"1-1", StringName("p%d" % i), 1)
	_state.call(&"unlock_level", &"1-2")
	# 05: panel mixto (antes de abrir el hub, para que la llegada vea este estado).
	await _spawn()
	var m1: Node = _hub.call(&"get_folder", &"m1")
	await _panel_shot(m1, out_dir, "05_m1_panel_mixto.png")
	# 03-04: Notas.
	var notas: Node = _hub.call(&"get_notas")
	var np: Node = notas.call(&"get_panel")
	np.call(&"open")
	await _frames(6)
	await _save(out_dir, "03_notas_iconos.png")
	_state.call(&"request_save")
	np.call(&"skip_input_delay")
	np.call(&"select_option", &"save")
	np.call(&"confirm")
	await _frames(4)
	await _save(out_dir, "04_notas_confirmar.png")
	# 10-11: cabecera tras guardar («Guardado en: aaaa-mm-dd hh:mm») y en Kernel.
	np.call(&"select_option", &"yes")
	np.call(&"confirm")
	await _frames(4)
	await _save(out_dir, "10_notas_guardado.png")
	_state.set(&"lap", 2)
	_state.call(&"request_save")
	np.call(&"refresh")
	await _frames(4)
	await _save(out_dir, "11_notas_kernel_sin_guardar.png")
	_state.set(&"lap", 1)
	np.call(&"close")
	# 09: «¿Seguro?» al entrar con cambios sin guardar.
	var fp: Node = m1.call(&"get_folder_panel")
	fp.call(&"open")
	fp.call(&"skip_input_delay")
	fp.call(&"select_option", &"1-1")
	fp.call(&"confirm")
	await _frames(4)
	_check(fp.call(&"is_confirming_unsaved"), "no pide confirmar")
	await _save(out_dir, "09_confirmar_sin_guardar.png")
	fp.call(&"close")
	# 01 / 06: Mundo 1 superado, faltan cosas.
	for id: StringName in M1:
		_state.call(&"mark_level_completed", id)
	_refresh()
	await _frames(6)
	await _save(out_dir, "01_carpetas_estados.png")
	await _panel_shot(m1, out_dir, "06_m1_panel_falta.png")
	# 08: Mundo 2.
	_state.call(&"mark_level_completed", &"2-1")
	_state.call(&"unlock_level", &"2-2")
	await _panel_shot(_hub.call(&"get_folder", &"m2"), out_dir, "08_m2_panel.png")
	# 02 / 07: todo obtenido en el Mundo 1 (y Mundo 3 desbloqueado para verlo encendido).
	for id: StringName in M1:
		for i: int in _hw().call(&"level_points_total", String(id)):
			_state.call(&"capture_attention_point", id, StringName("p%d" % i), 1)
		for bank: StringName in _state.call(&"level_power_bank_ids", id):
			_state.call(&"collect_power_bank_pickup", id, bank)
		for secret: StringName in _hw().call(&"level_extra_life_secrets", id):
			_state.call(&"collect_extra_life", id, secret)
	for id: StringName in [&"msg_1_1", &"msg_1_2", &"msg_1_3", &"boss_w1_l1"]:
		_state.call(&"obtain_memory", id)
	_state.call(&"mark_level_completed", &"2-boss")
	_check(_hw().call(&"is_world_all_done", _hw().call(&"world", &"m1")), "el Mundo 1 no esta completo")
	_refresh()
	await _frames(6)
	await _save(out_dir, "02_carpeta_check.png")
	await _panel_shot(m1, out_dir, "07_m1_panel_todo.png")
	# 12: Mundo 3 (3-1 completado, 3-2 nuevo, 3-3 y jefe bloqueados).
	_state.call(&"mark_level_completed", &"3-1")
	_state.call(&"unlock_level", &"3-2")
	_refresh()
	await _panel_shot(_hub.call(&"get_folder", &"m3"), out_dir, "12_m3_panel.png")
	# 13-14: menu de pausa (ESC) con iconos.
	var menu: Node = get_first_node_in_group(&"pause_menu")
	_check(menu != null and menu.call(&"request_open"), "el menu de pausa no se abre")
	if menu != null:
		await _frames(4)
		await _save(out_dir, "13_pausa_principal.png")
		menu.call(&"activate", 1)  # PauseMenu.Option.SETTINGS
		await _frames(4)
		await _save(out_dir, "14_pausa_ajustes.png")
		menu.call(&"close")
		await _frames(2)
	_hub.queue_free()
	await process_frame
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH))
	quit(0 if _ok else 1)


## HubWorlds sin nombrarlo: con -s el script se compila antes de los autoloads.
func _hw() -> GDScript:
	return load("res://scripts/hub/hub_worlds.gd") as GDScript


func _spawn() -> void:
	_hub = (load(SCENE) as PackedScene).instantiate()
	root.add_child(_hub)
	_check(await _wait(func() -> bool: return _hub.call(&"has_arrived")), "Isak no llega")
	await _frames(10)


func _refresh() -> void:
	for id: StringName in _hub.call(&"get_folder_ids"):
		_hub.call(&"get_folder", id).call(&"refresh_state")


func _panel_shot(folder: Node, out_dir: String, file_name: String) -> void:
	var panel: Node = folder.call(&"get_folder_panel")
	panel.call(&"open")
	await _frames(6)
	await _save(out_dir, file_name)
	panel.call(&"close")
	await _frames(2)


func _wait(cond: Callable) -> bool:
	for i: int in 60 * 20:
		if cond.call():
			return true
		await process_frame
	return false


func _frames(n: int) -> void:
	for i: int in n:
		await process_frame


func _check(ok: bool, why: String) -> void:
	if not ok:
		_ok = false
		push_error("render_hub_icons: " + why)


func _save(out_dir: String, file_name: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	var path: String = out_dir.path_join(file_name)
	var err: Error = root.get_texture().get_image().save_png(path)
	print("render_hub_icons: %s (%s)" % [path, error_string(err)])
