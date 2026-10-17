## Capturas a 1:1 (1280x720) de la TIENDA DE CALC POR PISTAS (tanda M1 de
## docs/propuesta-mejoras.md, 2026-10-17) en el hub real y del HUD con los
## maximos mayores. Usa su propio guardado (user://render_calc_shop_save.json, se
## borra al terminar), nunca el del jugador. Calc conocida, pulso y laser
## obtenidos, Debug sin obtener, 30 puntos, acceso Cache (vuelta 1).
##   01_inicio.png               tienda abierta: selector en Pulso (1 de 5), detalle de Pulso amplio
##   02_fila_laser.png           selector en Laser: detalle de Laser rapido
##   03_fila_debug_chip.png      selector en Debug sin obtener: chip «?», sin nombre ni efecto
##   04_fila_sync.png            selector en Sync Rate: Sync reforzado (110)
##   05_fila_energia.png         selector en Energia: Bateria ampliada (110)
##   06_compra_cargando.png      tras comprar el Pulso 2: el recuadro nuevo se carga
##   07_tras_comprar_2de5.png    Pulso 2 de 5; siguiente, Pulso aturdidor; «Faltan 10 puntos»
##   08_sin_puntos.png           Sync elegida con 5 puntos: «Faltan 10 puntos.»
##   09_bloqueado_acceso.png     Pulso 3 de 5 en Cache: «Requiere acceso Kernel» (candados)
##   10_proximamente.png         acceso Kernel: el Pulso 4 (Ocultarte) «Proximamente»
##   11_debug_obtenido.png       Debug obtenido y en el nivel 2: el 3 «Proximamente»
##   12_nivel_maximo.png         Sync Rate 5 de 5: «Nivel maximo»
##   13_hud_maximos.png          sala de prueba con Sync Rate 4 y Energia 4: HUD a 130 %
##   14_hud_maximos_mitad.png    la misma con Sync 65 y energia 65 de 130 (barras a la mitad)
## Necesita ventana (no funciona con --headless).
## Uso: Godot --path . -s tools/render_calc_shop.gd [-- carpeta_salida]
extends SceneTree

