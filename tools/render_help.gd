## Capturas a 1:1 (1280x720) de la ayuda de Eco con Q (HelpSystem,
## data/help.json; docs/propuesta-asistentes-y-vidas.md §3) con el flujo de
## juego real (scenes/main.tscn) y un guardado vacio (user://tool_save.json, se
## borra al arrancar; nunca el guardado del jugador):
##   01a_eco_se_acerca.png  el receptor del Tramo 2a es candidato: Eco empieza a
##                          brillar (glow_in) y sale de su sitio con la Q encima
##   01b_eco_vuela.png      Eco a medio camino, ya dorado, la Q le sigue
##   01c_eco_junto.png      Eco junto al receptor, brillando en ambar, la Q sobre Eco
##   02_ayuda_pausa.png     tras pulsar help: el juego en pausa, Eco explicando (sigue dorado)
##   03a_eco_vuelve.png     ayuda cerrada: Eco se apaga (glow_out) y vuelve hacia Isak
##   03b_receptor_sin_q.png Eco junto a Isak con su color normal; el receptor ya sin
##                          la Q normal (Isak quieto: ya asoma la Q apagada)
##   04_relectura_q_apagada.png Isak quieto junto al receptor ya aprendido: Q
##                          pequena y apagada sobre el receptor (Eco no vuela ni brilla)
##   05_relectura_pausa.png tras pulsar help: la misma explicacion, en pausa, sin aprender nada
## Necesita ventana (no funciona con --headless).
## Uso: Godot --path . -s tools/render_help.gd [-- carpeta_salida]
extends SceneTree

const SCENE: String = "res://scenes/main.tscn"
const DEFAULT_OUT: String = "user://help_shots"
const TILE: float = 64.0
const RECEIVER_PATH: NodePath = ^"Objects/receiver_56_9"
const WAIT_FRAMES: int = 60 * 10
## Segundos reales para que el cuadro de Eco termine de escribir.
const TYPE_WAIT_S: float = 2.5

var _main: Node


func _init() -> void:
	_run.call_deferred()


