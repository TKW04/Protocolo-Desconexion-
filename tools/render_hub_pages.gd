## Capturas a 1:1 (1280x720) del hub de varias paginas (2026-10-27, paso 2 de
## docs/propuesta-hub-mundos-4-6.md; scenes/hub/hub.tscn abierto directamente).
## Usa su propio guardado (user://render_hub_pages_save.json, se borra al
## terminar), nunca el del jugador. Eco y Notas conocidos (sin presentacion).
##   01_pagina1_sin_curadora.png  antes de vencer a La Curadora: una pagina, como siempre
##   02_pagina1_con_3boss.png     con 3-boss: glitch del borde derecho e indicador de 2 puntos
##                                (el segundo cargando); Isak junto al borde
##   03_deslizando.png            la camara a mitad del deslizamiento a la pagina 2
##   04_pagina2_en_instalacion.png pagina 2 «en instalacion» con el acertijo montado (paso 3:
##                                V1-V3, instalador 0/3, cargador; arte provisional)
##   05_acertijo_en_marcha.png    (paso 3) con el Debug activo (lector1 visible), la
##                                plataforma «Cargando...» arriba, el marco del nicho
##                                iluminado y V1 encendida (instalador 1/3)
##   06_instalando.png            (paso 5) instalacion: barra «Instalando…» a medio llenar
##   07_notas_tres_carpetas.png   (paso 5) tras el destello: pagina 2 final y la linea de Notas
##   08_pagina2_final.png         (paso 5) pagina 2 con M4 (disponible) y M5 bloqueada: Isak en
##                                la repisa de M5 («Sin descargar» + «Completa el mundo anterior»)
##   09_pagina3_la_nube.png       (paso 5) pagina 3: M6 bloqueada con el candado de 5 ranuras (3
##                                encendidas: recuerdos de jefe 1-3) y las dos lineas
##   10_m4_proximamente.png       (paso 5) panel de M4 abierto: «Próximamente»
##   11_pagina1_pieza4.png        (paso 5) pagina 1 con la pieza 4 (coral PROVISIONAL) en off
## Necesita ventana (no funciona con --headless) y --fixed-fps 60 (las esperas van
## por cuadros: sin el, a veces «Isak no llega» en las capturas 01-02).
## Uso: Godot --fixed-fps 60 --path . -s tools/render_hub_pages.gd [-- carpeta_salida]
extends SceneTree

