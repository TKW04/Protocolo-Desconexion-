## Capturas a 1:1 (1280x720) del hub REAL (scenes/hub/hub.tscn, abierto
## directamente; en el juego se llega al completar un nivel: la llegada tras
## el 1-1 la captura el bot, tools/play_level_bot.gd --shots) con el arte final. Usa
## su propio guardado (user://render_hub_save.json, se borra al terminar), nunca
## el del jugador. Antes de entrar simula haber completado el 1-1 con 9 puntos
## (cambios sin guardar).
##   01_llegada_vortice.png      Isak materializandose en P por el vortice
##   02_hub_llegada.png          Isak en P con el control; HUD con Modo Avion y «Sin guardar»
##   03_copia_local_prompt.png   Isak junto a la copia local: tecla del pulso
##   04_copia_local_panel.png    panel abierto (resumen) con Isak de espaldas
##   05_copia_local_confirmar.png confirmacion «¿Guardar copia local?»
##   06_copia_guardada.png       «Copia guardada», destello y el indicador apagado
##   07_calc_prompt.png          Isak junto a Calc dormida: tecla del pulso (simula 30 puntos para comprar)
##   08_calc_tienda.png          tienda de Calc: saldo, power banks, mejoras con coste y estado, detalle
##   09_calc_compra.png          «Comprada: Pulso amplio» (25 puntos menos; «Sin guardar» de nuevo)
##   10_calc_faltan_puntos.png   Sync reforzado elegido: «No tienes puntos suficientes»
##   11_carpeta_prompt.png       Isak en la repisa de M1: tecla del pulso
##   12_panel_subniveles.png     panel de subniveles de M1 (1-1 completado, 1-2 y 1-3 Proximamente)
##   13_carpeta_bloqueada.png    Isak en la repisa de M2: «Sin descargar»
##   14_confirmar_sin_guardar.png elegir el 1-1 con cambios sin guardar (la compra):
##                               «¿Seguro? Aún no has guardado.» (Entrar sin guardar / Volver)
##   15_entrar_vortice.png       tras «Entrar sin guardar»: Isak de espaldas absorbido por el vortice
##                               (el nivel no se carga: scene_switcher lo descarta)
## Necesita ventana (no funciona con --headless).
## Uso: Godot --path . -s tools/render_hub.gd [-- carpeta_salida]
extends SceneTree

const SCENE: String = "res://scenes/hub/hub.tscn"
const DEFAULT_OUT: String = "user://hub"
const SAVE_PATH: String = "user://render_hub_save.json"
const TILE: float = 64.0
const WAIT_FRAMES: int = 60 * 20