func _run() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var out_dir: String = args[0] if args.size() > 0 else ProjectSettings.globalize_path(DEFAULT_OUT)
	DirAccess.make_dir_recursive_absolute(out_dir)
	var main: Node = (load(SCENE) as PackedScene).instantiate()
	# Partida que ya paso por el encuentro con Eco (2026-10-16): Eco conocido y
	# el pulso obtenido (el 1-1 empieza sin pulso; el encuentro se captura con
	# tools/render_eco_encounter.gd).
	var game_state: Node = root.get_node(^"GameState")
	game_state.call(&"meet_ally", &"eco")
	game_state.call(&"mark_notice_seen", &"pulse")
	game_state.call(&"obtain_ability", &"pulse")
	# El puente cercano ya aprendido: al cerrar la ayuda no hay otro candidato
	# y se ve a Eco volver a Isak con su color.
	game_state.call(&"learn_help", &"bridge")
	main.set(&"start_level_id", "1-1")
	root.add_child(main)
	_main = main
	# Llegada por el vortice (Eco entra con Isak).
	var isak: Node2D = main.call(&"get_isak")
	var deadline: int = Time.get_ticks_msec() + 30000
	while Time.get_ticks_msec() < deadline:
		_confirm_lines()
		await process_frame
		if not paused and not isak.call(&"is_warping"):
			break
	for i: int in 30:
		_confirm_lines()
		await process_frame
	var level: Node = main.call(&"get_level")
	var help: Node = level.get_node(^"Help")
	var receiver: Node2D = level.get_node(RECEIVER_PATH)
	# Entre el receptor y el foso del puente, lejos de la Burbuja del 2a.
	isak.global_position = Vector2(57.6 * TILE, 10.0 * TILE)
	isak.set(&"velocity", Vector2.ZERO)
	var ok_q: bool = false
	for i: int in WAIT_FRAMES:
		_confirm_lines()
		await process_frame
		if help.call(&"get_target") == receiver:
			ok_q = true
			break
	var eco: Node = main.call(&"get_eco_companion")
	await _save(out_dir, "01a_eco_se_acerca.png")
	await create_timer(0.12).timeout
	await _save(out_dir, "01b_eco_vuela.png")
	await create_timer(0.8).timeout
	var shown: Node = help.call(&"get_target")
	ok_q = ok_q and shown == receiver and help.call(&"is_prompt_on_eco") and eco.call(&"get_glow") == 2
	print("render_help: Q sobre %s, en Eco %s, animacion %s" % [shown.name if shown != null else "nada",
		help.call(&"is_prompt_on_eco"), eco.call(&"get_shown_animation")])
	await _save(out_dir, "01c_eco_junto.png")
	var press := InputEventAction.new()
	press.action = &"help"
	press.pressed = true
	root.push_input(press)
	await create_timer(TYPE_WAIT_S).timeout
	var ok_pause: bool = paused and eco.call(&"get_glow") == 2
	var box: Node = level.get_node(^"EcoTextBox")
	var text: String = box.call(&"get_text")
	box.call(&"finish_typing")
	await create_timer(0.3).timeout
	await _save(out_dir, "02_ayuda_pausa.png")
	while box.call(&"confirm"):
		pass
	# Al terminar de cerrarse el cuadro, Eco se apaga (glow_out) y vuelve.
	var deadline_out: int = Time.get_ticks_msec() + 3000
	while eco.call(&"get_glow") == 2 and Time.get_ticks_msec() < deadline_out:
		await process_frame
	await create_timer(0.1).timeout
	await _save(out_dir, "03a_eco_vuelve.png")
	await create_timer(1.5).timeout
	var ok_after: bool = not paused and help.call(&"get_target") != receiver and eco.call(&"get_glow") == 0 \
			and not eco.call(&"is_helping")
	await _save(out_dir, "03b_receptor_sin_q.png")
	# Relectura: Isak sigue quieto junto al receptor (tipo ya aprendido).
	var deadline_reread: int = Time.get_ticks_msec() + 4000
	while help.call(&"get_reread_target") != receiver and Time.get_ticks_msec() < deadline_reread:
		await process_frame
	var learned: int = (game_state.get(&"learned_help") as Dictionary).size()
	var ok_reread: bool = help.call(&"get_reread_target") == receiver and help.call(&"is_reread_visible") \
			and eco.call(&"get_glow") == 0 and not eco.call(&"is_helping")
	await _save(out_dir, "04_relectura_q_apagada.png")
	root.push_input(press.duplicate())
	await create_timer(TYPE_WAIT_S).timeout
	box.call(&"finish_typing")
	await create_timer(0.3).timeout
	ok_reread = ok_reread and paused and box.call(&"get_text") == text and eco.call(&"get_glow") == 0 \
			and (game_state.get(&"learned_help") as Dictionary).size() == learned
	await _save(out_dir, "05_relectura_pausa.png")
	while box.call(&"confirm"):
		pass
	print("render_help: q=%s pausa=%s sin_q_despues=%s relectura=%s texto=«%s»" % [ok_q, ok_pause, ok_after,
		ok_reread, text])
	main.queue_free()
	await process_frame
	quit(0 if ok_q and ok_pause and ok_after and ok_reread else 1)


## Cierra (como el jugador) las lineas importantes de Eco, que pausan el juego.
func _confirm_lines() -> void:
	var level: Node = _main.call(&"get_level")
	var box: Node = level.get_node_or_null(^"EcoTextBox") if is_instance_valid(level) else null
	while box != null and box.call(&"is_important") and box.call(&"confirm"):
		pass


func _save(out_dir: String, file_name: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	var image: Image = root.get_texture().get_image()
	var path: String = out_dir.path_join(file_name)
	var err: Error = image.save_png(path)
	print("render_help: %s (%s)" % [path, error_string(err)])