const SCENE: String = "res://scenes/hub/hub.tscn"
const ARENA: String = "res://scenes/levels/test_arena.tscn"
const DEFAULT_OUT: String = "user://calc_shop"
const SAVE_PATH: String = "user://render_calc_shop_save.json"
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
	var state: Node = root.get_node("GameState")
	state.call(&"use_save_path", SAVE_PATH, true)
	state.set(&"current_level", &"1-2")
	state.call(&"mark_level_completed", &"1-1")
	state.call(&"mark_level_completed", &"1-2")
	for ally: StringName in [&"eco", &"notas", &"calc"]:
		state.call(&"meet_ally", ally)
	state.call(&"obtain_ability", &"pulse")
	state.call(&"obtain_ability", &"laser")
	state.set(&"attention_points", 30)
	state.call(&"save_game")
	_hub = (load(SCENE) as PackedScene).instantiate()
	root.add_child(_hub)
	var vortex: Node = _hub.call(&"get_arrival_vortex")
	if vortex != null:
		vortex.call(&"advance", 5.0)
	var isak: Node2D = _hub.call(&"get_isak")
	var fake: RefCounted = (load("res://scripts/player/player_input.gd") as GDScript).new()
	isak.set(&"input", fake)
	var calc: Node = _hub.call(&"get_calc")
	isak.global_position = Vector2(6.6 * TILE, isak.global_position.y)
	await _nudge(fake, 1.0)
	await _frames(20)
	_check(calc.call(&"open", isak), "no se abre la tienda")
	var shop: Node = calc.call(&"get_calc_panel")
	shop.call(&"skip_input_delay")
	await _frames(20)
	await _save(out_dir, "01_inicio.png")
	var rows: Array = [["laser", "02_fila_laser.png"], ["debug", "03_fila_debug_chip.png"],
		["sync", "04_fila_sync.png"], ["energia", "05_fila_energia.png"]]
	for row: Array in rows:
		shop.call(&"select_option", StringName(row[0]))
		await _frames(6)
		await _save(out_dir, String(row[1]))
	# Comprar el Pulso 2 (Pulso amplio): el recuadro se carga.
	shop.call(&"select_option", &"pulso")
	shop.call(&"confirm")
	_check(int(state.call(&"get_upgrade_level", &"pulso")) == 2, "no se compra el Pulso 2")
	shop.call(&"advance_for_tests", 0.15)
	await _save_frozen(out_dir, "06_compra_cargando.png")
	shop.call(&"finish_buy_animation")
	await _frames(4)
	await _save(out_dir, "07_tras_comprar_2de5.png")
	shop.call(&"select_option", &"sync")
	shop.call(&"confirm")
	_check(int(state.call(&"get_upgrade_level", &"sync")) == 1, "compra sin puntos")
	await _frames(4)
	await _save(out_dir, "08_sin_puntos.png")
	# Pulso 3 en Cache: el 4 pide Kernel.
	state.set(&"attention_points", 60)
	shop.call(&"select_option", &"pulso")
	shop.call(&"confirm")
	shop.call(&"finish_buy_animation")
	shop.call(&"confirm")
	_check(int(state.call(&"get_upgrade_level", &"pulso")) == 3, "el Pulso no llega al nivel 3")
	await _frames(4)
	await _save(out_dir, "09_bloqueado_acceso.png")
	# Kernel: el Pulso 4 (Ocultarte) es de la tanda M2.
	state.set(&"lap", 2)
	shop.call(&"refresh")
	shop.call(&"confirm")
	await _frames(4)
	await _save(out_dir, "10_proximamente.png")
	# Debug obtenido en el nivel 2: el 3 (revelado persistente) «Proximamente».
	state.call(&"obtain_ability", &"debug")
	var levels: Dictionary = state.get(&"upgrade_levels")
	levels[&"debug"] = 2
	shop.call(&"set_message", "")
	shop.call(&"select_option", &"debug")
	shop.call(&"refresh")
	await _frames(4)
	await _save(out_dir, "11_debug_obtenido.png")
	levels[&"sync"] = 5
	shop.call(&"select_option", &"sync")
	shop.call(&"refresh")
	await _frames(4)
	await _save(out_dir, "12_nivel_maximo.png")
	calc.call(&"close", true)
	_hub.queue_free()
	await process_frame
	# HUD con los maximos mayores en la sala de prueba de movimiento.
	levels[&"energia"] = 4
	levels[&"sync"] = 4
	var arena: Node = (load(ARENA) as PackedScene).instantiate()
	root.add_child(arena)
	await _frames(30)
	state.set(&"sync_rate", 130.0)
	state.set(&"debug_energy", 130.0)
	await _frames(60)
	_check(is_equal_approx(float(state.get(&"sync_rate")), 130.0), "el Sync Rate no llega a 130")
	await _save(out_dir, "13_hud_maximos.png")
	state.set(&"sync_rate", 65.0)
	state.set(&"debug_energy", 65.0)
	await _frames(90)
	await _save(out_dir, "14_hud_maximos_mitad.png")
	arena.queue_free()
	await process_frame
	print("render_calc_shop: %s" % ("OK" if _ok else "FALLO"))
	state.call(&"use_save_path", SAVE_PATH, true)
	SaveFile.delete(SAVE_PATH)
	quit(0 if _ok else 1)


func _nudge(fake: RefCounted, axis: float) -> void:
	fake.set(&"move_axis", axis)
	await physics_frame
	await physics_frame
	fake.set(&"move_axis", 0.0)


func _frames(n: int) -> void:
	for i: int in n:
		await process_frame


func _check(ok: bool, why: String) -> void:
	if not ok:
		_ok = false
		push_error("render_calc_shop: " + why)


func _save_frozen(out_dir: String, file_name: String) -> void:
	paused = true
	await _save(out_dir, file_name)
	paused = false


func _save(out_dir: String, file_name: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	var path: String = out_dir.path_join(file_name)
	var err: Error = root.get_texture().get_image().save_png(path)
	print("render_calc_shop: %s (%s)" % [path, error_string(err)])