var _hub: Node
var _ok: bool = true


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var out_dir: String = args[0] if args.size() > 0 else ProjectSettings.globalize_path(DEFAULT_OUT)
	DirAccess.make_dir_recursive_absolute(out_dir)
	var state: Node = root.get_node(^"GameState")
	state.call(&"use_save_path", SAVE_PATH, true)
	state.set(&"current_level", &"1-1")
	for i: int in 9:
		state.call(&"capture_attention_point", &"1-1", StringName("punto_%d" % i), 1)
	state.call(&"mark_level_completed", &"1-1")
	_hub = (load(SCENE) as PackedScene).instantiate()
	root.add_child(_hub)
	# 1. Llegada: el vortice cerrandose con Isak a medias.
	var vortex: Node = _hub.call(&"get_arrival_vortex")
	_check(vortex != null, "no hay vortice de llegada")
	_check(await _wait(func() -> bool:
		return is_instance_valid(vortex) and int(vortex.call(&"get_phase")) == 3 \
			and (vortex.get_node(^"Sprite") as AnimatedSprite2D).frame >= 1), "el vortice no se cierra")
	await _save_frozen(out_dir, "01_llegada_vortice.png")
	_check(await _wait(func() -> bool: return _hub.call(&"has_arrived")), "Isak no llega")
	await _frames(20)
	await _save(out_dir, "02_hub_llegada.png")
	# 3. Junto a la copia local.
	var station: Node = _hub.call(&"get_station", &"copia_local")
	var isak: Node2D = _hub.call(&"get_isak")
	var fake: RefCounted = (load("res://scripts/player/player_input.gd") as GDScript).new()
	isak.set(&"input", fake)
	fake.set(&"move_axis", -1.0)
	_check(await _wait(func() -> bool: return isak.global_position.x < 3.0 * TILE), "Isak no llega a la estacion")
	isak.global_position = Vector2(2.6 * TILE, isak.global_position.y)
	fake.set(&"move_axis", 0.0)
	await _frames(30)
	_check(station.call(&"is_key_hint_visible"), "no sale la tecla del pulso")
	await _save(out_dir, "03_copia_local_prompt.png")
	# 4. Pulso: panel abierto con Isak de espaldas.
	fake.set(&"pulse_pressed", true)
	await physics_frame
	await physics_frame
	fake.set(&"pulse_pressed", false)
	_check(await _wait(func() -> bool: return station.call(&"is_panel_open") and isak.call(&"is_facing_back")),
		"no se abre el panel")
	await _frames(20)
	await _save(out_dir, "04_copia_local_panel.png")
	var panel: Node = station.call(&"get_copy_panel")
	panel.call(&"select_option", &"save")
	panel.call(&"confirm")
	await _frames(4)
	await _save(out_dir, "05_copia_local_confirmar.png")
	panel.call(&"select_option", &"yes")
	panel.call(&"confirm")
	_check(not state.call(&"has_unsaved_changes"), "no se guardo")
	await _frames(2)
	await _save_frozen(out_dir, "06_copia_guardada.png")
	panel.call(&"cancel")
	_check(await _wait(func() -> bool: return not isak.call(&"is_facing_back")), "no se cierra la copia local")
	# 7. Calc dormida: Isak a su izquierda, mirandola (30 puntos para poder comprar).
	state.set(&"attention_points", 30)
	var calc: Node = _hub.call(&"get_calc")
	isak.global_position = Vector2(6.4 * TILE, isak.global_position.y)
	await _nudge(fake, 1.0)
	await _frames(30)
	_check(calc.call(&"is_key_hint_visible"), "no sale la tecla del pulso junto a Calc")
	await _save(out_dir, "07_calc_prompt.png")
	# 8. Pulso: tienda de Calc.
	fake.set(&"pulse_pressed", true)
	await physics_frame
	await physics_frame
	fake.set(&"pulse_pressed", false)
	_check(await _wait(func() -> bool: return calc.call(&"is_panel_open") and isak.call(&"is_facing_back")),
		"no se abre la tienda de Calc")
	await _frames(20)
	await _save(out_dir, "08_calc_tienda.png")
	# 9. Comprar Pulso amplio (la primera).
	var shop: Node = calc.call(&"get_calc_panel")
	shop.call(&"select_option", &"wide_pulse")
	shop.call(&"confirm")
	_check(state.call(&"is_upgrade_purchased", &"wide_pulse"), "no se compra Pulso amplio")
	_check(state.call(&"has_unsaved_changes"), "comprar no marca sin guardar")
	await _frames(4)
	await _save(out_dir, "09_calc_compra.png")
	# 10. Sin puntos para Sync reforzado.
	shop.call(&"select_option", &"reinforced_sync")
	shop.call(&"confirm")
	_check(not state.call(&"is_upgrade_purchased", &"reinforced_sync"), "compra sin puntos")
	await _frames(4)
	await _save(out_dir, "10_calc_faltan_puntos.png")
	shop.call(&"cancel")
	_check(await _wait(func() -> bool: return not isak.call(&"is_facing_back")), "no se cierra la tienda")
	# 11. Carpeta M1: Isak de pie en su repisa.
	var folder: Node2D = _hub.call(&"get_folder", &"m1")
	isak.global_position = Vector2(folder.position.x + 96.0, float(_hub.call(&"get_shelf_top_y")))
	await _nudge(fake, -1.0)
	await _frames(30)
	_check(folder.call(&"is_key_hint_visible"), "no sale la tecla del pulso en la carpeta")
	await _save(out_dir, "11_carpeta_prompt.png")
	# 12. Pulso: panel de subniveles.
	fake.set(&"pulse_pressed", true)
	await physics_frame
	await physics_frame
	fake.set(&"pulse_pressed", false)
	_check(await _wait(func() -> bool: return folder.call(&"is_panel_open")), "no se abre el panel de la carpeta")
	await _frames(20)
	await _save(out_dir, "12_panel_subniveles.png")
	var folder_panel: Node = folder.call(&"get_folder_panel")
	folder_panel.call(&"cancel")
	_check(await _wait(func() -> bool: return not isak.call(&"is_facing_back")), "no se cierra la carpeta")
	# 13. Carpeta bloqueada (M2).
	var locked: Node2D = _hub.call(&"get_folder", &"m2")
	isak.global_position = Vector2(locked.position.x + 32.0, float(_hub.call(&"get_shelf_top_y")))
	await _nudge(fake, 1.0)
	await _frames(30)
	_check(locked.call(&"is_locked_hint_visible"), "no sale «Sin descargar»")
	await _save(out_dir, "13_carpeta_bloqueada.png")
	# 14. Elegir el 1-1 con cambios sin guardar: confirmacion.
	_hub.set(&"scene_switcher", func(runner: Node) -> void: runner.free())
	isak.global_position = Vector2(folder.position.x + 96.0, float(_hub.call(&"get_shelf_top_y")))
	await _frames(30)
	folder.call(&"open", isak)
	folder_panel.call(&"select_option", &"1-1")
	folder_panel.call(&"confirm")
	_check(folder_panel.call(&"is_confirming_unsaved"), "no pide confirmar con cambios sin guardar")
	await _frames(4)
	await _save(out_dir, "14_confirmar_sin_guardar.png")
	# 15. Entrar sin guardar: vortice de salida (sin cargar el nivel).
	folder_panel.call(&"select_option", &"enter_unsaved")
	folder_panel.call(&"confirm")
	var departure: Node = _hub.call(&"get_departure_vortex")
	_check(departure != null, "no hay vortice de salida")
	_check(await _wait(func() -> bool:
		return is_instance_valid(departure) and int(departure.call(&"get_phase")) == 3), "el vortice de salida no se cierra")
	await _save_frozen(out_dir, "15_entrar_vortice.png")
	_check(await _wait(func() -> bool: return not _hub.is_inside_tree()), "no se pasa al nivel")
	print("render_hub: %s" % ("OK" if _ok else "FALLO"))
	if is_instance_valid(_hub):
		_hub.queue_free()
	await process_frame
	state.call(&"use_save_path", SAVE_PATH, true)
	quit(0 if _ok else 1)


## Un paso de fisica moviendose hacia `axis`: corta la animacion de la terminal
## holografica (idle largo) y deja a Isak mirando a ese lado.
func _nudge(fake: RefCounted, axis: float) -> void:
	fake.set(&"move_axis", axis)
	await physics_frame
	await physics_frame
	fake.set(&"move_axis", 0.0)


func _wait(cond: Callable) -> bool:
	for i: int in WAIT_FRAMES:
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
		push_error("render_hub: " + why)


## Captura con el arbol en pausa (la fase actual no avanza mientras se guarda).
func _save_frozen(out_dir: String, file_name: String) -> void:
	paused = true
	await _save(out_dir, file_name)
	paused = false


func _save(out_dir: String, file_name: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	var path: String = out_dir.path_join(file_name)
	var err: Error = root.get_texture().get_image().save_png(path)
	print("render_hub: %s (%s)" % [path, error_string(err)])
