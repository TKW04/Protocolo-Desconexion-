## Capturas a 1:1 (1280x720) del ENCUENTRO CON CALC en el hub real (2026-10-17,
## tanda H3 del paso 14 del 1-2; CalcIntro, data/calc_intro.json). Simula una
## partida que acaba de completar el 1-2 con 17 puntos: Eco y Notas conocidos y
## Calc teletransportada en esta sesion (EventBus.ally_teleported, como la
## azotea del 1-2), aun desconocida. Usa su propio guardado (se borra al
## terminar), nunca el del jugador.
##   01_llegada_calc_encendida.png  Isak llegando por el vortice; Calc ya en su estacion, despierta
##   02_calc_linea_NN.png           cada linea del encuentro ya escrita (Calc en su cuadro LCD con
##                                  nombre e icono; la de los puntos con el saldo 17 y el rombo)
##   03_calc_escribiendo.png        la linea de los puntos a medio escribir: «17» sale de golpe
##   04_eco_interrumpe.png          la linea de Eco (atenuado) que se descuelga entre las de Calc
##   05_calc_encendida.png          tras la escena: Calc conocida y encendida, tecla del pulso
##   06_tienda_abierta.png          la tienda de Calc abierta (sin cambios)
## Necesita ventana (no funciona con --headless).
## Uso: Godot --path . -s tools/render_calc_intro.gd [-- carpeta_salida]
extends SceneTree

const SCENE: String = "res://scenes/hub/hub.tscn"
const DEFAULT_OUT: String = "user://calc_intro"
const SAVE_PATH: String = "user://render_calc_intro_save.json"
const TILE: float = 64.0
const WAIT_FRAMES: int = 60 * 20
const POINTS: int = 17

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
	state.call(&"meet_ally", &"eco")
	state.call(&"meet_ally", &"notas")
	state.call(&"mark_level_completed", &"1-1")
	state.call(&"mark_level_completed", &"1-2")
	state.set(&"attention_points", POINTS)
	root.get_node(^"EventBus").emit_signal(&"ally_teleported", &"calc")
	_hub = (load(SCENE) as PackedScene).instantiate()
	root.add_child(_hub)
	var vortex: Node = _hub.call(&"get_arrival_vortex")
	_check(await _wait(func() -> bool:
		return is_instance_valid(vortex) and int(vortex.call(&"get_phase")) == 3 \
			and (vortex.get_node(^"Sprite") as AnimatedSprite2D).frame >= 1), "el vortice no se cierra")
	var calc: Node = _hub.call(&"get_calc")
	_check(calc.call(&"get_calc_animation") == &"awake", "Calc deberia llegar despierta")
	await _save_frozen(out_dir, "01_llegada_calc_encendida.png")
	_check(await _wait(func() -> bool: return _hub.call(&"has_arrived")), "Isak no llega")
	var intro: Node = _hub.call(&"get_calc_intro")
	var box: Node = _hub.call(&"get_text_box")
	_check(intro != null and intro.call(&"is_running"), "no empieza el encuentro")
	var n: int = 0
	while intro.call(&"is_running") and n < 12:
		var text: String = box.call(&"get_text")
		if text.begins_with("Has recogido"):
			# A medio escribir: el numero ya entero.
			_check(await _wait(func() -> bool: return String(box.call(&"get_visible_text")).contains("17")),
				"el numero no sale")
			await _save(out_dir, "03_calc_escribiendo.png")
		box.call(&"finish_typing")
		await _frames(20)
		# Con la indicacion de cierre encendida (parpadea).
		_check(await _wait(func() -> bool: return box.call(&"is_confirm_hint_lit")), "sin indicacion de cierre")
		await _save(out_dir, "02_calc_linea_%02d.png" % n)
		if box.call(&"get_speaker_id") == &"":
			await _save(out_dir, "04_eco_interrumpe.png")
		await _close_line(box)
		n += 1
	_check(intro.call(&"is_done"), "el encuentro no termina")
	_check(calc.call(&"is_powered"), "Calc deberia estar encendida")
	var isak: Node2D = _hub.call(&"get_isak")
	isak.global_position = Vector2(6.6 * TILE, float(_hub.call(&"get_floor_y")))
	await _frames(40)
	await _save(out_dir, "05_calc_encendida.png")
	_check(calc.call(&"open", isak), "la tienda no abre")
	await _frames(30)
	await _save(out_dir, "06_tienda_abierta.png")
	calc.call(&"close", true)
	_hub.queue_free()
	var dir := DirAccess.open("user://")
	if dir != null:
		dir.remove(SAVE_PATH.trim_prefix("user://"))
	quit(0 if _ok else 1)


## Cierra la linea importante del cuadro de texto como el jugador.
func _close_line(box: Node) -> void:
	var text: String = box.call(&"get_text")
	box.call(&"finish_typing")
	box.call(&"confirm")
	await _wait(func() -> bool: return box.call(&"get_text") != text)
	await _frames(2)


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
		push_error("render_calc_intro: " + why)


func _save_frozen(out_dir: String, file_name: String) -> void:
	paused = true
	await _save(out_dir, file_name)
	paused = false


func _save(out_dir: String, file_name: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	var path: String = out_dir.path_join(file_name)
	var err: Error = root.get_texture().get_image().save_png(path)
	print("render_calc_intro: %s (%s)" % [path, error_string(err)])
