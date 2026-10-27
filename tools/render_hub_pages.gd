## Capturas a 1:1 (1280x720) del hub de varias paginas (2026-10-27, paso 2 de
## docs/propuesta-hub-mundos-4-6.md; scenes/hub/hub.tscn abierto directamente).
## Usa su propio guardado (user://render_hub_pages_save.json, se borra al
## terminar), nunca el del jugador. Eco y Notas conocidos (sin presentacion).
##   01_pagina1_sin_curadora.png  antes de vencer a La Curadora: una pagina, como siempre
##   02_pagina1_con_3boss.png     con 3-boss: glitch del borde derecho e indicador de 2 puntos
##                                (el segundo cargando); Isak junto al borde
##   03_deslizando.png            la camara a mitad del deslizamiento a la pagina 2
##   04_pagina2_en_instalacion.png pagina 2 «en instalacion» (sala vacia, fondo provisional)
## Necesita ventana (no funciona con --headless).
## Uso: Godot --path . -s tools/render_hub_pages.gd [-- carpeta_salida]
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
	state.call(&"obtain_ability", &"pulse")
	for id: StringName in [&"1-1", &"1-2", &"1-3", &"1-boss", &"2-1", &"2-2", &"2-3", &"2-boss",
			&"3-1", &"3-2", &"3-3"]:
		state.call(&"mark_level_completed", id)
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
	await _save(out_dir, "04_pagina2_en_instalacion.png")
	hub.free()
	SaveFile.delete(SAVE_PATH)
	quit(0 if _ok else 1)


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
