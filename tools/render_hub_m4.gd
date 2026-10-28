## Capturas a 1:1 (1280x720) del hub con las carpetas del Mundo 4 y el Mundo 5
## (paso 22 de docs/propuesta-mundo-4.md §8, 2026-10-28; scenes/hub/hub.tscn
## abierto directamente). Usa su propio guardado (user://render_hub_m4_save.json,
## se borra al terminar), nunca el del jugador. Eco, Notas y Calc conocidos,
## La Curadora vencida y la actualizacion del hub instalada.
##   01_m4_filas_inicio.png    panel de M4 recien instalada: el 4-1 jugable
##   02_m4_filas_jefe.png      panel de M4 con el 4-1, el 4-2 y el 4-3 completados
##                             y la fila «Jefe: El Visto» jugable
##   03_pagina1_pieza_coral.png pagina 1 con la pieza coral encendida (El Visto vencido)
##   04_pagina2_m5_disponible.png pagina 2: M4 y M5 disponible (Isak en la repisa de M5)
##   05_m5_proximamente.png    panel de M5 abierto: «Próximamente»
##   06_pagina3_candado_4.png  pagina 3: M6 con 4 de 5 ranuras encendidas
## Necesita ventana (no funciona con --headless) y --fixed-fps 60.
## Uso: Godot --fixed-fps 60 --path . -s tools/render_hub_m4.gd [-- carpeta_salida]
extends SceneTree

const SCENE: String = "res://scenes/hub/hub.tscn"
const DEFAULT_OUT: String = "user://hub_m4"
const SAVE_PATH: String = "user://render_hub_m4_save.json"
const TILE: float = 64.0

var _ok: bool = true


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var out_dir: String = args[0] if args.size() > 0 else ProjectSettings.globalize_path(DEFAULT_OUT)
	DirAccess.make_dir_recursive_absolute(out_dir)
	var state: Node = root.get_node(^"GameState")
	state.call(&"use_save_path", SAVE_PATH, true)
	for ally: StringName in [&"eco", &"notas", &"calc"]:
		state.call(&"meet_ally", ally)
	for ability: StringName in [&"pulse", &"laser", &"debug", &"dash", &"ground_pound", &"compress"]:
		state.call(&"obtain_ability", ability)
	for id: StringName in [&"1-1", &"1-2", &"1-3", &"1-boss", &"2-1", &"2-2", &"2-3", &"2-boss",
			&"3-1", &"3-2", &"3-3", &"3-boss"]:
		state.call(&"unlock_level", id)
		state.call(&"mark_level_completed", id)
	for memory: StringName in [&"boss_w1_l1", &"boss_w2_l1", &"boss_w3_l1"]:
		state.call(&"obtain_memory", memory)
	state.call(&"install_hub_upgrade", &"hub_update_4_6")
	state.call(&"unlock_level", &"4-1")
	# 1. M4 recien instalada.
	var hub: Node = await _open()
	var isak: Node2D = hub.call(&"get_isak")
	await _panel(hub, isak, &"m4", out_dir, "01_m4_filas_inicio.png")
	hub.free()
	# 2. Con los tres niveles completados: fila del jefe.
	for id: StringName in [&"4-1", &"4-2", &"4-3"]:
		state.call(&"unlock_level", id)
		state.call(&"mark_level_completed", id)
	state.call(&"obtain_ability", &"shockwave")
	state.call(&"meet_ally", &"linterna")
	state.call(&"unlock_level", &"4-boss")
	hub = await _open()
	isak = hub.call(&"get_isak")
	await _panel(hub, isak, &"m4", out_dir, "02_m4_filas_jefe.png")
	hub.free()
	# 3-6. El Visto vencido.
	state.call(&"mark_level_completed", &"4-boss")
	state.call(&"obtain_memory", &"boss_w4_l1")
	hub = await _open()
	isak = hub.call(&"get_isak")
	_check(await _wait(func() -> bool: return not bool(hub.call(&"is_piece_pending")) \
		and not bool(hub.call(&"is_piece_lighting"))), "la pieza coral no termina de encenderse")
	await _frames(20)
	_check(hub.call(&"get_piece_animation", 4) == &"on", "la pieza coral no esta encendida")
	await _save(out_dir, "03_pagina1_pieza_coral.png")
	await _stand_on(hub, isak, &"m5")
	await _save(out_dir, "04_pagina2_m5_disponible.png")
	var m5: Node = hub.call(&"get_folder", &"m5")
	_check(bool(m5.call(&"open", isak)), "M5 no se abre")
	await _frames(20)
	await _save(out_dir, "05_m5_proximamente.png")
	m5.call(&"close", true)
	isak.call(&"face_side")
	# Isak a un lado de la repisa para que no tape el candado.
	var m6: Node = await _stand_on(hub, isak, &"m6", 150.0)
	_check(int(m6.call(&"get_lock_slots_lit")) == 4, "el candado de M6 no tiene 4 ranuras")
	await _save(out_dir, "06_pagina3_candado_4.png")
	hub.free()
	SaveFile.delete(SAVE_PATH)
	quit(0 if _ok else 1)


## Isak en la repisa de la carpeta `id` y su panel abierto.
func _panel(hub: Node, isak: Node2D, id: StringName, out_dir: String, file_name: String) -> void:
	var folder: Node = await _stand_on(hub, isak, id)
	_check(bool(folder.call(&"open", isak)), "%s no se abre" % id)
	await _frames(20)
	await _save(out_dir, file_name)
	folder.call(&"close", true)
	isak.call(&"face_side")


## Isak de pie en la repisa de la carpeta `id` (con el aviso o la tecla encima).
func _stand_on(hub: Node, isak: Node2D, id: StringName, dx: float = 64.0) -> Node:
	var folder: Node2D = hub.call(&"get_folder", id)
	isak.global_position = Vector2(folder.position.x + dx, float(hub.call(&"get_shelf_top_y")))
	isak.set(&"velocity", Vector2.ZERO)
	await _frames(6)
	hub.call(&"finish_page_slide")
	await _frames(40)
	return folder


## Cierra todas las lineas del cuadro de texto (importantes y no importantes).
func _close_lines(box: Node) -> void:
	for i: int in 30:
		await _frames(2)
		if not bool(box.call(&"is_showing")):
			return
		box.call(&"finish_typing")
		box.call(&"confirm")
		box.call(&"advance", 30.0)


func _open() -> Node:
	var hub: Node = (load(SCENE) as PackedScene).instantiate()
	root.add_child(hub)
	_check(await _wait(func() -> bool: return hub.call(&"has_arrived")), "Isak no llega")
	await _close_lines(hub.call(&"get_text_box"))
	return hub


func _check(cond: bool, msg: String) -> void:
	if not cond:
		_ok = false
		push_error("render_hub_m4: " + msg)


func _wait(cond: Callable, max_frames: int = 60 * 10) -> bool:
	for i: int in max_frames:
		if cond.call():
			return true
		await process_frame
	return bool(cond.call())


func _frames(n: int) -> void:
	for i: int in n:
		await process_frame


func _save(out_dir: String, file_name: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	var path: String = out_dir.path_join(file_name)
	var err: Error = root.get_texture().get_image().save_png(path)
	print("render_hub_m4: %s (%s)" % [path, error_string(err)])
