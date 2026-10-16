## Capturas a 1:1 (1280x720) de la llegada por el vortice y de la terminal de
## salida del 1-1 con el flujo de juego real (scenes/main.tscn; guardado de
## herramientas user://tool_save.json, nunca el del jugador):
##   01_inicio_vortice.png         la llegada: el nivel ya visible y el vortice de llegada (sin pausa: desde el
##                                 encuentro con Eco, 2026-10-16, el 1-1 no tiene linea al empezar)
##   02_vortice_a_medias.png       el vortice cerrandose con Isak materializandose
##   03_terminal_apagada.png       terminal apagada (Isak lejos)
##   04_terminal_prompt_g.png      Isak cerca: prompt y tecla del pulso
##   05_terminal_destello_giro.png destello cian del giro: pantalla llena de cian, Isak ya de espaldas
##   06_isak_espaldas_terminal.png Isak de espaldas frente a la terminal activa (antes del vortice)
##   07_vortice_salida_espaldas.png vortice de salida absorbiendo a Isak de espaldas
## Partida que ya paso por el encuentro con Eco (Eco conocido y pulso obtenido):
## la terminal necesita el pulso. Necesita ventana (no funciona con --headless).
## Uso: Godot --path . -s tools/render_warp_terminal.gd [-- carpeta_salida]
extends SceneTree

const SCENE: String = "res://scenes/main.tscn"
const DEFAULT_OUT: String = "user://warp_terminal"
const TILE: float = 64.0
const WAIT_FRAMES: int = 60 * 20

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
	_main = (load(SCENE) as PackedScene).instantiate()
	_main.set(&"start_level_id", "1-1")
	root.add_child(_main)
	# 1. Llegada: el vortice ya se ve (sin pausa).
	var arriving: Node = _main.call(&"get_arrival_vortex")
	_check(await _wait(func() -> bool:
		return is_instance_valid(arriving) and float(_main.call(&"get_fade_alpha")) <= 0.0), "el nivel no se ve")
	_check(not paused, "la llegada pausa el juego")
	await _save(out_dir, "01_inicio_vortice.png")
	# 2. Cierra las lineas importantes y captura el vortice a medio cerrar.
	var vortex: Node = _main.call(&"get_arrival_vortex")
	_check(vortex != null, "no hay vortice de llegada")
	_check(await _wait(func() -> bool:
		_confirm_lines()
		return not paused and is_instance_valid(vortex) and vortex.get_node(^"Sprite").frame >= 2), "el vortice no avanza")
	await _save(out_dir, "02_vortice_a_medias.png")
	_check(await _wait(func() -> bool:
		_confirm_lines()
		return not _isak().call(&"is_warping")), "Isak no recupera el control")
	var level: Node = _main.call(&"get_level")
	var bubble: Node = level.get_node_or_null(^"Enemies/burbuja_cierre")
	if bubble != null:
		bubble.queue_free()
	var terminal: Node = level.get_node(^"Objects/terminal_salida")
	# 3. Terminal apagada, Isak lejos.
	_teleport(285.5)
	await _frames(40)
	await _save(out_dir, "03_terminal_apagada.png")
	# 4. Isak frente a la terminal: prompt y tecla.
	_teleport(290.45)
	await _frames(30)
	_check(terminal.call(&"is_key_hint_visible"), "no sale la tecla del pulso")
	await _save(out_dir, "04_terminal_prompt_g.png")
	# 5-7. Pulso: la terminal se enciende, Isak gira de espaldas con el destello
	# y el vortice lo absorbe. Cada captura congela el arbol (pausa) para que la
	# fase no avance mientras se guarda.
	var fake: RefCounted = (load("res://scripts/player/player_input.gd") as GDScript).new()
	_isak().set(&"input", fake)
	fake.set(&"pulse_pressed", true)
	await physics_frame
	await physics_frame
	fake.set(&"pulse_pressed", false)
	_check(await _wait(func() -> bool:
		return terminal.call(&"is_turn_flashing") and _isak().call(&"is_facing_back")), "no hay destello con Isak de espaldas")
	await _save_frozen(out_dir, "05_terminal_destello_giro.png")
	_check(await _wait(func() -> bool:
		return int(terminal.call(&"get_turn_tick")) >= 0 and not terminal.call(&"is_turn_flashing")), "no se ve a Isak de espaldas sin destello")
	await _save_frozen(out_dir, "06_isak_espaldas_terminal.png")
	_check(await _wait(func() -> bool:
		var v: Node = terminal.call(&"get_vortex")
		return v != null and int(v.call(&"get_phase")) >= 2), "no se abre el vortice de salida")
	await _frames(2)
	await _save_frozen(out_dir, "07_vortice_salida_espaldas.png")
	print("render_warp_terminal: %s" % ("OK" if _ok else "FALLO"))
	_main.queue_free()
	await process_frame
	quit(0 if _ok else 1)


func _isak() -> Node2D:
	return _main.call(&"get_isak")


func _teleport(col: float) -> void:
	var isak: Node2D = _isak()
	isak.global_position = Vector2(col * TILE, 10.0 * TILE)
	isak.set(&"velocity", Vector2.ZERO)
	(isak.get_node(^"Camera2D") as Camera2D).reset_smoothing()


func _confirm_lines() -> void:
	var level: Node = _main.call(&"get_level")
	var box: Node = level.get_node_or_null(^"EcoTextBox") if is_instance_valid(level) else null
	while box != null and box.call(&"is_important") and box.call(&"confirm"):
		pass


func _wait(cond: Callable) -> bool:
	# Limite en tiempo real (WAIT_FRAMES a 60 fps): sin vsync los cuadros van mas rapido.
	var deadline: int = Time.get_ticks_msec() + int(WAIT_FRAMES * 1000.0 / 60.0)
	while Time.get_ticks_msec() < deadline:
		if cond.call():
			return true
		await process_frame
	return false


func _frames(n: int) -> void:
	# n cuadros a 60 fps en tiempo real (sin vsync los cuadros van mas rapido).
	await create_timer(n / 60.0).timeout
	await process_frame


func _check(ok: bool, why: String) -> void:
	if not ok:
		_ok = false
		push_error("render_warp_terminal: " + why)


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
	print("render_warp_terminal: %s (%s)" % [path, error_string(err)])