const SCENE: String = "res://scenes/hub/hub.tscn"
const DEFAULT_OUT: String = "user://hub_pages"
const SAVE_PATH: String = "user://render_hub_pages_save.json"
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
	state.call(&"meet_ally", &"eco")
	state.call(&"meet_ally", &"notas")
	for ability: StringName in [&"pulse", &"laser", &"debug", &"dash", &"ground_pound", &"compress"]:
		state.call(&"obtain_ability", ability)
	for id: StringName in [&"1-1", &"1-2", &"1-3", &"1-boss", &"2-1", &"2-2", &"2-3", &"2-boss",
			&"3-1", &"3-2", &"3-3"]:
		state.call(&"mark_level_completed", id)
	for memory: StringName in [&"boss_w1_l1", &"boss_w2_l1", &"boss_w3_l1"]:
		state.call(&"obtain_memory", memory)
	# 1. Antes de La Curadora.
	var hub: Node = await _open()
	await _frames(30)
	await _save(out_dir, "01_pagina1_sin_curadora.png")
	hub.free()
	# 2. Con 3-boss: acertijo pendiente.
	state.call(&"mark_level_completed", &"3-boss")
	hub = await _open()
	_check(int(hub.call(&"get_page_count")) == 2, "sin pagina 2 con 3-boss")
	var isak: Node2D = hub.call(&"get_isak")
	var fake: RefCounted = (load("res://scripts/player/player_input.gd") as GDScript).new()
	isak.set(&"input", fake)
	isak.global_position = Vector2(17.5 * TILE, isak.global_position.y)
	await _frames(70)
	await _save(out_dir, "02_pagina1_con_3boss.png")
	fake.set(&"move_axis", 1.0)
	_check(await _wait(func() -> bool: return hub.call(&"is_page_sliding")), "no se desliza")
	await _frames(10)
	await _save(out_dir, "03_deslizando.png")
	_check(await _wait(func() -> bool: return not hub.call(&"is_page_sliding")), "no termina")
	fake.set(&"move_axis", 0.0)
	await _frames(40)
	_check(int(hub.call(&"get_current_page")) == 2, "no llega a la pagina 2")
	# La linea de Eco de la pagina 2 (paso 6) sale entera en la 04 y se cierra antes
	# de la 05 para que no tape el instalador en las 05-06.
	(hub.call(&"get_text_box") as Node).call(&"finish_typing")
	await _frames(10)
	await _save(out_dir, "04_pagina2_en_instalacion.png")
	await _close_lines(hub.call(&"get_text_box"))
	# 5. Acertijo en marcha (paso 3).
	var puzzle: Node = hub.call(&"get_update_puzzle")
	_check(puzzle != null, "sin acertijo en la pagina 2")
	if puzzle != null:
		var debug: Node = root.get_node(^"DebugMode")
		debug.set(&"input_enabled", false)
		for i: int in 120:
			debug.call(&"step", 1.0 / 60.0, true)
		(puzzle.call(&"get_plate") as Node).call(&"press")
		(puzzle.call(&"get_reader3") as Node).call(&"power")
		(puzzle.call(&"get_check", &"v1") as Node).call(&"complete")
		isak.global_position = Vector2(20.0 * TILE + 4.5 * TILE, isak.global_position.y)
		await _frames(30)
		await _save(out_dir, "05_acertijo_en_marcha.png")
		debug.call(&"reset")
		debug.set(&"input_enabled", true)
		# 6-11. Instalacion y upgrade (paso 5).
		for id: StringName in [&"v2", &"v3"]:
			(puzzle.call(&"get_check", id) as Node).call(&"complete")
		isak.global_position = Vector2(20.0 * TILE + 9.0 * TILE, 9.0 * TILE)
		await _frames(20)
		(puzzle.call(&"get_installer") as Node).emit_signal(&"install_requested", &"hub_update_4_6")
		var install: Node = hub.call(&"get_update_install")
		_check(install != null, "no empieza la instalacion")
		if install != null:
			# La instalacion corre en tiempo real; aqui se avanza a mano (determinista).
			install.call(&"advance", 1.6)
			await _frames(10)
			await _save(out_dir, "06_instalando.png")
			install.call(&"advance", 1.5)
			install.call(&"advance", 0.31)
			_check(int(install.call(&"get_step")) == 3, "sin linea de Notas")
			var box: Node = hub.call(&"get_text_box")
			box.call(&"finish_typing")
			await _frames(20)
			await _save(out_dir, "07_notas_tres_carpetas.png")
			box.call(&"confirm")
			box.call(&"advance", 1.0)
			_check(await _wait(func() -> bool: return bool(install.call(&"is_done"))), "no termina la instalacion")
			# Cierra lo que quede en el cuadro: la linea de Notas (importante, pausa)
			# y el recordatorio «¡Apuntado! Guárdalo…» (no importante, paso 6).
			await _close_lines(hub.call(&"get_text_box"))
			_check(not paused, "el juego sigue en pausa tras la instalacion")
		_check(int(hub.call(&"get_page_count")) == 3, "sin pagina 3 tras instalar")
		await _stand_on(hub, isak, &"m5")
		await _save(out_dir, "08_pagina2_final.png")
		await _stand_on(hub, isak, &"m6")
		_check(int(hub.call(&"get_current_page")) == 3, "no llega a la pagina 3")
		await _save(out_dir, "09_pagina3_la_nube.png")
		var m4: Node = await _stand_on(hub, isak, &"m4")
		_check(bool(m4.call(&"open", isak)), "M4 no se abre")
		await _frames(20)
		await _save(out_dir, "10_m4_proximamente.png")
		m4.call(&"close", true)
		isak.call(&"face_side")
		isak.global_position = Vector2(10.0 * TILE, 9.0 * TILE)
		await _frames(10)
		hub.call(&"finish_page_slide")
		await _frames(40)
		await _save(out_dir, "11_pagina1_pieza4.png")
	hub.free()
	SaveFile.delete(SAVE_PATH)
	quit(0 if _ok else 1)


## Isak de pie en la repisa de la carpeta `id` (con el aviso o la tecla encima).
func _stand_on(hub: Node, isak: Node2D, id: StringName) -> Node:
	var folder: Node2D = hub.call(&"get_folder", id)
	isak.global_position = Vector2(folder.position.x + 64.0, float(hub.call(&"get_shelf_top_y")))
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
	return hub


func _check(cond: bool, msg: String) -> void:
	if not cond:
		_ok = false
		push_error("render_hub_pages: " + msg)


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
	print("render_hub_pages: %s (%s)" % [path, error_string(err)])
